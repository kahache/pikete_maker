import 'dart:typed_data';
import 'dart:ui' as ui;

import 'harmony.dart';
import 'models.dart';
import 'palette.dart';

/// Per-garment analysis layer (Phase 2.5) — Dart port of
/// `cv_core/src/colorlab/pipeline.py::analyze_garments` (issue #89, the
/// canonical reference with tests; parity pinned by the golden fixtures in
/// `test/core/fixtures/garment_analysis_F25.json`).
///
/// With a segmentation mask, attribution is solved by construction:
/// background, skin and hair pixels are never sampled (the #56 error
/// buckets), so the person-specific heuristics of the whole-photo path are
/// all retired here. The analysis becomes PER GARMENT (upper/lower, D21):
/// one small K-means palette per region, then ONE combined outfit palette and
/// ONE global base across garments (decision #6 lifted to the outfit level —
/// the UX contract renders exactly one recommendation set, U1).

/// Palette size PER GARMENT (GARMENT_COLORS in pipeline.py): a garment is
/// usually 1-2 colors plus shading; 3 keeps a two-tone garment plus one
/// genuine accent without fragmenting a solid garment into swatch noise the
/// way the whole-photo 5 would.
const int kGarmentColors = 3;

/// UI descriptions per scheme (same texts as the canonical mockup
/// `docs/design/mockups/result.html`). The name must match the keys of the
/// harmonies dict (harmony.py). Shared by the whole-photo `buildResult` and
/// the per-garment composition below.
const List<(HarmonyType, String, String)> kUiSchemes =
    <(HarmonyType, String, String)>[
  (HarmonyType.complementary, 'Complementario', 'Contraste máximo, 2 colores'),
  (HarmonyType.analogous, 'Análogo', 'Suave, tono sobre tono'),
  (HarmonyType.triadic, 'Triádico', 'Equilibrado, 3 colores'),
  (
    HarmonyType.splitComplementary,
    'Complementario dividido',
    'Contraste con matiz'
  ),
];

/// One garment region's pixel input to [buildGarmentAnalysis]. Plain fields
/// only (Float64List + enum + double) so the whole list is isolate-sendable.
class GarmentPixels {
  /// Creates the pixel input of one garment [region].
  const GarmentPixels({
    required this.region,
    required this.pixels,
    required this.pixelFraction,
  });

  /// Which garment region these pixels belong to.
  final GarmentRegion region;

  /// Flattened RGB `[n*3]` of this garment's (eroded) mask pixels — the same
  /// shape `dominantColors` consumes.
  final Float64List pixels;

  /// The garment's share of the FRAME (eroded mask pixels / frame pixels,
  /// `pixel_fraction` in pipeline.py): scales its weights in the combined
  /// palette so cross-garment weights are comparable (spec §6 contract #1).
  final double pixelFraction;
}

/// Assembles an [AnalysisResult] from an already-extracted palette: base →
/// harmonies (or canvas accents, D10) → samples. This is the tail every
/// composition shares — the whole-photo `buildResult` and the per-garment
/// [buildGarmentAnalysis] produce byte-identical harmonies/canvas structures
/// because they both end here.
AnalysisResult composeAnalysis({
  required List<List<int>> colors,
  required List<double> weights,
  required int baseIndex,
  List<GarmentBlockData> garments = const <GarmentBlockData>[],
  List<GarmentRegion> swatchRegions = const <GarmentRegion>[],
  String? segmentationLayout,
  String? segmentationDegradeReason,
}) {
  final bool isCanvas = baseIndex < 0;
  final List<Harmony> harmonyList;
  final List<ui.Color> canvasAccents;
  if (isCanvas) {
    harmonyList = const <Harmony>[];
    canvasAccents = <ui.Color>[
      for (final List<int> rgb in kCanvasAccents) colorFromRgb(rgb),
    ];
  } else {
    final Map<String, List<List<int>>> schemes = harmonies(colors[baseIndex]);
    harmonyList = <Harmony>[
      for (final (HarmonyType, String, String) scheme in kUiSchemes)
        Harmony(
          type: scheme.$1,
          name: scheme.$2,
          description: scheme.$3,
          colors: <ui.Color>[
            for (final List<int> rgb in schemes[scheme.$2]!) colorFromRgb(rgb),
          ],
        ),
    ];
    canvasAccents = const <ui.Color>[];
  }

  return AnalysisResult(
    baseIndex: baseIndex,
    palette: <ColorSample>[
      for (int i = 0; i < colors.length; i++)
        ColorSample(color: colorFromRgb(colors[i]), weight: weights[i]),
    ],
    harmonies: harmonyList,
    canvasAccents: canvasAccents,
    garments: garments,
    swatchRegions: swatchRegions,
    segmentationLayout: segmentationLayout,
    segmentationDegradeReason: segmentationDegradeReason,
  );
}

/// Opaque [ui.Color] from an `[r, g, b]` triple.
ui.Color colorFromRgb(List<int> rgb) =>
    ui.Color.fromARGB(0xFF, rgb[0], rgb[1], rgb[2]);

/// First index of the maximum weight — matches numpy's `argmax` tie-breaking
/// (the EARLIEST max wins; strict `>` never replaces on a tie). `dominantColors`
/// returns weights in descending order so this is normally 0, but it is computed
/// explicitly to mirror Python's `int(np.argmax(weights))` semantics exactly
/// (bug B-G25-1 per-garment display base).
int _argmaxWeight(List<double> weights) {
  int best = 0;
  for (int i = 1; i < weights.length; i++) {
    if (weights[i] > weights[best]) {
      best = i;
    }
  }
  return best;
}

