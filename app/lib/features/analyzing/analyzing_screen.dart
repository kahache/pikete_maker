import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/color_engine/color_engine.dart';
import '../../core/color_engine/models.dart';
import '../../core/crash/crash_reporter.dart';
import '../../l10n/l10n.dart';
import '../../routing/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../capture/capture_screen.dart';
import '../capture/flow_mode.dart';
import '../capture/photo_picker.dart';
import '../feedback/feedback_screen.dart';
import '../result/result_screen.dart';
import '../sneaker/sneaker_result_screen.dart';
import '../sneaker/sneaker_tip_illustrations.dart';
import 'prepare_image.dart';
import 'widgets/ad_slot.dart';
import 'widgets/analyzing_progress.dart';

/// Arguments of the "analyzing" route (step 4 of D12).
@immutable
class AnalyzingArgs {
  const AnalyzingArgs({
    required this.photo,
    this.withAd = true,
    this.mode = FlowMode.outfit,
    this.sneakerSituation,
  });

  /// Sneaker mode: the situation the photo was taken in, handed to the
  /// result (N1 / D37: a web screenshot opens the story preview OFF).
  final SneakerTipCase? sneakerSituation;

  /// Encoded bytes of the chosen photo (JPEG from the picker).
  final Uint8List photo;

  /// F8 rule (user-flows §3): the ad only on the FIRST attempt. On a manual
  /// retry the wait was already paid → the slot shows a capture tip (the
  /// layout does not jump).
  final bool withAd;

  /// Which flow is being analyzed (Phase 2S): swaps the copy map, the success
  /// analytics event, the error state and the destination result screen. The
  /// ENGINE is picked per mode at the composition root (`app.dart`): sneaker
  /// mode gets the product-mode engine (D24). Default keeps outfit untouched.
  final FlowMode mode;
}

