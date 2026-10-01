import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../segmentation/garment_segmenter.dart';
import '../segmentation/mask_hygiene.dart';
import '../segmentation/whole_photo_segmenter.dart';
import 'borders.dart';
import 'color_engine.dart';
import 'garments.dart';
import 'harmony.dart';
import 'models.dart';
import 'palette.dart';

/// REAL implementation of the [ColorEngine]: the color core of
/// `cv_core/colorlab` ported to Dart, 100% on-device and offline (D15, #32).
///
/// Pipeline (port of the whole-photo palette, D1 — background removal /
/// GrabCut is Phase 2.5 and is NOT ported):
///   bytes -> downscaled decode -> deterministic subsampling -> over-clustered
///   K-means + LAB merge -> chromatic base (D5) -> HSV harmonies.
///
/// Registration: in `app.dart`, `final ColorEngine _engine = ColorEngineDart();`.

/// Maximum longest side when decoding the image. The codec already rescales
/// on the fly (cheap, inside the Flutter engine) and 512 px more than
/// preserves the color statistics of an outfit; a full 12 MP photo would
/// blow up memory and the latency budget of gate G1 (photo→result < 10 s).
const int kMaxDecodeSide = 512;

/// Cap on pixels entering K-means (~40k). Above it we subsample with a FIXED
/// step (deterministic: same photo → same palette, no random sampling).
/// 40k px * 10 clusters * 4 restarts converges in ~1-2 s on a mid-range
/// device and the palette is statistically indistinguishable from using all.
const int kMaxKmeansPixels = 40000;

/// Minimum alpha for a pixel to count: transparent ones (PNG with the
/// background already cut out) are not outfit and would bias the palette
/// toward black (0,0,0).
const int kMinAlpha = 128;

/// The on-device Dart implementation of [ColorEngine] (D15): the whole
/// pipeline — decode, optional segmentation, k-means palette, base pick and
/// harmonies — runs locally, so the app works fully offline (D2).
///
/// This is the Dart port of the canonical Python `colorlab` package; the
/// golden fixtures in `test/core/fixtures/` pin the two implementations
/// together, so any behavior change here must be made in `cv_core` first.
class ColorEngineDart implements ColorEngine {
  /// [segmenter] is the clothing-segmentation seam (Phase 2.5, D21). It
  /// DEFAULTS to [WholePhotoSegmenter] → the whole photo is one region, i.e.
  /// identical to today's MVP (D1). Passing a real segmenter later
  /// ([MediaPipeGarmentSegmenter]) is the ONLY change needed to run the palette
  /// per garment; nothing else in the app moves. This constructor stays `const`
  /// and its default arg preserves every existing `const ColorEngineDart()`.
  ///
  /// [avoidBorderBackground] (issue #49, OFF by default) turns on the optional
  /// #48 wall/floor border-background layer: colors that match a uniform
  /// wall/floor border band are demoted from leading the harmonies (see
  /// `borders.dart`). With the default `false` the MVP whole-photo flow is
  /// byte-identical — no candidate is even estimated — exactly the posture of
  /// the Python `--avoid-border-bg` flag (off unless explicitly requested).
  ///
  /// [productMode] (D24, feature F11 sneaker/product, OFF by default) mirrors
  /// the Python `--product-mode`: a clean product/object shot has no person, so
  /// the subject-isolation layer is skipped and the CORE runs on the WHOLE
  /// frame. On the Python side product mode omits TWO person layers (background
  /// removal + skin filter); the Dart engine NEVER ported those (D15), so the
  /// only subject-specific layer here is the Phase-2.5 garment [segmenter],
  /// which product mode bypasses (mask == null → whole frame). With `false`
  /// the flow is byte-identical to the pre-D24 MVP.
  ///
  /// Since #84 (gate G2S review), product mode ALSO mirrors the two Python
  /// product-mode layers added there: the multi-edge background suppression
  /// (a color wrapping >= 3 image edges is background; its pixels are dropped
  /// BEFORE clustering — see [productBackgroundMask]) and the
  /// neutral-lightness merge protection (a true white sole / black upper must
  /// stay its own swatch instead of collapsing into a mid-gray — see
  /// `protectNeutralLightness` in `palette.dart`). Both are product-only:
  /// the outfit path never runs them.
  /// [garmentAnalysis] (Phase 2.5, issues #88/#89, OFF by default) activates
  /// the PER-GARMENT path: [segmenter] is expected to emit upper/lower masks
  /// (i.e. a real [MediaPipeGarmentSegmenter]); the engine applies the #89
  /// hygiene guards (erosion + min-region, `mask_hygiene.dart`), runs one
  /// small palette per garment and assembles the combined outfit palette +
  /// global base ([buildGarmentAnalysis], the Dart `analyze_garments`). Any
  /// [SegmentationException] degrades SILENTLY to the whole-photo pipeline
  /// (state S4 of the UX spec) — same output as today's engine, tagged for
  /// telemetry only. With the default `false` the flow is byte-identical to
  /// the pre-2.5 MVP (the beta posture: per #87 the model must not ship to
  /// testers without the per-ABI split, so default-off is mandatory).
  const ColorEngineDart({
    this.segmenter = const WholePhotoSegmenter(),
    this.avoidBorderBackground = false,
    this.productMode = false,
    this.garmentAnalysis = false,
  });

