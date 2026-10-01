import 'dart:typed_data';

import 'garment_segmenter.dart';

/// Mask hygiene guards for the per-garment split (Phase 2.5, issue #89) —
/// Dart parity of the two v1 guards in
/// `cv_core/src/colorlab/segmentation.py::split_garment_masks` (steps 3-4).
///
/// The spike's `MediaPipeGarmentSegmenter.buildMasks` does steps 1-2 (clothes
/// coverage check + bbox mid-row split); this module adds, ON TOP of any
/// [GarmentSegmentation]:
///
///  1. per-REGION erosion of [kMaskErodePx] px ([erodeMask]): the 256→full-res
///     nearest upscale leaves blocky edges, so a few boundary pixels of every
///     garment mask are really background/skin — eroding keeps that bleed out
///     of the palette. Eroding per region (not the whole clothes mask) also
///     trims the upper/lower seam, so hem-transition pixels vote in neither.
///  2. the min-region guard ([kMinRegionFraction]): a post-erosion region under
///     0.5% of the frame is absent (chest-up framing ⇒ no `lower` palette from
///     a waistband sliver). This guard is what feeds the single-region result
///     (state S3 of the per-garment UX spec).
///
/// If NO region survives, [SegmentationException] with `isNoPerson` — the same
/// loud degrade as the coverage check (mirror of Python's `NoPersonError`),
/// so callers fall back to the whole-photo pipeline, never a silent wrong
/// answer.

/// Pixels eroded from each region mask before sampling (MASK_ERODE_PX in
/// segmentation.py). Radius 2 ⇒ a 5×5 square kernel, matching cv2.erode.
const int kMaskErodePx = 2;

/// A garment region smaller than this fraction of the FRAME (after erosion)
/// is treated as absent (MIN_REGION_FRACTION in segmentation.py).
const double kMinRegionFraction = 0.005;

/// Erodes a 0/1 mask by [radius] px with a SQUARE (2·radius+1)² kernel —
/// the exact cv2.erode semantics `erode_mask` uses in Python: a pixel
/// survives iff every IN-BOUNDS neighbor within Chebyshev distance [radius]
/// is 1 (cv2's default border value for erosion is +∞, so out-of-bounds
/// neighbors never erase a pixel at the image border). `radius <= 0` returns
/// the mask unchanged (same no-op contract as Python).
///
/// Implemented as two separable 1-D min passes (a square min-filter is
/// separable), so it is O(n·radius) instead of O(n·radius²).
Uint8List erodeMask(Uint8List mask, int width, int height, int radius) {
  if (radius <= 0) {
    return mask;
  }
  assert(
      mask.length == width * height, 'mask length must equal width * height');
  // Pass 1: horizontal min over [x-radius, x+radius] (in-bounds only).
  final Uint8List horizontal = Uint8List(mask.length);
  for (int y = 0; y < height; y++) {
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      int min = 1;
      final int x0 = (x - radius < 0) ? 0 : x - radius;
      final int x1 = (x + radius >= width) ? width - 1 : x + radius;
      for (int xx = x0; xx <= x1; xx++) {
        if (mask[row + xx] == 0) {
          min = 0;
          break;
        }
      }
      horizontal[row + x] = min;
    }
  }
  // Pass 2: vertical min over [y-radius, y+radius] (in-bounds only).
  final Uint8List out = Uint8List(mask.length);
  for (int y = 0; y < height; y++) {
    final int y0 = (y - radius < 0) ? 0 : y - radius;
    final int y1 = (y + radius >= height) ? height - 1 : y + radius;
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      int min = 1;
      for (int yy = y0; yy <= y1; yy++) {
        if (horizontal[yy * width + x] == 0) {
          min = 0;
          break;
        }
      }
      out[row + x] = min;
    }
  }
  return out;
}

/// Number of selected (1) pixels in a 0/1 mask.
int maskPixelCount(Uint8List mask) {
  int count = 0;
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] != 0) {
      count++;
    }
  }
  return count;
}

/// Applies the two v1 hygiene guards (erosion + min-region) to the
/// upper/lower masks of [segmentation], returning a NEW [GarmentSegmentation]
/// containing only the surviving regions (upper first, same order contract as
/// Python's ordered dict).
///
/// Throws [SegmentationException] with `isNoPerson: true` when no region
/// survives — the caller falls back to the whole-photo pipeline (silent
/// degrade per the UX spec, loud in code per the engine contract).
GarmentSegmentation applyGarmentGuards(
  GarmentSegmentation segmentation, {
  int erodePx = kMaskErodePx,
  double minRegionFraction = kMinRegionFraction,
}) {
  final int frame = segmentation.width * segmentation.height;
  final Map<GarmentRegion, Uint8List> survivors = <GarmentRegion, Uint8List>{};
  for (final GarmentRegion region in <GarmentRegion>[
    GarmentRegion.upper,
    GarmentRegion.lower
  ]) {
    final Uint8List? mask = segmentation.maskFor(region);
    if (mask == null) {
      continue;
    }
    final Uint8List eroded =
        erodeMask(mask, segmentation.width, segmentation.height, erodePx);
    if (maskPixelCount(eroded) < frame * minRegionFraction) {
      continue; // absent garment (e.g. chest-up framing) — feeds S3
    }
    survivors[region] = eroded;
  }
  if (survivors.isEmpty) {
    throw const SegmentationException(
      'no garment region survived erosion + min-size guards',
      isNoPerson: true,
    );
  }
  return GarmentSegmentation(
    width: segmentation.width,
    height: segmentation.height,
    masks: survivors,
  );
}
