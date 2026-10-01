import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/widgets/outfit_hero_combo_spec.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo_band.dart';
import 'package:piketemaker/features/sneaker/widgets/sneaker_hero_combo_spec.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';

import '../story/story_test_helpers.dart';

/// N3 (2026-09-29, spec §7) — the "+ CREMA" wrap fix in the SHARED hero band
/// (outfit + sneaker, screen + story): tags never wrap, each segment is at
/// least as wide as its tag, and tags shrink (FittedBox) only as a last resort.
///
/// Measured with the REAL Roboto (the device font): the default test font's
/// 1-em glyphs are ~50% wider and would make every band look broken.

/// On-screen band = screen width − 90 (20+20 margin, 24+24 card padding, 2
/// border). Story bands = the photo width (unframed).
const List<double> _screenWidths = <double>[320, 360, 375, 390, 411, 432];
const List<double> _storyBands = <double>[236, 259, 283, 311, 392];
const double _screenInset = 90;

const List<String> _mainLocales = <String>['es', 'en', 'ca', 'fr'];
const List<String> _smokeLocales = <String>['zh', 'ko', 'ja'];

/// Chromatic results whose hero combo reads dark ("+ crema", the longest es
/// neutral tag) and light ("+ negro").
AnalysisResult _result(Color base, Color complement) => AnalysisResult(
      baseIndex: 0,
      palette: <ColorSample>[ColorSample(color: base, weight: 1.0)],
      harmonies: <Harmony>[
        Harmony(
          type: HarmonyType.complementary,
          name: 'Complementario',
          description: '',
          colors: <Color>[base, complement],
        ),
      ],
    );
final AnalysisResult _dark =
    _result(const Color(0xFFC4572A), const Color(0xFF2C6EC4));
final AnalysisResult _light =
    _result(const Color(0xFFF2D16B), const Color(0xFFB9D6F2));

/// Scale the FittedBox applied to a tag pill (1 = natural size).
double _pillScale(WidgetTester tester, Finder pill) =>
    tester.getRect(pill).width / tester.getSize(pill).width;

class _Case {
  _Case(this.locale, this.spec, this.bandWidth, this.textScale,
      {required this.framed, required this.dark});
  final String locale;
  final HeroComboBandSpec spec;
  final double bandWidth;
  final double textScale;
  final bool framed;
  final bool dark;

  String get label => '$locale · ${spec == outfitHeroBandSpec ? 'outfit' : 'sneaker'}'
      ' · ${framed ? 'screen' : 'story'} band ${bandWidth.toStringAsFixed(0)}'
      ' · ${textScale}x · ${dark ? 'crema' : 'negro'}';
}

