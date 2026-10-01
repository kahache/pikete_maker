import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Q2 · P1 — RELEASE MANIFEST LOCK (security audit, 2026-10-01).
///
/// The strongest privacy guarantee the app has is platform-enforced: the
/// release APK declares NO `INTERNET` permission, so the kernel refuses any
/// socket the app (or a third-party library inside it) tries to open — the
/// photo physically cannot be uploaded. And the only component other apps
/// can start is the launcher activity. This file breaks the build if either
/// changes without a security review.
///
/// Two layers, because `flutter test` cannot run Gradle's manifest merger:
///
///  1. SOURCE (always runs): `android/app/src/main/AndroidManifest.xml` adds
///     no permission, keeps the three `tools:node="remove"` lines that strip
///     what tflite's GPU library implies, exports only the launcher, and
///     enables no cleartext / debuggable / custom network config. The
///     debug/profile manifests may add INTERNET (Flutter tooling) — never
///     anything else.
///  2. MERGED (runs when a release APK + aapt2 exist, i.e. on the build PC
///     right after `flutter build apk --release --split-per-abi`; SKIPPED
///     otherwise, with the reason printed): dumps the real merged manifest
///     of every split APK with `aapt2` and pins the permission set, the
///     exported components, the providers and the FileProvider paths.
///
/// Limits (honest): layer 2 checks whatever APK is on disk — it can be stale
/// if the source changed after the last build (layer 1 then covers the
/// source side). CI has no APK, so there layer 2 is skipped. The PM rule
/// that closes the gap: run `flutter test test/security/` after EVERY
/// release build, before installing or distributing the APK.

const String _mainManifest = 'android/app/src/main/AndroidManifest.xml';
const String _apkDir = 'build/app/outputs/flutter-apk';
const String _appId = 'com.piketemaker.app';

/// Permissions the merged release manifest may declare. The androidx.core
/// signature permission protects the app's own non-exported dynamic
/// receivers (protectionLevel=signature): it grants nothing to anyone else.
const Set<String> _allowedMergedPermissions = <String>{
  '$_appId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
};

/// The permissions implied by `org.tensorflow.lite.gpu.api` (no
/// targetSdkVersion) that the main manifest must keep stripping.
const Set<String> _mustRemove = <String>{
  'android.permission.READ_PHONE_STATE',
  'android.permission.READ_EXTERNAL_STORAGE',
  'android.permission.WRITE_EXTERNAL_STORAGE',
};

/// Components other apps may start. ProfileInstallReceiver is exported but
/// guarded by `android.permission.DUMP` (signature|privileged: only the
/// shell / Play Store can send to it) — pinned below with that guard.
const Map<String, String?> _allowedExported = <String, String?>{
  'com.piketemaker.piketemaker.MainActivity': null,
  'androidx.profileinstaller.ProfileInstallReceiver': 'android.permission.DUMP',
};

/// Content providers in the merged manifest (all must be exported=false).
const Set<String> _allowedProviders = <String>{
  'io.flutter.plugins.imagepicker.ImagePickerFileProvider',
  'dev.fluttercommunity.plus.share.ShareFileProvider',
  'androidx.startup.InitializationProvider',
};

/// FileProvider path specs, per provider resource name: (tag, path). The
/// share provider exposes ONLY `cache/share_plus/` (where the story copy
/// lives). The image_picker provider exposes the whole cache dir — the
/// plugin's own default, accepted 2026-10-01: the provider is not exported
/// and only grants the one camera-output URI it creates (see the report).
const Map<String, List<(String, String)>> _allowedFilePaths =
    <String, List<(String, String)>>{
  'xml/flutter_share_file_paths': <(String, String)>[
    ('cache-path', 'share_plus/'),
  ],
  'xml/flutter_image_picker_file_paths': <(String, String)>[
    ('cache-path', '.'),
  ],
};

// ---------------------------------------------------------------- layer 1

