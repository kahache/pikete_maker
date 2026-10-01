import 'dart:math' as math;
import 'dart:typed_data';

import 'garment_segmenter.dart';
import 'mask_hygiene.dart';
import 'raster_ops.dart';

/// I2 condition C1 — mask hardening for the recolor (D38), OPT-IN.
///
/// Dart port of the hardening layer of `cv_core/src/colorlab/segmentation.py`
/// (the canonical reference with tests; parity pinned by
/// `test/core/fixtures/recolor_parity_I2.json`). The palette path can live
/// with a blocky, holed or fragmented clothes mask (erosion + K-means average
/// the defects away); a RECOLOR cannot — it paints every mask error onto the
/// user's own photo. So:
///
///  - [resampleClassMapSmooth] — smooth class contours instead of the 256-px
///    nearest staircase (`resample_class_map_smooth`);
///  - [fillClothesHoles] — small enclosed holes filled, skin/hair kept, the
///    face-only-island exception (`fill_clothes_holes`);
///  - [dropDetachedClothes] — clothes not on the person dropped (a coat on a
///    hook) (`drop_detached_clothes`);
///  - [hipSplitRow] — the waist instead of the bbox mid-row when there is
///    one (`hip_split_row`);
///  - [hardenClassMap] / [splitHardenedGarmentMasks] — the composition
///    (`harden_class_map`, `split_garment_masks(..., harden=)`).
///
/// OPT-IN: nothing here is called by the palette path. The per-garment
/// analysis the result screen shows (`analyzeSegmentedFrame`, the
/// `MediaPipeGarmentSegmenter.buildMasks` mid-row split + `applyGarmentGuards`)
/// is untouched, so every existing golden fixture stays byte-identical.

/// MediaPipe Selfie Multiclass class ids (D21) — mirror of
/// `colorlab.segmentation.CLASS_*` and of the `MediaPipeGarmentSegmenter`
/// constants (a test pins the three together). Do not renumber.
abstract final class SegClass {
  /// Background.
  static const int background = 0;

  /// Hair.
  static const int hair = 1;

  /// Body skin.
  static const int bodySkin = 2;

  /// Face skin.
  static const int faceSkin = 3;

  /// Clothes — the only class a garment region is cut from.
  static const int clothes = 4;

  /// Others (accessories).
  static const int others = 5;

  /// Number of classes.
  static const int count = 6;
}

/// Minimum clothes coverage of the frame (MIN_CLOTHES_COVERAGE).
const double kMinClothesCoverage = 0.01;

/// Gaussian sigma (TARGET px) of the smoothed resample
/// (CLASS_MAP_SMOOTH_SIGMA): one model cell at 512 px.
const double kClassMapSmoothSigma = 1.5;

/// Enclosed holes below this fraction of the clothes area are filled
/// (HOLE_MAX_FRACTION).
const double kHoleMaxFraction = 0.05;

/// A clothes component touching skin/hair/others within this many px is on
/// the person (PERSON_ADJACENCY_PX).
const int kPersonAdjacencyPx = 1;

/// Clothes components below this fraction of the clothes area are speckle
/// (SPECKLE_MIN_FRACTION).
const double kSpeckleMinFraction = 0.01;

/// Start of the waist search band, fraction of the clothes bbox height from
/// its top (HIP_SEARCH_BAND[0]).
const double kHipSearchBandStart = 0.30;

/// End of the waist search band (HIP_SEARCH_BAND[1]); it stops before the
/// crotch dip.
const double kHipSearchBandEnd = 0.55;

/// Width-profile smoothing window as a fraction of the bbox height
/// (HIP_PROFILE_SMOOTH_FRACTION).
const double kHipProfileSmoothFraction = 0.04;

/// A waist is narrower than this × the widest row on both sides
/// (HIP_WAIST_MAX_RATIO).
const double kHipWaistMaxRatio = 0.85;

