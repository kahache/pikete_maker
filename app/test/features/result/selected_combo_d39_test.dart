import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/garments.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/recolor/recolor_screen.dart';
import 'package:piketemaker/features/recolor/recolor_slot.dart';
import 'package:piketemaker/features/recolor/recolor_target.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/features/result/widgets/outfit_hero_combo_spec.dart';
import 'package:piketemaker/features/result/widgets/outfit_share_canvas.dart';
import 'package:piketemaker/features/result/widgets/outfit_story_frame.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo.dart';
import 'package:piketemaker/features/sneaker/widgets/hero_combo_band.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/features/story/story_share_sheet.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';

import '../recolor/recolor_test_helpers.dart';

/// D39 (CEO, 2026-09-30; amends D37/D38): the combo the user selects in
/// "Otras combis" is the combo the app ACTS on — the hero band (in place),
/// "Vérmelo puesto", the recolor view and both story frames. Rule b: for a
/// 3-colour combo the "súmale"/recolor colour is the FIRST non-base colour
/// in engine order. No selection (or the hero) = byte-identical to before.

final AppLocalizations es = lookupAppLocalizations(const Locale('es'));

/// A real engine result (the 4 harmonies in ENGINE order) around a red base.
final AnalysisResult engineResult = composeAnalysis(
  colors: const <List<int>>[
    <int>[200, 50, 40],
    <int>[230, 230, 225],
  ],
  weights: const <double>[0.6, 0.4],
  baseIndex: 0,
);

Harmony _h(AnalysisResult r, HarmonyType t) =>
    r.harmonies.firstWhere((Harmony h) => h.type == t);

Future<void> _pump(
  WidgetTester tester, {
  required AnalysisResult result,
  FakeOpener? opener,
  FakeImages? images,
  bool withPhoto = true,
  StorySharer? share,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: ResultScreen(
      result: result,
      photo: withPhoto ? Uint8List(8) : null,
      storyPreferences: StoryPreferencesInMemory(),
      openRecolor:
          (opener ?? FakeOpener(null, error: StateError('opener must not run')))
              .call,
      decodeRecolorPhoto: (Uint8List _) async => images!.original.clone(),
      shareStory: share ?? (File png, Rect? origin) async => 'success',
    ),
  ));
  await tester.pump();
  await tester.pump();
}

HeroCombo _bandCombo(WidgetTester tester) =>
    tester.widget<HeroComboBand>(find.byType(HeroComboBand).first).combo;

