import 'dart:math' as math;
import 'dart:typed_data';

import 'kmeans.dart';

/// Dominant color extraction (features 2 and 3) — Dart port of
/// `cv_core/src/colorlab/palette.py` (the canonical reference, with tests).
///
/// Strategy: over-cluster with K-means (more clusters than requested) and then
/// merge the perceptually equal clusters in CIELAB space. That way the light
/// gradations of a single garment collapse into one color and the
/// minority-but-distinctive colors (the outfit's "pop") survive.

/// Default number of palette colors (DEFAULT_COLORS in palette.py).
const int kDefaultColors = 5;

/// Clusters with a weight below this are residual (noise, duplicates) and are
/// discarded (MIN_WEIGHT in palette.py).
const double kMinWeight = 0.02;

/// Over-clustering factor: K-means starts with k * factor clusters to capture
/// nuances (light gradations, minority colors) that are later merged if they
/// are perceptually equal. With the default k (5) that gives 10 initial
/// clusters, within the 8-10 range validated with the Vuitton photo.
/// (OVERSEGMENT_FACTOR in palette.py.)
const int kOversegmentFactor = 2;

/// Merge threshold in deltaE (Euclidean in CIELAB with attenuated L, see
/// below). References: ~2.3 is the just-noticeable difference (JND) and at
/// 10-20 two colors are perceived as "the same color" under different
/// lighting. We chose 20.0, validated with samples/vuitton2006lr.jpg: the
/// fuchsia variants of the same garment collapse by chaining through the
/// closest pair, while the maroon and the lavender (dE > 60 to the fuchsia)
/// stay intact. (MERGE_DELTA_E in palette.py.)
const double kMergeDeltaE = 20.0;

/// Attenuation of the L term in the merge distance (equivalent to kL=2 of the
/// TEXTILES variant of CIE94). Shading of a single garment moves lightness L
/// a lot but a/b barely; with pure deltaE-76 the two halves (light/shadow) of
/// the lavender sneakers in the Vuitton photo were 24.9 apart and did not
/// merge, both dying separately under MIN_WEIGHT. With L/2 they are 12.7
/// apart and reunite, without merging genuinely distinct pairs (black-white
/// stays at 50, navy-mustard at 100). (MERGE_LIGHTNESS_WEIGHT in palette.py.)
const double kMergeLightnessWeight = 0.5;

/// Below this LAB chroma (C* = sqrt(a*^2 + b*^2)) a color reads as neutral
/// (gray/black/white/beige). Perceptual chroma, NOT HSV saturation (#22, bugs
/// B5/B8). Canonical HERE (the color-space module, same as NEUTRAL_CHROMA in
/// palette.py); re-exported by `harmony.dart` so existing imports keep working.
const double kNeutralChroma = 13.0;

/// When merging NEUTRAL-vs-NEUTRAL clusters, L* is the ONLY signal that
/// separates white from gray from black (their a*/b* are all ~0), so
/// attenuating it ([kMergeLightnessWeight]) is exactly wrong there: it lets a
/// near-white sole chain down into a mid-gray and render as gray (the white
/// bug, #84 round 2). With neutral-lightness protection ON we score
/// neutral-neutral pairs at FULL L, so white/gray/black stay distinct while
/// similar neutrals still merge. Chromatic pairs keep the attenuated L.
/// Opt-in — product mode only — so outfit-mode palettes are byte-identical.
/// (NEUTRAL_MERGE_LIGHTNESS_WEIGHT in palette.py.)
const double kNeutralMergeLightnessWeight = 1.0;

// sRGB -> CIELAB conversion with D65 illuminant (pure arithmetic, portable).
// Linear sRGB -> XYZ matrix (IEC 61966-2-1) and D65 reference white.
// (Same coefficients as _SRGB_TO_XYZ / _D65_WHITE in palette.py.)
const List<double> _srgbToXyz = <double>[
  0.4124564, 0.3575761, 0.1804375, //
  0.2126729, 0.7151522, 0.0721750, //
  0.0193339, 0.1191920, 0.9503041, //
];
const List<double> _d65White = <double>[0.95047, 1.0, 1.08883];

/// Knee threshold of the sRGB gamma curve (linear segment vs power segment).
const double _srgbGammaKnee = 0.04045;

