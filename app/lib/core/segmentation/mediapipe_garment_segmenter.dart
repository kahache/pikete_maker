import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'garment_segmenter.dart';

/// Loads the model and returns the ADDRESS of the native TFLite interpreter
/// (A4). An address — not an [Interpreter] object — is what can cross isolate
/// boundaries: the interpreter lives in the native heap (process-wide, no
/// Dart finalizer), so any isolate can rebuild a handle with
/// [Interpreter.fromAddress]. This is the same mechanism tflite_flutter's own
/// `IsolateInterpreter` uses.
typedef InterpreterLoader = Future<int> Function(int threads);

/// Runs ONE inference on the interpreter at `address`: model input tensor in,
/// raw `[1,256,256,6]` float scores out. It is executed INSIDE a worker
/// isolate, so it must be a top-level or static function (isolate-sendable).
typedef ModelInference = Float32List Function(int address, Float32List input);

/// Frees the native interpreter at `address`.
typedef InterpreterCloser = void Function(int address);

/// REAL on-device segmenter — MediaPipe Selfie Multiclass (D21), F2.5 spike.
///
/// Runs `selfie_multiclass_256x256.tflite` (16.37 MB, Apache-2.0, Google)
/// through the `tflite_flutter` runtime. Chosen over "MediaPipe Tasks" because
/// the official MediaPipe VISION task plugin does not exist on pub.dev
/// (google/flutter-mediapipe publishes only text/genai/core — verified
/// 2026-07-14), so the ADR's documented fallback (`tflite_flutter` + manual
/// pre/post-processing in pure Dart) is the lightest maintained route. See
/// `docs/architecture/2026-07-10_1730_F2.5_mediapipe-integration-scaffold.md`
/// (§3) and the on-device spike report of 2026-07-14.
///
/// Pipeline (all pure Dart around a single `invoke()`):
///   1. bilinear resize of the decoded RGBA frame to 256×256, RGB float [0,1];
///   2. one interpreter run → `[1,256,256,6]` class scores;
///   3. per-pixel argmax → class map (background/hair/body-skin/face-skin/
///      clothes/others). The learned skin classes are what RETIRES the YCbCr
///      proxy (prototype §5);
///   4. clothes bounding-box mid-row split → [GarmentRegion.upper] /
///      [GarmentRegion.lower] masks at full frame resolution (v1 geometric
///      split per D21; v1.1 = MediaPipe Pose hip line).
///
/// Wired at the composition root (`app.dart`, `kGarmentAnalysisEnabled`) as
/// the outfit engine's segmenter since r10.
///
/// THREADING (A4, r13): nothing heavy runs on the UI isolate. The model parse
/// + interpreter creation run in a worker isolate ([loadInterpreterAddress]),
/// and steps 1-4 above (preprocess, the synchronous FFI `invoke()`, argmax,
/// upscale, mask split) run together in ONE worker isolate per call
/// ([segmentFrame]), so the analyzing progress bar — and later the rewarded-ad
/// slot (F8) — keep animating. The pure functions are unchanged, so the output
/// is byte-identical to the former on-isolate path. Calls that touch the
/// native interpreter are SERIALIZED (a TFLite interpreter is not safe for
/// concurrent use), and the model load is SINGLE-FLIGHT: concurrent first
/// calls share one in-flight load → exactly one native interpreter (F12).
///
/// The model asset is GITIGNORED (16 MB): on a fresh clone run
/// `app/tool/fetch_models.sh` first. If the asset is missing or the TFLite
/// native library cannot load (e.g. host `flutter test` without
/// `tensorflowlite_c`), [segment] degrades loudly with a
/// [SegmentationException] — never a silent wrong answer. A failed load is
/// MEMOIZED for the life of the instance (the cause — missing asset or native
/// library — is permanent), so later analyses degrade to the whole-photo path
/// (S4) instantly instead of re-reading 16 MB each time; [dispose] resets it.
class MediaPipeGarmentSegmenter implements GarmentSegmenter {
  /// Creates a segmenter running the bundled model on [threads] CPU threads.
  ///
  /// [loader], [inference] and [closer] are test seams (the host test runner
  /// has no native TFLite library); production always uses the defaults.
  MediaPipeGarmentSegmenter({
    this.threads = defaultThreads,
    @visibleForTesting InterpreterLoader loader = loadInterpreterAddress,
    @visibleForTesting ModelInference inference = invokeModel,
    @visibleForTesting InterpreterCloser closer = closeInterpreter,
  })  : _loader = loader,
        _inference = inference,
        _closer = closer;

