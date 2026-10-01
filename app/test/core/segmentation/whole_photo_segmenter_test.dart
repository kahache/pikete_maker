import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/whole_photo_segmenter.dart';

/// [WholePhotoSegmenter] is the MVP no-op: it must select EVERY pixel as one
/// [GarmentRegion.whole] region, and feeding its mask through
/// [extractRgbaPixels] must be byte-identical to passing no mask (the
/// zero-regression guarantee).
///
/// Uses a small SYNTHETIC RGBA buffer (a fake — no real model, no image codec).

/// A `width * height` RGBA buffer with varied opaque colors.
Uint8List _syntheticRgba(int width, int height) {
  final int n = width * height;
  final Uint8List rgba = Uint8List(n * 4);
  for (int i = 0; i < n; i++) {
    rgba[i * 4] = (i * 3) % 256;
    rgba[i * 4 + 1] = (i * 5) % 256;
    rgba[i * 4 + 2] = (i * 7) % 256;
    rgba[i * 4 + 3] = 255; // opaque
  }
  return rgba;
}

void main() {
  const WholePhotoSegmenter segmenter = WholePhotoSegmenter();

  test('produces a single whole region covering every pixel', () async {
    const int width = 4;
    const int height = 4;
    final Uint8List rgba = _syntheticRgba(width, height);

    final GarmentSegmentation seg =
        await segmenter.segment(rgba, width, height);

    expect(seg.width, width);
    expect(seg.height, height);
    expect(seg.regions, <GarmentRegion>[GarmentRegion.whole]);

    final Uint8List? mask = seg.maskFor(GarmentRegion.whole);
    expect(mask, isNotNull);
    expect(mask!.length, width * height);
    expect(mask.every((int v) => v == 1), isTrue);

    // The other regions are absent (whole-photo has no top/bottom split).
    expect(seg.maskFor(GarmentRegion.upper), isNull);
    expect(seg.maskFor(GarmentRegion.lower), isNull);
  });

  test('its mask is a no-op for extractRgbaPixels (zero regression)', () async {
    final Uint8List rgba = _syntheticRgba(20, 20);
    final GarmentSegmentation seg = await segmenter.segment(rgba, 20, 20);

    final Float64List withMask =
        extractRgbaPixels(rgba, mask: seg.maskFor(GarmentRegion.whole));
    final Float64List withoutMask = extractRgbaPixels(rgba);

    expect(withMask, withoutMask);
  });
}
