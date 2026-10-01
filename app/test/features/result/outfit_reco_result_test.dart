import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/looks_search.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/theme/app_colors.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// D36 recommendation-first OUTFIT result (2026-07-23): on the segmented path
/// (`segmentationLayout` set) the hero combo (complementary) leads, the
/// extracted palette demotes to the "tu fit" strip, "Otras combis" carries the
/// 3 remaining schemes in the SNEAKER slang, and both CTAs (F5 "Ver looks así"
/// + F6 "Súbela a tu story") are kept. The legacy null-layout path (radio, the
/// technical harmony names) is pinned separately in looks_selection_test.

const Color _red = Color(0xFFE02020); // 'rojo'
const Color _teal = Color(0xFF20B2A2); // 'verde-azulado'
const Color _cobalt = Color(0xFF2B5CE4); // 'azul'
const Color _emerald = Color(0xFF12A150); // 'verde'
const Color _mustard = Color(0xFFE0A000); // 'naranja'
const Color _raspberry = Color(0xFFD6248C); // 'rosa'
const Color _gray = Color(0xFF808080);

const List<Harmony> _schemes = <Harmony>[
  Harmony(
    type: HarmonyType.complementary,
    name: 'Complementario',
    description: 'Contraste máximo, 2 colores',
    colors: <Color>[_red, _teal],
  ),
  Harmony(
    type: HarmonyType.analogous,
    name: 'Análogo',
    description: 'Vecinos de rueda, suave',
    colors: <Color>[_red, _mustard, _raspberry],
  ),
  Harmony(
    type: HarmonyType.triadic,
    name: 'Triádico',
    description: '3 colores, atrevida',
    colors: <Color>[_red, _cobalt, _emerald],
  ),
  Harmony(
    type: HarmonyType.splitComplementary,
    name: 'Complementario dividido',
    description: 'Contraste con matiz',
    colors: <Color>[_red, _cobalt, _mustard],
  ),
];

/// Chromatic outfit, two garments, LOWER owns the base — layout `garments`.
const AnalysisResult _reco = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _red, weight: 0.6),
    ColorSample(color: _gray, weight: 0.4),
  ],
  swatchRegions: <GarmentRegion>[GarmentRegion.lower, GarmentRegion.upper],
  harmonies: _schemes,
  garments: <GarmentBlockData>[
    GarmentBlockData(
      region: GarmentRegion.upper,
      palette: <ColorSample>[ColorSample(color: _gray, weight: 1.0)],
      baseIndex: -1,
      globalBaseIndex: -1,
    ),
    GarmentBlockData(
      region: GarmentRegion.lower,
      palette: <ColorSample>[ColorSample(color: _red, weight: 1.0)],
      baseIndex: 0,
      globalBaseIndex: 0,
    ),
  ],
  segmentationLayout: SegmentationLayouts.garments,
);

Future<void> _pump(
  WidgetTester tester, {
  InMemoryAnalyticsService? analytics,
  LooksSearchLauncher? launcher,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: ResultScreen(
      result: _reco,
      analytics: analytics,
      launchSearch: launcher ?? (Uri url) async => true,
    ),
  ));
  await tester.pumpAndSettle();
}

Color _nameInk(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapCta(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Ver looks así'));
  await tester.tap(find.text('Ver looks así'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hero is the protagonist: kicker, role tags, slang caption',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.text('Toma tu pikete'), findsOneWidget);
    expect(find.text('LA COMBI · CONTRASTE'), findsOneWidget);
    // Inverted hierarchy: the hero band is above the demoted strip.
    final Rect hero = tester.getRect(find.byKey(ResultScreen.heroBandKey));
    final Rect strip = tester.getRect(find.byKey(ResultScreen.fitStripKey));
    expect(hero.top, lessThan(strip.top));
    // Imperative role tags; dark combo → the neutral pop is crema.
    expect(find.text('TU FIT'), findsOneWidget);
    expect(find.text('SÚMALE'), findsOneWidget);
    expect(find.text('+ CREMA'), findsOneWidget);
    // Slang caption names the colors (verde-azulado + rojo).
    expect(
      find.textContaining('El verde-azulado hace saltar el rojo de tu fit.'),
      findsOneWidget,
    );
    expect(find.textContaining('Súmale crema o negro y vas fino.'),
        findsOneWidget);
    // Both CTAs kept (outfit IS the shareable object, Principle 3).
    expect(find.text('Ver looks así'), findsOneWidget);
    expect(find.text('Súbela a tu story'), findsOneWidget);
  });

  testWidgets('"Otras combis": 3 remaining schemes in sneaker slang',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.text('Otras combis'), findsOneWidget);
    expect(find.text('Tono sobre tono'), findsOneWidget);
    expect(find.text('Equilibrada'), findsOneWidget);
    expect(find.text('Contraste con matiz'), findsOneWidget);
    // The complementary hero is not repeated; technical names never surface.
    expect(find.text('Complementario'), findsNothing);
    expect(find.text('Análogo'), findsNothing);
    expect(find.text('Triádico'), findsNothing);
  });

  testWidgets('default CTA deep-links the hero combo (base + complement + crema)',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uri> launched = <Uri>[];
    await _pump(tester, analytics: analytics, launcher: (Uri url) async {
      launched.add(url);
      return true;
    });

    await _tapCta(tester);

    expect(launched.single.queryParameters['q'],
        'outfit rojo, verde azulado y crema');
    final AnalyticsEvent event =
        analytics.named(AnalyticsEvents.looksSearchLaunched).single;
    expect(event.params, <String, Object?>{
      'mode': 'outfit',
      'scheme': 'complementary',
      'query': 'outfit rojo, verde azulado y crema',
    });
  });

  testWidgets('tapping "Otras combis" toggles the selection and the CTA target',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uri> launched = <Uri>[];
    await _pump(tester, analytics: analytics, launcher: (Uri url) async {
      launched.add(url);
      return true;
    });

    // Select the triadic ("Equilibrada"): selected = action-fill white text.
    await _tapRow(tester, 'Equilibrada');
    expect(_nameInk(tester, 'Equilibrada'), AppColors.light.actionOnFill);
    expect(
      analytics.named(AnalyticsEvents.harmonySelected).single.params,
      <String, Object?>{'mode': 'outfit', 'scheme': 'triadic'},
    );

    await _tapCta(tester);
    expect(launched.single.queryParameters['q'], 'outfit rojo, azul y verde');

    // Re-tap deselects → back to the hero combo (default query).
    await _tapRow(tester, 'Equilibrada');
    expect(_nameInk(tester, 'Equilibrada'), AppColors.light.textPrimary);
    expect(
      analytics.named(AnalyticsEvents.harmonySelected).last.params['scheme'],
      'complementary',
    );
    await _tapCta(tester);
    expect(launched.last.queryParameters['q'],
        'outfit rojo, verde azulado y crema');
  });

  testWidgets('offline/no-browser: SnackBar, no crash, no launch event',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, analytics: analytics, launcher: (Uri url) async => false);

    await _tapCta(tester);

    expect(find.text(kLooksSearchFailedCopy), findsOneWidget);
    expect(analytics.fired(AnalyticsEvents.looksSearchLaunched), isFalse);
  });
}