  /// Whether this runtime bundles the native TFLite library the model needs
  /// (the Android/iOS builds). The host `flutter test` runner does not, so the
  /// composition root only schedules the [preload] where it can succeed.
  static bool get isRuntimeSupported => Platform.isAndroid || Platform.isIOS;

  /// The bundled model asset key (fetched by `app/tool/fetch_models.sh`,
  /// pinned by SHA-256 there).
  static const String modelAsset =
      'assets/models/selfie_multiclass_256x256.tflite';

  /// Class index of background pixels (argmax over the 6 score channels).
  static const int backgroundClassIndex = 0;

  /// Class index of hair pixels — the #56 "hair" attribution bucket.
  static const int hairClassIndex = 1;

  /// Class index of body-skin pixels. This real class retires the crude
  /// YCbCr skin proxy (D21).
  static const int bodySkinClassIndex = 2;

  /// Class index of face-skin pixels.
  static const int faceSkinClassIndex = 3;

  /// Class index of clothes pixels — the only class the palette reads.
  static const int clothesClassIndex = 4;

  /// Class index of everything else the model recognizes.
  static const int othersClassIndex = 5;

  /// Model input/output side in pixels (square), asserted at load.
  static const int modelSide = 256;

  /// Number of score channels the model emits, asserted at load.
  static const int numClasses = 6;

  /// Minimum fraction of model pixels that must be clothes to accept the
  /// frame. The prototype measured clothes coverage > 1% on 35/35 real
  /// selfies (mean 25.1%), so below this the photo very likely has no
  /// dressed person → [SegmentationException.isNoPerson].
  static const double minClothesCoverage = 0.01;

  /// CPU threads for the TFLite interpreter (XNNPACK/GPU delegates are a
  /// later optimization; D22 makes latency non-blocking).
  static const int defaultThreads = 4;

  /// CPU threads handed to the TFLite interpreter.
  final int threads;

  final InterpreterLoader _loader;
  final ModelInference _inference;
  final InterpreterCloser _closer;

  /// The ONE in-flight-or-finished model load (single-flight, F12). It
  /// memoizes success (the interpreter address) AND failure (a typed
  /// [SegmentationException]); null until the first [warmUp] / [segment], and
  /// again after [dispose].
  Future<int>? _load;

  /// Tail of the queue that serializes every use of the native interpreter
  /// (inference and [dispose]); it never completes with an error.
  Future<void> _queue = Future<void>.value();

  /// Loads the model (idempotent, single-flight). Concurrent callers share the
  /// SAME in-flight load, so only one native interpreter is ever created.
  /// Throws [SegmentationException] if the model cannot load; the failure is
  /// memoized (see the class doc).
  Future<void> warmUp() async {
    await _interpreterAddress();
  }

  /// [warmUp] that never throws: the composition root calls it right after
  /// the first frame so the first analysis does not pay the model load (A4).
  /// A failure is swallowed here on purpose — it stays memoized, and the next
  /// [segment] surfaces it as a [SegmentationException], which the engine
  /// turns into the silent whole-photo degrade (S4).
  Future<void> preload() async {
    try {
      await warmUp();
    } on SegmentationException {
      // Silent by contract: the analysis path reports the degrade.
    }
  }

