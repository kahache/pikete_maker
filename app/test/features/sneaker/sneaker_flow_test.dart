import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/analyzing/analyzing_screen.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:piketemaker/features/sneaker/sneaker_tip_case_data.dart';
import 'package:piketemaker/features/sneaker/sneaker_tip_illustrations.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/features/story/story_share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sneaker inner flow (Phase 2S · F11, final spec 2026-07-11): capture →
/// analyzing → result in product mode, D27 inverted hierarchy on the result.

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

/// Engine that finishes instantly with a fixed result (the sub-second real
/// phone of #55).
class _FixedEngine implements ColorEngine {
  const _FixedEngine(this.result);
  final AnalysisResult result;
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async => result;
}

/// Engine that always fails → sneaker error state.
class _FailingEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async =>
      throw const ColorEngineException('pipeline down');
}

const Color _rojo = Color(0xFFD6352E); // sneaker base (mockup kicks)
const Color _teal = Color(0xFF2E9E86); // its complement ("verde-azulado")

/// Red kicks: chromatic base + the engine's 4 schemes (mockup values). Both
/// hero colors are dark → the neutral suggestion must be CREMA.
const AnalysisResult _kicksResult = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _rojo, weight: 0.4),
    ColorSample(color: Color(0xFFEDE9E1), weight: 0.3),
    ColorSample(color: Color(0xFF23211F), weight: 0.2),
    ColorSample(color: Color(0xFF8A8F98), weight: 0.1),
  ],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[_rojo, _teal],
    ),
    Harmony(
      type: HarmonyType.analogous,
      name: 'Análogo',
      description: 'Suave, tono sobre tono',
      colors: <Color>[Color(0xFFD62E6E), _rojo, Color(0xFFD6702E)],
    ),
    Harmony(
      type: HarmonyType.triadic,
      name: 'Triádico',
      description: 'Equilibrado, 3 colores',
      colors: <Color>[_rojo, Color(0xFF2ED635), Color(0xFF352ED6)],
    ),
    Harmony(
      type: HarmonyType.splitComplementary,
      name: 'Complementario dividido',
      description: 'Contraste con matiz',
      colors: <Color>[_rojo, Color(0xFF2ED6A0), Color(0xFF2E86D6)],
    ),
  ],
);

/// 100% neutral kicks (D10 canvas mode): no base, no harmonies, curated pops.
const AnalysisResult _canvasResult = AnalysisResult(
  baseIndex: -1,
  palette: <ColorSample>[
    ColorSample(color: Color(0xFF8A8F98), weight: 0.6), // gris dominante
    ColorSample(color: Color(0xFFEDEDED), weight: 0.4),
  ],
  harmonies: <Harmony>[],
  canvasAccents: <Color>[
    Color(0xFFE4322B),
    Color(0xFF2B5CE4),
    Color(0xFFE0A000),
    Color(0xFF12A150),
    Color(0xFFD6248C),
  ],
);

Future<OnboardingService> _alreadySeen() async {
  final OnboardingServiceInMemory s = OnboardingServiceInMemory();
  await s.markSeen();
  return s;
}

/// Pumps the app and drives Home → "Mis zapas" → #83 selector ([card],
/// default "Casa o calle") → mini-tutorial CTA ([tipCta]) → confirm.
Future<InMemoryAnalyticsService> _pumpToConfirm(
  WidgetTester tester,
  ColorEngine engine, {
  String card = 'Casa o calle',
  String tipCta = 'Hacer la foto',
}) async {
  // Taller surface (keep the default 800 width so the shared confirm screen's
  // hint row doesn't wrap): the #83 mini-tutorial's full-width 4:3 illustration
  // needs more than the default 600 px of height on the non-scrolling tip
  // screen.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
  await tester.pumpWidget(PiketeMakerApp(
    onboarding: await _alreadySeen(),
    picker: _FakePicker(_testPhoto()),
    engine: engine,
    analytics: analytics,
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mis zapas'));
  await tester.pumpAndSettle();
  // #83 source selector → a situation card → its mini-tutorial → capture.
  await tester.tap(find.text(card));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tipCta));
  await tester.pumpAndSettle();
  return analytics;
}

