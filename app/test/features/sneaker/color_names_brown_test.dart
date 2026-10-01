import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/result/looks_search.dart';
import 'package:piketemaker/features/sneaker/color_names.dart';

/// BACKLOG E7 (CEO GO, 2026-10-01): a brown term. Before it, every warm hue
/// (15–70°) was "naranja" or "amarillo", so the r18 recolor kicker read
/// "ARRIBA · NARANJA" for a khaki partner (#8C7453). Rule: in the warm
/// buckets, DARK (HSV v < 0.6) or MUTED + MID-DARK (LAB chroma < 30 and
/// L* < 60) → marrón. Light / saturated warm colours and the neutrals are
/// unchanged.

String es(int argb) => spanishColorName(Color(argb));

void main() {
  group('the brown carve-out', () {
    test('the r18 khaki partner is marrón, not naranja', () {
      expect(es(0xFF8C7453), 'marrón');
      expect(colorTermOf(const Color(0xFF8C7453)), ColorTerm.marron);
    });

    test('dark / muted warm colours → marrón', () {
      expect(es(0xFF6F4E37), 'marrón', reason: 'coffee');
      expect(es(0xFF8B6B1A), 'marrón', reason: 'dark mustard');
      expect(es(0xFF7B5B3A), 'marrón', reason: 'tobacco');
    });

    test('light / saturated warm colours keep their pre-E7 names', () {
      expect(es(0xFFE8742A), 'naranja', reason: 'clear orange');
      expect(es(0xFFC4562B), 'naranja', reason: 'rust (saturated, v 0.77)');
      expect(es(0xFFD9A21E), 'naranja', reason: 'light mustard (h≈42°)');
      expect(es(0xFFF0C419), 'amarillo', reason: 'yellow');
      expect(es(0xFFA0522D), 'naranja',
          reason: 'sienna: saturated and v 0.63 (a warm orange-brown edge)');
      expect(es(0xFFC3B091), 'naranja',
          reason: 'light khaki: L* above 60, v above 0.6 (unchanged)');
    });

    test('hues outside 15–70° and the neutrals are untouched', () {
      expect(es(0xFF6B2E1F), 'rojo', reason: 'hue < 15°');
      expect(es(0xFF6B7A2B), 'verde', reason: 'olive, hue > 70°');
      expect(es(0xFF2B6CC4), 'azul');
      expect(es(0xFFC8BFAE), 'crema');
      expect(es(0xFFEDE9E1), 'blanco');
      expect(es(0xFF23211F), 'negro');
      expect(es(0xFF808080), 'gris');
    });
  });

  test('marrón localizes in all 7 locales', () {
    expect(<String>[
      for (final String l in <String>['es', 'en', 'ca', 'fr', 'zh', 'ko', 'ja'])
        colorTermName(ColorTerm.marron, l),
    ], <String>[
      'marrón',
      'brown',
      'marró',
      'marron',
      '棕色',
      '갈색',
      'ブラウン'
    ]);
    expect(localizedColorName(const Color(0xFF8C7453), 'en'), 'brown');
  });

  test('every term has a word in every locale (the vocabulary is total)', () {
    for (final String l in <String>['es', 'en', 'ca', 'fr', 'zh', 'ko', 'ja']) {
      for (final ColorTerm t in ColorTerm.values) {
        expect(colorTermName(t, l), isNotEmpty, reason: '$t in $l');
      }
    }
  });

  test('"Ver looks así" builds a sensible query with the new word', () {
    final String q = looksSearchQuery(
        const <Color>[Color(0xFF8C7453), Color(0xFF2B6CC4)],
        language: 'es');
    expect(q, contains('marrón'));
    expect(q, contains('azul'));
    expect(q, isNot(contains('naranja')));
  });
}
