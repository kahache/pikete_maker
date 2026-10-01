import 'dart:math' as math;
import 'dart:ui' show Color;

import 'palette.dart' show kNeutralChroma, srgbToLab;

/// Display-time canonicalization of neutral swatches (issue #85, D31 option A)
/// — Dart port of `cv_core/src/colorlab/display.py` (the canonical reference,
/// with tests; its fixture table is mirrored 1:1 in
/// `test/core/display_parity_test.dart`).
///
/// Under real lighting/flash a black sneaker never clusters to pure black: the
/// extracted swatch is the actual illuminated color (a #2E2928 / #3C3937 dark
/// gray), and a white one reads as a light gray (#D0CCC9). Technically
/// correct, but it does not match what the user KNOWS their shoe to be
/// ("es negra"). D31-A: snap those neutrals AT DISPLAY TIME only.
///
/// This module is pure presentation — it must NEVER feed back into the
/// analysis: the stored palette, weights, harmony base and canvas-mode routing
/// are computed on the RAW colors and stay byte-identical; callers apply
/// [snapNeutralForDisplay] / [snapColorForDisplay] only when *showing* a
/// swatch (the sneaker/product result screen — outfit mode is untouched).
///
/// Rule (exact contract, mirrored 1:1 from display.py):
///
///     chroma = LAB C* of the sRGB color (D65, same srgbToLab as the merge)
///     if chroma >= kNeutralChroma (13.0):        -> unchanged  (chroma gate)
///     elif L* <= kSnapBlackLHard (21.0):         -> #000000    (deep dark)
///     elif L* <= kSnapBlackLMax (28.0)
///          && chroma < kSnapBlackSoftChroma (4):  -> #000000    (soft band)
///     elif L* >= kSnapWhiteLMin (80.0):          -> #FFFFFF
///     else:                                      -> unchanged  (genuine gray)
///
/// The two-tier black branch (bug B-G25-3, measured 2026-07-20) exists because
/// chroma compresses as L* falls: at the top of the snap range C* < 13 still
/// admits visibly coloured garments (the CEO's blue crochet fishnet #3C414D,
/// C* 8.0; his olive/brown wool sweater #413934, C* 5.1) which were being
/// painted pure black. Below kSnapBlackLHard the original behaviour is kept
/// verbatim — that is where the genuine "negro diluido" swatches live.
///
/// The chroma gate is the safety property the CEO insisted on: a navy shoe
/// that is truly blue (#051C56, C* 41) or a maroon (#451316, C* 27) is never
/// touched — only hue-less colors (C* < kNeutralChroma, the same neutrality
/// definition as `isNeutral`/the #84 merge) are candidates.

/// Above (or at) this L* nothing snaps to black. 28.0 sits in the empty band
/// measured on the gate G2S phone battery between the CEO's "negro diluido"
/// swatches (all L* <= 25.0) and the darkest genuine NON-black neutrals that
/// must stay themselves (#52463E flesh-suede L* 30.7).
/// (SNAP_BLACK_L_MAX in display.py.)
const double kSnapBlackLMax = 28.0;

/// Below (or at) this L* a low-chroma color snaps to black UNCONDITIONALLY —
/// the original D31-A behaviour, kept for the deep darks it was built for.
/// 21.0 is the midpoint of the empty band measured on the 65-photo gate G2.5
/// set (B-G25-3) between the lightest correctly-snapped swatch carrying real
/// chroma (#372E24, L* 19.6 C* 8.3) and the darkest swatch the CEO rejected as
/// black (#303745, L* 23.0). (SNAP_BLACK_L_HARD in display.py.)
const double kSnapBlackLHard = 21.0;

/// In the soft band (kSnapBlackLHard, kSnapBlackLMax] a color must be much
/// closer to hue-less than [kNeutralChroma] to be called black, because chroma
/// compresses in dark colors. 4.0 sits in the measured empty band between
/// #39403F (C* 3.2 — CEO says "black") and #413934 (C* 5.1 — rejected).
/// (SNAP_BLACK_SOFT_CHROMA in display.py.)
const double kSnapBlackSoftChroma = 4.0;

/// Below this L* nothing snaps to white. 80.0 sits in the measured empty band
/// between the lightest genuine gray (#C2C0C3, L* 77.9) and the darkest
/// "white read as gray" the CEO flagged (#D0CCC9, L* 82.3).
/// (SNAP_WHITE_L_MIN in display.py.)
const double kSnapWhiteLMin = 80.0;

/// Canonical snap target for near-blacks: what the user believes the garment
/// IS. (SNAP_BLACK in display.py.)
const List<int> kSnapBlack = <int>[0, 0, 0];

/// Canonical snap target for near-whites. (SNAP_WHITE in display.py.)
const List<int> kSnapWhite = <int>[255, 255, 255];

/// Canonical display color for a swatch (D31-A): pure, display-only.
///
/// Snaps a low-chroma dark to pure black and a low-chroma light to white; any
/// color with real chroma (>= [kNeutralChroma]) or a genuine mid gray is
/// returned unchanged (as a copy — the input is never mutated). 1:1 port of
/// `snap_neutral_for_display`. Never feed the result back into
/// harmony/palette math.
List<int> snapNeutralForDisplay(List<int> rgb) {
  final List<double> lab = srgbToLab(<double>[
    rgb[0].toDouble(),
    rgb[1].toDouble(),
    rgb[2].toDouble(),
  ]);
  final double chroma = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
  if (chroma >= kNeutralChroma) {
    return List<int>.of(rgb); // chromatic: never touched
  }
  if (lab[0] <= kSnapBlackLHard) {
    return kSnapBlack; // deep dark: unconditional (original D31-A band)
  }
  if (lab[0] <= kSnapBlackLMax && chroma < kSnapBlackSoftChroma) {
    return kSnapBlack; // soft band: only if near hue-less (B-G25-3)
  }
  if (lab[0] >= kSnapWhiteLMin) {
    return kSnapWhite;
  }
  return List<int>.of(rgb); // genuine mid gray
}

/// [snapNeutralForDisplay] over a [Color] (UI convenience for the product
/// result screen). Returns the ORIGINAL object when the snap is a no-op, so
/// unchanged swatches keep identity (no rounding drift).
Color snapColorForDisplay(Color color) {
  // Same 0-255 extraction as the ES color namer (color_names.dart).
  final List<int> rgb = <int>[
    (color.r * 255.0).round().clamp(0, 255),
    (color.g * 255.0).round().clamp(0, 255),
    (color.b * 255.0).round().clamp(0, 255),
  ];
  final List<int> snapped = snapNeutralForDisplay(rgb);
  if (snapped[0] == rgb[0] && snapped[1] == rgb[1] && snapped[2] == rgb[2]) {
    return color;
  }
  return Color.fromARGB(0xFF, snapped[0], snapped[1], snapped[2]);
}
