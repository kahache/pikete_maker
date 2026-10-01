import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Decodes and NORMALIZES the photo before handing it to the [ColorEngine].
///
/// Why it exists (and why it returns a PNG and not raw pixels):
///  - The picker photo may come in huge; K-means needs no more than ~512 px
///    per side for a faithful palette, and rescaling here is what makes gate
///    G1 achievable (photo→result < 10 s on mid-range).
///  - The `ColorEngine.analyze(Uint8List)` contract carries ONE buffer with
///    no width/height. A raw RGBA dump would be ambiguous (it carries no
///    dimensions), so a PNG is delivered: self-describing, lossless (exact
///    RGB for the color analysis) and trivial to decode in pure Dart.
///  - dart:ui is used (the Flutter engine decodes JPEG/PNG and applies the
///    EXIF orientation): zero new dependencies in the APK.
///
/// NOTE FOR THE ENGINE PORT (D15): you will ALWAYS receive a PNG already
/// rescaled to ≤ [kMaxAnalysisSide] px. If the port prefers raw pixels, this
/// helper changes and the `core/color_engine/` contract is extended with
/// dimensions (PM decision: it is the seam between both territories).
///
/// Throws [UnreadableImageException] if the bytes are not a decodable image
/// (the UI treats it as E3).
const int kMaxAnalysisSide = 512;

class UnreadableImageException implements Exception {}

Future<Uint8List> prepareImageForAnalysis(Uint8List originalBytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(originalBytes);
    // The descriptor reads the dimensions WITHOUT decoding the full bitmap.
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final int longestSide = math.max(descriptor.width, descriptor.height);
    final double factor =
        longestSide > kMaxAnalysisSide ? kMaxAnalysisSide / longestSide : 1.0;

    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * factor).round(),
      targetHeight: (descriptor.height * factor).round(),
    );
    image = (await codec.getNextFrame()).image;

    final ByteData? png =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw UnreadableImageException();
    return png.buffer.asUint8List();
  } on UnreadableImageException {
    rethrow;
  } catch (_) {
    // Corrupt bytes / unsupported format → domain error, not a Flutter one.
    throw UnreadableImageException();
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
