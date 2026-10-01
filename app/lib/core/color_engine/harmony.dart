import 'dart:math' as math;

import 'palette.dart' show kNeutralChroma, srgbToLab;

export 'palette.dart' show kNeutralChroma;

/// Color harmonies: classic color theory in HSV (feature 4) — Dart port of
/// `cv_core/src/colorlab/harmony.py` (the canonical reference, with tests).
///
/// The RGB<->HSV conversions replicate Python's `colorsys` step by step
/// (including the TRUNCATION to int of hsv->rgb, not rounding) so that the
/// proposals match the reference backend's almost bit for bit.

// NOTE: kNeutralChroma moved to palette.dart (canonical, like NEUTRAL_CHROMA
// in palette.py) and is re-exported above so existing imports keep working.

/// Saturation floor so the proposals do not come out washed out.
/// (PROPOSAL_MIN_SAT in harmony.py.)
const double kProposalMinSat = 0.35;

/// Value (brightness) floor for the same reason. (PROPOSAL_MIN_VAL.)
const double kProposalMinVal = 0.55;

/// Canvas mode (D10, #21): a 100% neutral outfit has no chromatic base, so
/// instead of rotating an arbitrary hue (bug B3) we offer a curated, versatile
/// set of accent "pops" that read well against any neutral. Mirror of
/// `CANVAS_ACCENTS` in harmony.py, CEO-ratified — the golden fixture
/// `lienzo_neutro_D10.json` verifies both stay identical byte-for-byte.
const List<List<int>> kCanvasAccents = <List<int>>[
  <int>[0xE4, 0x32, 0x2B], // Rojo
  <int>[0x2B, 0x5C, 0xE4], // Cobalto
  <int>[0xE0, 0xA0, 0x00], // Mostaza
  <int>[0x12, 0xA1, 0x50], // Esmeralda
  <int>[0xD6, 0x24, 0x8C], // Frambuesa
];

/// Dominant-neutral context gate (#57): on a neutral-dominant outfit a chromatic
/// patch below this weight is demoted (as likely a reflection/wall as a real
/// accent — color alone cannot tell). Inert when the dominant color is
/// chromatic. (POP_ON_NEUTRAL_MIN in harmony.py.)
const double kPopOnNeutralMin = 0.10;

/// RGB 0-255 -> HSV with h, s, v in 0..1 (exact port of colorsys.rgb_to_hsv).
(double, double, double) rgbToHsv(List<int> rgb) {
  final double r = rgb[0] / 255.0;
  final double g = rgb[1] / 255.0;
  final double b = rgb[2] / 255.0;
  final double maxc = math.max(r, math.max(g, b));
  final double minc = math.min(r, math.min(g, b));
  final double v = maxc;
  if (minc == maxc) {
    return (0.0, 0.0, v);
  }
  final double range = maxc - minc;
  final double s = range / maxc;
  final double rc = (maxc - r) / range;
  final double gc = (maxc - g) / range;
  final double bc = (maxc - b) / range;
  double h;
  if (r == maxc) {
    h = bc - gc;
  } else if (g == maxc) {
    h = 2.0 + rc - bc;
  } else {
    h = 4.0 + gc - rc;
  }
  h = (h / 6.0) % 1.0;
  return (h, s, v);
}