  /// Clothing-segmentation seam (Phase 2.5, D21).
  final GarmentSegmenter segmenter;

  /// Enables the two-color (wall + floor) background model from `borders.dart`
  /// (#48). Off by default: it is an optional accuracy layer, not the MVP path.
  final bool avoidBorderBackground;

  /// Product mode (D24, sneakers): skips the person-specific layers, which a
  /// clean product photo does not need and which only add attribution error.
  final bool productMode;

  /// Per-garment analysis (Phase 2.5): emits one [GarmentBlockData] per
  /// region instead of a single whole-photo palette.
  final bool garmentAnalysis;

  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async {
    final _DecodedFrame frame = await _decodePixels(imageBytes);
    if (frame.pixels.length ~/ 3 < kDefaultColors * kOversegmentFactor) {
      // No usable pixels (tiny or 100% transparent image): there is no
      // outfit to analyze (ugly state E4).
      throw const ColorEngineException(
        'La imagen no tiene suficientes píxeles útiles',
        isNoOutfit: true,
      );
    }
    // PER-GARMENT PATH (Phase 2.5, #88/#89): segment → guards → one palette
    // per garment → combined outfit palette + global base. Degrades silently
    // to the whole-photo pipeline below on any SegmentationException.
    if (garmentAnalysis && !productMode) {
      return _analyzeGarments(frame);
    }
    // K-means takes ~1-2 s: off the UI thread (Isolate.run) so the progress
    // animation — and the rewarded ad slot (F8) — do not freeze. Since A4
    // (r13) the per-garment path above honors the same invariant: inference,
    // mask post-processing and erosion all run in worker isolates. The optional
    // border-background estimation (#49) and the product-mode multi-edge
    // suppression (#84) also run inside the isolate. Locals only (never
    // capture `this`): the closure must stay isolate-sendable.
    final Uint8List? frameRgba = frame.frameRgba; // null unless a flag is on
    final int width = frame.width;
    final int height = frame.height;
    final Float64List pixels = frame.pixels;
    final bool avoidBg = avoidBorderBackground;
    final bool product = productMode;
    return Isolate.run(() {
      final List<BackgroundCandidate>? candidates = (avoidBg &&
              frameRgba != null)
          ? estimateBackgroundCandidates(_rgbFromRgba(frameRgba), height, width)
          : null;
      // PRODUCT MODE (#84): drop the multi-edge background pixels before
      // clustering; the whole-frame pixels are the graceful fallback when the
      // suppression self-disables (see extractProductPixels).
      final Float64List analysisPixels = (product && frameRgba != null)
          ? extractProductPixels(frameRgba, height, width)
          : pixels;
      return buildResult(
        analysisPixels,
        backgroundCandidates: candidates,
        productMode: product,
      );
    });
  }

