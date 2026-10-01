import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/features/result/widgets/outfit_story_frame.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_layout.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/features/story/story_share_sheet.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:piketemaker/theme/brand_colors.dart';

import '../story/story_test_helpers.dart';

/// A3 (r13) → N1 / D37 — "Súbela a tu story" end to end on the outfit result:
/// the preview sheet opens, "Compartir" writes ONE 1080×1920 PNG to the cache
/// under a fixed name and hands it to the OS share sheet (seam:
/// `ResultScreen.shareStory`; production = share_plus). With the analyzed
/// photo in hand the default image is the PHOTO story; without it (or on the
/// legacy layout) it is r13's card-only story with the switch hidden.
///
/// Image decoding/encoding is real async → renders progress inside
/// `runAsync` + `pump` rounds (see [_settle]).
///
/// Preview for the CEO: run this file with `PIKETE_SHARE_PREVIEW=<out.png>`
/// and the card-only frame test also writes its PNG there (real Roboto).

const Key _host = Key('story_host');

/// Realistic D36 outfit: rust trousers (base) + an off-white tee; the hero
/// recommends denim blue + crema. Colors kept clear of the logo's purple and
/// turquoise so the pixel checks below can tell the lockup from the content.
const Color _rust = Color(0xFFC4562B);
const Color _denim = Color(0xFF2B6CC4);
const Color _offWhite = Color(0xFFEDEAE4);
const Color _olive = Color(0xFF6B7A2B);
const Color _plum = Color(0xFF8A2B6C);
const Color _mustard = Color(0xFFD9A21E);

const AnalysisResult _outfit = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _rust, weight: 0.55),
    ColorSample(color: _offWhite, weight: 0.45),
  ],
  swatchRegions: <GarmentRegion>[GarmentRegion.lower, GarmentRegion.upper],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[_rust, _denim],
    ),
    Harmony(
      type: HarmonyType.analogous,
      name: 'Análogo',
      description: 'Vecinos de rueda, suave',
      colors: <Color>[_rust, _mustard, _plum],
    ),
    Harmony(
      type: HarmonyType.triadic,
      name: 'Triádico',
      description: '3 colores, atrevida',
      colors: <Color>[_rust, _olive, _denim],
    ),
  ],
  garments: <GarmentBlockData>[
    GarmentBlockData(
      region: GarmentRegion.upper,
      palette: <ColorSample>[ColorSample(color: _offWhite, weight: 1.0)],
      baseIndex: -1,
      globalBaseIndex: -1,
    ),
    GarmentBlockData(
      region: GarmentRegion.lower,
      palette: <ColorSample>[ColorSample(color: _rust, weight: 1.0)],
      baseIndex: 0,
      globalBaseIndex: 0,
    ),
  ],
  segmentationLayout: SegmentationLayouts.garments,
);

/// Legacy whole-photo layout (segmentationLayout == null).
const AnalysisResult _legacy = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[ColorSample(color: _rust, weight: 1.0)],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[_rust, _denim],
    ),
  ],
);

bool _ctaReady(WidgetTester tester) {
  final Finder cta = find.descendant(
    of: find.byKey(StorySharePreviewSheet.ctaKey),
    matching: find.byType(FilledButton),
  );
  return cta.evaluate().isNotEmpty &&
      tester.widget<FilledButton>(cta).onPressed != null;
}

