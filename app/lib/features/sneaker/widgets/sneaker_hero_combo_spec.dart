import '../../../l10n/l10n.dart';
import 'combo_caption.dart';
import 'hero_combo.dart';
import 'hero_combo_band.dart';
import 'sneaker_result_keys.dart';

/// Sneaker-flow constants of the shared hero widgets (A6 / review F18).

/// Spec §5 (D27): band height 150, segment flex ×100 zapas ≈1.15 · ropa ≈1.55
/// · neutral ≈0.9, role micro-labels "tus zapas" / "tu ropa" / "+ {neutro}"
/// (D27-Q3 keeps them).
const HeroComboBandSpec sneakerHeroBandSpec = HeroComboBandSpec(
  bandKey: SneakerResultKeys.heroBand,
  height: 150,
  baseFlex: 115,
  complementFlex: 155,
  neutralFlex: 90,
  tags: _sneakerTags,
);

HeroComboTags _sneakerTags(AppLocalizations l10n, HeroCombo combo) => (
      base: l10n.sneakerTagZapas,
      complement: l10n.sneakerTagRopa,
      neutral: l10n.sneakerTagNeutral(combo.neutralName),
    );

/// Sneaker caption copy: chromatic lead/rest, and a two-part canvas caption.
const ComboCaptionCopy sneakerCaptionCopy = ComboCaptionCopy(
  lead: _sneakerLead,
  rest: _sneakerRest,
  canvasLead: _sneakerCanvasLead,
  canvasRest: _sneakerCanvasRest,
);

String _sneakerLead(AppLocalizations l10n, HeroCombo combo) =>
    l10n.sneakerCaptionLead(combo.complementName, combo.baseName);

String _sneakerRest(AppLocalizations l10n, HeroCombo combo) =>
    l10n.sneakerCaptionRest(combo.neutralName, combo.otherNeutralName);

String _sneakerCanvasLead(AppLocalizations l10n) =>
    l10n.sneakerCanvasCaptionLead;

String _sneakerCanvasRest(AppLocalizations l10n) =>
    l10n.sneakerCanvasCaptionRest;
