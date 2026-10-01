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

/// Per-garment result screen (Phase 2.5, #88) under the D36 recommendation-first
/// hierarchy (2026-07-23): the segmented states (S1-S4), the silent-degrade rule
/// (U4, forbidden copy), the legacy whole-photo pin (null layout keeps today's
/// "Tu paleta" screen byte-identical) and the §6 telemetry. The presentation is
/// now recommendation-first (hero combo above the demoted "tu fit" strip); the
/// engine contract (layouts, degrade reasons, base attribution) is unchanged.

const Color _green = Color(0xFF7E9C7B);
const Color _greenDark = Color(0xFF55704F);
const Color _purple = Color(0xFF9B59D0);
const Color _red = Color(0xFFD0342C);
const Color _black = Color(0xFF232128);
const Color _gray = Color(0xFF6B6A75);
const Color _white = Color(0xFFEEEEEE);

/// The full 4-scheme set the engine emits (#89). The hero uses the
/// complementary; "Otras combis" shows the 3 remaining (D36).
const List<Harmony> _schemes = <Harmony>[
  Harmony(
    type: HarmonyType.complementary,
    name: 'Complementario',
    description: 'Contraste máximo, 2 colores',
    colors: <Color>[_purple, Color(0xFF8ED059)],
  ),
  Harmony(
    type: HarmonyType.analogous,
    name: 'Análogo',
    description: 'Suave, tono sobre tono',
    colors: <Color>[_purple, Color(0xFFD059C4), Color(0xFF5965D0)],
  ),
  Harmony(
    type: HarmonyType.triadic,
    name: 'Triádico',
    description: 'Equilibrado, 3 colores',
    colors: <Color>[_purple, Color(0xFFD09B59), Color(0xFF59D09B)],
  ),
  Harmony(
    type: HarmonyType.splitComplementary,
    name: 'Complementario dividido',
    description: 'Contraste con matiz',
    colors: <Color>[_purple, Color(0xFFA6D059), Color(0xFF59D065)],
  ),
];

/// S1 · two garments, the LOWER owns the global base (the mockup's frame 1).
const AnalysisResult _s1 = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _purple, weight: 0.55),
    ColorSample(color: _green, weight: 0.30),
    ColorSample(color: _greenDark, weight: 0.15),
  ],
  swatchRegions: <GarmentRegion>[
    GarmentRegion.lower,
    GarmentRegion.upper,
    GarmentRegion.upper,
  ],
  harmonies: _schemes,
  garments: <GarmentBlockData>[
    GarmentBlockData(
      region: GarmentRegion.upper,
      palette: <ColorSample>[
        ColorSample(color: _green, weight: 0.67),
        ColorSample(color: _greenDark, weight: 0.33),
      ],
      baseIndex: 0,
      globalBaseIndex: -1,
    ),
    GarmentBlockData(
      region: GarmentRegion.lower,
      palette: <ColorSample>[ColorSample(color: _purple, weight: 1.0)],
      baseIndex: 0,
      globalBaseIndex: 0,
    ),
  ],
  segmentationLayout: SegmentationLayouts.garments,
);

/// S1 variant · the lower garment is fully NEUTRAL, the global base lives in
/// the upper garment (the mockup's frame 2).
const AnalysisResult _s1Neutral = AnalysisResult(
  baseIndex: 1,
  palette: <ColorSample>[
    ColorSample(color: _black, weight: 0.51),
    ColorSample(color: _red, weight: 0.49),
  ],
  swatchRegions: <GarmentRegion>[GarmentRegion.lower, GarmentRegion.upper],
  harmonies: _schemes,
  garments: <GarmentBlockData>[
    GarmentBlockData(
      region: GarmentRegion.upper,
      palette: <ColorSample>[ColorSample(color: _red, weight: 1.0)],
      baseIndex: 0,
      globalBaseIndex: 0,
    ),
    GarmentBlockData(
      region: GarmentRegion.lower,
      palette: <ColorSample>[
        ColorSample(color: _black, weight: 0.72),
        ColorSample(color: _gray, weight: 0.28),
      ],
      baseIndex: -1, // fully neutral garment
      globalBaseIndex: -1,
    ),
  ],
  segmentationLayout: SegmentationLayouts.garments,
);

