import 'package:flutter/animation.dart';

/// Motion — source: docs/design/tokens.json (motion).
///
/// "The palette reveal after the analysis uses 'reveal': it is THE moment of
/// the app. Everything else fast — Dani is speed-sensitive."
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  /// Palette reveal when the analysis finishes. The moment of the app.
  static const Duration reveal = Duration(milliseconds: 600);

  /// cubic-bezier(0.2, 0, 0, 1) — standard curve.
  static const Cubic standard = Cubic(0.2, 0, 0, 1);

  /// cubic-bezier(0, 0, 0, 1) — entrances.
  static const Cubic enter = Cubic(0, 0, 0, 1);
}
