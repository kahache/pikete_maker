import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/recolor/recolor_slot.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:piketemaker/features/story/story_preferences.dart';
import 'package:piketemaker/l10n/l10n.dart';
import 'package:piketemaker/theme/app_theme.dart';

import 'recolor_test_helpers.dart';

/// I2 (D38) BOUNDARY LOCKS — rules that must break the build, not live in a
/// doc note (CLAUDE.md working practice 3):
///
///  1. PRIVACY: the recolor code (engine `lib/core/recolor/`, UI
///     `lib/features/recolor/`) never touches the file system or persistent
///     storage. The recolored bitmap reaches disk ONLY inside the story PNG,
///     and that write lives in `lib/features/story/` (the D37 flow, with its
///     own deletion tests). The end-to-end check (nothing on disk during the
///     flow, the story file deleted on close) is in `recolor_flow_test.dart`.
///  2. NO TELEMETRY (CEO, D38): the recolor code imports no analytics /
///     telemetry / crash module and logs no event.
///  3. OUTFIT ONLY: the sneaker result never shows the recolor.

const List<String> _recolorDirs = <String>[
  'lib/core/recolor',
  'lib/features/recolor',
];

/// Source patterns that would let a recolored pixel (or anything about it)
/// leave memory or the device.
final Map<String, RegExp> _forbidden = <String, RegExp>{
  'dart:io (file system)': RegExp(r'''import\s+['"]dart:io['"]'''),
  'File / Directory': RegExp(r'\b(File|Directory|RandomAccessFile)\s*\('),
  'writeAsBytes': RegExp(r'writeAsBytes'),
  'shared_preferences': RegExp(r'shared_preferences'),
  'path_provider': RegExp(r'path_provider'),
  'analytics / telemetry / crash import': RegExp(
      r'''import\s+['"][^'"]*(analytics|telemetry|core/crash)[^'"]*['"]'''),
  'an analytics event':
      RegExp(r'(AnalyticsService|AnalyticsEvent|CrashReporter)'),
  'network': RegExp(r'''(package:http|HttpClient|dart:html)'''),
};

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('the recolor modules exist (the lock scans real code)', () {
    for (final String dir in _recolorDirs) {
      expect(_dartFiles(dir), isNotEmpty, reason: dir);
    }
  });

  for (final String dir in _recolorDirs) {
    test('$dir: no file system, storage, network or telemetry', () {
      final List<String> hits = <String>[];
      for (final File file in _dartFiles(dir)) {
        final String code = file.readAsStringSync();
        _forbidden.forEach((String what, RegExp pattern) {
          if (pattern.hasMatch(code)) hits.add('${file.path}: $what');
        });
      }
      expect(hits, isEmpty,
          reason: 'the recolor must stay memory-only and telemetry-free');
    });
  }

  testWidgets('the sneaker result never shows the recolor (outfit only)',
      (WidgetTester tester) async {
    final FakeOpener opener = FakeOpener(FakeRecolorSession(kBoth));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SneakerResultScreen(
        args: SneakerResultArgs(
          result: outfitResult(map: kFakeClassMap),
          photo: Uint8List(8),
        ),
        storyPreferences: StoryPreferencesInMemory(),
        shareStory: (File png, Rect? origin) async => 'success',
      ),
    ));
    await tester.pumpAndSettle();
    final AppLocalizations es = lookupAppLocalizations(const Locale('es'));
    expect(find.byKey(RecolorSlot.slotKey), findsNothing);
    expect(find.text(es.recolorCta), findsNothing);
    expect(opener.calls, 0);
  });
}
