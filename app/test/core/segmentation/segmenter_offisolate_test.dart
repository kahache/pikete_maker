import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mediapipe_garment_segmenter.dart';

/// A4 (r13): [MediaPipeGarmentSegmenter] off the UI isolate + model preload.
///
/// The host runner has no native TFLite library, so the NATIVE steps (model
/// load, `invoke()`, close) are replaced through the constructor test seams;
/// everything else — the single-flight load, the serialization queue, the
/// worker-isolate hop and the pure pre/post-processing — is the production
/// code. The inference fake is a TOP-LEVEL function because it really runs
/// inside the worker isolate (a closure over test state would not be
/// sendable), exactly like the production `invokeModel`.

const int _side = MediaPipeGarmentSegmenter.modelSide;
const int _classes = MediaPipeGarmentSegmenter.numClasses;

/// Deterministic stand-in for the model: per model pixel, "clothes" where the
/// red input channel dominates, "hair" where blue does, background elsewhere.
/// Scores carry fractional parts derived from the input so the argmax sees
/// realistic floats, not just 0/1.
Float32List _fakeInference(int address, Float32List input) {
  final Float32List scores = Float32List(_side * _side * _classes);
  for (int i = 0; i < _side * _side; i++) {
    final double r = input[i * 3];
    final double g = input[i * 3 + 1];
    final double b = input[i * 3 + 2];
    final int base = i * _classes;
    for (int c = 0; c < _classes; c++) {
      scores[base + c] = 0.1 * c * g;
    }
    if (r > 0.5 && r > b) {
      scores[base + MediaPipeGarmentSegmenter.clothesClassIndex] = 1.0 + r;
    } else if (b > 0.5) {
      scores[base + MediaPipeGarmentSegmenter.hairClassIndex] = 1.0 + b;
    } else {
      scores[base + MediaPipeGarmentSegmenter.backgroundClassIndex] = 1.0 + g;
    }
  }
  return scores;
}

Float32List _throwingInference(int address, Float32List input) =>
    throw StateError('native invoke failed');

/// 64×80 opaque frame: gray wall, a red "outfit" block (rows 20..69) and a
/// blue "hair" patch on top — enough clothes coverage to pass buildMasks.
Uint8List _frame({int width = 64, int height = 80}) {
  final Uint8List rgba = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int o = (y * width + x) * 4;
      List<int> px = <int>[140, 140, 140];
      if (y >= 20 && y < 70 && x >= 12 && x < 52) {
        px = <int>[200 + (x % 7), 30 + (y % 5), 40];
      } else if (y >= 5 && y < 18 && x >= 22 && x < 42) {
        px = <int>[20, 30, 190];
      }
      rgba[o] = px[0];
      rgba[o + 1] = px[1];
      rgba[o + 2] = px[2];
      rgba[o + 3] = 255;
    }
  }
  return rgba;
}

/// Loader fake that counts calls and can be held open to create overlap.
class _CountingLoader {
  _CountingLoader({this.address = 0xABCD, this.error});

  final int address;
  final Object? error;
  int calls = 0;
  Completer<void>? gate;

  Future<int> call(int threads) async {
    calls++;
    if (gate != null) {
      await gate!.future;
    }
    if (error != null) {
      throw error!;
    }
    return address;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('single-flight model load (F12)', () {
    test('two concurrent warmUps share ONE load → one interpreter', () async {
      final _CountingLoader loader = _CountingLoader()
        ..gate = Completer<void>();
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: loader.call, inference: _fakeInference);

      // Both first calls start before the load finishes (the F12 window).
      final Future<void> a = segmenter.warmUp();
      final Future<void> b = segmenter.warmUp();
      await Future<void>.delayed(Duration.zero);
      expect(loader.calls, 1, reason: 'second warmUp must join the in-flight load');
      loader.gate!.complete();
      await Future.wait(<Future<void>>[a, b]);

      // A later warmUp and a segment() reuse it too.
      await segmenter.warmUp();
      await segmenter.segment(_frame(), 64, 80);
      expect(loader.calls, 1);
    });

    test('concurrent first segment() calls also share the load', () async {
      final _CountingLoader loader = _CountingLoader()
        ..gate = Completer<void>();
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: loader.call, inference: _fakeInference);
      final Uint8List frame = _frame();
      final Future<GarmentSegmentation> s1 = segmenter.segment(frame, 64, 80);
      final Future<void> w = segmenter.warmUp();
      final Future<GarmentSegmentation> s2 = segmenter.segment(frame, 64, 80);
      await Future<void>.delayed(Duration.zero);
      loader.gate!.complete();
      final List<Object?> done = await Future.wait(<Future<Object?>>[s1, w, s2]);
      expect(loader.calls, 1);
      final GarmentSegmentation r1 = done[0]! as GarmentSegmentation;
      final GarmentSegmentation r2 = done[2]! as GarmentSegmentation;
      expect(r1.maskFor(GarmentRegion.upper), r2.maskFor(GarmentRegion.upper));
      expect(r1.maskFor(GarmentRegion.lower), r2.maskFor(GarmentRegion.lower));
    });

    test('dispose frees the one interpreter once; the next use reloads',
        () async {
      final _CountingLoader loader = _CountingLoader(address: 777);
      final List<int> closed = <int>[];
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
        loader: loader.call,
        inference: _fakeInference,
        closer: closed.add,
      );
      await Future.wait(<Future<void>>[segmenter.warmUp(), segmenter.warmUp()]);
      await segmenter.dispose();
      await segmenter.dispose(); // idempotent
      expect(closed, <int>[777]);
      await segmenter.warmUp();
      expect(loader.calls, 2);
    });