/// HSV in 0..1 (h is normalized modulo 1) -> RGB 0-255.
///
/// Exact port of colorsys.hsv_to_rgb + harmony.py's `int(x * 255)`
/// conversion: TRUNCATES toward zero (like Python's `int()`), no rounding.
List<int> hsvToRgb(double h, double s, double v) {
  h = h % 1.0; // Dart's % on doubles is Euclidean modulo, like Python
  double r, g, b;
  if (s == 0.0) {
    r = g = b = v;
  } else {
    final int i = (h * 6.0).toInt(); // Python's int(): truncation
    final double f = h * 6.0 - i;
    final double p = v * (1.0 - s);
    final double q = v * (1.0 - s * f);
    final double t = v * (1.0 - s * (1.0 - f));
    switch (i % 6) {
      case 0:
        (r, g, b) = (v, t, p);
      case 1:
        (r, g, b) = (q, v, p);
      case 2:
        (r, g, b) = (p, v, t);
      case 3:
        (r, g, b) = (p, q, v);
      case 4:
        (r, g, b) = (t, p, v);
      default:
        (r, g, b) = (v, p, q);
    }
  }
  return <int>[(r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt()];
}

/// RGB 0-255 -> '#RRGGBB' (uppercase, like hexstr in harmony.py).
String hexstr(List<int> rgb) {
  final StringBuffer sb = StringBuffer('#');
  for (final int c in rgb) {
    sb.write(c.toRadixString(16).toUpperCase().padLeft(2, '0'));
  }
  return sb.toString();
}

/// Perceptual chroma C* = sqrt(a*^2 + b*^2) in CIELAB (colorfulness). Stable
/// near black/white, unlike HSV saturation (#22). Port of `lab_chroma` in
/// harmony.py.
double labChroma(List<int> rgb) {
  final List<double> lab = srgbToLab(
      <double>[rgb[0].toDouble(), rgb[1].toDouble(), rgb[2].toDouble()]);
  return math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
}

/// Whites, grays, blacks, beiges: low chroma -> neutral (basic/background).
/// Chroma-based (kNeutralChroma), robust on near-blacks (#22, bugs B5/B8).
bool isNeutral(List<int> rgb) {
  return labChroma(rgb) < kNeutralChroma;
}

/// Chooses which color to build the harmonies on (decision D5, with tests in
/// Python — do NOT break it).
///
/// NOT the most frequent one (usually background/neutral), but the most
/// "chromatically leading" = saturation * weight.
///
/// Deliberate deviation from harmony.py's `pick_harmony_base`: here we return
/// the INDEX within the palette (the [AnalysisResult] contract works with
/// indices) and `-1` when ALL colors are neutral (canvas mode, D10, instead
/// of Python's silent fallback). The engine reproduces Python's fallback by
/// using `palette[0]` as the harmony base when we return -1.
int pickHarmonyBase(List<List<int>> colors, List<double> weights) {
  // Dominant-neutral context gate (#57): find the max-weight color.
  int dominant = 0;
  for (int i = 1; i < weights.length; i++) {
    if (weights[i] > weights[dominant]) {
      dominant = i;
    }
  }
  final bool dominantIsNeutral = isNeutral(colors[dominant]);

  int best = -1;
  double bestScore = -1.0;
  for (int i = 0; i < colors.length; i++) {
    if (isNeutral(colors[i])) {
      continue; // neutrals do not lead harmonies (chroma-based, #22)
    }
    if (dominantIsNeutral && weights[i] < kPopOnNeutralMin) {
      continue; // tiny chromatic on a neutral outfit -> canvas mode (#57)
    }
    final (_, double s, _) = rgbToHsv(colors[i]);
    final double score = s * weights[i];
    if (score > bestScore) {
      best = i;
      bestScore = score;
    }
  }
  return best;
}

/// Classic harmony schemes rotating the hue of the base color.
///
/// Same insertion order and same names as harmony.py's dict — the keys are
/// the SPANISH UI names, frozen by fixture parity (the UI maps
/// name -> [HarmonyType] in the engine).
Map<String, List<List<int>>> harmonies(List<int> baseRgb) {
  final (double h, double s0, double v0) = rgbToHsv(baseRgb);
  final double s = math.max(s0, kProposalMinSat);
  final double v = math.max(v0, kProposalMinVal);

  double deg(double d) => h + d / 360.0;

  return <String, List<List<int>>>{
    'Complementario': <List<int>>[baseRgb, hsvToRgb(deg(180), s, v)],
    'Análogo': <List<int>>[
      hsvToRgb(deg(-30), s, v),
      baseRgb,
      hsvToRgb(deg(30), s, v),
    ],
    'Triádico': <List<int>>[
      baseRgb,
      hsvToRgb(deg(120), s, v),
      hsvToRgb(deg(240), s, v),
    ],
    'Complementario dividido': <List<int>>[
      baseRgb,
      hsvToRgb(deg(150), s, v),
      hsvToRgb(deg(210), s, v),
    ],
  };
}
