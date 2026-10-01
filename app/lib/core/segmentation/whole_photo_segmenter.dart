import 'dart:typed_data';

import 'garment_segmenter.dart';

/// DEFAULT [GarmentSegmenter]: no segmentation — the whole photo is one region.
///
/// This reproduces today's MVP behavior EXACTLY (D1, whole-photo palette): it
/// returns a single [GarmentRegion.whole] mask with every pixel selected, so
/// wiring the color engine with it is a strict no-op (the palette pipeline sees
/// the same pixels it sees today; the alpha filter still discards transparent
/// ones independently). It lets the whole app depend on the [GarmentSegmenter]
/// seam BEFORE the real model exists, with zero behavioral change and zero new
/// dependency (gate G1).
///
/// When the MediaPipe port lands ([MediaPipeGarmentSegmenter]), only the
/// registration in `ColorEngineDart` swaps to it — nothing else changes.
class WholePhotoSegmenter implements GarmentSegmenter {
  /// Creates the identity segmenter: one [GarmentRegion.whole] region.
  const WholePhotoSegmenter();

  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    final int pixelCount = width * height;
    // Every pixel selected. `fillRange(0, n, 1)` — a fresh all-ones mask.
    final Uint8List whole = Uint8List(pixelCount)..fillRange(0, pixelCount, 1);
    return GarmentSegmentation(
      width: width,
      height: height,
      masks: <GarmentRegion, Uint8List>{GarmentRegion.whole: whole},
    );
  }
}
