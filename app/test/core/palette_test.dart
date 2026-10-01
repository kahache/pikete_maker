import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/palette.dart';

/// 1:1 mirror of cv_core/tests/test_palette.py: same cases and tolerances.
///
/// The pixel clouds are generated with Dart's RNG (not numpy): same Gaussian
/// distribution and fixed seed, different sequence. Assertions go against
/// the NOMINAL colors with tolerance, just like in Python, so the concrete
/// sequence does not matter. The parity against colorlab's EXACT output
/// lives in parity_fixtures_test.dart.

const List<double> navy = <double>[30.0, 50.0, 110.0];
const List<double> mustard = <double>[200.0, 150.0, 40.0];

// Conceptual Vuitton case (issue #5): a fuchsia garment that K-means splits
// into variants because of lighting, plus a minority-but-distinctive color
// (the outfit's "pop") that must survive the merge.
const List<double> pink = <double>[225.0, 54.0, 131.0];
const List<double> pinkLight = <double>[243.0, 84.0, 156.0]; // dE76 ~ 8.7
const List<double> pinkDark = <double>[196.0, 36.0, 106.0]; // dE76 ~ 9.7
const List<double> lavender = <double>[156.0, 166.0, 198.0]; // dE76 > 64

/// Standard Gaussian via Box-Muller (dart:math has no normal distribution).
double _gauss(math.Random rng) {
  double u1 = rng.nextDouble();
  while (u1 == 0.0) {
    u1 = rng.nextDouble();
  }
  final double u2 = rng.nextDouble();
  return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
}

/// Cloud of n pixels around a color with Gaussian jitter (mirror of the
/// _pixels helper in test_palette.py, fixed seed per cloud).
Float64List _pixels(List<double> color, int n,
    {double jitter = 3.0, int seed = 0}) {
  final math.Random rng = math.Random(seed);
  final Float64List out = Float64List(n * 3);
  for (int i = 0; i < n * 3; i++) {
    out[i] = (color[i % 3] + _gauss(rng) * jitter).clamp(0.0, 255.0);
  }
  return out;
}

Float64List _vstack(List<Float64List> clouds) {
  final int total = clouds.fold(0, (int acc, Float64List c) => acc + c.length);
  final Float64List out = Float64List(total);
  int offset = 0;
  for (final Float64List cloud in clouds) {
    out.setAll(offset, cloud);
    offset += cloud.length;
  }
  return out;
}

void _expectAllClose(List<int> actual, List<double> expected, double atol) {
  for (int d = 0; d < 3; d++) {
    expect(actual[d], closeTo(expected[d], atol),
        reason: 'channel $d of $actual vs $expected');
  }
}

double _sum(List<double> xs) => xs.fold(0.0, (double a, double b) => a + b);

