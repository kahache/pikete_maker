import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// An in-memory image decoded at the size a [BoxFit.cover] box needs, not
/// at the photo's full resolution (review F14, r13 A5).
///
/// Why not plain `Image.memory(cacheWidth: ...)`: the confirm preview is a
/// `BoxFit.cover` box and the photo can be portrait (an outfit selfie) or
/// landscape (a sneaker product shot). A fixed `cacheWidth` equal to the box
/// width is right for the first but UNDERSIZES the second — cover then scales
/// the landscape bitmap up to fill the box height and the preview goes soft.
/// Here the target size is picked at decode time, once the codec knows the
/// photo's intrinsic size ([coverDecodeSize]), so both cases decode to just
/// enough pixels to cover the box.
///
/// Memory: a 1600 px photo decodes to ~7.7 MB of RGBA; the preview box on a
/// mid-range phone needs roughly a third to a half of that.
@immutable
class CoverSizedMemoryImage extends ImageProvider<CoverSizedMemoryImage> {
  /// [boxWidth] / [boxHeight] are the box size in PHYSICAL pixels (logical
  /// size × device pixel ratio).
  const CoverSizedMemoryImage(
    this.bytes, {
    required this.boxWidth,
    required this.boxHeight,
  });

  /// The encoded photo (JPEG/PNG).
  final Uint8List bytes;

  /// Box width in physical pixels.
  final int boxWidth;

  /// Box height in physical pixels.
  final int boxHeight;

  @override
  Future<CoverSizedMemoryImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CoverSizedMemoryImage>(this);

  @override
  ImageStreamCompleter loadImage(
    CoverSizedMemoryImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'CoverSizedMemoryImage(${describeIdentity(key.bytes)})',
    );
  }

  Future<ui.Codec> _loadAsync(
    CoverSizedMemoryImage key,
    ImageDecoderCallback decode,
  ) async {
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(key.bytes);
    return decode(
      buffer,
      getTargetSize: (int intrinsicWidth, int intrinsicHeight) =>
          coverDecodeSize(
        intrinsicWidth: intrinsicWidth,
        intrinsicHeight: intrinsicHeight,
        boxWidth: key.boxWidth,
        boxHeight: key.boxHeight,
      ),
    );
  }

  // Same identity rule as [MemoryImage]: the SAME bytes object (a retake
  // swaps the buffer, which must decode again) at the same box size.
  @override
  bool operator ==(Object other) =>
      other is CoverSizedMemoryImage &&
      identical(other.bytes, bytes) &&
      other.boxWidth == boxWidth &&
      other.boxHeight == boxHeight;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(bytes), boxWidth, boxHeight);
}

/// Smallest decode size that still COVERS a `boxWidth × boxHeight` box
/// (physical pixels) with a photo of `intrinsicWidth × intrinsicHeight`,
/// keeping the aspect ratio. Never upscales: if the photo is already smaller
/// than what the box needs, it decodes at its own size.
///
/// Only the width is pinned; the codec derives the height from the aspect
/// ratio, so the bitmap is never distorted.
ui.TargetImageSize coverDecodeSize({
  required int intrinsicWidth,
  required int intrinsicHeight,
  required int boxWidth,
  required int boxHeight,
}) {
  if (intrinsicWidth <= 0 ||
      intrinsicHeight <= 0 ||
      boxWidth <= 0 ||
      boxHeight <= 0) {
    return const ui.TargetImageSize();
  }
  // Cover = the LARGER of the two axis scales.
  final double scale = math.max(
    boxWidth / intrinsicWidth,
    boxHeight / intrinsicHeight,
  );
  if (scale >= 1.0) return const ui.TargetImageSize();
  return ui.TargetImageSize(width: (intrinsicWidth * scale).ceil());
}
