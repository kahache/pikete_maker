import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/recolor/recolor_service.dart';
import 'package:piketemaker/core/segmentation/recolor_applicability.dart';
import 'package:piketemaker/features/recolor/recolor_screen.dart';
import 'package:piketemaker/features/recolor/recolor_slot.dart';
import 'package:piketemaker/features/recolor/widgets/recolor_photo_card.dart';
import 'package:piketemaker/features/recolor/widgets/region_selector.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/features/result/widgets/outfit_story_frame.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/features/story/story_share_sheet.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:piketemaker/widgets/pk_buttons.dart';

import 'recolor_test_helpers.dart';

/// I2 "Vérmelo puesto" (D38) pass 2 — the UI on the outfit result: the slot
/// (pill / tip / nothing), the recolor view (regions, press-and-hold,
/// loading, failure, disposal) and the D37 story hand-off. The engine is
/// faked ([FakeRecolorSession]); its own tests live in test/core/recolor.

final AppLocalizations es = lookupAppLocalizations(const Locale('es'));

Future<String> _neverShare(File png, Rect? origin) async =>
    fail('no share expected');

Future<void> _pumpResult(
  WidgetTester tester, {
  required AnalysisResult result,
  FakeOpener? opener,
  FakeImages? images,
  Uint8List? photo,
  bool withPhoto = true,
  Size size = const Size(390, 844),
  StorySharer share = _neverShare,
  StoryFileWriter write = writeStoryPng,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final FakeOpener o =
      opener ?? FakeOpener(null, error: StateError('opener must not run'));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: ResultScreen(
      result: result,
      photo: withPhoto ? (photo ?? Uint8List(8)) : null,
      storyPreferences: StoryPreferencesInMemory(),
      openRecolor: o.call,
      decodeRecolorPhoto: (Uint8List _) async => images!.original.clone(),
      shareStory: share,
      writeStoryFile: write,
    ),
  ));
  await tester.pump(); // post-frame: the assessment starts
  await tester.pump(); // …and lands
}

Future<void> _openView(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(RecolorSlot.pillKey));
  await tester.tap(find.byKey(RecolorSlot.pillKey));
  // Not pumpAndSettle: while the recolor renders, the progress line is an
  // indeterminate (endless) animation.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

RawImage? _recoloredLayer(WidgetTester tester, GarmentRegion region) {
  final Finder f = find.byKey(ValueKey<GarmentRegion>(region));
  return f.evaluate().isEmpty ? null : tester.widget<RawImage>(f);
}

bool _pillEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.descendant(
            of: find.byKey(RecolorSlot.pillKey),
            matching: find.byType(FilledButton)))
        .onPressed !=
    null;

bool _ctaEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.descendant(
            of: find.byKey(RecolorScreen.ctaKey),
            matching: find.byType(FilledButton)))
        .onPressed !=
    null;

