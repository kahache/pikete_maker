import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// Display snap on the sneaker result (issue #85, D31-A): the palette strip
/// renders the SNAPPED colors (a diluted #3C3937 black shows as pure black, a
/// #D0CCC9 "white read as gray" as pure white) and the ES namer reads the
/// snapped color, so the BASE badge says "negro" for a shoe shown black. The
/// [AnalysisResult] itself stays raw — the snap is presentation-only.

/// The CEO's canonical diluted black (L* 24.2, C* 1.9 → snaps to #000000).
const Color _dilutedBlack = Color(0xFF3C3937);

/// "Blanco leído como gris" (L* 82.3, C* 2.2 → snaps to #FFFFFF).
const Color _grayishWhite = Color(0xFFD0CCC9);

/// A genuine mid gray (L* 48.4, C* 5.1): must stay EXACTLY itself.
const Color _midGray = Color(0xFF6C747B);

/// Black kicks on a gray floor: 100% neutral → canvas mode (baseIndex -1),
/// the badge names the DOMINANT neutral (palette[0] = the diluted black).
const AnalysisResult _dilutedBlackKicks = AnalysisResult(
  baseIndex: -1,
  palette: <ColorSample>[
    ColorSample(color: _dilutedBlack, weight: 0.6),
    ColorSample(color: _grayishWhite, weight: 0.25),
    ColorSample(color: _midGray, weight: 0.15),
  ],
  harmonies: <Harmony>[],
  canvasAccents: <Color>[
    Color(0xFFE4322B),
    Color(0xFF2B5CE4),
    Color(0xFFE0A000),
    Color(0xFF12A150),
    Color(0xFFD6248C),
  ],
);

Future<void> _pumpResult(WidgetTester tester, AnalysisResult result) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: SneakerResultScreen(
      args: SneakerResultArgs(result: result, photo: Uint8List(0)),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Colors of the ColoredBox swatches inside the demoted palette strip.
List<Color> _stripColors(WidgetTester tester) => <Color>[
      for (final ColoredBox box in tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byKey(SneakerResultScreen.paletteStripKey),
          matching: find.byType(ColoredBox),
        ),
      ))
        box.color,
    ];

void main() {
  testWidgets(
      'palette strip renders snapped neutrals; raw diluted values never show',
      (WidgetTester tester) async {
    await _pumpResult(tester, _dilutedBlackKicks);

    final List<Color> strip = _stripColors(tester);
    expect(strip, contains(const Color(0xFF000000)),
        reason: 'diluted black must SHOW as pure black');
    expect(strip, contains(const Color(0xFFFFFFFF)),
        reason: 'grayish white must SHOW as pure white');
    expect(strip, contains(_midGray),
        reason: 'a genuine mid gray stays exactly itself');
    expect(strip, isNot(contains(_dilutedBlack)),
        reason: 'the raw diluted hex must not be rendered');
    expect(strip, isNot(contains(_grayishWhite)),
        reason: 'the raw grayish hex must not be rendered');
  });

  testWidgets('the BASE badge names the SNAPPED color ("negro", not "gris")',
      (WidgetTester tester) async {
    await _pumpResult(tester, _dilutedBlackKicks);

    // Canvas mode: the badge names the dominant neutral, read AFTER the snap —
    // the CEO wants a shoe shown black to be CALLED black.
    expect(find.text('BASE · NEGRO'), findsOneWidget);
    expect(find.text('BASE · GRIS'), findsNothing);
  });

  testWidgets('the analysis result itself stays raw (display-only snap)',
      (WidgetTester tester) async {
    await _pumpResult(tester, _dilutedBlackKicks);

    // The model still carries the raw extraction; only the render snapped.
    expect(_dilutedBlackKicks.palette[0].color, _dilutedBlack);
    expect(_dilutedBlackKicks.palette[1].color, _grayishWhite);
  });
}