  /// The per-garment analysis (Phase 2.5): one real segmentation, then the
  /// #89 hygiene guards + per-region extraction + [buildGarmentAnalysis],
  /// all inside ONE worker isolate ([analyzeSegmentedFrame], A4).
  ///
  /// THREADING (A4, r13): the segmenter runs its own inference off the UI
  /// isolate (see `MediaPipeGarmentSegmenter`), and the full-frame erosion +
  /// extraction + per-garment K-means run in the isolate below — so the UI
  /// isolate only awaits. A [SegmentationException] thrown inside the isolate
  /// (the guards killing every region) crosses back TYPED (`Isolate.run`
  /// rethrows the original sendable error), so the degrade below still fires.
  ///
  /// DEGRADE CONTRACT (UX spec U4 + §6): any [SegmentationException] — model
  /// missing/failed, no dressed person, no region surviving the guards —
  /// falls back to the whole-photo pipeline on the SAME frame, so the user
  /// sees exactly today's result (state S4, pixel-identical layout). The
  /// result is only TAGGED (`segmentationLayout: whole` + the reason) so the
  /// analyzing screen can log `segmentation_degraded {reason, to}`.
  ///
  /// UNTYPED failures of the per-garment attempt (r13, after A1 routed every
  /// uncaught error to E3) degrade the SAME way, tagged `model_failed`: a
  /// `RemoteError` / `IsolateSpawnException` from the worker isolates, an
  /// unexpected error in inference or mask building. The user still gets a
  /// result instead of the error screen. Two things still propagate (→ E3):
  /// a [ColorEngineException] (the engine's own typed failure, unchanged),
  /// and ANY error of the whole-photo fallback itself — it runs outside the
  /// try, so it is never swallowed.
  Future<AnalysisResult> _analyzeGarments(_DecodedFrame frame) async {
    final Uint8List frameRgba = frame.frameRgba!;
    final String reason;
    try {
      final GarmentSegmentation segmentation =
          await segmenter.segment(frameRgba, frame.width, frame.height);
      final AnalysisResult result =
          await _analyzeSegmentedOffIsolate(frameRgba, segmentation);
      // I2 (D38): keep the model class map (memory only) for the recolor.
      // The palette math above never sees it.
      return segmentation.classMap == null
          ? result
          : result.withSegmentationClassMap(segmentation.classMap);
    } on SegmentationException catch (e) {
      reason = e.isNoPerson
          ? SegmentationDegradeReasons.noPerson
          : SegmentationDegradeReasons.modelFailed;
    } on ColorEngineException {
      rethrow;
    } catch (e, stack) {
      // Debug-only diagnostics (developer.log is a no-op in release); the
      // degrade itself reaches telemetry via `segmentation_degraded`.
      developer.log('per-garment analysis failed; whole-photo degrade (S4)',
          name: 'segmentation', error: e, stackTrace: stack);
      reason = SegmentationDegradeReasons.modelFailed;
    }
    return _wholePhotoDegrade(frame.pixels, reason);
  }

  /// S4 whole-photo degrade: the SAME pixels today's engine would use
  /// (`frame.pixels` is the null-mask whole-frame extraction), so the
  /// palette/base/harmonies are byte-identical to the flag-off engine. Called
  /// OUTSIDE the degrade try on purpose: its own failures propagate (E3).
  static Future<AnalysisResult> _wholePhotoDegrade(
          Float64List pixels, String reason) =>
      Isolate.run(() => buildResult(
            pixels,
            segmentationLayout: SegmentationLayouts.whole,
            segmentationDegradeReason: reason,
          ));

