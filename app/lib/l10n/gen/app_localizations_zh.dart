// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get homeTutorialTooltip => '怎么拍这张照片';

  @override
  String get homeSneakerLabel => '我的球鞋';

  @override
  String get homeSneakerCaption => '从你的球鞋搭出整套穿搭';

  @override
  String get homeOutfitLabel => '我的穿搭';

  @override
  String get homeOutfitCaption => '提取你这身穿搭的配色';

  @override
  String get homeGoPill => '开始';

  @override
  String get onbSkip => '跳过';

  @override
  String get onbWelcomeHeadline => '你穿搭的颜色，\n有讲究。';

  @override
  String get onbWelcomeBody => '拍张照片，我来告诉你配色，以及怎么搭。';

  @override
  String get onbWelcomeCta => '开始';

  @override
  String get onbWelcomePrivacy => '照片不会离开你的手机，我们也不会保存。';

  @override
  String get onbTipBadge => '专业提示';

  @override
  String get onbTipHeadline => '拍准颜色的\n小技巧';

  @override
  String get onbTipPhraseWall => '站在纯色的平整墙面前。';

  @override
  String get onbTipPhraseFullFit => '拍到全身，从头到脚。';

  @override
  String get onbTipPhraseLight => '后退一步，光线要好。';

  @override
  String get onbTipCaption => '背景越干净，颜色读得越准。';

  @override
  String get onbTipCta => '拍我的第一张照片';

  @override
  String get onbExampleGood => '推荐';

  @override
  String get onbExampleBad => '避免';

  @override
  String get onbIllustrationGood => '好的示范：纯色墙前的全身照';

  @override
  String get onbIllustrationBad => '错误示范：同一个人在杂乱的房间里';

  @override
  String get privacyNote => '照片不会离开你的手机：就在本机分析。';

  @override
  String get sheetCameraTitle => '拍一张照片';

  @override
  String get sheetGalleryTitle => '从相册选择';

  @override
  String get sheetPlainBgHint => '背景干净 = 颜色更准。';

  @override
  String get outfitSheetTitle => '照片从哪来？';

  @override
  String get outfitSheetCameraCaption => '全身入镜，背景干净';

  @override
  String get outfitSheetGalleryCaption => '选一张已有的';

  @override
  String get outfitConfirmTitle => '你的穿搭拍清楚了吗？';

  @override
  String get outfitConfirmHint => '背景干净 = 颜色更准。';

  @override
  String get outfitConfirmCtaPrimary => '开始分析';

  @override
  String get outfitConfirmCtaSecondary => '重拍';

  @override
  String get outfitAnalyzingHeadline => '正在读取你穿搭的颜色…';

  @override
  String get outfitAnalyzingStep1 => '读取照片';

  @override
  String get outfitAnalyzingStep2 => '归类颜色';

  @override
  String get outfitAnalyzingStep3 => '生成配色方案';

  @override
  String get outfitAnalyzingSkipNotePrefix => '分析完成后马上出结果 — ';

  @override
  String get analyzingMonoLabel => '分析中';

  @override
  String get analyzingSkipNoteAccent => '快好了';

  @override
  String get adSlotTipBadge => '提示';

  @override
  String get adSlotAdCaption => '进度始终显示在上方：广告只是陪你等待，不会挡住流程。';

  @override
  String get adSlotTipCaption => '背景干净、后退一步：这样颜色才读得准。';

  @override
  String get feedbackCameraHeadline => '没有相机就拍不了穿搭。';

  @override
  String get feedbackCameraDetail => '在设置里开启权限，或从相册选一张照片。';

  @override
  String get feedbackCameraCtaPrimary => '如何开启';

  @override
  String get feedbackCameraCtaSecondary => '从相册选择';

  @override
  String get feedbackCameraSettingsPath => '系统设置 → 应用 → PiketeMaker → 权限 → 相机。';

  @override
  String get feedbackFailedHeadline => '没能读准你的穿搭。';

  @override
  String get feedbackFailedDetail => '试试更亮的光线，或后退一步。';

  @override
  String get feedbackFailedCtaPrimary => '换一张照片';

  @override
  String get feedbackFailedCtaSecondary => '用这张重试';

  @override
  String get feedbackNoOutfitHeadline => '这里看不出完整的穿搭。';

  @override
  String get feedbackNoOutfitDetail => '全身入镜、光线好、背景干净。';

  @override
  String get feedbackNoOutfitCtaPrimary => '再拍一张';

  @override
  String get feedbackNoOutfitCtaSecondary => '从相册选择';

  @override
  String get resultHeadlineLegacy => '你的配色';

  @override
  String get resultHeadlineGarments => '你的穿搭';

  @override
  String resultMeta(String date) {
    return '今日穿搭 · $date';
  }

  @override
  String get resultBaseBadge => '主色';

  @override
  String get resultBaseLead => '你的主色。';

  @override
  String get resultBaseAttributionUpper => '来自你的上半身。';

  @override
  String get resultBaseAttributionLower => '来自你的下半身。';

  @override
  String get resultBaseRest => '整套搭配都围绕它展开。';

  @override
  String get garmentUpperLabel => '上装';

  @override
  String get garmentLowerLabel => '下装';

  @override
  String get garmentSingleLabel => '你的衣服';

  @override
  String get resultRecoHeadline => '拿下你的穿搭';

  @override
  String get resultHeroKicker => '本套搭配 · 对比';

  @override
  String get resultTagFit => '你的穿搭';

  @override
  String get resultTagAdd => '搭这个';

  @override
  String resultTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String resultCaptionLead(String complement, String base) {
    return '$complement能衬出穿搭里的$base。';
  }

  @override
  String resultCaptionRest(String neutral1, String neutral2) {
    return ' 再加$neutral1或$neutral2，整体就很利落。';
  }

  @override
  String get resultPaletteLabel => '你的穿搭 · 搭配从这里来';

  @override
  String get resultPaletteLabelCanvas => '你的穿搭 · 你的中性画布';

  @override
  String get resultCanvasHeadline => '你的穿搭需要点色彩';

  @override
  String get resultCanvasKicker => '本套搭配 · 画布';

  @override
  String get resultCanvasBaseCap => '你整套穿搭都是中性色——百搭。所以我们给你差色，而不是配色方案。';

  @override
  String get harmoniesTitle => '适合搭配';

  @override
  String get harmoniesSub => '点一个，看看这些颜色的真实穿搭。';

  @override
  String get canvasTitle => '你的造型是一块画布';

  @override
  String get canvasBody => '黑、白、灰百搭。用下面任意一个点缀色提亮：';

  @override
  String get resultCtaLooks => '看看这样的穿搭';

  @override
  String get resultCtaStory => '发到你的 story';

  @override
  String get storyFailedSnack => '生成 story 失败，请再试一次。';

  @override
  String get storyIncludePhoto => '包含我的照片';

  @override
  String get storyPhotoPrivacy => '只有你自己分享时，照片才会离开手机。';

  @override
  String get storyShareCta => '分享';

  @override
  String get storyPreviewLabel => '你的 story 预览';

  @override
  String get looksSearchFailed => '无法打开浏览器。请检查网络后再试一次。';

  @override
  String get harmonyComplementaryName => '互补色';

  @override
  String get harmonyComplementaryDesc => '对比最强，2 种颜色';

  @override
  String get harmonyAnalogousName => '邻近色';

  @override
  String get harmonyAnalogousDesc => '柔和，同色系';

  @override
  String get harmonyTriadicName => '三角配色';

  @override
  String get harmonyTriadicDesc => '平衡，3 种颜色';

  @override
  String get harmonySplitName => '分裂互补';

  @override
  String get harmonySplitDesc => '对比中带层次';

  @override
  String get sneakerAppBarKicker => '我的球鞋';

  @override
  String get sneakerSourceTitle => '你在哪里拍？';

  @override
  String get sneakerSourceSub => '每个场景都有技巧。选你的。';

  @override
  String get sneakerSourceCasaTitle => '在家或街上';

  @override
  String get sneakerSourceCasaHint => '球鞋居中，尽量占满画面';

  @override
  String get sneakerSourceTiendaTitle => '在店里';

  @override
  String get sneakerSourceTiendaHint => '把鞋放在地上，像自己的一样拍';

  @override
  String get sneakerSourceWebTitle => '截图';

  @override
  String get sneakerSourceWebHint => '裁剪到只剩球鞋';

  @override
  String get sneakerTipBadge => '技巧';

  @override
  String get sneakerTipCasaTitle => '球鞋居中，占满画面';

  @override
  String get sneakerTipCasaBody => '靠近一点，让球鞋几乎占满整个屏幕。背景干净（地面或墙面），光线要好。';

  @override
  String get sneakerTipCasaCta => '拍照';

  @override
  String get sneakerTipTiendaTitle => '把鞋放在地上，像自己的一样';

  @override
  String get sneakerTipTiendaBody => '把球鞋放到地上，从上往下拍，就像已经是你的了。这样背景不会混进颜色里。';

  @override
  String get sneakerTipTiendaCta => '拍照';

  @override
  String get sneakerTipWebTitle => '裁剪到只剩球鞋';

  @override
  String get sneakerTipWebBody => '上传前先裁剪截图：去掉浏览器、价格和多余的白色，只留球鞋。';

  @override
  String get sneakerTipWebCta => '选择截图';

  @override
  String get sneakerIllustrationCasa => '一只居中的大球鞋，几乎碰到画面四角';

  @override
  String get sneakerIllustrationTienda => '一只放在地上的球鞋，一部手机从上方拍摄';

  @override
  String get sneakerIllustrationWeb => '一个浏览器窗口，里面有一只小球鞋，裁剪框只留下球鞋';

  @override
  String get sneakerSheetTitle => '球鞋照片从哪来？';

  @override
  String get sneakerSheetCameraCaption => '球鞋，背景干净';

  @override
  String get sneakerSheetGalleryCaption => '选一张已有的';

  @override
  String get sneakerConfirmTitle => '你的球鞋拍清楚了吗？';

  @override
  String get sneakerConfirmHint => '背景干净、光线充足 = 颜色更准。';

  @override
  String get sneakerConfirmCtaPrimary => '给我搭配方案';

  @override
  String get sneakerConfirmCtaSecondary => '换一张';

  @override
  String get sneakerAnalyzingHeadline => '正在提取球鞋的颜色…';

  @override
  String get sneakerAnalyzingStep => '正在把球鞋从背景中分离';

  @override
  String get sneakerAnalyzingSkipNotePrefix => '分析完成后马上出搭配 — ';

  @override
  String sneakerResultMeta(String date) {
    return '你的球鞋 · $date';
  }

  @override
  String get sneakerResultTitle => '用衣服搭配这双球鞋';

  @override
  String get sneakerResultHeroKicker => '本套搭配 · 对比';

  @override
  String get sneakerTagZapas => '你的球鞋';

  @override
  String get sneakerTagRopa => '你的衣服';

  @override
  String sneakerTagNeutral(String neutral) {
    return '+ $neutral';
  }

  @override
  String sneakerCaptionLead(String complement, String base) {
    return '$complement能衬出球鞋上的$base。';
  }

  @override
  String sneakerCaptionRest(String neutral1, String neutral2) {
    return ' 再加$neutral1或$neutral2，整体就很利落。';
  }

  @override
  String sneakerBaseBadge(String color) {
    return '主色 · $color';
  }

  @override
  String get sneakerBaseDescPre => '这是';

  @override
  String get sneakerBaseDescBold => '球鞋的配色';

  @override
  String sneakerBaseDescRest(String color) {
    return '。$color主导整套搭配。';
  }

  @override
  String get sneakerSectionTitle => '其他搭配';

  @override
  String get sneakerSectionSub => '点一个，看看这些颜色的真实穿搭。';

  @override
  String get sneakerHarmonyAnalogousName => '同色系';

  @override
  String get sneakerHarmonyAnalogousSub => '暖调，柔和';

  @override
  String get sneakerHarmonyTriadicName => '三色平衡';

  @override
  String get sneakerHarmonyTriadicSub => '3 种颜色，大胆';

  @override
  String get sneakerHarmonySplitName => '层次对比';

  @override
  String get sneakerHarmonySplitSub => '有冲击，更精致';

  @override
  String get sneakerResultCtaPrimary => '看更多这样的搭配';

  @override
  String get sneakerResultCtaSecondary => '换双球鞋';

  @override
  String get sneakerCanvasKicker => '本套搭配 · 画布';

  @override
  String get sneakerCanvasCaptionLead => '中性色球鞋 = 百搭画布。';

  @override
  String get sneakerCanvasCaptionRest => ' 这五个点缀色随便选一个，都好看。';

  @override
  String get sneakerErrorTitle => '没能读出颜色';

  @override
  String get sneakerErrorBody => '试试更亮的光线，或换个干净背景。';

  @override
  String get sneakerErrorCta => '再拍一张';

  @override
  String get settingsTooltip => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTelemetryTitle => '匿名使用统计';

  @override
  String get settingsTelemetryBody =>
      '它们帮助我们改进应用。这些数据是匿名的：绝不包含你的照片、个人资料或任何能识别你的信息。关闭后，我们将不再发送任何数据。';

  @override
  String get telemetryNoticeTitle => '这是你的';

  @override
  String get telemetryNoticeBody1Strong => '照片不会离开你的手机。';

  @override
  String get telemetryNoticeBody1Rest => '颜色分析就在本机完成，无需联网，无需账号。';

  @override
  String get telemetryNoticeBody2Intro => '为了改进应用，我们会发送少量匿名使用统计（例如分析的频率）。';

  @override
  String get telemetryNoticeBody2Strong => '没有照片，没有个人资料，不会识别你的身份。';

  @override
  String get telemetryNoticeBody2Rest => '你可以随时在设置中关闭。';

  @override
  String get telemetryNoticeCta => '知道了';

  @override
  String get telemetryNoticeLink => '我们如何处理数据';

  @override
  String get recolorCta => '穿上看看';

  @override
  String get recolorHeadline => '穿上会是这样';

  @override
  String recolorKicker(String region, String color) {
    return '$region · $color';
  }

  @override
  String get recolorExpectation => '只改变颜色：衣服还是你自己的那件。';

  @override
  String get recolorHoldHint => '按住查看原图';

  @override
  String get recolorHoldActive => '原图';

  @override
  String get recolorTipPeople => '想看颜色穿在身上的效果，请单独出镜。';

  @override
  String get recolorTipLight => '想看颜色穿在身上的效果，需要更多光线。';

  @override
  String get recolorTipCoverage => '想看颜色穿在身上的效果，请拍到整套穿搭。';

  @override
  String get recolorFailedSnack => '无法试色，请再试一次。';

  @override
  String get recolorPreviewLabel => '你的照片换上搭配的颜色';

  @override
  String resultComboKicker(String scheme) {
    return '本套搭配 · $scheme';
  }
}
