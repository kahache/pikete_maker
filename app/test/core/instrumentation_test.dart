import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/crash/crash_reporter.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/analyzing/analyzing_screen.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// Minimal instrumentation (#4): the events must fire at the right moments and
/// genuine failures must reach the crash reporter — asserted with the in-memory
/// doubles (no SDK, no backend).

/// Valid 1×1 px PNG (same as the critical-flow tests): decodable "photo".
Uint8List _testPhoto() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

class _FakePicker implements PhotoPicker {
  _FakePicker([this.bytes]);
  final Uint8List? bytes;
  @override
  Future<Uint8List?> pick(PhotoSource source) async => bytes;
}

/// Instant fixed result: the sub-second phone (#55).
class _InstantEngine implements ColorEngine {
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
  );
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async => result;
}

/// Always fails → E3.
class _FailingEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async =>
      throw const ColorEngineException('pipeline down');
}

PiketeMakerApp _app({
  required AnalyticsService analytics,
  required CrashReporter crash,
  required OnboardingService onboarding,
  ColorEngine? engine,
}) =>
    PiketeMakerApp(
      onboarding: onboarding,
      picker: _FakePicker(_testPhoto()),
      engine: engine,
      analytics: analytics,
      crashReporter: crash,
    );

Future<OnboardingService> _alreadySeen() async {
  final OnboardingServiceInMemory s = OnboardingServiceInMemory();
  await s.markSeen();
  return s;
}

/// Home → sheet → gallery → confirm → Analizar (real async under runAsync),
/// then drains the min-display window so the result route lands.
Future<void> _driveToResult(WidgetTester tester, ColorEngine engine,
    {required AnalyticsService analytics, required CrashReporter crash}) async {
  await tester.pumpWidget(_app(
    analytics: analytics,
    crash: crash,
    onboarding: await _alreadySeen(),
    engine: engine,
  ));
  await tester.pumpAndSettle();
  // Split Home (D26): "Mi pikete" is the outfit-flow entry.
  await tester.tap(find.text('Mi pikete'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Elegir de la galería'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(find.text('Analizar'));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump(AnalyzingScreen.minDisplayDuration);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('launch events (onboarding gate)', () {
    testWidgets('first launch fires first_launch', (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await tester.pumpWidget(_app(
        analytics: analytics,
        crash: InMemoryCrashReporter(),
        onboarding: OnboardingServiceInMemory(), // not seen
      ));
      await tester.pumpAndSettle();

      expect(analytics.fired(AnalyticsEvents.firstLaunch), isTrue);
      expect(analytics.fired(AnalyticsEvents.appReopened), isFalse);
    });

    testWidgets('a later launch fires app_reopened',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await tester.pumpWidget(_app(
        analytics: analytics,
        crash: InMemoryCrashReporter(),
        onboarding: await _alreadySeen(),
      ));
      await tester.pumpAndSettle();

      expect(analytics.fired(AnalyticsEvents.appReopened), isTrue);
      expect(analytics.fired(AnalyticsEvents.firstLaunch), isFalse);
    });
  });

  testWidgets('result_viewed fires when the result screen mounts',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ResultScreen(result: _InstantEngine.result, analytics: analytics),
    ));
    await tester.pumpAndSettle();

    expect(analytics.fired(AnalyticsEvents.resultViewed), isTrue);
  });

  testWidgets('analysis_completed fires on success, no error recorded',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final InMemoryCrashReporter crash = InMemoryCrashReporter();
    await _driveToResult(tester, _InstantEngine(),
        analytics: analytics, crash: crash);

    // Landed on the result.
    expect(find.text('Tu paleta'), findsOneWidget);

    final AnalyticsEvent completed =
        analytics.named(AnalyticsEvents.analysisCompleted).single;
    expect(completed.params['colors'], 2);
    expect(completed.params['canvas'], false);
    // The payoff event also fired, and nothing was reported as an error.
    expect(analytics.fired(AnalyticsEvents.resultViewed), isTrue);
    expect(crash.errors, isEmpty);
  });

  testWidgets('an E3 failure is recorded, analysis_completed does NOT fire',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final InMemoryCrashReporter crash = InMemoryCrashReporter();
    await tester.pumpWidget(_app(
      analytics: analytics,
      crash: crash,
      onboarding: await _alreadySeen(),
      engine: _FailingEngine(),
    ));
    await tester.pumpAndSettle();
    // Split Home (D26): "Mi pikete" is the outfit-flow entry.
    await tester.tap(find.text('Mi pikete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Analizar'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // E3 ugly state, one non-fatal recorded, and no success event.
    expect(find.text('No pillamos bien tu fit.'), findsOneWidget);
    expect(crash.errors, hasLength(1));
    expect(crash.errors.single.reason, contains('E3'));
    expect(crash.errors.single.error, isA<ColorEngineException>());
    expect(analytics.fired(AnalyticsEvents.analysisCompleted), isFalse);
  });
}