/// Waist guard (HIP_WAIST_MIN_UPPER_SHARE, 2026-10-01): a waist is trusted
/// only when the UPPER region it yields (clothes pixels on rows < the waist
/// row) holds at least this share of the whole clothes area; otherwise the
/// split falls back to the mid-row. It stops the head-pixelated selfie24
/// false waist (a raised sleeve labelled "others" leaves a narrow flat torso;
/// the argmin landed mid-shirt and the lower shirt was painted with the
/// trousers). VERIFIED in Python: no decision change on the 65 eval masks.
/// Spec: `docs/architecture/2026-10-01_1411_F2_I2-waist-guard.md`.
const double kHipWaistMinUpperShare = 0.30;

/// Recolor-only growth of the clothes mask into background/others
/// (RECOLOR_GROW_PX).
const int kRecolorGrowPx = 2;

/// Options of [hardenClassMap] / [splitHardenedGarmentMasks] — mirror of
/// Python's `MaskHardening` dataclass.
class MaskHardening {
  /// Every step ON except the growth, like Python's `MaskHardening()`.
  const MaskHardening({
    this.fillHoles = true,
    this.holeMaxFraction = kHoleMaxFraction,
    this.dropDetached = true,
    this.speckleMinFraction = kSpeckleMinFraction,
    this.hipSplit = true,
    this.growPx = 0,
  });

  /// Fill small enclosed holes ([fillClothesHoles]).
  final bool fillHoles;

  /// Hole-size limit, fraction of the clothes area.
  final double holeMaxFraction;

  /// Drop clothes components not on the person ([dropDetachedClothes]).
  final bool dropDetached;

  /// Speckle limit, fraction of the clothes area.
  final double speckleMinFraction;

  /// Split at the waist when there is one ([hipSplitRow]).
  final bool hipSplit;

  /// Growth of the clothes mask into background/others, px (0 = none).
  final int growPx;

  /// Same options with another [growPx] (the service scales it with the
  /// render size).
  MaskHardening withGrowPx(int px) => MaskHardening(
        fillHoles: fillHoles,
        holeMaxFraction: holeMaxFraction,
        dropDetached: dropDetached,
        speckleMinFraction: speckleMinFraction,
        hipSplit: hipSplit,
        growPx: px,
      );
}

/// `DEFAULT_HARDENING`.
const MaskHardening kDefaultHardening = MaskHardening();

/// `RECOLOR_HARDENING`: the recolor path preset (growth on).
const MaskHardening kRecolorHardening = MaskHardening(growPx: kRecolorGrowPx);

bool _isProtected(int cls) =>
    cls == SegClass.hair ||
    cls == SegClass.bodySkin ||
    cls == SegClass.faceSkin;

Uint8List _classMask(Uint8List classMap, int cls) {
  final Uint8List out = Uint8List(classMap.length);
  for (int i = 0; i < classMap.length; i++) {
    if (classMap[i] == cls) out[i] = 1;
  }
  return out;
}

void _checkMap(Uint8List classMap, int width, int height) {
  if (classMap.length != width * height) {
    throw ArgumentError(
        'class map length ${classMap.length} != $width*$height');
  }
}

