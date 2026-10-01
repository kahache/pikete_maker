import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh')
  ];

  /// No description provided for @homeTutorialTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cómo hacer la foto'**
  String get homeTutorialTooltip;

  /// No description provided for @homeSneakerLabel.
  ///
  /// In es, this message translates to:
  /// **'Mis zapas'**
  String get homeSneakerLabel;

  /// No description provided for @homeSneakerCaption.
  ///
  /// In es, this message translates to:
  /// **'Monta el fit desde tus zapas'**
  String get homeSneakerCaption;

  /// Home bottom zone label — D27 amendment to D26 ('Mi fit' → 'Mi pikete'). Voice-adapt per market, never translate literally.
  ///
  /// In es, this message translates to:
  /// **'Mi pikete'**
  String get homeOutfitLabel;

  /// No description provided for @homeOutfitCaption.
  ///
  /// In es, this message translates to:
  /// **'Saca la paleta de tu fit'**
  String get homeOutfitCaption;

  /// No description provided for @homeGoPill.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get homeGoPill;

  /// No description provided for @onbSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get onbSkip;

  /// No description provided for @onbWelcomeHeadline.
  ///
  /// In es, this message translates to:
  /// **'Los colores de tu fit,\ncon criterio.'**
  String get onbWelcomeHeadline;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In es, this message translates to:
  /// **'Hazte una foto y te digo tu paleta y con qué combina.'**
  String get onbWelcomeBody;

  /// No description provided for @onbWelcomeCta.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get onbWelcomeCta;

  /// First-run privacy reassurance shown up front on ONB-1 (#95, CEO). Two promises: the photo stays on-device AND is not stored. Voice-adapt per market; do NOT add any telemetry/analytics-consent claim here (that lands with #96).
  ///
  /// In es, this message translates to:
  /// **'Tu foto no sale de tu móvil y no la guardamos.'**
  String get onbWelcomePrivacy;

  /// No description provided for @onbTipBadge.
  ///
  /// In es, this message translates to:
  /// **'TIP PRO'**
  String get onbTipBadge;

  /// No description provided for @onbTipHeadline.
  ///
  /// In es, this message translates to:
  /// **'El truco para\nclavar los colores'**
  String get onbTipHeadline;

  /// No description provided for @onbTipPhraseWall.
  ///
  /// In es, this message translates to:
  /// **'Ponte frente a una pared lisa de un solo color.'**
  String get onbTipPhraseWall;

  /// No description provided for @onbTipPhraseFullFit.
  ///
  /// In es, this message translates to:
  /// **'Que se te vea el fit entero, de arriba abajo.'**
  String get onbTipPhraseFullFit;

  /// No description provided for @onbTipPhraseLight.
  ///
  /// In es, this message translates to:
  /// **'Un paso atrás y con buena luz.'**
  String get onbTipPhraseLight;

  /// No description provided for @onbTipCaption.
  ///
  /// In es, this message translates to:
  /// **'Cuanto más liso el fondo, mejor te leo los colores.'**
  String get onbTipCaption;

  /// No description provided for @onbTipCta.
  ///
  /// In es, this message translates to:
  /// **'Hacer mi primera foto'**
  String get onbTipCta;

  /// No description provided for @onbExampleGood.
  ///
  /// In es, this message translates to:
  /// **'BIEN'**
  String get onbExampleGood;

  /// No description provided for @onbExampleBad.
  ///
  /// In es, this message translates to:
  /// **'MAL'**
  String get onbExampleBad;

  /// No description provided for @onbIllustrationGood.
  ///
  /// In es, this message translates to:
  /// **'Foto bien hecha: cuerpo entero frente a una pared lisa'**
  String get onbIllustrationGood;

  /// No description provided for @onbIllustrationBad.
  ///
  /// In es, this message translates to:
  /// **'Foto mal hecha: la misma figura en un cuarto recargado'**
  String get onbIllustrationBad;

  /// No description provided for @privacyNote.
  ///
  /// In es, this message translates to:
  /// **'Tu foto no sale del móvil: se analiza aquí mismo.'**
  String get privacyNote;

  /// No description provided for @sheetCameraTitle.
  ///
  /// In es, this message translates to:
  /// **'Hacer una foto'**
  String get sheetCameraTitle;

  /// No description provided for @sheetGalleryTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get sheetGalleryTitle;

  /// No description provided for @sheetPlainBgHint.
  ///
  /// In es, this message translates to:
  /// **'Fondo liso = colores más finos.'**
  String get sheetPlainBgHint;

  /// No description provided for @outfitSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'¿De dónde sacamos la foto?'**
  String get outfitSheetTitle;

  /// No description provided for @outfitSheetCameraCaption.
  ///
  /// In es, this message translates to:
  /// **'Cuerpo entero, fondo liso'**
  String get outfitSheetCameraCaption;

  /// No description provided for @outfitSheetGalleryCaption.
  ///
  /// In es, this message translates to:
  /// **'Una que ya tengas'**
  String get outfitSheetGalleryCaption;

  /// No description provided for @outfitConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Se ve bien tu fit?'**
  String get outfitConfirmTitle;

  /// No description provided for @outfitConfirmHint.
  ///
  /// In es, this message translates to:
  /// **'Fondo liso = colores más finos.'**
  String get outfitConfirmHint;

  /// No description provided for @outfitConfirmCtaPrimary.
  ///
  /// In es, this message translates to:
  /// **'Analizar'**
  String get outfitConfirmCtaPrimary;

  /// No description provided for @outfitConfirmCtaSecondary.
  ///
  /// In es, this message translates to:
  /// **'Repetir'**
  String get outfitConfirmCtaSecondary;

  /// No description provided for @outfitAnalyzingHeadline.
  ///
  /// In es, this message translates to:
  /// **'Leyendo los colores de tu fit…'**
  String get outfitAnalyzingHeadline;

  /// No description provided for @outfitAnalyzingStep1.
  ///
  /// In es, this message translates to:
  /// **'Leyendo tu foto'**
  String get outfitAnalyzingStep1;

  /// No description provided for @outfitAnalyzingStep2.
  ///
  /// In es, this message translates to:
  /// **'Agrupando los colores'**
  String get outfitAnalyzingStep2;

  /// No description provided for @outfitAnalyzingStep3.
  ///
  /// In es, this message translates to:
  /// **'Montando tus armonías'**
  String get outfitAnalyzingStep3;

  /// No description provided for @outfitAnalyzingSkipNotePrefix.
  ///
  /// In es, this message translates to:
  /// **'Tu paleta aparece en cuanto termine — '**
  String get outfitAnalyzingSkipNotePrefix;

  /// No description provided for @analyzingMonoLabel.
  ///
  /// In es, this message translates to:
  /// **'analizando'**
  String get analyzingMonoLabel;

  /// No description provided for @analyzingSkipNoteAccent.
  ///
  /// In es, this message translates to:
  /// **'ya casi'**
  String get analyzingSkipNoteAccent;

  /// No description provided for @adSlotTipBadge.
  ///
  /// In es, this message translates to:
  /// **'TIP'**
  String get adSlotTipBadge;

  /// No description provided for @adSlotAdCaption.
  ///
  /// In es, this message translates to:
  /// **'El progreso queda siempre visible arriba: el ad acompaña la espera, no la bloquea.'**
  String get adSlotAdCaption;

  /// No description provided for @adSlotTipCaption.
  ///
  /// In es, this message translates to:
  /// **'Fondo liso y un paso atrás: así te clavo los colores.'**
  String get adSlotTipCaption;

  /// No description provided for @feedbackCameraHeadline.
  ///
  /// In es, this message translates to:
  /// **'Sin cámara no hay fit.'**
  String get feedbackCameraHeadline;

  /// No description provided for @feedbackCameraDetail.
  ///
  /// In es, this message translates to:
  /// **'Actívala en ajustes o elige una foto de tu galería.'**
  String get feedbackCameraDetail;

  /// No description provided for @feedbackCameraCtaPrimary.
  ///
  /// In es, this message translates to:
  /// **'Cómo activarla'**
  String get feedbackCameraCtaPrimary;

  /// No description provided for @feedbackCameraCtaSecondary.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get feedbackCameraCtaSecondary;

  /// No description provided for @feedbackCameraSettingsPath.
  ///
  /// In es, this message translates to:
  /// **'Ajustes del sistema → Apps → PiketeMaker → Permisos → Cámara.'**
  String get feedbackCameraSettingsPath;

  /// No description provided for @feedbackFailedHeadline.
  ///
  /// In es, this message translates to:
  /// **'No pillamos bien tu fit.'**
  String get feedbackFailedHeadline;

  /// No description provided for @feedbackFailedDetail.
  ///
  /// In es, this message translates to:
  /// **'Prueba con más luz o aléjate un paso.'**
  String get feedbackFailedDetail;

  /// No description provided for @feedbackFailedCtaPrimary.
  ///
  /// In es, this message translates to:
  /// **'Probar con otra foto'**
  String get feedbackFailedCtaPrimary;

  /// No description provided for @feedbackFailedCtaSecondary.
  ///
  /// In es, this message translates to:
  /// **'Reintentar con la misma'**
  String get feedbackFailedCtaSecondary;

  /// No description provided for @feedbackNoOutfitHeadline.
  ///
  /// In es, this message translates to:
  /// **'Aquí no vemos un outfit claro.'**
  String get feedbackNoOutfitHeadline;

  /// No description provided for @feedbackNoOutfitDetail.
  ///
  /// In es, this message translates to:
  /// **'Cuerpo entero, buena luz y fondo tranquilo.'**
  String get feedbackNoOutfitDetail;

  /// No description provided for @feedbackNoOutfitCtaPrimary.
  ///
  /// In es, this message translates to:
  /// **'Hacer otra foto'**
  String get feedbackNoOutfitCtaPrimary;

  /// No description provided for @feedbackNoOutfitCtaSecondary.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get feedbackNoOutfitCtaSecondary;

  /// No description provided for @resultHeadlineLegacy.
  ///
  /// In es, this message translates to:
  /// **'Tu paleta'**
  String get resultHeadlineLegacy;

  /// No description provided for @resultHeadlineGarments.
  ///
  /// In es, this message translates to:
  /// **'Tu pikete'**
  String get resultHeadlineGarments;

  /// Share-canvas meta line. {date} arrives pre-formatted by localizedShortDate() — NOT an intl DateFormat (es must stay byte-identical: '14 jul 2026').
  ///
  /// In es, this message translates to:
  /// **'Fit de hoy · {date}'**
  String resultMeta(String date);

  /// No description provided for @resultBaseBadge.
  ///
  /// In es, this message translates to:
  /// **'BASE'**
  String get resultBaseBadge;

  /// No description provided for @resultBaseLead.
  ///
  /// In es, this message translates to:
  /// **'Tu color dominante. '**
  String get resultBaseLead;

  /// No description provided for @resultBaseAttributionUpper.
  ///
  /// In es, this message translates to:
  /// **'Sale de tu parte de arriba. '**
  String get resultBaseAttributionUpper;

  /// No description provided for @resultBaseAttributionLower.
  ///
  /// In es, this message translates to:
  /// **'Sale de tu parte de abajo. '**
  String get resultBaseAttributionLower;

  /// No description provided for @resultBaseRest.
  ///
  /// In es, this message translates to:
  /// **'Todo conjunta alrededor de él.'**
  String get resultBaseRest;

  /// No description provided for @garmentUpperLabel.
  ///
  /// In es, this message translates to:
  /// **'ARRIBA'**
  String get garmentUpperLabel;

  /// No description provided for @garmentLowerLabel.
  ///
  /// In es, this message translates to:
  /// **'ABAJO'**
  String get garmentLowerLabel;

  /// No description provided for @garmentSingleLabel.
  ///
  /// In es, this message translates to:
  /// **'TU ROPA'**
  String get garmentSingleLabel;

  /// D36 (2026-07-23) recommendation-first outfit result H1 (chromatic). Replaces the extraction-led headline: the color RECOMMENDATION is now the hero, the extracted palette is demoted. Keeps 'pikete' (brand equity, Home 'Mi pikete'). Voice-adapt per market, never translate literally.
  ///
  /// In es, this message translates to:
  /// **'Toma tu pikete'**
  String get resultRecoHeadline;

  /// Kicker above the hero combo band (D36). The hero scheme is always the complementary → 'Contraste'. Mirrors sneakerResultHeroKicker.
  ///
  /// In es, this message translates to:
  /// **'La combi · Contraste'**
  String get resultHeroKicker;

  /// Role micro-label on the hero combo's BASE segment (D36): the outfit's dominant color.
  ///
  /// In es, this message translates to:
  /// **'tu fit'**
  String get resultTagFit;

  /// Imperative role micro-label on the hero combo's complement segment (D36): the color to ADD (cap/jacket/kicks). The imperative verb communicates a recommendation, not an extraction.
  ///
  /// In es, this message translates to:
  /// **'súmale'**
  String get resultTagAdd;

  /// Role micro-label on the hero combo's neutral segment (D36). Mirrors sneakerTagNeutral.
  ///
  /// In es, this message translates to:
  /// **'+ {neutral}'**
  String resultTagNeutral(String neutral);

  /// Hero caption lead (styled 600 textPrimary, D36). {complement}/{base} are localized color names from color_names.dart.
  ///
  /// In es, this message translates to:
  /// **'El {complement} hace saltar el {base} de tu fit.'**
  String resultCaptionLead(String complement, String base);

  /// Hero caption tail after the bold lead (D36). Mirrors sneakerCaptionRest.
  ///
  /// In es, this message translates to:
  /// **' Súmale {neutral1} o {neutral2} y vas fino.'**
  String resultCaptionRest(String neutral1, String neutral2);

  /// Section label of the DEMOTED extracted palette (D36): the ARRIBA/ABAJO strips are now evidence, not the headline. CEO wording (2026-07-23): the hero is 'pikete', the small extracted palette is 'tu fit'.
  ///
  /// In es, this message translates to:
  /// **'Tu fit · de aquí sale la combi'**
  String get resultPaletteLabel;

  /// Section label of the demoted neutral palette in canvas mode (D36).
  ///
  /// In es, this message translates to:
  /// **'Tu fit · tu lienzo neutro'**
  String get resultPaletteLabelCanvas;

  /// D36 canvas-mode H1 (100% neutral outfit). Slang; replaces 'Tu look es un lienzo'. The curated accent pops ARE the recommendation and move to the hero position. Voice-adapt per market.
  ///
  /// In es, this message translates to:
  /// **'Tu fit pide color'**
  String get resultCanvasHeadline;

  /// Kicker above the curated pops when the outfit is 100% neutral (D36). Mirrors sneakerCanvasKicker.
  ///
  /// In es, this message translates to:
  /// **'La combi · Lienzo'**
  String get resultCanvasKicker;

  /// Caption under the demoted neutral palette in canvas mode (D36): honest explanation of why we propose color pops instead of harmonies.
  ///
  /// In es, this message translates to:
  /// **'Todo tu fit es neutro — combina con todo. Por eso mandamos color, no armonías.'**
  String get resultCanvasBaseCap;

  /// No description provided for @harmoniesTitle.
  ///
  /// In es, this message translates to:
  /// **'Combina con'**
  String get harmoniesTitle;

  /// No description provided for @harmoniesSub.
  ///
  /// In es, this message translates to:
  /// **'Toca una y mira looks reales con esos colores.'**
  String get harmoniesSub;

  /// No description provided for @canvasTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu look es un lienzo'**
  String get canvasTitle;

  /// No description provided for @canvasBody.
  ///
  /// In es, this message translates to:
  /// **'Negro, blanco y grises combinan con todo. Dale un toque de color con uno de estos:'**
  String get canvasBody;

  /// No description provided for @resultCtaLooks.
  ///
  /// In es, this message translates to:
  /// **'Ver looks así'**
  String get resultCtaLooks;

  /// No description provided for @resultCtaStory.
  ///
  /// In es, this message translates to:
  /// **'Súbela a tu story'**
  String get resultCtaStory;

  /// No description provided for @storyFailedSnack.
  ///
  /// In es, this message translates to:
  /// **'No se pudo generar la story. Prueba otra vez.'**
  String get storyFailedSnack;

  /// N1 preview sheet (outfit + sneaker): label of the switch that puts the user's own uploaded photo in the shared 9:16 story. Default ON. Keep it first person and short (one line at 390 dp next to a switch).
  ///
  /// In es, this message translates to:
  /// **'Incluir mi foto'**
  String get storyIncludePhoto;

  /// N1 preview sheet: privacy line under the switch. Must stay literally true: the photo only leaves the device through the user's own OS share. Echoes onbWelcomePrivacy / privacyNote ('Tu foto no sale del móvil'). Keep 'del móvil': a bare 'sale' would read as 'appears (in the story)'.
  ///
  /// In es, this message translates to:
  /// **'Tu foto solo sale del móvil si tú la compartes.'**
  String get storyPhotoPrivacy;

  /// N1 preview sheet: primary CTA that opens the OS share sheet with the previewed image.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get storyShareCta;

  /// N1 preview sheet: accessibility (semantics) label of the preview image. Not visible.
  ///
  /// In es, this message translates to:
  /// **'Vista previa de tu story'**
  String get storyPreviewLabel;

  /// No description provided for @looksSearchFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir el navegador. Revisa tu conexión y prueba otra vez.'**
  String get looksSearchFailed;

  /// No description provided for @harmonyComplementaryName.
  ///
  /// In es, this message translates to:
  /// **'Complementario'**
  String get harmonyComplementaryName;

  /// No description provided for @harmonyComplementaryDesc.
  ///
  /// In es, this message translates to:
  /// **'Contraste máximo, 2 colores'**
  String get harmonyComplementaryDesc;

  /// No description provided for @harmonyAnalogousName.
  ///
  /// In es, this message translates to:
  /// **'Análogo'**
  String get harmonyAnalogousName;

  /// No description provided for @harmonyAnalogousDesc.
  ///
  /// In es, this message translates to:
  /// **'Suave, tono sobre tono'**
  String get harmonyAnalogousDesc;

  /// No description provided for @harmonyTriadicName.
  ///
  /// In es, this message translates to:
  /// **'Triádico'**
  String get harmonyTriadicName;

  /// No description provided for @harmonyTriadicDesc.
  ///
  /// In es, this message translates to:
  /// **'Equilibrado, 3 colores'**
  String get harmonyTriadicDesc;

  /// No description provided for @harmonySplitName.
  ///
  /// In es, this message translates to:
  /// **'Complementario dividido'**
  String get harmonySplitName;

  /// No description provided for @harmonySplitDesc.
  ///
  /// In es, this message translates to:
  /// **'Contraste con matiz'**
  String get harmonySplitDesc;

  /// No description provided for @sneakerAppBarKicker.
  ///
  /// In es, this message translates to:
  /// **'MIS ZAPAS'**
  String get sneakerAppBarKicker;

  /// No description provided for @sneakerSourceTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Desde dónde haces la foto?'**
  String get sneakerSourceTitle;

  /// No description provided for @sneakerSourceSub.
  ///
  /// In es, this message translates to:
  /// **'Cada sitio tiene su truco. Elige el tuyo.'**
  String get sneakerSourceSub;

  /// No description provided for @sneakerSourceCasaTitle.
  ///
  /// In es, this message translates to:
  /// **'Casa o calle'**
  String get sneakerSourceCasaTitle;

  /// No description provided for @sneakerSourceCasaHint.
  ///
  /// In es, this message translates to:
  /// **'Las zapas, en el centro y llenando la foto'**
  String get sneakerSourceCasaHint;

  /// No description provided for @sneakerSourceTiendaTitle.
  ///
  /// In es, this message translates to:
  /// **'En una tienda'**
  String get sneakerSourceTiendaTitle;

  /// No description provided for @sneakerSourceTiendaHint.
  ///
  /// In es, this message translates to:
  /// **'Ponlas en el suelo, como si fueran tuyas'**
  String get sneakerSourceTiendaHint;

  /// No description provided for @sneakerSourceWebTitle.
  ///
  /// In es, this message translates to:
  /// **'Captura de pantalla'**
  String get sneakerSourceWebTitle;

  /// No description provided for @sneakerSourceWebHint.
  ///
  /// In es, this message translates to:
  /// **'Recórtala hasta dejar solo la zapa'**
  String get sneakerSourceWebHint;

  /// No description provided for @sneakerTipBadge.
  ///
  /// In es, this message translates to:
  /// **'EL TRUCO'**
  String get sneakerTipBadge;

  /// No description provided for @sneakerTipCasaTitle.
  ///
  /// In es, this message translates to:
  /// **'Zapas en el centro, llenando la foto'**
  String get sneakerTipCasaTitle;

  /// No description provided for @sneakerTipCasaBody.
  ///
  /// In es, this message translates to:
  /// **'Acércate hasta que las zapas ocupen casi toda la pantalla. Fondo liso (suelo o pared) y buena luz.'**
  String get sneakerTipCasaBody;

  /// No description provided for @sneakerTipCasaCta.
  ///
  /// In es, this message translates to:
  /// **'Hacer la foto'**
  String get sneakerTipCasaCta;

  /// No description provided for @sneakerTipTiendaTitle.
  ///
  /// In es, this message translates to:
  /// **'Ponlas en el suelo, como tuyas'**
  String get sneakerTipTiendaTitle;

  /// No description provided for @sneakerTipTiendaBody.
  ///
  /// In es, this message translates to:
  /// **'Baja las zapas al suelo y dispara desde arriba, como si ya fueran tuyas. Así el fondo no se cuela en los colores.'**
  String get sneakerTipTiendaBody;

  /// No description provided for @sneakerTipTiendaCta.
  ///
  /// In es, this message translates to:
  /// **'Hacer la foto'**
  String get sneakerTipTiendaCta;

  /// No description provided for @sneakerTipWebTitle.
  ///
  /// In es, this message translates to:
  /// **'Recorta hasta dejar solo la zapa'**
  String get sneakerTipWebTitle;

  /// No description provided for @sneakerTipWebBody.
  ///
  /// In es, this message translates to:
  /// **'Antes de subirla, recorta la captura: fuera el navegador, el precio y todo lo blanco. Solo la zapa.'**
  String get sneakerTipWebBody;

  /// No description provided for @sneakerTipWebCta.
  ///
  /// In es, this message translates to:
  /// **'Elegir la captura'**
  String get sneakerTipWebCta;

  /// No description provided for @sneakerIllustrationCasa.
  ///
  /// In es, this message translates to:
  /// **'Zapa grande centrada que casi toca las esquinas del cuadro'**
  String get sneakerIllustrationCasa;

  /// No description provided for @sneakerIllustrationTienda.
  ///
  /// In es, this message translates to:
  /// **'Zapa en el suelo y un móvil disparando desde arriba'**
  String get sneakerIllustrationTienda;

  /// No description provided for @sneakerIllustrationWeb.
  ///
  /// In es, this message translates to:
  /// **'Ventana de navegador con una zapa pequeña y un recorte que deja solo la zapa'**
  String get sneakerIllustrationWeb;

  /// No description provided for @sneakerSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'¿De dónde sacamos las zapas?'**
  String get sneakerSheetTitle;

  /// No description provided for @sneakerSheetCameraCaption.
  ///
  /// In es, this message translates to:
  /// **'Las zapas, fondo liso'**
  String get sneakerSheetCameraCaption;

  /// No description provided for @sneakerSheetGalleryCaption.
  ///
  /// In es, this message translates to:
  /// **'Una que ya tengas'**
  String get sneakerSheetGalleryCaption;

  /// No description provided for @sneakerConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Se ven bien tus zapas?'**
  String get sneakerConfirmTitle;

  /// No description provided for @sneakerConfirmHint.
  ///
  /// In es, this message translates to:
  /// **'Fondo liso y bien iluminadas = colores más finos.'**
  String get sneakerConfirmHint;

  /// No description provided for @sneakerConfirmCtaPrimary.
  ///
  /// In es, this message translates to:
  /// **'Dame el pikete'**
  String get sneakerConfirmCtaPrimary;

  /// No description provided for @sneakerConfirmCtaSecondary.
  ///
  /// In es, this message translates to:
  /// **'Otra foto'**
  String get sneakerConfirmCtaSecondary;

  /// No description provided for @sneakerAnalyzingHeadline.
  ///
  /// In es, this message translates to:
  /// **'Sacando los colores de tus zapas…'**
  String get sneakerAnalyzingHeadline;

  /// No description provided for @sneakerAnalyzingStep.
  ///
  /// In es, this message translates to:
  /// **'Aislando las zapas del fondo'**
  String get sneakerAnalyzingStep;

  /// No description provided for @sneakerAnalyzingSkipNotePrefix.
  ///
  /// In es, this message translates to:
  /// **'Tu combi aparece en cuanto termine — '**
  String get sneakerAnalyzingSkipNotePrefix;

  /// No description provided for @sneakerResultMeta.
  ///
  /// In es, this message translates to:
  /// **'Tus zapas · {date}'**
  String sneakerResultMeta(String date);

  /// No description provided for @sneakerResultTitle.
  ///
  /// In es, this message translates to:
  /// **'Combina tu ropa con estas zapas'**
  String get sneakerResultTitle;

  /// No description provided for @sneakerResultHeroKicker.
  ///
  /// In es, this message translates to:
  /// **'La combi · Contraste'**
  String get sneakerResultHeroKicker;

  /// No description provided for @sneakerTagZapas.
  ///
  /// In es, this message translates to:
  /// **'tus zapas'**
  String get sneakerTagZapas;

  /// No description provided for @sneakerTagRopa.
  ///
  /// In es, this message translates to:
  /// **'tu ropa'**
  String get sneakerTagRopa;

  /// No description provided for @sneakerTagNeutral.
  ///
  /// In es, this message translates to:
  /// **'+ {neutral}'**
  String sneakerTagNeutral(String neutral);

  /// Hero caption lead (styled 600 textPrimary). {complement}/{base} are localized color names from color_names.dart.
  ///
  /// In es, this message translates to:
  /// **'El {complement} hace saltar el {base} de tus zapas.'**
  String sneakerCaptionLead(String complement, String base);

  /// No description provided for @sneakerCaptionRest.
  ///
  /// In es, this message translates to:
  /// **' Súmale {neutral1} o {neutral2} y vas fino.'**
  String sneakerCaptionRest(String neutral1, String neutral2);

  /// Label style; the widget applies .toUpperCase().
  ///
  /// In es, this message translates to:
  /// **'Base · {color}'**
  String sneakerBaseBadge(String color);

  /// No description provided for @sneakerBaseDescPre.
  ///
  /// In es, this message translates to:
  /// **'La '**
  String get sneakerBaseDescPre;

  /// No description provided for @sneakerBaseDescBold.
  ///
  /// In es, this message translates to:
  /// **'paleta de tus zapas'**
  String get sneakerBaseDescBold;

  /// Rich-text tail after the bold span; pre+bold+rest must compose into one grammatical sentence per locale.
  ///
  /// In es, this message translates to:
  /// **'. El {color} manda la combi.'**
  String sneakerBaseDescRest(String color);

  /// No description provided for @sneakerSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Otras combis'**
  String get sneakerSectionTitle;

  /// No description provided for @sneakerSectionSub.
  ///
  /// In es, this message translates to:
  /// **'Toca una y mira looks reales con esos colores.'**
  String get sneakerSectionSub;

  /// No description provided for @sneakerHarmonyAnalogousName.
  ///
  /// In es, this message translates to:
  /// **'Tono sobre tono'**
  String get sneakerHarmonyAnalogousName;

  /// No description provided for @sneakerHarmonyAnalogousSub.
  ///
  /// In es, this message translates to:
  /// **'Cálidos, suave'**
  String get sneakerHarmonyAnalogousSub;

  /// No description provided for @sneakerHarmonyTriadicName.
  ///
  /// In es, this message translates to:
  /// **'Equilibrada'**
  String get sneakerHarmonyTriadicName;

  /// No description provided for @sneakerHarmonyTriadicSub.
  ///
  /// In es, this message translates to:
  /// **'3 colores, atrevida'**
  String get sneakerHarmonyTriadicSub;

  /// No description provided for @sneakerHarmonySplitName.
  ///
  /// In es, this message translates to:
  /// **'Contraste con matiz'**
  String get sneakerHarmonySplitName;

  /// No description provided for @sneakerHarmonySplitSub.
  ///
  /// In es, this message translates to:
  /// **'Punch, más fino'**
  String get sneakerHarmonySplitSub;

  /// No description provided for @sneakerResultCtaPrimary.
  ///
  /// In es, this message translates to:
  /// **'Enséñame otros piketes'**
  String get sneakerResultCtaPrimary;

  /// No description provided for @sneakerResultCtaSecondary.
  ///
  /// In es, this message translates to:
  /// **'Otras zapas'**
  String get sneakerResultCtaSecondary;

  /// No description provided for @sneakerCanvasKicker.
  ///
  /// In es, this message translates to:
  /// **'La combi · Lienzo'**
  String get sneakerCanvasKicker;

  /// No description provided for @sneakerCanvasCaptionLead.
  ///
  /// In es, this message translates to:
  /// **'Zapas neutras = lienzo total.'**
  String get sneakerCanvasCaptionLead;

  /// No description provided for @sneakerCanvasCaptionRest.
  ///
  /// In es, this message translates to:
  /// **' Cualquiera de estos cinco pops les sienta de lujo.'**
  String get sneakerCanvasCaptionRest;

  /// No description provided for @sneakerErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No hemos pillado los colores'**
  String get sneakerErrorTitle;

  /// No description provided for @sneakerErrorBody.
  ///
  /// In es, this message translates to:
  /// **'Prueba con más luz o con un fondo liso.'**
  String get sneakerErrorBody;

  /// No description provided for @sneakerErrorCta.
  ///
  /// In es, this message translates to:
  /// **'Otra foto'**
  String get sneakerErrorCta;

  /// No description provided for @settingsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTooltip;

  /// Minimal settings surface (D33 telemetry opt-out home, docs/legal/consent-copy-first-run.md §3). Only reachable in telemetry-active builds.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsTelemetryTitle.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas de uso anónimas'**
  String get settingsTelemetryTitle;

  /// Opt-out switch caption, VERBATIM from docs/legal/consent-copy-first-run.md §3 (DRAFT pending lawyer). Must stay literally true: OFF ⇒ queue purged, zero sends.
  ///
  /// In es, this message translates to:
  /// **'Nos ayudan a mejorar la app. Son anónimas: nunca incluyen tus fotos, datos personales ni nada que te identifique. Al desactivarlas, dejamos de enviar nada.'**
  String get settingsTelemetryBody;

  /// First-run telemetry NOTICE (not a consent gate), copy VERBATIM from docs/legal/consent-copy-first-run.md §2 (DRAFT pending lawyer + UX-writer). Split into sentence-level keys so the bold emphasis survives CJK word order.
  ///
  /// In es, this message translates to:
  /// **'Esto es tuyo'**
  String get telemetryNoticeTitle;

  /// No description provided for @telemetryNoticeBody1Strong.
  ///
  /// In es, this message translates to:
  /// **'Tu foto no sale del móvil.'**
  String get telemetryNoticeBody1Strong;

  /// No description provided for @telemetryNoticeBody1Rest.
  ///
  /// In es, this message translates to:
  /// **'El análisis de color ocurre aquí dentro, sin conexión, sin cuenta.'**
  String get telemetryNoticeBody1Rest;

  /// No description provided for @telemetryNoticeBody2Intro.
  ///
  /// In es, this message translates to:
  /// **'Para mejorar la app enviamos algunas estadísticas anónimas de uso (por ejemplo, con qué frecuencia se analiza).'**
  String get telemetryNoticeBody2Intro;

  /// No description provided for @telemetryNoticeBody2Strong.
  ///
  /// In es, this message translates to:
  /// **'Sin fotos, sin datos personales, sin identificarte.'**
  String get telemetryNoticeBody2Strong;

  /// No description provided for @telemetryNoticeBody2Rest.
  ///
  /// In es, this message translates to:
  /// **'Puedes desactivarlo cuando quieras en Ajustes.'**
  String get telemetryNoticeBody2Rest;

  /// No description provided for @telemetryNoticeCta.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get telemetryNoticeCta;

  /// No description provided for @telemetryNoticeLink.
  ///
  /// In es, this message translates to:
  /// **'Cómo tratamos los datos'**
  String get telemetryNoticeLink;

  /// I2 result screen: outlined pill under the recommendation card that opens the recolor view (the user's own photo with one garment region repainted in the hero combo colour). The CEO's own words. One line at 390 dp.
  ///
  /// In es, this message translates to:
  /// **'Vérmelo puesto'**
  String get recolorCta;

  /// I2 recolor view: display headline AND the headline of the story shared from that view. Conditional on purpose (a colour preview, not a promise). One line, scaleDown floor 24 px on the story.
  ///
  /// In es, this message translates to:
  /// **'Así te quedaría'**
  String get recolorHeadline;

  /// I2 recolor view: label-style kicker under the headline. {region} = garmentUpperLabel|garmentLowerLabel (already uppercase), {color} = localized colour name of the applied swatch (color_names.dart). Rendered uppercase by the label style.
  ///
  /// In es, this message translates to:
  /// **'{region} · {color}'**
  String recolorKicker(String region, String color);

  /// I2 recolor view: one caption line under the photo card. Sets expectations (only the colour changes; no garment was swapped; prints stay prints) without apologising. Max 2 lines at 320 dp.
  ///
  /// In es, this message translates to:
  /// **'Solo cambia el color: tu prenda sigue siendo la tuya.'**
  String get recolorExpectation;

  /// I2 recolor view: screen-only chip on the photo (never exported). Affordance of the press-and-hold compare gesture. Rendered uppercase, label style; keep it short.
  ///
  /// In es, this message translates to:
  /// **'Mantén para ver el original'**
  String get recolorHoldHint;

  /// I2 recolor view: the same chip while the finger is down and the original photo is shown.
  ///
  /// In es, this message translates to:
  /// **'Original'**
  String get recolorHoldActive;

  /// I2 result screen, replaces the recolor button when more than one person is detected. A tip, not an error: no blame, no tech words. Same sentence family as the other two tips.
  ///
  /// In es, this message translates to:
  /// **'Para verte el color puesto, sal solo en la foto.'**
  String get recolorTipPeople;

  /// I2 result screen, replaces the recolor button when the scene is too dark for a credible recolor.
  ///
  /// In es, this message translates to:
  /// **'Para verte el color puesto, hace falta más luz.'**
  String get recolorTipLight;

  /// I2 result screen, replaces the recolor button when neither region mask is reliable enough (too small, holes, disconnected). Suggests a full-body photo without saying 'mask'.
  ///
  /// In es, this message translates to:
  /// **'Para verte el color puesto, que se vea tu fit entero.'**
  String get recolorTipCoverage;

  /// I2 defensive fallback when the recolor transform fails at runtime. Mirrors storyFailedSnack. Stays on the result screen.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido probar el color. Prueba otra vez.'**
  String get recolorFailedSnack;

  /// I2 recolor view: accessibility (semantics) label of the recolored photo card. Not visible.
  ///
  /// In es, this message translates to:
  /// **'Tu foto con el color de la combi'**
  String get recolorPreviewLabel;

  /// D39: kicker above the hero band when the user selected an 'Otras combis' row (the band swaps to that combo). {scheme} = that row's own name (sneakerHarmony*Name). Same prefix as resultHeroKicker; the hero (no selection) keeps resultHeroKicker.
  ///
  /// In es, this message translates to:
  /// **'La combi · {scheme}'**
  String resultComboKicker(String scheme);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ca',
        'en',
        'es',
        'fr',
        'ja',
        'ko',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
