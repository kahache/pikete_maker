import 'package:flutter/material.dart';

import '../../../core/color_engine/display.dart';
import '../../../core/color_engine/models.dart';
import '../color_names.dart';

/// The hero combo derived from the engine result: base + complement + one
/// neutral suggestion, with their localized names for the caption.
///
/// SHARED by both result screens (A6 / review F18): the sneaker result (D27)
/// and the outfit recommendation-first result (D36) derive the SAME combo;
/// the only difference is the display snap (see [of]). Lives in the sneaker
/// feature because the sneaker flow introduced it; the outfit result imports
/// it (same pattern as `OtherCombosSection`).
@immutable
class HeroCombo {
  const HeroCombo({
    required this.base,
    required this.complement,
    required this.neutral,
    required this.baseName,
    required this.complementName,
    required this.neutralName,
    required this.otherNeutralName,
  });

  /// Neutral suggestions (spec §5: "+ crema"/"+ negro"). Crema completes a
  /// dark/mid combo; negro completes a light one. Values from the canonical
  /// mockup. Their NAMES come from the locale vocabulary table (i18n round):
  /// crema/negro are [ColorTerm]s, so "crema" localizes to "cream"/"crème"/
  /// "クリーム"… with accuracy guaranteed by the same table the namer uses.
  static const Color kCrema = Color(0xFFEDE9E1);
  static const Color kNegro = Color(0xFF23211F);

  /// Both hero colors at/above this relative luminance → the combo reads
  /// light → suggest negro instead of crema.
  static const double _lightComboLuminance = 0.5;

  final Color base;
  final Color complement;
  final Color neutral;
  final String baseName;
  final String complementName;
  final String neutralName;
  final String otherNeutralName;

  /// Builds the hero combo for [result], naming its colors in [language].
  ///
  /// [snapForDisplay] (#85, D31-A): the display snap is a PRODUCT-mode rule —
  /// every rendered swatch on the sneaker screen goes through it (default
  /// `true`), while outfit mode is untouched (`false`: swatches shown RAW,
  /// see `core/color_engine/display.dart`). The hero colors are chromatic by
  /// construction (D5 base + saturation-floored complement), so the snap is an
  /// identity in practice; the flag keeps that boundary explicit.
  ///
  /// [scheme] (D39, outfit result): the combo the user SELECTED in "Otras
  /// combis"; null (or a scheme the result does not carry) = the hero
  /// complementary, byte-identical to before D39. The "súmale" colour
  /// ([complement]) is the scheme's FIRST NON-BASE colour in engine order
  /// ([partnerColor], rule b): complementary 180°, triadic +120°, split
  /// +150°, analogous −30°.
  ///
  /// Precondition: [result] is chromatic (has a base and a harmony) — canvas
  /// mode uses the curated pops instead.
  static HeroCombo of(
    AnalysisResult result,
    String language, {
    bool snapForDisplay = true,
    HarmonyType? scheme,
  }) {
    final Harmony hero = schemeHarmony(result, scheme);
    Color shown(Color color) =>
        snapForDisplay ? snapColorForDisplay(color) : color;
    final Color rawBase = result.base!.color;
    final Color base = shown(rawBase);
    final Color complement = shown(partnerColor(hero, rawBase));
    final bool lightCombo = base.computeLuminance() >= _lightComboLuminance &&
        complement.computeLuminance() >= _lightComboLuminance;
    final Color neutral = lightCombo ? kNegro : kCrema;
    final String cremaName = colorTermName(ColorTerm.crema, language);
    final String negroName = colorTermName(ColorTerm.negro, language);
    return HeroCombo(
      base: base,
      complement: complement,
      neutral: neutral,
      baseName: localizedColorName(base, language),
      complementName: localizedColorName(complement, language),
      neutralName: lightCombo ? negroName : cremaName,
      otherNeutralName: lightCombo ? cremaName : negroName,
    );
  }

  /// The harmony of [scheme] in [result] (D39), else the complementary (the
  /// hero), else the first harmony.
  static Harmony schemeHarmony(AnalysisResult result, HarmonyType? scheme) {
    if (scheme != null) {
      for (final Harmony h in result.harmonies) {
        if (h.type == scheme) return h;
      }
    }
    return result.harmonies.firstWhere(
      (Harmony h) => h.type == HarmonyType.complementary,
      orElse: () => result.harmonies.first,
    );
  }

  /// Rule b (D39): the FIRST colour of [harmony] (engine order) that is not
  /// [base]; the last colour when every colour equals the base. For the
  /// complementary `[base, complement]` this is `colors[1]`, exactly the
  /// pre-D39 pick.
  static Color partnerColor(Harmony harmony, Color base) {
    for (final Color color in harmony.colors) {
      if (color != base) return color;
    }
    return harmony.colors.last;
  }
}
