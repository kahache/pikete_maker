import 'package:flutter/painting.dart';

/// Raw BRAND palette (theme-independent) — source: docs/design/tokens.json (v1.2).
///
/// D8: mint = ACTION, purple = ACCENT. D9: the tinted neutrals live in
/// [AppColors] (they depend on the light/dark theme). Here only the brand
/// pair.
///
/// Golden rule (tokens.json / DESIGN_SYSTEM §2):
///  - Only the `ink` variant carries TEXT (AA contrast validated on white).
///  - `bright` = NON-textual elements (progress bar, graphic details).
///  - `tint`   = soft backgrounds of chips/badges; text on top goes in `ink`.
///
/// The app NEVER consumes these values directly in widgets: it consumes the
/// semantic aliases of [AppColors] (role.action / role.accent). This class is
/// the ramp definition; the semantic mapping lives in app_colors.dart.
abstract final class BrandColors {
  // --- Mint = ACTION (role.action) ---
  /// The only one valid for text/filled CTA. 5.10:1 on white.
  static const Color mintInk = Color(0xFF0B7C6C);

  /// Recognizable brand mint. NOT textual (1.59:1). Progress, underlines.
  static const Color mintBright = Color(0xFF43E5C2);

  /// Chip/badge background. Text on top always in [mintInk].
  static const Color mintTint = Color(0xFFDFF7F1);

  // --- Purple = ACCENT (role.accent) ---
  /// Textual accent (BASE badge, watermark). 6.42:1 on white.
  static const Color purpleInk = Color(0xFF6C3FD1);

  /// NON-textual accent (2.72:1). Graphic details.
  static const Color purpleBright = Color(0xFFA78BFA);

  /// Soft chip/badge background. Text on top in [purpleInk].
  static const Color purpleTint = Color(0xFFEFEAFB);

  // --- LOGO turquoise (D14) ---
  /// CAREFUL: this is NOT the UI mint. It is the brand turquoise of the logo
  /// mark/wordmark. Single value at all sizes (LOGO.md). Do not use as a
  /// functional UI color.
  static const Color logoTurquoise = Color(0xFF17B598);
}
