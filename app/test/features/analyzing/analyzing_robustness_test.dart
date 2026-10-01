import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/crash/crash_reporter.dart';
import 'package:piketemaker/features/analyzing/analyzing_screen.dart';
import 'package:piketemaker/features/capture/flow_mode.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/feedback/feedback_screen.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/routing/app_routes.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// r13 A1 · "never leave the user stuck" on the analyzing screen.
///
/// Locks the boundary the 2026-09-29 review (F1) broke with a scratch repro:
/// an engine throwing anything other than the two typed exceptions left the
/// screen on "Leyendo los colores…" at 96% forever. Now EVERY failure —
/// untyped errors, errors crossing an isolate boundary, a hung engine — lands
/// on the E3 ugly state and is reported. Also pins F10 (no automatic retry of
/// the deterministic engine) and F11 (success analytics only when the result
/// is really shown).

/// Valid 1×1 px PNG (same as the critical-flow tests): decodable "photo".
Uint8List _testPhoto() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

const String _outfitE3Headline = 'No pillamos bien tu fit.';
const String _sneakerErrorHeadline = 'No hemos pillado los colores';
const String _resultMarker = 'RESULT';
const String _startLabel = 'GO';

class _NullPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

/// Counts calls and throws whatever [error] builds.
class _ThrowingEngine implements ColorEngine {
  _ThrowingEngine(this.error);

  final Object Function() error;
  int calls = 0;

  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async {
    calls++;
    throw error();
  }
}

/// Runs the "analysis" in a REAL isolate, like the perf agent's move of the
/// inference off the UI isolate — so the error genuinely crosses the boundary.
class _IsolateEngine implements ColorEngine {
  _IsolateEngine(this.computation);

  final FutureOr<AnalysisResult> Function() computation;

  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) =>
      Isolate.run<AnalysisResult>(computation);
}

AnalysisResult _throwStateErrorInIsolate() =>
    throw StateError('segmenter blew up inside the isolate');

/// The isolate dies without sending a result (what a native crash / kill of
/// a worker isolate looks like from the caller): Isolate.run surfaces it as a
/// [RemoteError].
Future<AnalysisResult> _dieWithoutResult() {
  Isolate.current.kill(priority: Isolate.immediate);
  return Completer<AnalysisResult>().future;
}

class _HangingEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) =>
      Completer<AnalysisResult>().future;
}

/// Finishes instantly with a result that also carries a silent S4 degrade,
/// so both success events (`analysis_completed` + `segmentation_degraded`)
/// are in play.
class _InstantDegradedEngine implements ColorEngine {
  int calls = 0;

  static const AnalysisResult result = AnalysisResult(
    baseIndex: 0,
    palette: <ColorSample>[
      ColorSample(color: Color(0xFFE13683), weight: 0.6),
      ColorSample(color: Color(0xFF9CA6C6), weight: 0.4),
    ],
    harmonies: <Harmony>[
      Harmony(
        type: HarmonyType.complementary,
        name: 'Complementario',
        description: 'Contraste máximo, 2 colores',
        colors: <Color>[Color(0xFFE13683), Color(0xFF36E194)],
      ),
    ],
    segmentationLayout: 'whole',
    segmentationDegradeReason: 'model_failed',
  );

  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async {
    calls++;
    return result;
  }
}

/// Minimal app around the REAL [AnalyzingScreen] + [FeedbackScreen]: a start
/// button pushes the analyzing route; result routes are a marker. Standalone
/// (not PiketeMakerApp) so the engine time budget can be shortened.
class _Harness {
  _Harness(
    this.engine, {
    this.mode = FlowMode.outfit,
    this.timeout = AnalyzingScreen.analysisTimeout,
  });

  final ColorEngine engine;
  final FlowMode mode;
  final Duration timeout;
  final InMemoryCrashReporter crash = InMemoryCrashReporter();
  final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();

  Widget app() => MaterialApp(
        theme: AppTheme.light(),
        locale: kCanonicalLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        onGenerateRoute: _route,
      );

