import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/color_engine/harmony.dart' show kCanvasAccents;
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// Integration tests engine -> UI: [ResultScreen] fed with the REAL output of
/// [ColorEngineDart], not a hand-built fixture.
///
/// Born from a device bug (r3): the harmony swatches rendered BLANK because a
/// childless ColoredBox inside a Row without `stretch` collapses to height 0.
/// The model was correct and the fixture-based widget test (which only checks
/// texts) passed, so nothing caught it. These tests pin down what actually
/// PAINTS: real geometry (> 0), full opacity and non-white swatch colors, and
/// the BASE badge landing on the semantically correct swatch (D5).

/// Vertical stripes PNG (200x200) with exact colors and fractional widths:
/// deterministic input with a known expected palette.
Future<Uint8List> _stripesPng(List<(ui.Color, double)> stripes) async {
  const int side = 200;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..isAntiAlias = false;
  double x = 0;
  for (final (ui.Color, double) stripe in stripes) {
    paint.color = stripe.$1;
    final double width = (side * stripe.$2).roundToDouble();
    canvas.drawRect(ui.Rect.fromLTWH(x, 0, width, side.toDouble()), paint);
    x += width;
  }
  final ui.Image image = await recorder.endRecording().toImage(side, side);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

/// Generates the PNG and runs the REAL engine inside a widget test.
/// `runAsync` is mandatory for BOTH steps: `toImage` and `Isolate.run` use
/// real async whose messages never arrive inside the test's fake-async zone
/// (the test would hang until timeout).
Future<AnalysisResult> _analyze(
        WidgetTester tester, List<(ui.Color, double)> stripes) async =>
    (await tester.runAsync(() async {
      final Uint8List png = await _stripesPng(stripes);
      return const ColorEngineDart().analyze(png);
    }))!;

Future<void> _pumpResult(WidgetTester tester, AnalysisResult result) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: ResultScreen(result: result)),
  );
  await tester.pumpAndSettle();
}

/// The harmony swatches are the ColoredBox inside the strips (the harmony
/// rows are the only InkWell widgets declared by the screen).
Finder _harmonySwatches() => find.descendant(
    of: find.byType(InkWell), matching: find.byType(ColoredBox));

