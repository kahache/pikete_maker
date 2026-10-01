import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/result/looks_search.dart';

import 'import_graph.dart';

/// Q2 · P2 — PHOTO-BOUNDARY LOCKS (security audit, 2026-10-01).
///
/// The product promise (D2, ONB-1): "tu foto no sale de tu móvil y no la
/// guardamos". The photo bytes live in the capture → analyzing → result /
/// recolor → story path; the ONLY way they leave is the user's own OS share
/// of the story PNG (D37). These tests break the build if code that CAN send
/// something off the device (analytics / crash / telemetry seams, browser
/// deep-links) gains a path to the photo or the engine, or if the engine
/// gains a network path. Sibling locks: `recolor_boundary_test.dart` (I2
/// memory-only), `release_manifest_lock_test.dart` (no INTERNET),
/// `story_png_metadata_test.dart` (no EXIF/GPS in the shared PNG).
///
/// Mechanism: a static import scan (`import_graph.dart`). Limits: a raw
/// MethodChannel / ffi / reflection path is invisible to it — the platform
/// lock (no INTERNET permission) covers the network side of those.

/// Modules whose job is to send data (some day) off the device. Every
/// `lib/core/telemetry*` directory is included automatically.
List<String> _egressFiles() => <String>[
      ...dartFilesUnder('lib/core/analytics'),
      ...dartFilesUnder('lib/core/crash'),
      for (final FileSystemEntity e in Directory('lib/core').listSync())
        if (e is Directory &&
            normalizePath(e.path).split('/').last.startsWith('telemetry'))
          ...dartFilesUnder(normalizePath(e.path)),
    ];

/// The photo / engine side of the boundary.
const List<String> _engineDirs = <String>[
  'lib/core/color_engine/',
  'lib/core/segmentation/',
  'lib/core/recolor/',
];

/// Everything that holds the photo bytes in the UI (screens / pickers).
const String _featuresDir = 'lib/features/';

/// External packages that carry or produce photo pixels / files.
const List<String> _photoPackages = <String>[
  'package:image/',
  'package:image_picker',
  'package:camera',
  'package:share_plus',
  'package:tflite_flutter',
  'package:path_provider',
];

/// Identifiers of photo-carrying types. Matched on comment-free code.
final RegExp _photoTypes = RegExp(
    r'\b(Uint8List|ByteData|XFile|ImageProvider|MemoryImage|RawImage|'
    r'SegmentationClassMap|GarmentSegmentation|RecolorSession)\b|ui\.Image\b');

/// `dart:ui` may only be imported with a `show` list free of image types.
final RegExp _dartUiImageNames =
    RegExp(r'\b(Image|Picture|Codec|FrameInfo|ImmutableBuffer)\b');

/// Network capability, by API name, for the engine side.
final RegExp _networkApis = RegExp(
    r'\b(HttpClient|HttpRequest|HttpServer|Socket|RawSocket|SecureSocket|'
    r'WebSocket|RawDatagramSocket|InternetAddress|NetworkInterface)\b');

/// External imports the engine side may use (anything else must be reviewed
/// here first). `tflite_flutter` is the one third-party package INSIDE the
/// boundary: the MediaPipe interpreter (audited 2026-10-01: Dart side has no
/// network API; native side is blocked by the missing INTERNET permission).
bool _engineExternalAllowed(String uri, String clause) {
  if (uri == 'dart:io') {
    // Only `Platform` (runtime detection) — never files or sockets.
    return RegExp(r'\bshow\s+Platform\s*$').hasMatch(clause.trim());
  }
  const List<String> allowed = <String>[
    'dart:math',
    'dart:typed_data',
    'dart:ui',
    'dart:isolate',
    'dart:developer',
    'dart:async',
    'dart:collection',
    'package:flutter/foundation.dart',
    'package:flutter/painting.dart',
    'package:flutter/services.dart',
    'package:tflite_flutter/',
  ];
  return allowed.any((String a) => uri == a || uri.startsWith(a));
}

/// The browser deep-link callers reviewed on 2026-10-01. A NEW caller of
/// `url_launcher` must be reviewed (what goes into the URL?) and added here.
const Set<String> _reviewedUrlLauncherCallers = <String>{
  'lib/features/result/looks_search.dart',
  'lib/features/settings/telemetry_notice_sheet.dart',
};

