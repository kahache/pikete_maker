import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/features/result/looks_search.dart';
import 'package:piketemaker/features/sneaker/sneaker_strings.dart';
import 'package:piketemaker/l10n/l10n.dart';

/// es-BYTE-IDENTITY pin at the ARB level (i18n round, D18 extended).
///
/// The widget suite pins the RENDERED Spanish copy; this file pins the es ARB
/// source directly against the pre-i18n literals, so a translation-round edit
/// to `app_es.arb` that would silently change the F&F beta copy fails loudly
/// here even before a screen renders it. A deliberate CEO copy change updates
/// both this file and the ARB (copy-map-only, zero layout risk).
void main() {
  group('es ARB == pre-i18n literals (spot pins across every surface)', () {
    test('home + onboarding', () {
      expect(esL10n.homeSneakerLabel, 'Mis zapas');
      expect(esL10n.homeOutfitLabel, 'Mi pikete');
      expect(esL10n.homeOutfitCaption, 'Saca la paleta de tu fit');
      expect(esL10n.homeGoPill, 'Empezar');
      expect(
          esL10n.onbWelcomeHeadline, 'Los colores de tu fit,\ncon criterio.');
      expect(esL10n.onbTipPhraseWall,
          'Ponte frente a una pared lisa de un solo color.');
      expect(esL10n.onbTipCta, 'Hacer mi primera foto');
      expect(esL10n.onbSkip, 'Saltar');
      // #95: first-run photo-privacy reassurance (on-device + not stored).
      expect(esL10n.onbWelcomePrivacy,
          'Tu foto no sale de tu móvil y no la guardamos.');
    });

    test('outfit flow (source sheet, confirm, analyzing)', () {
      expect(esL10n.outfitSheetTitle, '¿De dónde sacamos la foto?');
      expect(esL10n.privacyNote,
          'Tu foto no sale del móvil: se analiza aquí mismo.');
      expect(esL10n.sheetCameraTitle, 'Hacer una foto');
      expect(esL10n.sheetGalleryTitle, 'Elegir de la galería');
      expect(esL10n.outfitConfirmTitle, '¿Se ve bien tu fit?');
      expect(esL10n.outfitConfirmCtaPrimary, 'Analizar');
      expect(esL10n.outfitAnalyzingHeadline, 'Leyendo los colores de tu fit…');
      expect(esL10n.outfitAnalyzingSkipNotePrefix,
          'Tu paleta aparece en cuanto termine — ');
      expect(esL10n.analyzingSkipNoteAccent, 'ya casi');
      expect(esL10n.analyzingMonoLabel, 'analizando');
    });

    test('result (outfit) incl. Phase 2.5 garment copy', () {
      expect(esL10n.resultHeadlineLegacy, 'Tu paleta');
      expect(esL10n.resultHeadlineGarments, 'Tu pikete');
      expect(esL10n.resultMeta('14 jul 2026'), 'Fit de hoy · 14 jul 2026');
      expect(esL10n.resultBaseLead, 'Tu color dominante. ');
      expect(esL10n.resultBaseAttributionUpper, 'Sale de tu parte de arriba. ');
      expect(esL10n.resultBaseAttributionLower, 'Sale de tu parte de abajo. ');
      expect(esL10n.resultBaseRest, 'Todo conjunta alrededor de él.');
      expect(esL10n.garmentUpperLabel, 'ARRIBA');
      expect(esL10n.garmentLowerLabel, 'ABAJO');
      expect(esL10n.garmentSingleLabel, 'TU ROPA');
      expect(esL10n.harmoniesTitle, 'Combina con');
      expect(esL10n.canvasTitle, 'Tu look es un lienzo');
      expect(esL10n.resultCtaLooks, 'Ver looks así');
      expect(esL10n.resultCtaStory, 'Súbela a tu story');
      // Engine parity: the localized harmony labels must MATCH the es
      // literals the engine still emits in Harmony.name/description.
      expect(esL10n.harmonyComplementaryName, 'Complementario');
      expect(esL10n.harmonyComplementaryDesc, 'Contraste máximo, 2 colores');
      expect(esL10n.harmonyAnalogousName, 'Análogo');
      expect(esL10n.harmonyTriadicName, 'Triádico');
      expect(esL10n.harmonySplitName, 'Complementario dividido');
    });

    test('result (outfit) D36 recommendation-first copy', () {
      // Hero (the recommendation is the protagonist).
      expect(esL10n.resultRecoHeadline, 'Toma tu pikete');
      expect(esL10n.resultHeroKicker, 'La combi · Contraste');
      expect(esL10n.resultTagFit, 'tu fit');
      expect(esL10n.resultTagAdd, 'súmale');
      expect(esL10n.resultTagNeutral('crema'), '+ crema');
      expect(esL10n.resultCaptionLead('verde', 'morado'),
          'El verde hace saltar el morado de tu fit.');
      expect(esL10n.resultCaptionRest('crema', 'negro'),
          ' Súmale crema o negro y vas fino.');
      // Demoted extracted palette ("tu fit", CEO wording 2026-07-23).
      expect(esL10n.resultPaletteLabel, 'Tu fit · de aquí sale la combi');
      expect(esL10n.resultPaletteLabelCanvas, 'Tu fit · tu lienzo neutro');
      // Canvas mode (the pops ARE the recommendation).
      expect(esL10n.resultCanvasHeadline, 'Tu fit pide color');
      expect(esL10n.resultCanvasKicker, 'La combi · Lienzo');
      expect(esL10n.resultCanvasBaseCap,
          'Todo tu fit es neutro — combina con todo. Por eso mandamos color, no armonías.');
      // "Otras combis" reuses the sneaker slang taxonomy (D36 decision 2).
      expect(esL10n.sneakerSectionTitle, 'Otras combis');
      expect(esL10n.sneakerHarmonyAnalogousName, 'Tono sobre tono');
      expect(esL10n.sneakerHarmonyTriadicName, 'Equilibrada');
      expect(esL10n.sneakerHarmonySplitName, 'Contraste con matiz');
    });

    test('errors + snackbars', () {
      expect(esL10n.feedbackCameraHeadline, 'Sin cámara no hay fit.');
      expect(esL10n.feedbackFailedHeadline, 'No pillamos bien tu fit.');
      expect(esL10n.feedbackNoOutfitHeadline, 'Aquí no vemos un outfit claro.');
      expect(esL10n.feedbackCameraSettingsPath,
          'Ajustes del sistema → Apps → PiketeMaker → Permisos → Cámara.');
      expect(esL10n.storyFailedSnack,
          'No se pudo generar la story. Prueba otra vez.');
      // N1 / D37 story preview sheet (2026-09-29).
      expect(esL10n.storyIncludePhoto, 'Incluir mi foto');
      expect(esL10n.storyPhotoPrivacy,
          'Tu foto solo sale del móvil si tú la compartes.');
      expect(esL10n.storyShareCta, 'Compartir');
      expect(esL10n.storyPreviewLabel, 'Vista previa de tu story');
      // The legacy constant the pre-i18n tests pin and the ARB stay one
      // value: both must be the SnackBar the screens actually show in es.
      expect(esL10n.looksSearchFailed, kLooksSearchFailedCopy);
    });

    test('SneakerStrings facade reads the es ARB (single source of truth)', () {
      expect(SneakerStrings.appBarKicker, 'MIS ZAPAS');
      expect(SneakerStrings.confirmCtaPrimary, 'Dame el pikete');
      expect(SneakerStrings.resultCtaPrimary, 'Enséñame otros piketes');
      expect(SneakerStrings.resultTitle, 'Combina tu ropa con estas zapas');
      expect(
          SneakerStrings.resultMeta('14 jul 2026'), 'Tus zapas · 14 jul 2026');
      expect(SneakerStrings.resultCaptionLead('rojo', 'verde-azulado'),
          'El rojo hace saltar el verde-azulado de tus zapas.');
      expect(SneakerStrings.resultCaptionRest('crema', 'negro'),
          ' Súmale crema o negro y vas fino.');
      expect(SneakerStrings.baseBadge('negro'), 'Base · negro');
      expect(
          SneakerStrings.baseDescRest('negro'), '. El negro manda la combi.');
      expect(SneakerStrings.errorTitle, 'No hemos pillado los colores');
      expect(SneakerStrings.tipCasaCta, 'Hacer la foto');
      expect(SneakerStrings.sourceTitle, '¿Desde dónde haces la foto?');
    });
  });
}