Future<void> _tapRow(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// Waits for the story sheet's PNG, then taps "Compartir".
Future<void> _shareFromSheet(WidgetTester tester) async {
  for (int i = 0; i < 80; i++) {
    final Finder cta = find.descendant(
        of: find.byKey(StorySharePreviewSheet.ctaKey),
        matching: find.byType(FilledButton));
    if (cta.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(cta).onPressed != null) {
      break;
    }
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.runAsync(() async {
    await tester.tap(find.text(es.storyShareCta));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

void main() {
  group('rule b: the partner of each scheme (engine order)', () {
    final Color base = engineResult.base!.color;

    test('complementary = colors[1], exactly the pre-D39 pick', () {
      final Harmony h = _h(engineResult, HarmonyType.complementary);
      expect(HeroCombo.partnerColor(h, base), h.colors[1]);
    });

    test('triadic = +120° and split = +150° (index 1)', () {
      for (final HarmonyType t in <HarmonyType>[
        HarmonyType.triadic,
        HarmonyType.splitComplementary,
      ]) {
        final Harmony h = _h(engineResult, t);
        expect(h.colors.first, base, reason: '$t starts at the base');
        expect(HeroCombo.partnerColor(h, base), h.colors[1], reason: '$t');
      }
    });

    test('analogous = −30° (index 0, before the base)', () {
      final Harmony h = _h(engineResult, HarmonyType.analogous);
      expect(h.colors[1], base, reason: 'engine order [-30, base, +30]');
      expect(HeroCombo.partnerColor(h, base), h.colors[0]);
    });

    test('scheme null / complementary / absent → the hero, field by field', () {
      final HeroCombo legacy =
          HeroCombo.of(engineResult, 'es', snapForDisplay: false);
      for (final HarmonyType? s in <HarmonyType?>[
        null,
        HarmonyType.complementary,
      ]) {
        final HeroCombo c =
            HeroCombo.of(engineResult, 'es', snapForDisplay: false, scheme: s);
        expect(c.base, legacy.base);
        expect(c.complement, legacy.complement);
        expect(c.neutral, legacy.neutral);
        expect(c.complementName, legacy.complementName);
        expect(c.neutralName, legacy.neutralName);
      }
      // outfitResult() carries no split-complementary harmony.
      final AnalysisResult r = outfitResult();
      expect(
          HeroCombo.of(r, 'es',
                  snapForDisplay: false, scheme: HarmonyType.splitComplementary)
              .complement,
          kDenim);
    });

    test('RecolorTarget follows the scheme; canvas ignores it', () {
      final RecolorTarget t =
          RecolorTarget.of(engineResult, 'es', scheme: HarmonyType.triadic);
      expect(t.color, _h(engineResult, HarmonyType.triadic).colors[1]);
      expect(
          t.name,
          HeroCombo.of(engineResult, 'es',
                  snapForDisplay: false, scheme: HarmonyType.triadic)
              .complementName);
      expect(
          RecolorTarget.of(canvasResult(), 'es',
                  selectedAccentIndex: 1, scheme: HarmonyType.triadic)
              .color,
          kPlum);
    });

    test('the kicker names the selected combo; the hero keeps its own', () {
      expect(outfitHeroKicker(es, null), es.resultHeroKicker);
      expect(
          outfitHeroKicker(es, HarmonyType.complementary), es.resultHeroKicker);
      expect(outfitHeroKicker(es, HarmonyType.triadic),
          'La combi · ${es.sneakerHarmonyTriadicName}');
      expect(outfitHeroKicker(es, HarmonyType.analogous),
          'La combi · ${es.sneakerHarmonyAnalogousName}');
      expect(outfitHeroKicker(es, HarmonyType.splitComplementary),
          'La combi · ${es.sneakerHarmonySplitName}');
    });
  });

  group('the result acts on the selected combo', () {
    testWidgets(
        'selecting a row swaps the hero band IN PLACE (partner + kicker); '
        're-tapping it returns to the main combo; the row stays highlighted',
        (WidgetTester tester) async {
      await _pump(tester, result: outfitResult());
      expect(_bandCombo(tester).complement, kDenim);
      expect(find.text(es.resultHeroKicker.toUpperCase()), findsOneWidget);
      double offsetInCanvas() =>
          tester.getRect(find.byKey(ResultScreen.heroBandKey)).top -
          tester.getRect(find.byType(OutfitShareCanvas)).top;
      final Size size = tester.getSize(find.byKey(ResultScreen.heroBandKey));
      final double offset = offsetInCanvas();

      await _tapRow(tester, es.sneakerHarmonyTriadicName);
      expect(_bandCombo(tester).complement, kOlive,
          reason: 'triadic partner (first non-base)');
      expect(_bandCombo(tester).base, kRust, reason: '"tu fit" unchanged');
      expect(
          find.text(
              es.resultComboKicker(es.sneakerHarmonyTriadicName).toUpperCase()),
          findsOneWidget);
      expect(tester.getSize(find.byKey(ResultScreen.heroBandKey)), size,
          reason: 'in place: same size');
      expect(offsetInCanvas(), offset, reason: 'in place: same slot');
      expect(find.text(es.sneakerHarmonyTriadicName), findsOneWidget,
          reason: 'no complementary row is added to "Otras combis"');

      await _tapRow(tester, es.sneakerHarmonyTriadicName);
      expect(_bandCombo(tester).complement, kDenim);
      expect(find.text(es.resultHeroKicker.toUpperCase()), findsOneWidget);
    });

    testWidgets(
        '"Vérmelo puesto" paints the selected combo\'s partner and the view '
        'shows that band; after deselecting it is the hero again',
        (WidgetTester tester) async {
      final FakeImages images = FakeImages();
      await tester.runAsync(images.create);
      final FakeRecolorSession base = FakeRecolorSession(kBoth, images: images);
      await _pump(tester,
          result: outfitResult(map: kFakeClassMap),
          opener: FakeOpener(base),
          images: images);

      await _tapRow(tester, es.sneakerHarmonyAnalogousName);
      await tester.tap(find.byKey(RecolorSlot.pillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(base.spawned.last.target, kMustard,
          reason: 'analogous partner in this fixture\'s order');
      final RecolorScreen view =
          tester.widget<RecolorScreen>(find.byType(RecolorScreen));
      expect(view.selectedScheme, HarmonyType.analogous);
      expect(view.target.color, kMustard);
      expect(_bandCombo(tester).complement, kMustard);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapRow(tester, es.sneakerHarmonyAnalogousName); // deselect
      await tester.tap(find.byKey(RecolorSlot.pillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(base.spawned.last.target, kDenim);
      expect(
          tester
              .widget<RecolorScreen>(find.byType(RecolorScreen))
              .selectedScheme,
          isNull);
    });

    testWidgets('canvas mode: no "Otras combis", the pop still drives it',
        (WidgetTester tester) async {
      await _pump(tester, result: canvasResult());
      expect(find.text(es.sneakerHarmonyTriadicName), findsNothing);
      expect(find.byType(HeroComboBand), findsNothing);
    });
  });

  group('the story shares the selected combo', () {
    late Directory tmp;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('pk_d39_story_');
      storyCacheDirectory = () => tmp;
    });
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    testWidgets(
        'result, no photo: the card-only PNG is the SELECTED combo\'s card '
        '(byte-identical to a reference render, not the hero\'s)',
        (WidgetTester tester) async {
      final List<Uint8List> shared = <Uint8List>[];
      await _pump(tester, result: outfitResult(), withPhoto: false,
          share: (File png, Rect? origin) async {
        shared.add(png.readAsBytesSync());
        return 'success';
      });
      await _tapRow(tester, es.sneakerHarmonyTriadicName);
      await tester.ensureVisible(find.text(es.resultCtaStory));
      await tester.tap(find.text(es.resultCtaStory));
      await tester.pumpAndSettle();
      await _shareFromSheet(tester);
      expect(shared, hasLength(1));

      final BuildContext host = tester.element(find.byType(ResultScreen));
      Uint8List? selected;
      Uint8List? hero;
      await tester.runAsync(() async {
        selected = await renderStoryPng(
            host,
            OutfitStoryFrame(
                result: outfitResult(), selectedScheme: HarmonyType.triadic));
        hero = await renderStoryPng(
            host, OutfitStoryFrame(result: outfitResult()));
      });
      expect(shared.single, selected);
      expect(shared.single, isNot(hero));
    });

    testWidgets(
        'recolor view: the photo story carries the selected combo\'s band '
        'with "Así te quedaría"', (WidgetTester tester) async {
      final FakeImages images = FakeImages();
      await tester.runAsync(images.create);
      final List<Uint8List> shared = <Uint8List>[];
      await _pump(tester,
          result: outfitResult(map: kFakeClassMap),
          opener: FakeOpener(FakeRecolorSession(kBoth, images: images)),
          images: images, share: (File png, Rect? origin) async {
        shared.add(png.readAsBytesSync());
        return 'success';
      });
      await _tapRow(tester, es.sneakerHarmonyTriadicName);
      await tester.tap(find.byKey(RecolorSlot.pillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(RecolorScreen.ctaKey));
      await tester.pumpAndSettle();
      await _shareFromSheet(tester);
      expect(shared, hasLength(1));

      final BuildContext host = tester.element(find.byType(RecolorScreen));
      Uint8List? expected;
      Uint8List? heroBand;
      await tester.runAsync(() async {
        final ui.Image upper = images.upper.clone();
        expected = await renderStoryPng(
            host,
            OutfitPhotoStoryFrame(
              result: outfitResult(map: kFakeClassMap),
              photo: upper,
              headline: es.recolorHeadline,
              selectedScheme: HarmonyType.triadic,
            ));
        heroBand = await renderStoryPng(
            host,
            OutfitPhotoStoryFrame(
              result: outfitResult(map: kFakeClassMap),
              photo: upper,
              headline: es.recolorHeadline,
            ));
        upper.dispose();
      });
      expect(shared.single, expected);
      expect(shared.single, isNot(heroBand));
    });
  });
}
