import 'package:flutter/widgets.dart';

import '../../core/color_engine/models.dart';
import '../../core/segmentation/recolor_applicability.dart';
import '../../l10n/l10n.dart';
import '../sneaker/color_names.dart';
import '../sneaker/widgets/hero_combo.dart';

/// The colour "Vérmelo puesto" paints (I2, D38) and its localized name.
///
/// SINGLE SOURCE (PM, r15): exactly the colour the result SHOWS — the D36
/// hero band's "súmale" complement (built the same way the band builds it:
/// `HeroCombo.of(..., snapForDisplay: false)`, D31-A raw outfit swatches),
/// or, in canvas mode (D10), the selected pop (the first one when none is
/// selected). Screen, recolor and story therefore never drift.
@immutable
class RecolorTarget {
  /// Creates a target.
  const RecolorTarget({required this.color, required this.name});

  /// The colour painted onto the garment.
  final Color color;

  /// Its localized name (the view's kicker "{Región} · {color}").
  final String name;

  /// The target for [result] in [language]; [selectedAccentIndex] is the
  /// canvas pop the user tapped (null = the first pop); [scheme] is the
  /// combo selected in "Otras combis" (D39; null = the hero) — its "súmale"
  /// colour is the scheme's first non-base colour (rule b, see
  /// [HeroCombo.partnerColor]).
  static RecolorTarget of(
    AnalysisResult result,
    String language, {
    int? selectedAccentIndex,
    HarmonyType? scheme,
  }) {
    if (result.isCanvas || result.harmonies.isEmpty) {
      final List<Color> pops = result.canvasAccents;
      final int i = (selectedAccentIndex != null &&
              selectedAccentIndex >= 0 &&
              selectedAccentIndex < pops.length)
          ? selectedAccentIndex
          : 0;
      final Color color = pops[i];
      return RecolorTarget(
          color: color, name: localizedColorName(color, language));
    }
    final HeroCombo combo =
        HeroCombo.of(result, language, snapForDisplay: false, scheme: scheme);
    return RecolorTarget(color: combo.complement, name: combo.complementName);
  }
}

/// The one-line tip that replaces the pill when the recolor is not offered
/// (UX §2.4; PM mapping r15), or null when NOTHING must be shown: without a
/// segmentation map the feature does not exist for that result, so no fix
/// is taught (`noSegmentation`).
String? recolorTipFor(AppLocalizations l10n, RecolorBlocker blocker) =>
    switch (blocker) {
      RecolorBlocker.severalPeople => l10n.recolorTipPeople,
      RecolorBlocker.poorLight => l10n.recolorTipLight,
      RecolorBlocker.maskUnreliable ||
      RecolorBlocker.regionTooSmall =>
        l10n.recolorTipCoverage,
      RecolorBlocker.noSegmentation => null,
    };

/// The localized region label (the selector segments + the kicker).
String recolorRegionLabel(AppLocalizations l10n, GarmentRegion region) =>
    region == GarmentRegion.lower
        ? l10n.garmentLowerLabel
        : l10n.garmentUpperLabel;