  /// Decodes and downscales the image with the engine's codec, and returns
  /// the flattened RGB pixels (plus, only when [avoidBorderBackground] is on,
  /// the full-frame RGBA + dimensions needed to estimate border candidates).
  Future<_DecodedFrame> _decodePixels(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Proportional downscale: the LONGEST side ends at kMaxDecodeSide
      // (giving only one dimension, the codec keeps the aspect ratio).
      int? targetWidth;
      int? targetHeight;
      if (math.max(descriptor.width, descriptor.height) > kMaxDecodeSide) {
        if (descriptor.width >= descriptor.height) {
          targetWidth = kMaxDecodeSide;
        } else {
          targetHeight = kMaxDecodeSide;
        }
      }
      codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      image = frame.image;
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw const ColorEngineException(
            'No se pudieron leer los píxeles de la imagen');
      }
      final Uint8List rgba =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // SEGMENTATION HOOK (Phase 2.5, D21): pick which pixels feed the palette.
      // With the default WholePhotoSegmenter this selects EVERY pixel, so the
      // extraction below is byte-identical to the pre-D21 MVP. A real segmenter
      // would return the garment mask here (and, later, per-region masks).
      //
      // PRODUCT MODE (D24): a product/object has no person to isolate, so the
      // segmenter is BYPASSED entirely and the whole frame feeds the palette
      // (mask == null). This is the Dart analog of the Python person-layer skip.
      final Uint8List? mask;
      if (productMode) {
        mask = null; // whole frame: no subject isolation for a product shot
      } else if (garmentAnalysis) {
        // Phase 2.5 per-garment path: the REAL segmentation (one inference,
        // upper/lower masks) runs later in _analyzeGarments; the whole-frame
        // pixels extracted here double as the S4 degrade input.
        mask = null;
      } else {
        final GarmentSegmentation seg =
            await segmenter.segment(rgba, image.width, image.height);
        mask = seg.maskFor(GarmentRegion.whole);
      }
      final Float64List pixels = extractRgbaPixels(rgba, mask: mask);
      // Only retain the full-frame RGBA when a layer that needs the 2D frame
      // is on (the #49 border layer, #84 product suppression or the 2.5
      // per-garment path): with the defaults `frameRgba` is null and the
      // pipeline is unchanged.
      return _DecodedFrame(
        pixels: pixels,
        frameRgba: (avoidBorderBackground || productMode || garmentAnalysis)
            ? rgba
            : null,
        width: image.width,
        height: image.height,
      );
    } on ColorEngineException {
      rethrow;
    } catch (e) {
      // Corrupt bytes / unsupported format: analysis failure (E3).
      throw ColorEngineException('No se pudo decodificar la imagen: $e');
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

/// Output of the decode step: the subsampled RGB pixels for the palette and,
/// only when a full-frame layer is on (#49 border candidates or #84 product
/// suppression), the full-frame RGBA and its dimensions. With both flags off,
/// [frameRgba] is null and this carries exactly what the pre-#49 pipeline
/// carried.
class _DecodedFrame {
  const _DecodedFrame({
    required this.pixels,
    required this.frameRgba,
    required this.width,
    required this.height,
  });

  final Float64List pixels;
  final Uint8List? frameRgba;
  final int width;
  final int height;
}

/// Runs [analyzeSegmentedFrame] in a worker isolate. Top-level on purpose:
/// the closure may only capture sendable values (never an engine `this`).
Future<AnalysisResult> _analyzeSegmentedOffIsolate(
        Uint8List frameRgba, GarmentSegmentation segmentation) =>
    Isolate.run(() => analyzeSegmentedFrame(frameRgba, segmentation),
        debugName: 'garment-analysis');

/// The per-garment analysis of ONE segmented frame, pure and synchronous:
/// the #89 guards ([applyGarmentGuards]: erosion + min-region) → per-region
/// [extractRgbaPixels] → [buildGarmentAnalysis]. The engine runs it inside a
/// worker isolate (A4); calling it on any isolate returns the identical
/// result (pinned by `garment_offisolate_parity_test.dart`).
///
/// Throws [SegmentationException] (`isNoPerson`) when no region survives the
/// guards or every surviving region is fully transparent — the engine's S4
/// whole-photo degrade trigger.
///
/// Visible (no `_`) so the parity tests exercise the exact composition.
AnalysisResult analyzeSegmentedFrame(
    Uint8List frameRgba, GarmentSegmentation segmentation) {
  final GarmentSegmentation guarded = applyGarmentGuards(segmentation);
  // The decoded frame's pixel count (rawRgba is exactly width*height*4).
  final int framePixels = frameRgba.length ~/ 4;
  final List<GarmentPixels> regions = <GarmentPixels>[];
  for (final GarmentRegion region in <GarmentRegion>[
    GarmentRegion.upper,
    GarmentRegion.lower
  ]) {
    final Uint8List? mask = guarded.maskFor(region);
    if (mask == null) {
      continue;
    }
    final Float64List regionPixels = extractRgbaPixels(frameRgba, mask: mask);
    if (regionPixels.isEmpty) {
      continue; // fully transparent region: nothing to sample
    }
    regions.add(GarmentPixels(
      region: region,
      pixels: regionPixels,
      // Python parity: pixel_fraction = eroded-mask pixels / frame pixels.
      pixelFraction: maskPixelCount(mask) / framePixels,
    ));
  }
  if (regions.isEmpty) {
    throw const SegmentationException(
      'garment regions contained no opaque pixels',
      isNoPerson: true,
    );
  }
  return buildGarmentAnalysis(regions);
}

/// Flat row-major RGB (drops alpha) from an RGBA buffer, the input shape
/// [estimateBackgroundCandidates] expects. Top-level so it is isolate-safe.
List<int> _rgbFromRgba(Uint8List rgba) {
  final int n = rgba.length ~/ 4;
  final List<int> out = List<int>.filled(n * 3, 0);
  for (int i = 0; i < n; i++) {
    out[i * 3] = rgba[i * 4];
    out[i * 3 + 1] = rgba[i * 4 + 1];
    out[i * 3 + 2] = rgba[i * 4 + 2];
  }
  return out;
}

/// Extracts RGB pixels `[n*3]` from a flat RGBA buffer, with DETERMINISTIC
/// fixed-step subsampling if there are more than [kMaxKmeansPixels] pixels.
///
/// [mask] (Phase 2.5, D21) is an optional per-pixel `0/1` selection of length
/// `n` (see [GarmentSegmentation]): only pixels with `mask[i] == 1` are kept.
/// A null mask (the MVP default) keeps ALL pixels, so the output is identical
/// to the pre-segmentation behavior.
///
/// Visible (no `_`) to be testable directly; the UI does not use it.
Float64List extractRgbaPixels(Uint8List rgba, {Uint8List? mask}) {
  final int n = rgba.length ~/ 4;
  int step = (n + kMaxKmeansPixels - 1) ~/ kMaxKmeansPixels; // ceil(n/max)
  // Odd step: an even step could align with an even image width (e.g. 512)
  // and sample only fixed columns; odd vs even width sweeps the whole image.
  // Still deterministic.
  if (step > 1 && step.isEven) {
    step += 1;
  }
  final List<double> samples = <double>[];
  for (int i = 0; i < n; i += step) {
    final int base = i * 4;
    if (rgba[base + 3] < kMinAlpha) {
      continue; // transparent: not outfit
    }
    if (mask != null && mask[i] == 0) {
      continue; // outside the selected garment region (Phase 2.5)
    }
    samples
      ..add(rgba[base].toDouble())
      ..add(rgba[base + 1].toDouble())
      ..add(rgba[base + 2].toDouble());
  }
  return Float64List.fromList(samples);
}

/// Product-mode pixel gathering (#84): the whole frame MINUS the multi-edge
/// background — the Dart analog of the `product_background_mask` drop in
/// `pipeline.py`'s product branch (pixels removed BEFORE clustering).
///
/// When the suppression self-disables (no color wraps >= 3 edges, or the mask
/// would cover more than [kProductBgMaxCoverage] of the frame), the extraction
/// is byte-identical to the plain whole-frame path — the same graceful
/// fallback as Python. Visible (no `_`) so the golden-fixture parity test can
/// exercise the exact composition the engine runs.
Float64List extractProductPixels(Uint8List rgba, int height, int width) {
  final List<int> rgb = _rgbFromRgba(rgba);
  final List<bool> drop = productBackgroundMask(rgb, height, width);
  Uint8List? keep;
  for (int i = 0; i < drop.length; i++) {
    if (drop[i]) {
      keep = Uint8List(drop.length);
      for (int p = 0; p < drop.length; p++) {
        keep[p] = drop[p] ? 0 : 1;
      }
      break;
    }
  }
  return extractRgbaPixels(rgba, mask: keep);
}

/// Pure pipeline pixels -> [AnalysisResult] (runs inside the isolate).
///
/// Visible (no `_`) to be testable without going through the image codec.
///
/// [backgroundCandidates] (#49) is the optional #48 border-background layer:
/// when non-null, wall/floor-like palette colors are demoted from leading the
/// harmonies (via [pickHarmonyBaseAvoidingBackground]). When NULL (the default,
/// the MVP path), the base pick is byte-identical to the pre-#49 engine.
///
/// [productMode] (D24/#84) protects neutral lightness in the cluster merge —
/// a product's true white sole / black upper must stay its own swatch instead
/// of collapsing into a mid-gray. `false` (outfit mode) keeps the historical
/// merge byte-identical.
///
/// [segmentationLayout]/[segmentationDegradeReason] (Phase 2.5) tag the S4
/// whole-photo degrade for telemetry only — the palette math is untouched
/// and with the default `null` the result is byte-identical to pre-2.5.
AnalysisResult buildResult(
  Float64List pixels, {
  List<BackgroundCandidate>? backgroundCandidates,
  bool productMode = false,
  String? segmentationLayout,
  String? segmentationDegradeReason,
}) {
  final DominantPalette palette =
      dominantColors(pixels, protectNeutralLightness: productMode);
  if (palette.colors.isEmpty) {
    // With weights summing to 1 and <= 10 clusters this should never happen,
    // but if it does it is an honest E3, not a crash.
    throw const ColorEngineException('No se pudo extraer una paleta fiable');
  }

  // Chromatic base (D5): saturation * weight among non-neutrals; -1 = all
  // neutral -> canvas mode (D10). In canvas mode there is no meaningful base:
  // we drop the arbitrary-hue harmonies (bug B3) and offer the curated accent
  // pops instead. With the optional border layer on (#49), background-like
  // colors are first demoted from eligibility.
  final int baseIndex = backgroundCandidates == null
      ? pickHarmonyBase(palette.colors, palette.weights)
      : pickHarmonyBaseAvoidingBackground(
          palette.colors, palette.weights, backgroundCandidates);

  // Shared assembly tail (harmonies / canvas accents / samples) — extracted
  // to `composeAnalysis` (garments.dart) when the per-garment path landed;
  // the output here is byte-identical to the historical inline version.
  return composeAnalysis(
    colors: palette.colors,
    weights: palette.weights,
    baseIndex: baseIndex,
    segmentationLayout: segmentationLayout,
    segmentationDegradeReason: segmentationDegradeReason,
  );
}
