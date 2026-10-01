import 'dart:math' as math;
import 'dart:typed_data';

/// CIELAB in the OpenCV FLOAT convention (L* 0..100, a*/b* signed) — the
/// colour space of the canonical recolor (`cv_core/src/colorlab/recolor.py`,
/// `cv2.cvtColor(rgb / 255, COLOR_RGB2LAB)` and back).
///
/// NOT the palette engine's LAB (`palette.dart` mirrors `palette.srgb_to_lab`,
/// a different implementation pinned by the palette fixtures); the recolor
/// uses its own on purpose so it matches `recolor.py`, its source of truth.
///
/// What is implemented: the ANALYTIC OpenCV float formula — sRGB gamma
/// (exact piecewise curve), the sRGB→XYZ D65 matrix OpenCV uses
/// (`sRGB2XYZ_D65`, white point 0.950456 / 1 / 1.088754), the Lab f() with
/// OpenCV's constants (threshold 0.008856, slope 7.787, 903.3 for L* below the
/// threshold) and the exact inverse (`XYZ2sRGB_D65`, the input clipped to
/// [0, 1] before the inverse gamma, as OpenCV does).
///
/// Tolerance, VERIFIED against OpenCV 5.0.0 (`recolor_parity_I2.json`, the
/// `lab` probes, and a sweep of 1/3 of the RGB cube in Python):
///  - LAB → RGB (float) matches to 1e-4 — OpenCV evaluates the formula;
///  - RGB → LAB differs by up to ~0.2 L* / ~0.5 a*b* units: OpenCV's float
///    RGB→Lab does NOT evaluate the formula, it trilinearly interpolates a
///    33³ fixed-point LUT (its output is quantized to 1/64 in a*/b*). The
///    formula here is the "true" value that LUT approximates; the difference
///    is < 1 ΔE, i.e. below one 8-bit RGB step after the round trip, and is
///    absorbed by the recolor parity tolerance (see the parity test).
abstract final class OpenCvLab {
  // sRGB -> XYZ (D65), rows X, Y, Z (OpenCV sRGB2XYZ_D65).
  static const double _m00 = 0.412453, _m01 = 0.357580, _m02 = 0.180423;
  static const double _m10 = 0.212671, _m11 = 0.715160, _m12 = 0.072169;
  static const double _m20 = 0.019334, _m21 = 0.119193, _m22 = 0.950227;

  // XYZ -> sRGB (OpenCV XYZ2sRGB_D65).
  static const double _i00 = 3.240479, _i01 = -1.53715, _i02 = -0.498535;
  static const double _i10 = -0.969256, _i11 = 1.875991, _i12 = 0.041556;
  static const double _i20 = 0.055648, _i21 = -0.204043, _i22 = 1.057311;

  // D65 white point (OpenCV D65).
  static const double _whiteX = 0.950456;
  static const double _whiteZ = 1.088754;

  // Lab f() constants, OpenCV's literal values.
  static const double _threshold = 0.008856; // (6/29)^3
  static const double _slope = 7.787; // (29/3)^3 / (29*4)
  static const double _kappa = 903.3; // (29/3)^3
  static const double _offset = 16.0 / 116.0;
  static const double _lThreshold = _threshold * _kappa;
  static const double _fThreshold = _slope * _threshold + _offset;

  /// Linear-light value of each 8-bit sRGB code (exact sRGB curve).
  static final Float64List _linearOf8bit = _buildLinearTable();

  static Float64List _buildLinearTable() {
    final Float64List table = Float64List(256);
    for (int i = 0; i < 256; i++) {
      table[i] = srgbToLinear(i / 255.0);
    }
    return table;
  }

  /// sRGB gamma decode of one channel in [0, 1].
  static double srgbToLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  /// sRGB gamma encode of one linear channel in [0, 1].
  static double linearToSrgb(double c) => c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1.0 / 2.4).toDouble() - 0.055;

  static double _f(double t) =>
      t > _threshold ? math.pow(t, 1.0 / 3.0).toDouble() : _slope * t + _offset;

  /// LAB of one 8-bit sRGB pixel, written to `out[offset..offset+2]`.
  static void rgb8ToLab(int r, int g, int b, Float64List out, int offset) {
    final double lr = _linearOf8bit[r];
    final double lg = _linearOf8bit[g];
    final double lb = _linearOf8bit[b];
    final double x = (_m00 * lr + _m01 * lg + _m02 * lb) / _whiteX;
    final double y = _m10 * lr + _m11 * lg + _m12 * lb;
    final double z = (_m20 * lr + _m21 * lg + _m22 * lb) / _whiteZ;
    final double fx = _f(x);
    final double fy = _f(y);
    final double fz = _f(z);
    out[offset] = y > _threshold ? 116.0 * fy - 16.0 : _kappa * y;
    out[offset + 1] = 500.0 * (fx - fy);
    out[offset + 2] = 200.0 * (fy - fz);
  }

  /// LAB (L*, a*, b*) of one `[r, g, b]` 8-bit triple.
  static List<double> labOf(List<int> rgb) {
    final Float64List out = Float64List(3);
    rgb8ToLab(rgb[0], rgb[1], rgb[2], out, 0);
    return out;
  }

  /// Float sRGB in [0, 1] (clipped, like OpenCV) of one LAB triple, written
  /// to `out[0..2]`.
  static void labToRgbFloat(double l, double a, double b, Float64List out) {
    final double y;
    final double fy;
    if (l <= _lThreshold) {
      y = l / _kappa;
      fy = _slope * y + _offset;
    } else {
      fy = (l + 16.0) / 116.0;
      y = fy * fy * fy;
    }
    double fx = a / 500.0 + fy;
    double fz = fy - b / 200.0;
    fx = fx <= _fThreshold ? (fx - _offset) / _slope : fx * fx * fx;
    fz = fz <= _fThreshold ? (fz - _offset) / _slope : fz * fz * fz;
    final double x = fx * _whiteX;
    final double z = fz * _whiteZ;
    out[0] = linearToSrgb(_clip01(_i00 * x + _i01 * y + _i02 * z));
    out[1] = linearToSrgb(_clip01(_i10 * x + _i11 * y + _i12 * z));
    out[2] = linearToSrgb(_clip01(_i20 * x + _i21 * y + _i22 * z));
  }

  static double _clip01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// `np.clip(np.rint(v * 255), 0, 255)` for one float channel: numpy's rint
  /// rounds HALF TO EVEN (Dart's `round` rounds half away from zero).
  static int to8bit(double v) {
    final double x = v * 255.0;
    double r = x.roundToDouble();
    if ((r - x).abs() == 0.5 && r % 2 != 0) {
      r -= (r > x) ? 1 : -1;
    }
    if (r < 0) return 0;
    if (r > 255) return 255;
    return r.toInt();
  }
}
