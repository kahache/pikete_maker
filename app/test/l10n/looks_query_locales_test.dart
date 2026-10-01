import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/features/result/looks_search.dart';
import 'package:piketemaker/features/sneaker/color_names.dart';
import 'package:piketemaker/widgets/result_blocks.dart';

/// Per-locale #82 query builder + color vocabulary + short date (i18n round).
///
/// The es cases are covered exhaustively by the pre-i18n suite
/// (looks_search_test.dart, unchanged — the byte-identity net); this file
/// asserts the LOCALIZED behavior: each locale searches with ITS color words
/// and ITS query pattern (Latin: lead noun + listed tail; CJK: space-joined
/// colors with the coordination noun LAST — natural search ordering, not a
/// calque).

// The spec's own teal example (#2E9E86, h≈167°) + saturated red.
const Color _red = Color(0xFFD62828);
const Color _teal = Color(0xFF2E9E86);
const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);

void main() {
  group('query pattern per locale (red + teal)', () {
    const List<Color> colors = <Color>[_red, _teal];

    test('es (default = canonical, byte-identical to pre-i18n)', () {
      expect(looksSearchQuery(colors), 'outfit rojo y verde azulado');
      expect(looksSearchQuery(colors, language: 'es'),
          'outfit rojo y verde azulado');
    });

    test('en', () {
      expect(looksSearchQuery(colors, language: 'en'), 'outfit red and teal');
    });

    test('ca', () {
      expect(looksSearchQuery(colors, language: 'ca'),
          'outfit vermell i verd blavós');
    });

    test('fr (teal = the native fashion term "bleu canard")', () {
      expect(looksSearchQuery(colors, language: 'fr'),
          'outfit rouge et bleu canard');
    });

    test('zh — colors first, 穿搭 last, space-joined', () {
      expect(looksSearchQuery(colors, language: 'zh'), '红色 蓝绿色 穿搭');
    });

    test('ko — colors first, 코디 last', () {
      expect(looksSearchQuery(colors, language: 'ko'), '빨강 청록 코디');
    });

    test('ja — colors first, コーデ last', () {
      expect(looksSearchQuery(colors, language: 'ja'), '赤 青緑 コーデ');
    });

    test('country-qualified localeName resolves by language subtag', () {
      expect(
          looksSearchQuery(colors, language: 'en_US'), 'outfit red and teal');
      expect(looksSearchQuery(colors, language: 'zh_Hans_CN'), '红色 蓝绿色 穿搭');
    });

    test('unknown language falls back to canonical es', () {
      expect(looksSearchQuery(colors, language: 'de'),
          'outfit rojo y verde azulado');
    });
  });

  group('query shape rules hold in every locale', () {
    test('3-name list keeps the head-comma pattern in Latin locales', () {
      expect(
        looksSearchQueryFromNames(const <String>['black', 'white', 'red'],
            language: 'en'),
        'outfit black, white and red',
      );
      expect(
        looksSearchQueryFromNames(const <String>['negre', 'blanc', 'vermell'],
            language: 'ca'),
        'outfit negre, blanc i vermell',
      );
    });

    test('CJK: all names space-joined, no comma, lead last', () {
      expect(
        looksSearchQueryFromNames(const <String>['黑色', '白色', '红色'],
            language: 'zh'),
        '黑色 白色 红色 穿搭',
      );
    });

    test('dedup + cap + empty behave identically across locales', () {
      // A snapped black shoe on a black floor: one word, not "black and
      // black" — same rule as es.
      expect(looksSearchQuery(const <Color>[_black, _black], language: 'en'),
          'outfit black');
      // Cap at 3 names.
      expect(
        looksSearchQueryFromNames(const <String>['a', 'b', 'c', 'd'],
            language: 'ja'),
        'a b c コーデ',
      );
      // Empty list degrades to the bare lead in every pattern shape.
      expect(looksSearchQuery(const <Color>[], language: 'en'), 'outfit');
      expect(looksSearchQuery(const <Color>[], language: 'ja'), 'コーデ');
    });
  });

  group('color vocabulary (accuracy over flavor)', () {
    test('neutrals localize', () {
      expect(localizedColorName(_black, 'es'), 'negro');
      expect(localizedColorName(_black, 'en'), 'black');
      expect(localizedColorName(_black, 'ca'), 'negre');
      expect(localizedColorName(_black, 'fr'), 'noir');
      expect(localizedColorName(_black, 'zh'), '黑色');
      expect(localizedColorName(_black, 'ko'), '검정');
      expect(localizedColorName(_black, 'ja'), '黒');
      expect(localizedColorName(_white, 'en'), 'white');
    });

    test('crema term (the hero combo neutral) localizes via the same table',
        () {
      expect(colorTermName(ColorTerm.crema, 'es'), 'crema');
      expect(colorTermName(ColorTerm.crema, 'en'), 'cream');
      expect(colorTermName(ColorTerm.crema, 'fr'), 'crème');
      expect(colorTermName(ColorTerm.crema, 'ja'), 'クリーム');
    });

    test('spanishColorName stays the canonical shortcut (telemetry)', () {
      expect(spanishColorName(_teal), 'verde-azulado');
      expect(spanishColorName(_red), 'rojo');
    });
  });

  group('localizedShortDate', () {
    final DateTime date = DateTime(2026, 7, 14);

    test('es path IS shortSpanishDate (byte-identical)', () {
      expect(localizedShortDate(date, 'es'), shortSpanishDate(date));
      expect(localizedShortDate(date, 'es'), '14 jul 2026');
    });

    test('per-locale formats', () {
      expect(localizedShortDate(date, 'en'), 'Jul 14, 2026');
      expect(localizedShortDate(date, 'ca'), '14 jul 2026');
      expect(localizedShortDate(date, 'fr'), '14 juil 2026');
      expect(localizedShortDate(date, 'zh'), '2026年7月14日');
      expect(localizedShortDate(date, 'ja'), '2026年7月14日');
      expect(localizedShortDate(date, 'ko'), '2026년 7월 14일');
      // Unknown → canonical es.
      expect(localizedShortDate(date, 'pt'), '14 jul 2026');
    });
  });
}