/// Pure per-garment pipeline: region pixels → [AnalysisResult] with garment
/// blocks (runs inside the isolate; 1:1 port of `analyze_garments`).
///
/// [regions] must be non-empty and in region order (upper first — the order
/// `split_garment_masks` emits). Steps, mirroring pipeline.py:
///
///  1. per garment: `dominantColors` over the garment's pixels only
///     ([kGarmentColors]) + the per-garment D5 base (`-1` = fully neutral
///     garment, the U7 caption signal);
///  2. combined outfit palette: per-garment palettes CONCATENATED with each
///     weight scaled by its garment's pixel share, sorted by descending
///     weight (deliberately NOT re-merged across garments so every swatch
///     keeps its attribution — the [GarmentBlockData] mapping is the Dart
///     shape of Python's `swatch_regions`);
///  3. global base across garments = `pickHarmonyBase` on the combined
///     palette (decision #6 at the outfit level; -1 ⇒ canvas mode D10, and
///     harmonies come from the global base otherwise — ONE set, U1).
///
/// A single surviving region ⇒ layout `single` with degrade reason
/// `region_too_small` (the min-region guard is the only path that gets here
/// with one region — spec §4 state S3).
AnalysisResult buildGarmentAnalysis(List<GarmentPixels> regions) {
  assert(regions.isNotEmpty, 'buildGarmentAnalysis needs >= 1 region');

  // 1. Per-garment palettes + per-garment DISPLAY base.
  final List<DominantPalette> palettes = <DominantPalette>[];
  final List<int> garmentBases = <int>[];
  for (final GarmentPixels region in regions) {
    final DominantPalette palette =
        dominantColors(region.pixels, k: kGarmentColors);
    palettes.add(palette);
    // Per-garment DISPLAY base (person path, bug B-G25-1, 2026-07-18): the
    // ARRIBA/ABAJO block labels "your top is X", so it shows the garment's OWN
    // dominant colour (max weight), NOT the most-chromatic swatch — a small
    // cross-garment/skin contaminant was hijacking the block's base (grey top +
    // red pants bleed -> block showed red; gate G2.5 FAIL->PASS). Rule #6 (most
    // chromatic) is for HARMONY generation and stays on the COMBINED outfit base
    // (step 3). BUT preserve the all-neutral canvas signal: when the garment has
    // NO chromatic colour, pickHarmonyBase returns -1 -> keep -1 (drives the U7
    // "neutro — combina con todo" caption / canvas). Mirrors the canonical
    // `harm if harm < 0 else int(np.argmax(weights))` in pipeline.py
    // analyze_garments (numpy argmax = FIRST max). Sneaker/product mode is a
    // separate path and keeps rule #6 untouched.
    final int harm = pickHarmonyBase(palette.colors, palette.weights);
    garmentBases.add(harm < 0 ? harm : _argmaxWeight(palette.weights));
  }

  // 2. Combined outfit palette: concat, scaling each garment's weights by its
  // pixel share so the weights are comparable across garments.
  double totalFraction = 0;
  for (final GarmentPixels region in regions) {
    totalFraction += region.pixelFraction;
  }
  final List<List<int>> allColors = <List<int>>[];
  final List<double> allWeights = <double>[];
  // owners[i] = (region index, index within that garment's palette).
  final List<(int, int)> owners = <(int, int)>[];
  for (int r = 0; r < regions.length; r++) {
    final double share = regions[r].pixelFraction / totalFraction;
    for (int i = 0; i < palettes[r].colors.length; i++) {
      allColors.add(palettes[r].colors[i]);
      allWeights.add(palettes[r].weights[i] * share);
      owners.add((r, i));
    }
  }
  final List<int> order = List<int>.generate(allColors.length, (int i) => i);
  order.sort((int a, int b) {
    final int byWeight = allWeights[b].compareTo(allWeights[a]);
    return byWeight != 0 ? byWeight : a.compareTo(b); // deterministic ties
  });
  final List<List<int>> colors = <List<int>>[
    for (final int i in order) allColors[i],
  ];
  final List<double> weights = <double>[
    for (final int i in order) allWeights[i]
  ];
  final List<(int, int)> sortedOwners = <(int, int)>[
    for (final int i in order) owners[i],
  ];

  // 3. Global base ACROSS garments (decision #6 lifted to the outfit level).
  final int baseIndex = pickHarmonyBase(colors, weights);
  int baseRegionIndex = -1;
  int baseIndexWithinGarment = -1;
  if (baseIndex >= 0) {
    (baseRegionIndex, baseIndexWithinGarment) = sortedOwners[baseIndex];
  }

  final List<GarmentBlockData> blocks = <GarmentBlockData>[
    for (int r = 0; r < regions.length; r++)
      GarmentBlockData(
        region: regions[r].region,
        palette: <ColorSample>[
          for (int i = 0; i < palettes[r].colors.length; i++)
            ColorSample(
              color: colorFromRgb(palettes[r].colors[i]),
              weight: palettes[r].weights[i],
            ),
        ],
        baseIndex: garmentBases[r],
        globalBaseIndex: r == baseRegionIndex ? baseIndexWithinGarment : -1,
      ),
  ];

  final bool single = regions.length == 1;
  return composeAnalysis(
    colors: colors,
    weights: weights,
    baseIndex: baseIndex,
    garments: blocks,
    swatchRegions: <GarmentRegion>[
      for (final (int, int) owner in sortedOwners) regions[owner.$1].region,
    ],
    segmentationLayout:
        single ? SegmentationLayouts.single : SegmentationLayouts.garments,
    segmentationDegradeReason:
        single ? SegmentationDegradeReasons.regionTooSmall : null,
  );
}
