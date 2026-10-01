import 'dart:math' as math;
import 'dart:typed_data';

import '../color_engine/palette.dart' show kNeutralChroma;
import '../segmentation/raster_ops.dart';
import 'opencv_lab.dart';

/// Per-region garment recolor (I2 "Vérmelo puesto", D38) — Dart port of
/// `cv_core/src/colorlab/recolor.py::recolor_region` (the canonical
/// reference; parity pinned by `test/core/fixtures/recolor_parity_I2.json`).
///
/// A CLASSIC, lighting-preserving transform in CIELAB (OpenCV float
/// convention, see [OpenCvLab]): no model, no server (D2). Per pixel of the
/// region:
///
///  1. lightness × a MULTIPLICATIVE gain `(L_target / L_source) ^ shift`
///     (a dye change scales reflectance: shadows stay dark, folds keep their
///     contrast as a ratio);
///  2. chroma, by regime (source/target chroma vs [kNeutralChroma]):
///     - both chromatic → HUE REPLACEMENT: the target hue with the pixel's
///       own chroma × the clamped target/source chroma ratio;
///     - otherwise → CHROMA INJECTION: the target (a*, b*) × a lightness bell
///       (this is also the chroma COLLAPSE when the target is neutral);
///  3. blended with weight = feathered mask × membership (a logo or the
///     other stripe of a print keeps its colour);
///  4. back to sRGB, clipped; pixels OUTSIDE the mask are byte-identical.
///
/// Pure and synchronous (runs inside a worker isolate); works on the app's
/// native RGBA buffers (alpha copied through).

/// Edge softening half-width in px (FEATHER_PX).
const int kRecolorFeatherPx = 3;

/// Lightness gain exponent for a chromatic target (LIGHTNESS_SHIFT_CHROMATIC).
const double kLightnessShiftChromatic = 0.7;

/// Lightness gain exponent for a neutral target (LIGHTNESS_SHIFT_NEUTRAL).
const double kLightnessShiftNeutral = 1.0;

/// Lower clamp of the target/source chroma ratio in the hue-replacement
/// regime (CHROMA_SCALE_MIN): a vivid source is not crushed to gray.
const double kChromaScaleMin = 0.5;

/// Upper clamp of that ratio (CHROMA_SCALE_MAX): a barely-chromatic source
/// is not blown up into posterized noise.
const double kChromaScaleMax = 3.0;

/// Floor of the injection lightness bell (INJECT_BELL_FLOOR).
const double kInjectBellFloor = 0.25;

/// Membership ramp: a pixel within this lightness-weighted ΔE of the source
/// colour is fully recolored (MEMBERSHIP_DELTA_E_FULL)…
const double kMembershipDeltaEFull = 25.0;

/// …and one at or beyond this ΔE is left untouched
/// (MEMBERSHIP_DELTA_E_ZERO); linear ramp in between.
const double kMembershipDeltaEZero = 55.0;

/// Weight of the L* axis in the membership distance
/// (MEMBERSHIP_LIGHTNESS_WEIGHT): shading stays in, a logo falls out.
const double kMembershipLightnessWeight = 0.5;

const double _labLMax = 100.0;
const double _lGainFloor = 2.0;

/// Which transform [recolorRegion] applied (diagnostics / tests).
enum RecolorRegime {
  /// Chromatic source and target: the target hue, the pixel's own chroma.
  hueReplacement,

  /// Neutral source and/or target: the target (a*, b*) × a lightness bell.
  chromaInjection,
}

/// Regime of a (source, target) LAB pair — Python's `_shift_lab` branch.
RecolorRegime recolorRegimeOf(List<double> sourceLab, List<double> targetLab) {
  final double cSrc = _hypot(sourceLab[1], sourceLab[2]);
  final double cTgt = _hypot(targetLab[1], targetLab[2]);
  return cSrc >= kNeutralChroma && cTgt >= kNeutralChroma
      ? RecolorRegime.hueReplacement
      : RecolorRegime.chromaInjection;
}

double _hypot(double a, double b) => math.sqrt(a * a + b * b);

/// Soft alpha INSIDE the region (`feather_mask`): the hard 0/1 [mask]
/// Gaussian-blurred (sigma = featherPx / 2, ksize = 2·ceil(3·sigma) + 1,
/// `BORDER_REFLECT_101`) and re-masked, so every pixel outside keeps alpha 0.
/// `featherPx <= 0` = the hard mask. Returns a full-frame plane.
Float32List featherMask(Uint8List mask, int width, int height,
    {int featherPx = kRecolorFeatherPx}) {
  final Float32List hard = Float32List(mask.length);
  int x0 = width, y0 = height, x1 = -1, y1 = -1;
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] == 0) continue;
    hard[i] = 1;
    final int y = i ~/ width;
    final int x = i - y * width;
    if (x < x0) x0 = x;
    if (x > x1) x1 = x;
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
  }
  if (featherPx <= 0 || x1 < 0) {
    return hard;
  }
  final double sigma = featherPx / 2.0;
  final int ksize = 2 * (3.0 * sigma).ceil() + 1;
  final Float32List soft = gaussianBlurPlane(
      hard, width, height, gaussianKernel(ksize, sigma),
      x0: x0, y0: y0, x1: x1, y1: y1);
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] == 0) soft[i] = 0;
  }
  return soft;
}

