import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/sneaker/sneaker_source_selector.dart';
import 'package:piketemaker/features/sneaker/sneaker_tip_illustrations.dart';

/// Sneaker "photo source selector" + mini-tutorials (Phase 2S · F11 · #83):
/// the situation chooser that REPLACES the source sheet in sneaker mode.

/// Valid 1×1 px PNG (same as the critical-flow tests): decodable "photo".
Uint8List _testPhoto() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

/// Picker that records the source it was asked for (to assert casa/tienda →
/// camera, web → gallery) and always returns a decodable photo.
class _RecordingPicker implements PhotoPicker {
  final List<PhotoSource> calls = <PhotoSource>[];
  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    calls.add(source);
    return _testPhoto();
  }
}

Future<OnboardingService> _alreadySeen() async {
  final OnboardingServiceInMemory s = OnboardingServiceInMemory();
  await s.markSeen();
  return s;
}

/// Pumps the app and drives Home → "Mis zapas" so the #83 selector is on top.
Future<void> _pumpToSelector(
  WidgetTester tester, {
  required PhotoPicker picker,
  required AnalyticsService analytics,
}) async {
  // Taller surface (keep the default 800 width so the shared confirm screen's
  // hint row doesn't wrap): the mini-tutorial's full-width 4:3 illustration
  // needs more than the default 600 px of height on the non-scrolling tip
  // screen.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(PiketeMakerApp(
    onboarding: await _alreadySeen(),
    picker: picker,
    analytics: analytics,
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mis zapas'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sneaker source selector (spec §3)', () {
    testWidgets(
        'renders the heading, sub, 3 situation cards and the privacy '
        'line (carried over from the source sheet)',
        (WidgetTester tester) async {
      await _pumpToSelector(
        tester,
        picker: _RecordingPicker(),
        analytics: InMemoryAnalyticsService(),
      );

      // Contextual kicker, never the wordmark (D27).
      expect(find.text('MIS ZAPAS'), findsOneWidget);
      expect(find.text('PiketeMaker'), findsNothing);

      expect(find.text('¿Desde dónde haces la foto?'), findsOneWidget);
      expect(find.text('Cada sitio tiene su truco. Elige el tuyo.'),
          findsOneWidget);

      // The 3 cards: title + 1-line hint each (exact copy from §6).
      expect(find.text('Casa o calle'), findsOneWidget);
      expect(find.text('Las zapas, en el centro y llenando la foto'),
          findsOneWidget);
      expect(find.text('En una tienda'), findsOneWidget);
      expect(find.text('Ponlas en el suelo, como si fueran tuyas'),
          findsOneWidget);
      expect(find.text('Captura de pantalla'), findsOneWidget);
      expect(find.text('Recórtala hasta dejar solo la zapa'), findsOneWidget);

      // Privacy reassurance moved onto the selector (CEO flow-merge).
      expect(find.text('Tu foto no sale del móvil: se analiza aquí mismo.'),
          findsOneWidget);

      // The old source-sheet copy must not leak into this mode.
      expect(find.text('¿De dónde sacamos las zapas?'), findsNothing);
      expect(find.text('Elegir de la galería'), findsNothing);
    });

    testWidgets('backing out of the selector returns null → stays on Home',
        (WidgetTester tester) async {
      await _pumpToSelector(
        tester,
        picker: _RecordingPicker(),
        analytics: InMemoryAnalyticsService(),
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);
    });
  });

  group('Card tap → analytics + mini-tutorial (spec §4/§7)', () {
    // (card copy · analytics source · tip title · tip CTA · resolved source)
    final List<(String, String, String, String, PhotoSource)> cases =
        <(String, String, String, String, PhotoSource)>[
      (
        'Casa o calle',
        'casa',
        'Zapas en el centro, llenando la foto',
        'Hacer la foto',
        PhotoSource.camera,
      ),
      (
        'En una tienda',
        'tienda',
        'Ponlas en el suelo, como tuyas',
        'Hacer la foto',
        PhotoSource.camera,
      ),
      (
        'Captura de pantalla',
        'web',
        'Recorta hasta dejar solo la zapa',
        'Elegir la captura',
        PhotoSource.gallery,
      ),
    ];

    for (final (
          String cardTitle,
          String source,
          String tipTitle,
          String cta,
          PhotoSource resolved,
        ) in cases) {
      testWidgets(
          'card "$cardTitle" fires sneaker_source_selected(source: $source), '
          'opens its truco, and its CTA picks ${resolved.name}',
          (WidgetTester tester) async {
        final _RecordingPicker picker = _RecordingPicker();
        final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
        await _pumpToSelector(tester, picker: picker, analytics: analytics);

        await tester.tap(find.text(cardTitle));
        await tester.pumpAndSettle();

        // Analytics fires BEFORE the tutorial, once, with the right source.
        final AnalyticsEvent event =
            analytics.named(AnalyticsEvents.sneakerSourceSelected).single;
        expect(event.params['source'], source);

        // The right mini-tutorial: «EL TRUCO» badge + its headline + CTA + the
        // matching illustration.
        expect(find.text('EL TRUCO'), findsOneWidget);
        expect(find.text(tipTitle), findsOneWidget);
        expect(find.text(cta), findsOneWidget);
        expect(
            find.byKey(SneakerSourceTipScreen.illustrationKey), findsOneWidget);
        expect(find.byType(SneakerTipIllustration), findsOneWidget);

        // The CTA is the capture trigger: it resolves to camera vs gallery and
        // lands on the confirm screen.
        await tester.tap(find.text(cta));
        await tester.pumpAndSettle();
        expect(picker.calls, <PhotoSource>[resolved]);
        expect(find.text('¿Se ven bien tus zapas?'), findsOneWidget);
      });
    }

    testWidgets(
        'backing out of a mini-tutorial returns to the selector '
        '(no capture)', (WidgetTester tester) async {
      final _RecordingPicker picker = _RecordingPicker();
      await _pumpToSelector(
        tester,
        picker: picker,
        analytics: InMemoryAnalyticsService(),
      );

      await tester.tap(find.text('Captura de pantalla'));
      await tester.pumpAndSettle();
      expect(find.text('Recorta hasta dejar solo la zapa'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back on the selector, nothing picked.
      expect(find.text('¿Desde dónde haces la foto?'), findsOneWidget);
      expect(picker.calls, isEmpty);
    });
  });
}