/// Class map → (`width` × `height`) class map with SMOOTH class contours
/// (`resample_class_map_smooth`): one-hot plane per class, resized, Gaussian
/// blurred with [sigma] target px and arg-maxed (ties → the lowest class id).
///
/// Resize convention: bilinear with OpenCV's half-pixel centres (the
/// `INTER_LINEAR` Python uses when the target is at least as large as the
/// source — the app's case: the 256-side model map upscaled to the photo).
/// Python switches to `INTER_AREA` when the target is SMALLER (a full-size
/// stored mask shrunk to 512); that branch is not ported and a smaller
/// target is refused with an [ArgumentError] so it cannot silently differ.
///
/// Memory: one running best plane + one label plane + two scratch planes
/// (the six class planes are never alive together).
///
/// SPEED (exact): when enlarging with a blur, only the BAND of pixels whose
/// bilinear + blur support touches a class boundary is computed; a pixel
/// whose whole support lies in one class has that class as its argmax by
/// construction (every plane is exactly one-hot there). The band pixels go
/// through the same arithmetic as [resampleClassMapSmoothDense], in the same
/// order, so the output is identical (pinned by a test) — ~3× faster at the
/// story size, where the boundary band is a fraction of the frame.
Uint8List resampleClassMapSmooth(
  Uint8List classMap,
  int srcWidth,
  int srcHeight,
  int width,
  int height, {
  double sigma = kClassMapSmoothSigma,
}) {
  _checkMap(classMap, srcWidth, srcHeight);
  final bool resize = width != srcWidth || height != srcHeight;
  if (!resize || sigma <= 0 || width * height < srcWidth * srcHeight) {
    return resampleClassMapSmoothDense(
        classMap, srcWidth, srcHeight, width, height,
        sigma: sigma);
  }
  final Float64List kernel =
      gaussianKernel(gaussianKsizeForFloat(sigma), sigma);
  final int r = kernel.length ~/ 2;
  final int n = width * height;

  // 1. Source cells whose neighbourhood (Chebyshev radius `reach`) is not a
  //    single class. `reach` covers the blur half-width in source cells plus
  //    the bilinear tap and a safety cell.
  final Uint8List edge = Uint8List(classMap.length);
  for (int y = 0; y < srcHeight; y++) {
    for (int x = 0; x < srcWidth; x++) {
      final int c = classMap[y * srcWidth + x];
      if ((x + 1 < srcWidth && classMap[y * srcWidth + x + 1] != c) ||
          (y + 1 < srcHeight && classMap[(y + 1) * srcWidth + x] != c)) {
        edge[y * srcWidth + x] = 1;
        if (x + 1 < srcWidth && classMap[y * srcWidth + x + 1] != c) {
          edge[y * srcWidth + x + 1] = 1;
        }
        if (y + 1 < srcHeight && classMap[(y + 1) * srcWidth + x] != c) {
          edge[(y + 1) * srcWidth + x] = 1;
        }
      }
    }
  }
  final double cellsPerPx =
      math.max(srcWidth / width, srcHeight / height).toDouble();
  final int reach = (r * cellsPerPx).ceil() + 2;
  final Uint8List mixedSrc = dilateMask(edge, srcWidth, srcHeight, reach);

  // 2. Every pixel starts as its nearest cell's class; band pixels (M) are
  //    recomputed below.
  final Int32List cellX = Int32List(width);
  final Int32List cellY = Int32List(height);
  for (int x = 0; x < width; x++) {
    cellX[x] = math.min(srcWidth - 1, ((x + 0.5) * srcWidth / width).floor());
  }
  for (int y = 0; y < height; y++) {
    cellY[y] =
        math.min(srcHeight - 1, ((y + 0.5) * srcHeight / height).floor());
  }
  final Uint8List label = Uint8List(n);
  final Uint8List band = Uint8List(n);
  bool anyBand = false;
  final Set<int> bandClasses = <int>{};
  for (int y = 0; y < height; y++) {
    final int srow = cellY[y] * srcWidth;
    for (int x = 0; x < width; x++) {
      final int cell = srow + cellX[x];
      if (mixedSrc[cell] != 0) {
        band[y * width + x] = 1;
        anyBand = true;
      } else {
        label[y * width + x] = classMap[cell];
      }
    }
  }
  if (!anyBand) return label;
  for (int i = 0; i < classMap.length; i++) {
    if (mixedSrc[i] != 0) bandClasses.add(classMap[i]);
  }

  // Rows / pixels the horizontal pass must produce: the band dilated
  // vertically by r (the reflected rows stay within r too).
  final Uint8List hBand = Uint8List(n);
  final Uint8List rowNeeded = Uint8List(height);
  for (int x = 0; x < width; x++) {
    int last = -1 << 30;
    for (int y = 0; y < height; y++) {
      if (band[y * width + x] != 0) last = y;
      if (y - last <= r) hBand[y * width + x] = 1;
    }
    last = 1 << 30;
    for (int y = height - 1; y >= 0; y--) {
      if (band[y * width + x] != 0) last = y;
      if (last - y <= r) hBand[y * width + x] = 1;
    }
  }
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (hBand[y * width + x] != 0) {
        rowNeeded[y] = 1;
        break;
      }
    }
  }

  final Int32List xs0 = Int32List(width), xs1 = Int32List(width);
  final Float32List fxs = Float32List(width);
  final Int32List ys0 = Int32List(height), ys1 = Int32List(height);
  final Float32List fys = Float32List(height);
  _bilinearTaps(srcWidth, width, xs0, xs1, fxs);
  _bilinearTaps(srcHeight, height, ys0, ys1, fys);

  final Float32List best = Float32List(n);
  final Float32List tmp = Float32List(n);
  final Float32List plane = Float32List(width);
  final Float32List row0 = Float32List(width), row1 = Float32List(width);
  final Float32List src = Float32List(srcWidth * srcHeight);
  final Float32List f32 = Float32List(1); // float32 store, like the dense plane
  for (int c = 0; c < SegClass.count; c++) {
    // A class absent from every band cell has an exactly-zero plane on the
    // band: it can never win there.
    if (!bandClasses.contains(c)) continue;
    for (int i = 0; i < classMap.length; i++) {
      src[i] = classMap[i] == c ? 1 : 0;
    }
    int lastRow0 = -1, lastRow1 = -1;
    for (int y = 0; y < height; y++) {
      if (rowNeeded[y] == 0) continue;
      final int sy0 = ys0[y], sy1 = ys1[y];
      if (sy0 != lastRow0 || sy1 != lastRow1) {
        _hResizeRow(src, srcWidth, sy0, xs0, xs1, fxs, row0);
        _hResizeRow(src, srcWidth, sy1, xs0, xs1, fxs, row1);
        lastRow0 = sy0;
        lastRow1 = sy1;
      }
      final double fy = fys[y];
      final double gy = 1 - fy;
      for (int x = 0; x < width; x++) {
        plane[x] = row0[x] * gy + row1[x] * fy;
      }
      final int row = y * width;
      for (int x = 0; x < width; x++) {
        if (hBand[row + x] == 0) continue;
        double acc = 0;
        if (x - r >= 0 && x + r < width) {
          final int base = x - r;
          for (int k = 0; k < kernel.length; k++) {
            acc += kernel[k] * plane[base + k];
          }
        } else {
          for (int k = 0; k < kernel.length; k++) {
            acc += kernel[k] * plane[_reflect101(x + k - r, width)];
          }
        }
        tmp[row + x] = acc;
      }
    }
    for (int y = 0; y < height; y++) {
      final bool interior = y - r >= 0 && y + r < height;
      final int row = y * width;
      for (int x = 0; x < width; x++) {
        if (band[row + x] == 0) continue;
        double acc = 0;
        if (interior) {
          int idx = (y - r) * width + x;
          for (int k = 0; k < kernel.length; k++) {
            acc += kernel[k] * tmp[idx];
            idx += width;
          }
        } else {
          for (int k = 0; k < kernel.length; k++) {
            acc += kernel[k] * tmp[_reflect101(y + k - r, height) * width + x];
          }
        }
        // Same float32 store + strict > as the dense path (ties -> lowest id).
        f32[0] = acc;
        final double v = f32[0];
        if (v > best[row + x]) {
          best[row + x] = v;
          label[row + x] = c;
        }
      }
    }
  }
  return label;
}

