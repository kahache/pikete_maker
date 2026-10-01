import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared helpers of the N1 story tests (not a test file itself).
///
/// PRIVACY: every "photo" here is SYNTHETIC — drawn with dart:ui at test time
/// (or the 1 KB solid-colour EXIF fixture). No real photo is used anywhere.

/// Quadrant colours of [quadrantPhoto]; chosen far from the band fixtures
/// (rust/denim/crema), the logo (turquoise/purple/ink) and white.
const Color qTopLeft = Color(0xFFE53935); // red
const Color qTopRight = Color(0xFF2E9E4F); // green
const Color qBottomLeft = Color(0xFF7B1FA2); // violet
const Color qBottomRight = Color(0xFFFDD835); // yellow

/// A synthetic photo of four solid quadrants (PNG bytes). Real async: call
/// inside `runAsync`.
Future<Uint8List> quadrantPhoto(int width, int height) {
  return _paintPng(width, height, (Canvas canvas, Size size) {
    final double w = size.width / 2, h = size.height / 2;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = qTopLeft)
      ..drawRect(Rect.fromLTWH(w, 0, w, h), Paint()..color = qTopRight)
      ..drawRect(Rect.fromLTWH(0, h, w, h), Paint()..color = qBottomLeft)
      ..drawRect(Rect.fromLTWH(w, h, w, h), Paint()..color = qBottomRight);
  });
}

/// A synthetic, featureless ILLUSTRATED outfit "photo" (PNG bytes): the same
/// drawn placeholder figure the design mockup uses (wall, floor, a figure in
/// a [top] and [pants]). Rights-clean by construction. Aspect = width/height.
Future<Uint8List> illustratedOutfitPhoto(
  int width,
  int height, {
  Color top = const Color(0xFFECE7DE),
  Color pants = const Color(0xFFC4572A),
}) {
  return _paintPng(width, height, (Canvas canvas, Size size) {
    // The figure is drawn in a 300 × 400 viewBox, centred and scaled to
    // cover the canvas height (xMidYMid slice).
    const Color wall = Color(0xFFDAD4CA);
    const Color floor = Color(0xFFBDB2A3);
    const Color skin = Color(0xFFB89A84);
    const Color hair = Color(0xFF2B2420);
    const Color shoe = Color(0xFFF4F2EE);
    const Color sole = Color(0xFF2A2730);
    final double s = size.height / 400;
    final double floorY = size.height * 330 / 400;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, floorY), Paint()..color = wall)
      ..drawRect(Rect.fromLTWH(0, floorY, size.width, size.height - floorY),
          Paint()..color = floor)
      ..save()
      ..translate((size.width - 300 * s) / 2, 0)
      ..scale(s);
    Paint p(Color c) => Paint()..color = c;
    canvas.drawOval(Rect.fromCenter(center: const Offset(150, 366), width: 144, height: 14),
        p(const Color(0x1F000000)));
    // Trousers.
    canvas.drawPath(
        Path()
          ..moveTo(104, 198)
          ..lineTo(196, 198)
          ..lineTo(192, 350)
          ..lineTo(158, 350)
          ..lineTo(151, 236)
          ..lineTo(144, 350)
          ..lineTo(108, 350)
          ..close(),
        p(pants));
    // Shoes + soles.
    canvas
      ..drawRRect(RRect.fromLTRBR(96, 348, 150, 362, const Radius.circular(6)), p(shoe))
      ..drawRRect(RRect.fromLTRBR(152, 348, 206, 362, const Radius.circular(6)), p(shoe))
      ..drawRRect(RRect.fromLTRBR(96, 360, 150, 364, const Radius.circular(2)), p(sole))
      ..drawRRect(RRect.fromLTRBR(152, 360, 206, 364, const Radius.circular(2)), p(sole));
    // Sleeves, hands, neck, torso.
    canvas.drawPath(
        Path()
          ..moveTo(96, 106)
          ..quadraticBezierTo(80, 112, 78, 140)
          ..lineTo(74, 206)
          ..lineTo(92, 206)
          ..lineTo(98, 150)
          ..close(),
        p(top));
    canvas.drawPath(
        Path()
          ..moveTo(204, 106)
          ..quadraticBezierTo(220, 112, 222, 140)
          ..lineTo(226, 206)
          ..lineTo(208, 206)
          ..lineTo(202, 150)
          ..close(),
        p(top));
    canvas
      ..drawOval(Rect.fromCenter(center: const Offset(83, 212), width: 16, height: 18), p(skin))
      ..drawOval(Rect.fromCenter(center: const Offset(217, 212), width: 16, height: 18), p(skin))
      ..drawRect(const Rect.fromLTWH(141, 80, 18, 24), p(skin));
    canvas.drawPath(
        Path()
          ..moveTo(96, 106)
          ..quadraticBezierTo(120, 96, 150, 96)
          ..quadraticBezierTo(180, 96, 204, 106)
          ..lineTo(200, 206)
          ..lineTo(100, 206)
          ..close(),
        p(top));
    // Head + hair.
    canvas.drawOval(Rect.fromCenter(center: const Offset(150, 60), width: 42, height: 50), p(skin));
    canvas.drawPath(
        Path()
          ..moveTo(129, 58)
          ..quadraticBezierTo(128, 32, 150, 32)
          ..quadraticBezierTo(173, 32, 171, 58)
          ..quadraticBezierTo(164, 44, 150, 44)
          ..quadraticBezierTo(136, 44, 129, 58)
          ..close(),
        p(hair));
    canvas.restore();
  });
}

