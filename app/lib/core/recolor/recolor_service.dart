import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../color_engine/color_engine_dart.dart'
    show analyzeSegmentedFrame, kMaxDecodeSide;
import '../color_engine/models.dart';
import '../segmentation/garment_segmenter.dart';
import '../segmentation/mask_hardening.dart';
import '../segmentation/recolor_applicability.dart';
import 'recolor_region.dart';

/// I2 "Vérmelo puesto" (D38) — the seam the result screen / recolor view
/// (pass 2) call. Outfit mode only; NO telemetry (CEO, D38: no analytics
/// call anywhere in this flow).
///
/// Two stages, both OFF the UI isolate:
///
///  1. [RecolorService.open] — cheap, at the ANALYSIS frame size (≤ 512 px,
///     the size the CEO's visual gate was judged at): smoothed + hardened
///     masks, [checkRecolorApplicability], the qualifying regions, the
///     default region (the one that is NOT the base) and each region's
///     source colour (the Dart `analyze_garments(harden=RECOLOR_HARDENING)`:
///     the per-garment engine run on the hardened split). The result screen
///     can build the pill-or-tip from [RecolorSession.availability].
///  2. [RecolorSession.renderAll] / [RecolorSession.render] — lazy, at the
///     story photo-box size (contained in [kRecolorRenderBox], D37 §8.3):
///     both regions in ONE worker
///     isolate (masks rebuilt once at that size), cached for the session.
///
/// PRIVACY (D37/D38): the photo, the class map and the recolored pixels live
/// in memory only; nothing here writes a file. [RecolorSession.dispose]
/// zero-fills and drops every buffer. The only way a recolored pixel reaches
/// disk is the story PNG the user explicitly shares (D37 flow, pass 2).

/// A render-size cap: the recolored bitmap is contained in [width] ×
/// [height] (aspect kept, never enlarged).
class RecolorRenderBox {
  /// Creates a [width] × [height] box.
  const RecolorRenderBox(this.width, this.height);

  /// Max width, px.
  final int width;

  /// Max height, px.
  final int height;
}

/// THE render-size knob (PM, r15): the recolored bitmaps are rendered
/// contained in this box. Default = the story photo-box export size (D37
/// §8.3: 392 × 415 logical × 2.5 = 980 × 1038), so one render serves the
/// screen AND the shared story. If the on-device timing is too slow, set it
/// to `RecolorRenderBox(512, 512)` — nothing else changes.
const RecolorRenderBox kRecolorRenderBox = RecolorRenderBox(980, 1038);

/// Opens a [RecolorSession] (the seam the result screen takes; production =
/// [openRecolorSession], tests inject a fake).
typedef RecolorOpener = Future<RecolorSession> Function({
  required Uint8List photo,
  required AnalysisResult analysis,
  required ui.Color target,
});

/// Production [RecolorOpener]: the default [RecolorService].
Future<RecolorSession> openRecolorSession({
  required Uint8List photo,
  required AnalysisResult analysis,
  required ui.Color target,
}) =>
    const RecolorService()
        .open(photo: photo, analysis: analysis, target: target);

/// Longest side the canonical px constants (smoothing sigma, growth,
/// feather) were tuned and visually gated at (the PoC / gate work size).
/// At another render size they are scaled by `side / 512` so the edge looks
/// the same relative to the garment — HYPOTHESIS until the pass-2 on-device
/// visual check.
const int kRecolorReferenceSide = 512;

/// The recolor could not be computed (a defensive fallback: the UX shows
/// `recolorFailedSnack` and stays on the result).
class RecolorException implements Exception {
  /// Creates a failure described by [reason] (never shown to users).
  const RecolorException(this.reason);

  /// Short machine-readable cause.
  final String reason;

  @override
  String toString() => 'RecolorException($reason)';
}

/// Whether the recolor is offered, and how (computed by
/// [RecolorService.open]).
class RecolorAvailability {
  /// Creates an availability verdict.
  const RecolorAvailability({
    required this.blocker,
    required this.regions,
    required this.defaultRegion,
    this.metrics = const <String, double>{},
  });

  /// Not offered at all (the UI shows the tip for this reason).
  const RecolorAvailability.unavailable(RecolorBlocker this.blocker,
      {this.metrics = const <String, double>{}})
      : regions = const <GarmentRegion>[],
        defaultRegion = null;

  /// Null = offered; else why not (the UX tip family: severalPeople →
  /// people tip, poorLight → light tip, the rest → coverage tip).
  final RecolorBlocker? blocker;

