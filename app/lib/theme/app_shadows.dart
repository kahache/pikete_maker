import 'package:flutter/painting.dart';

/// Elevation — source: docs/design/tokens.json (shadow).
///
/// "Minimal elevation: white rules. Faint shadows, never dramatic. Tinted rgba
/// base (D9), not pure black." CSS `x y blur rgba` → [BoxShadow].
abstract final class AppShadows {
  /// Tinted base colour of every shadow: textPrimary #1C1826 (D9).
  static const Color _ink08 = Color(0x141C1826); // rgba(28,24,38,0.08)
  static const Color _ink10 = Color(0x1A1C1826); // rgba(28,24,38,0.10)
  static const Color _ink14 = Color(0x241C1826); // rgba(28,24,38,0.14)

  /// shadow.sm — 0 1px 3px rgba(28,24,38,0.08). Cards.
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: _ink08, blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// shadow.md — 0 4px 16px rgba(28,24,38,0.10). Raised previews.
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: _ink10, blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// shadow.lg — 0 12px 32px rgba(28,24,38,0.14). Sheets.
  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: _ink14, blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Hairline ring drawn OUTSIDE a box (CSS `0 0 0 1px <border>`): unlike a
  /// [Border], it never covers a pixel of the content.
  static BoxShadow ring(Color color) => BoxShadow(color: color, spreadRadius: 1);
}
