import 'dart:math' as math;
import 'dart:typed_data';

import 'harmony.dart' show pickHarmonyBase;
import 'palette.dart' show dominantColors, srgbToLab, DominantPalette;

/// Optional border-band background model — Dart port of
/// `cv_core/src/colorlab/borders.py` (issue #48, the winning two-color
/// wall+floor model; port tracked as #49). It is the exact canonical
/// reference, with tests; the golden fixture `border_bg_D48.json` (generated
/// by `cv_core/tools/gen_border_fixtures_dart.py`) proves this port matches.
///
/// The frame is split into a WALL band (top + left + right strips) and a FLOOR
/// band (bottom strip): in full-body outfit photos the bottom edge is usually
/// floor and differs in color from the walls. Each band contributes one
/// background candidate, and only when the band is almost uniformly that color
/// (a strict coverage gate). Palette colors close to a qualified candidate are
/// then demoted from harmony-BASE eligibility — the palette itself is never
/// touched.
///
/// This layer is OPTIONAL and OFF BY DEFAULT, exactly like the Python side
/// (only `cli.py --avoid-border-bg` wires it; the default library pipeline
/// never calls it). In the app it is reachable only via
/// `ColorEngineDart(avoidBorderBackground: true)` / the optional
/// `buildResult(..., backgroundCandidates:)` argument; with the defaults the
/// MVP whole-photo flow is byte-identical.
///
/// The file also holds the second, PRODUCT-mode estimator from borders.py: the
/// multi-EDGE co-occurrence background model (issue #84) — see the section at
/// the bottom. That one runs automatically in product mode (D24) and never in
/// outfit mode.

/// Width of the border strips as a fraction of min(height, width).
/// (BORDER_BAND_FRACTION in borders.py.)
const double kBorderBandFraction = 0.04;

/// deltaE radius (attenuated L, repo convention) that counts as "the same
/// background color", used for both the band coverage measure and the palette
/// demotion. 15 is the safe edge of the evaluated plateau.
/// (BORDER_SIMILARITY_DELTA_E in borders.py.)
const double kBorderSimilarityDeltaE = 15.0;

/// Minimum fraction of a band covered by its dominant color for that color to
/// qualify as a background candidate. At 0.85 per clean band the layer only
/// acts on nearly uniform walls/floors. (BORDER_COVERAGE_MIN in borders.py.)
const double kBorderCoverageMin = 0.85;

/// Clusters used to summarize a band. 3 absorbs shadows/gradients so the
/// dominant cluster represents the actual surface color.
/// (BORDER_BAND_CLUSTERS in borders.py.)
const int kBorderBandClusters = 3;

/// Attenuation of the L term in deltaE (same convention as the palette merge
/// and the skin filter). (BORDER_LIGHTNESS_WEIGHT in borders.py.)
const double kBorderLightnessWeight = 0.5;

/// A border-band color that qualified as probable background. Mirror of the
/// `BackgroundCandidate` dataclass in borders.py.
class BackgroundCandidate {
  /// Creates a background candidate found on the [origin] border band.
  const BackgroundCandidate({
    required this.origin,
    required this.color,
    required this.coverage,
  });

  /// "wall" (top + sides) or "floor" (bottom).
  final String origin;

  /// The candidate background color, RGB 0-255.
  final List<int> color;

  /// Fraction of its band within the similarity radius.
  final double coverage;
}

/// Python's built-in `round()` / numpy rounding: round-half-to-even (banker's).
/// Used for the band thickness so the strip width matches borders.py exactly.
int _roundHalfToEven(double x) {
  final double floor = x.floorToDouble();
  final double diff = x - floor;
  if (diff < 0.5) {
    return floor.toInt();
  }
  if (diff > 0.5) {
    return floor.toInt() + 1;
  }
  // Exactly .5: round to the even neighbor.
  final int f = floor.toInt();
  return f.isEven ? f : f + 1;
}

/// deltaE-76 with attenuated L between one LAB pixel and one LAB color.
double _attenuatedDeltaELab(List<double> labPixel, List<double> labColor) {
  final double dl = (labPixel[0] - labColor[0]) * kBorderLightnessWeight;
  final double da = labPixel[1] - labColor[1];
  final double db = labPixel[2] - labColor[2];
  return math.sqrt(dl * dl + da * da + db * db);
}

