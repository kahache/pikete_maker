// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get homeTutorialTooltip => 'Comment faire la photo';

  @override
  String get homeSneakerLabel => 'Mes sneakers';

  @override
  String get homeSneakerCaption => 'Monte le fit à partir de tes sneakers';

  @override
  String get homeOutfitLabel => 'Mon fit';

  @override
  String get homeOutfitCaption => 'Sors la palette de ton fit';

  @override
  String get homeGoPill => 'Commencer';

  @override
  String get onbSkip => 'Passer';

  @override
  String get onbWelcomeHeadline => 'Les couleurs de ton fit,\navec du goût.';

  @override
  String get onbWelcomeBody =>
      'Prends une photo et je te dis ta palette et avec quoi elle matche.';

  @override
  String get onbWelcomeCta => 'Commencer';

  @override
  String get onbWelcomePrivacy =>
      'Ta photo reste sur ton tel et on ne la garde pas.';

  @override
  String get onbTipBadge => 'TIP PRO';

  @override
  String get onbTipHeadline => 'L’astuce pour\nchoper tes couleurs';

  @override
  String get onbTipPhraseWall =>
      'Mets-toi devant un mur uni, d’une seule couleur.';

  @override
  String get onbTipPhraseFullFit =>
      'Que ton fit se voie en entier, de haut en bas.';

  @override
  String get onbTipPhraseLight => 'Un pas en arrière et une bonne lumière.';

  @override
  String get onbTipCaption =>
      'Plus le fond est uni, mieux je lis tes couleurs.';

  @override
  String get onbTipCta => 'Prendre ma première photo';

  @override
  String get onbExampleGood => 'TOP';

  @override
  String get onbExampleBad => 'RATÉ';

  @override
  String get onbIllustrationGood =>
      'Bonne photo : corps entier devant un mur uni';

  @override
  String get onbIllustrationBad =>
      'Photo ratée : la même silhouette dans une pièce chargée';

  @override
  String get privacyNote =>
      'Ta photo ne quitte pas ton tel : elle est analysée ici même.';

  @override
  String get sheetCameraTitle => 'Prendre une photo';

  @override
  String get sheetGalleryTitle => 'Choisir dans la galerie';

  @override
  String get sheetPlainBgHint => 'Fond uni = couleurs plus propres.';

  @override
  String get outfitSheetTitle => 'D’où sort la photo ?';

  @override
  String get outfitSheetCameraCaption => 'Corps entier, fond uni';

  @override
  String get outfitSheetGalleryCaption => 'Une que tu as déjà';

  @override
  String get outfitConfirmTitle => 'Ton fit rend bien ?';

  @override
  String get outfitConfirmHint => 'Fond uni = couleurs plus propres.';

  @override
  String get outfitConfirmCtaPrimary => 'Analyser';

  @override
  String get outfitConfirmCtaSecondary => 'Refaire';

  @override
  String get outfitAnalyzingHeadline => 'Je lis les couleurs de ton fit…';

  @override
  String get outfitAnalyzingStep1 => 'Lecture de ta photo';

  @override
  String get outfitAnalyzingStep2 => 'Regroupement des couleurs';

  @override
  String get outfitAnalyzingStep3 => 'Montage de tes harmonies';

  @override
  String get outfitAnalyzingSkipNotePrefix =>
      'Ta palette arrive dès que c’est fini — ';

  @override
  String get analyzingMonoLabel => 'analyse';

  @override
  String get analyzingSkipNoteAccent => 'ça arrive';

  @override
  String get adSlotTipBadge => 'TIP';

  @override
  String get adSlotAdCaption =>
      'La progression reste visible en haut : la pub accompagne l’attente, elle ne la bloque pas.';

  @override
  String get adSlotTipCaption =>
      'Fond uni et un pas en arrière : c’est comme ça que je chope tes couleurs.';

  @override
  String get feedbackCameraHeadline => 'Sans caméra, pas de fit.';

  @override
  String get feedbackCameraDetail =>
      'Active-la dans les réglages ou choisis une photo de ta galerie.';

  @override
  String get feedbackCameraCtaPrimary => 'Comment l’activer';

  @override
  String get feedbackCameraCtaSecondary => 'Choisir dans la galerie';

  @override
  String get feedbackCameraSettingsPath =>
      'Réglages système → Applis → PiketeMaker → Autorisations → Caméra.';

  @override
  String get feedbackFailedHeadline => 'On n’a pas bien capté ton fit.';

  @override
  String get feedbackFailedDetail =>
      'Essaie avec plus de lumière ou recule d’un pas.';

  @override
  String get feedbackFailedCtaPrimary => 'Essayer une autre photo';

  @override
  String get feedbackFailedCtaSecondary => 'Réessayer avec la même';

  @override
  String get feedbackNoOutfitHeadline => 'On ne voit pas d’outfit clair ici.';

  @override
  String get feedbackNoOutfitDetail =>
      'Corps entier, bonne lumière et fond calme.';

  @override
  String get feedbackNoOutfitCtaPrimary => 'Faire une autre photo';

  @override
  String get feedbackNoOutfitCtaSecondary => 'Choisir dans la galerie';

  @override
  String get resultHeadlineLegacy => 'Ta palette';

  @override
  String get resultHeadlineGarments => 'Ton fit';

  @override
  String resultMeta(String date) {
    return 'Fit du jour · $date';
  }

  @override
  String get resultBaseBadge => 'BASE';

  @override
  String get resultBaseLead => 'Ta couleur dominante. ';

  @override
  String get resultBaseAttributionUpper => 'Elle vient du haut de ton fit. ';

  @override
  String get resultBaseAttributionLower => 'Elle vient du bas de ton fit. ';

  @override
  String get resultBaseRest => 'Tout le look s’accorde autour d’elle.';

  @override
  String get garmentUpperLabel => 'HAUT';

  @override
  String get garmentLowerLabel => 'BAS';

  @override
  String get garmentSingleLabel => 'TES VÊTEMENTS';

  @override
  String get resultRecoHeadline => 'Prends ton fit';

  @override
  String get resultHeroKicker => 'La combi · Contraste';

  @override
  String get resultTagFit => 'ton fit';

  @override
  String get resultTagAdd => 'ajoute';

  @override
  String resultTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String resultCaptionLead(String complement, String base) {
    return 'Combo $complement + $base : ton fit claque direct.';
  }

  @override
  String resultCaptionRest(String neutral1, String neutral2) {
    return ' Ajoute du $neutral1 ou du $neutral2 et c’est propre.';
  }

  @override
  String get resultPaletteLabel => 'Ton fit · la combi vient de là';

  @override
  String get resultPaletteLabelCanvas => 'Ton fit · ta toile neutre';

  @override
  String get resultCanvasHeadline => 'Ton fit réclame de la couleur';

  @override
  String get resultCanvasKicker => 'La combi · Toile';

  @override
  String get resultCanvasBaseCap =>
      'Tout ton fit est neutre — il va avec tout. C’est pour ça qu’on t’envoie de la couleur, pas des harmonies.';

  @override
  String get harmoniesTitle => 'Ça matche avec';

  @override
  String get harmoniesSub =>
      'Touche une combi et mate des looks réels avec ces couleurs.';

  @override
  String get canvasTitle => 'Ton look est une toile';

  @override
  String get canvasBody =>
      'Noir, blanc et gris vont avec tout. Ajoute une touche de couleur avec l’un d’eux :';

  @override
  String get resultCtaLooks => 'Voir des looks comme ça';

  @override
  String get resultCtaStory => 'Balance-la en story';

  @override
  String get storyFailedSnack => 'Impossible de générer la story. Réessaie.';

  @override
  String get storyIncludePhoto => 'Inclure ma photo';

  @override
  String get storyPhotoPrivacy =>
      'Ta photo ne quitte ton téléphone que si tu la partages.';

  @override
  String get storyShareCta => 'Partager';

  @override
  String get storyPreviewLabel => 'Aperçu de ta story';

  @override
  String get looksSearchFailed =>
      'Impossible d’ouvrir le navigateur. Vérifie ta connexion et réessaie.';

  @override
  String get harmonyComplementaryName => 'Complémentaire';

  @override
  String get harmonyComplementaryDesc => 'Contraste max, 2 couleurs';

  @override
  String get harmonyAnalogousName => 'Analogue';

  @override
  String get harmonyAnalogousDesc => 'Doux, ton sur ton';

  @override
  String get harmonyTriadicName => 'Triadique';

  @override
  String get harmonyTriadicDesc => 'Équilibré, 3 couleurs';

  @override
  String get harmonySplitName => 'Complémentaire divisé';

  @override
  String get harmonySplitDesc => 'Contraste avec nuance';

  @override
  String get sneakerAppBarKicker => 'MES SNEAKERS';

  @override
  String get sneakerSourceTitle => 'Tu fais la photo d’où ?';

  @override
  String get sneakerSourceSub => 'Chaque spot a son astuce. Choisis le tien.';

  @override
  String get sneakerSourceCasaTitle => 'Maison ou rue';

  @override
  String get sneakerSourceCasaHint => 'Les sneakers au centre, plein cadre';

  @override
  String get sneakerSourceTiendaTitle => 'En boutique';

  @override
  String get sneakerSourceTiendaHint =>
      'Pose-les au sol, comme si c’était les tiennes';

  @override
  String get sneakerSourceWebTitle => 'Capture d’écran';

  @override
  String get sneakerSourceWebHint => 'Recadre jusqu’à ne garder que la sneaker';

  @override
  String get sneakerTipBadge => 'L’ASTUCE';

  @override
  String get sneakerTipCasaTitle => 'Sneakers au centre, plein cadre';

  @override
  String get sneakerTipCasaBody =>
      'Rapproche-toi jusqu’à ce que les sneakers remplissent presque tout l’écran. Fond uni (sol ou mur) et bonne lumière.';

  @override
  String get sneakerTipCasaCta => 'Prendre la photo';

  @override
  String get sneakerTipTiendaTitle => 'Pose-les au sol, comme les tiennes';

  @override
  String get sneakerTipTiendaBody =>
      'Pose les sneakers au sol et shoote d’en haut, comme si elles étaient déjà à toi. Comme ça le fond ne s’invite pas dans les couleurs.';

  @override
  String get sneakerTipTiendaCta => 'Prendre la photo';

  @override
  String get sneakerTipWebTitle => 'Recadre pour ne garder que la sneaker';

  @override
  String get sneakerTipWebBody =>
      'Avant de l’envoyer, recadre la capture : plus de navigateur, plus de prix, plus de blanc. Juste la sneaker.';

  @override
  String get sneakerTipWebCta => 'Choisir la capture';

  @override
  String get sneakerIllustrationCasa =>
      'Une grande sneaker centrée qui touche presque les coins du cadre';

  @override
  String get sneakerIllustrationTienda =>
      'Une sneaker au sol et un téléphone qui shoote d’en haut';

  @override
  String get sneakerIllustrationWeb =>
      'Une fenêtre de navigateur avec une petite sneaker et un recadrage qui ne garde que la sneaker';

  @override
  String get sneakerSheetTitle => 'D’où sortent les sneakers ?';

  @override
  String get sneakerSheetCameraCaption => 'Les sneakers, fond uni';

  @override
  String get sneakerSheetGalleryCaption => 'Une que tu as déjà';

  @override
  String get sneakerConfirmTitle => 'Tes sneakers rendent bien ?';

  @override
  String get sneakerConfirmHint =>
      'Fond uni et bien éclairées = couleurs plus propres.';

  @override
  String get sneakerConfirmCtaPrimary => 'Balance le fit';

  @override
  String get sneakerConfirmCtaSecondary => 'Une autre photo';

  @override
  String get sneakerAnalyzingHeadline =>
      'J’extrais les couleurs de tes sneakers…';

  @override
  String get sneakerAnalyzingStep => 'J’isole les sneakers du fond';

  @override
  String get sneakerAnalyzingSkipNotePrefix =>
      'Ta combi arrive dès que c’est fini — ';

  @override
  String sneakerResultMeta(String date) {
    return 'Tes sneakers · $date';
  }

  @override
  String get sneakerResultTitle => 'Accorde tes vêtements à ces sneakers';

  @override
  String get sneakerResultHeroKicker => 'La combi · Contraste';

  @override
  String get sneakerTagZapas => 'baskets';

  @override
  String get sneakerTagRopa => 'fringues';

  @override
  String sneakerTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String sneakerCaptionLead(String complement, String base) {
    return 'Combo $complement + $base : tes sneakers claquent direct.';
  }

  @override
  String sneakerCaptionRest(String neutral1, String neutral2) {
    return ' Ajoute du $neutral1 ou du $neutral2 et c’est propre.';
  }

  @override
  String sneakerBaseBadge(String color) {
    return 'Base · $color';
  }

  @override
  String get sneakerBaseDescPre => 'La ';

  @override
  String get sneakerBaseDescBold => 'palette de tes sneakers';

  @override
  String sneakerBaseDescRest(String color) {
    return '. Le ton $color mène la combi.';
  }

  @override
  String get sneakerSectionTitle => 'D’autres combis';

  @override
  String get sneakerSectionSub =>
      'Touche une combi et mate des looks réels avec ces couleurs.';

  @override
  String get sneakerHarmonyAnalogousName => 'Ton sur ton';

  @override
  String get sneakerHarmonyAnalogousSub => 'Chaud, tout en douceur';

  @override
  String get sneakerHarmonyTriadicName => 'Équilibrée';

  @override
  String get sneakerHarmonyTriadicSub => '3 couleurs, osée';

  @override
  String get sneakerHarmonySplitName => 'Contraste avec nuance';

  @override
  String get sneakerHarmonySplitSub => 'Du punch, plus fin';

  @override
  String get sneakerResultCtaPrimary => 'Montre-moi d’autres fits';

  @override
  String get sneakerResultCtaSecondary => 'D’autres sneakers';

  @override
  String get sneakerCanvasKicker => 'La combi · Toile';

  @override
  String get sneakerCanvasCaptionLead => 'Sneakers neutres = toile totale.';

  @override
  String get sneakerCanvasCaptionRest =>
      ' N’importe lequel de ces cinq pops leur va de luxe.';

  @override
  String get sneakerErrorTitle => 'On n’a pas capté les couleurs';

  @override
  String get sneakerErrorBody => 'Essaie avec plus de lumière ou un fond uni.';

  @override
  String get sneakerErrorCta => 'Une autre photo';

  @override
  String get settingsTooltip => 'Réglages';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsTelemetryTitle => 'Stats d’usage anonymes';

  @override
  String get settingsTelemetryBody =>
      'Elles nous aident à améliorer l’app. Elles sont anonymes : jamais tes photos, tes données perso ni rien qui t’identifie. Si tu les désactives, on n’envoie plus rien.';

  @override
  String get telemetryNoticeTitle => 'C’est à toi';

  @override
  String get telemetryNoticeBody1Strong => 'Ta photo ne quitte pas ton tel.';

  @override
  String get telemetryNoticeBody1Rest =>
      'L’analyse des couleurs se fait ici même, sans connexion, sans compte.';

  @override
  String get telemetryNoticeBody2Intro =>
      'Pour améliorer l’app, on envoie quelques stats d’usage anonymes (par exemple, la fréquence des analyses).';

  @override
  String get telemetryNoticeBody2Strong =>
      'Pas de photos, pas de données perso, rien qui t’identifie.';

  @override
  String get telemetryNoticeBody2Rest =>
      'Tu peux désactiver ça quand tu veux dans les Réglages.';

  @override
  String get telemetryNoticeCta => 'Compris';

  @override
  String get telemetryNoticeLink => 'Comment on traite les données';

  @override
  String get recolorCta => 'Voir sur moi';

  @override
  String get recolorHeadline => 'Ça donnerait ça';

  @override
  String recolorKicker(String region, String color) {
    return '$region · $color';
  }

  @override
  String get recolorExpectation =>
      'Seule la couleur change : c’est toujours ta pièce.';

  @override
  String get recolorHoldHint => 'Maintiens pour voir l’original';

  @override
  String get recolorHoldActive => 'Original';

  @override
  String get recolorTipPeople =>
      'Pour voir la couleur sur toi, sois seul sur la photo.';

  @override
  String get recolorTipLight =>
      'Pour voir la couleur sur toi, il faut plus de lumière.';

  @override
  String get recolorTipCoverage =>
      'Pour voir la couleur sur toi, montre tout ton fit.';

  @override
  String get recolorFailedSnack => 'Impossible d’essayer la couleur. Réessaie.';

  @override
  String get recolorPreviewLabel => 'Ta photo avec la couleur de la combi';

  @override
  String resultComboKicker(String scheme) {
    return 'La combi · $scheme';
  }
}