int _reflect101(int i, int n) {
  if (n == 1) return 0;
  while (i < 0 || i >= n) {
    if (i < 0) i = -i;
    if (i >= n) i = 2 * n - 2 - i;
  }
  return i;
}

/// The straightforward full-frame implementation of
/// [resampleClassMapSmooth] (every class plane over the whole frame). Used
/// directly when there is no blur or no resize, and as the reference the
/// band-limited fast path is tested against.
Uint8List resampleClassMapSmoothDense(
  Uint8List classMap,
  int srcWidth,
  int srcHeight,
  int width,
  int height, {
  double sigma = kClassMapSmoothSigma,
}) {
  _checkMap(classMap, srcWidth, srcHeight);
  if (width * height < srcWidth * srcHeight) {
    throw ArgumentError('resampleClassMapSmooth only enlarges '
        '($srcWidth x $srcHeight -> $width x $height)');
  }
  final bool resize = width != srcWidth || height != srcHeight;
  final Float64List? kernel =
      sigma > 0 ? gaussianKernel(gaussianKsizeForFloat(sigma), sigma) : null;
  final int n = width * height;
  final Float32List best = Float32List(n);
  final Uint8List label = Uint8List(n);

  // Bilinear taps, shared by every class plane.
  final Int32List xs0 = Int32List(width), xs1 = Int32List(width);
  final Float32List fxs = Float32List(width);
  final Int32List ys0 = Int32List(height), ys1 = Int32List(height);
  final Float32List fys = Float32List(height);
  if (resize) {
    _bilinearTaps(srcWidth, width, xs0, xs1, fxs);
    _bilinearTaps(srcHeight, height, ys0, ys1, fys);
  }

  final Set<int> present = <int>{for (final int c in classMap) c};
  for (int c = 0; c < SegClass.count; c++) {
    // An absent class is an all-zero plane; the present planes sum to ~1 at
    // every pixel, so it can never win the argmax: skip it.
    if (!present.contains(c)) continue;
    Float32List plane;
    if (resize) {
      final Float32List src = Float32List(srcWidth * srcHeight);
      for (int i = 0; i < classMap.length; i++) {
        if (classMap[i] == c) src[i] = 1;
      }
      plane = Float32List(n);
      int lastRow0 = -1, lastRow1 = -1;
      final Float32List row0 = Float32List(width), row1 = Float32List(width);
      for (int y = 0; y < height; y++) {
        final int sy0 = ys0[y], sy1 = ys1[y];
        if (sy0 != lastRow0 || sy1 != lastRow1) {
          _hResizeRow(src, srcWidth, sy0, xs0, xs1, fxs, row0);
          _hResizeRow(src, srcWidth, sy1, xs0, xs1, fxs, row1);
          lastRow0 = sy0;
          lastRow1 = sy1;
        }
        final double fy = fys[y];
        final double gy = 1 - fy;
        final int row = y * width;
        for (int x = 0; x < width; x++) {
          plane[row + x] = row0[x] * gy + row1[x] * fy;
        }
      }
    } else {
      plane = Float32List(n);
      for (int i = 0; i < n; i++) {
        if (classMap[i] == c) plane[i] = 1;
      }
    }
    if (kernel != null) {
      plane = gaussianBlurPlane(plane, width, height, kernel);
    }
    for (int i = 0; i < n; i++) {
      // Strict > keeps the LOWEST class id on a tie (numpy argmax = first).
      if (plane[i] > best[i]) {
        best[i] = plane[i];
        label[i] = c;
      }
    }
  }
  return label;
}

