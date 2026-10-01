// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeTutorialTooltip => 'How to shoot the pic';

  @override
  String get homeSneakerLabel => 'My kicks';

  @override
  String get homeSneakerCaption => 'Build the fit around your kicks';

  @override
  String get homeOutfitLabel => 'My fit';

  @override
  String get homeOutfitCaption => 'Pull the palette off your fit';

  @override
  String get homeGoPill => 'Start';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbWelcomeHeadline => 'Your fit’s colors,\ndone right.';

  @override
  String get onbWelcomeBody =>
      'Snap a pic and I’ll tell you your palette and what goes with it.';

  @override
  String get onbWelcomeCta => 'Let’s go';

  @override
  String get onbWelcomePrivacy =>
      'Your photo stays on your phone and we don’t store it.';

  @override
  String get onbTipBadge => 'PRO TIP';

  @override
  String get onbTipHeadline => 'The trick to\nnailing your colors';

  @override
  String get onbTipPhraseWall => 'Stand in front of a plain, one-color wall.';

  @override
  String get onbTipPhraseFullFit => 'Get your whole fit in frame, head to toe.';

  @override
  String get onbTipPhraseLight => 'One step back, good light.';

  @override
  String get onbTipCaption =>
      'The plainer the background, the better I read your colors.';

  @override
  String get onbTipCta => 'Shoot my first pic';

  @override
  String get onbExampleGood => 'GOOD';

  @override
  String get onbExampleBad => 'BAD';

  @override
  String get onbIllustrationGood =>
      'A good photo: full body in front of a plain wall';

  @override
  String get onbIllustrationBad =>
      'A bad photo: the same figure in a cluttered room';

  @override
  String get privacyNote =>
      'Your photo never leaves your phone: it’s analyzed right here.';

  @override
  String get sheetCameraTitle => 'Take a photo';

  @override
  String get sheetGalleryTitle => 'Pick from your gallery';

  @override
  String get sheetPlainBgHint => 'Plain background = cleaner colors.';

  @override
  String get outfitSheetTitle => 'Where are we getting the pic?';

  @override
  String get outfitSheetCameraCaption => 'Full body, plain background';

  @override
  String get outfitSheetGalleryCaption => 'One you already have';

  @override
  String get outfitConfirmTitle => 'Your fit looking good?';

  @override
  String get outfitConfirmHint => 'Plain background = cleaner colors.';

  @override
  String get outfitConfirmCtaPrimary => 'Analyze';

  @override
  String get outfitConfirmCtaSecondary => 'Retake';

  @override
  String get outfitAnalyzingHeadline => 'Reading your fit’s colors…';

  @override
  String get outfitAnalyzingStep1 => 'Reading your photo';

  @override
  String get outfitAnalyzingStep2 => 'Grouping the colors';

  @override
  String get outfitAnalyzingStep3 => 'Building your harmonies';

  @override
  String get outfitAnalyzingSkipNotePrefix =>
      'Your palette drops as soon as it’s done — ';

  @override
  String get analyzingMonoLabel => 'analyzing';

  @override
  String get analyzingSkipNoteAccent => 'almost there';

  @override
  String get adSlotTipBadge => 'TIP';

  @override
  String get adSlotAdCaption =>
      'Progress stays visible up top: the ad rides along with the wait, it never blocks it.';

  @override
  String get adSlotTipCaption =>
      'Plain background and a step back: that’s how I nail your colors.';

  @override
  String get feedbackCameraHeadline => 'No camera, no fit.';

  @override
  String get feedbackCameraDetail =>
      'Turn it on in settings or pick a photo from your gallery.';

  @override
  String get feedbackCameraCtaPrimary => 'How to enable it';

  @override
  String get feedbackCameraCtaSecondary => 'Pick from gallery';

  @override
  String get feedbackCameraSettingsPath =>
      'System settings → Apps → PiketeMaker → Permissions → Camera.';

  @override
  String get feedbackFailedHeadline => 'We couldn’t read your fit.';

  @override
  String get feedbackFailedDetail => 'Try more light or take a step back.';

  @override
  String get feedbackFailedCtaPrimary => 'Try another photo';

  @override
  String get feedbackFailedCtaSecondary => 'Retry with this one';

  @override
  String get feedbackNoOutfitHeadline => 'No clear outfit in here.';

  @override
  String get feedbackNoOutfitDetail =>
      'Full body, good light, calm background.';

  @override
  String get feedbackNoOutfitCtaPrimary => 'Take another photo';

  @override
  String get feedbackNoOutfitCtaSecondary => 'Pick from gallery';

  @override
  String get resultHeadlineLegacy => 'Your palette';

  @override
  String get resultHeadlineGarments => 'Your fit';

  @override
  String resultMeta(String date) {
    return 'Today’s fit · $date';
  }

  @override
  String get resultBaseBadge => 'BASE';

  @override
  String get resultBaseLead => 'Your dominant color. ';

  @override
  String get resultBaseAttributionUpper => 'It comes from your top half. ';

  @override
  String get resultBaseAttributionLower => 'It comes from your bottom half. ';

  @override
  String get resultBaseRest => 'The whole look pulls together around it.';

  @override
  String get garmentUpperLabel => 'TOP';

  @override
  String get garmentLowerLabel => 'BOTTOM';

  @override
  String get garmentSingleLabel => 'YOUR CLOTHES';

  @override
  String get resultRecoHeadline => 'Grab your fit';

  @override
  String get resultHeroKicker => 'The combo · Contrast';

  @override
  String get resultTagFit => 'your fit';

  @override
  String get resultTagAdd => 'add it';

  @override
  String resultTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String resultCaptionLead(String complement, String base) {
    return 'The $complement makes the $base in your fit pop.';
  }

  @override
  String resultCaptionRest(String neutral1, String neutral2) {
    return ' Add $neutral1 or $neutral2 and you’re clean.';
  }

  @override
  String get resultPaletteLabel => 'Your fit · the combo comes from here';

  @override
  String get resultPaletteLabelCanvas => 'Your fit · your neutral canvas';

  @override
  String get resultCanvasHeadline => 'Your fit wants color';

  @override
  String get resultCanvasKicker => 'The combo · Canvas';

  @override
  String get resultCanvasBaseCap =>
      'Your whole fit is neutral — it goes with everything. That’s why we send color, not harmonies.';

  @override
  String get harmoniesTitle => 'Goes with';

  @override
  String get harmoniesSub => 'Tap one and see real looks with those colors.';

  @override
  String get canvasTitle => 'Your look is a canvas';

  @override
  String get canvasBody =>
      'Black, white and grays go with everything. Add a pop of color with one of these:';

  @override
  String get resultCtaLooks => 'See looks like this';

  @override
  String get resultCtaStory => 'Drop it on your story';

  @override
  String get storyFailedSnack => 'Couldn’t build the story. Try again.';

  @override
  String get storyIncludePhoto => 'Include my photo';

  @override
  String get storyPhotoPrivacy =>
      'Your photo only leaves your phone if you share it.';

  @override
  String get storyShareCta => 'Share';

  @override
  String get storyPreviewLabel => 'Your story preview';

  @override
  String get looksSearchFailed =>
      'Couldn’t open the browser. Check your connection and try again.';

  @override
  String get harmonyComplementaryName => 'Complementary';

  @override
  String get harmonyComplementaryDesc => 'Max contrast, 2 colors';

  @override
  String get harmonyAnalogousName => 'Analogous';

  @override
  String get harmonyAnalogousDesc => 'Soft, tone on tone';

  @override
  String get harmonyTriadicName => 'Triadic';

  @override
  String get harmonyTriadicDesc => 'Balanced, 3 colors';

  @override
  String get harmonySplitName => 'Split complementary';

  @override
  String get harmonySplitDesc => 'Contrast with a twist';

  @override
  String get sneakerAppBarKicker => 'MY KICKS';

  @override
  String get sneakerSourceTitle => 'Where are you shooting from?';

  @override
  String get sneakerSourceSub => 'Every spot has its trick. Pick yours.';

  @override
  String get sneakerSourceCasaTitle => 'Home or street';

  @override
  String get sneakerSourceCasaHint => 'Kicks centered, filling the frame';

  @override
  String get sneakerSourceTiendaTitle => 'At a store';

  @override
  String get sneakerSourceTiendaHint =>
      'Put them on the floor, like they’re yours';

  @override
  String get sneakerSourceWebTitle => 'Screenshot';

  @override
  String get sneakerSourceWebHint => 'Crop it down to just the shoe';

  @override
  String get sneakerTipBadge => 'THE TRICK';

  @override
  String get sneakerTipCasaTitle => 'Kicks centered, filling the frame';

  @override
  String get sneakerTipCasaBody =>
      'Get close until the kicks fill almost the whole screen. Plain background (floor or wall) and good light.';

  @override
  String get sneakerTipCasaCta => 'Take the photo';

  @override
  String get sneakerTipTiendaTitle => 'Put them on the floor, like yours';

  @override
  String get sneakerTipTiendaBody =>
      'Get the kicks on the floor and shoot from above, like they’re already yours. That way the background stays out of your colors.';

  @override
  String get sneakerTipTiendaCta => 'Take the photo';

  @override
  String get sneakerTipWebTitle => 'Crop until it’s just the shoe';

  @override
  String get sneakerTipWebBody =>
      'Before you upload it, crop the screenshot: no browser, no price tag, none of that white. Just the shoe.';

  @override
  String get sneakerTipWebCta => 'Pick the screenshot';

  @override
  String get sneakerIllustrationCasa =>
      'A big sneaker centered, almost touching the corners of the frame';

  @override
  String get sneakerIllustrationTienda =>
      'A sneaker on the floor with a phone shooting from above';

  @override
  String get sneakerIllustrationWeb =>
      'A browser window with a small sneaker and a crop that leaves just the sneaker';

  @override
  String get sneakerSheetTitle => 'Where are the kicks coming from?';

  @override
  String get sneakerSheetCameraCaption => 'The kicks, plain background';

  @override
  String get sneakerSheetGalleryCaption => 'One you already have';

  @override
  String get sneakerConfirmTitle => 'Your kicks looking right?';

  @override
  String get sneakerConfirmHint =>
      'Plain background and good lighting = cleaner colors.';

  @override
  String get sneakerConfirmCtaPrimary => 'Gimme the drip';

  @override
  String get sneakerConfirmCtaSecondary => 'Another photo';

  @override
  String get sneakerAnalyzingHeadline => 'Pulling the colors off your kicks…';

  @override
  String get sneakerAnalyzingStep => 'Cutting the kicks out of the background';

  @override
  String get sneakerAnalyzingSkipNotePrefix =>
      'Your combo drops as soon as it’s done — ';

  @override
  String sneakerResultMeta(String date) {
    return 'Your kicks · $date';
  }

  @override
  String get sneakerResultTitle => 'Match your clothes to these kicks';

  @override
  String get sneakerResultHeroKicker => 'The combo · Contrast';

  @override
  String get sneakerTagZapas => 'your kicks';

  @override
  String get sneakerTagRopa => 'your fit';

  @override
  String sneakerTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String sneakerCaptionLead(String complement, String base) {
    return 'The $complement makes the $base on your kicks pop.';
  }

  @override
  String sneakerCaptionRest(String neutral1, String neutral2) {
    return ' Add $neutral1 or $neutral2 and you’re clean.';
  }

  @override
  String sneakerBaseBadge(String color) {
    return 'Base · $color';
  }

  @override
  String get sneakerBaseDescPre => 'The ';

  @override
  String get sneakerBaseDescBold => 'palette of your kicks';

  @override
  String sneakerBaseDescRest(String color) {
    return '. The $color runs the combo.';
  }

  @override
  String get sneakerSectionTitle => 'More combos';

  @override
  String get sneakerSectionSub =>
      'Tap one and see real looks with those colors.';

  @override
  String get sneakerHarmonyAnalogousName => 'Tone on tone';

  @override
  String get sneakerHarmonyAnalogousSub => 'Warm, smooth';

  @override
  String get sneakerHarmonyTriadicName => 'Balanced';

  @override
  String get sneakerHarmonyTriadicSub => '3 colors, bold';

  @override
  String get sneakerHarmonySplitName => 'Contrast with a twist';

  @override
  String get sneakerHarmonySplitSub => 'Punch, more refined';

  @override
  String get sneakerResultCtaPrimary => 'Show me more drip';

  @override
  String get sneakerResultCtaSecondary => 'Other kicks';

  @override
  String get sneakerCanvasKicker => 'The combo · Canvas';

  @override
  String get sneakerCanvasCaptionLead => 'Neutral kicks = total canvas.';

  @override
  String get sneakerCanvasCaptionRest =>
      ' Any of these five pops looks fire on them.';

  @override
  String get sneakerErrorTitle => 'We couldn’t catch the colors';

  @override
  String get sneakerErrorBody => 'Try more light or a plain background.';

  @override
  String get sneakerErrorCta => 'Another photo';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTelemetryTitle => 'Anonymous usage stats';

  @override
  String get settingsTelemetryBody =>
      'They help us improve the app. They’re anonymous: never your photos, personal data or anything that identifies you. Turn them off and we stop sending anything.';

  @override
  String get telemetryNoticeTitle => 'This is yours';

  @override
  String get telemetryNoticeBody1Strong =>
      'Your photo never leaves your phone.';

  @override
  String get telemetryNoticeBody1Rest =>
      'The color analysis happens right here — no connection, no account.';

  @override
  String get telemetryNoticeBody2Intro =>
      'To improve the app we send a few anonymous usage stats (for example, how often an analysis runs).';

  @override
  String get telemetryNoticeBody2Strong =>
      'No photos, no personal data, nothing that identifies you.';

  @override
  String get telemetryNoticeBody2Rest =>
      'You can turn it off anytime in Settings.';

  @override
  String get telemetryNoticeCta => 'Got it';

  @override
  String get telemetryNoticeLink => 'How we handle data';

  @override
  String get recolorCta => 'See it on me';

  @override
  String get recolorHeadline => 'How it’d look on you';

  @override
  String recolorKicker(String region, String color) {
    return '$region · $color';
  }

  @override
  String get recolorExpectation =>
      'Only the color changes: it’s still your own piece.';

  @override
  String get recolorHoldHint => 'Hold to see the original';

  @override
  String get recolorHoldActive => 'Original';

  @override
  String get recolorTipPeople =>
      'To see the color on you, be alone in the photo.';

  @override
  String get recolorTipLight => 'To see the color on you, you need more light.';

  @override
  String get recolorTipCoverage =>
      'To see the color on you, show your whole fit.';

  @override
  String get recolorFailedSnack => 'Couldn’t try the color. Try again.';

  @override
  String get recolorPreviewLabel => 'Your photo in the combo color';

  @override
  String resultComboKicker(String scheme) {
    return 'The combo · $scheme';
  }
}
