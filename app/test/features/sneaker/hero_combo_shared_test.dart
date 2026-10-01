import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/widgets/outfit_hero_combo_spec.dart';
import 'package:piketemaker/features/sneaker/widgets/combo_caption.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo_band.dart';
import 'package:piketemaker/features/sneaker/widgets/sneaker_hero_combo_spec.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// A6 / review F18: the sneaker (D27) and outfit (D36) hero widgets are ONE
/// parameterized [HeroComboBand] / [ComboCaption] / [HeroCombo]. These pins
/// freeze each flow's constants so the de-dup stays a pure refactor: band
/// height, segment flex ratios, role labels and caption shape per flow.

const Color _base = Color(0xFFC4562B);
const Color _complement = Color(0xFF2B6CC4);

const AnalysisResult _chromatic = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[ColorSample(color: _base, weight: 1.0)],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[_base, _complement],
    ),
  ],
);

/// Band laid out at a fixed width, wide enough that every role tag fits its
/// flex share: since N3 (2026-09-29) a segment narrower than its tag grows to
/// the tag's width, so the pure flex ratios only hold when nothing is tight
/// (the narrow-width behavior is pinned in hero_combo_band_n3_test.dart).
const double _bandWidth = 740;

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _bandWidth, child: child),
      ),
    ),
  ));
}

/// Widths of the three colored segments, left to right.
List<double> _segmentWidths(WidgetTester tester, HeroCombo combo) {
  return <Color>[combo.base, combo.complement, combo.neutral].map((Color c) {
    final Finder seg = find.byWidgetPredicate(
        (Widget w) => w is Container && w.color == c && w.child != null);
    return tester.getSize(seg).width;
  }).toList();
}

void main() {
  final HeroCombo combo = HeroCombo.of(_chromatic, 'es');

  testWidgets('sneaker band: 150 tall, flex 115/155/90, D27 role labels',
      (WidgetTester tester) async {
    await _pump(tester, HeroComboBand(combo: combo, spec: sneakerHeroBandSpec));
    final Size band = tester.getSize(find.byKey(sneakerHeroBandSpec.bandKey));
    expect(band.height, 150);
    final List<double> w = _segmentWidths(tester, combo);
    // Inside the 1 px hairline ring: 738 px split 115:155:90.
    expect(w[0] / w[2], closeTo(115 / 90, 0.01));
    expect(w[1] / w[2], closeTo(155 / 90, 0.01));
    expect(find.text(esL10n.sneakerTagZapas.toUpperCase()), findsOneWidget);
    expect(find.text(esL10n.sneakerTagRopa.toUpperCase()), findsOneWidget);
  });

  testWidgets('outfit band: 154 tall, flex 130/150/90, D36 role labels',
      (WidgetTester tester) async {
    await _pump(tester, HeroComboBand(combo: combo, spec: outfitHeroBandSpec));
    final Size band = tester.getSize(find.byKey(outfitHeroBandSpec.bandKey));
    expect(band.height, 154);
    final List<double> w = _segmentWidths(tester, combo);
    expect(w[0] / w[2], closeTo(130 / 90, 0.01));
    expect(w[1] / w[2], closeTo(150 / 90, 0.01));
    expect(find.text(esL10n.resultTagFit.toUpperCase()), findsOneWidget);
    expect(find.text(esL10n.resultTagAdd.toUpperCase()), findsOneWidget);
  });

  testWidgets(
      'canvas caption: sneaker = lead + rest (rich), outfit = the single '
      'canvasBody line', (WidgetTester tester) async {
    await _pump(
        tester, const ComboCaption(combo: null, copy: sneakerCaptionCopy));
    expect(
      find.text(esL10n.sneakerCanvasCaptionLead + esL10n.sneakerCanvasCaptionRest),
      findsOneWidget,
    );

    await _pump(
        tester, const ComboCaption(combo: null, copy: outfitCaptionCopy));
    final Text line = tester.widget<Text>(find.text(esL10n.canvasBody));
    expect(line.data, esL10n.canvasBody, reason: 'plain Text, not Text.rich');
  });

  testWidgets('chromatic caption: each flow uses its own ARB lead/rest',
      (WidgetTester tester) async {
    await _pump(tester, ComboCaption(combo: combo, copy: sneakerCaptionCopy));
    expect(
      find.text(
          esL10n.sneakerCaptionLead(combo.complementName, combo.baseName) +
              esL10n.sneakerCaptionRest(
                  combo.neutralName, combo.otherNeutralName)),
      findsOneWidget,
    );

    await _pump(tester, ComboCaption(combo: combo, copy: outfitCaptionCopy));
    expect(
      find.text(esL10n.resultCaptionLead(combo.complementName, combo.baseName) +
          esL10n.resultCaptionRest(combo.neutralName, combo.otherNeutralName)),
      findsOneWidget,
    );
  });

  test('outfit combo keeps the RAW engine colors (snap is product-mode only)',
      () {
    final HeroCombo raw =
        HeroCombo.of(_chromatic, 'es', snapForDisplay: false);
    expect(raw.base, _base);
    expect(raw.complement, _complement);
    expect(raw.neutral, HeroCombo.kCrema, reason: 'dark/mid combo → crema');
  });
}
