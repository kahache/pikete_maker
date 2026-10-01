import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/features/story/story_share_sheet.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_test_helpers.dart';

/// N1 / D37 — the story PREVIEW SHEET (spec §3), driven with fake renderers
/// (tiny known PNGs, Completer-controlled) so every state is deterministic:
/// default ON, remembered OFF, toggle swaps bytes, CTA disabled until ready,
/// what-you-see-is-what-you-share, the degraded paths and the file cleanup.

late Uint8List _photoPng;
late Uint8List _cardPng;

Future<Uint8List> _solidPng(Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 9, 16), Paint()..color = color);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(9, 16);
  final ByteData data =
      (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  picture.dispose();
  return data.buffer.asUint8List();
}

/// Records what the sheet wrote/shared.
class _Spy {
  final List<Uint8List> written = <Uint8List>[];
  final List<File> shared = <File>[];
  final List<Map<String, Object?>> logged = <Map<String, Object?>>[];
  String status = 'success';
  Completer<String>? pendingShare;
  Object? shareError;

  Future<File> write(Uint8List png) async {
    written.add(png);
    return writeStoryPng(png); // real file in the private temp dir
  }

  Future<String> share(File file, Rect? origin) {
    shared.add(file);
    if (shareError != null) return Future<String>.error(shareError!);
    return pendingShare?.future ?? Future<String>.value(status);
  }

  void log({
    required String status,
    required int bytes,
    required bool photo,
    required int? previewMs,
  }) =>
      logged.add(<String, Object?>{
        'status': status,
        'bytes': bytes,
        'photo': photo,
        'preview_ms': previewMs,
      });
}

/// A result-like host with one button that opens the sheet.
class _Harness {
  _Harness({
    this.withPhoto = true,
    StoryPreferences? prefs,
    this.initialIncludePhoto,
    this.rememberChoice = true,
    this.photoRender,
    this.cardRender,
  }) : prefs = prefs ?? StoryPreferencesInMemory();

  final bool withPhoto;
  final StoryPreferences prefs;
  final bool? initialIncludePhoto;
  final bool rememberChoice;
  final StoryRenderer? photoRender;
  final StoryRenderer? cardRender;
  final _Spy spy = _Spy();
  final List<StoryShareOutcome> outcomes = <StoryShareOutcome>[];
  int photoRenders = 0;
  int cardRenders = 0;

  Widget app() => MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => outcomes.add(await showStorySharePreview(
                  context: context,
                  cardOnly: cardRender ??
                      (BuildContext _) async {
                        cardRenders++;
                        return _cardPng;
                      },
                  withPhoto: !withPhoto
                      ? null
                      : photoRender ??
                          (BuildContext _) async {
                            photoRenders++;
                            return _photoPng;
                          },
                  sharer: spy.share,
                  preferences: prefs,
                  initialIncludePhoto: initialIncludePhoto,
                  rememberChoice: rememberChoice,
                  writeFile: spy.write,
                  onShared: spy.log,
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
}

Future<void> _open(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(h.app());
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The bytes the preview is decoding right now (null = placeholder).
Uint8List? _previewBytes(WidgetTester tester) {
  final Finder img = find.descendant(
    of: find.byKey(StorySharePreviewSheet.previewKey),
    matching: find.byType(Image),
  );
  if (img.evaluate().isEmpty) return null;
  // AnimatedSwitcher keeps the outgoing child during the crossfade: the
  // LAST one is the incoming (current) image.
  final ImageProvider<Object> provider =
      tester.widgetList<Image>(img).last.image;
  final ImageProvider<Object> inner =
      provider is ResizeImage ? provider.imageProvider : provider;
  return (inner as MemoryImage).bytes;
}

bool _ctaEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.descendant(
          of: find.byKey(StorySharePreviewSheet.ctaKey),
          matching: find.byType(FilledButton),
        ))
        .onPressed !=
    null;

Switch _switch(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch));

Future<void> _tapShare(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(esL10n.storyShareCta));
    // Real file IO of the writer.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory tmp;