/// OpenCV `INTER_LINEAR` source taps for one axis: `f = (d + 0.5) * scale -
/// 0.5`, `s = floor(f)`; below 0 → (0, weight 0); at or past the last
/// source index → (last, weight 0).
void _bilinearTaps(
    int src, int dst, Int32List s0, Int32List s1, Float32List frac) {
  final double scale = src / dst;
  for (int d = 0; d < dst; d++) {
    double f = (d + 0.5) * scale - 0.5;
    int s = f.floor();
    f -= s;
    if (s < 0) {
      s = 0;
      f = 0;
    }
    if (s >= src - 1) {
      s = src - 1;
      f = 0;
    }
    s0[d] = s;
    s1[d] = s + 1 < src ? s + 1 : src - 1;
    frac[d] = f;
  }
}

void _hResizeRow(Float32List src, int srcWidth, int sy, Int32List xs0,
    Int32List xs1, Float32List fxs, Float32List out) {
  final int base = sy * srcWidth;
  for (int x = 0; x < out.length; x++) {
    final double fx = fxs[x];
    out[x] = src[base + xs0[x]] * (1 - fx) + src[base + xs1[x]] * fx;
  }
}

/// Clothes mask (0/1) with the small ENCLOSED holes filled
/// (`fill_clothes_holes`): a 4-connected non-clothes component not touching
/// the frame edge and below [maxFraction] of the clothes area is filled on
/// its background/others pixels; skin and hair inside it stay — except a
/// hole made only of face skin with no hair/body-skin pixel (a printed face
/// or a model misfire), which is filled whole. Returns a NEW mask.
Uint8List fillClothesHoles(Uint8List classMap, int width, int height,
    {double maxFraction = kHoleMaxFraction}) {
  _checkMap(classMap, width, height);
  final Uint8List clothes = _classMask(classMap, SegClass.clothes);
  final int clothesArea = maskPixelCount(clothes);
  if (clothesArea == 0) {
    return clothes;
  }
  final Uint8List notClothes = Uint8List(clothes.length);
  for (int i = 0; i < clothes.length; i++) {
    notClothes[i] = clothes[i] == 0 ? 1 : 0;
  }
  final Components cc =
      labelComponents(notClothes, width, height, eightConnected: false);
  // Per component: fillable? anchored (has hair or body skin)?
  final List<bool> fillable = List<bool>.filled(cc.count + 1, false);
  for (int id = 1; id <= cc.count; id++) {
    final int k = id - 1;
    final bool touchesEdge = cc.minX[k] == 0 ||
        cc.minY[k] == 0 ||
        cc.maxX[k] == width - 1 ||
        cc.maxY[k] == height - 1;
    fillable[id] = !touchesEdge && cc.areas[k] < maxFraction * clothesArea;
  }
  final List<bool> anchored = List<bool>.filled(cc.count + 1, false);
  for (int i = 0; i < classMap.length; i++) {
    final int id = cc.labels[i];
    if (id != 0 && fillable[id]) {
      final int cls = classMap[i];
      if (cls == SegClass.hair || cls == SegClass.bodySkin) anchored[id] = true;
    }
  }
  final Uint8List out = Uint8List.fromList(clothes);
  for (int i = 0; i < classMap.length; i++) {
    final int id = cc.labels[i];
    if (id == 0 || !fillable[id]) continue;
    if (anchored[id] && _isProtected(classMap[i])) continue;
    out[i] = 1;
  }
  return out;
}