  /// Frees the native interpreter once any queued inference has finished.
  /// Safe to call more than once; a later [warmUp]/[segment] loads again.
  Future<void> dispose() {
    final InterpreterCloser closer = _closer;
    final Future<void> done = _queue.then((void _) async {
      final Future<int>? load = _load;
      _load = null;
      if (load == null) {
        return;
      }
      try {
        closer(await load);
      } on SegmentationException {
        // The load never produced an interpreter: nothing to free.
      }
    });
    _queue = done.then<void>((void _) {}, onError: (Object _) {});
    return done;
  }

  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    _checkFrame(rgba, width, height);
    final ModelInference inference = _inference;
    return _withInterpreter((int address) =>
        _segmentOffIsolate(rgba, width, height, address, inference));
  }

  /// Runs the model once and returns the per-pixel class map at FULL frame
  /// resolution (nearest-neighbor upscale of the 256×256 argmax). Diagnostic
  /// surface for the spike harness / eval overlays; [segment] builds on it.
  /// Runs off the UI isolate, like [segment].
  Future<Uint8List> classify(Uint8List rgba, int width, int height) async {
    _checkFrame(rgba, width, height);
    final ModelInference inference = _inference;
    return _withInterpreter((int address) =>
        _classifyOffIsolate(rgba, width, height, address, inference));
  }

  /// The single-flight load: the first caller starts it, everyone shares it.
  /// `_load ??=` assigns synchronously (an `async` function returns its
  /// future before its first `await`), so there is no check-then-await gap.
  Future<int> _interpreterAddress() => _load ??= _loadOnce();

  Future<int> _loadOnce() async {
    try {
      return await _loader(threads);
    } on SegmentationException {
      rethrow;
    } catch (e) {
      // Missing asset (fresh clone without fetch_models.sh) or missing
      // native TFLite library (host tests): fail loudly, typed.
      throw SegmentationException('cannot load $modelAsset: $e');
    }
  }

  /// Runs [body] with the interpreter address, strictly after every
  /// previously queued interpreter use (no concurrent `invoke()` on the same
  /// native interpreter, no [dispose] under a running inference).
  Future<T> _withInterpreter<T>(Future<T> Function(int address) body) {
    final Future<T> result =
        _queue.then((void _) async => body(await _interpreterAddress()));
    _queue = result.then<void>((T _) {}, onError: (Object _) {});
    return result;
  }

  static void _checkFrame(Uint8List rgba, int width, int height) {
    if (rgba.length != width * height * 4) {
      throw SegmentationException(
          'rgba length ${rgba.length} != $width*$height*4');
    }
  }

  // The two isolate hops live in STATIC helpers on purpose: the closure
  // handed to Isolate.run must capture only sendable values (never `this`).
  static Future<GarmentSegmentation> _segmentOffIsolate(Uint8List rgba,
          int width, int height, int address, ModelInference inference) =>
      Isolate.run(() => segmentFrame(rgba, width, height, address, inference),
          debugName: 'garment-segmentation');

  static Future<Uint8List> _classifyOffIsolate(Uint8List rgba, int width,
          int height, int address, ModelInference inference) =>
      Isolate.run(() => classifyFrame(rgba, width, height, address, inference),
          debugName: 'garment-classify');

  /// Default [InterpreterLoader]: reads the asset, then parses the model and
  /// creates + allocates the interpreter (the synchronous FFI part) in a
  /// worker isolate, returning the native address. The asset read itself is
  /// an async platform call; only its bytes cross into the worker.
  static Future<int> loadInterpreterAddress(int threads) async {
    final ByteData raw = await rootBundle.load(modelAsset);
    final Uint8List bytes =
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    return Isolate.run(() => _createInterpreter(bytes, threads),
        debugName: 'garment-model-load');
  }

  /// Creates the interpreter from the model [bytes] and asserts the tensor
  /// shapes. Runs inside the load worker isolate.
  static int _createInterpreter(Uint8List bytes, int threads) {
    final Interpreter interpreter = Interpreter.fromBuffer(
      bytes,
      options: InterpreterOptions()..threads = threads,
    );
    final List<int> inShape = interpreter.getInputTensor(0).shape;
    final List<int> outShape = interpreter.getOutputTensor(0).shape;
    if (inShape.join('x') != '1x${modelSide}x${modelSide}x3' ||
        outShape.join('x') != '1x${modelSide}x${modelSide}x$numClasses') {
      interpreter.close();
      throw SegmentationException(
          'unexpected model tensors (in $inShape, out $outShape)');
    }
    return interpreter.address;
  }

  /// Default [ModelInference]: the exact tensor I/O of the former on-isolate
  /// path (raw input bytes in, raw float32 scores out), on a handle rebuilt
  /// from the native address. `allocated: true` because the tensors were
  /// allocated at creation (re-allocating an allocated interpreter is a
  /// no-op in TFLite).
  static Float32List invokeModel(int address, Float32List input) {
    final Interpreter interpreter =
        Interpreter.fromAddress(address, allocated: true);
    interpreter.getInputTensor(0).data = input.buffer.asUint8List();
    interpreter.invoke();
    final Uint8List out = interpreter.getOutputTensor(0).data;
    return out.buffer.asFloat32List(out.offsetInBytes, out.length ~/ 4);
  }

  /// Default [InterpreterCloser]: deletes the native interpreter.
  static void closeInterpreter(int address) {
    Interpreter.fromAddress(address, allocated: true).close();
  }

  /// The full class-map computation, pure and synchronous: preprocess → one
  /// [inference] → argmax → nearest upscale to the frame. This is what runs
  /// inside the worker isolate; calling it directly on any isolate returns
  /// the identical buffer (the off-isolate parity tests rely on that).
  static Uint8List classifyFrame(Uint8List rgba, int width, int height,
          int address, ModelInference inference) =>
      _upscaleNearest(classifyModelMap(rgba, width, height, address, inference),
          width, height);

  /// preprocess -> one [inference] -> argmax: the model-side 256x256 class
  /// map, before any upscale.
  static Uint8List classifyModelMap(Uint8List rgba, int width, int height,
      int address, ModelInference inference) {
    final Float32List input = preprocess(rgba, width, height);
    final Float32List scores;
    try {
      scores = inference(address, input);
    } catch (e) {
      throw SegmentationException('inference failed: $e');
    }
    return argmax(scores);
  }

  /// [classifyFrame] + [buildMasks]: the whole [segment] computation, pure
  /// and synchronous (runs inside the worker isolate). The masks are
  /// byte-identical to the pre-I2 path; the 256x256 model map rides along in
  /// [GarmentSegmentation.classMap] for the I2 recolor (D38).
  static GarmentSegmentation segmentFrame(Uint8List rgba, int width, int height,
      int address, ModelInference inference) {
    final Uint8List map256 =
        classifyModelMap(rgba, width, height, address, inference);
    final GarmentSegmentation masks =
        buildMasks(_upscaleNearest(map256, width, height), width, height);
    return GarmentSegmentation(
      width: masks.width,
      height: masks.height,
      masks: masks.masks,
      classMap: SegmentationClassMap(
        width: modelSide,
        height: modelSide,
        classes: map256,
        frameWidth: width,
        frameHeight: height,
      ),
    );
  }

  /// Bilinear resize of the RGBA frame to the model's 256×256 RGB float
  /// input, normalized to [0,1] (the MediaPipe image-tensor convention for
  /// this model; validated on real photos in the spike).
  static Float32List preprocess(Uint8List rgba, int width, int height) {
    final Float32List input = Float32List(modelSide * modelSide * 3);
    final double xScale = width / modelSide;
    final double yScale = height / modelSide;
    int o = 0;
    for (int oy = 0; oy < modelSide; oy++) {
      double sy = (oy + 0.5) * yScale - 0.5;
      if (sy < 0) sy = 0;
      final int y0 = sy.floor();
      final int y1 = (y0 + 1 < height) ? y0 + 1 : height - 1;
      final double fy = sy - y0;
      for (int ox = 0; ox < modelSide; ox++) {
        double sx = (ox + 0.5) * xScale - 0.5;
        if (sx < 0) sx = 0;
        final int x0 = sx.floor();
        final int x1 = (x0 + 1 < width) ? x0 + 1 : width - 1;
        final double fx = sx - x0;
        final int i00 = (y0 * width + x0) * 4;
        final int i01 = (y0 * width + x1) * 4;
        final int i10 = (y1 * width + x0) * 4;
        final int i11 = (y1 * width + x1) * 4;
        final double w00 = (1 - fy) * (1 - fx);
        final double w01 = (1 - fy) * fx;
        final double w10 = fy * (1 - fx);
        final double w11 = fy * fx;
        for (int c = 0; c < 3; c++) {
          final double v = rgba[i00 + c] * w00 +
              rgba[i01 + c] * w01 +
              rgba[i10 + c] * w10 +
              rgba[i11 + c] * w11;
          input[o++] = v / 255.0;
        }
      }
    }
    return input;
  }

  /// Per-pixel argmax over the [numClasses] score channels → 256×256 class
  /// map (values 0..5).
  static Uint8List argmax(Float32List scores) {
    const int pixels = modelSide * modelSide;
    final Uint8List map = Uint8List(pixels);
    for (int i = 0; i < pixels; i++) {
      final int base = i * numClasses;
      int best = 0;
      double bestScore = scores[base];
      for (int c = 1; c < numClasses; c++) {
        final double s = scores[base + c];
        if (s > bestScore) {
          bestScore = s;
          best = c;
        }
      }
      map[i] = best;
    }
    return map;
  }

  /// Splits the clothes pixels of a full-resolution [classMap] into
  /// [GarmentRegion.upper] / [GarmentRegion.lower] at the mid-row of the
  /// clothes bounding box (v1 geometric split, D21). Throws
  /// [SegmentationException] with `isNoPerson` when clothes coverage is
  /// under [minClothesCoverage].
  static GarmentSegmentation buildMasks(
      Uint8List classMap, int width, int height) {
    final int pixels = width * height;
    if (classMap.length != pixels) {
      throw SegmentationException(
          'classMap length ${classMap.length} != $width*$height');
    }
    int clothesCount = 0;
    int r0 = -1;
    int r1 = -1;
    for (int y = 0; y < height; y++) {
      final int row = y * width;
      bool rowHasClothes = false;
      for (int x = 0; x < width; x++) {
        if (classMap[row + x] == clothesClassIndex) {
          clothesCount++;
          rowHasClothes = true;
        }
      }
      if (rowHasClothes) {
        if (r0 < 0) r0 = y;
        r1 = y;
      }
    }
    if (clothesCount < pixels * minClothesCoverage) {
      throw const SegmentationException(
        'no dressed person found (clothes coverage below threshold)',
        isNoPerson: true,
      );
    }
    final int mid = (r0 + r1) ~/ 2;
    final Uint8List upper = Uint8List(pixels);
    final Uint8List lower = Uint8List(pixels);
    for (int y = 0; y < height; y++) {
      final int row = y * width;
      final Uint8List target = (y < mid) ? upper : lower;
      for (int x = 0; x < width; x++) {
        if (classMap[row + x] == clothesClassIndex) {
          target[row + x] = 1;
        }
      }
    }
    return GarmentSegmentation(
      width: width,
      height: height,
      masks: <GarmentRegion, Uint8List>{
        GarmentRegion.upper: upper,
        GarmentRegion.lower: lower,
      },
    );
  }

  /// Nearest-neighbor upscale of the 256×256 class map to (width, height).
  static Uint8List _upscaleNearest(Uint8List map256, int width, int height) {
    if (width == modelSide && height == modelSide) {
      return map256;
    }
    final Uint8List map = Uint8List(width * height);
    for (int y = 0; y < height; y++) {
      final int my = y * modelSide ~/ height;
      final int mrow = my * modelSide;
      final int row = y * width;
      for (int x = 0; x < width; x++) {
        map[row + x] = map256[mrow + (x * modelSide ~/ width)];
      }
    }
    return map;
  }
}
