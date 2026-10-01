import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// THEME-DEPENDENT color tokens (D9: neutrals tinted with purple).
///
/// Exposed as a [ThemeExtension] — not as loose constants — by explicit
/// decision of tokens.json: *"the app consumes themes.{light|dark}.token from
/// day 1 so that dark is filling in values, not refactoring"*. Widgets read
/// `Theme.of(context).extension<AppColors>()!` (or the `context.colors`
/// helper), so the day dark mode is designed only a second [AppColors.dark]
/// instance is added and not a single widget is touched.
///
/// The semantic aliases (D8) are [action] and [accent]: widgets use these,
/// never `BrandColors.*` directly.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.action,
    required this.actionBright,
    required this.actionTint,
    required this.actionOnFill,
    required this.accent,
    required this.accentBright,
    required this.accentTint,
    required this.scrim,
    required this.error,
    required this.success,
  });

  // Surfaces
  final Color bg; // app background (white: makes the user's palette pop)
  final Color surface; // cards
  final Color surfaceSubtle; // ad slot, placeholders, alternating rows

  // Tinted borders (D9)
  final Color border; // hairline dividers
  final Color borderStrong; // secondary button outline

  // Tinted text ramp (D9) — only up to textTertiary is AA
  final Color textPrimary; // 17.38:1
  final Color textSecondary; // 7.88:1
  final Color textTertiary; // 5.62:1 — last one valid for text
  final Color textDisabled; // 3.41:1 — NOT AA, disabled/watermark only

  // ACTION role (mint) — the only functional color
  final Color action; // CTAs, links, active states
  final Color actionBright; // progress fill (non-textual)
  final Color actionTint; // progress bar track, soft chips
  final Color actionOnFill; // text/icon on filled CTA

  // ACCENT role (purple) — minimal doses (max 2 per screen)
  final Color accent; // BASE badge, watermark signature
  final Color accentBright; // non-textual detail
  final Color accentTint; // accent badge background

  // Utility
  final Color scrim; // veil under sheets (tinted, D9)
  final Color error; // real errors only
  final Color success; // discreet confirmations

  /// LIGHT instance (themes.light of tokens.json). The only one designed (D7).
  static const AppColors light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF7F5FB),
    border: Color(0xFFE9E6F2),
    borderStrong: Color(0xFFD9D3E6),
    textPrimary: Color(0xFF1C1826),
    textSecondary: Color(0xFF544E68),
    textTertiary: Color(0xFF6B6383),
    textDisabled: Color(0xFF8F87A3),
    action: BrandColors.mintInk,
    actionBright: BrandColors.mintBright,
    actionTint: BrandColors.mintTint,
    actionOnFill: Color(0xFFFFFFFF),
    accent: BrandColors.purpleInk,
    accentBright: BrandColors.purpleBright,
    accentTint: BrandColors.purpleTint,
    scrim: Color(0x661C1826), // rgba(28,24,38,0.40)
    error: Color(0xFFB3261E),
    success: Color(0xFF2E7D32),
  );

  // DARK NOTE (POSTPONED, D7): when designed, a `static const dark` is added
  // with the same names. The `ink` values will need lighter variants for AA
  // on a dark background. See tokens.json → themes.dark.

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSubtle,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? action,
    Color? actionBright,
    Color? actionTint,
    Color? actionOnFill,
    Color? accent,
    Color? accentBright,
    Color? accentTint,
    Color? scrim,
    Color? error,
    Color? success,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      action: action ?? this.action,
      actionBright: actionBright ?? this.actionBright,
      actionTint: actionTint ?? this.actionTint,
      actionOnFill: actionOnFill ?? this.actionOnFill,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentTint: accentTint ?? this.accentTint,
      scrim: scrim ?? this.scrim,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      action: Color.lerp(action, other.action, t)!,
      actionBright: Color.lerp(actionBright, other.actionBright, t)!,
      actionTint: Color.lerp(actionTint, other.actionTint, t)!,
      actionOnFill: Color.lerp(actionOnFill, other.actionOnFill, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBright: Color.lerp(accentBright, other.accentBright, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Syntactic sugar: `context.colors.action` instead of the long line.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