/// Threshold (6/29)^3 of the linear segment of the LAB model's f(t) function
/// (exactly 216/24389, same value as _LAB_EPSILON in palette.py).
const double _labEpsilon = 216.0 / 24389.0;

/// Slope 3*(6/29)^2 of the linear segment of f(t): f(t) = t/(3*(6/29)^2)+4/29.
const double _labKnee = 108.0 / 841.0;

/// Converts an sRGB 0-255 color `[r, g, b]` to CIELAB (D65) `[L, a, b]`.
///
/// Standard sRGB -> XYZ -> LAB implementation, sufficient to measure
/// deltaE-76 perceptual distances between cluster centers.
List<double> srgbToLab(List<double> rgb) {
  // Linearize the sRGB gamma curve.
  final List<double> linear = <double>[
    for (int d = 0; d < 3; d++) _linearizeSrgb(rgb[d] / 255.0),
  ];
  // xyz = M @ linear, normalized by the D65 white.
  final List<double> f = <double>[0, 0, 0];
  for (int row = 0; row < 3; row++) {
    double xyz = 0;
    for (int col = 0; col < 3; col++) {
      xyz += _srgbToXyz[row * 3 + col] * linear[col];
    }
    xyz /= _d65White[row];
    f[row] = xyz > _labEpsilon
        ? math.pow(xyz, 1.0 / 3.0).toDouble()
        : xyz / _labKnee + 4.0 / 29.0;
  }
  final double lightness = 116.0 * f[1] - 16.0;
  final double a = 500.0 * (f[0] - f[1]);
  final double b = 200.0 * (f[1] - f[2]);
  return <double>[lightness, a, b];
}

double _linearizeSrgb(double c) => c <= _srgbGammaKnee
    ? c / 12.92
    : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// Iteratively merges the closest pair of colors in LAB.
///
/// While a pair with deltaE < threshold exists (Euclidean in LAB with L
/// attenuated by [kMergeLightnessWeight], CIE94-textiles style), the closest
/// one is merged: center = weight-weighted mean, weight = sum of weights.
/// We average in RGB because the merged colors are nearly equal by definition
/// of the threshold (the error versus averaging in LAB is negligible and it
/// spares us the inverse LAB -> sRGB conversion).
///
/// When [protectNeutralLightness] is set (product mode, #84), a pair in which
/// BOTH clusters are neutral (chroma < [kNeutralChroma]) is scored at FULL L
/// ([kNeutralMergeLightnessWeight]) instead of the attenuated L, so a
/// near-white never collapses into a mid-gray it merely shares a hue-less
/// axis with. Chromatic pairs are unaffected. Off by default: outfit-mode
/// output is byte-identical. (protect_neutral_lightness in palette.py.)
///
/// Same ordering discipline as palette.py: the two merged entries are removed
/// and the result is appended AT THE END of the list (affects tie-breaking).
(List<List<double>>, List<double>) mergeSimilarColors(
    List<List<double>> colors, List<double> weights, double threshold,
    {bool protectNeutralLightness = false}) {
  final List<List<double>> cs = <List<double>>[
    for (final List<double> c in colors) List<double>.of(c),
  ];
  final List<double> ws = List<double>.of(weights);

  while (cs.length > 1) {
    final List<List<double>> labs = <List<double>>[
      for (final List<double> c in cs) srgbToLab(c),
    ];
    // Neutrality per cluster (raw a*/b*, unaffected by the L attenuation).
    final List<bool> neutral = <bool>[
      if (protectNeutralLightness)
        for (final List<double> lab in labs)
          math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]) < kNeutralChroma,
    ];
    double bestDist = double.infinity;
    int mi = -1, mj = -1;
    for (int i = 0; i < labs.length; i++) {
      for (int j = i + 1; j < labs.length; j++) {
        // Neutral-vs-neutral pairs score at FULL L (their only separating
        // axis, #84); everything else keeps the historical attenuated L.
        final double lWeight =
            (protectNeutralLightness && neutral[i] && neutral[j])
                ? kNeutralMergeLightnessWeight
                : kMergeLightnessWeight;
        final double dl = (labs[i][0] - labs[j][0]) * lWeight;
        final double da = labs[i][1] - labs[j][1];
        final double db = labs[i][2] - labs[j][2];
        final double dist = math.sqrt(dl * dl + da * da + db * db);
        if (dist < bestDist) {
          bestDist = dist;
          mi = i;
          mj = j;
        }
      }
    }
    if (bestDist >= threshold) {
      break;
    }
    final double mergedWeight = ws[mi] + ws[mj];
    final List<double> mergedColor = <double>[
      for (int d = 0; d < 3; d++)
        (cs[mi][d] * ws[mi] + cs[mj][d] * ws[mj]) / mergedWeight,
    ];
    // mj > mi always: remove the high index first so it does not shift.
    cs.removeAt(mj);
    cs.removeAt(mi);
    ws.removeAt(mj);
    ws.removeAt(mi);
    cs.add(mergedColor);
    ws.add(mergedWeight);
  }
  return (cs, ws);
}