  Route<dynamic> _route(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRoutes.analyzing => AnalyzingScreen(
          engine: engine,
          picker: _NullPicker(),
          args: settings.arguments! as AnalyzingArgs,
          analytics: analytics,
          crashReporter: crash,
          timeout: timeout,
        ),
      AppRoutes.feedback =>
        FeedbackScreen(args: settings.arguments! as FeedbackArgs),
      AppRoutes.result ||
      AppRoutes.sneakerResult =>
        const Scaffold(body: Text(_resultMarker)),
      _ => Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.analyzing,
                arguments: AnalyzingArgs(photo: _testPhoto(), mode: mode),
              ),
              child: const Text(_startLabel),
            ),
          ),
        ),
    };
    return MaterialPageRoute<dynamic>(
        settings: settings, builder: (BuildContext _) => page);
  }

  /// Taps start and lets the REAL async work (image decode, isolates,
  /// timeouts) run until [done] holds or [max] elapses, then settles.
  Future<void> run(
    WidgetTester tester, {
    required bool Function() done,
    Duration max = const Duration(seconds: 10),
  }) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(_startLabel));
      await tester.pump();
      final DateTime deadline = DateTime.now().add(max);
      while (!done() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A1 · any failure lands on E3 (never a frozen 96%)', () {
    // The review's repro was an ArgumentError (palette n == 0); the rest are
    // the other types that bypassed the two typed catches.
    final Map<String, Object Function()> unexpected = <String, Object Function()>{
      'ArgumentError (review F1 repro)': () => ArgumentError('n must be > 0'),
      'StateError': () => StateError('bad state'),
      'RemoteError (isolate boundary)': () =>
          RemoteError('boom in worker', '#0 worker'),
      'IsolateSpawnException': () => IsolateSpawnException('cannot spawn'),
      'OutOfMemoryError': () => const OutOfMemoryError(),
      'a thrown non-Error object': () => 'just a string',
    };

    unexpected.forEach((String label, Object Function() error) {
      testWidgets('$label → E3 with both exits, reported',
          (WidgetTester tester) async {
        final _ThrowingEngine engine = _ThrowingEngine(error);
        final _Harness h = _Harness(engine);
        await h.run(tester, done: () => h.crash.errors.isNotEmpty);

        expect(find.text(_outfitE3Headline), findsOneWidget);
        // E3's two exits (never a dead end).
        expect(find.text('Probar con otra foto'), findsOneWidget);
        expect(find.text('Reintentar con la misma'), findsOneWidget);
        expect(find.text('Leyendo los colores de tu fit…'), findsNothing);

        final RecordedError reported = h.crash.errors.single;
        expect(reported.error.runtimeType, error().runtimeType);
        expect(reported.reason, contains('unexpected'));
        expect(reported.reason, contains('E3'));
        expect(h.analytics.fired(AnalyticsEvents.analysisCompleted), isFalse);
      });
    });

    testWidgets('an error thrown inside a REAL isolate → E3, reported',
        (WidgetTester tester) async {
      final _Harness h = _Harness(_IsolateEngine(_throwStateErrorInIsolate));
      await h.run(tester, done: () => h.crash.errors.isNotEmpty);

      expect(find.text(_outfitE3Headline), findsOneWidget);
      expect(h.crash.errors.single.error, isA<StateError>());
    });

    testWidgets('a worker isolate dying without a result → E3 (RemoteError)',
        (WidgetTester tester) async {
      final _Harness h = _Harness(_IsolateEngine(_dieWithoutResult));
      await h.run(tester, done: () => h.crash.errors.isNotEmpty);

      expect(find.text(_outfitE3Headline), findsOneWidget);
      expect(h.crash.errors.single.error, isA<RemoteError>());
    });

    testWidgets('a hung engine times out → E3, reported as a timeout',
        (WidgetTester tester) async {
      final _Harness h = _Harness(
        _HangingEngine(),
        timeout: const Duration(milliseconds: 300),
      );
      await h.run(tester, done: () => h.crash.errors.isNotEmpty);

      expect(find.text(_outfitE3Headline), findsOneWidget);
      expect(h.crash.errors.single.error, isA<TimeoutException>());
    });

    test('the production time budget stays well above the G1 10 s target', () {
      expect(AnalyzingScreen.analysisTimeout,
          greaterThanOrEqualTo(const Duration(seconds: 20)));
      // Constructed only, never pumped: no async work starts.
      final AnalyzingScreen screen = AnalyzingScreen(
        engine: _HangingEngine(),
        picker: _NullPicker(),
        args: AnalyzingArgs(photo: Uint8List(0)),
      );
      expect(screen.timeout, AnalyzingScreen.analysisTimeout);
    });

    testWidgets('sneaker mode: an unexpected error → the sneaker error state',
        (WidgetTester tester) async {
      final _Harness h = _Harness(
        _ThrowingEngine(() => StateError('bad state')),
        mode: FlowMode.sneaker,
      );
      await h.run(tester, done: () => h.crash.errors.isNotEmpty);

      expect(find.text(_sneakerErrorHeadline), findsOneWidget);
      expect(find.text('Otra foto'), findsOneWidget);
      expect(h.crash.errors, hasLength(1));
    });

    testWidgets('"Reintentar con la misma" from an unexpected-error E3 re-runs',
        (WidgetTester tester) async {
      final _ThrowingEngine engine =
          _ThrowingEngine(() => StateError('bad state'));
      final _Harness h = _Harness(engine);
      await h.run(tester, done: () => h.crash.errors.isNotEmpty);
      expect(engine.calls, 1);

      await tester.runAsync(() async {
        await tester.tap(find.text('Reintentar con la misma'));
        await tester.pump();
        final DateTime deadline =
            DateTime.now().add(const Duration(seconds: 10));
        while (h.crash.errors.length < 2 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();

      // The manual retry really ran the engine again and still has an exit.
      expect(engine.calls, 2);
      expect(find.text(_outfitE3Headline), findsOneWidget);
    });
  });

  group('F10 · no automatic retry of the deterministic engine', () {
    testWidgets('a typed E3 failure runs the engine exactly once',
        (WidgetTester tester) async {
      final _ThrowingEngine engine =
          _ThrowingEngine(() => const ColorEngineException('pipeline down'));
      final _Harness h = _Harness(engine);
      await h.run(tester, done: () => h.crash.errors.isNotEmpty);

      expect(find.text(_outfitE3Headline), findsOneWidget);
      expect(engine.calls, 1);
      expect(h.crash.errors.single.error, isA<ColorEngineException>());
    });

    testWidgets('E4 (no outfit) is not reported as a fault',
        (WidgetTester tester) async {
      final _ThrowingEngine engine = _ThrowingEngine(
          () => const ColorEngineException('no outfit', isNoOutfit: true));
      final _Harness h = _Harness(engine);
      await h.run(tester, done: () => engine.calls > 0,
          max: const Duration(seconds: 2));

      expect(find.text('Aquí no vemos un outfit claro.'), findsOneWidget);
      expect(engine.calls, 1);
      expect(h.crash.errors, isEmpty);
    });
  });

  group('F11 · success analytics only when the result is shown', () {
    testWidgets('backing out during the #55 hold logs nothing',
        (WidgetTester tester) async {
      final _InstantDegradedEngine engine = _InstantDegradedEngine();
      final _Harness h = _Harness(engine);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text(_startLabel));
        await tester.pump();
        final DateTime deadline =
            DateTime.now().add(const Duration(seconds: 10));
        while (engine.calls == 0 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        // Let the engine's continuation hold the result.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      // The result is held (window not elapsed): still on analyzing.
      expect(find.text('Leyendo los colores de tu fit…'), findsOneWidget);

      // System back during the hold.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(AnalyzingScreen.minDisplayDuration);
      await tester.pumpAndSettle();

      expect(find.text(_startLabel), findsOneWidget);
      expect(find.text(_resultMarker), findsNothing);
      expect(h.analytics.fired(AnalyticsEvents.analysisCompleted), isFalse);
      expect(h.analytics.fired(AnalyticsEvents.segmentationDegraded), isFalse);
      expect(h.crash.errors, isEmpty);
    });

    testWidgets('staying through the hold logs both events, once, on reveal',
        (WidgetTester tester) async {
      final _InstantDegradedEngine engine = _InstantDegradedEngine();
      final _Harness h = _Harness(engine);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text(_startLabel));
        await tester.pump();
        final DateTime deadline =
            DateTime.now().add(const Duration(seconds: 10));
        while (engine.calls == 0 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      // Engine done, result held: nothing counted yet.
      expect(h.analytics.fired(AnalyticsEvents.analysisCompleted), isFalse);

      await tester.pump(AnalyzingScreen.minDisplayDuration);
      await tester.pumpAndSettle();

      expect(find.text(_resultMarker), findsOneWidget);
      expect(h.analytics.named(AnalyticsEvents.analysisCompleted), hasLength(1));
      final AnalyticsEvent degraded =
          h.analytics.named(AnalyticsEvents.segmentationDegraded).single;
      expect(degraded.params['reason'], 'model_failed');
      expect(degraded.params['to'], 'whole');
    });
  });
}
