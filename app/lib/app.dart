import 'dart:async';

import 'package:flutter/material.dart';

import 'core/analytics/analytics_service.dart';
import 'core/color_engine/color_engine.dart';
import 'core/color_engine/color_engine_dart.dart';
import 'core/crash/crash_reporter.dart';
import 'core/onboarding/onboarding_service.dart';
import 'core/segmentation/mediapipe_garment_segmenter.dart';
import 'core/telemetry/retention_state.dart';
import 'core/telemetry/telemetry_config.dart';
import 'core/telemetry/telemetry_controller.dart';
import 'core/telemetry/telemetry_transport.dart';
import 'features/analyzing/analyzing_screen.dart';
import 'features/capture/capture_screen.dart';
import 'features/capture/flow_mode.dart';
import 'features/capture/photo_picker.dart';
import 'features/capture/picker_cache.dart';
import 'features/feedback/feedback_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/result/result_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/sneaker/sneaker_result_screen.dart';
import 'features/story/story_export.dart';
import 'l10n/l10n.dart';
import 'routing/app_routes.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';

/// Root of the app. A single place to:
///  - apply the theme (design tokens → ThemeData).
///  - build the dependencies (composition) and route.
///
/// The optional constructor parameters exist ONLY for widget tests (injecting
/// fakes without native plumbing); production uses the defaults below.
///
/// REGISTRATION POINT OF THE COLOR CORE (D15): when the Dart port exists,
/// ONLY the `_engine = ...` line changes to the real implementation. Nothing
/// else in the app knows the concrete implementation.
class PiketeMakerApp extends StatefulWidget {
  const PiketeMakerApp({
    super.key,
    this.engine,
    this.onboarding,
    this.picker,
    this.analytics,
    this.crashReporter,
    this.telemetry,
    this.followDeviceLocale = false,
  });

  final ColorEngine? engine;
  final OnboardingService? onboarding;
  final PhotoPicker? picker;
  final AnalyticsService? analytics;
  final CrashReporter? crashReporter;

  /// D33 telemetry brains. Tests inject a controller wired to fakes; the
  /// production default below is INERT unless `TELEMETRY_ENDPOINT` was baked
  /// in at build time (telemetry_config.dart) — no storage, no network.
  final TelemetryController? telemetry;

  /// i18n (D18 extended, 2026-07-15). True (production, set by `main.dart`):
  /// the locale follows the DEVICE, resolved against [kSupportedLocales]
  /// with canonical-es fallback. False (the default, hence every test
  /// harness): the locale is PINNED to es — the flutter tester shell always
  /// reports en_US, which would silently flip the copy-pinning suite (the
  /// F&F beta regression net) to the EN translation. Locale behavior itself
  /// is covered by dedicated tests that pass an explicit locale.
  final bool followDeviceLocale;

  @override
  State<PiketeMakerApp> createState() => _PiketeMakerAppState();
}

/// Phase 2.5 feature flag: the PER-GARMENT outfit analysis (#88/#89).
///
/// ON since r10 (2026-07-18): gate G2.5 is SIGNED (base 84.6% no bias, Dart
/// parity done, M33 latency 544 ms) and the #87 per-ABI split ships the 16 MB
/// model without bloating a universal APK, so the outfit engine now runs the
/// MediaPipe per-garment path ("Tu pikete", ARRIBA/ABAJO) with a silent
/// whole-photo degrade (S4) for any photo the segmenter can't split.
///
/// OFF (the prior beta posture, kept documented): the outfit engine is
/// byte-identical to the whole-photo MVP — no segmenter runs, no model asset
/// is needed, the result screen renders the legacy "Tu paleta" layout.
/// Flipping this constant is the ONLY composition change the feature needs: it
/// registers a [MediaPipeGarmentSegmenter] on the outfit engine below.
const bool kGarmentAnalysisEnabled = true;

class _PiketeMakerAppState extends State<PiketeMakerApp> {
  // --- Dependency composition (root) ---
  // Real on-device engine (issue #32): parity with colorlab guaranteed by
  // the golden fixtures of test/core/. The fake remains for the tests.
  // With the Phase 2.5 flag on, the outfit engine gains the MediaPipe
  // segmenter and the per-garment analysis path (#88/#89).
  late final ColorEngine _engine = widget.engine ??
      (kGarmentAnalysisEnabled
          ? ColorEngineDart(
              segmenter: _garmentSegmenter!,
              garmentAnalysis: true,
            )
          : const ColorEngineDart());
  // The outfit engine's segmenter, kept as a field so the model can be
  // PRELOADED (A4). Null when a test injects the engine or the flag is off.
  late final MediaPipeGarmentSegmenter? _garmentSegmenter =
      (widget.engine == null && kGarmentAnalysisEnabled)
          ? MediaPipeGarmentSegmenter()
          : null;
  // Sneaker/product mode (Phase 2S, D24): the SAME engine with the
  // product-mode flag on (core without the person layers). A test-injected
  // engine serves both flows — the fakes are mode-agnostic.
  late final ColorEngine _productEngine =
      widget.engine ?? const ColorEngineDart(productMode: true);
  late final OnboardingService _onboarding =
      widget.onboarding ?? OnboardingServicePrefs();
  late final PhotoPicker _picker = widget.picker ?? ImagePickerPhotoPicker();
  // D33 telemetry (anonymous aggregate cards, ADR 2026-07-19). With the
  // endpoint empty (every build today) the controller is a total no-op.
  late final TelemetryController _telemetry = widget.telemetry ??
      TelemetryController(
        store: PrefsRetentionStore(),
        transport: HttpTelemetryTransport(
          endpoint: kTelemetryEndpoint,
          apiKey: kTelemetryApiKey,
        ),
      );
  // Instrumentation seams (#4). Log-only default, DECORATED by the telemetry
  // sink (ADR §7: the one-line seam swap — call sites untouched; the
  // decorator derives the retention signals from the events that matter and
  // passes everything through).
  late final AnalyticsService _analytics = TelemetryAnalyticsService(
    inner: widget.analytics ?? const LogAnalyticsService(),
    controller: _telemetry,
  );
  late final CrashReporter _crash =
      widget.crashReporter ?? const LogCrashReporter();