/// A synthetic, generic PRODUCT "photo" of a sneaker (PNG bytes): the same
/// drawn placeholder the design mockup uses (no brand, no trademark), centred
/// on a warm-grey backdrop. Rights-clean by construction.
Future<Uint8List> illustratedSneakerPhoto(
  int width,
  int height, {
  Color upper = const Color(0xFF2F7A4D),
}) {
  return _paintPng(width, height, (Canvas canvas, Size size) {
    const Color backdrop = Color(0xFFE8E4DD);
    const Color sole = Color(0xFFF6F4F0);
    canvas.drawRect(Offset.zero & size, Paint()..color = backdrop);
    // 300 × 300 viewBox, fitted to the width and centred vertically.
    final double s = size.width / 300;
    canvas
      ..save()
      ..translate(0, (size.height - 300 * s) / 2)
      ..scale(s);
    Paint p(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(152, 208), width: 240, height: 20),
        p(const Color(0x1F000000)));
    canvas.drawPath(
        Path()
          ..moveTo(40, 180)
          ..lineTo(262, 180)
          ..quadraticBezierTo(272, 180, 270, 192)
          ..quadraticBezierTo(268, 204, 254, 204)
          ..lineTo(48, 204)
          ..quadraticBezierTo(36, 204, 36, 192)
          ..quadraticBezierTo(36, 180, 40, 180)
          ..close(),
        p(sole));
    canvas.drawRRect(RRect.fromLTRBR(38, 198, 268, 204, const Radius.circular(3)),
        p(const Color(0xFFCFC9C0)));
    canvas.drawPath(
        Path()
          ..moveTo(48, 180)
          ..quadraticBezierTo(46, 138, 70, 120)
          ..lineTo(118, 96)
          ..quadraticBezierTo(130, 90, 140, 100)
          ..lineTo(160, 124)
          ..quadraticBezierTo(190, 130, 226, 144)
          ..quadraticBezierTo(262, 156, 264, 180)
          ..close(),
        p(upper));
    canvas.drawPath(
        Path()
          ..moveTo(196, 140)
          ..quadraticBezierTo(236, 150, 262, 172)
          ..lineTo(264, 180)
          ..lineTo(200, 180)
          ..close(),
        p(const Color(0x2EFFFFFF)));
    canvas.drawPath(
        Path()
          ..moveTo(70, 120)
          ..lineTo(100, 106)
          ..lineTo(112, 180)
          ..lineTo(84, 180)
          ..close(),
        p(const Color(0x1F000000)));
    canvas.drawPath(
        Path()
          ..moveTo(112, 164)
          ..quadraticBezierTo(160, 150, 214, 158),
        stroke(sole, 8));
    canvas
      ..drawLine(const Offset(132, 108), const Offset(146, 114), stroke(sole, 4))
      ..drawLine(const Offset(140, 100), const Offset(154, 108), stroke(sole, 4))
      ..drawLine(const Offset(146, 118), const Offset(160, 122), stroke(sole, 4));
    canvas.drawPath(
        Path()
          ..moveTo(104, 98)
          ..quadraticBezierTo(118, 88, 132, 96),
        stroke(const Color(0xFF1F4F33), 6));
    canvas.restore();
  });
}