/// Boolean membership (row-major, index = row * width + col) for the wall band
/// (top + sides, excluding the bottom strip rows so no floor pixel pollutes the
/// wall estimate) and the floor band (bottom strip, full width). Mirror of
/// `_band_masks` in borders.py, including the numpy iteration order (row-major)
/// so the band pixels feed K-means in the same order as the reference.
(List<bool>, List<bool>, int) _bandMasks(
    int height, int width, double bandFraction) {
  final int thickness =
      math.max(1, _roundHalfToEven(bandFraction * math.min(height, width)));
  final List<bool> wall = List<bool>.filled(height * width, false);
  final List<bool> floor = List<bool>.filled(height * width, false);
  final int sideRowLimit = height - thickness; // side strips stop above floor
  for (int r = 0; r < height; r++) {
    final bool topStrip = r < thickness;
    final bool sideRow = r < sideRowLimit;
    final bool floorRow = r >= height - thickness;
    for (int c = 0; c < width; c++) {
      final int p = r * width + c;
      if (topStrip) {
        wall[p] = true;
      } else if (sideRow && (c < thickness || c >= width - thickness)) {
        wall[p] = true;
      }
      if (floorRow) {
        floor[p] = true;
      }
    }
  }
  return (wall, floor, thickness);
}

/// Dominant band color if the band is uniform enough, else null. Mirror of
/// `_band_candidate` in borders.py.
BackgroundCandidate? _bandCandidate(
  List<int> rgb,
  List<bool> bandMask,
  String origin,
  double similarityDeltaE,
  double coverageMin,
) {
  // Collect band pixels in row-major order (same order numpy's boolean index
  // yields), flattened for K-means.
  final List<double> flat = <double>[];
  int count = 0;
  for (int p = 0; p < bandMask.length; p++) {
    if (bandMask[p]) {
      flat
        ..add(rgb[p * 3].toDouble())
        ..add(rgb[p * 3 + 1].toDouble())
        ..add(rgb[p * 3 + 2].toDouble());
      count++;
    }
  }
  if (count == 0) {
    return null;
  }
  final DominantPalette palette =
      dominantColors(Float64List.fromList(flat), k: kBorderBandClusters);
  if (palette.colors.isEmpty) {
    return null; // pathological band; borders.py would index colors[0]
  }
  final List<int> top = palette.colors[0];
  final List<double> topLab = srgbToLab(
      <double>[top[0].toDouble(), top[1].toDouble(), top[2].toDouble()]);
  int within = 0;
  for (int i = 0; i < count; i++) {
    final List<double> lab =
        srgbToLab(<double>[flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2]]);
    if (_attenuatedDeltaELab(lab, topLab) < similarityDeltaE) {
      within++;
    }
  }
  final double coverage = within / count;
  if (coverage < coverageMin) {
    return null;
  }
  return BackgroundCandidate(origin: origin, color: top, coverage: coverage);
}

/// Estimates up to two background candidates (wall, floor) from the frame.
///
/// [rgb] is a FLAT row-major RGB buffer of length `height * width * 3`
/// (r, g, b, r, g, b, ...). A busy band (coverage below [coverageMin]) yields
/// no candidate: the layer switches itself off rather than guessing (the
/// do-no-harm lesson of #29/#44). 1:1 port of `estimate_background_candidates`.
List<BackgroundCandidate> estimateBackgroundCandidates(
  List<int> rgb,
  int height,
  int width, {
  double bandFraction = kBorderBandFraction,
  double similarityDeltaE = kBorderSimilarityDeltaE,
  double coverageMin = kBorderCoverageMin,
}) {
  final (List<bool> wallMask, List<bool> floorMask, _) =
      _bandMasks(height, width, bandFraction);
  final List<BackgroundCandidate> candidates = <BackgroundCandidate>[];
  final BackgroundCandidate? wall =
      _bandCandidate(rgb, wallMask, 'wall', similarityDeltaE, coverageMin);
  if (wall != null) {
    candidates.add(wall);
  }
  final BackgroundCandidate? floor =
      _bandCandidate(rgb, floorMask, 'floor', similarityDeltaE, coverageMin);
  if (floor != null) {
    candidates.add(floor);
  }
  return candidates;
}

