import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart raster primitives for the I2 mask hardening and the recolor
/// (D38) — the handful of OpenCV operations `colorlab.segmentation` /
/// `colorlab.recolor` use, written by hand because the app has no `image`
/// package (APK weight, gate G1). Same spirit as `erodeMask` in
/// `mask_hygiene.dart`: plain loops over row-major buffers, no allocation per
/// pixel, isolate-safe (top-level functions, no state).
///
/// OpenCV semantics mirrored (and where they matter):
///  - [dilateMask]: square kernel, out-of-bounds neighbours IGNORED (OpenCV's
///    default border value for dilation is -inf), the mirror of `erodeMask`;
///  - [gaussianKernel] / [gaussianBlurPlane]: `cv2.getGaussianKernel` weights
///    (computed, normalized to sum 1) applied separably with the default
///    `BORDER_REFLECT_101` (`gfedcb|abcdefgh|gfedcba`);
///  - [labelComponents]: `cv2.connectedComponentsWithStats` areas and
///    bounding boxes. Label NUMBERS are internal (never compared with
///    OpenCV's); they follow the raster order of each component's first
///    pixel, which is also how OpenCV numbers them.

/// Dilates a 0/1 mask by [radius] px with a SQUARE (2·radius+1)² kernel: a
/// pixel is set iff any IN-BOUNDS neighbour within Chebyshev distance
/// [radius] is set (`cv2.dilate` with the default border). Separable (two
/// 1-D max passes). `radius <= 0` returns a copy.
Uint8List dilateMask(Uint8List mask, int width, int height, int radius) {
  if (radius <= 0) {
    return Uint8List.fromList(mask);
  }
  final Uint8List horizontal = Uint8List(mask.length);
  for (int y = 0; y < height; y++) {
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      final int x0 = x - radius < 0 ? 0 : x - radius;
      final int x1 = x + radius >= width ? width - 1 : x + radius;
      for (int xx = x0; xx <= x1; xx++) {
        if (mask[row + xx] != 0) {
          horizontal[row + x] = 1;
          break;
        }
      }
    }
  }
  final Uint8List out = Uint8List(mask.length);
  for (int y = 0; y < height; y++) {
    final int y0 = y - radius < 0 ? 0 : y - radius;
    final int y1 = y + radius >= height ? height - 1 : y + radius;
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      for (int yy = y0; yy <= y1; yy++) {
        if (horizontal[yy * width + x] != 0) {
          out[row + x] = 1;
          break;
        }
      }
    }
  }
  return out;
}

/// `cv2.getGaussianKernel(ksize, sigma)` for `sigma > 0`: weights
/// `exp(-x² / (2σ²))` at `x = i - (ksize-1)/2`, normalized to sum 1.
Float64List gaussianKernel(int ksize, double sigma) {
  final Float64List kernel = Float64List(ksize);
  final double scale = -0.5 / (sigma * sigma);
  double sum = 0;
  for (int i = 0; i < ksize; i++) {
    final double x = i - (ksize - 1) * 0.5;
    kernel[i] = math.exp(scale * x * x);
    sum += kernel[i];
  }
  for (int i = 0; i < ksize; i++) {
    kernel[i] /= sum;
  }
  return kernel;
}

/// Kernel size OpenCV derives for `GaussianBlur(src, (0, 0), sigma)` on a
/// FLOAT image: `cvRound(sigma * 4 * 2 + 1) | 1`.
int gaussianKsizeForFloat(double sigma) => (sigma * 8 + 1).round() | 1;

/// `BORDER_REFLECT_101` index into `[0, n)`.
int _reflect101(int i, int n) {
  if (n == 1) return 0;
  while (i < 0 || i >= n) {
    if (i < 0) i = -i;
    if (i >= n) i = 2 * n - 2 - i;
  }
  return i;
}