/// Clothes mask (0/1) without the components that are not on the person
/// (`drop_detached_clothes`): 8-connected clothes components are kept when
/// they touch skin/hair/others within [adjacencyPx] AND are at least
/// [speckleMinFraction] of the clothes area; if none is attached, the
/// largest one is kept. Returns a NEW mask.
Uint8List dropDetachedClothes(Uint8List classMap, int width, int height,
    {double speckleMinFraction = kSpeckleMinFraction,
    int adjacencyPx = kPersonAdjacencyPx}) {
  _checkMap(classMap, width, height);
  final Uint8List clothes = _classMask(classMap, SegClass.clothes);
  final Components cc =
      labelComponents(clothes, width, height, eightConnected: true);
  if (cc.count <= 1) {
    return clothes;
  }
  int clothesArea = 0;
  for (int k = 0; k < cc.count; k++) {
    clothesArea += cc.areas[k];
  }
  final Uint8List attachment = Uint8List(classMap.length);
  for (int i = 0; i < classMap.length; i++) {
    final int cls = classMap[i];
    if (_isProtected(cls) || cls == SegClass.others) attachment[i] = 1;
  }
  final Uint8List nearPerson =
      dilateMask(attachment, width, height, adjacencyPx);
  final List<bool> keep = List<bool>.filled(cc.count + 1, false);
  for (int i = 0; i < classMap.length; i++) {
    final int id = cc.labels[i];
    if (id == 0 || keep[id] || nearPerson[i] == 0) continue;
    if (cc.areas[id - 1] < speckleMinFraction * clothesArea) continue;
    keep[id] = true;
  }
  if (!keep.contains(true)) {
    int largest = 0;
    for (int k = 1; k < cc.count; k++) {
      if (cc.areas[k] > cc.areas[largest]) largest = k;
    }
    keep[largest + 1] = true;
  }
  final Uint8List out = Uint8List(classMap.length);
  for (int i = 0; i < classMap.length; i++) {
    final int id = cc.labels[i];
    if (id != 0 && keep[id]) out[i] = 1;
  }
  return out;
}

