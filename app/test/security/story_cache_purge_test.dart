import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/story/story_export.dart';

/// Q2 · P2 fix — the app-start purge reaches share_plus's REAL folder
/// (security audit, 2026-10-01).
///
/// On Android `Directory.systemTemp` is `<data>/code_cache` (the Flutter
/// engine's TMPDIR, verified on device in the F2.5 spike), while share_plus
/// copies the shared story — the user's photo — into
/// `Context.getCacheDir()/share_plus` = `<data>/cache/share_plus`. The purge
/// used to look in `code_cache/share_plus` (never exists), so the copy
/// survived app restarts until the next share. These tests reproduce the
/// Android layout on the host.

void main() {
  late Directory data;
  late Directory Function() previous;

  setUp(() {
    // <data>/{code_cache,cache} like /data/user/0/com.piketemaker.app/.
    data = Directory.systemTemp.createTempSync('pk_sec_data_');
    previous = storyCacheDirectory;
  });

  tearDown(() {
    storyCacheDirectory = previous;
    if (data.existsSync()) data.deleteSync(recursive: true);
  });

  test(
      'Android layout: systemTemp = code_cache → the purge deletes '
      'cache/share_plus (the plugin copy with the photo) and our story PNG, '
      'and nothing else', () {
    final Directory codeCache = Directory('${data.path}/code_cache')
      ..createSync();
    final Directory cache = Directory('${data.path}/cache')..createSync();
    storyCacheDirectory = () => codeCache;

    storyFile().writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
    final Directory plugin = Directory('${cache.path}/$kSharePluginCacheFolder')
      ..createSync();
    File('${plugin.path}/$kStoryFileName')
        .writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
    final File unrelatedCache = File('${cache.path}/keep.bin')
      ..writeAsBytesSync(<int>[1]);
    final File unrelatedCode = File('${codeCache.path}/keep.bin')
      ..writeAsBytesSync(<int>[1]);

    expect(shareCacheDirectoryFor(codeCache).path,
        Directory('${data.path}/cache').path);

    purgeStoryCache();

    expect(storyFile().existsSync(), isFalse);
    expect(plugin.existsSync(), isFalse,
        reason: 'the plugin copy of the last shared story holds the user '
            'photo: "no la guardamos" (D37)');
    expect(unrelatedCache.existsSync(), isTrue);
    expect(unrelatedCode.existsSync(), isTrue);
  });

  test('a trailing separator on the temp path resolves the same way', () {
    final Directory codeCache = Directory('${data.path}/code_cache/');
    String norm(String p) => p.replaceAll('\\', '/');
    expect(norm(shareCacheDirectoryFor(codeCache).path),
        norm('${data.path}/cache'));
  });

  test(
      'non-Android layout (temp dir not named code_cache): the plugin '
      'folder is looked for inside the temp dir, a sibling "cache" is never '
      'touched', () {
    final Directory tmp = Directory('${data.path}/tmp')..createSync();
    final Directory siblingPlugin =
        Directory('${data.path}/cache/$kSharePluginCacheFolder')
          ..createSync(recursive: true);
    final Directory ownPlugin =
        Directory('${tmp.path}/$kSharePluginCacheFolder')..createSync();
    storyCacheDirectory = () => tmp;

    expect(shareCacheDirectoryFor(tmp).path, tmp.path);
    purgeStoryCache();

    expect(ownPlugin.existsSync(), isFalse);
    expect(siblingPlugin.existsSync(), isTrue,
        reason: 'outside the app sandbox layout we only touch our temp dir');
  });

  test('missing directories: the purge is a silent no-op', () {
    storyCacheDirectory = () => Directory('${data.path}/nope/code_cache');
    expect(purgeStoryCache, returnsNormally);
  });
}