/// Taps "Dame la combi". The image prep + engine are REAL async → runAsync
/// (same pattern as the critical-flow tests); the #55 window stays on the
/// fake clock for the caller to drive with pump(duration).
Future<void> _tapDameLaCombi(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Dame el pikete'));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

/// Full drive to the sneaker result screen.
Future<InMemoryAnalyticsService> _pumpToResult(
  WidgetTester tester,
  ColorEngine engine, {
  String card = 'Casa o calle',
  String tipCta = 'Hacer la foto',
}) async {
  final InMemoryAnalyticsService analytics =
      await _pumpToConfirm(tester, engine, card: card, tipCta: tipCta);
  await _tapDameLaCombi(tester);
  await tester.pump(AnalyzingScreen.minDisplayDuration); // #55 window
  await tester.pumpAndSettle(); // reveal transition
  return analytics;
}

/// Lets the story sheet's real-async render finish (runAsync + pump rounds)
/// so no work is left in flight at teardown.
Future<void> _settleSheet(WidgetTester tester) async {
  bool ready() {
    final Finder cta = find.descendant(
      of: find.byKey(StorySharePreviewSheet.ctaKey),
      matching: find.byType(FilledButton),
    );
    return cta.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(cta).onPressed != null;
  }

  for (int i = 0; i < 60 && !ready(); i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(ready(), isTrue, reason: 'the story preview rendered');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sneaker capture (spec §3)', () {
    testWidgets(
        'confirm screen: sneaker copy map + contextual MIS ZAPAS app bar',
        (WidgetTester tester) async {
      await _pumpToConfirm(tester, const _FixedEngine(_kicksResult));

      // Contextual kicker, exact casing (D27-Q6) — never the wordmark here.
      expect(find.text('MIS ZAPAS'), findsOneWidget);
      expect(find.text('PiketeMaker'), findsNothing);
      // Sneaker copy map (full slang CTAs, D27-Q5).
      expect(find.text('¿Se ven bien tus zapas?'), findsOneWidget);
      expect(find.text('Fondo liso y bien iluminadas = colores más finos.'),
          findsOneWidget);
      expect(find.text('Dame el pikete'), findsOneWidget);
      expect(find.text('Otra foto'), findsOneWidget);
      // The outfit confirm copy must not leak into this mode.
      expect(find.text('¿Se ve bien tu fit?'), findsNothing);
      expect(find.text('Analizar'), findsNothing);
    });
  });

  group('Sneaker analyzing (spec §4)', () {
    testWidgets('sneaker copy + the #55 minimum window still holds',
        (WidgetTester tester) async {
      await _pumpToConfirm(tester, const _FixedEngine(_kicksResult));
      await _tapDameLaCombi(tester);

      // Sneaker analyzing copy; ad slot identical to outfit (F8).
      expect(find.text('Sacando los colores de tus zapas…'), findsOneWidget);
      expect(find.text('Aislando las zapas del fondo'), findsOneWidget);
      expect(find.textContaining('Tu combi aparece en cuanto termine'),
          findsOneWidget);
      expect(find.text('HUECO REWARDED · F8 · ADMOB'), findsOneWidget);

      // The instant engine already finished, but the result is HELD (#55).
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Combina tu ropa con estas zapas'), findsNothing);

      // The window elapses → the reveal happens.
      await tester.pump(AnalyzingScreen.minDisplayDuration);
      await tester.pumpAndSettle();
      expect(find.text('Combina tu ropa con estas zapas'), findsOneWidget);
    });

    testWidgets('sneaker_analysis_completed fires (and the outfit event NOT)',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics =
          await _pumpToResult(tester, const _FixedEngine(_kicksResult));

      final AnalyticsEvent event =
          analytics.named(AnalyticsEvents.sneakerAnalysisCompleted).single;
      expect(event.params['colors'], _kicksResult.palette.length);
      expect(event.params['canvas'], false);
      // The funnels stay separable (G2 vs G2S).
      expect(analytics.fired(AnalyticsEvents.analysisCompleted), isFalse);
    });
  });

  group('Sneaker result (spec §5, D27 inverted hierarchy)', () {
    testWidgets(
        'recommendation is the protagonist: hero band ABOVE the '
        'demoted palette strip, with role micro-labels',
        (WidgetTester tester) async {
      await _pumpToResult(tester, const _FixedEngine(_kicksResult));

      expect(find.text('MIS ZAPAS'), findsOneWidget); // contextual app bar
      expect(find.text('Combina tu ropa con estas zapas'), findsOneWidget);
      expect(find.textContaining('Tus zapas ·'), findsOneWidget); // meta

      // Hero kicker names the hero scheme (label style = uppercase on text).
      expect(find.text('LA COMBI · CONTRASTE'), findsOneWidget);

      // D27: hero combo band renders BEFORE (above) the raw palette strip.
      final Rect hero =
          tester.getRect(find.byKey(SneakerResultScreen.heroBandKey));
      final Rect strip =
          tester.getRect(find.byKey(SneakerResultScreen.paletteStripKey));
      expect(hero.top, lessThan(strip.top));
      expect(hero.height, 150); // spec §5 band height

      // Micro-labels kept (D27-Q3); dark combo → the neutral pop is crema.
      expect(find.text('TUS ZAPAS'), findsOneWidget);
      expect(find.text('TU ROPA'), findsOneWidget);
      expect(find.text('+ CREMA'), findsOneWidget);

      // Caption names the colors (ES naming: teal → "verde-azulado").
      expect(
        find.textContaining(
            'El verde-azulado hace saltar el rojo de tus zapas.'),
        findsOneWidget,
      );
      expect(find.textContaining('Súmale crema o negro y vas fino.'),
          findsOneWidget);

      // Demoted palette: BASE badge (D5) + description.
      expect(find.text('BASE · ROJO'), findsOneWidget);
      expect(find.textContaining('El rojo manda la combi.'), findsOneWidget);
    });

    testWidgets(
        '"Otras combis": the 3 remaining schemes, relabelled — the '
        'complementary hero is not repeated', (WidgetTester tester) async {
      await _pumpToResult(tester, const _FixedEngine(_kicksResult));

      expect(find.text('Otras combis'), findsOneWidget);
      expect(find.text('Tono sobre tono'), findsOneWidget);
      expect(find.text('Cálidos, suave'), findsOneWidget);
      expect(find.text('Equilibrada'), findsOneWidget);
      expect(find.text('3 colores, atrevida'), findsOneWidget);
      expect(find.text('Contraste con matiz'), findsOneWidget);
      expect(find.text('Punch, más fino'), findsOneWidget);
      // Engine scheme names never surface, and no 4th (complementary) row.
      expect(find.text('Complementario'), findsNothing);
      expect(find.text('Análogo'), findsNothing);
    });

    testWidgets(
        'D37 CTA stack: "Enséñame otros piketes" pill, then "Súbela a tu '
        'story" as the SECONDARY pill (outfit slot), then "Otras zapas" as a '
        '44 px text button 4 below; still NO save UI (D27-Q4)',
        (WidgetTester tester) async {
      await _pumpToResult(tester, const _FixedEngine(_kicksResult));

      final Rect looks = tester.getRect(find.ancestor(
          of: find.text('Enséñame otros piketes'),
          matching: find.byType(FilledButton)));
      final Rect story = tester.getRect(find.ancestor(
          of: find.text('Súbela a tu story'),
          matching: find.byType(OutlinedButton)));
      final Finder otherBtn = find.ancestor(
          of: find.text('Otras zapas'), matching: find.byType(TextButton));
      expect(otherBtn, findsOneWidget, reason: 'a text button, not a pill');
      final Rect other = tester.getRect(otherBtn);

      expect(story.top - looks.bottom, 12, reason: 'Space.md between pills');
      expect(story.height, 56);
      expect(other.top - story.bottom, 4, reason: 'text button 4 below');
      expect(other.height, 44, reason: 'touch target');
      expect(other.width, story.width, reason: 'full width, label centred');
      expect(
          find.ancestor(
              of: find.text('Otras zapas'),
              matching: find.byType(OutlinedButton)),
          findsNothing);
      // Nothing save-shaped, no outfit CTA leaks in.
      expect(find.text('Ver looks así'), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    });

    testWidgets(
        'capture-source hand-off (D37 §5.3): "Casa o calle" reaches the '
        'result as the user\'s own photo', (WidgetTester tester) async {
      await _pumpToResult(tester, const _FixedEngine(_kicksResult));
      final SneakerResultScreen screen =
          tester.widget<SneakerResultScreen>(find.byType(SneakerResultScreen));
      expect(screen.args.situation, SneakerTipCase.casa);
      expect(screen.args.situation!.isThirdPartyImage, isFalse);
    });

    testWidgets(
        'capture-source hand-off (D37 §5.3): "Captura de pantalla" reaches '
        'the result as the third-party one', (WidgetTester tester) async {
      await _pumpToResult(tester, const _FixedEngine(_kicksResult),
          card: 'Captura de pantalla', tipCta: 'Elegir la captura');
      final SneakerResultScreen screen =
          tester.widget<SneakerResultScreen>(find.byType(SneakerResultScreen));
      expect(screen.args.situation, SneakerTipCase.web);
      expect(screen.args.situation!.isThirdPartyImage, isTrue);
      expect(screen.args.photo, isNotEmpty);
    });

    testWidgets(
        'a shop screenshot opens the story preview with "Incluir mi foto" OFF '
        'even when the remembered choice is ON', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{StoryPreferencesPrefs.key: true});
      await _pumpToResult(tester, const _FixedEngine(_kicksResult),
          card: 'Captura de pantalla', tipCta: 'Elegir la captura');
      await tester.ensureVisible(find.text('Súbela a tu story'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Súbela a tu story'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await _settleSheet(tester);
    });

    testWidgets('a camera photo opens the story preview ON (the default)',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _pumpToResult(tester, const _FixedEngine(_kicksResult));
      await tester.ensureVisible(find.text('Súbela a tu story'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Súbela a tu story'));
      await tester.pumpAndSettle();
      await _settleSheet(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('"Otras zapas" → fresh capture with the #83 selector open',
        (WidgetTester tester) async {
      await _pumpToResult(tester, const _FixedEngine(_kicksResult));

      await tester.ensureVisible(find.text('Otras zapas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otras zapas'));
      await tester.pumpAndSettle();

      // Sneaker retake opens the #83 selector (it replaced the source sheet).
      // The confirm-with-old-photo fallback is still in the stack, just covered
      // by the opaque selector (skipOffstage: false to see it underneath).
      expect(find.text('¿Desde dónde haces la foto?'), findsOneWidget);
      expect(find.text('¿Se ven bien tus zapas?', skipOffstage: false),
          findsOneWidget);
    });

    testWidgets(
        'canvas mode (D10): neutral kicks → curated pops as hero, '
        'canvas copy, no "Otras combis"', (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics =
          await _pumpToResult(tester, const _FixedEngine(_canvasResult));

      // Hero slot: the accents strip replaces the combo band.
      expect(find.byKey(SneakerResultScreen.canvasAccentsKey), findsOneWidget);
      expect(find.byKey(SneakerResultScreen.heroBandKey), findsNothing);
      expect(find.text('LA COMBI · LIENZO'), findsOneWidget);
      expect(
          find.textContaining('Zapas neutras = lienzo total.'), findsOneWidget);

      // Secondary strip renders as usual; the base is the dominant NEUTRAL.
      expect(find.byKey(SneakerResultScreen.paletteStripKey), findsOneWidget);
      expect(find.text('BASE · GRIS'), findsOneWidget);

      // No chromatic base → no harmonies section; CTAs unchanged.
      expect(find.text('Otras combis'), findsNothing);
      expect(find.text('Enséñame otros piketes'), findsOneWidget);
      expect(find.text('Otras zapas'), findsOneWidget);

      // The analytics event reports canvas mode.
      final AnalyticsEvent event =
          analytics.named(AnalyticsEvents.sneakerAnalysisCompleted).single;
      expect(event.params['canvas'], true);
    });
  });

  group('Sneaker error state (spec §5, states)', () {
    testWidgets(
        'analysis failed → sneaker copy, ONE exit CTA back to capture '
        'with the sheet open', (WidgetTester tester) async {
      await _pumpToConfirm(tester, _FailingEngine());
      await _tapDameLaCombi(tester);
      // Errors never wait the #55 window: only the route transition settles
      // (the confirm screen below goes offstage — it shares the "Otra foto"
      // string with this state's single CTA).
      await tester.pumpAndSettle();

      // Sneaker error copy.
      expect(find.text('No hemos pillado los colores'), findsOneWidget);
      expect(
          find.text('Prueba con más luz o con un fondo liso.'), findsOneWidget);
      expect(find.text('Otra foto'), findsOneWidget);
      // Single exit: no secondary CTA at all (outlined button absent).
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Reintentar con la misma'), findsNothing);

      await tester.tap(find.text('Otra foto'));
      await tester.pumpAndSettle();
      // Retake opens the #83 selector (replaced the source sheet); the confirm
      // fallback is underneath, covered by the opaque selector.
      expect(find.text('¿Desde dónde haces la foto?'), findsOneWidget);
      expect(find.text('¿Se ven bien tus zapas?', skipOffstage: false),
          findsOneWidget);
    });
  });
}