    test('dispose waits for a queued inference before freeing', () async {
      final _CountingLoader loader = _CountingLoader(address: 5);
      final List<String> events = <String>[];
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
        loader: loader.call,
        inference: _fakeInference,
        closer: (int _) => events.add('closed'),
      );
      final Future<void> seg = segmenter
          .segment(_frame(), 64, 80)
          .then((GarmentSegmentation _) => events.add('segmented'));
      final Future<void> disposed = segmenter.dispose();
      await Future.wait(<Future<void>>[seg, disposed]);
      expect(events, <String>['segmented', 'closed']);
    });
  });

  group('load failure → typed, memoized, silent preload (S4 intact)', () {
    test('a failed load is wrapped, memoized and never retried', () async {
      final _CountingLoader loader =
          _CountingLoader(error: StateError('asset missing'));
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: loader.call, inference: _fakeInference);

      await segmenter.preload(); // must NOT throw
      await expectLater(
          segmenter.warmUp(), throwsA(isA<SegmentationException>()));
      await expectLater(segmenter.segment(_frame(), 64, 80),
          throwsA(isA<SegmentationException>().having(
              (SegmentationException e) => e.isNoPerson,
              'isNoPerson (model failure, not a no-person frame)',
              isFalse)));
      expect(loader.calls, 1, reason: 'F12: no 16 MB reload per analysis');
    });

    test('the real default loader degrades typed on the host (no native lib)',
        () async {
      // Production loader, unmocked: on the host either the gitignored asset
      // is missing or the worker isolate fails to open tensorflowlite_c.
      // Both must surface as the seam's typed error — the engine's S4 input.
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter();
      await segmenter.preload();
      await expectLater(segmenter.segment(_frame(), 64, 80),
          throwsA(isA<SegmentationException>()));
    });

    test('an inference failure inside the worker isolate crosses back typed',
        () async {
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: _CountingLoader().call, inference: _throwingInference);
      await expectLater(segmenter.segment(_frame(), 64, 80),
          throwsA(isA<SegmentationException>()));
      // The queue survives a failed call.
      await expectLater(segmenter.classify(_frame(), 64, 80),
          throwsA(isA<SegmentationException>()));
    });

    test('the runtime gate keeps the preload off the host test runner', () {
      expect(MediaPipeGarmentSegmenter.isRuntimeSupported, isFalse);
    });
  });

  group('off-isolate output is byte-identical to the on-isolate path', () {
    test('segment() == segmentFrame() run on the calling isolate', () async {
      final Uint8List frame = _frame();
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: _CountingLoader(address: 42).call,
          inference: _fakeInference);

      final GarmentSegmentation offIsolate =
          await segmenter.segment(frame, 64, 80);
      final GarmentSegmentation onIsolate = MediaPipeGarmentSegmenter
          .segmentFrame(frame, 64, 80, 42, _fakeInference);

      expect(offIsolate.width, onIsolate.width);
      expect(offIsolate.height, onIsolate.height);
      expect(offIsolate.regions.toList(), onIsolate.regions.toList());
      for (final GarmentRegion region in onIsolate.regions) {
        expect(offIsolate.maskFor(region), onIsolate.maskFor(region),
            reason: '$region mask must be byte-identical');
      }
      // Non-trivial: both garments were actually found.
      expect(onIsolate.maskFor(GarmentRegion.upper)!.contains(1), isTrue);
      expect(onIsolate.maskFor(GarmentRegion.lower)!.contains(1), isTrue);
    });

    test('classify() == classifyFrame() == the historical inline steps',
        () async {
      final Uint8List frame = _frame();
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: _CountingLoader().call, inference: _fakeInference);

      final Uint8List offIsolate = await segmenter.classify(frame, 64, 80);
      final Uint8List onIsolate = MediaPipeGarmentSegmenter.classifyFrame(
          frame, 64, 80, 0, _fakeInference);
      expect(offIsolate, onIsolate);

      // The pre-A4 body, step by step: preprocess → invoke → argmax →
      // nearest upscale (upscale re-derived here from its definition).
      final Uint8List map256 = MediaPipeGarmentSegmenter.argmax(
          _fakeInference(0, MediaPipeGarmentSegmenter.preprocess(frame, 64, 80)));
      final Uint8List upscaled = Uint8List(64 * 80);
      for (int y = 0; y < 80; y++) {
        for (int x = 0; x < 64; x++) {
          upscaled[y * 64 + x] =
              map256[(y * _side ~/ 80) * _side + (x * _side ~/ 64)];
        }
      }
      expect(offIsolate, upscaled);
    });

    test('a mismatched frame is rejected before touching the model', () async {
      final _CountingLoader loader = _CountingLoader();
      final MediaPipeGarmentSegmenter segmenter = MediaPipeGarmentSegmenter(
          loader: loader.call, inference: _fakeInference);
      await expectLater(segmenter.segment(Uint8List(10), 4, 4),
          throwsA(isA<SegmentationException>()));
      expect(loader.calls, 0);
    });
  });
}