/// Separable Gaussian blur of a float plane (`cv2.GaussianBlur` with the
/// default `BORDER_REFLECT_101`), returning a NEW plane.
///
/// Only the output rectangle `[x0, x1] × [y0, y1]` (inclusive, clamped to the
/// frame) is computed; everything else in the returned plane is 0. Callers
/// that re-mask the result (the recolor feather) pass the region's bounding
/// box, which makes the blur O(bbox) instead of O(frame). Defaults = the
/// whole frame.
Float32List gaussianBlurPlane(
  Float32List plane,
  int width,
  int height,
  Float64List kernel, {
  int x0 = 0,
  int y0 = 0,
  int? x1,
  int? y1,
}) {
  final int r = kernel.length ~/ 2;
  final int ox0 = math.max(0, x0);
  final int oy0 = math.max(0, y0);
  final int ox1 = math.min(width - 1, x1 ?? width - 1);
  final int oy1 = math.min(height - 1, y1 ?? height - 1);
  final Float32List out = Float32List(plane.length);
  if (ox1 < ox0 || oy1 < oy0) {
    return out;
  }
  // Horizontal pass on every row the vertical pass will read (with the
  // reflection, rows outside [oy0 - r, oy1 + r] are never read).
  final int hy0 = math.max(0, oy0 - r);
  final int hy1 = math.min(height - 1, oy1 + r);
  final Float32List tmp = Float32List(plane.length);
  final bool xInterior = ox0 - r >= 0 && ox1 + r < width;
  for (int y = hy0; y <= hy1; y++) {
    final int row = y * width;
    for (int x = ox0; x <= ox1; x++) {
      double acc = 0;
      if (xInterior || (x - r >= 0 && x + r < width)) {
        final int base = row + x - r;
        for (int k = 0; k < kernel.length; k++) {
          acc += kernel[k] * plane[base + k];
        }
      } else {
        for (int k = 0; k < kernel.length; k++) {
          acc += kernel[k] * plane[row + _reflect101(x + k - r, width)];
        }
      }
      tmp[row + x] = acc;
    }
  }
  for (int y = oy0; y <= oy1; y++) {
    final bool interior = y - r >= 0 && y + r < height;
    for (int x = ox0; x <= ox1; x++) {
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
      out[y * width + x] = acc;
    }
  }
  return out;
}

/// Connected components of the set pixels of a 0/1 mask, with the stats of
/// `cv2.connectedComponentsWithStats` (area + bounding box per component).
class Components {
  Components._(this.labels, this.count, this.areas, this.minX, this.minY,
      this.maxX, this.maxY);

  /// Per-pixel label: 0 = not in the mask, 1..[count] = component id.
  final Int32List labels;

  /// Number of components (labels 1..count).
  final int count;

  /// `areas[id - 1]` = pixel count of component `id`.
  final Int32List areas;

  /// Inclusive bounding box of component `id` at index `id - 1`: left.
  final Int32List minX;

  /// Top of the bounding box.
  final Int32List minY;

  /// Right of the bounding box (inclusive).
  final Int32List maxX;

  /// Bottom of the bounding box (inclusive).
  final Int32List maxY;
}

/// Labels the set pixels of [mask] (4- or 8-connectivity) with an explicit
/// stack flood fill in raster order, so ids follow the raster order of each
/// component's first pixel.
Components labelComponents(Uint8List mask, int width, int height,
    {required bool eightConnected}) {
  final Int32List labels = Int32List(mask.length);
  final List<int> areas = <int>[];
  final List<int> minX = <int>[];
  final List<int> minY = <int>[];
  final List<int> maxX = <int>[];
  final List<int> maxY = <int>[];
  final Int32List stack = Int32List(mask.length);
  int next = 0;
  for (int start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || labels[start] != 0) continue;
    next++;
    int area = 0;
    int bx0 = width, by0 = height, bx1 = -1, by1 = -1;
    int sp = 0;
    stack[sp++] = start;
    labels[start] = next;
    while (sp > 0) {
      final int p = stack[--sp];
      final int y = p ~/ width;
      final int x = p - y * width;
      area++;
      if (x < bx0) bx0 = x;
      if (x > bx1) bx1 = x;
      if (y < by0) by0 = y;
      if (y > by1) by1 = y;
      for (int dy = -1; dy <= 1; dy++) {
        final int ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          if (!eightConnected && dx != 0 && dy != 0) continue;
          final int nx = x + dx;
          if (nx < 0 || nx >= width) continue;
          final int q = ny * width + nx;
          if (mask[q] != 0 && labels[q] == 0) {
            labels[q] = next;
            stack[sp++] = q;
          }
        }
      }
    }
    areas.add(area);
    minX.add(bx0);
    minY.add(by0);
    maxX.add(bx1);
    maxY.add(by1);
  }
  return Components._(
    labels,
    next,
    Int32List.fromList(areas),
    Int32List.fromList(minX),
    Int32List.fromList(minY),
    Int32List.fromList(maxX),
    Int32List.fromList(maxY),
  );
}
