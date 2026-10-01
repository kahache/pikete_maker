import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/capture/picker_cache.dart';
import 'package:piketemaker/features/story/story_export.dart';

/// Q2 · F1 fix — image_picker's copies of every analysed photo no longer
/// stay in the app cache (security audit, 2026-10-01).
///
/// image_picker_android 0.8.13 writes into `Context.getCacheDir()`
/// (= `<data>/cache`, the sibling of `Directory.systemTemp` = `<data>/
/// code_cache`): gallery → `cache/<uuid>/<original>` (FULL resolution) +
/// `cache/scaled_<original>`; camera → `cache/scaled_<uuid><n>.jpg` (EXIF GPS
/// copied in). These tests rebuild that layout on the host and check that the
/// pick and the app-start sweep delete EXACTLY those files — never
/// share_plus's folder, our story PNG, or anything outside the cache dir.

const String _uuid = '3f2b8c1e-9a4d-4e6f-b1c2-7d8e9f0a1b2c';
const String _uuid2 = 'A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF';

void main() {
  late Directory data;
  late Directory codeCache;
  late Directory cache;
  late Directory Function() previousDir;
  late bool Function() previousEnabled;

  File touch(String path, [List<int> bytes = const <int>[1, 2, 3]]) =>
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  setUp(() {
    data = Directory.systemTemp.createTempSync('pk_sec_picker_');
    codeCache = Directory('${data.path}/code_cache')..createSync();
    cache = Directory('${data.path}/cache')..createSync();
    previousDir = pickerCacheDirectory;
    previousEnabled = pickerPurgeEnabled;
    // The production derivation from systemTemp (= code_cache on Android).
    pickerCacheDirectory = () => shareCacheDirectoryFor(codeCache);
    pickerPurgeEnabled = () => true;
  });

  tearDown(() {
    pickerCacheDirectory = previousDir;
    pickerPurgeEnabled = previousEnabled;
    if (data.existsSync()) data.deleteSync(recursive: true);
  });

  /// Everything that must SURVIVE any picker purge.
  List<File> keepers() => <File>[
        touch('${cache.path}/share_plus/piketemaker_story.png'),
        touch('${codeCache.path}/$kStoryFileName'),
        touch('${cache.path}/notes.txt'),
        touch('${cache.path}/not-a-uuid/photo.jpg'),
        touch('${cache.path}/$_uuid.txt'),
        touch('${data.path}/files/photo.jpg'),
        touch('${codeCache.path}/scaled_photo.jpg'),
      ];

  test(
      'the app-start sweep deletes every image_picker artifact and nothing '
      'else', () {
    final List<File> keep = keepers();
    final List<FileSystemEntity> picker = <FileSystemEntity>[
      touch('${cache.path}/$_uuid/IMG_20260930_101500.jpg').parent,
      touch('${cache.path}/$_uuid2/selfie.HEIC').parent,
      touch('${cache.path}/scaled_IMG_20260930_101500.jpg'),
      touch('${cache.path}/scaled_${_uuid}8812345.jpg'),
      touch('${cache.path}/${_uuid}8812345.jpg'),
      touch('${cache.path}/image_picker_$_uuid.jpg'),
    ];

    expect(purgePickerCache(), picker.length);

    for (final FileSystemEntity e in picker) {
      expect(e.existsSync(), isFalse, reason: '${e.path} must be gone');
    }
    for (final File f in keep) {
      expect(f.existsSync(), isTrue, reason: '${f.path} must survive');
    }
  });

  test(
      'gallery pick: the returned scaled copy AND the full-size original '
      'are deleted right after the bytes are read', () async {
    final List<File> keep = keepers();
    final File original =
        touch('${cache.path}/$_uuid/IMG_1.jpg', <int>[9, 9, 9, 9]);
    final File scaled = touch('${cache.path}/scaled_IMG_1.jpg', <int>[4, 5, 6]);
    final ImagePickerPhotoPicker picker = ImagePickerPhotoPicker(
        pickFile: (PhotoSource _) async => XFile(scaled.path));

    final Uint8List? bytes = await picker.pick(PhotoSource.gallery);

    expect(bytes, <int>[4, 5, 6], reason: 'the bytes are in memory');
    expect(scaled.existsSync(), isFalse);
    expect(original.existsSync(), isFalse);
    expect(original.parent.existsSync(), isFalse, reason: 'the <uuid> dir');
    for (final File f in keep) {
      expect(f.existsSync(), isTrue, reason: '${f.path} must survive');
    }
  });

  test('camera pick: the scaled copy (EXIF GPS) is deleted', () async {
    final File scaled = touch('${cache.path}/scaled_${_uuid}42.jpg');
    final ImagePickerPhotoPicker picker = ImagePickerPhotoPicker(
        pickFile: (PhotoSource _) async => XFile(scaled.path));

    expect(await picker.pick(PhotoSource.camera), isNotNull);
    expect(scaled.existsSync(), isFalse);
  });

  test('a picked file OUTSIDE the cache dir is never deleted', () async {
    final File outside = touch('${data.path}/files/picked.jpg');
    final ImagePickerPhotoPicker picker = ImagePickerPhotoPicker(
        pickFile: (PhotoSource _) async => XFile(outside.path));

    expect(await picker.pick(PhotoSource.gallery), isNotNull);
    expect(outside.existsSync(), isTrue);
  });

  test('cancel: nothing is read, nothing is deleted', () async {
    final List<File> keep = keepers();
    final ImagePickerPhotoPicker picker =
        ImagePickerPhotoPicker(pickFile: (PhotoSource _) async => null);
    expect(await picker.pick(PhotoSource.gallery), isNull);
    for (final File f in keep) {
      expect(f.existsSync(), isTrue);
    }
  });

  test('host safety: with the guard off (desktop temp dir) nothing is swept',
      () {
    pickerPurgeEnabled = () => false;
    final File scaled = touch('${cache.path}/scaled_IMG_1.jpg');
    final Directory dir = touch('${cache.path}/$_uuid/IMG_1.jpg').parent;
    expect(purgePickerCache(), 0);
    expect(scaled.existsSync(), isTrue);
    expect(dir.existsSync(), isTrue);
  });

  test('the production guard is Android / iOS only', () {
    pickerPurgeEnabled = previousEnabled;
    expect(pickerPurgeEnabled(), Platform.isAndroid || Platform.isIOS);
  });

  test('wiring lock: app start sweeps, the pick deletes after reading', () {
    final String app = File('lib/app.dart').readAsStringSync();
    final int start = app.indexOf('void initState()');
    expect(start, isNonNegative);
    expect(app.indexOf('purgePickerCache();', start), isNonNegative,
        reason: 'app start must sweep image_picker leftovers');
    final String picker =
        File('lib/features/capture/photo_picker.dart').readAsStringSync();
    final int read = picker.indexOf('readAsBytes()');
    expect(read, isNonNegative);
    expect(picker.indexOf('deletePickedFile(', read), isNonNegative,
        reason: 'the picked file must be deleted after the bytes are read');
  });
}
