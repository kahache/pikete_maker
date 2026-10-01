import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/crash/crash_reporter.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';

/// r13 A2 (review F9): leaving the F13 tutorial with the SYSTEM back gesture
/// counts as "Saltar" — the `onboardingSeen` flag is set, so the tutorial and
/// the `first_launch` event do not come back on every cold start
/// (onboarding-tutorial.md §1.3: set on completing OR skipping, never repeats).

class _NullPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

class _UnusedEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) =>
      throw UnimplementedError('the tutorial never analyzes');
}

PiketeMakerApp _app(
  OnboardingService onboarding,
  AnalyticsService analytics,
) =>
    PiketeMakerApp(
      onboarding: onboarding,
      picker: _NullPicker(),
      engine: _UnusedEngine(),
      analytics: analytics,
      crashReporter: InMemoryCrashReporter(),
    );

/// A "cold start": tear the tree down and pump a fresh app instance over the
/// SAME persisted onboarding flag.
Future<InMemoryAnalyticsService> _coldStart(
  WidgetTester tester,
  OnboardingService onboarding,
) async {
  await tester.pumpWidget(const SizedBox());
  final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
  await tester.pumpWidget(_app(onboarding, analytics));
  await tester.pumpAndSettle();
  return analytics;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final bool fromSecondPage in <bool>[false, true]) {
    final String where = fromSecondPage ? 'ONB-2 (pro tip)' : 'ONB-1';
    testWidgets('system back on $where marks the tutorial as seen',
        (WidgetTester tester) async {
      final OnboardingServiceInMemory onboarding = OnboardingServiceInMemory();
      final InMemoryAnalyticsService firstRun = InMemoryAnalyticsService();
      await tester.pumpWidget(_app(onboarding, firstRun));
      await tester.pumpAndSettle();

      // First launch: the tutorial opened by itself.
      expect(find.text('Saltar'), findsOneWidget);
      expect(firstRun.fired(AnalyticsEvents.firstLaunch), isTrue);
      if (fromSecondPage) {
        await tester.tap(find.text('Empezar'));
        await tester.pumpAndSettle();
        expect(find.text('TIP PRO'), findsOneWidget);
      }

      // Android back gesture / button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Back on the split Home, and the flag is persisted.
      expect(find.text('Saltar'), findsNothing);
      expect(find.text('Mi pikete'), findsOneWidget);
      expect(await onboarding.seen(), isTrue);

      // Next cold start: no tutorial, and it counts as a reopen, not a new
      // first launch.
      final InMemoryAnalyticsService secondRun =
          await _coldStart(tester, onboarding);
      expect(find.text('Saltar'), findsNothing);
      expect(find.text('Mi pikete'), findsOneWidget);
      expect(secondRun.fired(AnalyticsEvents.firstLaunch), isFalse);
      expect(secondRun.fired(AnalyticsEvents.appReopened), isTrue);
    });
  }

  testWidgets('"Saltar" still marks it as seen (explicit exit unchanged)',
      (WidgetTester tester) async {
    final OnboardingServiceInMemory onboarding = OnboardingServiceInMemory();
    await tester.pumpWidget(_app(onboarding, InMemoryAnalyticsService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(await onboarding.seen(), isTrue);
    await _coldStart(tester, onboarding);
    expect(find.text('Saltar'), findsNothing);
  });
}
