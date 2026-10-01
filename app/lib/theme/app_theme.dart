import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'brand_colors.dart';
import 'dimens.dart';

/// Assembles the app's [ThemeData] from the design tokens.
///
/// THIS is the ONLY place where tokens become a Material theme (CLAUDE.md:
/// "nobody hardcodes colors/spacing in widgets"). Two layers coexist on
/// purpose:
///  1. Standard Material 3 [ColorScheme] / [TextTheme] — so Material widgets
///     (buttons, sheets, ripples) come out with our colors already.
///  2. The [AppColors] [ThemeExtension] — for the tokens Material does not
///     model (tints, brights, 4-level text ramp, surfaceSubtle, scrim...).
///
/// Light theme first (D7). Dark remains a structural TODO: add an
/// `AppTheme.dark()` using `AppColors.dark` when it gets designed.
abstract final class AppTheme {
  static ThemeData light() {
    const AppColors c = AppColors.light;

    // Material 3 ColorScheme mapping the semantic roles (D8).
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.mintInk, // role.action
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: BrandColors.mintTint,
      onPrimaryContainer: BrandColors.mintInk,
      secondary: BrandColors.purpleInk, // role.accent
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: BrandColors.purpleTint,
      onSecondaryContainer: BrandColors.purpleInk,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1C1826),
      surfaceContainerHighest: Color(0xFFF7F5FB), // surfaceSubtle
      onSurfaceVariant: Color(0xFF544E68),
      outline: Color(0xFFD9D3E6), // borderStrong
      outlineVariant: Color(0xFFE9E6F2), // border
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      scrim: Color(0x661C1826),
      shadow: Color(0x141C1826),
    );

    final TextTheme textTheme = _buildTextTheme(c);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      textTheme: textTheme,

      // Register the extension: widgets read `context.colors.*`.
      extensions: const <ThemeExtension<dynamic>>[c],

      // --- Components with our shape (radius/pill) and tokens ---
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: c.action, // back/chevrons in action (mint)
        titleTextStyle: AppType.label.copyWith(color: c.textTertiary),
      ),

      // Filled primary button (CTA) — pill, 56px, white text on mint.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.actionOnFill,
          disabledBackgroundColor: c.borderStrong,
          disabledForegroundColor: c.textDisabled,
          minimumSize: const Size.fromHeight(Sizes.ctaHeight),
          textStyle: AppType.cta,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),

      // Secondary button (outline) — same size, strong border, text in action.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.action,
          minimumSize: const Size.fromHeight(Sizes.ctaHeight),
          textStyle: AppType.cta,
          side: BorderSide(color: c.borderStrong, width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),

      // Links / light actions.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.action,
          textStyle: AppType.cta,
        ),
      ),

      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radii.rLg),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.actionBright, // non-textual fill (D8)
        linearTrackColor: c.actionTint,
      ),
    );
  }

  /// Maps the tokens.json type scale to the Material slots.
  /// Colored with textPrimary by default; each widget may recolor.
  static TextTheme _buildTextTheme(AppColors c) {
    final Color ink = c.textPrimary;
    return TextTheme(
      displaySmall: AppType.display.copyWith(color: ink),
      titleLarge: AppType.title.copyWith(color: ink),
      titleMedium: AppType.heading.copyWith(color: ink),
      bodyLarge: AppType.body.copyWith(color: c.textSecondary),
      bodyMedium: AppType.body.copyWith(color: c.textSecondary),
      bodySmall: AppType.caption.copyWith(color: c.textTertiary),
      labelSmall: AppType.label.copyWith(color: c.textTertiary),
      labelLarge: AppType.cta.copyWith(color: ink),
    );
  }
}