  setUpAll(() async {
    // Real Roboto: the sheet's text lays out like on a phone (the privacy
    // line is ONE line at 390 dp; the 1-em test font would wrap it).
    await loadRealFonts();
    _photoPng = await _solidPng(const Color(0xFFE53935));
    _cardPng = await _solidPng(const Color(0xFF2E9E4F));
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pk_story_sheet_');
    storyCacheDirectory = () => tmp;
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
      'default ON: the photo PNG is previewed, the switch is ON, the privacy '
      'line shows; "Compartir" shares the IDENTICAL bytes and logs photo:true',
      (WidgetTester tester) async {
    final _Harness h = _Harness();
    await _open(tester, h);

    expect(find.text(esL10n.storyIncludePhoto), findsOneWidget);
    expect(_switch(tester).value, isTrue);
    expect(find.text(esL10n.storyPhotoPrivacy), findsOneWidget);
    expect(find.bySemanticsLabel(esL10n.storyPreviewLabel), findsOneWidget);
    expect(h.photoRenders, 1);
    expect(h.cardRenders, 0, reason: 'OFF is rendered lazily, on toggle');
    final Uint8List? previewed = _previewBytes(tester);
    expect(previewed, same(_photoPng));
    expect(_ctaEnabled(tester), isTrue);

    await _tapShare(tester);

    expect(h.spy.written.single, same(previewed),
        reason: 'what you see is what you share (identical Uint8List)');
    expect(h.spy.shared.single.path, endsWith(kStoryFileName));
    expect(h.spy.logged.single['photo'], isTrue);
    expect(h.spy.logged.single['status'], 'success');
    expect(h.spy.logged.single['bytes'], _photoPng.length);
    expect(h.spy.logged.single.keys,
        unorderedEquals(<String>['status', 'bytes', 'photo', 'preview_ms']),
        reason: 'no image data, no path in analytics');
    // success → the sheet closed, and the story file is gone.
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsNothing);
    expect(h.outcomes, <StoryShareOutcome>[StoryShareOutcome.shared]);
    expect(storyFile().existsSync(), isFalse,
        reason: 'deleted when the sheet closes ("no la guardamos")');
  });

  testWidgets(
      'loading: plain surfaceSubtle box, "Compartir" DISABLED until the PNG '
      'exists', (WidgetTester tester) async {
    final Completer<Uint8List> render = Completer<Uint8List>();
    final _Harness h =
        _Harness(photoRender: (BuildContext _) => render.future);
    await _open(tester, h);

    expect(find.byKey(StorySharePreviewSheet.previewPlaceholderKey),
        findsOneWidget);
    expect(_previewBytes(tester), isNull, reason: 'no spinner, no image');
    expect(_ctaEnabled(tester), isFalse);

    render.complete(_photoPng);
    await tester.pumpAndSettle();
    expect(_previewBytes(tester), same(_photoPng));
    expect(_ctaEnabled(tester), isTrue);
  });

  testWidgets(
      'toggle OFF swaps to the card PNG (rendered once, cached), remembers '
      'OFF locally and shares the card with photo:false',
      (WidgetTester tester) async {
    final StoryPreferencesInMemory prefs = StoryPreferencesInMemory();
    final _Harness h = _Harness(prefs: prefs);
    await _open(tester, h);

    await tester.tap(find.text(esL10n.storyIncludePhoto)); // whole row
    await tester.pumpAndSettle();
    expect(_switch(tester).value, isFalse);
    expect(_previewBytes(tester), same(_cardPng));
    expect(prefs.stored, isFalse, reason: 'remembered locally');

    // Back ON and OFF again: both cached, no re-render.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(_previewBytes(tester), same(_photoPng));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((h.photoRenders, h.cardRenders), (1, 1));

    await _tapShare(tester);
    expect(h.spy.written.single, same(_cardPng));
    expect(h.spy.logged.single['photo'], isFalse);
  });

  testWidgets(
      'switching to a state not rendered yet keeps the current PNG and '
      'disables "Compartir" until the new one is ready',
      (WidgetTester tester) async {
    final Completer<Uint8List> card = Completer<Uint8List>();
    final _Harness h = _Harness(cardRender: (BuildContext _) => card.future);
    await _open(tester, h);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(_previewBytes(tester), same(_photoPng), reason: 'keeps the current');
    expect(_ctaEnabled(tester), isFalse, reason: 'OFF not ready yet');

    card.complete(_cardPng);
    await tester.pumpAndSettle();
    expect(_previewBytes(tester), same(_cardPng));
    expect(_ctaEnabled(tester), isTrue);
  });

  testWidgets('a remembered OFF opens OFF (card PNG, photo never rendered)',
      (WidgetTester tester) async {
    final _Harness h =
        _Harness(prefs: StoryPreferencesInMemory(includePhoto: false));
    await _open(tester, h);
    expect(_switch(tester).value, isFalse);
    expect(_previewBytes(tester), same(_cardPng));
    expect(h.photoRenders, 0);
  });

