import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/core/recolor/recolor_service.dart';
import 'package:piketemaker/core/segmentation/recolor_applicability.dart';
import 'package:piketemaker/features/analyzing/analyzing_screen.dart';
import 'package:piketemaker/features/capture/capture_screen.dart';
import 'package:piketemaker/features/capture/flow_mode.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/feedback/feedback_screen.dart';
import 'package:piketemaker/features/home/home_screen.dart';
import 'package:piketemaker/features/onboarding/onboarding_screen.dart';
import 'package:piketemaker/features/recolor/recolor_screen.dart';
import 'package:piketemaker/features/recolor/recolor_target.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:piketemaker/features/sneaker/sneaker_source_selector.dart';
import 'package:piketemaker/features/sneaker/sneaker_tip_illustrations.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:piketemaker/widgets/pk_buttons.dart';

import '../features/recolor/recolor_test_helpers.dart';

/// Locale-switch SMOKE suite (i18n round, D18 extended to 7 locales):
/// every key screen must RENDER in each supported locale on a phone-sized
/// viewport without throwing — the failure this hunts is the RenderFlex
/// overflow caused by copy length differences (CJK vs Latin, long fr/ca CTAs
/// on the pill buttons and labels).
///
/// Caveat (flagged in the round's report): the test font renders every glyph
/// at 1em, so latin copy measures WIDER than production while CJK measures
/// the same — this net is conservative for Latin locales and approximate for
/// CJK; a device pass over zh/ko/ja stays on the native-review checklist.
void main() {
  /// Valid 1×1 px PNG (same fixture as critical_flow_test).
  final Uint8List photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  const Color red = Color(0xFFD62828);
  const Color teal = Color(0xFF2E9E86);
  const Color dark = Color(0xFF23211F);
  const Color light = Color(0xFFEDE9E1);

  Harmony harmony(HarmonyType type, String name) => Harmony(
        type: type,
        name: name, // engine literals; the UI maps labels by TYPE via l10n
        description: '—',
        colors: const <Color>[red, teal],
      );

  final AnalysisResult chromaticResult = AnalysisResult(
    baseIndex: 0,
    palette: const <ColorSample>[
      ColorSample(color: red, weight: 0.45),
      ColorSample(color: dark, weight: 0.35),
      ColorSample(color: light, weight: 0.20),
    ],
    harmonies: <Harmony>[
      harmony(HarmonyType.complementary, 'Complementario'),
      harmony(HarmonyType.analogous, 'Análogo'),
      harmony(HarmonyType.triadic, 'Triádico'),
      harmony(HarmonyType.splitComplementary, 'Complementario dividido'),
    ],
  );

  const AnalysisResult canvasResult = AnalysisResult(
    baseIndex: -1,
    palette: <ColorSample>[
      ColorSample(color: dark, weight: 0.7),
      ColorSample(color: light, weight: 0.3),
    ],
    harmonies: <Harmony>[],
    canvasAccents: <Color>[
      red,
      teal,
      Color(0xFF2450D9),
      Color(0xFFE8A020),
      Color(0xFFB33FBF)
    ],
  );

  final AnalysisResult garmentsResult = AnalysisResult(
    baseIndex: 0,
    palette: chromaticResult.palette,
    harmonies: chromaticResult.harmonies,
    segmentationLayout: SegmentationLayouts.garments,
    garments: const <GarmentBlockData>[
      GarmentBlockData(
        region: GarmentRegion.upper,
        palette: <ColorSample>[
          ColorSample(color: red, weight: 0.8),
          ColorSample(color: light, weight: 0.2),
        ],
        baseIndex: 0,
        globalBaseIndex: 0,
      ),
      GarmentBlockData(
        region: GarmentRegion.lower,
        palette: <ColorSample>[
          ColorSample(color: dark, weight: 1.0),
        ],
        baseIndex: -1,
        globalBaseIndex: -1,
      ),
    ],
  );

  // D36 canvas: 100% neutral outfit on the segmented path → the curated pops
  // are promoted to the hero, with the new canvas headline/kicker/caption.
  final AnalysisResult garmentsCanvasResult = AnalysisResult(
    baseIndex: -1,
    palette: canvasResult.palette,
    harmonies: const <Harmony>[],
    canvasAccents: canvasResult.canvasAccents,
    segmentationLayout: SegmentationLayouts.garments,
    garments: const <GarmentBlockData>[
      GarmentBlockData(
        region: GarmentRegion.upper,
        palette: <ColorSample>[ColorSample(color: dark, weight: 1.0)],
        baseIndex: -1,
        globalBaseIndex: -1,
      ),
      GarmentBlockData(
        region: GarmentRegion.lower,
        palette: <ColorSample>[ColorSample(color: light, weight: 1.0)],
        baseIndex: -1,
        globalBaseIndex: -1,
      ),
    ],
  );

  Widget localized(Locale locale, Widget home) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        theme: AppTheme.light(),
        home: home,
      );

  Future<void> pumpPhoneSized(
    WidgetTester tester,
    Locale locale,
    Widget home, {
    Duration settle = const Duration(milliseconds: 400),
    Size logicalSize = const Size(390, 844),
  }) async {
    tester.view.physicalSize = logicalSize * 3; // default 390×844 @3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(localized(locale, home));
    await tester.pump(settle);
    expect(
      tester.takeException(),
      isNull,
      reason: 'threw (likely overflow) under locale "$locale" for $home',
    );
  }

  for (final Locale locale in kSupportedLocales) {
    group('locale $locale', () {
      testWidgets('Home renders', (WidgetTester tester) async {
        final OnboardingServiceInMemory onboarding =
            OnboardingServiceInMemory();
        await onboarding.markSeen(); // no tutorial auto-push
        await pumpPhoneSized(
          tester,
          locale,
          HomeScreen(onboarding: onboarding, picker: _NullPicker()),
        );
        expect(find.byKey(HomeScreen.sneakerZoneKey), findsOneWidget);
      });

      testWidgets('Onboarding (both pages) renders',
          (WidgetTester tester) async {
        await pumpPhoneSized(
          tester,
          locale,
          OnboardingScreen(onboarding: OnboardingServiceInMemory()),
        );
        // Page 2 (the CJK-heavy pro-tip page with the highlight loop).
        await tester.tap(find.byType(PkPrimaryButton));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull,
            reason: 'ONB-2 threw under locale "$locale"');
        // Dispose the highlight-loop ticker before the test ends.
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Sneaker source selector + the 3 mini-tutorials render',
          (WidgetTester tester) async {
        await pumpPhoneSized(
            tester, locale, const SneakerSourceSelectorScreen());
        for (final SneakerTipCase tipCase in SneakerTipCase.values) {
          await pumpPhoneSized(
              tester, locale, SneakerSourceTipScreen(tipCase: tipCase));
        }
      });

      testWidgets('Confirm (outfit + sneaker) renders',
          (WidgetTester tester) async {
        for (final FlowMode mode in FlowMode.values) {
          await pumpPhoneSized(
            tester,
            locale,
            CaptureScreen(
              args: CaptureArgs(photo: photo, mode: mode),
              picker: _NullPicker(),
            ),
          );
        }
      });

      testWidgets('Analyzing (outfit + sneaker) renders',
          (WidgetTester tester) async {
        for (final FlowMode mode in FlowMode.values) {
          await pumpPhoneSized(
            tester,
            locale,
            AnalyzingScreen(
              engine: _HangingEngine(),
              picker: _NullPicker(),
              args: AnalyzingArgs(photo: photo, mode: mode),
            ),
            settle: const Duration(milliseconds: 300),
          );
          // Dispose the progress ticker cleanly before the next mode.
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('Ugly states (all) render', (WidgetTester tester) async {
        for (final UglyState state in UglyState.values) {
          await pumpPhoneSized(
            tester,
            locale,
            FeedbackScreen(args: FeedbackArgs(state: state)),
          );
        }
      });

      testWidgets('Outfit result (chromatic, canvas, garments) renders',
          (WidgetTester tester) async {
        for (final AnalysisResult result in <AnalysisResult>[
          chromaticResult,
          canvasResult,
          garmentsResult,
          garmentsCanvasResult,
        ]) {
          await pumpPhoneSized(tester, locale, ResultScreen(result: result));
        }
      });

      testWidgets(
          'Outfit result with the I2 CTA (pill + the 3 tips) renders; the '
          'three CTAs sit on screen at 390×844 and 360×640',
          (WidgetTester tester) async {
        for (final Size size in const <Size>[Size(390, 844), Size(360, 640)]) {
          for (final RecolorAvailability availability in <RecolorAvailability>[
            kBoth,
            blocked(RecolorBlocker.severalPeople),
            blocked(RecolorBlocker.poorLight),
            blocked(RecolorBlocker.regionTooSmall),
          ]) {
            await pumpPhoneSized(
              tester,
              locale,
              ResultScreen(
                // A fresh State per case (the slot is assessed in initState).
                key: ValueKey<String>('$size ${availability.blocker}'),
                result: garmentsResult.withSegmentationClassMap(kFakeClassMap),
                photo: photo,
                openRecolor: FakeOpener(FakeRecolorSession(availability)).call,
              ),
              logicalSize: size,
            );
            final int ctas = availability.isAvailable ? 3 : 2;
            expect(find.byType(FilledButton), findsNWidgets(ctas));
            for (final Element e in find.byType(FilledButton).evaluate()) {
              final Rect r = tester.getRect(find.byWidget(e.widget));
              expect(r.bottom, lessThanOrEqualTo(size.height),
                  reason: 'CTA off screen under "$locale" at $size');
            }
          }
        }
      });

      testWidgets('Recolor view (2 regions, 1 region, canvas) renders',
          (WidgetTester tester) async {
        final FakeImages images = FakeImages();
        await tester.runAsync(images.create);
        for (final (AnalysisResult, RecolorAvailability) c
            in <(AnalysisResult, RecolorAvailability)>[
          (garmentsResult, kBoth),
          (garmentsResult, kUpperOnly),
          (garmentsCanvasResult, kBoth),
        ]) {
          await pumpPhoneSized(
            tester,
            locale,
            RecolorScreen(
              session: FakeRecolorSession(c.$2, images: images),
              result: c.$1,
              photo: photo,
              target: RecolorTarget.of(c.$1, locale.languageCode),
              frameAspect: 3 / 4,
              decodePhoto: (Uint8List _) async => images.original.clone(),
            ),
          );
          expect(find.byType(RecolorScreen), findsOneWidget);
        }
      });

      testWidgets('Sneaker result (hero combo + canvas kicks) renders',
          (WidgetTester tester) async {
        for (final AnalysisResult result in <AnalysisResult>[
          chromaticResult,
          canvasResult,
        ]) {
          await pumpPhoneSized(
            tester,
            locale,
            SneakerResultScreen(
              args: SneakerResultArgs(result: result, photo: photo),
            ),
          );
        }
      });
    });
  }
}

class _NullPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

/// Engine that never finishes: keeps the analyzing screen stable to inspect.
class _HangingEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) =>
      Completer<AnalysisResult>().future;
}