/// Repaints the garment under [mask] toward [targetRgb] — see the file doc.
///
/// [rgba]: the photo, `width * height * 4`. [mask]: the 0/1 region (use the
/// UN-eroded hardened split so the recolor reaches the garment edge).
/// [sourceRgb]: the garment's dominant colour as the engine measured it;
/// null = the mean LAB of the region. [lightnessShift] null = the neutral /
/// chromatic default by the target's chroma. [selective] false = uniform
/// (no membership weight).
///
/// Returns a NEW RGBA buffer; pixels with `mask == 0` are byte-identical.
/// Throws [ArgumentError] on an empty mask or mismatched sizes.
Uint8List recolorRegion(
  Uint8List rgba,
  int width,
  int height,
  Uint8List mask,
  List<int> targetRgb, {
  List<int>? sourceRgb,
  int featherPx = kRecolorFeatherPx,
  double? lightnessShift,
  bool selective = true,
}) {
  final int n = width * height;
  if (rgba.length != n * 4) {
    throw ArgumentError('rgba length ${rgba.length} != $width*$height*4');
  }
  if (mask.length != n) {
    throw ArgumentError('mask length ${mask.length} != $width*$height');
  }

  // LAB of the region's pixels only (outside the mask nothing is touched).
  final Int32List index = Int32List(n);
  int count = 0;
  for (int i = 0; i < n; i++) {
    if (mask[i] != 0) index[count++] = i;
  }
  if (count == 0) {
    throw ArgumentError('region mask is empty: nothing to recolor');
  }
  final Float64List lab = Float64List(count * 3);
  for (int k = 0; k < count; k++) {
    final int p = index[k] * 4;
    OpenCvLab.rgb8ToLab(rgba[p], rgba[p + 1], rgba[p + 2], lab, k * 3);
  }

  final List<double> sourceLab;
  if (sourceRgb != null) {
    sourceLab = OpenCvLab.labOf(sourceRgb);
  } else {
    double sl = 0, sa = 0, sb = 0;
    for (int k = 0; k < count; k++) {
      sl += lab[k * 3];
      sa += lab[k * 3 + 1];
      sb += lab[k * 3 + 2];
    }
    sourceLab = <double>[sl / count, sa / count, sb / count];
  }
  final List<double> targetLab = OpenCvLab.labOf(targetRgb);
  final double lSrc = sourceLab[0], aSrc = sourceLab[1], bSrc = sourceLab[2];
  final double lTgt = targetLab[0], aTgt = targetLab[1], bTgt = targetLab[2];
  final double cSrc = _hypot(aSrc, bSrc);
  final double cTgt = _hypot(aTgt, bTgt);
  final bool targetIsNeutral = cTgt < kNeutralChroma;
  final double shift = lightnessShift ??
      (targetIsNeutral ? kLightnessShiftNeutral : kLightnessShiftChromatic);
  final double gain = math
      .pow(math.max(lTgt, _lGainFloor) / math.max(lSrc, _lGainFloor), shift)
      .toDouble();
  final bool hueReplacement =
      recolorRegimeOf(sourceLab, targetLab) == RecolorRegime.hueReplacement;
  final double scale = hueReplacement
      ? (cTgt / cSrc).clamp(kChromaScaleMin, kChromaScaleMax).toDouble()
      : 0;
  final double peak = math.max(lTgt * (_labLMax - lTgt), 1.0);

  final Float32List alpha =
      featherMask(mask, width, height, featherPx: featherPx);
  final Uint8List out = Uint8List.fromList(rgba);
  final Float64List rgb = Float64List(3);
  const double membershipSpan = kMembershipDeltaEZero - kMembershipDeltaEFull;
  for (int k = 0; k < count; k++) {
    final int i = index[k];
    final double l = lab[k * 3], a = lab[k * 3 + 1], b = lab[k * 3 + 2];

    double weight = alpha[i];
    if (selective) {
      final double dl = (l - lSrc) * kMembershipLightnessWeight;
      final double da = a - aSrc;
      final double db = b - bSrc;
      final double dist = math.sqrt(dl * dl + da * da + db * db);
      double ramp = (kMembershipDeltaEZero - dist) / membershipSpan;
      ramp = ramp < 0 ? 0 : (ramp > 1 ? 1 : ramp);
      weight *= ramp;
    }

    double ls = l * gain;
    ls = ls < 0 ? 0 : (ls > _labLMax ? _labLMax : ls);
    final double as, bs;
    if (hueReplacement) {
      final double chroma = _hypot(a, b) * scale;
      as = chroma * (aTgt / cTgt);
      bs = chroma * (bTgt / cTgt);
    } else {
      double bell = ls * (_labLMax - ls) / peak;
      bell = bell < kInjectBellFloor ? kInjectBellFloor : (bell > 1 ? 1 : bell);
      as = aTgt * bell;
      bs = bTgt * bell;
    }

    OpenCvLab.labToRgbFloat(
      l + weight * (ls - l),
      a + weight * (as - a),
      b + weight * (bs - b),
      rgb,
    );
    final int p = i * 4;
    out[p] = OpenCvLab.to8bit(rgb[0]);
    out[p + 1] = OpenCvLab.to8bit(rgb[1]);
    out[p + 2] = OpenCvLab.to8bit(rgb[2]);
  }
  return out;
}