/// Engine files a deep-link builder may import: pure colour math / colour
/// value types (no pixel buffers). The pixel-handling engine files
/// (`color_engine_dart.dart`, `garments.dart`, `borders.dart`, `kmeans.dart`,
/// `color_engine.dart`) are NOT here on purpose.
const Set<String> _colourOnlyEngineFiles = <String>{
  'lib/core/color_engine/display.dart',
  'lib/core/color_engine/models.dart',
  'lib/core/color_engine/harmony.dart',
  'lib/core/color_engine/palette.dart',
};

/// The app's reviewed direct dependencies (pubspec `dependencies:`). A new
/// one is a new third party inside the APK: review it against the photo
/// boundary (does it get the bytes? does it open sockets?) before adding it.
const Set<String> _reviewedDependencies = <String>{
  'flutter',
  'flutter_localizations',
  'intl',
  'cupertino_icons',
  'image_picker',
  'shared_preferences',
  'url_launcher',
  'tflite_flutter',
  'share_plus',
  'path_provider_android',
  'path_provider_foundation',
};

/// Ads / analytics / attribution / crash SDKs. None may appear in the
/// resolved graph (pubspec.lock) without a security review: D33 telemetry is
/// our own anonymous-card sink, and ads (F8, #97) are OFF until decided.
final RegExp _trackerPackages = RegExp(
    r'^(firebase\w*|google_mobile_ads|gma_\w+|facebook\w*|flutter_facebook\w*|'
    r'applovin\w*|unity_ads\w*|ironsource\w*|appodeal\w*|sentry\w*|'
    r'amplitude\w*|mixpanel\w*|segment_analytics\w*|posthog\w*|appsflyer\w*|'
    r'adjust_sdk|branch_sdk\w*|flutter_branch_sdk|onesignal\w*|datadog\w*|'
    r'bugsnag\w*|instabug\w*|smartlook\w*|clarity\w*)$');

List<String> _pubspecSection(String section) {
  final List<String> lines = File('pubspec.yaml').readAsLinesSync();
  final List<String> names = <String>[];
  bool inside = false;
  for (final String line in lines) {
    if (RegExp(r'^\S').hasMatch(line)) {
      inside = line.trimRight() == '$section:';
      continue;
    }
    final RegExpMatch? m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (inside && m != null) names.add(m.group(1)!);
  }
  return names;
}