/// Lets the real-async story render progress (decode → paint → PNG encode)
/// until [done] holds: real time inside runAsync, then a pump to flush the
/// widget test's fake-zone continuations.
Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (int i = 0; i < 60 && !done(); i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _openStorySheet(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Súbela a tu story'));
  await tester.tap(find.text('Súbela a tu story'));
  await tester.pumpAndSettle();
  await _settle(tester, () => _ctaReady(tester));
  expect(_ctaReady(tester), isTrue, reason: 'the preview PNG was rendered');
}

Future<void> _tapCompartir(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Compartir'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pk_story_export_');
    storyCacheDirectory = () => tmp;
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
      'the card-only story frame (r13, switch OFF) renders to a 1080×1920 PNG '
      'with the lockup centered UNDER the card, inside the story-safe area',
      (WidgetTester tester) async {
    final String? previewOut = Platform.environment['PIKETE_SHARE_PREVIEW'];
    if (previewOut != null) {
      await tester.runAsync(loadRealFonts);
    }
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SizedBox.expand(key: _host)),
    ));
    final BuildContext context = tester.element(find.byKey(_host));

    Uint8List? png;
    Pixels? px;
    await tester.runAsync(() async {
      png = await renderWidgetToPng(
        context,
        const OutfitStoryFrame(result: _outfit),
        logicalSize: OutfitStoryFrame.logicalSize,
        pixelRatio: OutfitStoryFrame.pixelRatio,
      );
      px = await Pixels.decode(png!);
      if (previewOut != null) File(previewOut).writeAsBytesSync(png!);
    });

    expect(png!.sublist(0, 4), pngSignature);
    expect(pngSize(png!), (1080, 1920), reason: '9:16 at story resolution');

    // The hero band (base + complement) is in the image…
    final Rect? rust = px!.bboxOf(_rust);
    final Rect? denim = px!.bboxOf(_denim);
    expect(rust, isNotNull, reason: 'base color (hero band + tu fit strip)');
    expect(denim, isNotNull, reason: 'recommended complement (hero band)');

    // …and the logo turquoise (mark bowl + "Maker") sits entirely BELOW every
    // card pixel of the user's colors: the lockup never covers the combo.
    final Rect? logo = px!.bboxOf(BrandColors.logoTurquoise);
    expect(logo, isNotNull, reason: 'the brand lockup signs the story');
    expect(logo!.top, greaterThan(rust!.bottom));
    expect(logo.top, greaterThan(denim!.bottom));

    // Centered horizontally (the bowl starts right of the stem, so allow the
    // stem's width of slack) and clear of the bottom story chrome.
    expect((logo.center.dx - 540).abs(), lessThan(30));
    expect(
        logo.bottom,
        lessThan(
            1920 - OutfitStoryFrame.safeInsetV * OutfitStoryFrame.pixelRatio));
  });

  testWidgets(
      'no photo: "Súbela a tu story" → preview (switch hidden) → "Compartir" '
      'hands ONE 1080×1920 card PNG in the cache to the share sheet and logs '
      'story_exported (photo:false, mode:outfit, no path)',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uint8List> shared = <Uint8List>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ResultScreen(
        result: _outfit,
        analytics: analytics,
        storyPreferences: StoryPreferencesInMemory(),
        shareStory: (File png, Rect? origin) async {
          // Sync read: real async never completes outside runAsync.
          shared.add(png.readAsBytesSync());
          expect(png.path, endsWith(kStoryFileName),
              reason: 'fixed name: the cache never piles up stories');
          expect(origin, isNotNull, reason: 'iPad popover anchor = the CTA');
          return 'success';
        },
      ),
    ));
    await _openStorySheet(tester);
    expect(find.byType(Switch), findsNothing, reason: 'no photo → no switch');

    await _tapCompartir(tester);

    expect(shared, hasLength(1));
    final Uint8List bytes = shared.single;
    expect(bytes.sublist(0, 4), pngSignature);
    expect(pngSize(bytes), (1080, 1920));

    final AnalyticsEvent event =
        analytics.named(AnalyticsEvents.storyExported).single;
    expect(event.params['bytes'], bytes.length);
    expect(event.params['status'], 'success');
    expect(event.params['photo'], isFalse);
    expect(event.params['mode'], 'outfit');
    expect(event.params.containsKey('path'), isFalse,
        reason: 'no device paths in analytics');

    // The share sheet IS the feedback: no SnackBar; the preview closed and
    // the story file is gone.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsNothing);
    expect(storyFile().existsSync(), isFalse);
  });

  testWidgets(
      'with the analyzed photo: the DEFAULT shared image is the photo story '
      '(the photo pixels are in the PNG), logged photo:true',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    late Uint8List photo;
    await tester.runAsync(() async => photo = await quadrantPhoto(600, 800));
    final List<Uint8List> shared = <Uint8List>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ResultScreen(
        result: _outfit,
        photo: photo,
        analytics: analytics,
        storyPreferences: StoryPreferencesInMemory(),
        shareStory: (File png, Rect? origin) async {
          shared.add(png.readAsBytesSync());
          return 'success';
        },
      ),
    ));
    await _openStorySheet(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await _tapCompartir(tester);

    late Pixels px;
    await tester.runAsync(() async => px = await Pixels.decode(shared.single));
    final Rect photoRect =
        PhotoStoryLayout.compute(photoAspect: 3 / 4).photo;
    const double r = StoryGeometry.pixelRatio;
    expect(
        px.isNear(((photoRect.left + photoRect.width / 4) * r).round(),
            ((photoRect.top + photoRect.height / 4) * r).round(), qTopLeft),
        isTrue,
        reason: 'the user photo is in the shared story');
    expect(analytics.named(AnalyticsEvents.storyExported).single.params['photo'],
        isTrue);
  });

  testWidgets('legacy layout: card-only, switch hidden even with a photo',
      (WidgetTester tester) async {
    late Uint8List photo;
    await tester.runAsync(() async => photo = await quadrantPhoto(60, 80));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ResultScreen(
        result: _legacy,
        photo: photo,
        storyPreferences: StoryPreferencesInMemory(),
        shareStory: (File png, Rect? origin) async => 'success',
      ),
    ));
    await _openStorySheet(tester);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('a double tap on "Súbela a tu story" opens ONE sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ResultScreen(
        result: _outfit,
        storyPreferences: StoryPreferencesInMemory(),
        shareStory: (File png, Rect? origin) async => 'success',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Súbela a tu story'));
    await tester.tap(find.text('Súbela a tu story'));
    await tester.tap(find.text('Súbela a tu story'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsOneWidget);
    await _settle(tester, () => _ctaReady(tester));
  });

  testWidgets('a share failure degrades to the "couldn\'t generate" SnackBar',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ResultScreen(
        result: _outfit,
        storyPreferences: StoryPreferencesInMemory(),
        shareStory: (File png, Rect? origin) async =>
            throw PlatformException(code: 'no_activity'),
      ),
    ));
    await _openStorySheet(tester);
    await _tapCompartir(tester);

    expect(find.byKey(StorySharePreviewSheet.previewKey), findsNothing);
    expect(find.text('No se pudo generar la story. Prueba otra vez.'),
        findsOneWidget);
    // Drain the SnackBar's auto-hide timer before teardown.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
