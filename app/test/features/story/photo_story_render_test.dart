import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/widgets/outfit_story_frame.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo.dart';
import 'package:piketemaker/features/sneaker/widgets/sneaker_photo_story_frame.dart';
import 'package:piketemaker/features/sneaker/widgets/sneaker_share_canvas.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_layout.dart';
import 'package:piketemaker/features/story/story_photo.dart';
import 'package:piketemaker/features/story/widgets/story_frame.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:piketemaker/theme/app_typography.dart';
import 'package:piketemaker/theme/brand_colors.dart';

import 'story_test_helpers.dart';

/// N1 / D37 — the PHOTO story, rendered offscreen for real (1080 × 1920 PNG).
///
/// THE TRAP (spec §8.4): `renderWidgetToPng` paints once, synchronously; an
/// `Image` widget would still be loading and the shared photo would be BLANK.
/// The photo is decoded to a `ui.Image` first and painted with `RawImage`.
/// The pixel test below compares the PNG's photo region against the fixture.
///
/// Samples for the CEO: run this file with `PIKETE_STORY_SAMPLES=<dir>` and
/// the "samples" test writes the photo story (3:4 + 9:16 + canvas) and the
/// card-only fallback there, plus host render timings. Synthetic photos only.

const Key _host = Key('story_host');

const Color _rust = Color(0xFFC4572A);
const Color _denim = Color(0xFF2C6EC4);
const Color _offWhite = Color(0xFFECE8E1);

/// Realistic D36 outfit (the mockup's): rust trousers (base) + off-white tee;
/// the hero recommends denim blue + crema.
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

/// The five curated pops (D10) as in the mockup.
const List<Color> _pops = <Color>[
  Color(0xFFE4322B),
  Color(0xFF2B5CE4),
  Color(0xFFE0A000),
  Color(0xFF12A150),
  Color(0xFFD6248C),
];

/// 100% neutral fit → canvas mode.
const AnalysisResult _canvasOutfit = AnalysisResult(
  baseIndex: -1,
  palette: <ColorSample>[
    ColorSample(color: Color(0xFF2A2730), weight: 0.6),
    ColorSample(color: Color(0xFF8E8B93), weight: 0.4),
  ],
  harmonies: <Harmony>[],
  canvasAccents: _pops,
  segmentationLayout: SegmentationLayouts.garments,
);

/// Green kicks (the mockup's): base green, the hero recommends pink + crema.
const AnalysisResult _kicks = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: Color(0xFF2F7A4D), weight: 0.55),
    ColorSample(color: Color(0xFFF6F4F0), weight: 0.45),
  ],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[Color(0xFF2F7A4D), Color(0xFFB8477A)],
    ),
  ],
);

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: SizedBox.expand(key: _host)),
  ));
  return tester.element(find.byKey(_host));
}

