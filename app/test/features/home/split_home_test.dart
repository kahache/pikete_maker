import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/home/home_screen.dart';
import 'package:piketemaker/theme/app_colors.dart';
import 'package:piketemaker/theme/app_typography.dart';
import 'package:piketemaker/theme/dimens.dart';
import 'package:piketemaker/widgets/mode_glyphs.dart';

/// Split Home (Phase 2S · D26 Variant A, labels per D27): two equal zones,
/// each routing to its mode, each firing `mode_selected` (G2 funnel).

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

Future<OnboardingService> _alreadySeen() async {
  final OnboardingServiceInMemory s = OnboardingServiceInMemory();
  await s.markSeen();
  return s;
}

/// App under test, landing on the split Home (tutorial already seen).
Future<InMemoryAnalyticsService> _pumpHome(WidgetTester tester) async {
  final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
  await tester.pumpWidget(PiketeMakerApp(
    onboarding: await _alreadySeen(),
    picker: _FakePicker(_testPhoto()),
    analytics: analytics,
  ));
  await tester.pumpAndSettle();
  return analytics;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Split Home (D26/D27)', () {
    testWidgets('renders the two zones: labels, captions and affordances',
        (WidgetTester tester) async {
      await _pumpHome(tester);

      // Canonical labels: "Mis zapas" (D26) + "Mi pikete" (D27 rename).
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);
      expect(find.text('Mi fit'), findsNothing); // pre-D27 label must not leak
      expect(find.text('Monta el fit desde tus zapas'), findsOneWidget);
      expect(find.text('Saca la paleta de tu fit'), findsOneWidget);
      // One "Empezar ›" affordance per zone.
      expect(find.text('Empezar'), findsNWidgets(2));

      // 50/50 and "Mi pikete" on top (CEO 2026-09-30: the outfit pikete +
      // "Vérmelo puesto" is the app's best part; supersedes D26's order).
      final Rect zapas = tester.getRect(find.byKey(HomeScreen.sneakerZoneKey));
      final Rect pikete = tester.getRect(find.byKey(HomeScreen.outfitZoneKey));
      expect(pikete.top, lessThan(zapas.top));
      expect(zapas.height, moreOrLessEquals(pikete.height, epsilon: 1));

      // Tutorial re-entry survives the redesign (spec §1).
      expect(find.byTooltip('Cómo hacer la foto'), findsOneWidget);
    });

    testWidgets(
        '#81 polish: zone contents mirror around the center divider and '
        '"Empezar" is a big pill', (WidgetTester tester) async {
      // Phone-sized surface: the geometry claim ("blocks hug the divider,
      // the air lives at the outer edges") only reads on realistic heights;
      // the default 800×600 test surface leaves the zones too cramped.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _pumpHome(tester);

      final Rect zapasZone =
          tester.getRect(find.byKey(HomeScreen.sneakerZoneKey));
      final Rect piketeZone =
          tester.getRect(find.byKey(HomeScreen.outfitZoneKey));
      final Finder pills = find.byKey(HomeScreen.goPillKey);
      expect(pills, findsNWidgets(2));
      // "Mi pikete" is the top zone since 2026-09-30, "Mis zapas" the bottom.
      final Rect goPikete = tester.getRect(pills.first); // top zone's pill
      final Rect goZapas = tester.getRect(pills.last); // bottom zone's pill
      final Rect glyphPikete = tester.getRect(find.byType(ModeGlyph).first);
      final Rect glyphZapas = tester.getRect(find.byType(ModeGlyph).last);

      // Top zone block pulled DOWN toward the divider: the air sits ABOVE
      // the block, not between block and divider.
      expect(piketeZone.bottom - goPikete.bottom,
          lessThan(glyphPikete.top - piketeZone.top));
      // Bottom zone block pulled UP toward it (CEO r8: the bottom zone must
      // not hug the bottom edge): the air sits BELOW the block.
      expect(glyphZapas.top - zapasZone.top,
          lessThan(zapasZone.bottom - goZapas.bottom));

      // Mirrored: the top block ends the same distance above the divider as
      // the bottom block starts below it.
      final double gapAboveDivider = piketeZone.bottom - goPikete.bottom;
      final double gapBelowDivider = glyphZapas.top - zapasZone.top;
      expect(gapAboveDivider, moreOrLessEquals(gapBelowDivider, epsilon: 1));

      // Bigger affordance (#81): cta type (16, was caption 13) inside a pill
      // at least touch-target tall.
      final Text go = tester.widget<Text>(find.text('Empezar').first);
      expect(go.style!.fontSize, AppType.cta.fontSize);
      expect(tester.getSize(pills.first).height,
          greaterThanOrEqualTo(Sizes.touchTargetMin));
      expect(tester.getSize(pills.last).height,
          greaterThanOrEqualTo(Sizes.touchTargetMin));
    });

    testWidgets(
        'tint washes come from the theme: mint on zapas, purple on '
        'pikete (D26-ratified D8 exception)', (WidgetTester tester) async {
      await _pumpHome(tester);

      final AppColors c =
          tester.element(find.byType(Scaffold)).colors; // theme tokens
      Color zoneColor(Key key) => tester
          .widget<Material>(find
              .descendant(of: find.byKey(key), matching: find.byType(Material))
              .first)
          .color!;

      expect(zoneColor(HomeScreen.sneakerZoneKey), c.actionTint);
      expect(zoneColor(HomeScreen.outfitZoneKey), c.accentTint);
    });

    testWidgets(
        '"Mis zapas" → #83 source selector (F11 flow) + '
        'mode_selected(sneaker)', (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = await _pumpHome(tester);

      await tester.tap(find.text('Mis zapas'));
      await tester.pumpAndSettle();

      // The sneaker flow (Phase 2S · #83): the situation selector replaced the
      // source sheet, carrying the privacy line onto it (CEO flow-merge).
      expect(find.text('¿Desde dónde haces la foto?'), findsOneWidget);
      expect(find.text('Casa o calle'), findsOneWidget);
      expect(find.text('Tu foto no sale del móvil: se analiza aquí mismo.'),
          findsOneWidget);

      final AnalyticsEvent event =
          analytics.named(AnalyticsEvents.modeSelected).single;
      expect(event.params['mode'], 'sneaker');

      // Backing out of the selector stays on the Home: not a dead end.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);
    });

    testWidgets(
        '"Mi pikete" → existing outfit flow (source sheet → confirm) + '
        'mode_selected(outfit)', (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = await _pumpHome(tester);

      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();

      final AnalyticsEvent event =
          analytics.named(AnalyticsEvents.modeSelected).single;
      expect(event.params['mode'], 'outfit');

      // The UNCHANGED outfit flow: source sheet, then the confirm screen.
      expect(find.text('¿De dónde sacamos la foto?'), findsOneWidget);
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
    });

    testWidgets('cancelling the source sheet stays on Home, no dead end',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await tester.pumpWidget(PiketeMakerApp(
        onboarding: await _alreadySeen(),
        picker: _FakePicker(), // picker cancels (returns null)
        analytics: analytics,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      // Cancelled pick → back on the split Home.
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);
      // The pick was still an explicit mode choice: the event fired.
      expect(analytics.fired(AnalyticsEvents.modeSelected), isTrue);
    });
  });
}
