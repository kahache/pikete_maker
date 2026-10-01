import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/color_engine/models.dart';

/// End-to-end tests of the real engine: image bytes -> AnalysisResult.
///
/// The test PNG is generated with Canvas + toByteData(png) from Flutter's
/// own engine: zero new dependencies (gate G1) and exact known colors.

const List<int> navy = <int>[30, 50, 110];
const List<int> mustard = <int>[200, 150, 40];

/// 100x100 PNG: 70% navy (top) / 30% mustard (bottom), no antialiasing so
/// only two exact colors exist.
Future<Uint8List> _twoColorPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..isAntiAlias = false;
  paint.color = const ui.Color(0xFF1E326E); // navy (30, 50, 110)
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 70), paint);
  paint.color = const ui.Color(0xFFC89628); // mustard (200, 150, 40)
  canvas.drawRect(const ui.Rect.fromLTWH(0, 70, 100, 30), paint);
  final ui.Image image = await recorder.endRecording().toImage(100, 100);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

/// Fully transparent 8x8 PNG (canvas with nothing drawn).
Future<Uint8List> _transparentPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  final ui.Image image = await recorder.endRecording().toImage(8, 8);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

List<int> _channels(ColorSample sample) {
  // ignore: deprecated_member_use  (Color.value: universal across Flutter 3.19+)
  final int value = sample.color.value;
  return <int>[(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ColorEngineDart engine = ColorEngineDart();

  test('navy/mustard 70-30 PNG -> palette, D5 base and 4 harmonies', () async {
    final Uint8List png = await _twoColorPng();
    final AnalysisResult res = await engine.analyze(png);

    expect(res.palette, hasLength(2));
    // Exact colors from the PNG (minimal tolerance for the codec roundtrip).
    for (int d = 0; d < 3; d++) {
      expect(_channels(res.palette[0])[d], closeTo(navy[d], 2));
      expect(_channels(res.palette[1])[d], closeTo(mustard[d], 2));
    }
    expect(res.palette[0].weight, closeTo(0.7, 0.02));
    expect(res.palette[1].weight, closeTo(0.3, 0.02));

    // D5 base: navy wins (saturation 0.73 * weight 0.7 > 0.8 * 0.3).
    expect(res.baseIndex, 0);
    expect(res.base, isNotNull);

    // The 4 harmonies, in mockup order, each one containing the base.
    expect(res.harmonies, hasLength(4));
    expect(
      <HarmonyType>[for (final Harmony h in res.harmonies) h.type],
      <HarmonyType>[
        HarmonyType.complementary,
        HarmonyType.analogous,
        HarmonyType.triadic,
        HarmonyType.splitComplementary,
      ],
    );
    for (final Harmony harmony in res.harmonies) {
      expect(harmony.name, isNotEmpty);
      expect(harmony.description, isNotEmpty);
      expect(harmony.colors, contains(res.base!.color));
    }
  });

  test('the analysis is deterministic: same photo -> same palette', () async {
    final Uint8List png = await _twoColorPng();
    final AnalysisResult a = await engine.analyze(png);
    final AnalysisResult b = await engine.analyze(png);
    expect(
      <String>[for (final ColorSample s in a.palette) s.hex],
      <String>[for (final ColorSample s in b.palette) s.hex],
    );
    expect(
      <double>[for (final ColorSample s in a.palette) s.weight],
      <double>[for (final ColorSample s in b.palette) s.weight],
    );
  });

  test('corrupt bytes -> ColorEngineException (ugly state E3)', () async {
    await expectLater(
      engine.analyze(Uint8List.fromList(<int>[1, 2, 3, 4, 5])),
      throwsA(isA<ColorEngineException>().having(
          (ColorEngineException e) => e.isNoOutfit, 'isNoOutfit', isFalse)),
    );
  });

  test('100% transparent image -> E4 (no outfit)', () async {
    final Uint8List png = await _transparentPng();
    await expectLater(
      engine.analyze(png),
      throwsA(isA<ColorEngineException>().having(
          (ColorEngineException e) => e.isNoOutfit, 'isNoOutfit', isTrue)),
    );
  });

  group('extractRgbaPixels (deterministic subsampling)', () {
    test('respects the pixel cap and is reproducible', () {
      // 120k synthetic RGBA pixels (3x the cap) with varied colors.
      const int n = 120000;
      final Uint8List rgba = Uint8List(n * 4);
      for (int i = 0; i < n; i++) {
        rgba[i * 4] = i % 256;
        rgba[i * 4 + 1] = (i * 7) % 256;
        rgba[i * 4 + 2] = (i * 13) % 256;
        rgba[i * 4 + 3] = 255;
      }
      final Float64List a = extractRgbaPixels(rgba);
      final Float64List b = extractRgbaPixels(rgba);

      expect(a.length % 3, 0);
      expect(a.length ~/ 3, lessThanOrEqualTo(kMaxKmeansPixels));
      // enough sample for the palette (> half the cap)
      expect(a.length ~/ 3, greaterThan(kMaxKmeansPixels ~/ 2));
      expect(a, b); // fixed step, nothing random
    });

    test('discards transparent pixels', () {
      // 100 pixels: 50 opaque red, 50 transparent.
      final Uint8List rgba = Uint8List(100 * 4);
      for (int i = 0; i < 50; i++) {
        rgba[i * 4] = 255;
        rgba[i * 4 + 3] = 255;
      }
      final Float64List pixels = extractRgbaPixels(rgba);
      expect(pixels.length ~/ 3, 50);
      for (int i = 0; i < pixels.length; i += 3) {
        expect(pixels[i], 255.0);
      }
    });
  });
}