  testWidgets(
      'forced OFF + not remembered (pass-2 screenshot source): opens OFF over '
      'a remembered ON, and toggling never touches the stored choice',
      (WidgetTester tester) async {
    final StoryPreferencesInMemory prefs =
        StoryPreferencesInMemory(includePhoto: true);
    final _Harness h = _Harness(
        prefs: prefs, initialIncludePhoto: false, rememberChoice: false);
    await _open(tester, h);
    expect(_switch(tester).value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(_switch(tester).value, isTrue);
    expect(prefs.stored, isTrue, reason: 'untouched');
  });

  testWidgets('no photo → switch hidden, card shared',
      (WidgetTester tester) async {
    final _Harness h = _Harness(withPhoto: false);
    await _open(tester, h);
    expect(find.byType(Switch), findsNothing);
    expect(find.text(esL10n.storyIncludePhoto), findsNothing);
    expect(find.text(esL10n.storyPhotoPrivacy), findsOneWidget);
    expect(_previewBytes(tester), same(_cardPng));
    await _tapShare(tester);
    expect(h.spy.written.single, same(_cardPng));
  });

  testWidgets(
      'the photo render throws → silently card-only with the switch hidden '
      '(no error message)', (WidgetTester tester) async {
    final _Harness h = _Harness(
        photoRender: (BuildContext _) async => throw StateError('decode'));
    await _open(tester, h);
    expect(find.byType(Switch), findsNothing);
    expect(_previewBytes(tester), same(_cardPng));
    expect(_ctaEnabled(tester), isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the card render throws too → the sheet closes with "failed"',
      (WidgetTester tester) async {
    final _Harness h = _Harness(
      photoRender: (BuildContext _) async => throw StateError('photo'),
      cardRender: (BuildContext _) async => throw StateError('card'),
    );
    await _open(tester, h);
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsNothing);
    expect(h.outcomes, <StoryShareOutcome>[StoryShareOutcome.failed]);
  });

  testWidgets(
      'OS sheet dismissed → the preview stays open; closing it via the scrim '
      'deletes the story file', (WidgetTester tester) async {
    final _Harness h = _Harness()..spy.status = 'dismissed';
    await _open(tester, h);
    await _tapShare(tester);
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsOneWidget);
    expect(storyFile().existsSync(), isTrue, reason: 'written for the share');

    await tester.tapAt(const Offset(20, 20)); // scrim
    await tester.pumpAndSettle();
    expect(find.byKey(StorySharePreviewSheet.previewKey), findsNothing);
    expect(h.outcomes, <StoryShareOutcome>[StoryShareOutcome.closed]);
    expect(storyFile().existsSync(), isFalse);
  });

  testWidgets('a share that throws closes the sheet with "failed"',
      (WidgetTester tester) async {
    final _Harness h = _Harness()..spy.shareError = StateError('no activity');
    await _open(tester, h);
    await _tapShare(tester);
    expect(h.outcomes, <StoryShareOutcome>[StoryShareOutcome.failed]);
    expect(storyFile().existsSync(), isFalse);
  });

  testWidgets('a double tap while the OS sheet is open shares only once',
      (WidgetTester tester) async {
    final _Harness h = _Harness()..spy.pendingShare = Completer<String>();
    await _open(tester, h);
    await tester.runAsync(() async {
      await tester.tap(find.text(esL10n.storyShareCta));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(_ctaEnabled(tester), isFalse, reason: 'guarded while sharing');
    await tester.runAsync(() async {
      await tester.tap(find.text(esL10n.storyShareCta), warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      h.spy.pendingShare!.complete('success');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(h.spy.shared, hasLength(1));
  });

  testWidgets(
      'layout on the 390 × 844 reference: preview 270 × 480 (9:16), toggle '
      'row 56 tall, CTA 56 tall 24 above the bottom, sheet top ≈ 112',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final _Harness h = _Harness();
    await _open(tester, h);

    final Rect preview =
        tester.getRect(find.byKey(StorySharePreviewSheet.previewKey));
    expect(preview.size, const Size(270, 480));
    expect(preview.center.dx, 195, reason: 'centred');
    expect(preview.top, closeTo(112 + 28, 1));
    expect(tester.getSize(find.byKey(StorySharePreviewSheet.toggleKey)).height,
        56);
    final Rect cta = tester.getRect(find.byKey(StorySharePreviewSheet.ctaKey));
    expect(cta.height, 56);
    expect(cta.bottom, closeTo(844 - 24, 1), reason: 'thumb zone');
    expect(cta.width, 390 - 40);
  });

  testWidgets('short phone: the preview flexes down, never below 280',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 1920) // 360 × 640
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _open(tester, _Harness());
    final Size preview =
        tester.getSize(find.byKey(StorySharePreviewSheet.previewKey));
    expect(preview.height, 280);
    expect(preview.width, closeTo(157.5, 0.01));
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  test('StoryPreferencesPrefs: default ON, remembers OFF (SharedPreferences)',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const StoryPreferencesPrefs prefs = StoryPreferencesPrefs();
    expect(await prefs.includePhoto(), isTrue);
    await prefs.setIncludePhoto(false);
    expect(await prefs.includePhoto(), isFalse);
    expect(StoryPreferencesPrefs.key, 'story_include_photo');
  });
}