  /// The regions the view may offer, upper first (2 = show the selector,
  /// 1 = hide it). Empty when [blocker] is set.
  final List<GarmentRegion> regions;

  /// The region the view opens on: the qualifying region that does NOT hold
  /// the outfit base (UX §2.2), else the first qualifying one. Null when not
  /// offered.
  final GarmentRegion? defaultRegion;

  /// The applicability statistics (diagnostics / tests only — never sent
  /// anywhere).
  final Map<String, double> metrics;

  /// True when the "Vérmelo puesto" pill should be shown.
  bool get isAvailable => blocker == null && regions.isNotEmpty;
}

/// One recolored photo, RGBA at [width] × [height] (memory only).
class RecolorFrame {
  /// Creates a frame over [rgba].
  const RecolorFrame(this.region, this.width, this.height, this.rgba);

  /// The region that was repainted.
  final GarmentRegion region;

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;

  /// Row-major RGBA, `width * height * 4`.
  final Uint8List rgba;

  /// A GPU image of the frame for `RawImage` / the story frame. The caller
  /// owns it and must `dispose()` it.
  Future<ui.Image> toImage() async {
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(rgba);
    final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final ui.Codec codec = await descriptor.instantiateCodec();
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

/// Entry point of the recolor engine (stateless; one [RecolorSession] per
/// result screen).
class RecolorService {
  /// Creates the service; [renderBox] caps the render size.
  const RecolorService({this.renderBox = kRecolorRenderBox});

  /// Render size cap (default [kRecolorRenderBox]).
  final RecolorRenderBox renderBox;

  /// Render width cap, px.
  int get renderMaxWidth => renderBox.width;

  /// Render height cap, px.
  int get renderMaxHeight => renderBox.height;

  /// Stage 1: decodes [photo] (the picker bytes the result flow already
  /// carries, `ResultArgs.photo`) at the analysis frame size and assesses
  /// the recolor for [analysis] (its `segmentationClassMap`) with the colour
  /// [target] (the hero combo colour the result screen SHOWS, or the selected
  /// canvas pop — the caller picks it, so screen, recolor and story never
  /// drift).
  ///
  /// Never throws for a "no": every refusal is a [RecolorAvailability]
  /// blocker. Throws [RecolorException] only if the photo cannot be decoded
  /// or the worker isolate fails (the UI treats it like a blocked recolor).
  Future<RecolorSession> open({
    required Uint8List photo,
    required AnalysisResult analysis,
    required ui.Color target,
  }) async {
    final List<int> targetRgb = rgbOfColor(target);
    final SegmentationClassMap? classMap = analysis.segmentationClassMap;
    if (classMap == null) {
      return _ServiceRecolorSession(
        service: this,
        photo: photo,
        classMap: null,
        targetRgb: targetRgb,
        availability: const RecolorAvailability.unavailable(
            RecolorBlocker.noSegmentation),
        sources: const <GarmentRegion, List<int>>{},
      );
    }
    final _Decoded frame = await _decodeAnalysisFrame(photo, classMap);
    final GarmentRegion? baseRegion = analysis.baseBlock?.region;
    final RecolorAssessment assessment;
    try {
      assessment = await Isolate.run(
          () => assessRecolor(classMap, frame.rgba, frame.width, frame.height),
          debugName: 'recolor-assess');
    } on Object catch (e) {
      throw RecolorException('assessment failed: $e');
    } finally {
      frame.rgba.fillRange(0, frame.rgba.length, 0);
    }
    final RecolorApplicability verdict = assessment.applicability;
    final RecolorAvailability availability;
    if (!verdict.applicable) {
      availability = RecolorAvailability.unavailable(verdict.reason!,
          metrics: verdict.metrics);
    } else {
      final List<GarmentRegion> regions = verdict.qualifyingRegions;
      availability = regions.isEmpty
          ? RecolorAvailability.unavailable(RecolorBlocker.regionTooSmall,
              metrics: verdict.metrics)
          : RecolorAvailability(
              blocker: null,
              regions: regions,
              defaultRegion: defaultRecolorRegion(regions, baseRegion),
              metrics: verdict.metrics,
            );
    }
    return _ServiceRecolorSession(
      service: this,
      photo: photo,
      classMap: classMap,
      targetRgb: targetRgb,
      availability: availability,
      sources: assessment.sources,
    );
  }

  /// Render size for an (upright) photo of `width × height`: contained in
  /// the caps, aspect kept, never enlarged.
  ({int width, int height}) renderSizeFor(int width, int height) {
    final double scale = math.min(
        1.0, math.min(renderMaxWidth / width, renderMaxHeight / height));
    return (
      width: math.max(1, (width * scale).round()),
      height: math.max(1, (height * scale).round()),
    );
  }

  /// Decodes [bytes] at EXACTLY the analysis frame: the same codec call
  /// `prepareImageForAnalysis` makes (encoded size × min(1, 512 / longest
  /// side), rounded), so the pixels are the ones the class map was computed
  /// on. A size mismatch is refused (never a misaligned mask).
  Future<_Decoded> _decodeAnalysisFrame(
      Uint8List bytes, SegmentationClassMap classMap) async {
    final _Decoded frame = await _decodeWith(bytes, (int w, int h) {
      final int longest = math.max(w, h);
      final double factor =
          longest > kMaxDecodeSide ? kMaxDecodeSide / longest : 1.0;
      return ((w * factor).round(), (h * factor).round());
    });
    if (frame.width != classMap.frameWidth ||
        frame.height != classMap.frameHeight) {
      frame.rgba.fillRange(0, frame.rgba.length, 0);
      throw RecolorException('analysis frame mismatch: '
          '${frame.width}x${frame.height} vs '
          '${classMap.frameWidth}x${classMap.frameHeight}');
    }
    return frame;
  }

  /// Decodes [bytes] at the render size: the upright photo (orientation
  /// read from the analysis frame's aspect, since the codec applies EXIF
  /// after the resize) contained in the caps.
  Future<_Decoded> _decodeRender(
      Uint8List bytes, SegmentationClassMap classMap) {
    final bool uprightLandscape = classMap.frameWidth >= classMap.frameHeight;
    return _decodeWith(bytes, (int w, int h) {
      // Encoded (pre-EXIF) size -> upright size.
      final bool swapped = (w >= h) != uprightLandscape;
      final int uw = swapped ? h : w;
      final int uh = swapped ? w : h;
      final ({int width, int height}) upright = renderSizeFor(uw, uh);
      return swapped
          ? (upright.height, upright.width)
          : (upright.width, upright.height);
    });
  }

  Future<_Decoded> _decodeWith(
      Uint8List bytes, (int, int) Function(int w, int h) targetSize) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final (int tw, int th) = targetSize(descriptor.width, descriptor.height);
      codec =
          await descriptor.instantiateCodec(targetWidth: tw, targetHeight: th);
      image = (await codec.getNextFrame()).image;
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw const RecolorException('no pixels');
      return _Decoded(
        Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)),
        image.width,
        image.height,
      );
    } on RecolorException {
      rethrow;
    } catch (e) {
      throw RecolorException('cannot decode the photo: $e');
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

/// The recolor state of ONE result screen: the verdict, and (lazily) the
/// recolored bitmaps. Holds the photo bytes + class map by reference (the
/// result flow already keeps them in memory); dispose it with its owner.
abstract interface class RecolorSession {
  /// Whether / how the recolor is offered (independent of the target).
  RecolorAvailability get availability;

  /// The target colour as `[r, g, b]`.
  List<int> get targetRgb;

  /// Each qualifying region's source colour (its dominant colour on the
  /// hardened split), `[r, g, b]`; a region missing here is recolored from
  /// its mean colour.
  Map<GarmentRegion, List<int>> get sources;

  /// A NEW session with the same verdict and sources (no re-assessment) and
  /// another [target] — e.g. the canvas pop the user selected after the
  /// result was built. It has its own render cache and lifetime.
  RecolorSession withTarget(ui.Color target);

  /// Recolors EVERY offered region at the render size in one worker isolate
  /// (single-flight, cached). Throws [RecolorException] when not available,
  /// disposed, or on a failure.
  Future<Map<GarmentRegion, RecolorFrame>> renderAll();

  /// The recolored frame of [region] (see [renderAll]).
  Future<RecolorFrame> render(GarmentRegion region);

  /// [renderAll] as GPU images, one per offered region. The CALLER owns the
  /// images and must dispose them.
  Future<Map<GarmentRegion, ui.Image>> renderImages();

  /// Drops (and zero-fills) every recolored bitmap. Idempotent.
  void dispose();
}

class _ServiceRecolorSession implements RecolorSession {
  _ServiceRecolorSession({
    required RecolorService service,
    required Uint8List photo,
    required SegmentationClassMap? classMap,
    required List<int> targetRgb,
    required this.availability,
    required Map<GarmentRegion, List<int>> sources,
  })  : _service = service,
        _photo = photo,
        _classMap = classMap,
        _targetRgb = targetRgb,
        _sources = sources;

  final RecolorService _service;
  final Uint8List _photo;
  final SegmentationClassMap? _classMap;
  final List<int> _targetRgb;
  final Map<GarmentRegion, List<int>> _sources;
  Future<Map<GarmentRegion, RecolorFrame>>? _frames;
  bool _disposed = false;

  @override
  final RecolorAvailability availability;

  @override
  List<int> get targetRgb => List<int>.unmodifiable(_targetRgb);

  @override
  Map<GarmentRegion, List<int>> get sources =>
      Map<GarmentRegion, List<int>>.unmodifiable(_sources);

  @override
  RecolorSession withTarget(ui.Color target) => _ServiceRecolorSession(
        service: _service,
        photo: _photo,
        classMap: _classMap,
        targetRgb: rgbOfColor(target),
        availability: availability,
        sources: _sources,
      );

  @override
  Future<Map<GarmentRegion, ui.Image>> renderImages() async {
    final Map<GarmentRegion, RecolorFrame> frames = await renderAll();
    final Map<GarmentRegion, ui.Image> images = <GarmentRegion, ui.Image>{};
    try {
      for (final MapEntry<GarmentRegion, RecolorFrame> e in frames.entries) {
        images[e.key] = await e.value.toImage();
      }
    } catch (e) {
      for (final ui.Image image in images.values) {
        image.dispose();
      }
      throw e is RecolorException ? e : RecolorException('$e');
    }
    return images;
  }

  @override
  Future<Map<GarmentRegion, RecolorFrame>> renderAll() {
    if (_disposed) {
      return Future<Map<GarmentRegion, RecolorFrame>>.error(
          const RecolorException('session disposed'));
    }
    if (!availability.isAvailable) {
      return Future<Map<GarmentRegion, RecolorFrame>>.error(
          const RecolorException('recolor not available for this photo'));
    }
    return _frames ??= _renderAll().catchError((Object e) {
      _frames = null; // let a later tap retry
      throw e is RecolorException ? e : RecolorException('$e');
    });
  }

  @override
  Future<RecolorFrame> render(GarmentRegion region) async {
    final RecolorFrame? frame = (await renderAll())[region];
    if (frame == null) {
      throw RecolorException('region ${region.name} not offered');
    }
    return frame;
  }

  Future<Map<GarmentRegion, RecolorFrame>> _renderAll() async {
    final SegmentationClassMap classMap = _classMap!;
    final _Decoded photo = await _service._decodeRender(_photo, classMap);
    final List<GarmentRegion> regions = availability.regions;
    final List<int> target = _targetRgb;
    final Map<GarmentRegion, List<int>> sources = _sources;
    try {
      final Map<GarmentRegion, Uint8List> out = await Isolate.run(
          () => renderRecolorRegions(classMap, photo.rgba, photo.width,
              photo.height, regions, target, sources),
          debugName: 'recolor-render');
      if (_disposed) {
        for (final Uint8List rgba in out.values) {
          rgba.fillRange(0, rgba.length, 0);
        }
        throw const RecolorException('session disposed');
      }
      return <GarmentRegion, RecolorFrame>{
        for (final MapEntry<GarmentRegion, Uint8List> e in out.entries)
          e.key: RecolorFrame(e.key, photo.width, photo.height, e.value),
      };
    } finally {
      photo.rgba.fillRange(0, photo.rgba.length, 0);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final Future<Map<GarmentRegion, RecolorFrame>>? frames = _frames;
    _frames = null;
    frames?.then((Map<GarmentRegion, RecolorFrame> map) {
      for (final RecolorFrame f in map.values) {
        f.rgba.fillRange(0, f.rgba.length, 0);
      }
    }, onError: (Object _) {});
  }
}

class _Decoded {
  const _Decoded(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

/// Output of [assessRecolor] (plain data, sendable across isolates).
class RecolorAssessment {
  /// Creates an assessment.
  const RecolorAssessment(this.applicability, this.sources);

  /// The applicability verdict at the analysis frame size.
  final RecolorApplicability applicability;

  /// Each region's dominant colour on the hardened split, `[r, g, b]`.
  final Map<GarmentRegion, List<int>> sources;
}

/// `[r, g, b]` of an opaque [ui.Color] (same extraction as `display.dart`).
List<int> rgbOfColor(ui.Color color) => <int>[
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
    ];

/// UX §2.2: the view opens on the qualifying region that does NOT hold the
/// outfit base ("súmale" = the colour to ADD to the other garment); canvas
/// mode (no base) or a single region → the first qualifying region.
GarmentRegion? defaultRecolorRegion(
    List<GarmentRegion> regions, GarmentRegion? baseRegion) {
  if (regions.isEmpty) return null;
  for (final GarmentRegion region in regions) {
    if (region != baseRegion) return region;
  }
  return regions.first;
}

/// Scale of the canonical px constants at a render of longest side [side].
double recolorPxScale(int side) => side / kRecolorReferenceSide;

/// Stage-1 computation, pure and synchronous (runs in a worker isolate;
/// visible for the tests and the benchmark): at the analysis frame size,
/// RAW nearest map (applicability metrics) + smoothed map → hardened
/// un-eroded split (region sizes) → [checkRecolorApplicability]; then the
/// per-garment engine on the hardened split (default erosion, the Dart
/// `analyze_garments(harden=RECOLOR_HARDENING)`, C1c) for each region's
/// dominant colour.
RecolorAssessment assessRecolor(
    SegmentationClassMap classMap, Uint8List rgba, int width, int height) {
  final Uint8List raw = upscaleClassMapNearest(
      classMap.classes, classMap.width, classMap.height, width, height);
  final Uint8List smooth = resampleClassMapSmooth(
      classMap.classes, classMap.width, classMap.height, width, height,
      sigma: kClassMapSmoothSigma * recolorPxScale(math.max(width, height)));
  HardenedSplit? split;
  try {
    split = splitHardenedGarmentMasks(smooth, width, height,
        options: kRecolorHardening.withGrowPx(
            (kRecolorGrowPx * recolorPxScale(math.max(width, height))).round()),
        erodePx: 0);
  } on SegmentationException {
    split = null; // no person on the hardened map: no regions
  }
  final RecolorApplicability applicability = checkRecolorApplicability(
      raw, width, height,
      rgba: rgba, regions: split?.masks ?? <GarmentRegion, Uint8List>{});
  final Map<GarmentRegion, List<int>> sources = <GarmentRegion, List<int>>{};
  if (split != null && applicability.applicable) {
    try {
      final AnalysisResult hardened =
          analyzeSegmentedFrame(rgba, split.toSegmentation());
      for (final GarmentBlockData block in hardened.garments) {
        ColorSample best = block.palette.first;
        for (final ColorSample s in block.palette) {
          if (s.weight > best.weight) best = s;
        }
        sources[block.region] = rgbOfColor(best.color);
      }
    } on SegmentationException {
      // Every region died in the erosion: the recolor falls back to the
      // region's mean colour as its source.
    }
  }
  return RecolorAssessment(applicability, sources);
}

/// Stage-2 computation, pure and synchronous (worker isolate; visible for
/// the tests and the benchmark): smoothed + hardened masks at the render
/// size (px constants scaled by [recolorPxScale]), then [recolorRegion] for
/// each of [regions]. Throws [RecolorException] if a region the assessment
/// offered does not exist at the render size.
Map<GarmentRegion, Uint8List> renderRecolorRegions(
  SegmentationClassMap classMap,
  Uint8List rgba,
  int width,
  int height,
  List<GarmentRegion> regions,
  List<int> targetRgb,
  Map<GarmentRegion, List<int>> sources,
) {
  final double scale = recolorPxScale(math.max(width, height));
  final Uint8List smooth = resampleClassMapSmooth(
      classMap.classes, classMap.width, classMap.height, width, height,
      sigma: kClassMapSmoothSigma * scale);
  final HardenedSplit split;
  try {
    split = splitHardenedGarmentMasks(smooth, width, height,
        options: kRecolorHardening.withGrowPx((kRecolorGrowPx * scale).round()),
        erodePx: 0);
  } on SegmentationException catch (e) {
    throw RecolorException('no regions at render size: ${e.reason}');
  }
  final int feather = math.max(1, (kRecolorFeatherPx * scale).round());
  final Map<GarmentRegion, Uint8List> out = <GarmentRegion, Uint8List>{};
  for (final GarmentRegion region in regions) {
    final Uint8List? mask = split.masks[region];
    if (mask == null) {
      throw RecolorException('region ${region.name} missing at render size');
    }
    out[region] = recolorRegion(rgba, width, height, mask, targetRgb,
        sourceRgb: sources[region], featherPx: feather);
  }
  return out;
}