/// [pickHarmonyBase] with background-like colors demoted from eligibility.
///
/// Palette colors within [similarityDeltaE] of ANY qualified candidate cannot
/// lead the harmonies. The palette and its weights are never modified. Returns
/// the palette INDEX of the chosen base, or `-1` (canvas mode D10) when no
/// eligible color qualifies — this is the same index/`-1` contract as
/// [pickHarmonyBase] (the [AnalysisResult] contract works with indices).
///
/// DELIBERATE DEVIATION from `pick_harmony_base_avoiding_background` in
/// borders.py, identical in spirit to the existing `pickHarmonyBase` vs
/// `pick_harmony_base` deviation: Python returns an RGB and, when the eligible
/// survivors are all neutral, silently falls back to the eligible dominant;
/// here we return `-1` so the engine routes to canvas mode (D10). When at
/// least one eligible color is chromatic (the only scenario the layer is meant
/// to help), both agree on the same color — the golden fixture verifies it.
///
/// If no candidate qualified, or if demotion would leave nothing eligible (the
/// whole palette looks like background — more likely a monochrome outfit), the
/// baseline pick is returned unchanged.
int pickHarmonyBaseAvoidingBackground(
  List<List<int>> colors,
  List<double> weights,
  List<BackgroundCandidate> candidates, {
  double similarityDeltaE = kBorderSimilarityDeltaE,
}) {
  if (candidates.isEmpty) {
    return pickHarmonyBase(colors, weights);
  }
  final List<List<double>> labs = <List<double>>[
    for (final List<int> c in colors)
      srgbToLab(<double>[c[0].toDouble(), c[1].toDouble(), c[2].toDouble()]),
  ];
  final List<bool> backgroundLike = List<bool>.filled(colors.length, false);
  for (final BackgroundCandidate candidate in candidates) {
    final List<double> labCand = srgbToLab(<double>[
      candidate.color[0].toDouble(),
      candidate.color[1].toDouble(),
      candidate.color[2].toDouble(),
    ]);
    for (int i = 0; i < colors.length; i++) {
      if (_attenuatedDeltaELab(labs[i], labCand) < similarityDeltaE) {
        backgroundLike[i] = true;
      }
    }
  }
  if (backgroundLike.every((bool b) => b)) {
    // The whole palette matches the border: refuse to act (do-no-harm).
    return pickHarmonyBase(colors, weights);
  }
  // Run the normal base pick over the survivors, then map back to the original
  // palette index (or propagate the -1 canvas signal).
  final List<int> eligibleIndex = <int>[];
  final List<List<int>> subColors = <List<int>>[];
  final List<double> subWeights = <double>[];
  for (int i = 0; i < colors.length; i++) {
    if (!backgroundLike[i]) {
      eligibleIndex.add(i);
      subColors.add(colors[i]);
      subWeights.add(weights[i]);
    }
  }
  final int sub = pickHarmonyBase(subColors, subWeights);
  return sub < 0 ? -1 : eligibleIndex[sub];
}

// ---------------------------------------------------------------------------
// Multi-edge co-occurrence background model (issue #84, PRODUCT mode) — Dart
// port of the second estimator in borders.py. A centered product (the guided
// #83 sneaker shot) touches AT MOST 1-2 adjacent image edges; the background
// wraps 3+. A color present on >= kMultiEdgeMin distinct edges is background
// and its PIXELS are dropped before clustering (a mask, not just base
// demotion). Parity proven by the product_mode_D24.json golden fixture.
// ---------------------------------------------------------------------------

/// Thickness of each of the four edge bands, as a fraction of min(h, w). A
/// touch wider than the #48 wall/floor band (0.04): a product shot's edge is
/// more likely to carry a lighting gradient. (EDGE_BAND_FRACTION in borders.py.)
const double kEdgeBandFraction = 0.06;

/// Clusters used to summarize each edge band; 3 absorbs shadows/gradients.
/// (EDGE_BAND_CLUSTERS in borders.py.)
const int kEdgeBandClusters = 3;

/// deltaE radius (attenuated L, repo convention) at which a pixel/color counts
/// as "the same color" as an edge cluster — used both for the band coverage
/// measure and for the pixels dropped from the frame.
/// (EDGE_MATCH_DELTA_E in borders.py.)
const double kEdgeMatchDeltaE = 16.0;

/// Minimum fraction of an edge band that a candidate color must cover to count
/// as "present" on that edge. (EDGE_PRESENCE_MIN in borders.py.)
const double kEdgePresenceMin = 0.30;

/// Number of DISTINCT edges a color must be present on to be judged background
/// and hard-dropped. 3 (not 2) is the CEO's false-positive-safe threshold for
/// the GUIDED sneaker flow: the sneaker itself touches at most 1-2 adjacent
/// edges — only the surrounding floor/wall wraps 3+.
/// (MULTI_EDGE_MIN in borders.py.)
const int kMultiEdgeMin = 3;

