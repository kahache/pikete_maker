import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/core/telemetry/retention_state.dart';
import 'package:piketemaker/core/telemetry/telemetry_controller.dart';
import 'package:piketemaker/core/telemetry/telemetry_transport.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/home/home_screen.dart';
import 'package:piketemaker/features/settings/settings_screen.dart';

/// D33 telemetry surfaces: first-run NOTICE (legal doc §2) + "Ajustes"
/// opt-out (§3) — and their ABSENCE when the endpoint is empty (no consent
/// theater: nothing collected ⇒ nothing shown, r10-identical Home).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String endpoint = 'https://ingest.test/v1/signals';

  Future<OnboardingService> alreadySeen() async {
    final OnboardingServiceInMemory s = OnboardingServiceInMemory();
    await s.markSeen();
    return s;
  }

  TelemetryController active(
          InMemoryRetentionStore store, _FakeTransport transport) =>
      TelemetryController(
        store: store,
        transport: transport,
        endpoint: endpoint,
        platform: 'android',
        locale: 'es',
      );

  Future<void> pumpApp(WidgetTester tester,
      {TelemetryController? telemetry}) async {
    await tester.pumpWidget(PiketeMakerApp(
      onboarding: await alreadySeen(),
      picker: _FakePicker(),
      analytics: InMemoryAnalyticsService(),
      telemetry: telemetry,
    ));
    await tester.pumpAndSettle();
  }

  group('first-run notice (telemetry active)', () {
    testWidgets(
        'renders the es legal copy, "Entendido" closes it and the '
        'install card flushes only then', (WidgetTester tester) async {
      final InMemoryRetentionStore store = InMemoryRetentionStore();
      final _FakeTransport transport = _FakeTransport();
      await pumpApp(tester, telemetry: active(store, transport));

      // The notice sheet, copy VERBATIM from the legal doc (es canonical).
      expect(find.text('Esto es tuyo'), findsOneWidget);
      expect(
          find.textContaining('Tu foto no sale del móvil.', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('estadísticas anónimas', findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('Sin fotos, sin datos personales',
              findRichText: true),
          findsOneWidget);
      // Nothing was sent while the notice is up ("nothing before the
      // notice is shown").
      expect(transport.batches, isEmpty);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Esto es tuyo'), findsNothing);

      // Now the queued install card went out — exactly one, anonymous.
      expect(transport.batches, hasLength(1));
      expect(transport.batches.single.single['kind'], 'install');
      expect(store.record!.noticeSeen, isTrue);
    });

    testWidgets('shown at most once: a later launch shows no notice',
        (WidgetTester tester) async {
      final InMemoryRetentionStore store = InMemoryRetentionStore();
      final _FakeTransport transport = _FakeTransport();
      store.record = RetentionRecord(noticeSeen: true); // previous launch
      await pumpApp(tester, telemetry: active(store, transport));
      expect(find.text('Esto es tuyo'), findsNothing);
    });

    testWidgets('opted out ⇒ no notice either', (WidgetTester tester) async {
      final InMemoryRetentionStore store = InMemoryRetentionStore();
      store.record = RetentionRecord(enabled: false, noticeSeen: true);
      await pumpApp(tester, telemetry: active(store, _FakeTransport()));
      expect(find.text('Esto es tuyo'), findsNothing);
    });
  });

  group('"Ajustes" opt-out surface (telemetry active)', () {
    testWidgets(
        'gear → Ajustes → switching OFF purges the queue and blocks '
        'sends', (WidgetTester tester) async {
      final InMemoryRetentionStore store = InMemoryRetentionStore();
      final _FakeTransport transport = _FakeTransport()
        ..fallback = TelemetrySendOutcome.notSent; // strand the install card
      store.record = RetentionRecord(noticeSeen: true);
      await pumpApp(tester, telemetry: active(store, transport));

      // The offline queue holds the (unsendable) install card.
      expect(store.record!.queue, hasLength(1));

      await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Estadísticas de uso anónimas'), findsOneWidget);
      expect(find.textContaining('Al desactivarlas, dejamos de enviar nada.'),
          findsOneWidget);

      final Finder toggle = find.byKey(SettingsScreen.telemetrySwitchKey);
      expect(tester.widget<Switch>(toggle).value, isTrue); // default ON
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(store.record!.enabled, isFalse);
      expect(store.record!.queue, isEmpty); // purged, not just paused
    });
  });

  group('endpoint EMPTY (every build today): zero telemetry surface', () {
    testWidgets('no notice, no settings gear — the Home is r10-identical',
        (WidgetTester tester) async {
      await pumpApp(tester); // default (inert) telemetry wiring
      expect(find.text('Esto es tuyo'), findsNothing);
      expect(find.byKey(HomeScreen.settingsButtonKey), findsNothing);
      // The split Home is intact.
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);
    });

    testWidgets(
        'an inert controller over a THROWING store: the app runs the '
        'whole gate without touching storage or network',
        (WidgetTester tester) async {
      final _FakeTransport transport = _FakeTransport();
      final TelemetryController off = TelemetryController(
        store: ThrowingRetentionStore(),
        transport: transport,
        endpoint: '',
        platform: 'android',
        locale: 'es',
      );
      await pumpApp(tester, telemetry: off);
      expect(find.text('Esto es tuyo'), findsNothing);
      expect(find.byKey(HomeScreen.settingsButtonKey), findsNothing);
      expect(transport.batches, isEmpty);
    });
  });
}

/// Valid 1×1 px PNG (same fixture as the critical-flow tests).
class _FakePicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

class _FakeTransport implements TelemetryTransport {
  final List<List<Map<String, Object?>>> batches =
      <List<Map<String, Object?>>>[];
  TelemetrySendOutcome fallback = TelemetrySendOutcome.delivered;

  @override
  Future<TelemetrySendOutcome> send(List<Map<String, Object?>> cards) async {
    batches.add(List<Map<String, Object?>>.from(cards));
    return fallback;
  }
}