/// Story px of a logical rect.
Rect _px(Rect r) => Rect.fromLTRB(
      r.left * StoryGeometry.pixelRatio,
      r.top * StoryGeometry.pixelRatio,
      r.right * StoryGeometry.pixelRatio,
      r.bottom * StoryGeometry.pixelRatio,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real Roboto: the story is measured/painted like on a phone.
    await loadRealFonts();
  });

  testWidgets(
      'the photo is ACTUALLY painted in the offscreen PNG (not blank): the '
      'photo region matches the fixture quadrant by quadrant',
      (WidgetTester tester) async {
    final BuildContext context = await _pumpHost(tester);
    late Uint8List png;
    late Pixels px;
    await tester.runAsync(() async {
      final Uint8List photo = await quadrantPhoto(1200, 1600); // 3:4
      png = await renderPhotoStoryPng(
        context,
        photo,
        (ui.Image image) => OutfitPhotoStoryFrame(result: _outfit, photo: image),
      );
      px = await Pixels.decode(png);
    });

    expect(png.sublist(0, 4), pngSignature);
    expect(pngSize(png), (1080, 1920), reason: '9:16 at story resolution');

    final PhotoStoryLayout layout =
        PhotoStoryLayout.compute(photoAspect: 3 / 4);
    final Rect photo = _px(layout.photo);
    // Each quadrant's centre, in the PNG, carries the fixture's colour.
    final Map<Offset, Color> probes = <Offset, Color>{
      Offset(photo.left + photo.width / 4, photo.top + photo.height / 4):
          qTopLeft,
      Offset(photo.left + photo.width * 3 / 4, photo.top + photo.height / 4):
          qTopRight,
      Offset(photo.left + photo.width / 4, photo.top + photo.height * 3 / 4):
          qBottomLeft,
      Offset(photo.left + photo.width * 3 / 4,
          photo.top + photo.height * 3 / 4): qBottomRight,
    };
    probes.forEach((Offset at, Color expected) {
      expect(px.isNear(at.dx.round(), at.dy.round(), expected), isTrue,
          reason: 'photo pixel at $at should be $expected, got '
              '${px.at(at.dx.round(), at.dy.round())} (blank = the '
              'offscreen-render trap)');
    });
    // The whole photo, uncropped: the red quadrant starts at the card's
    // top-left corner region and the yellow one reaches its bottom-right.
    final Rect red = px.bboxOf(qTopLeft, tol: 8)!;
    final Rect yellow = px.bboxOf(qBottomRight, tol: 8)!;
    expect(red.left, closeTo(photo.left, 3));
    expect(red.top, closeTo(photo.top, 3));
    expect(yellow.right, closeTo(photo.right, 3));
    expect(yellow.bottom, closeTo(photo.bottom, 3));
  });

  testWidgets(
      'the band is glued UNDER the photo, card-wide; the lockup sits below it, '
      'centred, inside the story-safe band', (WidgetTester tester) async {
    final BuildContext context = await _pumpHost(tester);
    late Pixels px;
    await tester.runAsync(() async {
      final Uint8List photo = await quadrantPhoto(1200, 1600);
      final Uint8List png = await renderPhotoStoryPng(
        context,
        photo,
        (ui.Image image) => OutfitPhotoStoryFrame(result: _outfit, photo: image),
      );
      px = await Pixels.decode(png);
    });
    final PhotoStoryLayout layout =
        PhotoStoryLayout.compute(photoAspect: 3 / 4);
    final Rect photo = _px(layout.photo);
    final Rect band = _px(layout.band);

    final Rect rust = px.bboxOf(_rust)!;
    final Rect denim = px.bboxOf(_denim)!;
    // Band segments: under the photo, within the card's width.
    for (final Rect seg in <Rect>[rust, denim]) {
      expect(seg.top, closeTo(band.top, 3));
      expect(seg.bottom, closeTo(band.bottom, 3));
      expect(seg.left, greaterThanOrEqualTo(photo.left - 1));
      expect(seg.right, lessThanOrEqualTo(photo.right + 1));
    }
    expect(rust.left, closeTo(photo.left, 3), reason: 'base segment first');

    final Rect logo = px.bboxOf(BrandColors.logoTurquoise)!;
    expect(logo.top, greaterThan(band.bottom));
    expect((logo.center.dx - 540).abs(), lessThan(30), reason: 'centred');
    expect(logo.bottom,
        lessThan(StoryGeometry.safeBottom * StoryGeometry.pixelRatio));
    // No content in the unsafe strips: rows 0–200 and 1720–1920 are white.
    for (final int y in <int>[10, 150, 199, 1721, 1800, 1910]) {
      for (int x = 0; x < 1080; x += 27) {
        expect(px.isNear(x, y, Colors.white, tol: 2), isTrue,
            reason: 'unsafe strip pixel ($x, $y) must be background');
      }
    }
  });

  testWidgets(
      'EXIF Orientation = 6: the photo is decoded UPRIGHT (portrait) and the '
      'story card is portrait', (WidgetTester tester) async {
    final BuildContext context = await _pumpHost(tester);
    late int w, h;
    late Pixels decoded;
    late Pixels story;
    await tester.runAsync(() async {
      final ui.Image image = await decodeStoryPhoto(exif6Fixture());
      w = image.width;
      h = image.height;
      decoded = await Pixels.fromImage(image);
      image.dispose();
      final Uint8List png = await renderPhotoStoryPng(
        context,
        exif6Fixture(),
        (ui.Image image) => OutfitPhotoStoryFrame(result: _outfit, photo: image),
      );
      story = await Pixels.decode(png);
    });

    expect(w, 120, reason: 'stored 160×120, displayed 120×160');
    expect(h, 160);
    expect(decoded.isNear(60, 10, exifTopColor, tol: 24), isTrue,
        reason: 'the red half is on TOP once upright');
    expect(decoded.isNear(60, 150, exifBottomColor, tol: 24), isTrue);

    final PhotoStoryLayout layout =
        PhotoStoryLayout.compute(photoAspect: 120 / 160);
    expect(layout.photo.height, greaterThan(layout.photo.width),
        reason: 'portrait card');
    final Rect photo = _px(layout.photo);
    expect(
        story.isNear(photo.center.dx.round(), (photo.top + 40).round(),
            exifTopColor,
            tol: 24),
        isTrue);
    expect(
        story.isNear(photo.center.dx.round(), (photo.bottom - 40).round(),
            exifBottomColor,
            tol: 24),
        isTrue);
  });

  testWidgets(
      'a 9:16 photo is clamped to 5:8 (259 × 415): trimmed evenly top and '
      'bottom, full width kept', (WidgetTester tester) async {
    final BuildContext context = await _pumpHost(tester);
    late Pixels px;
    await tester.runAsync(() async {
      final Uint8List photo = await quadrantPhoto(900, 1600);
      final Uint8List png = await renderPhotoStoryPng(
        context,
        photo,
        (ui.Image image) => OutfitPhotoStoryFrame(result: _outfit, photo: image),
      );
      px = await Pixels.decode(png);
    });
    final PhotoStoryLayout layout =
        PhotoStoryLayout.compute(photoAspect: 9 / 16);
    expect(layout.photo.width, closeTo(259.4, 0.1));
    final Rect photo = _px(layout.photo);
    final Rect red = px.bboxOf(qTopLeft, tol: 8)!;
    final Rect violet = px.bboxOf(qBottomLeft, tol: 8)!;
    // Horizontal: nothing cut. Vertical: the split between the halves sits
    // at the card's middle (the cut was even).
    expect(red.left, closeTo(photo.left, 3));
    expect(red.bottom, closeTo(photo.center.dy, 3));
    expect(violet.top, closeTo(photo.center.dy, 3));
    expect(violet.bottom, closeTo(photo.bottom, 3));
  });

  testWidgets(
      'canvas mode: "Tu fit pide color" + the 5 pops, equal widths, no tags; '
      'a picked pop takes 40% with the "súmale" tag', (WidgetTester tester) async {
    final BuildContext context = await _pumpHost(tester);
    late Pixels plain, picked;
    await tester.runAsync(() async {
      final Uint8List photo = await illustratedOutfitPhoto(1200, 1600,
          top: const Color(0xFF2A2730), pants: const Color(0xFF8E8B93));
      plain = await Pixels.decode(await renderPhotoStoryPng(
        context,
        photo,
        (ui.Image image) =>
            OutfitPhotoStoryFrame(result: _canvasOutfit, photo: image),
      ));
      picked = await Pixels.decode(await renderPhotoStoryPng(
        context,
        photo,
        (ui.Image image) => OutfitPhotoStoryFrame(
            result: _canvasOutfit, photo: image, selectedAccentIndex: 2),
      ));
    });
    final Rect band =
        _px(PhotoStoryLayout.compute(photoAspect: 3 / 4).band);
    double segWidth(Pixels p, Color c) {
      final Rect r = p.bboxOf(c)!;
      expect(r.top, closeTo(band.top, 3));
      return r.width;
    }

    for (final Color pop in _pops) {
      expect(segWidth(plain, pop), closeTo(band.width / 5, 4));
    }
    // Picked pop: 40% of the band (its tag pill sits inside it).
    expect(segWidth(picked, _pops[2]), closeTo(band.width * 0.40, 4));
    expect(segWidth(picked, _pops[0]), closeTo(band.width * 0.15, 4));
  });

  testWidgets(
      'the photo story shows the headline + tags only: no date, kicker, '
      'caption or ARRIBA/ABAJO strip (on-screen pump of the same frame)',
      (WidgetTester tester) async {
    late ui.Image image;
    await tester.runAsync(() async {
      image = await decodeStoryPhoto(await quadrantPhoto(300, 400));
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Align(
        alignment: Alignment.topLeft,
        child: OutfitPhotoStoryFrame(result: _outfit, photo: image),
      ),
    ));
    expect(find.text(esL10n.resultRecoHeadline), findsOneWidget);
    expect(find.text(esL10n.resultTagFit.toUpperCase()), findsOneWidget);
    expect(find.text(esL10n.resultTagAdd.toUpperCase()), findsOneWidget);
    expect(find.textContaining('Fit de hoy'), findsNothing, reason: 'no date');
    expect(find.text(esL10n.resultHeroKicker.toUpperCase()), findsNothing);
    expect(find.text(esL10n.garmentUpperLabel), findsNothing);
    expect(find.text(esL10n.garmentLowerLabel), findsNothing);
    expect(find.byType(RawImage), findsOneWidget,
        reason: 'painted from the decoded bitmap, never an async Image');
    expect(find.byType(Image), findsNothing);
    image.dispose();
  });

  testWidgets(
      'SNEAKER photo story: the title on TWO lines at 32 px (CEO 2026-09-29), '
      'a 3:4 photo at 283 × 377 from y = 184, the sneaker band under it',
      (WidgetTester tester) async {
    final BuildContext context = await _pumpHost(tester);
    late Pixels px;
    await tester.runAsync(() async {
      final Uint8List photo = await quadrantPhoto(1200, 1600);
      px = await Pixels.decode(await renderPhotoStoryPng(
        context,
        photo,
        (ui.Image image) => SneakerPhotoStoryFrame(result: _kicks, photo: image),
      ));
    });
    final PhotoStoryLayout layout =
        PhotoStoryLayout.compute(photoAspect: 3 / 4, headlineLines: 2);
    expect(layout.photo.size.width, closeTo(283, 0.5));
    expect(layout.photo.size.height, 377);
    expect(layout.photo.top, 184);
    final Rect photo = _px(layout.photo);
    expect(
        px.isNear((photo.left + photo.width / 4).round(),
            (photo.top + photo.height / 4).round(), qTopLeft),
        isTrue,
        reason: 'the photo is painted where the 2-line layout puts it');
    expect(
        px.isNear((photo.right - photo.width / 4).round(),
            (photo.bottom - photo.height / 4).round(), qBottomRight),
        isTrue);
    // Headline ink in BOTH line boxes (92–130 and 130–168): two lines, not a
    // 1-line scale-down.
    bool inkIn(double top, double bottom) {
      for (int y = (top * 2.5).round(); y < (bottom * 2.5).round(); y++) {
        for (int x = 60; x < 1020; x += 3) {
          if (px.isNear(x, y, const Color(0xFF1C1826), tol: 12)) return true;
        }
      }
      return false;
    }

    expect(inkIn(92, 130), isTrue, reason: 'line 1');
    expect(inkIn(130, 168), isTrue, reason: 'line 2');
    // The sneaker hero band (display-snapped, like on screen) under the photo.
    final HeroCombo combo = HeroCombo.of(_kicks, 'es');
    final Rect band = _px(layout.band);
    for (final Color seg in <Color>[combo.base, combo.complement]) {
      final Rect r = px.bboxOf(seg)!;
      expect(r.top, closeTo(band.top, 3));
      expect(r.bottom, closeTo(band.bottom, 3));
    }
    final Rect logo = px.bboxOf(BrandColors.logoTurquoise)!;
    expect(logo.top, greaterThan(band.bottom));
    expect(logo.bottom,
        lessThan(StoryGeometry.safeBottom * StoryGeometry.pixelRatio));
  });

  test('headline fit: natural → 1 line; too wide → scaled (floor 24/32); '
      'beyond the floor → 2 lines', () {
    const TextStyle style = TextStyle(
        fontFamily: 'Roboto', fontSize: 32, fontWeight: FontWeight.w800);
    const String text = 'Toma tu pikete';
    final TextPainter tp = TextPainter(
      text: const TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final double natural = tp.width;
    tp.dispose();

    final StoryHeadlineFit fits =
        StoryHeadlineFit.of(text, style, maxWidth: natural + 1);
    expect((fits.lines, fits.scale), (1, 1.0));
    final StoryHeadlineFit scaled =
        StoryHeadlineFit.of(text, style, maxWidth: natural * 0.9);
    expect(scaled.lines, 1);
    expect(scaled.scale, closeTo(0.9, 0.001));
    expect(StoryHeadlineFit.of(text, style, maxWidth: natural * 0.7).lines, 2,
        reason: 'below the 24 px floor → 2 lines at 32');
    // The real strings at the real width (Roboto): outfit fits one line, the
    // sneaker title always takes 2 (spec §5.1).
    expect(StoryHeadlineFit.of(esL10n.resultRecoHeadline, style,
            maxWidth: StoryGeometry.contentWidth)
        .lines, 1);
    // The sneaker title (pass 2) does NOT fit naturally; with Roboto it fits
    // one line scaled above the 24 px floor (the spec's Arial proxy said 2
    // lines); StoryFrame.photo(headlineLines: 2) can force the spec's 2.
    final StoryHeadlineFit sneaker = StoryHeadlineFit.of(
        esL10n.sneakerResultTitle, AppType.display.copyWith(fontFamily: 'Roboto'),
        maxWidth: StoryGeometry.contentWidth);
    expect(sneaker.lines == 2 || sneaker.scale < 1, isTrue);
  });

  testWidgets('samples + host timings (only with PIKETE_STORY_SAMPLES=<dir>)',
      (WidgetTester tester) async {
    final String? dir = Platform.environment['PIKETE_STORY_SAMPLES'];
    if (dir == null) return;
    final BuildContext context = await _pumpHost(tester);
    final List<String> log = <String>[];
    await tester.runAsync(() async {
      Future<void> write(String name, Future<Uint8List> Function() render,
          {String? timingLabel}) async {
        final Stopwatch sw = Stopwatch()..start();
        final Uint8List png = await render();
        final int renderMs = sw.elapsedMilliseconds;
        // What the sheet does next: decode the PNG at preview size.
        sw.reset();
        final ui.Codec codec =
            await ui.instantiateImageCodec(png, targetWidth: 709);
        (await codec.getNextFrame()).image.dispose();
        codec.dispose();
        final int previewMs = sw.elapsedMilliseconds;
        File('$dir/$name').writeAsBytesSync(png);
        log.add('$name: render+encode ${renderMs}ms, preview decode '
            '${previewMs}ms, ${(png.length / 1024).round()} KB');
      }

      // Warm-up (first render compiles shaders / loads the lockup).
      await renderStoryPng(context, const OutfitStoryFrame(result: _outfit));

      final Uint8List photo34 = await illustratedOutfitPhoto(1200, 1600);
      final Uint8List photo916 = await illustratedOutfitPhoto(900, 1600);
      final Uint8List canvasPhoto = await illustratedOutfitPhoto(1200, 1600,
          top: const Color(0xFF2A2730), pants: const Color(0xFF8E8B93));
      await write(
          'story_photo_preview.png',
          () => renderPhotoStoryPng(
              context,
              photo34,
              (ui.Image i) =>
                  OutfitPhotoStoryFrame(result: _outfit, photo: i)));
      await write(
          'story_photo_916_preview.png',
          () => renderPhotoStoryPng(
              context,
              photo916,
              (ui.Image i) =>
                  OutfitPhotoStoryFrame(result: _outfit, photo: i)));
      await write(
          'story_photo_canvas_preview.png',
          () => renderPhotoStoryPng(
              context,
              canvasPhoto,
              (ui.Image i) => OutfitPhotoStoryFrame(
                  result: _canvasOutfit, photo: i, selectedAccentIndex: 1)));
      // Photo-like entropy (per-pixel noise): the realistic PNG-encode cost
      // of a real camera photo (the flat illustration compresses too well).
      final Uint8List noisy = await noisePhoto(1200, 1600);
      await write(
          'story_photo_noise_timing.png',
          () => renderPhotoStoryPng(
              context,
              noisy,
              (ui.Image i) =>
                  OutfitPhotoStoryFrame(result: _outfit, photo: i)));
      await write('story_card_preview.png',
          () => renderStoryPng(context, const OutfitStoryFrame(result: _outfit)));
      // Pass 2 (sneaker): 3:4 synthetic product shot, 2-line title.
      final Uint8List sneaker = await illustratedSneakerPhoto(1200, 1600);
      await write(
          'story_sneaker_preview.png',
          () => renderPhotoStoryPng(
              context,
              sneaker,
              (ui.Image i) =>
                  SneakerPhotoStoryFrame(result: _kicks, photo: i)));
      await write(
          'story_sneaker_card_preview.png',
          () => renderStoryPng(
              context,
              const StoryFrame.card(
                card: SneakerShareCanvas(
                  result: _kicks,
                  selectedAccentIndex: null,
                  showWatermark: false,
                ),
              )));
    });
    File('$dir/story_timings.txt').writeAsStringSync(log.join('\n'));
    // ignore: avoid_print
    print(log.join('\n'));
  });
}
