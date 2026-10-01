import 'dart:typed_data';
import 'dart:ui' as ui;

import '../capture/cover_sized_memory_image.dart';
import 'story_layout.dart';

/// Decodes the user's photo into a [ui.Image] sized for the story's photo box
/// (N1 / D37), ready to be PAINTED synchronously by the offscreen story frame.
///
/// Why a `ui.Image` and not an `Image.memory` widget: `renderWidgetToPng`
/// builds, lays out and paints the story tree ONCE, synchronously. An `Image`
/// widget resolves its provider asynchronously, so inside that one-shot tree
/// it would paint NOTHING and the shared story would carry a blank photo
/// (spec §8.4, the known trap). The photo is therefore decoded here FIRST,
/// awaited, and handed to the frame, which paints it with `RawImage`.
///
/// Sized decode (r13 A5 logic, reused): the target size is picked once the
/// codec knows the photo's intrinsic size, with the same [coverDecodeSize]
/// rule `CoverSizedMemoryImage` uses. The box is the story photo box for the
/// photo's own aspect at export resolution (max 980 × 1038 px; a 3:4 photo
/// needs 778 × 1038). The 1-line headline box is used because it is the
/// larger of the two, so the bitmap is never undersized. Picker photos are
/// ≤ 1600 px, so this is always a downscale (or 1:1), never an upscale.
///
/// EXIF orientation: the engine's decoder applies the JPEG Orientation tag,
/// so the returned image is upright, and its [ui.Image.width] /
/// [ui.Image.height] are the ones the layout must use (never the header's).
/// Privacy bonus: the story is re-rendered from pixels, so no EXIF/GPS
/// metadata of the original can ride along into the shared PNG.
///
/// The caller owns the returned image and must `dispose()` it.
/// Throws if [bytes] are not a decodable image.
Future<ui.Image> decodeStoryPhoto(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  // instantiateImageCodecWithSize disposes the buffer itself.
  final ui.Codec codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: storyPhotoDecodeSize,
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// Decode size for a photo of `intrinsicWidth × intrinsicHeight` so that it
/// just covers its story photo box at export resolution.
ui.TargetImageSize storyPhotoDecodeSize(int intrinsicWidth, int intrinsicHeight) {
  if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
    return const ui.TargetImageSize();
  }
  final ui.Size box =
      StoryGeometry.photoBox(intrinsicWidth / intrinsicHeight);
  return coverDecodeSize(
    intrinsicWidth: intrinsicWidth,
    intrinsicHeight: intrinsicHeight,
    boxWidth: (box.width * StoryGeometry.pixelRatio).ceil(),
    boxHeight: (box.height * StoryGeometry.pixelRatio).ceil(),
  );
}