Future<List<double>> _pumpBand(WidgetTester tester, _Case c) async {
  final HeroCombo combo = HeroCombo.of(c.dark ? _dark : _light, c.locale,
      snapForDisplay: false);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    locale: Locale(c.locale),
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: kSupportedLocales,
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(c.textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: c.bandWidth,
              child: HeroComboBand(
                combo: combo,
                spec: c.spec,
                height: c.framed ? null : 72,
                framed: c.framed,
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  final Finder pills = find.byType(ComboTagPill);
  expect(pills, findsNWidgets(3), reason: c.label);
  final List<double> scales = <double>[];
  for (int i = 0; i < 3; i++) {
    final Finder pill = pills.at(i);
    final Finder text =
        find.descendant(of: pill, matching: find.byType(Text));
    final double fontPx = 10 * c.textScale;
    // One line: the text box is a single line tall (never wrapped).
    expect(tester.getSize(text).height, lessThan(fontPx * 1.6),
        reason: '${c.label}: tag $i wrapped');
    // The (possibly scaled) pill fits inside its segment, with the padding.
    final Rect seg = tester.getRect(
        find.ancestor(of: pill, matching: find.byType(ComboSegment)).first);
    final Rect r = tester.getRect(pill);
    expect(r.left, greaterThanOrEqualTo(seg.left + 8 - 0.5),
        reason: '${c.label}: tag $i overflows left');
    expect(r.right, lessThanOrEqualTo(seg.right - 8 + 0.5),
        reason: '${c.label}: tag $i overflows its segment');
    scales.add(_pillScale(tester, pill));
  }
  expect(tester.takeException(), isNull, reason: c.label);
  return scales;
}

void main() {
  setUpAll(loadRealFonts);

  group('comboSegmentWidths (CSS min-width:auto resolution)', () {
    test('all minimums fit their flex shares → pure flex split', () {
      final List<double> w = comboSegmentWidths(
          total: 370, flexes: <int>[130, 150, 90], minWidths: <double>[50, 50, 50]);
      expect(w[0], closeTo(130, 1e-9));
      expect(w[1], closeTo(150, 1e-9));
      expect(w[2], closeTo(90, 1e-9));
    });

    test('a segment below its minimum is grown to it; the deficit comes from '
        'the others by flex', () {
      final List<double> w = comboSegmentWidths(
          total: 270, flexes: <int>[130, 150, 90], minWidths: <double>[60, 70, 79]);
      expect(w[2], 79);
      expect(w[0] / w[1], closeTo(130 / 150, 1e-9));
      expect(w.reduce((double a, double b) => a + b), closeTo(270, 1e-9));
    });

    test('cascading: taking the deficit can push another below its min', () {
      final List<double> w = comboSegmentWidths(
          total: 240, flexes: <int>[130, 150, 90], minWidths: <double>[80, 60, 79]);
      expect(w[0], 80);
      expect(w[2], 79);
      expect(w[1], closeTo(81, 1e-9));
    });

    test('last resort: minimums don\'t fit → proportional to the minimums', () {
      final List<double> w = comboSegmentWidths(
          total: 200, flexes: <int>[130, 150, 90], minWidths: <double>[100, 100, 50]);
      expect(w, <double>[80, 80, 40]);
    });
  });

  testWidgets(
      'outfit band, es/en/ca/fr at 1.0×: no tag wraps anywhere, no scaling on '
      'any band ≥ 259 (story 9:16 photo and every phone ≥ 360), never below '
      'the 0.8 floor', (WidgetTester tester) async {
    for (final String locale in _mainLocales) {
      for (final bool dark in <bool>[true, false]) {
        final List<_Case> cases = <_Case>[
          for (final double w in _screenWidths)
            _Case(locale, outfitHeroBandSpec, w - _screenInset, 1.0,
                framed: true, dark: dark),
          for (final double w in _storyBands)
            _Case(locale, outfitHeroBandSpec, w, 1.0, framed: false, dark: dark),
        ];
        for (final _Case c in cases) {
          final List<double> scales = await _pumpBand(tester, c);
          final double min = scales.reduce((double a, double b) => a < b ? a : b);
          if (c.bandWidth >= 259) {
            expect(min, closeTo(1, 1e-6), reason: '${c.label}: scaled $scales');
          } else {
            expect(min, greaterThanOrEqualTo(0.8),
                reason: '${c.label}: below the floor $scales');
          }
        }
      }
    }
  });

  testWidgets(
      'sneaker band, es/en/ca/fr at 1.0× (with the §4.3 short tags): no tag '
      'wraps; ≥ 0.8 on every band from 236 (story 5:8 at 377) to 411 dp; es '
      'needs no scaling from 360 dp (was: "TUS ZAPAS" wrapped at 360); no '
      'scaling at all on story bands ≥ 283', (WidgetTester tester) async {
    for (final String locale in _mainLocales) {
      for (final bool dark in <bool>[true, false]) {
        final List<_Case> cases = <_Case>[
          for (final double w in _screenWidths)
            _Case(locale, sneakerHeroBandSpec, w - _screenInset, 1.0,
                framed: true, dark: dark),
          for (final double w in _storyBands)
            _Case(locale, sneakerHeroBandSpec, w, 1.0,
                framed: false, dark: dark),
        ];
        for (final _Case c in cases) {
          final List<double> scales = await _pumpBand(tester, c);
          final double min =
              scales.reduce((double a, double b) => a < b ? a : b);
          if (c.bandWidth >= 236) {
            expect(min, greaterThanOrEqualTo(0.8),
                reason: '${c.label}: below the floor $scales');
          }
          if (!c.framed && c.bandWidth >= 283) {
            expect(min, closeTo(1, 1e-6), reason: '${c.label}: $scales');
          }
          if (locale == 'es' && c.framed && c.bandWidth >= 360 - _screenInset) {
            expect(min, closeTo(1, 1e-6), reason: '${c.label}: $scales');
          }
        }
      }
    }
  });

  test('§4.3 short sneaker tags (en/ca/fr); es unchanged', () {
    AppLocalizations l(String code) => lookupAppLocalizations(Locale(code));
    expect((l('es').sneakerTagZapas, l('es').sneakerTagRopa),
        ('tus zapas', 'tu ropa'));
    expect((l('en').sneakerTagZapas, l('en').sneakerTagRopa),
        ('your kicks', 'your fit'));
    expect((l('ca').sneakerTagZapas, l('ca').sneakerTagRopa),
        ('bambes', 'roba'));
    expect((l('fr').sneakerTagZapas, l('fr').sneakerTagRopa),
        ('baskets', 'fringues'));
  });

  testWidgets(
      'accessibility text scale 1.3× and the zh/ko/ja smoke: still ONE line, '
      'every pill inside its segment (outfit + sneaker, screen + story)',
      (WidgetTester tester) async {
    for (final String locale in <String>[..._mainLocales, ..._smokeLocales]) {
      for (final HeroComboBandSpec spec in <HeroComboBandSpec>[
        outfitHeroBandSpec,
        sneakerHeroBandSpec,
      ]) {
        final double scale = _smokeLocales.contains(locale) ? 1.0 : 1.3;
        for (final double w in _screenWidths) {
          await _pumpBand(
              tester,
              _Case(locale, spec, w - _screenInset, scale,
                  framed: true, dark: true));
        }
        for (final double w in _storyBands) {
          await _pumpBand(
              tester, _Case(locale, spec, w, 1.0, framed: false, dark: true));
        }
      }
    }
  });
}
