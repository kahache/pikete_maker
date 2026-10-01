// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get homeTutorialTooltip => '写真の撮り方';

  @override
  String get homeSneakerLabel => 'マイスニーカー';

  @override
  String get homeSneakerCaption => 'スニーカーからコーデを組む';

  @override
  String get homeOutfitLabel => 'マイコーデ';

  @override
  String get homeOutfitCaption => 'コーデのパレットを抽出';

  @override
  String get homeGoPill => 'スタート';

  @override
  String get onbSkip => 'スキップ';

  @override
  String get onbWelcomeHeadline => 'きみのコーデの色を、\nセンスよく。';

  @override
  String get onbWelcomeBody => '写真を撮れば、パレットと合う色を教えるよ。';

  @override
  String get onbWelcomeCta => 'はじめる';

  @override
  String get onbWelcomePrivacy => '写真はスマホの外に出ず、保存もしません。';

  @override
  String get onbTipBadge => 'プロのコツ';

  @override
  String get onbTipHeadline => '色をきれいに\n読み取るコツ';

  @override
  String get onbTipPhraseWall => '単色のフラットな壁の前に立とう。';

  @override
  String get onbTipPhraseFullFit => '頭からつま先まで、全身が写るように。';

  @override
  String get onbTipPhraseLight => '一歩下がって、明るい場所で。';

  @override
  String get onbTipCaption => '背景がシンプルなほど、色を正確に読めるよ。';

  @override
  String get onbTipCta => 'はじめての一枚を撮る';

  @override
  String get onbExampleGood => 'GOOD';

  @override
  String get onbExampleBad => 'NG';

  @override
  String get onbIllustrationGood => '良い例：フラットな壁の前の全身写真';

  @override
  String get onbIllustrationBad => '悪い例：散らかった部屋にいる同じ人物';

  @override
  String get privacyNote => '写真はスマホの外に出ません。この中だけで解析します。';

  @override
  String get sheetCameraTitle => '写真を撮る';

  @override
  String get sheetGalleryTitle => 'ギャラリーから選ぶ';

  @override
  String get sheetPlainBgHint => 'シンプルな背景＝より正確な色。';

  @override
  String get outfitSheetTitle => '写真はどこから？';

  @override
  String get outfitSheetCameraCaption => '全身、シンプルな背景';

  @override
  String get outfitSheetGalleryCaption => '手持ちの一枚';

  @override
  String get outfitConfirmTitle => 'コーデ、ちゃんと写ってる?';

  @override
  String get outfitConfirmHint => 'シンプルな背景＝より正確な色。';

  @override
  String get outfitConfirmCtaPrimary => '解析する';

  @override
  String get outfitConfirmCtaSecondary => '撮り直す';

  @override
  String get outfitAnalyzingHeadline => 'コーデの色を読み取り中…';

  @override
  String get outfitAnalyzingStep1 => '写真を読み込み中';

  @override
  String get outfitAnalyzingStep2 => '色をグルーピング中';

  @override
  String get outfitAnalyzingStep3 => '配色を組み立て中';

  @override
  String get outfitAnalyzingSkipNotePrefix => '終わったらすぐパレットが出るよ — ';

  @override
  String get analyzingMonoLabel => '解析中';

  @override
  String get analyzingSkipNoteAccent => 'もうすぐ';

  @override
  String get adSlotTipBadge => 'コツ';

  @override
  String get adSlotAdCaption => '進行状況は常に上に表示。広告は待ち時間のお供で、じゃまはしません。';

  @override
  String get adSlotTipCaption => 'シンプルな背景で一歩下がる。それで色がきれいに読めるよ。';

  @override
  String get feedbackCameraHeadline => 'カメラがないとコーデも撮れない。';

  @override
  String get feedbackCameraDetail => '設定でオンにするか、ギャラリーから写真を選ぼう。';

  @override
  String get feedbackCameraCtaPrimary => 'オンにする方法';

  @override
  String get feedbackCameraCtaSecondary => 'ギャラリーから選ぶ';

  @override
  String get feedbackCameraSettingsPath =>
      'システム設定 → アプリ → PiketeMaker → 権限 → カメラ。';

  @override
  String get feedbackFailedHeadline => 'コーデをうまく読めなかった。';

  @override
  String get feedbackFailedDetail => 'もっと明るい場所か、一歩下がって試してみて。';

  @override
  String get feedbackFailedCtaPrimary => '別の写真で試す';

  @override
  String get feedbackFailedCtaSecondary => '同じ写真でリトライ';

  @override
  String get feedbackNoOutfitHeadline => 'ここでははっきりしたコーデが見えない。';

  @override
  String get feedbackNoOutfitDetail => '全身、良い光、落ち着いた背景。';

  @override
  String get feedbackNoOutfitCtaPrimary => 'もう一枚撮る';

  @override
  String get feedbackNoOutfitCtaSecondary => 'ギャラリーから選ぶ';

  @override
  String get resultHeadlineLegacy => 'きみのパレット';

  @override
  String get resultHeadlineGarments => 'きみのコーデ';

  @override
  String resultMeta(String date) {
    return '今日のコーデ · $date';
  }

  @override
  String get resultBaseBadge => 'ベース';

  @override
  String get resultBaseLead => 'きみのメインカラー。';

  @override
  String get resultBaseAttributionUpper => '上半身から取った色。';

  @override
  String get resultBaseAttributionLower => '下半身から取った色。';

  @override
  String get resultBaseRest => '全体はこの色を軸にまとまる。';

  @override
  String get garmentUpperLabel => 'トップス';

  @override
  String get garmentLowerLabel => 'ボトムス';

  @override
  String get garmentSingleLabel => 'きみの服';

  @override
  String get resultRecoHeadline => 'きみのコーデを決めろ';

  @override
  String get resultHeroKicker => 'おすすめコンボ · コントラスト';

  @override
  String get resultTagFit => 'きみのコーデ';

  @override
  String get resultTagAdd => '足して';

  @override
  String resultTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String resultCaptionLead(String complement, String base) {
    return '$complementがコーデの$baseを引き立てる。';
  }

  @override
  String resultCaptionRest(String neutral1, String neutral2) {
    return ' そこに$neutral1か$neutral2を足せばキマる。';
  }

  @override
  String get resultPaletteLabel => 'きみのコーデ · ここから配色が出る';

  @override
  String get resultPaletteLabelCanvas => 'きみのコーデ · ニュートラルなキャンバス';

  @override
  String get resultCanvasHeadline => 'きみのコーデに色を';

  @override
  String get resultCanvasKicker => 'おすすめコンボ · キャンバス';

  @override
  String get resultCanvasBaseCap =>
      'きみのコーデは全部ニュートラル——なんでも合う。だから配色じゃなく差し色を出してる。';

  @override
  String get harmoniesTitle => '相性のいい配色';

  @override
  String get harmoniesSub => 'タップして、その色のリアルなルックを見よう。';

  @override
  String get canvasTitle => 'きみのルックはキャンバス';

  @override
  String get canvasBody => '黒・白・グレーは何にでも合う。ここから一色、差し色をどうぞ：';

  @override
  String get resultCtaLooks => 'こんなルックを見る';

  @override
  String get resultCtaStory => 'ストーリーに上げる';

  @override
  String get storyFailedSnack => 'ストーリーを作れなかった。もう一度試してね。';

  @override
  String get storyIncludePhoto => '自分の写真を入れる';

  @override
  String get storyPhotoPrivacy => '写真がスマホから出るのは、自分でシェアしたときだけ。';

  @override
  String get storyShareCta => 'シェアする';

  @override
  String get storyPreviewLabel => 'ストーリーのプレビュー';

  @override
  String get looksSearchFailed => 'ブラウザを開けなかった。接続を確認してもう一度どうぞ。';

  @override
  String get harmonyComplementaryName => '補色';

  @override
  String get harmonyComplementaryDesc => 'コントラスト最大、2色';

  @override
  String get harmonyAnalogousName => '類似色';

  @override
  String get harmonyAnalogousDesc => 'やわらかいトーンオントーン';

  @override
  String get harmonyTriadicName => 'トライアド';

  @override
  String get harmonyTriadicDesc => 'バランスのいい3色';

  @override
  String get harmonySplitName => 'スプリット補色';

  @override
  String get harmonySplitDesc => 'ニュアンスのあるコントラスト';

  @override
  String get sneakerAppBarKicker => 'マイスニーカー';

  @override
  String get sneakerSourceTitle => 'どこで撮る?';

  @override
  String get sneakerSourceSub => '場所ごとにコツがある。選んでね。';

  @override
  String get sneakerSourceCasaTitle => '家か路上';

  @override
  String get sneakerSourceCasaHint => 'スニーカーを中央に、画面いっぱいに';

  @override
  String get sneakerSourceTiendaTitle => 'お店で';

  @override
  String get sneakerSourceTiendaHint => '床に置いて、自分のもののように';

  @override
  String get sneakerSourceWebTitle => 'スクリーンショット';

  @override
  String get sneakerSourceWebHint => 'スニーカーだけ残るようにトリミング';

  @override
  String get sneakerTipBadge => 'コツ';

  @override
  String get sneakerTipCasaTitle => 'スニーカーを中央に、画面いっぱいに';

  @override
  String get sneakerTipCasaBody => 'スニーカーが画面をほぼ埋めるまで近づこう。背景はフラット（床か壁）で、明るい場所で。';

  @override
  String get sneakerTipCasaCta => '写真を撮る';

  @override
  String get sneakerTipTiendaTitle => '床に置いて、自分のもののように';

  @override
  String get sneakerTipTiendaBody =>
      'スニーカーを床に置いて、真上から撮ろう。もう自分のもののつもりで。そうすれば背景の色が混ざらない。';

  @override
  String get sneakerTipTiendaCta => '写真を撮る';

  @override
  String get sneakerTipWebTitle => 'スニーカーだけ残るようにトリミング';

  @override
  String get sneakerTipWebBody =>
      'アップする前にスクショをトリミング。ブラウザも価格も白い余白もカットして、スニーカーだけに。';

  @override
  String get sneakerTipWebCta => 'スクショを選ぶ';

  @override
  String get sneakerIllustrationCasa => '画面の角にほぼ届く、中央に置かれた大きなスニーカー';

  @override
  String get sneakerIllustrationTienda => '床に置かれたスニーカーと、真上から撮るスマホ';

  @override
  String get sneakerIllustrationWeb => '小さなスニーカーが写ったブラウザ画面と、スニーカーだけを残すトリミング枠';

  @override
  String get sneakerSheetTitle => 'スニーカーの写真はどこから?';

  @override
  String get sneakerSheetCameraCaption => 'スニーカー、フラットな背景';

  @override
  String get sneakerSheetGalleryCaption => '手持ちの一枚';

  @override
  String get sneakerConfirmTitle => 'スニーカー、ちゃんと写ってる?';

  @override
  String get sneakerConfirmHint => 'フラットな背景と良い光＝より正確な色。';

  @override
  String get sneakerConfirmCtaPrimary => 'コーデをちょうだい';

  @override
  String get sneakerConfirmCtaSecondary => '別の写真';

  @override
  String get sneakerAnalyzingHeadline => 'スニーカーの色を抽出中…';

  @override
  String get sneakerAnalyzingStep => '背景からスニーカーを切り出し中';

  @override
  String get sneakerAnalyzingSkipNotePrefix => '終わったらすぐコンボが出るよ — ';

  @override
  String sneakerResultMeta(String date) {
    return 'きみのスニーカー · $date';
  }

  @override
  String get sneakerResultTitle => 'このスニーカーに服を合わせよう';

  @override
  String get sneakerResultHeroKicker => 'おすすめコンボ · コントラスト';

  @override
  String get sneakerTagZapas => 'きみのスニーカー';

  @override
  String get sneakerTagRopa => 'きみの服';

  @override
  String sneakerTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String sneakerCaptionLead(String complement, String base) {
    return '$complementがスニーカーの$baseを引き立てる。';
  }

  @override
  String sneakerCaptionRest(String neutral1, String neutral2) {
    return ' そこに$neutral1か$neutral2を足せばキマる。';
  }

  @override
  String sneakerBaseBadge(String color) {
    return 'ベース · $color';
  }

  @override
  String get sneakerBaseDescPre => 'これは';

  @override
  String get sneakerBaseDescBold => 'スニーカーのパレット';

  @override
  String sneakerBaseDescRest(String color) {
    return '。$colorがコンボを引っ張る。';
  }

  @override
  String get sneakerSectionTitle => 'ほかのコンボ';

  @override
  String get sneakerSectionSub => 'タップして、その色のリアルなルックを見よう。';

  @override
  String get sneakerHarmonyAnalogousName => 'トーンオントーン';

  @override
  String get sneakerHarmonyAnalogousSub => '暖色系、やわらかめ';

  @override
  String get sneakerHarmonyTriadicName => 'バランス型';

  @override
  String get sneakerHarmonyTriadicSub => '3色、攻めた組み合わせ';

  @override
  String get sneakerHarmonySplitName => 'ニュアンス系コントラスト';

  @override
  String get sneakerHarmonySplitSub => 'パンチがあって、より上品';

  @override
  String get sneakerResultCtaPrimary => 'ほかのコーデも見せて';

  @override
  String get sneakerResultCtaSecondary => '別のスニーカー';

  @override
  String get sneakerCanvasKicker => 'おすすめコンボ · キャンバス';

  @override
  String get sneakerCanvasCaptionLead => 'ニュートラルなスニーカー＝無限キャンバス。';

  @override
  String get sneakerCanvasCaptionRest => ' この5つの差し色、どれでもハマる。';

  @override
  String get sneakerErrorTitle => '色を読み取れなかった';

  @override
  String get sneakerErrorBody => 'もっと明るい場所か、フラットな背景で試してみて。';

  @override
  String get sneakerErrorCta => '別の写真';

  @override
  String get settingsTooltip => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsTelemetryTitle => '匿名の利用統計';

  @override
  String get settingsTelemetryBody =>
      'アプリの改善に役立ちます。匿名なので、写真や個人情報、あなたを特定できるものは一切含まれません。オフにすると、何も送信しません。';

  @override
  String get telemetryNoticeTitle => 'これはあなたのもの';

  @override
  String get telemetryNoticeBody1Strong => '写真はスマホの外に出ません。';

  @override
  String get telemetryNoticeBody1Rest => '色の解析はこの中だけで行われます。通信も、アカウントも不要です。';

  @override
  String get telemetryNoticeBody2Intro =>
      'アプリ改善のため、匿名の利用統計を少しだけ送信します（例：解析の頻度）。';

  @override
  String get telemetryNoticeBody2Strong => '写真も、個人情報も、あなたを特定するものもありません。';

  @override
  String get telemetryNoticeBody2Rest => '設定からいつでもオフにできます。';

  @override
  String get telemetryNoticeCta => 'OK';

  @override
  String get telemetryNoticeLink => 'データの取り扱いについて';

  @override
  String get recolorCta => '着てみる';

  @override
  String get recolorHeadline => '着るとこうなる';

  @override
  String recolorKicker(String region, String color) {
    return '$region · $color';
  }

  @override
  String get recolorExpectation => '変わるのは色だけ。服はあなたのままだよ。';

  @override
  String get recolorHoldHint => '長押しで元の写真';

  @override
  String get recolorHoldActive => '元の写真';

  @override
  String get recolorTipPeople => '色を着て見るには、ひとりで写ってね。';

  @override
  String get recolorTipLight => '色を着て見るには、もっと明るさが必要だよ。';

  @override
  String get recolorTipCoverage => '色を着て見るには、コーデ全体を写してね。';

  @override
  String get recolorFailedSnack => '色を試せなかった。もう一度試してね。';

  @override
  String get recolorPreviewLabel => 'コンビの色にしたあなたの写真';

  @override
  String resultComboKicker(String scheme) {
    return 'おすすめコンボ · $scheme';
  }
}
