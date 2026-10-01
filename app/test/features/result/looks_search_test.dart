import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/result/looks_search.dart';

/// The F5-lite query builder (#82) is a PURE function: these tests pin the
/// exact search strings the CEO specified (ES color NAMES, never hexes) for
/// every shape the screens feed it — 1 color, 2, 3, the 5 canvas accents, and
/// the snap/dedupe edges.

// Chromatic fixtures (never snapped).
const Color _red = Color(0xFFE02020); // 'rojo'
const Color _teal = Color(0xFF20B2A2); // 'verde-azulado' (h ≈ 173°)
const Color _cobalt = Color(0xFF2B5CE4); // 'azul'
const Color _emerald = Color(0xFF12A150); // 'verde'

// Neutral fixtures (display snap, D31-A — same values as display_parity).
const Color _dilutedBlack = Color(0xFF3C3937); // snaps → #000 → 'negro'
const Color _grayishWhite = Color(0xFFD0CCC9); // snaps → #FFF → 'blanco'
const Color _midGray = Color(0xFF6C747B); // stays itself → 'gris'

/// The curated canvas accent set (kCanvasAccents, D10), verbatim.
const List<Color> _canvasAccents = <Color>[
  Color(0xFFE4322B), // rojo
  Color(0xFF2B5CE4), // azul
  Color(0xFFE0A000), // naranja (mostaza, h ≈ 43°)
  Color(0xFF12A150), // verde
  Color(0xFFD6248C), // rosa
];

void main() {
  group('looksSearchQuery (colors → ES query)', () {
    test('1 color', () {
      expect(looksSearchQuery(const <Color>[_red]), 'outfit rojo');
    });

    test('2 colors join with "y"', () {
      expect(looksSearchQuery(const <Color>[_red, _teal]),
          'outfit rojo y verde azulado');
    });

    test('3 colors: comma list + final "y"', () {
      expect(looksSearchQuery(const <Color>[_red, _cobalt, _emerald]),
          'outfit rojo, azul y verde');
    });

    test('hyphenated names become searchable words (CEO example)', () {
      // Nobody types "verde-azulado" in a search box.
      expect(looksSearchQuery(const <Color>[_teal, _red]),
          'outfit verde azulado y rojo');
    });

    test('canvas accents: capped at $kLooksQueryMaxNames names', () {
      expect(looksSearchQuery(_canvasAccents), 'outfit rojo, azul y naranja');
    });

    test('SNAPPED names (D31-A): diluted black searches as "negro"', () {
      expect(looksSearchQuery(const <Color>[_dilutedBlack]), 'outfit negro');
      expect(looksSearchQuery(const <Color>[_grayishWhite]), 'outfit blanco');
    });

    test('a genuine mid gray stays "gris" (never snapped)', () {
      expect(looksSearchQuery(const <Color>[_midGray]), 'outfit gris');
    });

    test('duplicate names collapse (snapped black + pure black)', () {
      expect(
        looksSearchQuery(const <Color>[_dilutedBlack, Color(0xFF000000)]),
        'outfit negro',
        reason: '"negro y negro" reads broken',
      );
    });

    test('empty input degrades to the bare lead (defensive)', () {
      expect(looksSearchQuery(const <Color>[]), 'outfit');
    });
  });

  group('looksSearchQueryFromNames (pre-resolved names)', () {
    test('the sneaker hero trio, with its own "crema" neutral', () {
      expect(
        looksSearchQueryFromNames(
            const <String>['rojo', 'verde-azulado', 'crema']),
        'outfit rojo, verde azulado y crema',
      );
    });

    test('dedupe + cap apply to names too', () {
      expect(
        looksSearchQueryFromNames(const <String>[
          'negro', 'negro', 'blanco', 'rojo', 'azul', // 4 distinct, cap 3
        ]),
        'outfit negro, blanco y rojo',
      );
    });
  });

  group('looksSearchUri (deep-link target)', () {
    test('Google Images with the query, nothing else', () {
      final Uri uri = looksSearchUri('outfit rojo y negro');
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/search');
      expect(uri.queryParameters,
          <String, String>{'q': 'outfit rojo y negro', 'tbm': 'isch'});
    });
  });
}
