import 'dart:typed_data';

/// INTEGRATION POINT of clothing segmentation (Phase 2.5, D21).
///
/// This is the seam where on-device garment segmentation plugs into the color
/// pipeline. Today the app extracts ONE palette from the whole photo (D1); the
/// differentiator (PRD §product, not-optional) is to run the palette per
/// garment (top / bottom). The whole scaffold depends ONLY on this abstraction,
/// never on a concrete implementation → when the MediaPipe port is ready, the
/// new implementation is registered in a single place (see `ColorEngineDart`)
/// and neither the color engine nor the UI has to change.
///
/// The confirmed v1 model is **MediaPipe Selfie Multiclass** (D21, validated in
/// `docs/architecture/2026-07-10_1700_F2.5_mediapipe-prototype.md`): a 16.37 MB
/// Apache-2.0 `.tflite` that emits 6 classes and whose learned skin class
/// retires the crude YCbCr proxy. The MVP default remains whole-photo
/// ([WholePhotoSegmenter]) so this scaffold is a strict no-op until the model
/// is wired.

/// The garment regions a segmenter can select.
///
/// [whole] = every pixel (the MVP behavior, no segmentation). [upper] / [lower]
/// = the two garment regions of the top/bottom split (D21: no footwear). The
/// v1 split is the geometric mid-height of the clothes bounding box; v1.1
/// refines it with MediaPipe Pose hip landmarks (see the ADR).
enum GarmentRegion {
  /// Every pixel — the MVP behavior, no segmentation (D1).
  whole,

  /// The top garment (shirt, jacket…).
  upper,

  /// The bottom garment (trousers, skirt…).
  lower,
}

/// Per-pixel selection for the garment regions found in ONE decoded RGBA frame.
///
/// A [mask] is a per-pixel `0/1` buffer of length `width * height` (row-major,
/// same order as the decoded RGBA pixels): `mask[i] == 1` means pixel `i` (at
/// RGBA byte offset `i * 4`) belongs to that region. This mirrors the backend
/// contract `segment_garments(rgb) -> {"upper": mask, "lower": mask}` validated
/// end-to-end in the MediaPipe prototype, so the Python reference and the
/// on-device port speak the same shape.
class GarmentSegmentation {
  /// Creates a segmentation of a [width]×[height] frame from its [masks].
  const GarmentSegmentation({
    required this.width,
    required this.height,
    required this.masks,
    this.classMap,
  });

  /// Width of the decoded frame the masks index into (post-downscale).
  final int width;

  /// Height of the decoded frame the masks index into (post-downscale).
  final int height;

  /// region -> per-pixel selection (length `width * height`, values 0 or 1).
  final Map<GarmentRegion, Uint8List> masks;

  /// The model's per-pixel class map these masks were cut from, when the
  /// segmenter has one (MediaPipe: the 256x256 argmax map; whole-photo:
  /// null). Kept for the I2 recolor (D38), which rebuilds SMOOTH hardened
  /// masks from it at the render size. Memory only (64 KB), never persisted.
  final SegmentationClassMap? classMap;

  /// The regions this segmentation actually produced (whole-photo → just
  /// [GarmentRegion.whole]; MediaPipe → [GarmentRegion.upper]/[lower]).
  Iterable<GarmentRegion> get regions => masks.keys;

  /// The selection mask for [region], or null if this segmenter did not produce
  /// it. A null mask means "no constraint" downstream (all pixels), so a
  /// consumer can treat a missing [GarmentRegion.whole] as the full frame.
  Uint8List? maskFor(GarmentRegion region) => masks[region];
}

/// A model-side class map (MediaPipe Selfie Multiclass ids, D21) plus the
/// size of the decoded frame it was computed from.
///
/// Why it is kept (I2, D38): the palette only needs the upper/lower masks,
/// but the recolor re-derives SMOOTH, hardened masks at the photo's render
/// size, which needs the raw classes (not the nearest-upscaled masks, whose
/// 256-px staircase is visible on a recolored edge). 256x256 bytes; it lives
/// in memory with the analysis result and is never written anywhere (privacy
/// D37/D38: it is derived from the user's photo).
class SegmentationClassMap {
  /// Creates a [width]x[height] class map computed from a
  /// [frameWidth]x[frameHeight] decoded frame.
  const SegmentationClassMap({
    required this.width,
    required this.height,
    required this.classes,
    required this.frameWidth,
    required this.frameHeight,
  });

  /// Class-map width (the model side, 256, for MediaPipe).
  final int width;

  /// Class-map height.
  final int height;

  /// Row-major class ids (length `width * height`, values 0..5).
  final Uint8List classes;

  /// Width of the decoded analysis frame (post-downscale) the map covers.
  final int frameWidth;

  /// Height of the decoded analysis frame.
  final int frameHeight;
}

/// Produces a per-region pixel selection for the garments in a decoded frame.
///
/// Must be 100% ON-DEVICE and OFFLINE (D2/D21): not a single network call.
/// Latency target (D22, gate G2.5): non-blocking — the analysis progress
/// animation (and the rewarded ad slot, F8) cover it. The prototype measured
/// 0.43 s on laptop CPU for the MediaPipe model; the Android GPU delegate is
/// typically an order of magnitude faster.
abstract interface class GarmentSegmenter {
  /// Segments the decoded RGBA pixels ([rgba], length `width * height * 4`,
  /// row-major) into per-region masks. Runs the model ONCE and returns all
  /// regions it knows about, so a caller wanting both top and bottom does not
  /// pay for inference twice.
  ///
  /// Throws [SegmentationException] if the model cannot run or finds no person
  /// (the UI routes to an ugly state, analogous to E4). A whole-photo segmenter
  /// never throws.
  Future<GarmentSegmentation> segment(Uint8List rgba, int width, int height);
}

/// Segmentation error: the model failed to run or found no person / no garment.
///
/// Mirrors [ColorEngineException]'s style; kept separate so the color engine
/// can decide how to degrade (e.g. fall back to whole-photo) rather than
/// surfacing a raw exception.
class SegmentationException implements Exception {
  /// Creates a segmentation failure described by [reason]. Set [isNoPerson]
  /// when the frame simply has no dressed person rather than the model
  /// having failed.
  const SegmentationException(this.reason, {this.isNoPerson = false});

  /// Short machine-readable cause, for crash reports (never shown to users).
  final String reason;

  /// true → the frame has no detectable person/garment (route to an E4-like
  /// ugly state); false → the model itself failed to run (E3-like).
  final bool isNoPerson;

  @override
  String toString() => 'SegmentationException($reason)';
}