/// S2 · both garments neutral → global canvas mode (D10).
const AnalysisResult _s2Canvas = AnalysisResult(
  baseIndex: -1,
  palette: <ColorSample>[
    ColorSample(color: _white, weight: 0.51),
    ColorSample(color: _black, weight: 0.49),
  ],
  swatchRegions: <GarmentRegion>[GarmentRegion.lower, GarmentRegion.upper],
  harmonies: <Harmony>[],
  canvasAccents: <Color>[
    Color(0xFFE4322B),
    Color(0xFF2B5CE4),
    Color(0xFFE0A000),
    Color(0xFF12A150),
    Color(0xFFD6248C),
  ],
  garments: <GarmentBlockData>[
    GarmentBlockData(
      region: GarmentRegion.upper,
      palette: <ColorSample>[ColorSample(color: _black, weight: 1.0)],
      baseIndex: -1,
      globalBaseIndex: -1,
    ),
    GarmentBlockData(
      region: GarmentRegion.lower,
      palette: <ColorSample>[ColorSample(color: _white, weight: 1.0)],
      baseIndex: -1,
      globalBaseIndex: -1,
    ),
  ],
  segmentationLayout: SegmentationLayouts.garments,
);

/// S3 · a single region survived the min-region guard.
const AnalysisResult _s3Single = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _red, weight: 0.8),
    ColorSample(color: _gray, weight: 0.2),
  ],
  swatchRegions: <GarmentRegion>[GarmentRegion.upper, GarmentRegion.upper],
  harmonies: _schemes,
  garments: <GarmentBlockData>[
    GarmentBlockData(
      region: GarmentRegion.upper,
      palette: <ColorSample>[
        ColorSample(color: _red, weight: 0.8),
        ColorSample(color: _gray, weight: 0.2),
      ],
      baseIndex: 0,
      globalBaseIndex: 0,
    ),
  ],
  segmentationLayout: SegmentationLayouts.single,
  segmentationDegradeReason: SegmentationDegradeReasons.regionTooSmall,
);

/// S4 · whole-photo degrade: the segmented flow fell back to today's pipeline
/// — NO garment blocks, layout `whole`, reason tagged. Still recommendation-
/// first (D36 §4): the demoted strip is a single UNLABELED row.
const AnalysisResult _s4Whole = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _red, weight: 0.7),
    ColorSample(color: _gray, weight: 0.3),
  ],
  harmonies: _schemes,
  segmentationLayout: SegmentationLayouts.whole,
  segmentationDegradeReason: SegmentationDegradeReasons.noPerson,
);

/// Legacy result (flag off / whole-photo safety fallback): no segmentation
/// metadata at all → today's extraction-led "Tu paleta" screen.
const AnalysisResult _legacy = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _red, weight: 0.7),
    ColorSample(color: _gray, weight: 0.3),
  ],
  harmonies: _schemes,
);

Future<void> _pump(WidgetTester tester, AnalysisResult result,
    {InMemoryAnalyticsService? analytics}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: ResultScreen(
      result: result,
      analytics: analytics,
      launchSearch: (Uri url) async => true,
    ),
  ));
  await tester.pumpAndSettle();
}

