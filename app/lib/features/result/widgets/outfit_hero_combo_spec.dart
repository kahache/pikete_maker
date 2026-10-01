import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../sneaker/widgets/combo_caption.dart';
import '../../sneaker/widgets/hero_combo.dart';
import '../../sneaker/widgets/hero_combo_band.dart';
import 'outfit_result_keys.dart';

/// Outfit-flow (D36) constants of the shared hero widgets (A6 / review F18):
/// the outfit result reuses the sneaker [HeroComboBand] / [ComboCaption] and
/// only supplies these values.

/// Band height (mockup `.combo { height: 154px }`), segment flex ×100 (mockup:
/// fit 1.3 · súmale 1.5 · neutral 0.9), imperative role micro-labels
/// "tu fit" / "súmale" / "+ {neutro}".
const HeroComboBandSpec outfitHeroBandSpec = HeroComboBandSpec(
  bandKey: OutfitResultKeys.heroBand,
  height: 154,
  baseFlex: 130,
  complementFlex: 150,
  neutralFlex: 90,
  tags: _outfitTags,
);

/// The kicker above the outfit hero band (D36 / D39): the hero
/// (complementary, or no selection) keeps `resultHeroKicker` verbatim; a
/// combo selected in "Otras combis" shows that row's OWN name.
String outfitHeroKicker(AppLocalizations l10n, HarmonyType? scheme) =>
    switch (scheme) {
      null || HarmonyType.complementary => l10n.resultHeroKicker,
      HarmonyType.analogous =>
        l10n.resultComboKicker(l10n.sneakerHarmonyAnalogousName),
      HarmonyType.triadic =>
        l10n.resultComboKicker(l10n.sneakerHarmonyTriadicName),
      HarmonyType.splitComplementary =>
        l10n.resultComboKicker(l10n.sneakerHarmonySplitName),
    };

HeroComboTags _outfitTags(AppLocalizations l10n, HeroCombo combo) => (
      base: l10n.resultTagFit,
      complement: l10n.resultTagAdd,
      neutral: l10n.resultTagNeutral(combo.neutralName),
    );

/// Outfit caption copy: the slang one-liner for a chromatic combo; canvas mode
/// reuses `canvasBody` verbatim as a single line (the pops ARE the
/// recommendation, D36 §5).
const ComboCaptionCopy outfitCaptionCopy = ComboCaptionCopy(
  lead: _outfitLead,
  rest: _outfitRest,
  canvasRest: _outfitCanvasBody,
);

String _outfitLead(AppLocalizations l10n, HeroCombo combo) =>
    l10n.resultCaptionLead(combo.complementName, combo.baseName);

String _outfitRest(AppLocalizations l10n, HeroCombo combo) =>
    l10n.resultCaptionRest(combo.neutralName, combo.otherNeutralName);

String _outfitCanvasBody(AppLocalizations l10n) => l10n.canvasBody;
