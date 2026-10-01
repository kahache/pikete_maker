import 'dart:io';

import 'package:flutter/foundation.dart';

import '../story/story_export.dart';

/// Security audit Q2 finding F1 (2026-10-01): `image_picker` leaves a copy of
/// EVERY picked photo in the app cache, and nothing deleted it — so the
/// onboarding promise "no la guardamos" was literally false.
///
/// What `image_picker_android` 0.8.13 writes into `Context.getCacheDir()`
/// (VERIFIED in the plugin source by the audit; on-device presence is the
/// auditor's HYPOTHESIS, a release build is not debuggable):
///
///  * gallery: `cache/<uuid>/<original name>` — the FULL-RESOLUTION original
///    copied from the content URI — plus `cache/scaled_<original name>`;
///  * camera: `cache/<uuid><digits>.jpg` temp + `cache/scaled_<uuid><digits>.jpg`
///    (the scaled copy carries the EXIF GPS: `ExifDataCopier`).
///
/// iOS writes `tmp/image_picker_<uuid>.jpg`.
///
/// The bytes the app works with are read into memory right after the pick,
/// so these files have no further use: [purgePickerCache] deletes them right
/// after `readAsBytes()` and again on app start (covers a kill in between).
///
/// SCOPE GUARD: only the top level of the cache directory is swept, only
/// entries matching image_picker's own naming are deleted, and nothing
/// outside that directory is ever touched — share_plus's folder and the
/// story PNG belong to the story module (`purgeStoryCache`).

/// The directory image_picker writes into, derived without a platform call:
/// Android `<data>/code_cache` (= `Directory.systemTemp`) → `<data>/cache`;
/// iOS / host → the temp dir itself (same rule as the share_plus copy, see
/// [shareCacheDirectoryFor]). Tests point it at a private layout.
@visibleForTesting
Directory Function() pickerCacheDirectory =
    () => shareCacheDirectoryFor(Directory.systemTemp);

/// Whether the sweep may run. Production: only on Android / iOS, where
/// [pickerCacheDirectory] is the app's PRIVATE cache. Never on a desktop
/// host (`flutter test`): there `Directory.systemTemp` is the machine's shared
/// temp dir, full of other programs' UUID-named folders. Tests that build a
/// private layout switch it on.
@visibleForTesting
bool Function() pickerPurgeEnabled = () => Platform.isAndroid || Platform.isIOS;

/// A UUID as `java.util.UUID.toString()` writes it.
const String _uuid =
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

/// Directories named exactly as a UUID (the gallery copy's parent).
final RegExp _pickerDirName = RegExp('^$_uuid\$');

/// Files of image_picker: `scaled_*` (both sources), `<uuid><digits>.jpg`
/// (camera temp), `image_picker*` (iOS / older Android versions).
final RegExp _pickerFileName =
    RegExp('^(scaled_.+|$_uuid[0-9]*\\.jpe?g|image_picker.*)\$');

String _basename(String path) =>
    path.split(RegExp(r'[/\\]')).where((String s) => s.isNotEmpty).last;

/// True for an entry of the cache directory that image_picker created.
@visibleForTesting
bool isPickerArtifact(FileSystemEntity entity) {
  final String name = _basename(entity.path);
  if (entity is Directory) return _pickerDirName.hasMatch(name);
  if (entity is File) return _pickerFileName.hasMatch(name);
  return false;
}

/// Deletes image_picker's leftovers from the top level of
/// [pickerCacheDirectory] (UUID directories recursively). Synchronous so app
/// start can run it before the first frame; never throws; returns how many
/// entries were deleted (tests).
int purgePickerCache() {
  if (!pickerPurgeEnabled()) return 0;
  int deleted = 0;
  try {
    final Directory root = pickerCacheDirectory();
    if (!root.existsSync()) return 0;
    for (final FileSystemEntity entity in root.listSync(followLinks: false)) {
      if (!isPickerArtifact(entity)) continue;
      try {
        entity.deleteSync(recursive: true);
        deleted++;
      } on FileSystemException {
        // Best effort: one stubborn file must not stop the sweep.
      }
    }
  } on FileSystemException {
    // No cache dir / not listable: nothing to purge.
  }
  return deleted;
}

/// Deletes the picked file at [path] (and its `<uuid>` parent directory when
/// that is image_picker's) IF it lives inside [pickerCacheDirectory], then
/// sweeps the rest of the picker's leftovers ([purgePickerCache] — the
/// gallery leaves a second copy next to the one returned). Never throws.
void deletePickedFile(String path) {
  if (!pickerPurgeEnabled()) return;
  try {
    final Directory root = pickerCacheDirectory().absolute;
    final File file = File(path).absolute;
    final String rootPath = _normalize(root.path);
    if (_normalize(file.path).startsWith('$rootPath/')) {
      final Directory parent = file.parent;
      final bool uuidParent = _normalize(parent.parent.path) == rootPath &&
          _pickerDirName.hasMatch(_basename(parent.path));
      if (file.existsSync()) file.deleteSync();
      if (uuidParent && parent.existsSync()) {
        parent.deleteSync(recursive: true);
      }
    }
  } on FileSystemException {
    // Best effort; the sweep below and the next app start catch the rest.
  }
  purgePickerCache();
}

String _normalize(String path) {
  String p = path.replaceAll('\\', '/');
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}
