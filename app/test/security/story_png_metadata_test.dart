import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/features/story/story_photo.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// Q2 · P2 — the SHARED story PNG carries no photo metadata (security audit,
/// 2026-10-01).
///
/// The story (D37) is the one path by which the user's photo leaves the
/// phone. A camera JPEG can carry EXIF GPS coordinates, the device model and
/// free-text tags; forwarding them inside a story posted publicly would leak
/// where the user lives. The export re-renders the photo offscreen and
/// encodes a fresh PNG, so no metadata should survive — this test VERIFIES
/// it with a JPEG whose EXIF holds a GPS IFD and a text canary, through the
/// exact production path (`renderPhotoStoryPng` → `writeStoryPng`), by
/// parsing every chunk of the written file.

/// Canary written into the EXIF ImageDescription tag.
const String _canary = 'PIKETE-EXIF-CANARY-41N-2E';

/// Chunks a bare re-encoded PNG may contain (pixel data + colour/physical
/// rendering hints). Anything else is metadata and fails the test.
const Set<String> _allowedChunks = <String>{
  'IHDR',
  'IDAT',
  'IEND',
  'PLTE',
  'tRNS',
  'sRGB',
  'gAMA',
  'cHRM',
  'iCCP',
  'pHYs',
  'sBIT',
  'bKGD',
};

/// A big-endian TIFF/EXIF block: IFD0 {ImageDescription = canary,
/// Orientation = 6, GPSInfo → GPS IFD {LatitudeRef 'N', Latitude 41°23'12.34"}}.
Uint8List _exifWithGps() {
  final BytesBuilder b = BytesBuilder();
  void u16(int v) => b.add(<int>[(v >> 8) & 0xFF, v & 0xFF]);
  void u32(int v) => b.add(
      <int>[(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
  final List<int> canary = <int>[...ascii.encode(_canary), 0];
  const int ifd0 = 8;
  const int ifd0Size = 2 + 3 * 12 + 4;
  const int canaryAt = ifd0 + ifd0Size; // 50
  final int gpsAt = (canaryAt + canary.length + 1) & ~1; // word-aligned
  const int gpsSize = 2 + 2 * 12 + 4;
  final int ratAt = gpsAt + gpsSize;

  b.add(ascii.encode('MM'));
  u16(42);
  u32(ifd0);
  // IFD0 — entries sorted by tag.
  u16(3);
  u16(0x010E);
  u16(2);
  u32(canary.length);
  u32(canaryAt); // ImageDescription
  u16(0x0112);
  u16(3);
  u32(1);
  u16(6);
  u16(0); // Orientation = 6
  u16(0x8825);
  u16(4);
  u32(1);
  u32(gpsAt); // GPSInfo IFD pointer
  u32(0);
  b.add(canary);
  while (b.length < gpsAt) {
    b.addByte(0);
  }
  // GPS IFD.
  u16(2);
  u16(0x0001);
  u16(2);
  u32(2);
  b.add(<int>[0x4E, 0, 0, 0]); // LatitudeRef "N"
  u16(0x0002);
  u16(5);
  u32(3);
  u32(ratAt); // Latitude (3 RATIONAL)
  u32(0);
  for (final (int n, int d) in <(int, int)>[(41, 1), (23, 1), (1234, 100)]) {
    u32(n);
    u32(d);
  }
  return b.toBytes();
}

/// The story fixture JPEG (EXIF orientation 6, 160×120 stored) with its APP1
/// replaced by [_exifWithGps].
Uint8List _jpegWithGps() {
  final Uint8List src =
      File('test/features/story/fixtures/exif6_portrait.jpg').readAsBytesSync();
  final BytesBuilder out = BytesBuilder()..add(src.sublist(0, 2)); // SOI
  int i = 2;
  bool replaced = false;
  while (i < src.length) {
    final int marker = src[i + 1];
    final int len = (src[i + 2] << 8) | src[i + 3];
    if (marker == 0xDA) {
      out.add(src.sublist(i)); // SOS + entropy data + EOI
      break;
    }
    if (marker == 0xE1 && !replaced) {
      final List<int> payload = <int>[
        ...ascii.encode('Exif'),
        0,
        0,
        ..._exifWithGps()
      ];
      out
        ..add(<int>[0xFF, 0xE1])
        ..add(<int>[
          ((payload.length + 2) >> 8) & 0xFF,
          (payload.length + 2) & 0xFF
        ])
        ..add(payload);
      replaced = true;
    } else {
      out.add(src.sublist(i, i + 2 + len));
    }
    i += 2 + len;
  }
  expect(replaced, isTrue, reason: 'the fixture must have an EXIF APP1');
  return out.toBytes();
}

/// The chunk types of [png], in order (validates the signature and lengths).
List<String> _pngChunks(Uint8List png) {
  expect(
      png.sublist(0, 8), <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ByteData d = ByteData.sublistView(png);
  final List<String> types = <String>[];
  int i = 8;
  while (i + 8 <= png.length) {
    final int len = d.getUint32(i);
    types.add(ascii.decode(png.sublist(i + 4, i + 8)));
    i += 12 + len;
  }
  expect(i, png.length, reason: 'chunk lengths must tile the file exactly');
  return types;
}

bool _contains(Uint8List hay, List<int> needle) {
  outer:
  for (int i = 0; i + needle.length <= hay.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late Directory tmp;
  late Directory Function() originalDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pk_sec_story_');
    originalDir = storyCacheDirectory;
    storyCacheDirectory = () => tmp;
  });

  tearDown(() {
    storyCacheDirectory = originalDir;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
      'a photo with EXIF GPS + text → the shared story PNG has no metadata '
      'chunk, no canary, and is the file handed to the share sheet',
      (WidgetTester tester) async {
    const Key host = Key('host');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SizedBox.expand(key: host)),
    ));
    final BuildContext context = tester.element(find.byKey(host));
    final Uint8List jpeg = _jpegWithGps();
    final List<int> canaryBytes = ascii.encode(_canary);

    // Non-vacuous: the input really carries the canary + GPS IFD …
    expect(_contains(jpeg, canaryBytes), isTrue);
    expect(_contains(jpeg, <int>[0x88, 0x25]), isTrue, reason: 'GPSInfo tag');

    late int w, h;
    late Uint8List png;
    late Uint8List written;
    await tester.runAsync(() async {
      // … and the decoder really parsed that EXIF (orientation 6 applied).
      final ui.Image upright = await decodeStoryPhoto(jpeg);
      w = upright.width;
      h = upright.height;
      upright.dispose();
      png = await renderPhotoStoryPng(
        context,
        jpeg,
        (ui.Image photo) => SizedBox.expand(child: RawImage(image: photo)),
      );
      written = (await writeStoryPng(png)).readAsBytesSync();
    });

    expect((w, h), (120, 160), reason: 'EXIF was read (stored 160×120)');
    expect(written, png, reason: 'the file shared is exactly the render');

    final List<String> chunks = _pngChunks(written);
    expect(chunks.first, 'IHDR');
    expect(chunks.last, 'IEND');
    expect(chunks.where((String c) => !_allowedChunks.contains(c)).toList(),
        isEmpty,
        reason: 'no eXIf / tEXt / zTXt / iTXt / tIME chunk may survive: '
            'chunks were $chunks');
    expect(_contains(written, canaryBytes), isFalse,
        reason: 'the EXIF text canary must not reach the shared file');
    expect(_contains(written, ascii.encode('Exif')), isFalse);
  });
}
