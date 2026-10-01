// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get homeTutorialTooltip => 'Cómo hacer la foto';

  @override
  String get homeSneakerLabel => 'Mis zapas';

  @override
  String get homeSneakerCaption => 'Monta el fit desde tus zapas';

  @override
  String get homeOutfitLabel => 'Mi pikete';

  @override
  String get homeOutfitCaption => 'Saca la paleta de tu fit';

  @override
  String get homeGoPill => 'Empezar';

  @override
  String get onbSkip => 'Saltar';

  @override
  String get onbWelcomeHeadline => 'Los colores de tu fit,\ncon criterio.';

  @override
  String get onbWelcomeBody =>
      'Hazte una foto y te digo tu paleta y con qué combina.';

  @override
  String get onbWelcomeCta => 'Empezar';

  @override
  String get onbWelcomePrivacy =>
      'Tu foto no sale de tu móvil y no la guardamos.';

  @override
  String get onbTipBadge => 'TIP PRO';

  @override
  String get onbTipHeadline => 'El truco para\nclavar los colores';

  @override
  String get onbTipPhraseWall =>
      'Ponte frente a una pared lisa de un solo color.';

  @override
  String get onbTipPhraseFullFit =>
      'Que se te vea el fit entero, de arriba abajo.';

  @override
  String get onbTipPhraseLight => 'Un paso atrás y con buena luz.';

  @override
  String get onbTipCaption =>
      'Cuanto más liso el fondo, mejor te leo los colores.';

  @override
  String get onbTipCta => 'Hacer mi primera foto';

  @override
  String get onbExampleGood => 'BIEN';

  @override
  String get onbExampleBad => 'MAL';

  @override
  String get onbIllustrationGood =>
      'Foto bien hecha: cuerpo entero frente a una pared lisa';

  @override
  String get onbIllustrationBad =>
      'Foto mal hecha: la misma figura en un cuarto recargado';

  @override
  String get privacyNote => 'Tu foto no sale del móvil: se analiza aquí mismo.';

  @override
  String get sheetCameraTitle => 'Hacer una foto';

  @override
  String get sheetGalleryTitle => 'Elegir de la galería';

  @override
  String get sheetPlainBgHint => 'Fondo liso = colores más finos.';

  @override
  String get outfitSheetTitle => '¿De dónde sacamos la foto?';

  @override
  String get outfitSheetCameraCaption => 'Cuerpo entero, fondo liso';

  @override
  String get outfitSheetGalleryCaption => 'Una que ya tengas';

  @override
  String get outfitConfirmTitle => '¿Se ve bien tu fit?';

  @override
  String get outfitConfirmHint => 'Fondo liso = colores más finos.';

  @override
  String get outfitConfirmCtaPrimary => 'Analizar';

  @override
  String get outfitConfirmCtaSecondary => 'Repetir';

  @override
  String get outfitAnalyzingHeadline => 'Leyendo los colores de tu fit…';

  @override
  String get outfitAnalyzingStep1 => 'Leyendo tu foto';

  @override
  String get outfitAnalyzingStep2 => 'Agrupando los colores';

  @override
  String get outfitAnalyzingStep3 => 'Montando tus armonías';

  @override
  String get outfitAnalyzingSkipNotePrefix =>
      'Tu paleta aparece en cuanto termine — ';

  @override
  String get analyzingMonoLabel => 'analizando';

  @override
  String get analyzingSkipNoteAccent => 'ya casi';

  @override
  String get adSlotTipBadge => 'TIP';

  @override
  String get adSlotAdCaption =>
      'El progreso queda siempre visible arriba: el ad acompaña la espera, no la bloquea.';

  @override
  String get adSlotTipCaption =>
      'Fondo liso y un paso atrás: así te clavo los colores.';

  @override
  String get feedbackCameraHeadline => 'Sin cámara no hay fit.';

  @override
  String get feedbackCameraDetail =>
      'Actívala en ajustes o elige una foto de tu galería.';

  @override
  String get feedbackCameraCtaPrimary => 'Cómo activarla';

  @override
  String get feedbackCameraCtaSecondary => 'Elegir de la galería';

  @override
  String get feedbackCameraSettingsPath =>
      'Ajustes del sistema → Apps → PiketeMaker → Permisos → Cámara.';

  @override
  String get feedbackFailedHeadline => 'No pillamos bien tu fit.';

  @override
  String get feedbackFailedDetail => 'Prueba con más luz o aléjate un paso.';

  @override
  String get feedbackFailedCtaPrimary => 'Probar con otra foto';

  @override
  String get feedbackFailedCtaSecondary => 'Reintentar con la misma';

  @override
  String get feedbackNoOutfitHeadline => 'Aquí no vemos un outfit claro.';

  @override
  String get feedbackNoOutfitDetail =>
      'Cuerpo entero, buena luz y fondo tranquilo.';

  @override
  String get feedbackNoOutfitCtaPrimary => 'Hacer otra foto';

  @override
  String get feedbackNoOutfitCtaSecondary => 'Elegir de la galería';

  @override
  String get resultHeadlineLegacy => 'Tu paleta';

  @override
  String get resultHeadlineGarments => 'Tu pikete';

  @override
  String resultMeta(String date) {
    return 'Fit de hoy · $date';
  }

  @override
  String get resultBaseBadge => 'BASE';

  @override
  String get resultBaseLead => 'Tu color dominante. ';

  @override
  String get resultBaseAttributionUpper => 'Sale de tu parte de arriba. ';

  @override
  String get resultBaseAttributionLower => 'Sale de tu parte de abajo. ';

  @override
  String get resultBaseRest => 'Todo conjunta alrededor de él.';

  @override
  String get garmentUpperLabel => 'ARRIBA';

  @override
  String get garmentLowerLabel => 'ABAJO';

  @override
  String get garmentSingleLabel => 'TU ROPA';

  @override
  String get resultRecoHeadline => 'Toma tu pikete';

  @override
  String get resultHeroKicker => 'La combi · Contraste';

  @override
  String get resultTagFit => 'tu fit';

  @override
  String get resultTagAdd => 'súmale';

  @override
  String resultTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String resultCaptionLead(String complement, String base) {
    return 'El $complement hace saltar el $base de tu fit.';
  }

  @override
  String resultCaptionRest(String neutral1, String neutral2) {
    return ' Súmale $neutral1 o $neutral2 y vas fino.';
  }

  @override
  String get resultPaletteLabel => 'Tu fit · de aquí sale la combi';

  @override
  String get resultPaletteLabelCanvas => 'Tu fit · tu lienzo neutro';

  @override
  String get resultCanvasHeadline => 'Tu fit pide color';

  @override
  String get resultCanvasKicker => 'La combi · Lienzo';

  @override
  String get resultCanvasBaseCap =>
      'Todo tu fit es neutro — combina con todo. Por eso mandamos color, no armonías.';

  @override
  String get harmoniesTitle => 'Combina con';

  @override
  String get harmoniesSub => 'Toca una y mira looks reales con esos colores.';

  @override
  String get canvasTitle => 'Tu look es un lienzo';

  @override
  String get canvasBody =>
      'Negro, blanco y grises combinan con todo. Dale un toque de color con uno de estos:';

  @override
  String get resultCtaLooks => 'Ver looks así';

  @override
  String get resultCtaStory => 'Súbela a tu story';

  @override
  String get storyFailedSnack =>
      'No se pudo generar la story. Prueba otra vez.';

  @override
  String get storyIncludePhoto => 'Incluir mi foto';

  @override
  String get storyPhotoPrivacy =>
      'Tu foto solo sale del móvil si tú la compartes.';

  @override
  String get storyShareCta => 'Compartir';

  @override
  String get storyPreviewLabel => 'Vista previa de tu story';

  @override
  String get looksSearchFailed =>
      'No se ha podido abrir el navegador. Revisa tu conexión y prueba otra vez.';

  @override
  String get harmonyComplementaryName => 'Complementario';

  @override
  String get harmonyComplementaryDesc => 'Contraste máximo, 2 colores';

  @override
  String get harmonyAnalogousName => 'Análogo';

  @override
  String get harmonyAnalogousDesc => 'Suave, tono sobre tono';

  @override
  String get harmonyTriadicName => 'Triádico';

  @override
  String get harmonyTriadicDesc => 'Equilibrado, 3 colores';

  @override
  String get harmonySplitName => 'Complementario dividido';

  @override
  String get harmonySplitDesc => 'Contraste con matiz';

  @override
  String get sneakerAppBarKicker => 'MIS ZAPAS';

  @override
  String get sneakerSourceTitle => '¿Desde dónde haces la foto?';

  @override
  String get sneakerSourceSub => 'Cada sitio tiene su truco. Elige el tuyo.';

  @override
  String get sneakerSourceCasaTitle => 'Casa o calle';

  @override
  String get sneakerSourceCasaHint =>
      'Las zapas, en el centro y llenando la foto';

  @override
  String get sneakerSourceTiendaTitle => 'En una tienda';

  @override
  String get sneakerSourceTiendaHint =>
      'Ponlas en el suelo, como si fueran tuyas';

  @override
  String get sneakerSourceWebTitle => 'Captura de pantalla';

  @override
  String get sneakerSourceWebHint => 'Recórtala hasta dejar solo la zapa';

  @override
  String get sneakerTipBadge => 'EL TRUCO';

  @override
  String get sneakerTipCasaTitle => 'Zapas en el centro, llenando la foto';

  @override
  String get sneakerTipCasaBody =>
      'Acércate hasta que las zapas ocupen casi toda la pantalla. Fondo liso (suelo o pared) y buena luz.';

  @override
  String get sneakerTipCasaCta => 'Hacer la foto';

  @override
  String get sneakerTipTiendaTitle => 'Ponlas en el suelo, como tuyas';

  @override
  String get sneakerTipTiendaBody =>
      'Baja las zapas al suelo y dispara desde arriba, como si ya fueran tuyas. Así el fondo no se cuela en los colores.';

  @override
  String get sneakerTipTiendaCta => 'Hacer la foto';

  @override
  String get sneakerTipWebTitle => 'Recorta hasta dejar solo la zapa';

  @override
  String get sneakerTipWebBody =>
      'Antes de subirla, recorta la captura: fuera el navegador, el precio y todo lo blanco. Solo la zapa.';

  @override
  String get sneakerTipWebCta => 'Elegir la captura';

  @override
  String get sneakerIllustrationCasa =>
      'Zapa grande centrada que casi toca las esquinas del cuadro';

  @override
  String get sneakerIllustrationTienda =>
      'Zapa en el suelo y un móvil disparando desde arriba';

  @override
  String get sneakerIllustrationWeb =>
      'Ventana de navegador con una zapa pequeña y un recorte que deja solo la zapa';

  @override
  String get sneakerSheetTitle => '¿De dónde sacamos las zapas?';

  @override
  String get sneakerSheetCameraCaption => 'Las zapas, fondo liso';

  @override
  String get sneakerSheetGalleryCaption => 'Una que ya tengas';

  @override
  String get sneakerConfirmTitle => '¿Se ven bien tus zapas?';

  @override
  String get sneakerConfirmHint =>
      'Fondo liso y bien iluminadas = colores más finos.';

  @override
  String get sneakerConfirmCtaPrimary => 'Dame el pikete';

  @override
  String get sneakerConfirmCtaSecondary => 'Otra foto';

  @override
  String get sneakerAnalyzingHeadline => 'Sacando los colores de tus zapas…';

  @override
  String get sneakerAnalyzingStep => 'Aislando las zapas del fondo';

  @override
  String get sneakerAnalyzingSkipNotePrefix =>
      'Tu combi aparece en cuanto termine — ';

  @override
  String sneakerResultMeta(String date) {
    return 'Tus zapas · $date';
  }

  @override
  String get sneakerResultTitle => 'Combina tu ropa con estas zapas';

  @override
  String get sneakerResultHeroKicker => 'La combi · Contraste';

  @override
  String get sneakerTagZapas => 'tus zapas';

  @override
  String get sneakerTagRopa => 'tu ropa';

  @override
  String sneakerTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String sneakerCaptionLead(String complement, String base) {
    return 'El $complement hace saltar el $base de tus zapas.';
  }

  @override
  String sneakerCaptionRest(String neutral1, String neutral2) {
    return ' Súmale $neutral1 o $neutral2 y vas fino.';
  }

  @override
  String sneakerBaseBadge(String color) {
    return 'Base · $color';
  }

  @override
  String get sneakerBaseDescPre => 'La ';

  @override
  String get sneakerBaseDescBold => 'paleta de tus zapas';

  @override
  String sneakerBaseDescRest(String color) {
    return '. El $color manda la combi.';
  }

  @override
  String get sneakerSectionTitle => 'Otras combis';

  @override
  String get sneakerSectionSub =>
      'Toca una y mira looks reales con esos colores.';

  @override
  String get sneakerHarmonyAnalogousName => 'Tono sobre tono';

  @override
  String get sneakerHarmonyAnalogousSub => 'Cálidos, suave';

  @override
  String get sneakerHarmonyTriadicName => 'Equilibrada';

  @override
  String get sneakerHarmonyTriadicSub => '3 colores, atrevida';

  @override
  String get sneakerHarmonySplitName => 'Contraste con matiz';

  @override
  String get sneakerHarmonySplitSub => 'Punch, más fino';

  @override
  String get sneakerResultCtaPrimary => 'Enséñame otros piketes';

  @override
  String get sneakerResultCtaSecondary => 'Otras zapas';

  @override
  String get sneakerCanvasKicker => 'La combi · Lienzo';

  @override
  String get sneakerCanvasCaptionLead => 'Zapas neutras = lienzo total.';

  @override
  String get sneakerCanvasCaptionRest =>
      ' Cualquiera de estos cinco pops les sienta de lujo.';

  @override
  String get sneakerErrorTitle => 'No hemos pillado los colores';

  @override
  String get sneakerErrorBody => 'Prueba con más luz o con un fondo liso.';

  @override
  String get sneakerErrorCta => 'Otra foto';

  @override
  String get settingsTooltip => 'Ajustes';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsTelemetryTitle => 'Estadísticas de uso anónimas';

  @override
  String get settingsTelemetryBody =>
      'Nos ayudan a mejorar la app. Son anónimas: nunca incluyen tus fotos, datos personales ni nada que te identifique. Al desactivarlas, dejamos de enviar nada.';

  @override
  String get telemetryNoticeTitle => 'Esto es tuyo';

  @override
  String get telemetryNoticeBody1Strong => 'Tu foto no sale del móvil.';

  @override
  String get telemetryNoticeBody1Rest =>
      'El análisis de color ocurre aquí dentro, sin conexión, sin cuenta.';

  @override
  String get telemetryNoticeBody2Intro =>
      'Para mejorar la app enviamos algunas estadísticas anónimas de uso (por ejemplo, con qué frecuencia se analiza).';

  @override
  String get telemetryNoticeBody2Strong =>
      'Sin fotos, sin datos personales, sin identificarte.';

  @override
  String get telemetryNoticeBody2Rest =>
      'Puedes desactivarlo cuando quieras en Ajustes.';

  @override
  String get telemetryNoticeCta => 'Entendido';

  @override
  String get telemetryNoticeLink => 'Cómo tratamos los datos';

  @override
  String get recolorCta => 'Vérmelo puesto';

  @override
  String get recolorHeadline => 'Así te quedaría';

  @override
  String recolorKicker(String region, String color) {
    return '$region · $color';
  }

  @override
  String get recolorExpectation =>
      'Solo cambia el color: tu prenda sigue siendo la tuya.';

  @override
  String get recolorHoldHint => 'Mantén para ver el original';

  @override
  String get recolorHoldActive => 'Original';

  @override
  String get recolorTipPeople =>
      'Para verte el color puesto, sal solo en la foto.';

  @override
  String get recolorTipLight =>
      'Para verte el color puesto, hace falta más luz.';

  @override
  String get recolorTipCoverage =>
      'Para verte el color puesto, que se vea tu fit entero.';

  @override
  String get recolorFailedSnack =>
      'No hemos podido probar el color. Prueba otra vez.';

  @override
  String get recolorPreviewLabel => 'Tu foto con el color de la combi';

  @override
  String resultComboKicker(String scheme) {
    return 'La combi · $scheme';
  }
}
