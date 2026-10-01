import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:piketemaker/features/sneaker/sneaker_tip_illustrations.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_layout.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/features/story/story_share_sheet.dart';
import 'package:piketemaker/theme/app_theme.dart';

import '../story/story_test_helpers.dart';

/// N1 / D37 pass 2 — "Súbela a tu story" on the SNEAKER result: the shared
/// preview sheet with the sneaker photo story (2-line title) as the default,
/// the sneaker card as OFF, `story_exported` with `mode: sneaker`, and the
/// shop-screenshot rule (opens OFF, never remembered).

const Color _green = Color(0xFF2F7A4D);
const Color _pink = Color(0xFFB8477A);

const AnalysisResult _kicks = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _green, weight: 0.55),
    ColorSample(color: Color(0xFFF6F4F0), weight: 0.45),
  ],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[_green, _pink],
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

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 60 && !_ctaReady(tester); i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required Uint8List photo,
  SneakerTipCase? situation,
  StoryPreferences? prefs,
  AnalyticsService? analytics,
  StorySharer? share,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: SneakerResultScreen(
      args: SneakerResultArgs(
          result: _kicks, photo: photo, situation: situation),
      analytics: analytics,
      storyPreferences: prefs ?? StoryPreferencesInMemory(),
      shareStory: share ?? (File png, Rect? origin) async => 'success',
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(SneakerResultScreen.storyCtaKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(SneakerResultScreen.storyCtaKey));
  await tester.pumpAndSettle();
  await _settle(tester);
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
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pk_sneaker_story_');
    storyCacheDirectory = () => tmp;
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
      'own photo: the default shared image is the sneaker PHOTO story (2-line '
      'layout), logged story_exported {photo:true, mode:sneaker}; the file is '
      'gone after the share', (WidgetTester tester) async {
    late Uint8List photo;
    await tester.runAsync(() async => photo = await quadrantPhoto(600, 800));
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uint8List> shared = <Uint8List>[];
    await _pump(tester,
        photo: photo,
        situation: SneakerTipCase.casa,
        analytics: analytics, share: (File png, Rect? origin) async {
      shared.add(png.readAsBytesSync());
      expect(origin, isNotNull, reason: 'iPad popover anchor');
      return 'success';
    });
    await _openSheet(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await _tapCompartir(tester);

    late Pixels px;
    await tester.runAsync(() async => px = await Pixels.decode(shared.single));
    final Rect p =
        PhotoStoryLayout.compute(photoAspect: 3 / 4, headlineLines: 2).photo;
    const double r = StoryGeometry.pixelRatio;
    expect(
        px.isNear(((p.left + p.width / 4) * r).round(),
            ((p.top + p.height / 4) * r).round(), qTopLeft),
        isTrue,
        reason: 'the photo sits where the 2-line sneaker layout puts it');
    final AnalyticsEvent event =
        analytics.named(AnalyticsEvents.storyExported).single;
    expect(event.params['mode'], 'sneaker');
    expect(event.params['photo'], isTrue);
    expect(event.params['status'], 'success');
    expect(event.params.containsKey('path'), isFalse);
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsNothing);
    expect(storyFile().existsSync(), isFalse);
  });

  testWidgets(
      '"Captura de pantalla" (third-party image): opens OFF over a remembered '
      'ON, toggling is NOT remembered, OFF shares the card (photo:false)',
      (WidgetTester tester) async {
    late Uint8List photo;
    await tester.runAsync(() async => photo = await quadrantPhoto(60, 80));
    final StoryPreferencesInMemory prefs =
        StoryPreferencesInMemory(includePhoto: true);
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester,
        photo: photo,
        situation: SneakerTipCase.web,
        prefs: prefs,
        analytics: analytics);
    await _openSheet(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await _settle(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(prefs.stored, isTrue, reason: 'the remembered choice is untouched');

    await _tapCompartir(tester);
    expect(
        analytics.named(AnalyticsEvents.storyExported).single.params['photo'],
        isFalse);
  });

  testWidgets('no photo bytes → card-only, switch hidden',
      (WidgetTester tester) async {
    await _pump(tester, photo: Uint8List(0));
    await _openSheet(tester);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('a share failure degrades to the "couldn\'t generate" SnackBar',
      (WidgetTester tester) async {
    await _pump(tester,
        photo: Uint8List(0),
        share: (File png, Rect? origin) async =>
            throw PlatformException(code: 'no_activity'));
    await _openSheet(tester);
    await _tapCompartir(tester);
    expect(find.text('No se pudo generar la story. Prueba otra vez.'),
        findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