/// Upper/lower split of a clothes mask (`hip_split_row`): the first row of
/// the LOWER region and whether it came from a waist (else the v1 bbox
/// mid-row). Throws [ArgumentError] on an empty mask.
///
/// [minUpperShare] is the waist guard ([kHipWaistMinUpperShare]); tests pass
/// 0 to reproduce the pre-guard rule (Python monkeypatches the constant).
({int row, bool fromWaist}) hipSplitRow(
    Uint8List clothes, int width, int height,
    {double minUpperShare = kHipWaistMinUpperShare}) {
  final Int32List profileCounts = Int32List(height);
  int top = -1, bottom = -1;
  for (int y = 0; y < height; y++) {
    int count = 0;
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      if (clothes[row + x] != 0) count++;
    }
    profileCounts[y] = count;
    if (count > 0) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  if (top < 0) {
    throw ArgumentError('empty clothes mask: nothing to split');
  }
  final int mid = (top + bottom) ~/ 2;
  final int bboxHeight = bottom - top + 1;
  final int lo = top + (kHipSearchBandStart * bboxHeight).floor();
  final int hi = top + (kHipSearchBandEnd * bboxHeight).floor();
  if (hi - lo < 3) {
    return (row: mid, fromWaist: false);
  }
  // np.convolve(profile, ones(window) / window, mode="same"), odd window,
  // zero padding.
  final int window =
      math.max(3, (kHipProfileSmoothFraction * bboxHeight).floor() | 1);
  final double w = 1.0 / window;
  final int half = (window - 1) ~/ 2;
  final Float64List smooth = Float64List(height);
  for (int y = 0; y < height; y++) {
    double acc = 0;
    for (int k = -half; k <= half; k++) {
      final int yy = y + k;
      if (yy >= 0 && yy < height) acc += profileCounts[yy] * w;
    }
    smooth[y] = acc;
  }
  int row = lo;
  for (int y = lo + 1; y <= hi; y++) {
    if (smooth[y] < smooth[row]) row = y; // first minimum, like np.argmin
  }
  if (row == lo || row == hi) {
    return (row: mid, fromWaist: false); // monotone in the band: no waist
  }
  double widestAbove = smooth[top];
  for (int y = top; y < row; y++) {
    widestAbove = math.max(widestAbove, smooth[y]);
  }
  double widestBelow = smooth[row + 1];
  for (int y = row + 1; y <= bottom; y++) {
    widestBelow = math.max(widestBelow, smooth[y]);
  }
  if (smooth[row] > kHipWaistMaxRatio * math.min(widestAbove, widestBelow)) {
    return (row: mid, fromWaist: false);
  }
  // Waist guard: the "waist" must not leave a stub top.
  int upper = 0;
  int total = 0;
  for (int y = 0; y < height; y++) {
    if (y < row) upper += profileCounts[y];
    total += profileCounts[y];
  }
  if (upper < minUpperShare * total) {
    return (row: mid, fromWaist: false);
  }
  return (row: row, fromWaist: true);
}

/// Class map with a hardened CLOTHES class, other classes untouched
/// (`harden_class_map`): detached drop (→ background), hole fill (→ clothes),
/// growth of `options.growPx` into background/others. Returns a NEW map.
Uint8List hardenClassMap(Uint8List classMap, int width, int height,
    [MaskHardening options = kDefaultHardening]) {
  _checkMap(classMap, width, height);
  Uint8List clothes = options.dropDetached
      ? dropDetachedClothes(classMap, width, height,
          speckleMinFraction: options.speckleMinFraction)
      : _classMask(classMap, SegClass.clothes);
  final Uint8List out = Uint8List.fromList(classMap);
  for (int i = 0; i < out.length; i++) {
    if (classMap[i] == SegClass.clothes && clothes[i] == 0) {
      out[i] = SegClass.background;
    }
  }
  if (options.fillHoles) {
    clothes = fillClothesHoles(out, width, height,
        maxFraction: options.holeMaxFraction);
    for (int i = 0; i < out.length; i++) {
      if (clothes[i] != 0) out[i] = SegClass.clothes;
    }
  }
  if (options.growPx > 0) {
    final Uint8List grown = dilateMask(clothes, width, height, options.growPx);
    for (int i = 0; i < out.length; i++) {
      if (grown[i] != 0 && !_isProtected(out[i])) out[i] = SegClass.clothes;
    }
  }
  return out;
}

/// Result of [splitHardenedGarmentMasks].
class HardenedSplit {
  /// Creates a split of a [width]×[height] frame.
  const HardenedSplit({
    required this.width,
    required this.height,
    required this.hardenedMap,
    required this.splitRow,
    required this.fromWaist,
    required this.masks,
  });

  /// Frame width.
  final int width;

  /// Frame height.
  final int height;

  /// The hardened class map the regions were cut from.
  final Uint8List hardenedMap;

  /// First row of the lower region.
  final int splitRow;