void main() {
  test('recovers two colors in frequency order', () {
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(navy, 700), _pixels(mustard, 300)]);
    final DominantPalette res = dominantColors(pixels, k: 2);

    expect(res.colors, hasLength(2));
    // the most frequent one first
    _expectAllClose(res.colors[0], navy, 10);
    _expectAllClose(res.colors[1], mustard, 10);
    expect(res.weights[0], greaterThan(res.weights[1]));
    expect(_sum(res.weights), closeTo(1.0, 1e-9));
  });

  test('weights follow the pixel proportions', () {
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(navy, 700), _pixels(mustard, 300)]);
    final DominantPalette res = dominantColors(pixels, k: 2);
    expect(res.weights[0], closeTo(0.7, 0.05));
    expect(res.weights[1], closeTo(0.3, 0.05));
  });

  test('residual clusters are discarded', () {
    // With k=5 over data of only 2 colors, near-empty or duplicated clusters
    // with weight < minWeight must not appear in the result.
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(navy, 980), _pixels(mustard, 20)]);
    final DominantPalette res = dominantColors(pixels, k: 5, minWeight: 0.05);
    for (final double w in res.weights) {
      expect(w, greaterThanOrEqualTo(0.05));
    }
    expect(res.colors.length, res.weights.length);
  });

  test('colors are valid integer RGB', () {
    final Float64List pixels = _pixels(mustard, 200);
    final DominantPalette res = dominantColors(pixels, k: 1);
    for (final List<int> c in res.colors) {
      for (final int channel in c) {
        expect(channel, inInclusiveRange(0, 255));
      }
    }
  });

  // --- Merge of perceptually close clusters in LAB (issue #5) ---

  test('srgbToLab: reference values', () {
    // Reference white and black: L 100/0 with a, b ~ 0 (D65).
    final List<double> white = srgbToLab(<double>[255.0, 255.0, 255.0]);
    final List<double> black = srgbToLab(<double>[0.0, 0.0, 0.0]);
    expect(white[0], closeTo(100.0, 0.5));
    expect(white[1], closeTo(0.0, 0.5));
    expect(white[2], closeTo(0.0, 0.5));
    for (final double c in black) {
      expect(c, closeTo(0.0, 0.5));
    }
  });

  test('light variants of the same hue merge into one color', () {
    // Two clouds of the same hue with slightly different lightness must
    // merge into a single palette color.
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(pink, 500), _pixels(pinkLight, 500)]);
    final DominantPalette res = dominantColors(pixels, k: 5);

    expect(res.colors, hasLength(1));
    // the merged color lies between both variants (weighted mean)
    final List<double> expected = <double>[
      for (int d = 0; d < 3; d++) (pink[d] + pinkLight[d]) / 2,
    ];
    _expectAllClose(res.colors[0], expected, 12);
    expect(res.weights[0], closeTo(1.0, 1e-9));
  });

  test('clearly distinct colors do NOT merge', () {
    // navy vs mustard: dE76 ~ 107.
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(navy, 600), _pixels(mustard, 400)]);
    final DominantPalette res = dominantColors(pixels, k: 5);

    expect(res.colors, hasLength(2));
    _expectAllClose(res.colors[0], navy, 10);
    _expectAllClose(res.colors[1], mustard, 10);
  });

  test('Vuitton case: the pink collapses and the minority pop survives', () {
    // Pink majority in 3 lighting variants + lavender minority (the pop).
    // After the merge: the pink collapses into 1 color, the lavender
    // survives and RISES in relative weight (from 5th among 4 pinks to 2nd
    // of 2 colors).
    final Float64List pixels = _vstack(<Float64List>[
      _pixels(pink, 400),
      _pixels(pinkLight, 330),
      _pixels(pinkDark, 220),
      _pixels(lavender, 50),
    ]);
    final DominantPalette res = dominantColors(pixels, k: 5);

    expect(res.colors, hasLength(2));
    // the collapsed pink dominates and is pink (near the pinks' weighted mean)
    final List<double> expectedPink = <double>[
      for (int d = 0; d < 3; d++)
        (pink[d] * 400 + pinkLight[d] * 330 + pinkDark[d] * 220) / 950,
    ];
    _expectAllClose(res.colors[0], expectedPink, 15);
    expect(res.weights[0], closeTo(0.95, 0.02));
    // the lavender survives as second color with its full weight
    _expectAllClose(res.colors[1], lavender, 10);
    expect(res.weights[1], closeTo(0.05, 0.02));
  });

  test('shadow fragments of the minority color reunite', () {
    // Regression of the real bug in the Vuitton photo: over-clustering split
    // the lavender sneakers into a light half / shadow half (~1.7% each,
    // dE76 ~ 24.9 due to the L difference) and both died separately under
    // minWeight. With the attenuated L they must reunite and survive.
    const List<double> lavShadow = <double>[0x7A, 0x7F, 0x9A];
    const List<double> lavLight = <double>[0xB5, 0xC1, 0xE3];
    final Float64List pixels = _vstack(<Float64List>[
      _pixels(pink, 966),
      _pixels(lavShadow, 17),
      _pixels(lavLight, 17),
    ]);
    final DominantPalette res = dominantColors(pixels, k: 5, minWeight: 0.02);

    expect(res.colors, hasLength(2));
    final List<double> expectedLavender = <double>[
      for (int d = 0; d < 3; d++) (lavShadow[d] + lavLight[d]) / 2,
    ];
    _expectAllClose(res.colors[1], expectedLavender, 12);
    // survives the residual filter
    expect(res.weights[1], greaterThanOrEqualTo(0.02));
  });

  test('the merge can be disabled (plain K-means)', () {
    // mergeDeltaE <= 0 disables the merge: plain K-means with k clusters,
    // the two pink variants stay separate.
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(pink, 500), _pixels(pinkLight, 500)]);
    final DominantPalette res = dominantColors(pixels, k: 2, mergeDeltaE: 0);
    expect(res.colors, hasLength(2));
  });

  test('determinism: the same input produces the same palette', () {
    // Fixed seed (kKmeansSeed): reproducible demo, no flakiness.
    final Float64List pixels =
        _vstack(<Float64List>[_pixels(navy, 700), _pixels(mustard, 300)]);
    final DominantPalette a = dominantColors(pixels, k: 5);
    final DominantPalette b = dominantColors(pixels, k: 5);
    expect(a.colors, b.colors);
    expect(a.weights, b.weights);
  });

  // --- Neutral-lightness merge protection (issue #84 round 2, the white bug).
  // 1:1 mirror of the protection tests in cv_core/tests/test_palette.py.

  group('protectNeutralLightness (#84, product mode)', () {
    const List<double> nearWhite = <double>[245.0, 245.0, 245.0]; // L* ~ 96
    const List<double> midGray = <double>[150.0, 150.0, 150.0]; // L* ~ 62
    const List<double> nearBlack = <double>[20.0, 20.0, 20.0]; // L* ~ 7

    /// A white minority over a gray majority + some black — the shape where a
    /// small near-white sole risks being pulled into the larger mid-gray.
    Float64List whiteGrayBlackPixels() => _vstack(<Float64List>[
          _pixels(nearWhite, 250),
          _pixels(midGray, 500),
          _pixels(nearBlack, 250),
        ]);

    List<double> lightnessOf(DominantPalette res) => <double>[
          for (final List<int> c in res.colors)
            srgbToLab(<double>[
              c[0].toDouble(),
              c[1].toDouble(),
              c[2].toDouble(),
            ])[0],
        ];

    test('baseline: neutrals collapse toward gray WITHOUT protection', () {
      // Outfit behavior (default OFF): the near-white minority fuses with the
      // mid-gray majority, so no genuinely white swatch (L* > 85) survives —
      // this is the bug the protection targets.
      final DominantPalette res = dominantColors(whiteGrayBlackPixels(), k: 5);
      expect(lightnessOf(res).any((double l) => l > 85), isFalse,
          reason: 'unexpected white swatch without protection: ${res.colors}');
    });

    test('protection keeps white, gray and black as distinct swatches', () {
      final DominantPalette res = dominantColors(whiteGrayBlackPixels(),
          k: 5, protectNeutralLightness: true);
      final List<double> lightness = lightnessOf(res);
      expect(lightness.any((double l) => l > 90), isTrue,
          reason: 'white lost: ${res.colors}');
      expect(lightness.any((double l) => l < 20), isTrue,
          reason: 'black lost: ${res.colors}');
      expect(lightness.any((double l) => l > 40 && l < 80), isTrue,
          reason: 'mid-gray lost: ${res.colors}');
    });

    test('protection still merges two shades of one near-white', () {
      // Not 'never merge neutrals': a lit sole vs. its own faint shadow still
      // merges into one white — it only stops the white/gray collapse.
      final Float64List pixels = _vstack(<Float64List>[
        _pixels(<double>[250.0, 250.0, 250.0], 500),
        _pixels(<double>[232.0, 232.0, 232.0], 500),
      ]);
      final DominantPalette res =
          dominantColors(pixels, k: 5, protectNeutralLightness: true);
      final int whites = lightnessOf(res).where((double l) => l > 85).length;
      expect(whites, 1,
          reason: 'two near-white shades did not merge: ${res.colors}');
    });

    test('protection does not touch chromatic shading merges', () {
      // Only NEUTRAL-vs-neutral pairs are re-scored; a chromatic garment's
      // light/shadow halves still merge exactly as before.
      final Float64List pixels =
          _vstack(<Float64List>[_pixels(pink, 500), _pixels(pinkDark, 500)]);
      final DominantPalette plain = dominantColors(pixels, k: 5);
      final DominantPalette withProtection =
          dominantColors(pixels, k: 5, protectNeutralLightness: true);
      expect(plain.colors, hasLength(1));
      expect(withProtection.colors, hasLength(1));
      expect(withProtection.colors, plain.colors);
    });
  });
}