/// Two candidate edge colors within this deltaE (attenuated L) are treated as
/// the same background color when de-duplicating.
/// (EDGE_DEDUP_DELTA_E in borders.py.)
const double kEdgeDedupDeltaE = 8.0;

/// Guardrail: if the multi-edge mask would drop MORE than this fraction of the
/// frame, the "background" is really a frame-filling subject — suppress
/// nothing and let the whole-frame palette stand.
/// (PRODUCT_BG_MAX_COVERAGE in borders.py.)
const double kProductBgMaxCoverage = 0.99;

/// Boolean membership (row-major, index = row * width + col) for the four
/// independent edge bands, in the same iteration order as borders.py's dict
/// (top, bottom, left, right). Unlike the #48 wall/floor split, the bands are
/// kept separate (and may overlap at the corners) so co-occurrence across
/// DISTINCT edges can be counted. Mirror of `_four_edge_masks`.
List<List<bool>> _fourEdgeMasks(int height, int width, double bandFraction) {
  final int thickness =
      math.max(1, _roundHalfToEven(bandFraction * math.min(height, width)));
  final List<bool> top = List<bool>.filled(height * width, false);
  final List<bool> bottom = List<bool>.filled(height * width, false);
  final List<bool> left = List<bool>.filled(height * width, false);
  final List<bool> right = List<bool>.filled(height * width, false);
  for (int r = 0; r < height; r++) {
    final bool topRow = r < thickness;
    final bool bottomRow = r >= height - thickness;
    for (int c = 0; c < width; c++) {
      final int p = r * width + c;
      if (topRow) {
        top[p] = true;
      }
      if (bottomRow) {
        bottom[p] = true;
      }
      if (c < thickness) {
        left[p] = true;
      }
      if (c >= width - thickness) {
        right[p] = true;
      }
    }
  }
  return <List<bool>>[top, bottom, left, right];
}

/// LAB pixels (row-major band order) of the band selected by [bandMask].
List<List<double>> _bandLabs(List<int> rgb, List<bool> bandMask) {
  final List<List<double>> labs = <List<double>>[];
  for (int p = 0; p < bandMask.length; p++) {
    if (bandMask[p]) {
      labs.add(srgbToLab(<double>[
        rgb[p * 3].toDouble(),
        rgb[p * 3 + 1].toDouble(),
        rgb[p * 3 + 2].toDouble(),
      ]));
    }
  }
  return labs;
}

/// Collapses near-identical colors (attenuated-L deltaE) into one each,
/// keeping first-occurrence order. Mirror of `_dedup_colors` in borders.py.
List<List<int>> _dedupColors(List<List<int>> colors, double deltaE) {
  final List<List<int>> kept = <List<int>>[];
  final List<List<double>> keptLabs = <List<double>>[];
  for (final List<int> color in colors) {
    final List<double> lab = srgbToLab(<double>[
      color[0].toDouble(),
      color[1].toDouble(),
      color[2].toDouble(),
    ]);
    bool duplicate = false;
    for (final List<double> keptLab in keptLabs) {
      if (_attenuatedDeltaELab(lab, keptLab) < deltaE) {
        duplicate = true;
        break;
      }
    }
    if (!duplicate) {
      kept.add(color);
      keptLabs.add(lab);
    }
  }
  return kept;
}