/// Palette result: integer RGB colors and weights, in descending weight order.
class DominantPalette {
  /// Creates a palette from its [colors] and their relative [weights].
  const DominantPalette(this.colors, this.weights);

  /// Colors [m][3] RGB 0-255, from most to least frequent (m <= k).
  final List<List<int>> colors;

  /// Weight (pixel fraction) of each color. Not renormalized after
  /// discarding residuals (same as palette.py): may sum < 1.
  final List<double> weights;
}

/// Dominant colors by K-means over flattened RGB pixels `[n*3]`.
///
/// Over-clusters with `k * kOversegmentFactor` clusters and then merges the
/// clusters whose deltaE distance in LAB (with attenuated L, see
/// [kMergeLightnessWeight]) is below [mergeDeltaE] (`mergeDeltaE <= 0`
/// disables the merge and is equivalent to plain K-means).
///
/// [protectNeutralLightness] (product mode, #84) keeps neutral clusters that
/// differ mainly in lightness — white vs. gray vs. black — from merging into
/// one gray; see [mergeSimilarColors]. Off by default so outfit-mode palettes
/// are unchanged.
///
/// Returns colors and weights sorted from most to least frequent, with
/// m <= k, discarding clusters with weight < [minWeight]. 1:1 port of
/// `dominant_colors()` in palette.py.
DominantPalette dominantColors(
  Float64List pixels, {
  int k = kDefaultColors,
  double minWeight = kMinWeight,
  double mergeDeltaE = kMergeDeltaE,
  bool protectNeutralLightness = false,
}) {
  final int n = pixels.length ~/ 3;
  if (n == 0) {
    throw ArgumentError('dominantColors needs at least one pixel');
  }
  // Never request more clusters than available pixels.
  final int kOver =
      mergeDeltaE > 0 ? math.min(k * kOversegmentFactor, n) : math.min(k, n);

  final KmeansResult km = kmeans(pixels, kOver);
  final List<int> counts = List<int>.filled(kOver, 0);
  for (final int label in km.labels) {
    counts[label]++;
  }

  // Centers clamped to the valid RGB range; empty clusters contribute nothing
  // and would break the merge's weighted mean.
  List<List<double>> colors = <List<double>>[];
  List<double> weights = <double>[];
  for (int c = 0; c < kOver; c++) {
    if (counts[c] == 0) {
      continue;
    }
    colors.add(<double>[
      for (int d = 0; d < 3; d++) km.centers[c * 3 + d].clamp(0.0, 255.0),
    ]);
    weights.add(counts[c] / n);
  }

  if (mergeDeltaE > 0) {
    final (List<List<double>>, List<double>) merged = mergeSimilarColors(
        colors, weights, mergeDeltaE,
        protectNeutralLightness: protectNeutralLightness);
    colors = merged.$1;
    weights = merged.$2;
  }

  // Descending weight order, ties broken by position (deterministic).
  final List<int> order = List<int>.generate(colors.length, (int i) => i);
  order.sort((int a, int b) {
    final int byWeight = weights[b].compareTo(weights[a]);
    return byWeight != 0 ? byWeight : a.compareTo(b);
  });

  final List<List<int>> finalColors = <List<int>>[];
  final List<double> finalWeights = <double>[];
  for (final int i in order.take(k)) {
    if (weights[i] < minWeight) {
      continue;
    }
    finalColors.add(<int>[
      for (int d = 0; d < 3; d++) colors[i][d].round().clamp(0, 255),
    ]);
    finalWeights.add(weights[i]);
  }
  return DominantPalette(finalColors, finalWeights);
}