/// Step 4 of D12 · "analyzing" (canonical mockup result.html, screen 2).
///
/// The MONETIZABLE WAIT (F8) lives here: progress always visible above the
/// rewarded ad slot, which occupies the layout from v1 so the ad never feels
/// like a toll. In the demo the slot is a marked placeholder; in Phase 5 it
/// is filled with AdMob without redesigning the flow.
///
/// Screen pipeline:
///  1. decodes + rescales the real photo (prepare_image.dart),
///  2. calls the [ColorEngine] (seam of the color core), bounded by
///     [AnalyzingScreen.analysisTimeout],
///  3. routes: OK → result (motion.reveal) · E4 → no outfit ·
///     E3 → analysis failed.
///
/// "Never a dead end" (r13, A1): ANY failure lands on E3 — not only the typed
/// [ColorEngineException] / [UnreadableImageException], but also untyped
/// errors (`StateError`, `ArgumentError`, OOM), errors crossing an isolate
/// boundary (`RemoteError`, `IsolateSpawnException`) and a hung engine
/// (`TimeoutException`). The unexpected ones are reported to the
/// [CrashReporter] seam. There is NO automatic retry any more: the engine is
/// deterministic (seed 42, same bytes), so a silent re-run could only fail the
/// same way and doubled the time to E3 (review F10). The manual "Reintentar
/// con la misma" exit of E3 remains.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.engine,
    required this.picker,
    required this.args,
    this.analytics,
    this.crashReporter,
    this.timeout = analysisTimeout,
  });

  /// Minimum time this screen stays visible when the analysis SUCCEEDS (#55).
  ///
  /// The Dart engine finishes sub-second on modern phones, so without a floor
  /// the honest steps and the F8 ad-slot message flash by unread. 3.5 s is
  /// enough to read the two-line slot caption, well under the 10 s G1 budget,
  /// and rehearses the Phase 5 economics (a rewarded video will pace this
  /// screen at 15-30 s). The wait is deliberate pacing, not fake work: the
  /// copy already announces the ad slot, the progress keeps its honest 96%
  /// cap, and ERRORS (E3/E4) never wait — failing fast is honest too.
  static const Duration minDisplayDuration = Duration(milliseconds: 3500);

  /// Upper bound for one engine run before the screen gives up and shows E3
  /// (the E3 spec already covers "pipeline error / timeout").
  ///
  /// Gate G1 budgets 10 s photo→result on a mid-range phone and the M33
  /// measures ~0.5 s, so 30 s is only ever hit by a genuinely hung engine
  /// (e.g. an isolate that never answers) — never by a slow-but-working one.
  /// Without it a hang would leave the user on the 96% bar forever.
  static const Duration analysisTimeout = Duration(seconds: 30);

  final ColorEngine engine;

  /// For the "Elegir de la galería" exit of E4 (never a dead end).
  final PhotoPicker picker;

  final AnalyzingArgs args;

  /// Instrumentation seams (#4). Optional: null → not recorded (tests).
  final AnalyticsService? analytics;
  final CrashReporter? crashReporter;

  /// Engine time budget; production always uses [analysisTimeout]. Tests
  /// shorten it (the engine runs in real async there, so the fake clock
  /// cannot fast-forward it).
  final Duration timeout;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  /// Successful result HELD until the minimum window elapses (#55). The
  /// progress ticker IS the clock of the window (no separate timer): whichever
  /// finishes LAST — engine or animation — releases the result, so the bar
  /// sits exactly on its 96% cap when the reveal happens.
  AnalysisResult? _heldResult;

  /// True once the progress animation completed = the window elapsed.
  bool _minDisplayElapsed = false;

  /// Progress never shows 100% without a result (perceived honesty).
  static const double _capWithoutResult = 0.96;

  bool get _isSneaker => widget.args.mode == FlowMode.sneaker;

  @override
  void initState() {
    super.initState();
    // The progress animation is paced across the minimum window (#55): the
    // three steps distribute over it and the bar lands on the 96% cap right
    // when the held result is released. If the engine is genuinely slower,
    // the bar simply holds at the cap (honesty rule unchanged).
    _progress = AnimationController(
      vsync: this,
      duration: AnalyzingScreen.minDisplayDuration,
    )
      ..addStatusListener(_onProgressStatus)
      ..forward();
    _analyze();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- analysis

  Future<void> _analyze() async {
    // Captured BEFORE navigating: the FeedbackArgs callbacks run when this
    // State is already unmounted (pushReplacement) and its context invalid.
    final NavigatorState nav = Navigator.of(context);
    final AnalysisResult result;
    try {
      final Uint8List normalizedImage =
          await prepareImageForAnalysis(widget.args.photo);
      result = await widget.engine
          .analyze(normalizedImage)
          .timeout(widget.timeout);
    } on ColorEngineException catch (e, stack) {
      // E4 (no outfit) is an expected outcome, not a fault — do not report it.
      // E3 (the pipeline failed) is a real non-fatal.
      if (!e.isNoOutfit) {
        widget.crashReporter
            ?.recordError(e, stack, reason: 'analysis failed (E3)');
      }
      if (!mounted) return;
      _goToUglyState(
        nav,
        e.isNoOutfit ? UglyState.noOutfit : UglyState.analysisFailed,
      );
      return;
    } on UnreadableImageException catch (e, stack) {
      widget.crashReporter
          ?.recordError(e, stack, reason: 'unreadable image (E3)');
      if (!mounted) return;
      _goToUglyState(nav, UglyState.analysisFailed);
      return;
    } on Object catch (e, stack) {
      // Anything else (A1): an untyped engine/segmenter error, an error
      // re-thrown across an isolate boundary (RemoteError), a failed isolate
      // spawn, OOM or the timeout above. It is a bug, so it is REPORTED — and
      // the user still gets the E3 exits instead of a frozen 96% bar.
      widget.crashReporter?.recordError(e, stack,
          reason: 'analysis failed: unexpected ${e.runtimeType} (E3)');
      if (!mounted) return;
      _goToUglyState(nav, UglyState.analysisFailed);
      return;
    }

    // The user may have backed out while the engine ran: nothing to show, and
    // nothing to count (F11).
    if (!mounted) return;
    // Hold the SUCCESSFUL result until the minimum window elapses (#55).
    // Only success pays it: the error paths above navigate immediately.
    _heldResult = result;
    _releaseResultIfReady(nav);
  }

  /// Success analytics, fired only when the result is actually RELEASED to
  /// the result screen (F11): a user who backs out during the #55 hold never
  /// sees a result, so it must not count toward `analyses_bucket` /
  /// `retained_w1` (the telemetry decorator derives both from these events).
  void _logAnalysisCompleted(AnalysisResult result) {
    // Phase 2.5 (#88/#89, spec §6): the segmented path degraded silently —
    // the UI never says so (U4), but the beta telemetry must know how often
    // S3/S4 fire. `to` == the layout the result actually renders.
    if (result.segmentationDegradeReason != null) {
      widget.analytics?.log(AnalyticsEvent(
        AnalyticsEvents.segmentationDegraded,
        <String, Object?>{
          'reason': result.segmentationDegradeReason,
          'to': result.segmentationLayout,
        },
      ));
    }

    // Analysis landed (#4): the funnel's key success event. Each mode has
    // its own event so the G2 (outfit) and G2S (sneaker) funnels stay
    // separable; params are identical by design.
    widget.analytics?.log(AnalyticsEvent(
      _isSneaker
          ? AnalyticsEvents.sneakerAnalysisCompleted
          : AnalyticsEvents.analysisCompleted,
      <String, Object?>{
        'colors': result.palette.length,
        'canvas': result.isCanvas,
      },
    ));
  }

  /// #55: the progress ticker completing = the minimum window elapsed.
  void _onProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _minDisplayElapsed = true;
    if (mounted) _releaseResultIfReady(Navigator.of(context));
  }

  /// Navigates to the result once BOTH the engine and the window are done —
  /// called from both sides because either can finish last (sub-second engine
  /// on a modern phone vs. a genuinely slow analysis).
  void _releaseResultIfReady(NavigatorState nav) {
    final AnalysisResult? result = _heldResult;
    if (result == null || !_minDisplayElapsed) return;
    _heldResult = null;
    // Both callers only get here while mounted (see _analyze and
    // _onProgressStatus), so this is the moment the user really gets a result.
    _logAnalysisCompleted(result);
    if (_isSneaker) {
      // Sneaker mode → the D27 inverted-hierarchy result. It carries the
      // photo so "Otras zapas" can rebuild a capture with a fallback.
      nav.pushReplacementNamed(
        AppRoutes.sneakerResult,
        arguments: SneakerResultArgs(
          result: result,
          photo: widget.args.photo,
          situation: widget.args.sneakerSituation,
        ),
      );
    } else {
      // N1 (D37): the photo rides along (in memory) so the shared story can
      // carry it.
      nav.pushReplacementNamed(
        AppRoutes.result,
        arguments: ResultArgs(result: result, photo: widget.args.photo),
      );
    }
  }

  void _goToUglyState(NavigatorState nav, UglyState state) {
    // Sneaker mode (spec §5 states): ONE error state for E3 and E4 alike
    // ("No hemos pillado los colores") with a single exit CTA. Permission
    // and offline states stay the shared outfit templates by spec.
    if (_isSneaker) state = UglyState.sneakerAnalysisFailed;
    nav.pushReplacementNamed(
      AppRoutes.feedback,
      arguments: FeedbackArgs(
        state: state,
        // "Probar con otra foto" / "Hacer otra foto" / "Otra foto" (#47, UX
        // audit F-3): fresh Confirm over a clean stack (home → confirm) WITH
        // the source sheet already open — the user asked for another photo,
        // so the sheet is one navigation away, not one extra tap. The failed
        // photo stays underneath as fallback if the sheet is dismissed.
        onPrimary: () => nav.pushNamedAndRemoveUntil(
          AppRoutes.capture,
          ModalRoute.withName(AppRoutes.home),
          arguments: CaptureArgs(
            photo: widget.args.photo,
            openSourceSheetOnEntry: true,
            mode: widget.args.mode,
            sneakerSituation: widget.args.sneakerSituation,
          ),
        ),
        // The sneaker error has no secondary CTA (spec: only "Otra foto").
        onSecondary: switch (state) {
          UglyState.sneakerAnalysisFailed => null,
          UglyState.analysisFailed => _retrySamePhoto(nav),
          _ => _pickFromGallery(nav),
        },
      ),
    );
  }

  /// E3 · "Reintentar con la misma": same analysis WITHOUT a second ad (F8).
  VoidCallback _retrySamePhoto(NavigatorState nav) {
    final AnalyzingArgs args = widget.args;
    return () => nav.pushReplacementNamed(
          AppRoutes.analyzing,
          arguments: AnalyzingArgs(
            photo: args.photo,
            withAd: false,
            mode: args.mode,
            sneakerSituation: args.sneakerSituation,
          ),
        );
  }

  /// E4 · "Elegir de la galería": new photo → back to confirm with a clean
  /// stack (home → confirm). If the picker is cancelled, we stay on E4
  /// (which keeps offering its two exits: no dead ends).
  VoidCallback _pickFromGallery(NavigatorState nav) {
    final PhotoPicker picker = widget.picker;
    return () async {
      final Uint8List? bytes = await picker.pick(PhotoSource.gallery);
      if (bytes == null) return;
      // Fire-and-forget by design: the callback's job ends once the route is
      // pushed; nothing here depends on the new route being popped.
      unawaited(nav.pushNamedAndRemoveUntil(
        AppRoutes.capture,
        ModalRoute.withName(AppRoutes.home),
        arguments: CaptureArgs(photo: bytes, mode: widget.args.mode),
      ));
    };
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    // Mode copy map (Phase 2S), resolved in the ACTIVE locale (i18n round):
    // headline, step lines and skip note. Layout is identical for both modes.
    final FlowCopy copy = FlowCopy.of(widget.args.mode, context.l10n);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Space.xxl),
              // Progress zone (ALWAYS above the ad).
              Text(
                copy.analyzingHeadline,
                style: AppType.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.xs),
              AnalyzingProgress(
                animation: _progress,
                copy: copy,
                cap: _capWithoutResult,
              ),
              const SizedBox(height: Space.xxl),
              // REWARDED AD SLOT (F8) — or a capture tip if the ad is off.
              // Align: loose constraints so the slot's max 4:5 rules.
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AdSlot(withAd: widget.args.withAd),
                ),
              ),
              // The accent (purple) signs off exactly once.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xl),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      style: AppType.caption.copyWith(color: c.textTertiary),
                      children: <TextSpan>[
                        TextSpan(text: copy.analyzingSkipNotePrefix),
                        TextSpan(
                          text: context.l10n.analyzingSkipNoteAccent,
                          style: TextStyle(
                              color: c.accent, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
