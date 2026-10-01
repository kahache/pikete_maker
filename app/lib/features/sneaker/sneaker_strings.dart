import '../../l10n/l10n.dart';

/// CANONICAL-ES facade of the sneaker copy map (Phase 2S · F11) — i18n round.
///
/// The strings themselves moved to the ARB files (`lib/l10n/app_*.arb`,
/// #46/D18 groundwork paid): production widgets read the ACTIVE locale via
/// `context.l10n.sneaker…`. This class stays as a THIN FACADE over the
/// canonical es lookup so that:
///  - the copy-pinning widget tests (the F&F beta regression net) keep their
///    `SneakerStrings.x` assertions compiling and passing unchanged, and
///  - there is exactly ONE source of truth — the es ARB; these getters can
///    never drift from what the app renders in Spanish.
///
/// Spec keys live as `@description` metadata in `app_es.arb` (source: copy
/// inventory §6 of `docs/design/2026-07-11_1030_F2S_sneaker-flow-final-spec.md`
/// and the #83 selector spec). The CEO can still tweak slang live: editing
/// `app_es.arb` + `flutter gen-l10n` is copy-map-only, zero layout risk.
abstract final class SneakerStrings {
  // ---- App bar (shared by capture + result) ----
  static String get appBarKicker => esL10n.sneakerAppBarKicker;

  // ---- Screen 0 · Source selector (F2S · #83) ----
  static String get sourceTitle => esL10n.sneakerSourceTitle;
  static String get sourceSub => esL10n.sneakerSourceSub;
  static String get sourcePrivacy => esL10n.privacyNote;
  static String get sourceCasaTitle => esL10n.sneakerSourceCasaTitle;
  static String get sourceCasaHint => esL10n.sneakerSourceCasaHint;
  static String get sourceTiendaTitle => esL10n.sneakerSourceTiendaTitle;
  static String get sourceTiendaHint => esL10n.sneakerSourceTiendaHint;
  static String get sourceWebTitle => esL10n.sneakerSourceWebTitle;
  static String get sourceWebHint => esL10n.sneakerSourceWebHint;

  // ---- Mini-tutorial · «EL TRUCO» (F2S · #83) ----
  static String get tipBadge => esL10n.sneakerTipBadge;
  static String get tipCasaTitle => esL10n.sneakerTipCasaTitle;
  static String get tipCasaBody => esL10n.sneakerTipCasaBody;
  static String get tipCasaCta => esL10n.sneakerTipCasaCta;
  static String get tipTiendaTitle => esL10n.sneakerTipTiendaTitle;
  static String get tipTiendaBody => esL10n.sneakerTipTiendaBody;
  static String get tipTiendaCta => esL10n.sneakerTipTiendaCta;
  static String get tipWebTitle => esL10n.sneakerTipWebTitle;
  static String get tipWebBody => esL10n.sneakerTipWebBody;
  static String get tipWebCta => esL10n.sneakerTipWebCta;

  // ---- Screen 1 · Captura (source sheet + confirm) ----
  static String get sheetTitle => esL10n.sneakerSheetTitle;
  static String get sheetCameraCaption => esL10n.sneakerSheetCameraCaption;
  static String get sheetGalleryCaption => esL10n.sneakerSheetGalleryCaption;
  static String get confirmTitle => esL10n.sneakerConfirmTitle;
  static String get confirmHint => esL10n.sneakerConfirmHint;
  static String get confirmCtaPrimary => esL10n.sneakerConfirmCtaPrimary;
  static String get confirmCtaSecondary => esL10n.sneakerConfirmCtaSecondary;

  // ---- Screen 2 · Analizando ----
  static String get analyzingHeadline => esL10n.sneakerAnalyzingHeadline;
  static String get analyzingStep => esL10n.sneakerAnalyzingStep;
  static String get analyzingSkipNotePrefix =>
      esL10n.sneakerAnalyzingSkipNotePrefix;

  // ---- Screen 3 · Resultado (D27 inverted hierarchy) ----
  static String resultMeta(String fecha) => esL10n.sneakerResultMeta(fecha);
  static String get resultTitle => esL10n.sneakerResultTitle;
  static String get resultHeroKicker => esL10n.sneakerResultHeroKicker;
  static String get tagZapas => esL10n.sneakerTagZapas;
  static String get tagRopa => esL10n.sneakerTagRopa;
  static String tagNeutral(String neutro) => esL10n.sneakerTagNeutral(neutro);
  static String resultCaptionLead(String complemento, String base) =>
      esL10n.sneakerCaptionLead(complemento, base);
  static String resultCaptionRest(String neutro1, String neutro2) =>
      esL10n.sneakerCaptionRest(neutro1, neutro2);
  static String baseBadge(String color) => esL10n.sneakerBaseBadge(color);
  static String get baseDescPre => esL10n.sneakerBaseDescPre;
  static String get baseDescBold => esL10n.sneakerBaseDescBold;
  static String baseDescRest(String color) => esL10n.sneakerBaseDescRest(color);
  static String get sectionTitle => esL10n.sneakerSectionTitle;
  static String get sectionSub => esL10n.sneakerSectionSub;
  static String get harmonyAnalogousName => esL10n.sneakerHarmonyAnalogousName;
  static String get harmonyAnalogousSub => esL10n.sneakerHarmonyAnalogousSub;
  static String get harmonyTriadicName => esL10n.sneakerHarmonyTriadicName;
  static String get harmonyTriadicSub => esL10n.sneakerHarmonyTriadicSub;
  static String get harmonySplitCompName => esL10n.sneakerHarmonySplitName;
  static String get harmonySplitCompSub => esL10n.sneakerHarmonySplitSub;
  static String get resultCtaPrimary => esL10n.sneakerResultCtaPrimary;
  static String get resultCtaSecondary => esL10n.sneakerResultCtaSecondary;

  // ---- Canvas mode (D10) ----
  static String get canvasKicker => esL10n.sneakerCanvasKicker;
  static String get canvasCaptionLead => esL10n.sneakerCanvasCaptionLead;
  static String get canvasCaptionRest => esL10n.sneakerCanvasCaptionRest;

  // ---- Error state (spec §5, states table) ----
  static String get errorTitle => esL10n.sneakerErrorTitle;
  static String get errorBody => esL10n.sneakerErrorBody;
  static String get errorCta => esL10n.sneakerErrorCta;
}