void main() {
  testWidgets(
      'REGRESSION r3: harmony swatches PAINT (visible size, opaque, non-white)',
      (WidgetTester tester) async {
    // 70% saturated navy + 30% neutral gray.
    final AnalysisResult result = await _analyze(
      tester,
      <(ui.Color, double)>[
        (const ui.Color(0xFF1E326E), 0.7),
        (const ui.Color(0xFFB0B0B0), 0.3),
      ],
    );
    await _pumpResult(tester, result);

    // The 4 harmony rows exist with their swatch strips: 2 (complementary)
    // + 3 (analogous) + 3 (triadic) + 3 (split complementary).
    expect(result.harmonies, hasLength(4));
    final Iterable<Element> swatches = _harmonySwatches().evaluate();
    expect(swatches, hasLength(2 + 3 + 3 + 3));

    for (final Element element in swatches) {
      final ColoredBox box = element.widget as ColoredBox;
      final Size size = element.size!;
      // THE r3 bug: they laid out at height 0 and painted nothing.
      expect(size.height, greaterThan(20),
          reason: 'swatch ${box.color} collapsed: $size');
      expect(size.width, greaterThan(20),
          reason: 'swatch ${box.color} collapsed: $size');
      // Full alpha (a Color(0xRRGGBB) built without alpha is invisible).
      expect(box.color.a, 1.0, reason: 'swatch ${box.color} is not opaque');
      // Non-white: with a navy base no scheme contains white.
      expect(box.color.toARGB32() & 0xFFFFFF, isNot(0xFFFFFF),
          reason: 'blank/white swatch');
    }
  });

  testWidgets('palette bands PAINT with the real engine (same bug class)',
      (WidgetTester tester) async {
    final AnalysisResult result = await _analyze(
      tester,
      <(ui.Color, double)>[
        (const ui.Color(0xFF1E326E), 0.7),
        (const ui.Color(0xFFC89628), 0.3),
      ],
    );
    await _pumpResult(tester, result);

    for (final ColorSample sample in result.palette) {
      expect(sample.color.a, 1.0,
          reason: 'palette color ${sample.hex} is not opaque');
      // Its band (rectangular DecoratedBox with the sample color) exists and
      // has area. The circle is excluded: the base color also paints the
      // BASE line's circular chip.
      final Finder band = find.byWidgetPredicate((Widget w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.rectangle &&
          (w.decoration as BoxDecoration).color == sample.color);
      expect(band, findsOneWidget);
      expect(tester.getSize(band).height, greaterThan(0));
      expect(tester.getSize(band).width, greaterThan(0));
    }
  });

  group('BASE badge lands on the semantically correct swatch (D5)', () {
    /// The hex of the base swatch renders in bold (w700); the others in w500.
    void expectBaseHexBold(WidgetTester tester, AnalysisResult result) {
      for (int i = 0; i < result.palette.length; i++) {
        final Text hexText =
            tester.widget<Text>(find.text(result.palette[i].hex));
        expect(
          hexText.style!.fontWeight,
          i == result.baseIndex ? FontWeight.w700 : FontWeight.w500,
          reason: 'swatch $i (${result.palette[i].hex}) badged wrong',
        );
      }
    }

    testWidgets('a) dominant saturated color -> base is the FIRST swatch',
        (WidgetTester tester) async {
      final AnalysisResult result = await _analyze(
        tester,
        <(ui.Color, double)>[
          (const ui.Color(0xFF1E326E), 0.7), // saturated navy, dominant
          (const ui.Color(0xFFB0B0B0), 0.3), // neutral gray
        ],
      );
      await _pumpResult(tester, result);

      expect(result.baseIndex, 0, reason: 'D5: sat*weight -> dominant navy');
      expect(find.text('BASE'), findsOneWidget);
      expectBaseHexBold(tester, result);
    });

    testWidgets('b) minority pop among neutrals -> base is THAT swatch',
        (WidgetTester tester) async {
      final AnalysisResult result = await _analyze(
        tester,
        <(ui.Color, double)>[
          (const ui.Color(0xFFE8E8E8), 0.6), // near white
          (const ui.Color(0xFF9E9E9E), 0.3), // gray
          (const ui.Color(0xFFE02020), 0.1), // vivid red pop
        ],
      );
      await _pumpResult(tester, result);

      // The base is the red one — identified by CONTENT, not by position.
      expect(result.baseIndex, greaterThanOrEqualTo(0));
      final ColorSample base = result.base!;
      expect(base.color.r, greaterThan(180 / 255),
          reason: 'the base must be the red pop, got ${base.hex}');
      expect(base.color.g, lessThan(90 / 255));
      expect(find.text('BASE'), findsOneWidget);
      expectBaseHexBold(tester, result);
    });
  });

  group('canvas mode (D10, #21): 100% neutral outfit', () {
    testWidgets(
        'engine -> curated accents, no base, no harmonies; UI shows the canvas',
        (WidgetTester tester) async {
      // All-neutral outfit: charcoal + gray + off-white. No chromatic base.
      final AnalysisResult result = await _analyze(
        tester,
        <(ui.Color, double)>[
          (const ui.Color(0xFF222226), 0.6),
          (const ui.Color(0xFF808080), 0.25),
          (const ui.Color(0xFFEEEEEE), 0.15),
        ],
      );

      // Engine contract: canvas mode, no arbitrary harmonies (bug B3), and the
      // curated accent set surfaced verbatim.
      expect(result.isCanvas, isTrue, reason: 'baseIndex=${result.baseIndex}');
      expect(result.baseIndex, -1);
      expect(result.harmonies, isEmpty);
      expect(result.base, isNull);
      expect(result.canvasAccents, hasLength(kCanvasAccents.length));
      for (int i = 0; i < kCanvasAccents.length; i++) {
        final List<int> rgb = kCanvasAccents[i];
        expect(result.canvasAccents[i],
            ui.Color.fromARGB(0xFF, rgb[0], rgb[1], rgb[2]));
      }

      await _pumpResult(tester, result);

      // The BASE badge is hidden and the neutral canvas is acknowledged.
      expect(find.text('BASE'), findsNothing);
      expect(find.textContaining('lienzo'), findsOneWidget);

      // Each curated accent PAINTS as a visible, opaque swatch (same bug class
      // as the r3 harmony-swatch collapse).
      for (final List<int> rgb in kCanvasAccents) {
        final ui.Color accent = ui.Color.fromARGB(0xFF, rgb[0], rgb[1], rgb[2]);
        final Finder swatch = find.byWidgetPredicate((Widget w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == accent);
        expect(swatch, findsOneWidget, reason: 'accent $accent not painted');
        expect(tester.getSize(swatch).height, greaterThan(20));
        expect(tester.getSize(swatch).width, greaterThan(20));
      }
    });
  });
}