  @override
  void initState() {
    super.initState();
    // N1 (D37): a story PNG left in the cache (the app was killed while the
    // preview sheet was open) and share_plus's copy of the last shared story
    // both contain the user's photo — delete them on start so "no la
    // guardamos" stays literally true. Sync, no-op if absent.
    purgeStoryCache();
    // Security audit Q2 F1: image_picker's copies of picked photos (the
    // gallery original, the scaled copy with EXIF GPS) left by a kill
    // between the pick and its own purge. Sync, picker files only.
    purgePickerCache();
    // MODEL PRELOAD (A4, r13): load the 16 MB segmentation model right after
    // the first frame (in a worker isolate) so the first outfit analysis does
    // not pay it inside the progress bar. Silent by contract: a missing asset
    // or native library is memoized and the analysis degrades to the
    // whole-photo path (S4). Only on runtimes that bundle the native TFLite
    // library (Android/iOS), never under the host `flutter test` runner.
    final MediaPipeGarmentSegmenter? segmenter = _garmentSegmenter;
    if (segmenter != null && MediaPipeGarmentSegmenter.isRuntimeSupported) {
      WidgetsBinding.instance.addPostFrameCallback(
          (Duration _) => unawaited(segmenter.preload()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PiketeMaker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Light theme first (D7); themeMode fixed until dark is designed.
      themeMode: ThemeMode.light,
      // i18n (D18 extended): device-driven locale with es fallback in
      // production; pinned canonical es otherwise (see followDeviceLocale).
      // No manual locale picker in this round — device-driven only.
      locale: widget.followDeviceLocale ? null : kCanonicalLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      initialRoute: AppRoutes.home,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Injects the dependencies into each screen according to the route.
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return _page(
          settings,
          HomeScreen(
            onboarding: _onboarding,
            picker: _picker,
            analytics: _analytics,
            telemetry: _telemetry,
          ),
        );

      case AppRoutes.onboarding:
        return _page(settings, OnboardingScreen(onboarding: _onboarding));

      case AppRoutes.capture:
        final CaptureArgs captureArgs = settings.arguments! as CaptureArgs;
        return _page(
          settings,
          CaptureScreen(
            args: captureArgs,
            picker: _picker,
            analytics: _analytics,
          ),
        );

      case AppRoutes.analyzing:
        final AnalyzingArgs args = settings.arguments! as AnalyzingArgs;
        return _page(
          settings,
          AnalyzingScreen(
            // Sneaker mode runs the product-mode engine (D24); same seam.
            engine: args.mode == FlowMode.sneaker ? _productEngine : _engine,
            picker: _picker,
            args: args,
            analytics: _analytics,
            crashReporter: _crash,
          ),
        );

      case AppRoutes.result:
        final ResultArgs resultArgs = settings.arguments! as ResultArgs;
        // The palette enters with motion.reveal: THE moment of the app.
        return _revealRoute(
          settings,
          ResultScreen(
            result: resultArgs.result,
            photo: resultArgs.photo,
            analytics: _analytics,
          ),
        );

      case AppRoutes.sneakerResult:
        final SneakerResultArgs sneakerArgs =
            settings.arguments! as SneakerResultArgs;
        // Same reveal moment as the outfit result (spec §5, states table).
        return _revealRoute(settings,
            SneakerResultScreen(args: sneakerArgs, analytics: _analytics));

      case AppRoutes.feedback:
        final FeedbackArgs args = settings.arguments! as FeedbackArgs;
        return _page(settings, FeedbackScreen(args: args));

      case AppRoutes.settings:
        return _page(settings, SettingsScreen(telemetry: _telemetry));

      default:
        return null;
    }
  }

  MaterialPageRoute<dynamic> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (BuildContext _) => child,
    );
  }

  /// Reveal transition (tokens → motion.reveal, 600 ms): fade + subtle
  /// upward slide. Only the result route uses it.
  PageRouteBuilder<dynamic> _revealRoute(RouteSettings settings, Widget child) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: AppMotion.reveal,
      reverseTransitionDuration: AppMotion.base,
      pageBuilder:
          (BuildContext _, Animation<double> __, Animation<double> ___) =>
              child,
      transitionsBuilder: (BuildContext _, Animation<double> animation,
          Animation<double> __, Widget page) {
        final CurvedAnimation curve =
            CurvedAnimation(parent: animation, curve: AppMotion.enter);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curve),
            child: page,
          ),
        );
      },
    );
  }
}