void main() {
  group('source manifest (always)', () {
    final String src = File(_mainManifest)
        .readAsStringSync()
        // Strip XML comments: prose must never satisfy or trip the lock.
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    test('adds no permission; keeps stripping the three implied ones', () {
      final Iterable<RegExpMatch> perms =
          RegExp(r'<uses-permission\b[^>]*>').allMatches(src);
      final Set<String> removed = <String>{};
      final List<String> added = <String>[];
      for (final RegExpMatch m in perms) {
        final String tag = m[0]!;
        final String name =
            RegExp(r'android:name="([^"]+)"').firstMatch(tag)![1]!;
        if (tag.contains('tools:node="remove"')) {
          removed.add(name);
        } else {
          added.add(name);
        }
      }
      expect(added, isEmpty,
          reason: 'the release declares NO permission (no INTERNET: D2). '
              'Adding one (e.g. INTERNET for telemetry, BACKLOG C1) is a '
              'deliberate, reviewed change to this lock.');
      expect(removed, containsAll(_mustRemove));
      expect(RegExp(r'<uses-permission-sdk-23\b').hasMatch(src), isFalse);
    });

    test('exports only the launcher activity', () {
      final List<String> exported = <String>[
        for (final RegExpMatch m
            in RegExp(r'<(activity|service|receiver|provider)\b[^>]*>')
                .allMatches(src))
          if (m[0]!.contains('android:exported="true"'))
            RegExp(r'android:name="([^"]+)"').firstMatch(m[0]!)![1]!,
      ];
      expect(exported, <String>['.MainActivity']);
      expect(RegExp(r'<intent-filter\b').allMatches(src).length, 1,
          reason: 'only MAIN/LAUNCHER: no deep-link / VIEW / SEND filter '
              'that another app could use to push data in');
    });

    test('no debuggable, cleartext or custom network config', () {
      expect(src, isNot(contains('android:debuggable')));
      expect(src, isNot(contains('android:usesCleartextTraffic="true"')));
      expect(src, isNot(contains('android:networkSecurityConfig')));
    });

    test('debug/profile manifests add nothing but INTERNET (tooling)', () {
      for (final String variant in <String>['debug', 'profile']) {
        final File f = File('android/app/src/$variant/AndroidManifest.xml');
        if (!f.existsSync()) continue;
        final String code =
            f.readAsStringSync().replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
        final List<String> names = <String>[
          for (final RegExpMatch m
              in RegExp(r'<uses-permission\b[^>]*android:name="([^"]+)"')
                  .allMatches(code))
            m[1]!,
        ];
        expect(
            names.toSet().difference(<String>{'android.permission.INTERNET'}),
            isEmpty,
            reason: variant);
        expect(
            RegExp(r'<(activity|service|receiver|provider)\b').hasMatch(code),
            isFalse,
            reason: variant);
      }
      expect(Directory('android/app/src/release').existsSync(), isFalse,
          reason: 'a release-only manifest would bypass layer 1');
    });
  });

  // -------------------------------------------------------------- layer 2

  group('merged release manifest of the built APKs', () {
    final String? aapt2 = _findAapt2();
    final List<File> apks = Directory(_apkDir).existsSync()
        ? (Directory(_apkDir)
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('-release.apk'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path)))
        : <File>[];
    final String? skip = aapt2 == null
        ? 'aapt2 not found (no Android SDK on this machine)'
        : apks.isEmpty
            ? 'no release APK in $_apkDir (build one, then re-run)'
            : null;

    if (skip != null) {
      test('skipped: $skip', () {}, skip: skip);
      return;
    }

    for (final File apk in apks) {
      final String name = apk.uri.pathSegments.last;
      test('$name: permissions, exported components, providers, flags',
          () async {
        final _Manifest m = _Manifest.parse(await _aapt2(aapt2!, <String>[
          'dump',
          'xmltree',
          '--file',
          'AndroidManifest.xml',
          apk.path
        ]));

        expect(m.packageName, _appId);
        expect(m.permissions.toSet(), _allowedMergedPermissions,
            reason: 'NO INTERNET (or anything else) in the release');
        expect(m.permissions, isNot(contains('android.permission.INTERNET')));

        final Map<String, String?> exported = <String, String?>{
          for (final _Element c in m.components)
            if (c.attrs['exported'] == 'true')
              c.attrs['name']!: c.attrs['permission'],
        };
        expect(exported, _allowedExported,
            reason: 'a new exported component is a new door into the app');

        final List<_Element> providers =
            m.components.where((_Element c) => c.tag == 'provider').toList();
        expect(providers.map((_Element p) => p.attrs['name']).toSet(),
            _allowedProviders);
        for (final _Element p in providers) {
          expect(p.attrs['exported'], 'false', reason: p.attrs['name']);
        }

        expect(m.application['debuggable'], isNot('true'));
        expect(m.application['usesCleartextTraffic'], isNot('true'));
        expect(m.application.containsKey('networkSecurityConfig'), isFalse);
      });

      test('$name: signed (v2+) with the release key, never a debug cert',
          () async {
        // build.gradle silently falls back to DEBUG signing when
        // key.properties is missing (other machine / CI). Such an APK must
        // never be distributed: users could not update it to the real one.
        final String? apksigner =
            _findBuildTool(Platform.isWindows ? 'apksigner.bat' : 'apksigner');
        if (apksigner == null) {
          markTestSkipped('apksigner not found');
          return;
        }
        final ProcessResult r = await Process.run(
            apksigner,
            <String>[
              'verify',
              '--verbose',
              '--print-certs',
              _nativePath(apk.absolute.path),
            ],
            runInShell: Platform.isWindows);
        // Booleans only in the expectations: a failure must not dump the
        // certificate digests into a CI log.
        final String out = '${r.stdout}';
        if (r.exitCode != 0 && !out.contains('Verifies')) {
          // No Java on this machine, typically: say so, do not pretend.
          markTestSkipped('apksigner could not run (exit ${r.exitCode})');
          return;
        }
        expect(RegExp(r'^Verifies\s*$', multiLine: true).hasMatch(out), isTrue,
            reason: 'apksigner verify failed');
        expect(
            RegExp(r'Verified using v[23](\.\d)? scheme[^:]*: true')
                .hasMatch(out),
            isTrue,
            reason: 'APK Signature Scheme v2 or v3 required (minSdk 24)');
        expect(out.contains('CN=Android Debug'), isFalse,
            reason: 'signed with a DEBUG certificate: key.properties was '
                'missing at build time — do not distribute this APK');
        expect(RegExp(r'Number of signers: 1\b').hasMatch(out), isTrue);
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('$name: FileProvider paths are the reviewed ones', () async {
        final String table =
            await _aapt2(aapt2!, <String>['dump', 'resources', apk.path]);
        for (final MapEntry<String, List<(String, String)>> e
            in _allowedFilePaths.entries) {
          final RegExpMatch? file = RegExp(
                  '${RegExp.escape(e.key)}\\s*\\n\\s*\\(\\) \\(file\\) (\\S+)')
              .firstMatch(table);
          expect(file, isNotNull, reason: '${e.key} resource not found');
          final String xml = await _aapt2(aapt2,
              <String>['dump', 'xmltree', '--file', file![1]!, apk.path]);
          final List<(String, String)> specs = <(String, String)>[];
          final List<String> lines = xml.split('\n');
          for (int i = 0; i < lines.length; i++) {
            final RegExpMatch? el =
                RegExp(r'E: ((?:cache|files|external|external-files|'
                        r'external-cache|external-media|root)-path)\b')
                    .firstMatch(lines[i]);
            if (el == null) continue;
            for (int j = i + 1; j < lines.length && j < i + 4; j++) {
              final RegExpMatch? p =
                  RegExp(r'A: path="([^"]*)"').firstMatch(lines[j]);
              if (p != null) {
                specs.add((el[1]!, p[1]!));
                break;
              }
            }
          }
          expect(specs, e.value, reason: e.key);
        }
      });
    }
  });
}

// ---------------------------------------------------------------- helpers

String? _findAapt2() =>
    _findBuildTool(Platform.isWindows ? 'aapt2.exe' : 'aapt2');

/// The newest `build-tools/<version>/<exe>` of the Android SDK found via
/// ANDROID_HOME / ANDROID_SDK_ROOT / android/local.properties.
String? _findBuildTool(String exe) {
  final List<String> roots = <String>[
    if (Platform.environment['ANDROID_HOME'] case final String h) h,
    if (Platform.environment['ANDROID_SDK_ROOT'] case final String h) h,
  ];
  final File local = File('android/local.properties');
  if (local.existsSync()) {
    for (final String line in local.readAsLinesSync()) {
      if (line.startsWith('sdk.dir=')) {
        roots.add(line
            .substring('sdk.dir='.length)
            .replaceAll(r'\:', ':')
            .replaceAll(r'\\', r'\'));
      }
    }
  }
  for (final String root in roots) {
    final Directory bt = Directory('$root/build-tools');
    if (!bt.existsSync()) continue;
    final List<Directory> versions = bt
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((Directory a, Directory b) => b.path.compareTo(a.path));
    for (final Directory v in versions) {
      final File f = File('${v.path}/$exe');
      if (f.existsSync()) return f.path;
    }
  }
  return null;
}

Future<String> _aapt2(String aapt2, List<String> args) async {
  final ProcessResult r = await Process.run(aapt2, args);
  expect(r.exitCode, 0, reason: 'aapt2 ${args.join(' ')}: ${r.stderr}');
  return r.stdout as String;
}

class _Element {
  _Element(this.tag);
  final String tag;
  final Map<String, String> attrs = <String, String>{};
}

/// Minimal reader of `aapt2 dump xmltree` output: every `E:` line opens an
/// element, the `A:` lines right after it are its attributes.
class _Manifest {
  _Manifest(
      this.packageName, this.permissions, this.components, this.application);

  final String packageName;
  final List<String> permissions;
  final List<_Element> components;
  final Map<String, String> application;

  static final RegExp _el = RegExp(r'^\s*E: ([\w-]+)');
  static final RegExp _attr =
      RegExp(r'^\s*A: (?:http://schemas\.android\.com/apk/res/android:)?'
          r'(\w+)(?:\(0x[0-9a-f]+\))?=(?:"([^"]*)"|(\S+))');

  static _Manifest parse(String dump) {
    final List<_Element> all = <_Element>[];
    _Element? current;
    for (final String line in dump.split('\n')) {
      final RegExpMatch? e = _el.firstMatch(line);
      if (e != null) {
        current = _Element(e[1]!);
        all.add(current);
        continue;
      }
      final RegExpMatch? a = _attr.firstMatch(line);
      if (a != null && current != null) {
        current.attrs[a[1]!] = a[2] ?? a[3]!;
      }
    }
    const Set<String> componentTags = <String>{
      'activity',
      'activity-alias',
      'service',
      'receiver',
      'provider'
    };
    return _Manifest(
      all.firstWhere((_Element x) => x.tag == 'manifest').attrs['package']!,
      <String>[
        for (final _Element x in all)
          if (x.tag == 'uses-permission' || x.tag == 'uses-permission-sdk-23')
            x.attrs['name']!,
      ],
      all.where((_Element x) => componentTags.contains(x.tag)).toList(),
      all.firstWhere((_Element x) => x.tag == 'application').attrs,
    );
  }
}

/// Backslashes on Windows (a `.bat` run through cmd.exe mis-parses `/`).
String _nativePath(String p) =>
    Platform.isWindows ? p.replaceAll('/', r'\') : p;
