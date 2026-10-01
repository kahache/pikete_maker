import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/capture/capture_screen.dart';
import 'package:piketemaker/features/capture/cover_sized_memory_image.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// r13 A5 (review F14): the confirm preview decodes the photo at the size its
/// `BoxFit.cover` box needs on THIS screen (physical pixels), not at the
/// photo's full resolution — for portrait selfies and landscape product shots
/// alike.

Uint8List _onePixelPng() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

class _NullPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

/// Encodes a flat [width]×[height] PNG with the engine (real bytes to decode).
Future<Uint8List> _png(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFF7E9C7B),
  );
  final ui.Image image =
      await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Resolves [provider] and returns the decoded bitmap's size.
Future<Size> _decodedSize(ImageProvider<Object> provider) {
  final Completer<Size> done = Completer<Size>();
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      done.complete(Size(
          info.image.width.toDouble(), info.image.height.toDouble()));
      stream.removeListener(listener);
    },
    onError: (Object e, StackTrace? s) => done.completeError(e, s),
  );
  stream.addListener(listener);
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('coverDecodeSize (the cover math)', () {
    test('portrait selfie in a portrait box: the width binds', () {
      // 1200×1600 photo, 950×1300 px box → scale max(0.79, 0.8125) = 0.8125.
      final ui.TargetImageSize size = coverDecodeSize(
          intrinsicWidth: 1200,
          intrinsicHeight: 1600,
          boxWidth: 950,
          boxHeight: 1300);
      expect(size.width, 975);
      expect(size.height, isNull, reason: 'aspect ratio kept by the codec');
    });

    test('landscape product shot: the HEIGHT binds (no soft preview)', () {
      // 1600×900 photo, 900×600 px box → scale max(0.5625, 0.667) = 0.667.
      // A naive cacheWidth = 900 would decode 900×506 and cover would have
      // to upscale it to fill the 600 px height.
      final ui.TargetImageSize size = coverDecodeSize(
          intrinsicWidth: 1600,
          intrinsicHeight: 900,
          boxWidth: 900,
          boxHeight: 600);
      expect(size.width, 1067);
      expect(1067 * 900 / 1600, greaterThanOrEqualTo(600));
    });

    test('never upscales a photo smaller than the box', () {
      final ui.TargetImageSize size = coverDecodeSize(
          intrinsicWidth: 400,
          intrinsicHeight: 300,
          boxWidth: 900,
          boxHeight: 1300);
      expect(size.width, isNull);
      expect(size.height, isNull);
    });

    test('degenerate sizes fall back to the full decode', () {
      final ui.TargetImageSize size = coverDecodeSize(
          intrinsicWidth: 1200,
          intrinsicHeight: 1600,
          boxWidth: 0,
          boxHeight: 0);
      expect(size.width, isNull);
      expect(size.height, isNull);
    });
  });

  testWidgets('the provider really decodes at the cover size',
      (WidgetTester tester) async {
    final Size decoded = (await tester.runAsync(() async {
      final Uint8List photo = await _png(400, 300);
      return _decodedSize(
          CoverSizedMemoryImage(photo, boxWidth: 100, boxHeight: 100));
    }))!;
    // 400×300 into 100×100 → scale max(0.25, 0.333) → 134×100 (aspect kept).
    expect(decoded.width, 134);
    expect(decoded.height, closeTo(100, 1));
  });

  testWidgets('Confirm sizes the preview to its box × device pixel ratio',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625; // Galaxy M33-class screen
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: kCanonicalLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      home: CaptureScreen(
        args: CaptureArgs(photo: _onePixelPng()),
        picker: _NullPicker(),
      ),
    ));
    await tester.pump();

    final Finder preview = find.byType(Image);
    expect(preview, findsOneWidget);
    final Image image = tester.widget<Image>(preview);
    expect(image.image, isA<CoverSizedMemoryImage>());
    final CoverSizedMemoryImage provider =
        image.image as CoverSizedMemoryImage;

    final Size box = tester.getSize(preview);
    expect(box.width, lessThan(1080 / 2.625), reason: 'inside the margins');
    expect(provider.boxWidth, (box.width * 2.625).ceil());
    expect(provider.boxHeight, (box.height * 2.625).ceil());
    // The key is the photo bytes object + box: a retake re-decodes.
    expect(provider,
        previewImageFor(provider.bytes, box, 2.625));
  });
}
