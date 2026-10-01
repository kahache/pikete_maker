import 'dart:typed_data';

import 'models.dart';

/// INTEGRATION POINT of the color core.
///
/// This is the seam where the color pipeline reimplemented in Dart on-device
/// (D15) plugs in. The whole scaffold (analyzing and result screens) depends
/// ONLY on this abstraction, never on a concrete implementation → when the
/// port is ready, the new implementation is registered in a single place (see
/// `app.dart`) and the UI does not change.
///
/// The canonical reference core is the Python package `cv_core/colorlab`
/// (K-means in LAB + cluster merging + chromatic ranking + HSV harmonies).
/// The MVP ports the "whole-photo palette" logic (D1); the background
/// removal / GrabCut is NOT ported (it belongs to Phase 2.5).
abstract interface class ColorEngine {
  /// Analyzes the bytes of an image and returns the palette + harmonies.
  ///
  /// Must be 100% ON-DEVICE and OFFLINE (D2/D15): not a single network call.
  /// Latency target (gate G1): photo→result < 10 s on a mid-range device.
  ///
  /// Throws [ColorEngineException] if a reliable palette cannot be extracted
  /// (no subject / no chromatic base → the UI routes to ugly state E4).
  Future<AnalysisResult> analyze(Uint8List imageBytes);
}

/// Engine error: the photo yields no reliable palette (E4) or the pipeline
/// failed (E3).
class ColorEngineException implements Exception {
  /// Creates an engine failure described by [reason]. Set [isNoOutfit] for
  /// the expected E4 outcome rather than a genuine pipeline fault.
  const ColorEngineException(this.reason, {this.isNoOutfit = false});

  /// Short machine-readable cause, surfaced in crash reports (never to users).
  final String reason;

  /// true → E4 ("aquí no vemos un outfit claro"); false → E3 (failure/timeout).
  final bool isNoOutfit;

  @override
  String toString() => 'ColorEngineException($reason)';
}
