import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/harmony.dart';

/// 1:1 mirror of cv_core/tests/test_harmony.py: same cases, same tolerances.
/// If a test changes there, it must change here (and vice versa).

const List<int> fuchsia = <int>[225, 54, 131];
const List<int> navy = <int>[30, 50, 110];
const List<int> gray = <int>[128, 128, 128];
const List<int> beige = <int>[210, 205, 195];

void main() {
  test('rgb -> hsv -> rgb roundtrip (abs 1: hsv_to_rgb truncates like Python)',
      () {
    final (double h, double s, double v) = rgbToHsv(fuchsia);
    final List<int> roundtrip = hsvToRgb(h, s, v);
    for (int d = 0; d < 3; d++) {
      expect(roundtrip[d], closeTo(fuchsia[d], 1));
    }
  });

  test('hexstr', () {
    expect(hexstr(<int>[225, 54, 131]), '#E13683');
    expect(hexstr(<int>[0, 0, 0]), '#000000');
  });

  test('isNeutral detects grays and beiges', () {
    expect(isNeutral(gray), isTrue);
    expect(isNeutral(beige), isTrue);
    expect(isNeutral(<int>[255, 255, 255]), isTrue);
  });

  test('isNeutral rejects vivid colors', () {
    expect(isNeutral(fuchsia), isFalse);
    expect(isNeutral(navy), isFalse);
  });

  // #22: chroma-based neutrality is stable on near-blacks (bugs B5/B8).
  const List<int> nearBlack = <int>[3, 2, 3]; // B8: sat unstable, chroma ~0
  const List<int> darkBlueGray = <int>[58, 57, 70]; // B5: #3A3946
  const List<int> darkMaroon = <int>[96, 18, 34]; // dark but chromatic
  const List<int> beigeWall = <int>[200, 180, 150]; // muted wall, chromatic

  test('isNeutral catches near-black and dark neutral (B5/B8)', () {
    expect(isNeutral(nearBlack), isTrue);
    expect(isNeutral(darkBlueGray), isTrue);
  });

  test('isNeutral keeps dark-but-chromatic colors', () {
    expect(isNeutral(darkMaroon), isFalse);
    expect(isNeutral(beigeWall), isFalse);
  });

  test('a near-black does not steal the base from a real garment (B8)', () {
    final List<List<int>> colors = <List<int>>[
      nearBlack,
      <int>[238, 43, 56], // saturated red cardigan
      gray,
    ];
    final List<double> weights = <double>[0.70, 0.25, 0.05];
    expect(pickHarmonyBase(colors, weights), 1);
  });

  // #57: dominant-neutral context gate (reflection attribution).
  test('tiny chromatic on a neutral outfit -> canvas mode (-1)', () {
    // selfie22 repro: 3% blue reflection on an all-black outfit is demoted.
    final List<List<int>> colors = <List<int>>[
      <int>[18, 18, 20], // black outfit (dominant, neutral)
      gray,
      <int>[180, 178, 175], // neutral wall
      <int>[45, 90, 205], // blue reflection, 3%
    ];
    final List<double> weights = <double>[0.70, 0.17, 0.10, 0.03];
    expect(pickHarmonyBase(colors, weights), -1);
  });

  test('substantial accent on a neutral outfit still leads', () {
    final List<List<int>> colors = <List<int>>[
      <int>[18, 18, 20],
      gray,
      <int>[200, 40, 45], // real 20% red accent
    ];
    final List<double> weights = <double>[0.62, 0.18, 0.20];
    expect(pickHarmonyBase(colors, weights), 2);
  });

  test('gate inert when the dominant color is chromatic (Vuitton guard)', () {
    final List<List<int>> colors = <List<int>>[
      fuchsia, // chromatic dominant
      <int>[156, 166, 198], // lavender pop, 5%
    ];
    final List<double> weights = <double>[0.95, 0.05];
    expect(pickHarmonyBase(colors, weights), 0);
  });

  test('pickHarmonyBase skips the dominant neutral', () {
    // The neutral (background) is the most frequent, but the base must be
    // the chromatic color.
    final int index = pickHarmonyBase(
      <List<int>>[beige, navy],
      <double>[0.7, 0.3],
    );
    expect(index, 1); // navy
  });

  test('pickHarmonyBase weighs saturation and frequency', () {
    // Between two chromatic colors, the highest saturation*weight wins.
    final List<int> washed = hsvToRgb(0.6, 0.25, 0.8); // washed blue, frequent
    final List<int> vivid = hsvToRgb(0.9, 0.95, 0.85); // vivid fuchsia, less
    final int index = pickHarmonyBase(
      <List<int>>[washed, vivid],
      <double>[0.55, 0.45],
    );
    expect(index, 1); // the vivid one
  });

  test(
      'pickHarmonyBase returns -1 when everything is neutral (canvas mode D10)',
      () {
    // Documented deviation from Python (which falls back to the dominant):
    // the AnalysisResult contract uses -1 and the ENGINE applies the
    // fallback to palette[0] for the harmonies (see color_engine_dart_test).
    final int index = pickHarmonyBase(
      <List<int>>[beige, gray],
      <double>[0.6, 0.4],
    );
    expect(index, -1);
  });

  test('harmonies structure', () {
    final Map<String, List<List<int>>> schemes = harmonies(fuchsia);
    expect(
      schemes.keys.toSet(),
      <String>{
        'Complementario',
        'Análogo',
        'Triádico',
        'Complementario dividido',
      },
    );
    expect(schemes['Complementario'], hasLength(2));
    expect(schemes['Análogo'], hasLength(3));
    expect(schemes['Triádico'], hasLength(3));
    for (final List<List<int>> colors in schemes.values) {
      // the base color appears in every scheme
      expect(colors, contains(fuchsia));
      // every proposed color is valid RGB
      for (final List<int> rgb in colors) {
        for (final int c in rgb) {
          expect(c, inInclusiveRange(0, 255));
        }
      }
    }
  });

  test('the complementary is the opposite hue', () {
    final (double baseH, _, _) = rgbToHsv(fuchsia);
    final List<int> comp = harmonies(fuchsia)['Complementario']![1];
    final (double compH, _, _) = rgbToHsv(comp);
    final double delta = ((compH - baseH) % 1.0).abs();
    expect(delta, closeTo(0.5, 0.02));
  });
}
