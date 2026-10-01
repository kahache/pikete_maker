import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/display.dart';
import 'package:piketemaker/core/color_engine/palette.dart' show kNeutralChroma;

/// PYTHON PARITY for the display-time neutral snap (issue #85, D31-A).
///
/// The fixture table below is a 1:1 MIRROR of `DART_PARITY_FIXTURES` in
/// `cv_core/tests/test_display.py` — the exact contract of
/// `colorlab.display.snap_neutral_for_display`. If a row changes there, it
/// must change HERE with it (deliberately, not by drift). Evidence hexes come
/// from the gate G2S phone battery and the CEO's photo-by-photo notes.

List<int> _rgb(String hex) {
  final String h = hex.replaceFirst('#', '');
  return <int>[
    int.parse(h.substring(0, 2), radix: 16),
    int.parse(h.substring(2, 4), radix: 16),
    int.parse(h.substring(4, 6), radix: 16),
  ];
}

String _hex(List<int> rgb) {
  final StringBuffer sb = StringBuffer('#');
  for (final int c in rgb) {
    sb.write(c.toRadixString(16).toUpperCase().padLeft(2, '0'));
  }
  return sb.toString();
}

/// (input hex, expected display hex, why) — mirror of test_display.py.
const List<(String, String, String)> kDartParityFixtures =
    <(String, String, String)>[
  ('#2E2928', '#000000', 'diluted black, CEO row 04 (L 17.1, C 2.6)'),
  ('#221A1A', '#000000', 'diluted black, CEO row 06 (L 10.2, C 4.2)'),
  ('#3C3937', '#000000', "the CEO's canonical example (L 24.2, C 1.9)"),
  ('#3D3B39', '#000000', 'lightest measured diluted black (L 25.0, C 1.6)'),
  ('#383737', '#000000', 'diluted black, row 32 (L 23.2, C 0.5)'),
  ('#1F1F27', '#000000', 'diluted black, row 14 (L 12.1, C 5.8)'),
  ('#000000', '#000000', 'pure black is idempotent'),
  ('#D0CCC9', '#FFFFFF', "'blanco leído como gris', row 29 (L 82.3, C 2.2)"),
  ('#CDDDD8', '#FFFFFF', 'white sole read as gray (L 86.8, C 6.3)'),
  ('#FFFFFB', '#FFFFFF', 'near-white, row 27 (L 99.9, C 2.0)'),
  ('#FFFFFF', '#FFFFFF', 'pure white is idempotent'),
  ('#051C56', '#051C56', 'real navy: chroma 41.2 >= gate, NEVER touched'),
  ('#304474', '#304474', 'real blue: chroma 31.0 >= gate, untouched'),
  ('#451316', '#451316', 'real dark maroon: chroma 26.6 >= gate, untouched'),
  ('#2E1F3A', '#2E1F3A', 'real dark purple: chroma 20.1 >= gate, untouched'),
  ('#6C747B', '#6C747B', 'genuine mid gray stays (L 48.4, C 5.1)'),
  ('#99A39D', '#99A39D', 'genuine gray stays (L 66.1, C 5.1)'),
  ('#AEAEB4', '#AEAEB4', 'genuine light gray stays (L 71.3, C 3.3)'),
  ('#C2C0C3', '#C2C0C3', 'lightest genuine gray stays (L 77.9 < 80)'),
  ('#52463E', '#52463E', 'dark flesh-suede, NOT black (L 30.7 > 28)'),
  ('#4B5F59', '#4B5F59', 'dark green-gray, NOT black (L 38.6 > 28)'),
  // Boundary rows (display.py: <= for black, >= for white, < for chroma).
  ('#424242', '#000000', 'boundary: L 27.97 <= 28.0 snaps'),
  ('#434343', '#434343', 'boundary: L 28.41 > 28.0 stays'),
  ('#C6C6C6', '#C6C6C6', 'boundary: L 79.88 < 80.0 stays'),
  ('#CACACA', '#FFFFFF', 'boundary: L 81.33 >= 80.0 snaps'),
  ('#232B3F', '#232B3F', 'boundary: chroma 14.05 >= 13.0, gate holds'),
  ('#222F39', '#000000', 'dark slate: chroma 8.5 < 13, L 18.7 -> black'),
  // --- B-G25-3: the soft band (L* 21-28 needs chroma < 4.0 to read black) ---
  // The three swatches the CEO rejected as black on the gate G2.5 set.
  ('#3C414D', '#3C414D', 'B-G25-3 blue fishnet: L 27.5, C 8.0 -> stays blue'),
  ('#303745', '#303745', 'B-G25-3 fishnet lower: L 23.0, C 9.7 -> stays'),
  ('#413934', '#413934', 'B-G25-3 olive/brown wool: L 24.6, C 5.1 -> stays'),
  // ...while the genuine dark neutrals in the SAME band still snap: this is
  // the #85-A/D31 behaviour the loosening must not resurrect.
  ('#39403F', '#000000', 'selfie15 trousers: L 26.4 but C 3.2 < 4 -> black'),
  // Below the hard floor the original rule is verbatim: chroma is IGNORED.
  ('#372E24', '#000000', 'L 19.6 C 8.3: under the hard floor, snaps anyway'),
  ('#1F0E07', '#000000', 'L 5.6 C 9.0: deep dark, chroma irrelevant'),
];

void main() {
  test('the snap thresholds are pinned to the Python constants (D31-A)', () {
    // Calibrated on the gate G2S measured data (see display.py rationale). If
    // they change in Python, this port and the table below must change WITH
    // them — deliberately, not by drift.
    expect(kSnapBlackLMax, 28.0);
    expect(kSnapWhiteLMin, 80.0);
    expect(kNeutralChroma, 13.0);
    // Two-tier black branch (B-G25-3, measured on the 65-photo gate G2.5 set).
    expect(kSnapBlackLHard, 21.0);
    expect(kSnapBlackSoftChroma, 4.0);
    expect(kSnapBlackLHard, lessThan(kSnapBlackLMax));
    expect(kSnapBlackSoftChroma, lessThan(kNeutralChroma));
  });

  group('snapNeutralForDisplay mirrors the Python fixture table 1:1', () {
    for (final (String input, String expected, String why)
        in kDartParityFixtures) {
      test('$input -> $expected', () {
        expect(_hex(snapNeutralForDisplay(_rgb(input))), expected, reason: why);
      });
    }
  });

  test('the input list is never mutated (display-only guarantee, D31-A)', () {
    final List<int> raw = <int>[46, 41, 40]; // #2E2928 -> snaps to black
    final List<int> snapped = snapNeutralForDisplay(raw);
    expect(raw, <int>[46, 41, 40]);
    expect(snapped, <int>[0, 0, 0]);
  });

  group('snapColorForDisplay (UI convenience)', () {
    test('snaps a diluted black to pure black', () {
      expect(snapColorForDisplay(const Color(0xFF3C3937)),
          const Color(0xFF000000));
    });

    test('snaps a white-read-as-gray to pure white', () {
      expect(snapColorForDisplay(const Color(0xFFD0CCC9)),
          const Color(0xFFFFFFFF));
    });

    test('returns the SAME object when the snap is a no-op', () {
      const Color navy = Color(0xFF051C56); // chroma-gated
      expect(identical(snapColorForDisplay(navy), navy), isTrue);
      const Color midGray = Color(0xFF6C747B); // genuine mid gray
      expect(identical(snapColorForDisplay(midGray), midGray), isTrue);
    });
  });
}
