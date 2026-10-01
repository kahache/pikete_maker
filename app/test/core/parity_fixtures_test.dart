import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/harmony.dart';
import 'package:piketemaker/core/color_engine/palette.dart';

/// PYTHON PARITY: verifies the Dart port against the EXACT output of
/// `cv_core/colorlab` (the canonical reference of the algorithm, with tests).
///
/// The fixtures are generated with `cv_core/tools/gen_fixtures_dart.py`
/// (venv at the repo root) and contain the exact input pixels (numpy
/// float64) and Python's expected output. The tolerances are the SAME the
/// Python tests use (atol 10-15 in RGB, 0.02-0.05 in weights): Dart's
/// K-means converges to the same clusters, not bit for bit.
///
/// Fixture file names and JSON keys are FROZEN (generated from Python, in
/// another territory): do not rename them here.

const List<String> _paletteFixtures = <String>[
  'dos_colores_700_300',
  'residuales_980_20',
  'mostaza_solo_200',
  'fusion_rosa_500_500',
  'distintos_no_fusionan_600_400',
  'vuitton_pop_lavanda',
  'sombras_lavanda_reunificadas',
  'sin_fusion_kmeans_directo',
  'lienzo_neutro_D10',
];

Map<String, dynamic> _load(String name) {
  // `flutter test` runs with cwd = package root (app/).
  final File file = File('test/core/fixtures/$name');
  if (!file.existsSync()) {
    fail('$name does not exist. Regenerate with: '
        '.venv/bin/python cv_core/tools/gen_fixtures_dart.py '
        '(from the repo root).');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Float64List _flattenPixels(List<dynamic> pixels) {
  final Float64List out = Float64List(pixels.length * 3);
  for (int i = 0; i < pixels.length; i++) {
    final List<dynamic> px = pixels[i] as List<dynamic>;
    for (int d = 0; d < 3; d++) {
      out[i * 3 + d] = (px[d] as num).toDouble();
    }
  }
  return out;
}

List<int> _rgb(dynamic value) =>
    <int>[for (final dynamic c in value as List<dynamic>) (c as num).toInt()];

void main() {
  group('dominantColors parity with colorlab', () {
    for (final String name in _paletteFixtures) {
      test(name, () {
        final Map<String, dynamic> f = _load('$name.json');
        final Map<String, dynamic> expected =
            f['esperado'] as Map<String, dynamic>;
        final double atolRgb = (f['atol_rgb'] as num).toDouble();
        final double atolWeight = (f['atol_peso'] as num).toDouble();

        final DominantPalette res = dominantColors(
          _flattenPixels(f['pixeles'] as List<dynamic>),
          k: f['k'] as int,
          minWeight: (f['min_weight'] as num).toDouble(),
          mergeDeltaE: (f['merge_delta_e'] as num).toDouble(),
        );

        // STRUCTURAL parity: same number of colors as Python.
        final List<dynamic> expectedColors =
            expected['colores'] as List<dynamic>;
        final List<dynamic> expectedWeights =
            expected['pesos'] as List<dynamic>;
        expect(res.colors.length, expectedColors.length,
            reason: 'color count differs from Python: ${res.colors}');

        for (int i = 0; i < expectedColors.length; i++) {
          final List<int> expectedRgb = _rgb(expectedColors[i]);
          for (int d = 0; d < 3; d++) {
            expect(res.colors[i][d], closeTo(expectedRgb[d], atolRgb),
                reason: 'color $i: ${res.colors[i]} vs $expectedRgb');
          }
          expect(
            res.weights[i],
            closeTo((expectedWeights[i] as num).toDouble(), atolWeight),
            reason: 'weight $i',
          );
        }

        // Parity of the D5 base (index chosen by saturation * weight).
        final int baseIndex = pickHarmonyBase(res.colors, res.weights);
        expect(baseIndex, expected['indice_base'] as int);
        if (baseIndex >= 0) {
          final List<int> expectedBase = _rgb(expected['base']);
          for (int d = 0; d < 3; d++) {
            expect(res.colors[baseIndex][d], closeTo(expectedBase[d], atolRgb));
          }
        } else {
          // Canvas mode (D10): the curated accent set must match the Python
          // reference byte-for-byte (it is a hardcoded const on both sides).
          final List<dynamic> expectedAccents =
              expected['acentos_lienzo'] as List<dynamic>;
          expect(kCanvasAccents.length, expectedAccents.length);
          for (int i = 0; i < expectedAccents.length; i++) {
            expect(kCanvasAccents[i], _rgb(expectedAccents[i]),
                reason: 'canvas accent $i');
          }
        }

        // Harmony parity FROM PYTHON'S EXACT BASE: decouples the K-means
        // tolerance from the HSV arithmetic, which must match channel by
        // channel (+-1 due to int() truncation). Canvas mode (D10) emits no
        // harmonies (armonias == {}); the accents were checked above.
        final Map<String, dynamic> expectedHarmonies =
            expected['armonias'] as Map<String, dynamic>;
        if (expectedHarmonies.isEmpty) {
          return;
        }
        final Map<String, List<List<int>>> dartHarmonies =
            harmonies(_rgb(expected['base']));
        expect(dartHarmonies.keys.toSet(), expectedHarmonies.keys.toSet());
        expectedHarmonies.forEach((String scheme, dynamic colors) {
          final List<dynamic> list = colors as List<dynamic>;
          expect(dartHarmonies[scheme], hasLength(list.length));
          for (int i = 0; i < list.length; i++) {
            final List<int> expectedRgb = _rgb(list[i]);
            for (int d = 0; d < 3; d++) {
              expect(dartHarmonies[scheme]![i][d], closeTo(expectedRgb[d], 1),
                  reason: '$scheme[$i]: ${dartHarmonies[scheme]![i]} '
                      'vs $expectedRgb');
            }
          }
        });
      });
    }
  });

  group('harmony module parity with colorlab', () {
    test('armonias_casos.json: hsv, hex, neutrality and 4 schemes', () {
      final Map<String, dynamic> f = _load('armonias_casos.json');
      for (final dynamic caseDyn in f['casos'] as List<dynamic>) {
        final Map<String, dynamic> caseMap = caseDyn as Map<String, dynamic>;
        final String name = caseMap['nombre'] as String;
        final List<int> base = _rgb(caseMap['base']);

        // RGB -> HSV conversion: same IEEE arithmetic, minimal tolerance.
        final (double h, double s, double v) = rgbToHsv(base);
        final List<dynamic> expectedHsv = caseMap['hsv'] as List<dynamic>;
        expect(h, closeTo((expectedHsv[0] as num).toDouble(), 1e-9),
            reason: '$name h');
        expect(s, closeTo((expectedHsv[1] as num).toDouble(), 1e-9),
            reason: '$name s');
        expect(v, closeTo((expectedHsv[2] as num).toDouble(), 1e-9),
            reason: '$name v');

        expect(hexstr(base), caseMap['hex'], reason: name);
        expect(isNeutral(base), caseMap['es_neutro'], reason: name);

        final Map<String, dynamic> expectedHarmonies =
            caseMap['armonias'] as Map<String, dynamic>;
        final Map<String, List<List<int>>> dartHarmonies = harmonies(base);
        expectedHarmonies.forEach((String scheme, dynamic colors) {
          final List<dynamic> list = colors as List<dynamic>;
          for (int i = 0; i < list.length; i++) {
            final List<int> expectedRgb = _rgb(list[i]);
            for (int d = 0; d < 3; d++) {
              expect(dartHarmonies[scheme]![i][d], closeTo(expectedRgb[d], 1),
                  reason: '$name / $scheme[$i]');
            }
          }
        });
      }
    });
  });
}