void main() {
  late FakeImages images;

  group('the slot on the result', () {
    testWidgets('no segmentation map (S4 / flag off): no pill, no tip',
        (WidgetTester tester) async {
      final FakeOpener opener = FakeOpener(FakeRecolorSession(kBoth));
      await _pumpResult(tester, result: outfitResult(), opener: opener);
      expect(find.byKey(RecolorSlot.slotKey), findsNothing);
      expect(find.text(es.recolorCta), findsNothing);
      expect(opener.calls, 0, reason: 'nothing is assessed');
    });

    testWidgets('legacy layout or no photo: no slot either',
        (WidgetTester tester) async {
      final FakeOpener opener = FakeOpener(FakeRecolorSession(kBoth));
      await _pumpResult(tester,
          result: outfitResult(map: kFakeClassMap, legacy: true),
          opener: opener);
      expect(find.byKey(RecolorSlot.slotKey), findsNothing);
      await _pumpResult(tester,
          result: outfitResult(map: kFakeClassMap),
          opener: opener,
          withPhoto: false);
      expect(find.byKey(RecolorSlot.slotKey), findsNothing);
      expect(opener.calls, 0);
    });

    testWidgets(
        'CEO amendment: "Vérmelo puesto" is the FIRST CTA of the bottom block '
        '(disabled while assessing, same size), then the story, then the '
        'looks — all three outlined, visible without scrolling',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      final FakeOpener opener =
          FakeOpener(FakeRecolorSession(kBoth), gate: gate);
      await _pumpResult(tester,
          result: outfitResult(map: kFakeClassMap), opener: opener);
      expect(opener.calls, 1);
      expect(opener.target, kDenim, reason: 'the hero "súmale" colour');
      expect(_pillEnabled(tester), isFalse, reason: 'pending = disabled');
      final Size pending = tester.getSize(find.byKey(RecolorSlot.slotKey));
      expect(find.byKey(RecolorSlot.tipKey), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(_pillEnabled(tester), isTrue);
      expect(tester.getSize(find.byKey(RecolorSlot.slotKey)), pending,
          reason: 'no layout jump');

      final Rect pill = tester.getRect(find.byKey(RecolorSlot.pillKey));
      final Rect story = tester.getRect(find.text(es.resultCtaStory));
      final Rect looks = tester.getRect(find.text(es.resultCtaLooks));
      expect(pill.bottom, lessThan(story.top));
      expect(story.bottom, lessThan(looks.top));
      expect(looks.bottom, lessThanOrEqualTo(844), reason: 'above the fold');
      // Outside the scroll area: the card is above the whole block.
      final Rect hero = tester.getRect(find.byKey(ResultScreen.heroBandKey));
      expect(hero.bottom, lessThan(pill.top));
      // CEO 2026-09-30 (r17): all three FILLED with white text, mint ·
      // purple · mint — the story is the single purple one.
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(FilledButton), findsNWidgets(3));
      expect(find.byType(PkAccentButton), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(PkAccentButton),
              matching: find.text(es.resultCtaStory)),
          findsOneWidget);
      expect(find.byType(PkPrimaryButton), findsNWidgets(2));
    });

    testWidgets('not eligible: the block has only the story and the looks',
        (WidgetTester tester) async {
      await _pumpResult(tester, result: outfitResult());
      expect(find.byKey(RecolorSlot.slotKey), findsNothing);
      expect(find.byType(FilledButton), findsNWidgets(2));
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(PkAccentButton), findsOneWidget);
      expect(tester.getRect(find.text(es.resultCtaStory)).bottom,
          lessThan(tester.getRect(find.text(es.resultCtaLooks)).top));
    });

    testWidgets(
        'small phone (360×640): the three CTAs fit and the content above '
        'still scrolls', (WidgetTester tester) async {
      await _pumpResult(tester,
          result: outfitResult(map: kFakeClassMap),
          opener: FakeOpener(FakeRecolorSession(kBoth)),
          size: const Size(360, 640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(tester.getRect(find.text(es.resultCtaLooks)).bottom,
          lessThanOrEqualTo(640));
      final Finder scroll = find.byType(SingleChildScrollView);
      expect(tester.getSize(scroll).height, greaterThan(100));
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(es.sneakerSectionTitle));
      expect(find.text(es.sneakerSectionTitle).hitTestable(), findsOneWidget);
    });

    final Map<RecolorBlocker, String?> tips = <RecolorBlocker, String?>{
      RecolorBlocker.severalPeople: es.recolorTipPeople,
      RecolorBlocker.poorLight: es.recolorTipLight,
      RecolorBlocker.maskUnreliable: es.recolorTipCoverage,
      RecolorBlocker.regionTooSmall: es.recolorTipCoverage,
      RecolorBlocker.noSegmentation: null,
    };
    for (final MapEntry<RecolorBlocker, String?> e in tips.entries) {
      testWidgets('${e.key.name} → ${e.value == null ? 'nothing' : 'tip'}',
          (WidgetTester tester) async {
        await _pumpResult(tester,
            result: outfitResult(map: kFakeClassMap),
            opener: FakeOpener(FakeRecolorSession(blocked(e.key))));
        expect(find.byKey(RecolorSlot.pillKey), findsNothing);
        if (e.value == null) {
          expect(find.byKey(RecolorSlot.slotKey), findsNothing);
        } else {
          expect(find.text(e.value!), findsOneWidget);
        }
      });
    }

    testWidgets('a refused assessment (e.g. the EXIF guard): nothing',
        (WidgetTester tester) async {
      await _pumpResult(tester,
          result: outfitResult(map: kFakeClassMap),
          opener: FakeOpener(null, error: const RecolorException('mismatch')));
      expect(find.byKey(RecolorSlot.slotKey), findsNothing);
    });

    testWidgets('the result disposes its assessed session',
        (WidgetTester tester) async {
      final FakeRecolorSession base = FakeRecolorSession(kBoth);
      await _pumpResult(tester,
          result: outfitResult(map: kFakeClassMap), opener: FakeOpener(base));
      await tester.pumpWidget(const SizedBox());
      expect(base.disposed, isTrue);
    });
  });

  group('the recolor view', () {
    setUp(() => images = FakeImages());

    Future<FakeRecolorSession> openView(WidgetTester tester,
        {RecolorAvailability availability = kBoth,
        Completer<void>? gate,
        bool fail = false,
        AnalysisResult? result}) async {
      await tester.runAsync(images.create);
      final FakeRecolorSession base = FakeRecolorSession(availability,
          images: images, gate: gate, fail: fail);
      await _pumpResult(tester,
          result: result ?? outfitResult(map: kFakeClassMap),
          opener: FakeOpener(base),
          images: images);
      await _openView(tester);
      return base;
    }

    testWidgets(
        'opens on the NON-base region with its kicker, both segments, the '
        'expectation line and the story CTA — bound to the hero colour',
        (WidgetTester tester) async {
      final FakeRecolorSession base = await openView(tester);
      final FakeRecolorSession view = base.spawned.single;
      expect(view.target, kDenim);
      expect(view.renders, 1, reason: 'renderAll starts on entry');

      expect(find.text(es.recolorHeadline), findsOneWidget);
      final String kicker =
          tester.widget<Text>(find.byKey(RecolorScreen.kickerKey)).data!;
      expect(kicker, startsWith(es.garmentUpperLabel.toUpperCase()));
      expect(kicker, contains(' · '));
      expect(find.text(es.recolorExpectation), findsOneWidget);
      expect(find.byType(RegionSelector), findsOneWidget);
      expect(find.text(es.resultCtaStory), findsOneWidget);
      expect(
          _recoloredLayer(tester, GarmentRegion.upper)!
              .image!
              .isCloneOf(images.upper),
          isTrue);
      expect(find.text(es.recolorHoldHint.toUpperCase()), findsOneWidget);
      expect(find.byKey(RecolorPhotoCard.progressKey), findsNothing);
      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('ABAJO / ARRIBA switch instantly (cached, no re-render)',
        (WidgetTester tester) async {
      final FakeRecolorSession base = await openView(tester);
      await tester
          .tap(find.byKey(RegionSelector.segmentKey(GarmentRegion.lower)));
      await tester.pumpAndSettle();
      expect(
          _recoloredLayer(tester, GarmentRegion.lower)!
              .image!
              .isCloneOf(images.lower),
          isTrue);
      expect(tester.widget<Text>(find.byKey(RecolorScreen.kickerKey)).data,
          startsWith(es.garmentLowerLabel.toUpperCase()));
      await tester
          .tap(find.byKey(RegionSelector.segmentKey(GarmentRegion.upper)));
      await tester.pumpAndSettle();
      expect(_recoloredLayer(tester, GarmentRegion.upper), isNotNull);
      expect(base.spawned.single.renders, 1);
    });

    testWidgets('one region: the selector is hidden',
        (WidgetTester tester) async {
      await openView(tester, availability: kUpperOnly);
      expect(find.byType(RegionSelector), findsNothing);
      expect(_recoloredLayer(tester, GarmentRegion.upper), isNotNull);
    });

    testWidgets(
        'press-and-hold anywhere on the photo shows the original (chip '
        '"Original"), release brings the recolor back (200 ms cross-fade)',
        (WidgetTester tester) async {
      await openView(tester);
      final TestGesture finger = await tester.startGesture(
          tester.getCenter(find.byKey(RecolorPhotoCard.photoKey)));
      await tester.pump();
      expect(find.text(es.recolorHoldActive.toUpperCase()), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_recoloredLayer(tester, GarmentRegion.upper), isNull,
          reason: 'faded out: the original shows');
      expect(find.byKey(RecolorPhotoCard.originalKey), findsOneWidget);

      await finger.up();
      await tester.pump();
      expect(find.text(es.recolorHoldHint.toUpperCase()), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_recoloredLayer(tester, GarmentRegion.upper), isNotNull);
    });

    testWidgets(
        'loading: the original + a progress line, CTA disabled; then the '
        'recolor lands', (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      await openView(tester, gate: gate);
      expect(find.byKey(RecolorPhotoCard.progressKey), findsOneWidget);
      expect(find.byKey(RecolorPhotoCard.originalKey), findsOneWidget);
      expect(_recoloredLayer(tester, GarmentRegion.upper), isNull);
      expect(find.byKey(RecolorPhotoCard.chipKey), findsNothing);
      expect(_ctaEnabled(tester), isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(RecolorPhotoCard.progressKey), findsNothing);
      expect(_recoloredLayer(tester, GarmentRegion.upper), isNotNull);
      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets(
        'a RecolorException: back on the result with recolorFailedSnack',
        (WidgetTester tester) async {
      await openView(tester, fail: true);
      await tester.pumpAndSettle();
      expect(find.byType(RecolorScreen), findsNothing);
      expect(find.text(es.recolorFailedSnack), findsOneWidget);
      expect(find.byKey(RecolorSlot.pillKey), findsOneWidget);
    });

    testWidgets(
        'back disposes the session and releases every bitmap; the result '
        'can open the view again', (WidgetTester tester) async {
      final FakeRecolorSession base = await openView(tester);
      final FakeRecolorSession view = base.spawned.single;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RecolorScreen), findsNothing);
      expect(view.disposed, isTrue);
      expect(base.disposed, isFalse, reason: 'the verdict stays');
      for (final ui.Image image in view.handedOut) {
        expect(image.debugDisposed, isTrue);
      }

      await _openView(tester);
      expect(base.spawned, hasLength(2));
      expect(find.byType(RecolorScreen), findsOneWidget);
    });

    testWidgets('canvas mode: the first pop by default',
        (WidgetTester tester) async {
      final FakeRecolorSession base =
          await openView(tester, result: canvasResult(map: kFakeClassMap));
      expect(base.spawned.single.target, kMustard);
    });
  });

  group('the story hand-off (D37 sheet, unchanged)', () {
    late Directory tmp;
    setUp(() {
      images = FakeImages();
      tmp = Directory.systemTemp.createTempSync('pk_recolor_story_');
      storyCacheDirectory = () => tmp;
    });
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    testWidgets(
        'shares the RECOLORED bitmap with "Así te quedaría"; the only file is '
        'the story PNG, deleted when the sheet closes; no bitmap on disk',
        (WidgetTester tester) async {
      await tester.runAsync(images.create);
      final List<Uint8List> shared = <Uint8List>[];
      final List<String> written = <String>[];
      Future<File> spyWrite(Uint8List png) async {
        final File f = await writeStoryPng(png);
        written.add(f.path);
        return f;
      }

      final FakeRecolorSession base = FakeRecolorSession(kBoth, images: images);
      await _pumpResult(
        tester,
        result: outfitResult(map: kFakeClassMap),
        opener: FakeOpener(base),
        images: images,
        write: spyWrite,
        share: (File png, Rect? origin) async {
          shared.add(png.readAsBytesSync());
          return 'success';
        },
      );
      await _openView(tester);
      await tester
          .tap(find.byKey(RegionSelector.segmentKey(GarmentRegion.lower)));
      await tester.pumpAndSettle();
      expect(tmp.listSync(), isEmpty, reason: 'nothing on disk so far');

      await tester.tap(find.byKey(RecolorScreen.ctaKey));
      await tester.pumpAndSettle();
      for (int i = 0; i < 80; i++) {
        final Finder cta = find.descendant(
            of: find.byKey(StorySharePreviewSheet.ctaKey),
            matching: find.byType(FilledButton));
        if (cta.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(cta).onPressed != null) {
          break;
        }
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue,
          reason: '"Incluir mi foto" default ON, as r14');
      expect(find.text(es.storyPhotoPrivacy), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text(es.storyShareCta));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(written, hasLength(1));
      expect(written.single, endsWith(kStoryFileName));
      expect(tmp.listSync(), isEmpty,
          reason: 'the story file is deleted when the sheet closes');

      // The shared PNG IS the photo story of the recolored ABAJO bitmap with
      // the view's headline: byte-identical to a reference render.
      final BuildContext host = tester.element(find.byType(RecolorScreen));
      Uint8List? expected;
      Uint8List? defaultHeadline;
      await tester.runAsync(() async {
        final ui.Image lower = images.lower.clone();
        expected = await renderStoryPng(
            host,
            OutfitPhotoStoryFrame(
                result: outfitResult(map: kFakeClassMap),
                photo: lower,
                headline: es.recolorHeadline));
        defaultHeadline = await renderStoryPng(
            host,
            OutfitPhotoStoryFrame(
                result: outfitResult(map: kFakeClassMap), photo: lower));
        lower.dispose();
      });
      expect(shared.single, expected);
      expect(shared.single, isNot(defaultHeadline),
          reason: 'the headline is "Así te quedaría", not "Toma tu pikete"');
    });
  });
}