/// U4 forbidden copy (spec §5): no state may ever show error language,
/// garment-type names or confidence figures.
void _expectNoForbiddenCopy() {
  for (final String forbidden in <String>[
    'No pudimos separar tu ropa',
    'Análisis parcial',
    'Modo básico',
    'camiseta',
    'pantalón',
  ]) {
    expect(find.textContaining(forbidden), findsNothing,
        reason: 'forbidden copy "$forbidden" must never render (U4)');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S1 · two garments (happy path, D36 reco-first)', () {
    testWidgets(
        'recommendation is the protagonist: hero band ABOVE the demoted '
        '"tu fit" strip, region labels kept', (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await _pump(tester, _s1, analytics: analytics);

      // D36: the headline sells the recommendation, not the extraction.
      expect(find.text('Toma tu pikete'), findsOneWidget);
      expect(find.text('Tu pikete'), findsNothing);
      expect(find.text('Tu paleta'), findsNothing);
      // Hero kicker (label style = uppercase on text).
      expect(find.text('LA COMBI · CONTRASTE'), findsOneWidget);
      // Inverted hierarchy: hero band renders ABOVE the demoted strip.
      final Rect hero =
          tester.getRect(find.byKey(ResultScreen.heroBandKey));
      final Rect strip =
          tester.getRect(find.byKey(ResultScreen.fitStripKey));
      expect(hero.top, lessThan(strip.top));
      // Imperative role tags (recommendation, not extraction).
      expect(find.text('TU FIT'), findsOneWidget);
      expect(find.text('SÚMALE'), findsOneWidget);
      // Demoted strip label + region labels kept (U2), small; no big per-garment
      // blocks (the old GarmentBlock widget was removed, r13 A6), no per-swatch
      // hex index anymore.
      expect(find.text('TU FIT · DE AQUÍ SALE LA COMBI'), findsOneWidget);
      expect(find.text('ARRIBA'), findsOneWidget);
      expect(find.text('ABAJO'), findsOneWidget);
      expect(find.text('TU ROPA'), findsNothing);
      expect(find.text('#9B59D0'), findsNothing);
      // U3: the base line carries the attribution sentence (base in ABAJO).
      expect(find.textContaining('Sale de tu parte de abajo.'), findsOneWidget);
      expect(find.textContaining('Tu color dominante.'), findsOneWidget);
      // D36: "Otras combis" (never "Combina con"); the complementary hero is
      // not repeated as a row.
      expect(find.text('Otras combis'), findsOneWidget);
      expect(find.text('Combina con'), findsNothing);
      expect(find.text('Complementario'), findsNothing);
      _expectNoForbiddenCopy();
      // §6 telemetry: result_viewed tagged with the layout.
      final AnalyticsEvent viewed =
          analytics.named(AnalyticsEvents.resultViewed).single;
      expect(viewed.params['layout'], SegmentationLayouts.garments);
    });

    testWidgets('a neutral garment: attribution points at the chromatic owner',
        (WidgetTester tester) async {
      await _pump(tester, _s1Neutral);
      // Attribution points at the chromatic owner (upper).
      expect(
          find.textContaining('Sale de tu parte de arriba.'), findsOneWidget);
      // D36 simplification: the demoted strip drops the per-garment neutral
      // caption (it lives on the legacy per-block layout only).
      expect(find.text('neutro — combina con todo'), findsNothing);
      _expectNoForbiddenCopy();
    });
  });

  testWidgets('S2 · both garments neutral → canvas hero, pops promoted',
      (WidgetTester tester) async {
    await _pump(tester, _s2Canvas);
    // Canvas headline + kicker; the curated pops ARE the hero.
    expect(find.text('Tu fit pide color'), findsOneWidget);
    expect(find.text('LA COMBI · LIENZO'), findsOneWidget);
    expect(find.byKey(ResultScreen.canvasAccentsKey), findsOneWidget);
    expect(find.byKey(ResultScreen.heroBandKey), findsNothing);
    // Demoted neutral strip + its honest caption; no chromatic base badge.
    expect(find.text('TU FIT · TU LIENZO NEUTRO'), findsOneWidget);
    expect(
        find.textContaining('Por eso mandamos color, no armonías.'),
        findsOneWidget);
    expect(find.textContaining('Tu color dominante.'), findsNothing);
    // No harmonies section; the legacy "lienzo" headline never surfaces here.
    expect(find.text('Otras combis'), findsNothing);
    expect(find.text('Combina con'), findsNothing);
    expect(find.text('Tu look es un lienzo'), findsNothing);
    _expectNoForbiddenCopy();
  });

  testWidgets('S3 · single region is "TU ROPA", today\'s base copy verbatim',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _s3Single, analytics: analytics);
    expect(find.text('Toma tu pikete'), findsOneWidget);
    // U5: never advertise the missing half.
    expect(find.text('TU ROPA'), findsOneWidget);
    expect(find.text('ARRIBA'), findsNothing);
    expect(find.text('ABAJO'), findsNothing);
    // No attribution sentence — today's copy verbatim (spec §5).
    expect(find.textContaining('Sale de tu parte'), findsNothing);
    expect(find.textContaining('Tu color dominante.'), findsOneWidget);
    expect(
        find.textContaining('Todo conjunta alrededor de él.'), findsOneWidget);
    _expectNoForbiddenCopy();
    expect(
      analytics.named(AnalyticsEvents.resultViewed).single.params['layout'],
      SegmentationLayouts.single,
    );
  });

  testWidgets('S4 · whole-photo degrade: reco-first, single unlabeled strip',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _s4Whole, analytics: analytics);
    // Same reco-first tone as S1 (U4): the segmented flow leads with the combi.
    expect(find.text('Toma tu pikete'), findsOneWidget);
    expect(find.byKey(ResultScreen.heroBandKey), findsOneWidget);
    expect(find.byKey(ResultScreen.fitStripKey), findsOneWidget);
    // No blocks, no region labels (whole-photo palette, design §4).
    expect(find.text('ARRIBA'), findsNothing);
    expect(find.text('TU ROPA'), findsNothing);
    expect(find.textContaining('Sale de tu parte'), findsNothing);
    expect(find.textContaining('Tu color dominante.'), findsOneWidget);
    expect(find.text('Otras combis'), findsOneWidget);
    _expectNoForbiddenCopy();
    expect(
      analytics.named(AnalyticsEvents.resultViewed).single.params['layout'],
      SegmentationLayouts.whole,
    );
  });

  testWidgets(
      'legacy-layout pin · a result with no segmentation metadata '
      'renders today\'s extraction-led screen and the param-less event',
      (WidgetTester tester) async {
    // The render decision keys on result.segmentationLayout: a legacy result
    // (layout == null) keeps the pre-D36 "Tu paleta" screen byte-identical even
    // with the composition flag ON — the S4 whole-photo safety fallback.
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _legacy, analytics: analytics);
    expect(find.text('Tu paleta'), findsOneWidget);
    expect(find.text('Toma tu pikete'), findsNothing);
    // Legacy = extraction-led: today's "Combina con", no reco hierarchy.
    expect(find.text('Combina con'), findsOneWidget);
    expect(find.byKey(ResultScreen.heroBandKey), findsNothing);
    expect(find.byKey(ResultScreen.fitStripKey), findsNothing);
    expect(find.textContaining('Sale de tu parte'), findsNothing);
    // Legacy result_viewed: NO params (unchanged telemetry).
    final AnalyticsEvent viewed =
        analytics.named(AnalyticsEvents.resultViewed).single;
    expect(viewed.params, isEmpty);
    // The composition-root flag is ON since r10 (gate G2.5 signed 2026-07-18):
    // outfit mode runs the per-garment path by default. The legacy render above
    // holds independently of it.
    expect(kGarmentAnalysisEnabled, isTrue,
        reason:
            'gate G2.5 signed (2026-07-18): per-garment ON for the r10 beta');
  });

  group('§6 telemetry · segmentation_degraded fires in analyzing', () {
    testWidgets('a degraded result logs {reason, to}; result still lands',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await _driveToResult(tester, const _FixedEngine(_s4Whole), analytics);

      expect(find.text('Toma tu pikete'), findsOneWidget);
      final AnalyticsEvent degraded =
          analytics.named(AnalyticsEvents.segmentationDegraded).single;
      expect(degraded.params['reason'], SegmentationDegradeReasons.noPerson);
      expect(degraded.params['to'], SegmentationLayouts.whole);
      // The funnel success event still fires after the degrade.
      expect(analytics.fired(AnalyticsEvents.analysisCompleted), isTrue);
    });

    testWidgets('a clean segmented result does NOT log a degrade',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await _driveToResult(tester, const _FixedEngine(_s1), analytics);

      expect(find.text('Toma tu pikete'), findsOneWidget);
      expect(analytics.fired(AnalyticsEvents.segmentationDegraded), isFalse);
    });

    testWidgets('the legacy path never logs a degrade',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      await _driveToResult(tester, const _FixedEngine(_legacy), analytics);

      expect(find.text('Tu paleta'), findsOneWidget);
      expect(analytics.fired(AnalyticsEvents.segmentationDegraded), isFalse);
    });
  });
}

/// Valid 1×1 px PNG (same as the critical-flow tests): decodable "photo".
Uint8List _testPhoto() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

class _FakePicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => _testPhoto();
}

/// Returns a fixed result: lets the flow test any segmentation outcome.
class _FixedEngine implements ColorEngine {
  const _FixedEngine(this.result);
  final AnalysisResult result;
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async => result;
}

/// Home → gallery → Analizar → (min-display window) → result. Same drive as
/// the instrumentation suite.
Future<void> _driveToResult(WidgetTester tester, ColorEngine engine,
    InMemoryAnalyticsService analytics) async {
  final OnboardingServiceInMemory onboarding = OnboardingServiceInMemory();
  await onboarding.markSeen();
  await tester.pumpWidget(PiketeMakerApp(
    onboarding: onboarding,
    picker: _FakePicker(),
    engine: engine,
    analytics: analytics,
    crashReporter: InMemoryCrashReporter(),
  ));
  await tester.pumpAndSettle();
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
