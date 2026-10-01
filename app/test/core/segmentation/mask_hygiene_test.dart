import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mask_hygiene.dart';

/// Unit tests for the #89 mask-hygiene guards, mirroring the split/erosion/
/// guard behaviors of `cv_core/tests/test_segmentation.py` (the canonical
/// suite) on the Dart side. The cross-language byte parity itself is pinned
/// by `garment_parity_test.dart`; these tests document the CONTRACT so a
/// future refactor cannot silently change it.

const int _w = 50;
const int _h = 50;

/// A 0/1 mask with a filled rectangle [r0, r1) × [c0, c1).
Uint8List _rect(int r0, int r1, int c0, int c1, {int w = _w, int h = _h}) {
  final Uint8List mask = Uint8List(w * h);
  for (int y = r0; y < r1; y++) {
    for (int x = c0; x < c1; x++) {
      mask[y * w + x] = 1;
    }
  }
  return mask;
}

GarmentSegmentation _segmentation(Map<GarmentRegion, Uint8List> masks,
        {int w = _w, int h = _h}) =>
    GarmentSegmentation(width: w, height: h, masks: masks);

void main() {
  group('erodeMask (5×5 square min-filter, cv2.erode parity)', () {
    test('removes the 2-px boundary ring, interior survives', () {
      // Mirror of test_erode_mask_removes_boundary_ring.
      final Uint8List mask = _rect(10, 40, 10, 40);
      final Uint8List eroded = erodeMask(mask, _w, _h, 2);
      for (int y = 12; y < 38; y++) {
        for (int x = 12; x < 38; x++) {
          expect(eroded[y * _w + x], 1,
              reason: 'interior ($x,$y) must survive');
        }
      }
      for (int x = 10; x < 40; x++) {
        expect(eroded[10 * _w + x], 0, reason: 'boundary row 10 must be gone');
        expect(eroded[11 * _w + x], 0, reason: 'boundary row 11 must be gone');
      }
      for (int y = 10; y < 40; y++) {
        expect(eroded[y * _w + 10], 0);
        expect(eroded[y * _w + 11], 0);
      }
    });

    test('radius 0 is a no-op (same object)', () {
      final Uint8List mask = _rect(10, 40, 10, 40);
      expect(identical(erodeMask(mask, _w, _h, 0), mask), isTrue);
    });

    test('image-border pixels are NOT eroded from out of bounds', () {
      // cv2.erode's default border value is +inf for erosion: a mask touching
      // the frame edge keeps its frame-edge pixels. The Dart min-filter must
      // ignore out-of-bounds neighbors the same way (parity-critical: a
      // full-bleed garment would otherwise lose 2 px Python keeps).
      final Uint8List mask = _rect(0, 20, 0, 20);
      final Uint8List eroded = erodeMask(mask, _w, _h, 2);
      expect(eroded[0], 1,
          reason: 'corner (0,0) survives: no out-of-bounds erosion');
      expect(eroded[17 * _w + 17], 1);
      expect(eroded[19 * _w + 19], 0, reason: 'inner boundary still erodes');
      expect(eroded[18 * _w + 5], 0,
          reason: 'row 18 is within 2 of the mask edge');
    });

    test('eroded mask is a strict subset of the input', () {
      // Mirror of test_split_masks_erosion_shrinks_regions (subset property).
      final Uint8List mask = _rect(5, 45, 5, 45);
      final Uint8List eroded = erodeMask(mask, _w, _h, 2);
      expect(maskPixelCount(eroded), lessThan(maskPixelCount(mask)));
      for (int i = 0; i < mask.length; i++) {
        if (eroded[i] == 1) {
          expect(mask[i], 1, reason: 'erosion can never ADD a pixel');
        }
      }
    });
  });

  group('applyGarmentGuards (#89: erosion + min-region, feeds S3/S4)', () {
    test('both solid regions survive, eroded', () {
      final GarmentSegmentation guarded = applyGarmentGuards(_segmentation(
        <GarmentRegion, Uint8List>{
          GarmentRegion.upper: _rect(5, 25, 10, 40),
          GarmentRegion.lower: _rect(25, 45, 10, 40),
        },
      ));
      expect(guarded.regions.toList(),
          <GarmentRegion>[GarmentRegion.upper, GarmentRegion.lower]);
      // 20×30 → post-erosion 16×26.
      expect(maskPixelCount(guarded.maskFor(GarmentRegion.upper)!), 16 * 26);
      expect(maskPixelCount(guarded.maskFor(GarmentRegion.lower)!), 16 * 26);
    });

    test('a tiny region is dropped (min-region guard → single, S3)', () {
      // Mirror of test_split_masks_min_region_guard_drops_tiny_garment:
      // 6×8 sliver → 2×4 = 8 px post-erosion < 0.5% of 2500 (12.5).
      final GarmentSegmentation guarded = applyGarmentGuards(_segmentation(
        <GarmentRegion, Uint8List>{
          GarmentRegion.upper: _rect(5, 25, 10, 40),
          GarmentRegion.lower: _rect(30, 36, 20, 28),
        },
      ));
      expect(guarded.regions.toList(), <GarmentRegion>[GarmentRegion.upper]);
    });

    test('no region survives → SegmentationException isNoPerson', () {
      // Mirror of test_split_masks_no_region_survives_guards_is_no_person:
      // 1-px-thin stripes erode to nothing.
      final Uint8List thin = Uint8List(_w * _h);
      for (int y = 5; y < 45; y += 4) {
        for (int x = 5; x < 45; x++) {
          thin[y * _w + x] = 1;
        }
      }
      expect(
        () => applyGarmentGuards(_segmentation(
            <GarmentRegion, Uint8List>{GarmentRegion.upper: thin})),
        throwsA(isA<SegmentationException>().having(
            (SegmentationException e) => e.isNoPerson, 'isNoPerson', isTrue)),
      );
    });

    test('a whole-only segmentation degrades as no-person (defensive)', () {
      // If the flag is ever turned on with a segmenter that only emits
      // `whole` (e.g. WholePhotoSegmenter), the guards find no garment
      // regions and degrade loudly → the engine falls back to today's
      // whole-photo path instead of producing a wrong per-garment answer.
      final Uint8List whole = Uint8List(_w * _h)..fillRange(0, _w * _h, 1);
      expect(
        () => applyGarmentGuards(_segmentation(
            <GarmentRegion, Uint8List>{GarmentRegion.whole: whole})),
        throwsA(isA<SegmentationException>().having(
            (SegmentationException e) => e.isNoPerson, 'isNoPerson', isTrue)),
      );
    });
  });
}