  /// Whether [splitRow] is a detected waist (else the bbox mid-row).
  final bool fromWaist;

  /// The surviving regions, upper first (0/1 masks, `width * height`).
  final Map<GarmentRegion, Uint8List> masks;

  /// As a [GarmentSegmentation] (the shape `analyzeSegmentedFrame` takes).
  GarmentSegmentation toSegmentation() =>
      GarmentSegmentation(width: width, height: height, masks: masks);
}

/// `split_garment_masks(class_map, erode_px=, min_region_fraction=,
/// harden=options)`: harden the RAW [classMap], check the clothes coverage,
/// split at [hipSplitRow] (or the mid-row when `options.hipSplit` is off),
/// erode each region by [erodePx] and drop regions under
/// [minRegionFraction] of the frame. Throws [SegmentationException]
/// (`isNoPerson`) like Python's `NoPersonError`.
///
/// Pass the RAW map: the growth is not idempotent.
HardenedSplit splitHardenedGarmentMasks(
  Uint8List classMap,
  int width,
  int height, {
  MaskHardening options = kRecolorHardening,
  int erodePx = kMaskErodePx,
  double minRegionFraction = kMinRegionFraction,
}) {
  final Uint8List hardened = hardenClassMap(classMap, width, height, options);
  final Uint8List clothes = _classMask(hardened, SegClass.clothes);
  final int n = width * height;
  if (maskPixelCount(clothes) < n * kMinClothesCoverage) {
    throw const SegmentationException(
      'no dressed person found (clothes coverage below threshold)',
      isNoPerson: true,
    );
  }
  int top = -1, bottom = -1;
  for (int y = 0; y < height && top < 0; y++) {
    for (int x = 0; x < width; x++) {
      if (clothes[y * width + x] != 0) {
        top = y;
        break;
      }
    }
  }
  for (int y = height - 1; y >= 0 && bottom < 0; y--) {
    for (int x = 0; x < width; x++) {
      if (clothes[y * width + x] != 0) {
        bottom = y;
        break;
      }
    }
  }
  int mid = (top + bottom) ~/ 2;
  bool fromWaist = false;
  if (options.hipSplit) {
    final ({int row, bool fromWaist}) split =
        hipSplitRow(clothes, width, height);
    mid = split.row;
    fromWaist = split.fromWaist;
  }
  final Uint8List upper = Uint8List(n);
  final Uint8List lower = Uint8List(n);
  for (int i = 0; i < n; i++) {
    if (clothes[i] == 0) continue;
    if (i ~/ width < mid) {
      upper[i] = 1;
    } else {
      lower[i] = 1;
    }
  }
  final Map<GarmentRegion, Uint8List> masks = <GarmentRegion, Uint8List>{};
  for (final (GarmentRegion, Uint8List) entry in <(GarmentRegion, Uint8List)>[
    (GarmentRegion.upper, upper),
    (GarmentRegion.lower, lower),
  ]) {
    final Uint8List eroded = erodeMask(entry.$2, width, height, erodePx);
    if (maskPixelCount(eroded) < n * minRegionFraction) continue;
    masks[entry.$1] = eroded;
  }
  if (masks.isEmpty) {
    throw const SegmentationException(
      'no garment region survived erosion + min-size guards',
      isNoPerson: true,
    );
  }
  return HardenedSplit(
    width: width,
    height: height,
    hardenedMap: hardened,
    splitRow: mid,
    fromWaist: fromWaist,
    masks: masks,
  );
}

/// Nearest-neighbour upscale of a square model map to (width, height) — the
/// exact index arithmetic of `MediaPipeGarmentSegmenter` / Python's
/// `upscale_class_map` (`my = y * side ~/ height`): the RAW map the
/// applicability metrics are defined on.
Uint8List upscaleClassMapNearest(
    Uint8List map, int srcWidth, int srcHeight, int width, int height) {
  _checkMap(map, srcWidth, srcHeight);
  if (width == srcWidth && height == srcHeight) {
    return Uint8List.fromList(map);
  }
  final Uint8List out = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    final int srow = (y * srcHeight ~/ height) * srcWidth;
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      out[row + x] = map[srow + (x * srcWidth ~/ width)];
    }
  }
  return out;
}
