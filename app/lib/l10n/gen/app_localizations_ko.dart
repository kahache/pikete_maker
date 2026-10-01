// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get homeTutorialTooltip => '사진 찍는 법';

  @override
  String get homeSneakerLabel => '내 신발';

  @override
  String get homeSneakerCaption => '신발에서 시작하는 코디';

  @override
  String get homeOutfitLabel => '내 코디';

  @override
  String get homeOutfitCaption => '내 코디의 컬러 팔레트 뽑기';

  @override
  String get homeGoPill => '시작';

  @override
  String get onbSkip => '건너뛰기';

  @override
  String get onbWelcomeHeadline => '내 코디의 컬러,\n감각 있게.';

  @override
  String get onbWelcomeBody => '사진 한 장이면 팔레트와 어울리는 조합을 알려드려요.';

  @override
  String get onbWelcomeCta => '시작하기';

  @override
  String get onbWelcomePrivacy => '사진은 휴대폰 밖으로 나가지 않고 저장하지도 않아요.';

  @override
  String get onbTipBadge => '프로 팁';

  @override
  String get onbTipHeadline => '컬러를 정확히\n잡는 요령';

  @override
  String get onbTipPhraseWall => '단색의 매끈한 벽 앞에 서세요.';

  @override
  String get onbTipPhraseFullFit => '머리부터 발끝까지 전신이 나오게.';

  @override
  String get onbTipPhraseLight => '한 걸음 뒤로, 조명은 밝게.';

  @override
  String get onbTipCaption => '배경이 깔끔할수록 컬러를 더 정확히 읽어요.';

  @override
  String get onbTipCta => '첫 사진 찍기';

  @override
  String get onbExampleGood => '좋음';

  @override
  String get onbExampleBad => '나쁨';

  @override
  String get onbIllustrationGood => '좋은 예: 매끈한 벽 앞에서 찍은 전신 사진';

  @override
  String get onbIllustrationBad => '나쁜 예: 어수선한 방 안의 같은 인물';

  @override
  String get privacyNote => '사진은 휴대폰 밖으로 나가지 않아요. 이 안에서 바로 분석돼요.';

  @override
  String get sheetCameraTitle => '사진 찍기';

  @override
  String get sheetGalleryTitle => '갤러리에서 선택';

  @override
  String get sheetPlainBgHint => '깔끔한 배경 = 더 정확한 컬러.';

  @override
  String get outfitSheetTitle => '사진은 어디서 가져올까요?';

  @override
  String get outfitSheetCameraCaption => '전신, 깔끔한 배경';

  @override
  String get outfitSheetGalleryCaption => '이미 있는 사진';

  @override
  String get outfitConfirmTitle => '코디가 잘 보이나요?';

  @override
  String get outfitConfirmHint => '깔끔한 배경 = 더 정확한 컬러.';

  @override
  String get outfitConfirmCtaPrimary => '분석하기';

  @override
  String get outfitConfirmCtaSecondary => '다시 찍기';

  @override
  String get outfitAnalyzingHeadline => '코디의 컬러를 읽는 중…';

  @override
  String get outfitAnalyzingStep1 => '사진 읽는 중';

  @override
  String get outfitAnalyzingStep2 => '컬러 묶는 중';

  @override
  String get outfitAnalyzingStep3 => '조합 만드는 중';

  @override
  String get outfitAnalyzingSkipNotePrefix => '끝나면 바로 팔레트가 떠요 — ';

  @override
  String get analyzingMonoLabel => '분석 중';

  @override
  String get analyzingSkipNoteAccent => '거의 다 됐어요';

  @override
  String get adSlotTipBadge => '팁';

  @override
  String get adSlotAdCaption => '진행 상황은 항상 위에 보여요. 광고는 기다림을 함께할 뿐, 흐름을 막지 않아요.';

  @override
  String get adSlotTipCaption => '깔끔한 배경에서 한 걸음 뒤로. 그래야 컬러를 정확히 잡아요.';

  @override
  String get feedbackCameraHeadline => '카메라 없이는 코디도 없어요.';

  @override
  String get feedbackCameraDetail => '설정에서 권한을 켜거나 갤러리에서 사진을 고르세요.';

  @override
  String get feedbackCameraCtaPrimary => '켜는 방법 보기';

  @override
  String get feedbackCameraCtaSecondary => '갤러리에서 선택';

  @override
  String get feedbackCameraSettingsPath =>
      '시스템 설정 → 앱 → PiketeMaker → 권한 → 카메라.';

  @override
  String get feedbackFailedHeadline => '코디를 제대로 읽지 못했어요.';

  @override
  String get feedbackFailedDetail => '더 밝은 곳에서 찍거나 한 걸음 물러나 보세요.';

  @override
  String get feedbackFailedCtaPrimary => '다른 사진으로';

  @override
  String get feedbackFailedCtaSecondary => '같은 사진으로 재시도';

  @override
  String get feedbackNoOutfitHeadline => '여기선 코디가 잘 안 보여요.';

  @override
  String get feedbackNoOutfitDetail => '전신, 좋은 조명, 차분한 배경.';

  @override
  String get feedbackNoOutfitCtaPrimary => '다시 찍기';

  @override
  String get feedbackNoOutfitCtaSecondary => '갤러리에서 선택';

  @override
  String get resultHeadlineLegacy => '내 팔레트';

  @override
  String get resultHeadlineGarments => '내 코디';

  @override
  String resultMeta(String date) {
    return '오늘의 코디 · $date';
  }

  @override
  String get resultBaseBadge => '베이스';

  @override
  String get resultBaseLead => '가장 지배적인 컬러. ';

  @override
  String get resultBaseAttributionUpper => '상의에서 나온 컬러예요. ';

  @override
  String get resultBaseAttributionLower => '하의에서 나온 컬러예요. ';

  @override
  String get resultBaseRest => '모든 조합이 이 컬러를 중심으로 돌아가요.';

  @override
  String get garmentUpperLabel => '상의';

  @override
  String get garmentLowerLabel => '하의';

  @override
  String get garmentSingleLabel => '내 옷';

  @override
  String get resultRecoHeadline => '네 코디 완성';

  @override
  String get resultHeroKicker => '추천 조합 · 대비';

  @override
  String get resultTagFit => '네 코디';

  @override
  String get resultTagAdd => '더해';

  @override
  String resultTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String resultCaptionLead(String complement, String base) {
    return '$complement 컬러가 코디의 $base 컬러를 살려줘요.';
  }

  @override
  String resultCaptionRest(String neutral1, String neutral2) {
    return ' 여기에 $neutral1 또는 $neutral2 컬러를 더하면 깔끔해요.';
  }

  @override
  String get resultPaletteLabel => '네 코디 · 여기서 조합이 나와요';

  @override
  String get resultPaletteLabelCanvas => '네 코디 · 중립 캔버스';

  @override
  String get resultCanvasHeadline => '네 코디엔 색이 필요해';

  @override
  String get resultCanvasKicker => '추천 조합 · 캔버스';

  @override
  String get resultCanvasBaseCap =>
      '네 코디 전체가 중립색이라 뭐든 잘 어울려요. 그래서 조합이 아니라 포인트 컬러를 골라줘요.';

  @override
  String get harmoniesTitle => '어울리는 조합';

  @override
  String get harmoniesSub => '하나를 눌러 이 컬러의 실제 룩을 보세요.';

  @override
  String get canvasTitle => '내 룩은 캔버스';

  @override
  String get canvasBody => '블랙, 화이트, 그레이는 어디에나 어울려요. 이 중 하나로 포인트를 주세요:';

  @override
  String get resultCtaLooks => '이런 룩 보기';

  @override
  String get resultCtaStory => '스토리에 올리기';

  @override
  String get storyFailedSnack => '스토리를 만들지 못했어요. 다시 시도하세요.';

  @override
  String get storyIncludePhoto => '내 사진 넣기';

  @override
  String get storyPhotoPrivacy => '사진은 직접 공유할 때만 폰 밖으로 나가요.';

  @override
  String get storyShareCta => '공유하기';

  @override
  String get storyPreviewLabel => '내 스토리 미리보기';

  @override
  String get looksSearchFailed => '브라우저를 열 수 없어요. 연결을 확인하고 다시 시도하세요.';

  @override
  String get harmonyComplementaryName => '보색';

  @override
  String get harmonyComplementaryDesc => '대비 최대, 2가지 컬러';

  @override
  String get harmonyAnalogousName => '유사색';

  @override
  String get harmonyAnalogousDesc => '부드러운 톤온톤';

  @override
  String get harmonyTriadicName => '삼각 배색';

  @override
  String get harmonyTriadicDesc => '균형 잡힌 3가지 컬러';

  @override
  String get harmonySplitName => '분할 보색';

  @override
  String get harmonySplitDesc => '뉘앙스를 더한 대비';

  @override
  String get sneakerAppBarKicker => '내 신발';

  @override
  String get sneakerSourceTitle => '어디서 찍으세요?';

  @override
  String get sneakerSourceSub => '장소마다 요령이 달라요. 골라 보세요.';

  @override
  String get sneakerSourceCasaTitle => '집이나 길거리';

  @override
  String get sneakerSourceCasaHint => '신발을 가운데에, 화면 가득';

  @override
  String get sneakerSourceTiendaTitle => '매장에서';

  @override
  String get sneakerSourceTiendaHint => '바닥에 내려놓고, 내 신발처럼';

  @override
  String get sneakerSourceWebTitle => '스크린샷';

  @override
  String get sneakerSourceWebHint => '신발만 남게 잘라내기';

  @override
  String get sneakerTipBadge => '요령';

  @override
  String get sneakerTipCasaTitle => '신발을 가운데에, 화면 가득';

  @override
  String get sneakerTipCasaBody =>
      '신발이 화면을 거의 채울 때까지 다가가세요. 깔끔한 배경(바닥이나 벽)에 밝은 조명.';

  @override
  String get sneakerTipCasaCta => '사진 찍기';

  @override
  String get sneakerTipTiendaTitle => '바닥에 내려놓고, 내 신발처럼';

  @override
  String get sneakerTipTiendaBody =>
      '신발을 바닥에 내려놓고 위에서 찍으세요. 이미 내 것처럼요. 그래야 배경이 컬러에 섞이지 않아요.';

  @override
  String get sneakerTipTiendaCta => '사진 찍기';

  @override
  String get sneakerTipWebTitle => '신발만 남게 잘라내기';

  @override
  String get sneakerTipWebBody => '올리기 전에 스크린샷을 잘라내세요. 브라우저, 가격, 흰 여백은 빼고 신발만.';

  @override
  String get sneakerTipWebCta => '스크린샷 선택';

  @override
  String get sneakerIllustrationCasa => '화면 모서리에 거의 닿을 만큼 큰, 가운데 놓인 신발';

  @override
  String get sneakerIllustrationTienda => '바닥에 놓인 신발과 위에서 찍는 휴대폰';

  @override
  String get sneakerIllustrationWeb => '작은 신발이 있는 브라우저 창과 신발만 남기는 잘라내기 영역';

  @override
  String get sneakerSheetTitle => '신발 사진은 어디서 가져올까요?';

  @override
  String get sneakerSheetCameraCaption => '신발, 깔끔한 배경';

  @override
  String get sneakerSheetGalleryCaption => '이미 있는 사진';

  @override
  String get sneakerConfirmTitle => '신발이 잘 보이나요?';

  @override
  String get sneakerConfirmHint => '깔끔한 배경과 좋은 조명 = 더 정확한 컬러.';

  @override
  String get sneakerConfirmCtaPrimary => '조합 보여줘';

  @override
  String get sneakerConfirmCtaSecondary => '다른 사진';

  @override
  String get sneakerAnalyzingHeadline => '신발의 컬러를 뽑는 중…';

  @override
  String get sneakerAnalyzingStep => '배경에서 신발 분리 중';

  @override
  String get sneakerAnalyzingSkipNotePrefix => '끝나면 바로 조합이 떠요 — ';

  @override
  String sneakerResultMeta(String date) {
    return '내 신발 · $date';
  }

  @override
  String get sneakerResultTitle => '이 신발에 옷을 맞춰 보세요';

  @override
  String get sneakerResultHeroKicker => '추천 조합 · 대비';

  @override
  String get sneakerTagZapas => '내 신발';

  @override
  String get sneakerTagRopa => '내 옷';

  @override
  String sneakerTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String sneakerCaptionLead(String complement, String base) {
    return '$complement 컬러가 신발의 $base 컬러를 살려줘요.';
  }

  @override
  String sneakerCaptionRest(String neutral1, String neutral2) {
    return ' 여기에 $neutral1 또는 $neutral2 컬러를 더하면 깔끔해요.';
  }

  @override
  String sneakerBaseBadge(String color) {
    return '베이스 · $color';
  }

  @override
  String get sneakerBaseDescPre => '이건 ';

  @override
  String get sneakerBaseDescBold => '신발의 팔레트';

  @override
  String sneakerBaseDescRest(String color) {
    return '예요. $color 컬러가 조합을 이끌어요.';
  }

  @override
  String get sneakerSectionTitle => '다른 조합';

  @override
  String get sneakerSectionSub => '하나를 눌러 이 컬러의 실제 룩을 보세요.';

  @override
  String get sneakerHarmonyAnalogousName => '톤온톤';

  @override
  String get sneakerHarmonyAnalogousSub => '따뜻하고 부드럽게';

  @override
  String get sneakerHarmonyTriadicName => '밸런스';

  @override
  String get sneakerHarmonyTriadicSub => '3가지 컬러, 과감하게';

  @override
  String get sneakerHarmonySplitName => '뉘앙스 대비';

  @override
  String get sneakerHarmonySplitSub => '펀치 있게, 더 세련되게';

  @override
  String get sneakerResultCtaPrimary => '이런 조합 더 보기';

  @override
  String get sneakerResultCtaSecondary => '다른 신발';

  @override
  String get sneakerCanvasKicker => '추천 조합 · 캔버스';

  @override
  String get sneakerCanvasCaptionLead => '뉴트럴 신발 = 완전한 캔버스.';

  @override
  String get sneakerCanvasCaptionRest => ' 이 다섯 가지 포인트 컬러, 어느 것이든 잘 어울려요.';

  @override
  String get sneakerErrorTitle => '컬러를 읽지 못했어요';

  @override
  String get sneakerErrorBody => '더 밝은 곳이나 깔끔한 배경에서 다시 찍어 보세요.';

  @override
  String get sneakerErrorCta => '다른 사진';

  @override
  String get settingsTooltip => '설정';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsTelemetryTitle => '익명 사용 통계';

  @override
  String get settingsTelemetryBody =>
      '앱 개선에 도움이 돼요. 익명이라서 사진, 개인정보, 나를 식별할 수 있는 정보는 절대 포함되지 않아요. 끄면 아무것도 보내지 않아요.';

  @override
  String get telemetryNoticeTitle => '이건 당신 거예요';

  @override
  String get telemetryNoticeBody1Strong => '사진은 휴대폰 밖으로 나가지 않아요.';

  @override
  String get telemetryNoticeBody1Rest =>
      '색상 분석은 이 안에서 이루어져요. 인터넷도, 계정도 필요 없어요.';

  @override
  String get telemetryNoticeBody2Intro =>
      '앱을 개선하기 위해 익명 사용 통계를 조금 보내요(예: 분석 빈도).';

  @override
  String get telemetryNoticeBody2Strong => '사진도, 개인정보도, 나를 식별하는 것도 없어요.';

  @override
  String get telemetryNoticeBody2Rest => '언제든지 설정에서 끌 수 있어요.';

  @override
  String get telemetryNoticeCta => '확인';

  @override
  String get telemetryNoticeLink => '데이터 처리 방식';

  @override
  String get recolorCta => '입어 보기';

  @override
  String get recolorHeadline => '이렇게 어울려요';

  @override
  String recolorKicker(String region, String color) {
    return '$region · $color';
  }

  @override
  String get recolorExpectation => '색만 바뀌어요. 옷은 그대로 네 옷이에요.';

  @override
  String get recolorHoldHint => '길게 눌러 원본 보기';

  @override
  String get recolorHoldActive => '원본';

  @override
  String get recolorTipPeople => '색을 입어 보려면 혼자 나온 사진이어야 해요.';

  @override
  String get recolorTipLight => '색을 입어 보려면 빛이 더 필요해요.';

  @override
  String get recolorTipCoverage => '색을 입어 보려면 코디 전체가 보여야 해요.';

  @override
  String get recolorFailedSnack => '색을 입혀 보지 못했어요. 다시 시도하세요.';

  @override
  String get recolorPreviewLabel => '조합 색으로 바꾼 내 사진';

  @override
  String resultComboKicker(String scheme) {
    return '추천 조합 · $scheme';
  }
}
