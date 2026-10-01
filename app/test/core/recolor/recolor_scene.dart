import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:piketemaker/core/segmentation/mask_hardening.dart';

/// Synthetic scene for the recolor service tests and benchmark (no real
/// photo: `app/test/**` is exported to the public repo). A person drawn in
/// normalized coordinates, rasterized both as a 256×256 model class map and
/// as a textured photo of any size, so the two stay aligned.

/// Scene colours (RGB).
const List<int> kSceneWall = <int>[196, 190, 180];
const List<int> kSceneSkin = <int>[205, 160, 125];
const List<int> kSceneHair = <int>[60, 45, 35];

/// Top (the chromatic outfit base in the tests) and trousers.
const List<int> kSceneTop = <int>[178, 42, 52];
const List<int> kSceneTrousers = <int>[40, 72, 160];

/// Class of the normalized point (u, v) in [0, 1)² of a person centred at
/// [cx] with [scale] (1 = fills the frame height).
int _personClass(double u, double v, double cx, double top, double scale) {
  final double y = (v - top) / scale;
  final double x = (u - cx) / scale;
  if (y < 0 || y >= 1) return SegClass.background;
  if (y < 0.08 && x.abs() < 0.09) return SegClass.hair;
  if (y < 0.2 && x.abs() < 0.075) return SegClass.faceSkin;
  if (y < 0.24 && x.abs() < 0.04) return SegClass.bodySkin;
  if (y < 0.56 && x.abs() < 0.19) return SegClass.clothes; // top
  if (y < 0.56 && x.abs() < 0.24) return SegClass.bodySkin; // bare arms
  if (y < 0.96 && x.abs() < 0.15) return SegClass.clothes; // trousers
  return SegClass.background;
}

/// Class at (u, v) of the scene: one person, or two ([twoPeople]).
int sceneClass(double u, double v, {bool twoPeople = false}) {
  if (!twoPeople) return _personClass(u, v, 0.5, 0.02, 0.95);
  final int a = _personClass(u, v, 0.3, 0.02, 0.9);
  if (a != SegClass.background) return a;
  return _personClass(u, v, 0.75, 0.25, 0.6);
}

/// The 256×256 model class map of the scene.
Uint8List sceneModelMap({bool twoPeople = false}) {
  const int side = 256;
  final Uint8List map = Uint8List(side * side);
  for (int y = 0; y < side; y++) {
    for (int x = 0; x < side; x++) {
      map[y * side + x] =
          sceneClass((x + 0.5) / side, (y + 0.5) / side, twoPeople: twoPeople);
    }
  }
  return map;
}

/// The textured RGBA photo of the scene at [width] × [height].
/// [exposure] scales every channel (a dim photo < 1).
Uint8List scenePhotoRgba(int width, int height,
    {bool twoPeople = false, double exposure = 1.0}) {
  final Uint8List rgba = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final double u = (x + 0.5) / width;
      final double v = (y + 0.5) / height;
      final int cls = sceneClass(u, v, twoPeople: twoPeople);
      List<int> c;
      double shade = 1.0;
      switch (cls) {
        case SegClass.hair:
          c = kSceneHair;
        case SegClass.faceSkin:
        case SegClass.bodySkin:
          c = kSceneSkin;
        case SegClass.clothes:
          c = v < 0.55 ? kSceneTop : kSceneTrousers;
          shade = 0.8 + 0.2 * math.sin(u * 90) * math.cos(v * 40);
        default:
          c = kSceneWall;
      }
      final int p = (y * width + x) * 4;
      for (int ch = 0; ch < 3; ch++) {
        rgba[p + ch] = (c[ch] * shade * exposure).round().clamp(0, 255);
      }
      rgba[p + 3] = 255;
    }
  }
  return rgba;
}

/// PNG bytes of an RGBA buffer (what the picker would hand the flow).
Future<Uint8List> encodePng(Uint8List rgba, int width, int height) async {
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(rgba);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(buffer,
      width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888);
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}
