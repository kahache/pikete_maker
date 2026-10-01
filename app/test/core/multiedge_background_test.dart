import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/borders.dart';
import 'package:piketemaker/core/color_engine/palette.dart' show srgbToLab;

/// Behavioral mirror of the multi-edge section of `cv_core/tests/test_borders.py`
/// (issue #84): synthetics that isolate the MECHANISM (>= 3 distinct edges =
/// background; centered subject untouched; frame-filling guardrail). The
/// bit-level parity against colorlab's exact output lives in
/// `product_mode_parity_test.dart` (golden fixture `product_mode_D24.json`).

const List<int> _productBlue = <int>[40, 90, 180];
const List<int> _wall = <int>[95, 105, 120];
const List<int> _floor = <int>[150, 110, 85];

/// Plain (full-L) deltaE-76 between two RGB colors, same as the Python tests'
/// `_delta_e` helper.
double _deltaE(List<int> a, List<int> b) {
  final List<double> la =
      srgbToLab(<double>[a[0].toDouble(), a[1].toDouble(), a[2].toDouble()]);
  final List<double> lb =
      srgbToLab(<double>[b[0].toDouble(), b[1].toDouble(), b[2].toDouble()]);
  double sum = 0;
  for (int d = 0; d < 3; d++) {
    sum += (la[d] - lb[d]) * (la[d] - lb[d]);
  }
  return math.sqrt(sum);
}

/// Flat row-major frame filled with [bg]; [paint] overrides regions.
List<int> _frame(
    int height,
    int width,
    List<int> bg,
    void Function(
            void Function(int r0, int r1, int c0, int c1, List<int> color) fill)
        paint) {
  final List<int> rgb = List<int>.filled(height * width * 3, 0);
  void fill(int r0, int r1, int c0, int c1, List<int> color) {
    for (int r = r0; r < r1; r++) {
      for (int c = c0; c < c1; c++) {
        final int p = (r * width + c) * 3;
        rgb[p] = color[0];
        rgb[p + 1] = color[1];
        rgb[p + 2] = color[2];
      }
    }
  }

  fill(0, height, 0, width, bg);
  paint(fill);
  return rgb;
}

/// Centered subject over a wall (top half) + floor (bottom half) background:
/// each background tone is present on 3 edges, the centered subject on none.
/// Mirror of `_wrapping_bg_photo` (scaled down: pure-Dart LAB per pixel).
(List<int>, int, int) _wrappingBgPhoto() {
  const int height = 170;
  const int width = 130;
  final List<int> rgb = _frame(height, width, _wall,
      (void Function(int, int, int, int, List<int>) fill) {
    fill(height ~/ 2, height, 0, width, _floor);
    fill((0.26 * height).toInt(), (0.74 * height).toInt(),
        (0.33 * width).toInt(), (0.67 * width).toInt(), _productBlue);
  });
  return (rgb, height, width);
}

void main() {
  test('kMultiEdgeMin is three (the CEO false-positive-safe threshold)', () {
    expect(kMultiEdgeMin, 3);
  });

  test('flags colors wrapping three edges, never the centered subject', () {
    final (List<int> rgb, int height, int width) = _wrappingBgPhoto();
    final List<List<int>> bg = estimateMultiedgeBackground(rgb, height, width);
    expect(bg, isNotEmpty, reason: 'wrapping background not detected');
    expect(bg.any((List<int> c) => _deltaE(c, _wall) < 12), isTrue,
        reason: 'wall missed: $bg');
    expect(bg.any((List<int> c) => _deltaE(c, _floor) < 12), isTrue,
        reason: 'floor missed: $bg');
    expect(bg.every((List<int> c) => _deltaE(c, _productBlue) >= 12), isTrue,
        reason: 'subject wrongly flagged: $bg');
  });

  test('ignores a subject sharing only the bottom edge (>= 3 rule)', () {
    const int height = 170;
    const int width = 130;
    const List<int> wall = <int>[200, 200, 200];
    const List<int> ground = <int>[60, 140, 90];
    final List<int> rgb = _frame(height, width, wall,
        (void Function(int, int, int, int, List<int>) fill) {
      fill((0.80 * height).toInt(), height, 0, width, ground);
    });
    final List<List<int>> bg = estimateMultiedgeBackground(rgb, height, width);
    expect(bg.any((List<int> c) => _deltaE(c, wall) < 12), isTrue,
        reason: '3-edge wall not flagged: $bg');
    expect(bg.every((List<int> c) => _deltaE(c, ground) >= 12), isTrue,
        reason: 'a bottom-only color was wrongly flagged as background: $bg');
  });

  test('the mask drops the wrapping background and keeps the subject', () {
    final (List<int> rgb, int height, int width) = _wrappingBgPhoto();
    final List<bool> mask = productBackgroundMask(rgb, height, width);
    expect(mask.any((bool d) => d), isTrue);
    expect(mask.every((bool d) => d), isFalse);
    // Center (subject) kept; a top-edge sample (wall) dropped.
    final int center = (height ~/ 2) * width + width ~/ 2;
    expect(mask[center], isFalse, reason: 'subject center was dropped');
    expect(mask[2 * width + width ~/ 2], isTrue,
        reason: 'top-edge background was not dropped');
  });

  test('guardrail: a frame-filling subject suppresses nothing', () {
    const int height = 150;
    const int width = 120;
    final List<int> rgb = _frame(height, width, _productBlue,
        (void Function(int, int, int, int, List<int>) fill) {});
    final List<bool> mask = productBackgroundMask(rgb, height, width);
    expect(mask.any((bool d) => d), isFalse,
        reason: 'guardrail failed: frame-filling subject would be dropped');
  });
}