/// Per-pixel pseudo-random noise (PNG bytes, seeded): worst-case photo
/// entropy for PNG-encode timing. Real async: call inside `runAsync`.
Future<Uint8List> noisePhoto(int width, int height, {int seed = 42}) async {
  final Random rnd = Random(seed);
  final Uint8List rgba = Uint8List(width * height * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i] = rnd.nextInt(256);
    rgba[i + 1] = rnd.nextInt(256);
    rgba[i + 2] = rnd.nextInt(256);
    rgba[i + 3] = 255;
  }
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(buffer,
      width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888);
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data =
      (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return data.buffer.asUint8List();
}

Future<Uint8List> _paintPng(
  int width,
  int height,
  void Function(Canvas canvas, Size size) paint,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  paint(canvas, Size(width.toDouble(), height.toDouble()));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData data =
      (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  picture.dispose();
  return data.buffer.asUint8List();
}

/// The EXIF Orientation = 6 fixture: stored LANDSCAPE 160×120 (left half red,
/// right half blue), displayed PORTRAIT 120×160 (top red, bottom blue).
Uint8List exif6Fixture() =>
    File('test/features/story/fixtures/exif6_portrait.jpg').readAsBytesSync();
const Color exifTopColor = Color(0xFFDC2828);
const Color exifBottomColor = Color(0xFF2828DC);

/// Width/height from a PNG's IHDR chunk (big-endian at bytes 16..23).
(int, int) pngSize(Uint8List png) {
  final ByteData d = ByteData.sublistView(png);
  return (d.getUint32(16), d.getUint32(20));
}

/// PNG magic number.
const List<int> pngSignature = <int>[0x89, 0x50, 0x4E, 0x47];

/// Decoded RGBA pixels + colour helpers.
class Pixels {
  Pixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;

  /// Real async: call inside `runAsync`.
  static Future<Pixels> decode(Uint8List png) async {
    final ui.Codec codec = await ui.instantiateImageCodec(png);
    final ui.Image image = (await codec.getNextFrame()).image;
    final Pixels p = await fromImage(image);
    image.dispose();
    codec.dispose();
    return p;
  }

  static Future<Pixels> fromImage(ui.Image image) async {
    final ByteData data =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Pixels(image.width, image.height, data.buffer.asUint8List());
  }

  Color at(int x, int y) {
    final int i = (y * width + x) * 4;
    return Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
  }

  /// True if the pixel at (x, y) is within [tol] (per channel) of [color].
  bool isNear(int x, int y, Color color, {int tol = 8}) {
    final Color p = at(x, y);
    int ch(double v) => (v * 255).round();
    return (ch(p.r) - ch(color.r)).abs() <= tol &&
        (ch(p.g) - ch(color.g)).abs() <= tol &&
        (ch(p.b) - ch(color.b)).abs() <= tol;
  }

  /// Bounding box of the pixels within [tol] of [color], or null if none.
  Rect? bboxOf(Color color, {int tol = 6}) {
    final int r = (color.r * 255).round();
    final int g = (color.g * 255).round();
    final int b = (color.b * 255).round();
    int minX = width, minY = height, maxX = -1, maxY = -1;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int i = (y * width + x) * 4;
        if ((rgba[i] - r).abs() <= tol &&
            (rgba[i + 1] - g).abs() <= tol &&
            (rgba[i + 2] - b).abs() <= tol) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return null;
    return Rect.fromLTRB(
        minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0);
  }
}

/// Loads the real Android faces (Roboto) from the Flutter SDK so text
/// measures and renders like on a phone (the default test font's glyphs are
/// 1 em squares, ~50% wider than Roboto). Resolved from the running
/// flutter_tester binary: <flutter>/bin/cache/artifacts/material_fonts.
/// Loading fonts is process-wide: only call it from files that want it.
Future<void> loadRealFonts() async {
  Directory dir = File(Platform.resolvedExecutable).parent;
  while (!Directory('${dir.path}/material_fonts').existsSync()) {
    final Directory up = dir.parent;
    if (up.path == dir.path) {
      fail('material_fonts not found above ${Platform.resolvedExecutable}');
    }
    dir = up;
  }
  final String fonts = '${dir.path}/material_fonts';
  ByteData read(String name) =>
      ByteData.sublistView(File('$fonts/$name').readAsBytesSync());
  final FontLoader roboto = FontLoader('Roboto');
  for (final String f in <String>[
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(Future<ByteData>.value(read(f)));
  }
  await roboto.load();
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(read('materialicons-regular.otf')));
  await icons.load();
}