void main() {
  test('the lock scans real code (non-vacuous)', () {
    expect(_egressFiles(), isNotEmpty);
    for (final String dir in _engineDirs) {
      expect(dartFilesUnder(dir), isNotEmpty, reason: dir);
    }
    expect(filesImporting('package:url_launcher'), isNotEmpty);
  });

  group('egress modules (analytics / crash / telemetry*)', () {
    test(
        'cannot reach the engine, the photo UI or photo packages, even '
        'transitively', () {
      final Closure c = closureOf(_egressFiles());
      final List<String> hits = <String>[
        for (final String f in c.files)
          if (_engineDirs.any(f.startsWith) || f.startsWith(_featuresDir))
            'reaches $f',
        for (final MapEntry<String, String> e in c.externals.entries)
          if (_photoPackages.any(e.key.startsWith))
            '${e.value} imports ${e.key}',
      ];
      expect(hits, isEmpty,
          reason: 'telemetry/analytics/crash must never be able to see the '
              'photo, a mask or the engine (D2/D33)');
    });

    test('never names a photo-carrying type nor imports dart:ui images', () {
      final List<String> hits = <String>[];
      for (final String f in closureOf(_egressFiles()).files) {
        if (_photoTypes.hasMatch(codeWithoutComments(f))) {
          hits.add('$f: ${_photoTypes.firstMatch(codeWithoutComments(f))![0]}');
        }
        for (final ImportEdge e in importsOf(f)) {
          if (e.uri == 'dart:ui' &&
              (!e.clause.contains(' show ') ||
                  _dartUiImageNames.hasMatch(e.clause))) {
            hits.add('$f: dart:ui without a narrow show list');
          }
        }
      }
      expect(hits, isEmpty);
    });
  });

  group('engine side (color_engine / segmentation / recolor)', () {
    test('its transitive closure stays inside the engine dirs', () {
      final List<String> roots = <String>[
        for (final String d in _engineDirs) ...dartFilesUnder(d),
      ];
      final Closure c = closureOf(roots);
      final List<String> outside =
          c.files.where((String f) => !_engineDirs.any(f.startsWith)).toList();
      expect(outside, isEmpty,
          reason: 'the engine must not import UI, analytics, telemetry, '
              'crash or story code');
    });

    test(
        'imports no network / file / third-party package beyond the '
        'reviewed allowlist', () {
      final List<String> hits = <String>[];
      for (final String d in _engineDirs) {
        for (final String f in dartFilesUnder(d)) {
          for (final ImportEdge e in importsOf(f)) {
            if (e.isExternal && !_engineExternalAllowed(e.uri, e.clause)) {
              hits.add('$f imports ${e.uri}');
            }
          }
          final RegExpMatch? api =
              _networkApis.firstMatch(codeWithoutComments(f));
          if (api != null) hits.add('$f uses ${api[0]}');
        }
      }
      expect(hits, isEmpty,
          reason: 'inference and the colour pipeline run offline (D2): no '
              'sockets, no HttpClient, no package:http, no file access');
    });
  });

  group('browser deep-links (url_launcher callers)', () {
    test('the set of callers is the reviewed one', () {
      expect(filesImporting('package:url_launcher').toSet(),
          _reviewedUrlLauncherCallers,
          reason: 'a new url_launcher caller must be security-reviewed: '
              'what goes into the URL?');
    });

    test('callers import no photo / pixel code and name no photo type', () {
      final List<String> hits = <String>[];
      for (final String f in _reviewedUrlLauncherCallers) {
        for (final ImportEdge e in importsOf(f)) {
          final String? t = e.target;
          if (t != null) {
            final bool engine = _engineDirs.any(t.startsWith);
            if (engine && !_colourOnlyEngineFiles.contains(t)) {
              hits.add('$f imports $t');
            }
            if (t.startsWith('lib/features/capture/') ||
                t.startsWith('lib/features/story/') ||
                t.startsWith('lib/features/recolor/') ||
                t.startsWith('lib/features/analyzing/')) {
              hits.add('$f imports $t');
            }
          } else if (_photoPackages.any(e.uri.startsWith)) {
            hits.add('$f imports ${e.uri}');
          }
        }
        final RegExpMatch? type =
            _photoTypes.firstMatch(codeWithoutComments(f));
        if (type != null) hits.add('$f names ${type[0]}');
      }
      expect(hits, isEmpty);
    });

    test(
        'the looks URL carries only colour words: fixed host, q + tbm only, '
        'no hex, no digits', () {
      const List<List<Color>> combos = <List<Color>>[
        <Color>[Color(0xFF2E9E86), Color(0xFFC4572A)],
        <Color>[Color(0xFF101010), Color(0xFFF5F5F0), Color(0xFF7B1FA2)],
        <Color>[
          Color(0xFF2C6EC4),
          Color(0xFFE0A000),
          Color(0xFF12A150),
          Color(0xFFD6248C)
        ],
      ];
      for (final String lang in <String>[
        'es',
        'en',
        'ca',
        'fr',
        'zh',
        'ko',
        'ja'
      ]) {
        for (final List<Color> combo in combos) {
          final Uri uri =
              looksSearchUri(looksSearchQuery(combo, language: lang));
          expect(uri.scheme, 'https');
          expect(uri.host, 'www.google.com');
          expect(uri.path, '/search');
          expect(uri.queryParameters.keys.toSet(), <String>{'q', 'tbm'});
          expect(uri.queryParameters['tbm'], 'isch');
          final String q = uri.queryParameters['q']!;
          expect(q, isNot(contains('#')), reason: '$lang: no hex codes');
          expect(RegExp(r'\d').hasMatch(q), isFalse,
              reason: '$lang "$q": no numbers (no hex, no ids)');
          expect(q.length, lessThan(80), reason: '$lang "$q"');
        }
      }
    });
  });

  group('third-party SDKs', () {
    test('direct dependencies are the security-reviewed set', () {
      expect(_pubspecSection('dependencies').toSet(), _reviewedDependencies,
          reason: 'a new dependency is a new third party in the APK: review '
              'it against the photo boundary first, then add it here');
    });

    test('no ads / analytics / attribution / crash SDK in the resolved graph',
        () {
      final List<String> pkgs = <String>[
        for (final String line in File('pubspec.lock').readAsLinesSync())
          if (RegExp(r'^  [a-z0-9_]+:$').hasMatch(line))
            line.trim().replaceAll(':', ''),
      ];
      expect(pkgs, isNotEmpty);
      expect(pkgs.where(_trackerPackages.hasMatch).toList(), isEmpty,
          reason: 'ads (F8/#97) and third-party analytics need a security '
              'review of the photo boundary before they enter the build');
    });
  });
}