/// Colors that occur on >= [minEdges] distinct image edges (background).
///
/// [rgb] is a FLAT row-major RGB buffer of length `height * width * 3`. Each
/// of the four edge bands is summarized by K-means; every resulting candidate
/// color is then tested against ALL four bands, and a candidate is returned as
/// background when it substantially covers ([presenceMin]) at least
/// [minEdges] of them. Returns an empty list when nothing qualifies, so the
/// caller's suppression switches itself off (the do-no-harm lesson carried
/// over from #29/#44/#48). 1:1 port of `estimate_multiedge_background`.
List<List<int>> estimateMultiedgeBackground(
  List<int> rgb,
  int height,
  int width, {
  double bandFraction = kEdgeBandFraction,
  double matchDeltaE = kEdgeMatchDeltaE,
  double presenceMin = kEdgePresenceMin,
  int minEdges = kMultiEdgeMin,
}) {
  final List<List<bool>> edgeMasks =
      _fourEdgeMasks(height, width, bandFraction);
  final List<List<List<double>>> edgeLabs = <List<List<double>>>[
    for (final List<bool> mask in edgeMasks) _bandLabs(rgb, mask),
  ];

  // Candidate background colors = the dominant colors of each edge band.
  final List<List<int>> rawCandidates = <List<int>>[];
  for (final List<bool> mask in edgeMasks) {
    final List<double> flat = <double>[];
    for (int p = 0; p < mask.length; p++) {
      if (mask[p]) {
        flat
          ..add(rgb[p * 3].toDouble())
          ..add(rgb[p * 3 + 1].toDouble())
          ..add(rgb[p * 3 + 2].toDouble());
      }
    }
    final DominantPalette palette =
        dominantColors(Float64List.fromList(flat), k: kEdgeBandClusters);
    rawCandidates.addAll(palette.colors);
  }
  final List<List<int>> candidates =
      _dedupColors(rawCandidates, kEdgeDedupDeltaE);

  final List<List<int>> background = <List<int>>[];
  for (final List<int> color in candidates) {
    final List<double> lab = srgbToLab(<double>[
      color[0].toDouble(),
      color[1].toDouble(),
      color[2].toDouble(),
    ]);
    int hits = 0;
    for (final List<List<double>> labPixels in edgeLabs) {
      if (labPixels.isEmpty) {
        continue;
      }
      int within = 0;
      for (final List<double> pixel in labPixels) {
        if (_attenuatedDeltaELab(pixel, lab) < matchDeltaE) {
          within++;
        }
      }
      if (within / labPixels.length >= presenceMin) {
        hits++;
      }
    }
    if (hits >= minEdges) {
      background.add(color);
    }
  }
  return _dedupColors(background, kEdgeDedupDeltaE);
}

/// Boolean mask (row-major, length `height * width`) of pixels within
/// [matchDeltaE] of any background color. Port of `multiedge_background_mask`.
List<bool> multiedgeBackgroundMask(
  List<int> rgb,
  int height,
  int width,
  List<List<int>> bgColors, {
  double matchDeltaE = kEdgeMatchDeltaE,
}) {
  final int n = height * width;
  final List<bool> drop = List<bool>.filled(n, false);
  if (bgColors.isEmpty) {
    return drop;
  }
  final List<List<double>> bgLabs = <List<double>>[
    for (final List<int> c in bgColors)
      srgbToLab(<double>[c[0].toDouble(), c[1].toDouble(), c[2].toDouble()]),
  ];
  for (int p = 0; p < n; p++) {
    final List<double> lab = srgbToLab(<double>[
      rgb[p * 3].toDouble(),
      rgb[p * 3 + 1].toDouble(),
      rgb[p * 3 + 2].toDouble(),
    ]);
    for (final List<double> bgLab in bgLabs) {
      if (_attenuatedDeltaELab(lab, bgLab) < matchDeltaE) {
        drop[p] = true;
        break;
      }
    }
  }
  return drop;
}

/// Center-subject background mask for PRODUCT mode (issue #84).
///
/// Estimates the multi-edge background colors and returns the mask of pixels
/// to drop before clustering. Self-disables (returns an all-false mask) both
/// when no color qualifies as background AND when the mask would cover more
/// than [maxCoverage] of the frame (the flagged color IS a frame-filling
/// subject) — so the whole-frame palette is the graceful fallback in the two
/// ambiguous extremes. 1:1 port of `product_background_mask`.
List<bool> productBackgroundMask(
  List<int> rgb,
  int height,
  int width, {
  double bandFraction = kEdgeBandFraction,
  double matchDeltaE = kEdgeMatchDeltaE,
  double presenceMin = kEdgePresenceMin,
  int minEdges = kMultiEdgeMin,
  double maxCoverage = kProductBgMaxCoverage,
}) {
  final List<List<int>> bgColors = estimateMultiedgeBackground(
    rgb,
    height,
    width,
    bandFraction: bandFraction,
    matchDeltaE: matchDeltaE,
    presenceMin: presenceMin,
    minEdges: minEdges,
  );
  final List<bool> mask = multiedgeBackgroundMask(rgb, height, width, bgColors,
      matchDeltaE: matchDeltaE);
  int dropped = 0;
  for (final bool d in mask) {
    if (d) {
      dropped++;
    }
  }
  if (dropped / mask.length > maxCoverage) {
    // Subject likely fills the frame: suppress nothing.
    return List<bool>.filled(mask.length, false);
  }
  return mask;
}
