import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mask_hardening.dart';
import 'package:piketemaker/core/segmentation/raster_ops.dart';

import '../recolor/recolor_scene.dart';

/// Unit tests of the I2 hardening port beyond the Python parity fixture
/// (`recolor_parity_test.dart`): the band-limited fast path of the smoothed
/// resample must equal the dense reference EXACTLY, and the raster
/// primitives keep their OpenCV border semantics.

Uint8List _noisyMap(int side, int seed) {
  // Blobby random map: random class discs on a background.
  final math.Random rng = math.Random(seed);
  final Uint8List map = Uint8List(side * side);
  for (int k = 0; k < 40; k++) {
    final double cx = rng.nextDouble() * side;
    final double cy = rng.nextDouble() * side;
    final double rad = 3 + rng.nextDouble() * side / 6;
    final int cls = rng.nextInt(SegClass.count);
    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        final double dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy <= rad * rad) map[y * side + x] = cls;
      }
    }
  }
  return map;
}

void main() {
  group('resampleClassMapSmooth fast path == dense reference', () {
    final Map<String, Uint8List> maps = <String, Uint8List>{
      'scene': sceneModelMap(),
      'two people': sceneModelMap(twoPeople: true),
      'random blobs': _noisyMap(256, 7),
    };
    const List<(int, int, double)> sizes = <(int, int, double)>[
      (384, 512, 1.5),
      (779, 1038, 1.5 * 1038 / 512),
      (300, 301, 0.8),
    ];
    for (final MapEntry<String, Uint8List> m in maps.entries) {
      for (final (int, int, double) size in sizes) {
        test('${m.key} -> ${size.$1}x${size.$2} sigma ${size.$3}', () {
          final Uint8List fast = resampleClassMapSmooth(
              m.value, 256, 256, size.$1, size.$2,
              sigma: size.$3);
          final Uint8List dense = resampleClassMapSmoothDense(
              m.value, 256, 256, size.$1, size.$2,
              sigma: size.$3);
          int diff = 0;
          for (int i = 0; i < fast.length; i++) {
            if (fast[i] != dense[i]) diff++;
          }
          expect(diff, 0);
        });
      }
    }
  });

  test('a shrinking resample is refused (INTER_AREA not ported)', () {
    expect(() => resampleClassMapSmooth(Uint8List(100), 10, 10, 5, 5),
        throwsArgumentError);
  });

  test('dilateMask ignores out-of-bounds neighbours (cv2 default border)', () {
    final Uint8List m = Uint8List(25)..[0] = 1; // 5x5, top-left pixel
    final Uint8List d = dilateMask(m, 5, 5, 1);
    expect(d.where((int v) => v == 1).length, 4); // 2x2 corner, no wrap
    expect(d[6], 1);
    expect(d[12], 0);
  });

  test('labelComponents: 4- vs 8-connectivity, raster-ordered ids', () {
    // Two diagonal pixels + a separate one.
    final Uint8List m = Uint8List(16);
    m[0] = 1; // (0,0)
    m[5] = 1; // (1,1) diagonal to (0,0)
    m[15] = 1; // (3,3)
    final Components four = labelComponents(m, 4, 4, eightConnected: false);
    final Components eight = labelComponents(m, 4, 4, eightConnected: true);
    expect(four.count, 3);
    expect(eight.count, 2);
    expect(eight.labels[0], 1);
    expect(eight.labels[5], 1);
    expect(eight.labels[15], 2);
    expect(eight.areas.toList(), <int>[2, 1]);
    expect((eight.minX[0], eight.maxX[0]), (0, 1));
  });

  test('gaussianKernel matches the OpenCV sizes and sums to 1', () {
    expect(gaussianKsizeForFloat(1.5), 13);
    final Float64List k = gaussianKernel(11, 1.5);
    expect(k.reduce((double a, double b) => a + b), closeTo(1, 1e-12));
    expect(k[5], greaterThan(k[4]));
    expect(k[0], closeTo(k[10], 1e-15));
  });

  group('waist guard (HIP_WAIST_MIN_UPPER_SHARE, mirrors Python)', () {
    // Frame + silhouette helper of cv_core/tests/test_mask_hardening.py.
    const int h = 320, w = 240, top = 40, center = 120;
    Uint8List silhouette(List<int> widths) {
      final Uint8List m = Uint8List(w * h);
      for (int i = 0; i < widths.length; i++) {
        for (int x = center - widths[i] ~/ 2;
            x < center + widths[i] ~/ 2;
            x++) {
          m[(top + i) * w + x] = 1;
        }
      }
      return m;
    }

    List<int> rep(int value, int n) => List<int>.filled(n, value);
    // A raised sleeve mislabelled "others": a narrow flat torso widening to
    // the hips; the argmin lands 1 row inside the band edge (row 95).
    final List<int> edgeMinimum = <int>[
      ...rep(50, 50),
      ...rep(42, 5),
      ...rep(38, 4),
      ...rep(120, 121),
    ];
    // A true waist whose top is just above the guard (upper share ~0.31).
    final List<int> trueWaist = <int>[
      ...rep(100, 55),
      ...rep(60, 15),
      ...rep(110, 110),
    ];
    double upperShare(Uint8List m, int row) {
      int up = 0, all = 0;
      for (int i = 0; i < m.length; i++) {
        if (m[i] == 0) continue;
        all++;
        if (i ~/ w < row) up++;
      }
      return up / all;
    }

    test('an edge minimum that leaves a stub top falls back to the mid-row',
        () {
      final Uint8List clothes = silhouette(edgeMinimum);
      final ({int row, bool fromWaist}) raw =
          hipSplitRow(clothes, w, h, minUpperShare: 0);
      expect(raw, (row: 95, fromWaist: true), reason: 'the pre-guard rule');
      expect(upperShare(clothes, raw.row), lessThan(kHipWaistMinUpperShare));
      expect(hipSplitRow(clothes, w, h), (row: 129, fromWaist: false),
          reason: '(40 + 40 + 180 - 1) ~/ 2');
    });

    test('a true waist with a full top is kept', () {
      final Uint8List clothes = silhouette(trueWaist);
      final ({int row, bool fromWaist}) split = hipSplitRow(clothes, w, h);
      expect(split, (row: 98, fromWaist: true));
      expect(upperShare(clothes, split.row),
          greaterThanOrEqualTo(kHipWaistMinUpperShare));
    });

    test('end to end: the fallback reaches the recolor regions', () {
      final Uint8List map = Uint8List(w * h);
      void paint(int y0, int y1, int x0, int x1, int cls) {
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            map[y * w + x] = cls;
          }
        }
      }

      paint(10, 22, 100, 140, SegClass.hair);
      paint(22, 34, 102, 138, SegClass.faceSkin);
      paint(34, 40, 110, 130, SegClass.bodySkin);
      final Uint8List clothes = silhouette(edgeMinimum);
      for (int i = 0; i < clothes.length; i++) {
        if (clothes[i] != 0) map[i] = SegClass.clothes;
      }
      final HardenedSplit split =
          splitHardenedGarmentMasks(map, w, h, erodePx: 0);
      int lastRow(Uint8List m) {
        for (int y = h - 1; y >= 0; y--) {
          for (int x = 0; x < w; x++) {
            if (m[y * w + x] != 0) return y;
          }
        }
        return -1;
      }

      int firstRow(Uint8List m) {
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            if (m[y * w + x] != 0) return y;
          }
        }
        return -1;
      }

      final int upperLast = lastRow(split.masks[GarmentRegion.upper]!);
      final int lowerFirst = firstRow(split.masks[GarmentRegion.lower]!);
      expect(upperLast + 1, lowerFirst);
      expect(lowerFirst, greaterThan(40 + 70),
          reason: 'well below the stub-top row (95)');
      expect(split.fromWaist, isFalse);
    });
  });
}
