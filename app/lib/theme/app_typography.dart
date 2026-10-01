import 'package:flutter/widgets.dart';

/// Type scale — source: docs/design/tokens.json (typography.scale).
///
/// System fonts (zero cost, zero loading, coherent with on-device D2): in
/// Flutter that means NOT setting `fontFamily` for the sans (uses the
/// system's Roboto/San Francisco) and using the platform mono for data.
///
/// Conversions from tokens.json:
///  - `height` (multiplier) = lineHeight / size.
///  - `letterSpacing` (logical px) = tracking_em * size.
///
/// Colors are NOT set here (they depend on the theme): each widget applies
/// the semantic token color with `.copyWith(color: context.colors.xxx)`.
abstract final class AppType {
  /// System monospace family for HEX and percentages (read as data).
  static const String _mono = 'monospace';

  /// Single screen headline ("Tu paleta"). One per screen.
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.02 * 32,
  );

  /// Section titles ("Combina con").
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.01 * 20,
  );

  /// Harmony name, card title.
  static const TextStyle heading = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Running text. Max 2 consecutive lines.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  /// Metadata, helper texts.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  /// System labels: BASE, scheme names. Uppercase (applied on the text).
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.08 * 11,
  );

  /// Palette hex values and weights.
  static const TextStyle dataMono = TextStyle(
    fontFamily: _mono,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.02 * 13,
  );

  /// Button text. Big and obvious.
  static const TextStyle cta = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
  );
}
