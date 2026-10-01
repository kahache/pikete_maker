import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mediapipe_garment_segmenter.dart';

/// [MediaPipeGarmentSegmenter] — the REAL TFLite impl (F2.5 spike). On the
/// host test runner the TFLite NATIVE library is not available (and on a
/// fresh clone the gitignored model asset is missing too), so [segment] must
/// degrade LOUDLY with a typed [SegmentationException] — never a silent
/// wrong answer. The pure-Dart pre/post-processing (resize, argmax, bbox
/// split) is fully testable here with synthetic buffers; the actual
/// inference is exercised on a device by
/// `integration_test/segmentation_spike_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('documents the model class map (argmax indices)', () {
    expect(MediaPipeGarmentSegmenter.backgroundClassIndex, 0);
    expect(MediaPipeGarmentSegmenter.hairClassIndex, 1);
    expect(MediaPipeGarmentSegmenter.bodySkinClassIndex, 2);
    expect(MediaPipeGarmentSegmenter.faceSkinClassIndex, 3);
    expect(MediaPipeGarmentSegmenter.clothesClassIndex, 4);
    expect(MediaPipeGarmentSegmenter.othersClassIndex, 5);
  });

  // The model-load failure path (missing tflite native lib / missing
  // gitignored asset → SegmentationException) was untestable here while the
  // load ran on the test isolate (tflite_flutter's lazy DynamicLibrary
  // failure leaked a second, unhandled zone error — 2026-07-14). Since A4
  // (r13) the native load runs in a worker isolate, so that failure stays
  // there and crosses back typed: it is now covered, with the single-flight
  // and off-isolate parity tests, in segmenter_offisolate_test.dart. The REAL
  // path (asset present + native lib present) is exercised on a device by
  // integration_test/segmentation_spike_test.dart.

  test('segment rejects an rgba buffer that does not match its dimensions',
      () async {
    final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter();
    await expectLater(
      segmenter.segment(Uint8List(10), 4, 4),
      throwsA(isA<SegmentationException>()),
    );
  });

  group('preprocess (bilinear resize + [0,1] normalization)', () {
    test('a uniform frame maps to a uniform normalized tensor', () {
      // 2x2 all-grey (128) → every model pixel must be 128/255 exactly.
      final Uint8List rgba = Uint8List.fromList(
        List<int>.filled(2 * 2 * 4, 128),
      );
      final Float32List input =
          MediaPipeGarmentSegmenter.preprocess(rgba, 2, 2);
      const int side = MediaPipeGarmentSegmenter.modelSide;
      expect(input.length, side * side * 3);
      expect(input.first, closeTo(128 / 255.0, 1e-6));
      expect(input.last, closeTo(128 / 255.0, 1e-6));
      expect(input.every((double v) => (v - 128 / 255.0).abs() < 1e-6), isTrue);
    });

    test('values stay in [0,1] for extreme channels', () {
      // 1x1 pure red: R=1.0, G=0.0, B=0.0 replicated everywhere.
      final Uint8List rgba = Uint8List.fromList(<int>[255, 0, 0, 255]);
      final Float32List input =
          MediaPipeGarmentSegmenter.preprocess(rgba, 1, 1);
      expect(input[0], closeTo(1.0, 1e-6)); // R
      expect(input[1], closeTo(0.0, 1e-6)); // G
      expect(input[2], closeTo(0.0, 1e-6)); // B
    });
  });

  test('argmax picks the winning class per pixel', () {
    const int side = MediaPipeGarmentSegmenter.modelSide;
    const int classes = MediaPipeGarmentSegmenter.numClasses;
    final Float32List scores = Float32List(side * side * classes);
    // Pixel 0 wins class 4 (clothes); pixel 1 wins class 1 (hair); the rest
    // win class 0 by default (all-zero scores → first index).
    scores[0 * classes + 4] = 0.9;
    scores[1 * classes + 1] = 0.7;
    final Uint8List map = MediaPipeGarmentSegmenter.argmax(scores);
    expect(map[0], MediaPipeGarmentSegmenter.clothesClassIndex);
    expect(map[1], MediaPipeGarmentSegmenter.hairClassIndex);
    expect(map[2], MediaPipeGarmentSegmenter.backgroundClassIndex);
  });

  group('buildMasks (bbox mid-row top/bottom split, D21 v1)', () {
    test('splits a clothes block into upper and lower at the bbox midpoint',
        () {
      // 16x16 frame, clothes filling rows 4..11 (bbox mid = (4+11)~/2 = 7):
      // upper = rows 4..6, lower = rows 7..11.
      const int w = 16, h = 16;
      final Uint8List classMap = Uint8List(w * h);
      for (int y = 4; y <= 11; y++) {
        for (int x = 0; x < w; x++) {
          classMap[y * w + x] = MediaPipeGarmentSegmenter.clothesClassIndex;
        }
      }
      final GarmentSegmentation seg =
          MediaPipeGarmentSegmenter.buildMasks(classMap, w, h);
      final Uint8List upper = seg.maskFor(GarmentRegion.upper)!;
      final Uint8List lower = seg.maskFor(GarmentRegion.lower)!;
      expect(seg.maskFor(GarmentRegion.whole), isNull);
      int upperCount = 0, lowerCount = 0;
      for (int i = 0; i < w * h; i++) {
        upperCount += upper[i];
        lowerCount += lower[i];
        // A pixel is never in both regions.
        expect(upper[i] & lower[i], 0);
      }
      expect(upperCount, 3 * w); // rows 4,5,6
      expect(lowerCount, 5 * w); // rows 7..11
      // Skin/background rows contribute nothing.
      expect(upper[0], 0);
      expect(lower[(h - 1) * w], 0);
    });

    test('throws isNoPerson when clothes coverage is under the threshold', () {
      const int w = 32, h = 32;
      final Uint8List classMap = Uint8List(w * h); // all background
      expect(
        () => MediaPipeGarmentSegmenter.buildMasks(classMap, w, h),
        throwsA(isA<SegmentationException>().having(
            (SegmentationException e) => e.isNoPerson, 'isNoPerson', isTrue)),
      );
    });
  });
}
