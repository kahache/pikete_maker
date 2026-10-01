import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/analyzing/analyzing_screen.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/features/story/story_export.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valid 1×1 px PNG: the tests' "photo" (we do not need content, only
/// decodable bytes for the preview and the analysis step).
Uint8List _testPhoto() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );

/// Fake picker: always returns the same photo (or null = cancel).
class _FakePicker implements PhotoPicker {
  _FakePicker([this.bytes]);

  final Uint8List? bytes;
  final List<PhotoSource> calls = <PhotoSource>[];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    calls.add(source);
    return bytes;
  }
}

/// Fake picker for E1: camera denied, gallery OK.
class _CameraDeniedPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    if (source == PhotoSource.camera) throw CameraPermissionDeniedException();
    return _testPhoto();
  }
}

/// Engine that never finishes: keeps the "analyzing" screen stable so it can
/// be inspected without depending on timings (or pending timers).
class _HangingEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) =>
      Completer<AnalysisResult>().future;
}

/// Engine that always fails → E3.
class _FailingEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async =>
      throw const ColorEngineException('pipeline down');
}

/// Engine that never sees an outfit → E4 (not retried).
class _NoOutfitEngine implements ColorEngine {
  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async =>
      throw const ColorEngineException('no outfit', isNoOutfit: true);
}

/// Engine that finishes INSTANTLY with a fixed result — the sub-second real
/// phone that motivated the minimum display window (#55).
class _InstantEngine implements ColorEngine {
  static const AnalysisResult result = AnalysisResult(
    baseIndex: 0,
    palette: <ColorSample>[
      ColorSample(color: Color(0xFFE13683), weight: 0.6),
      ColorSample(color: Color(0xFF9CA6C6), weight: 0.4),
    ],
    harmonies: <Harmony>[
      Harmony(
        type: HarmonyType.complementary,
        name: 'Complementario',
        description: 'Contraste máximo, 2 colores',
        colors: <Color>[Color(0xFFE13683), Color(0xFF36E194)],
      ),
    ],
  );

  @override
  Future<AnalysisResult> analyze(Uint8List imageBytes) async => result;
}

/// App under test with injected fakes (no native plugins).
PiketeMakerApp _app({
  OnboardingService? onboarding,
  PhotoPicker? picker,
  ColorEngine? engine,
}) {
  return PiketeMakerApp(
    onboarding: onboarding ?? OnboardingServiceInMemory(),
    picker: picker ?? _FakePicker(_testPhoto()),
    engine: engine ?? _HangingEngine(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Service already marked as seen (launches after the first one).
  Future<OnboardingService> alreadySeen() async {
    final OnboardingServiceInMemory s = OnboardingServiceInMemory();
    await s.markSeen();
    return s;
  }

  group('D12 critical path', () {
    testWidgets(
        'First launch: the F13 tutorial opens by itself and Saltar stays on Home',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Step 2 · the tutorial appears WITHOUT touching anything
      // (onboardingSeen gate).
      expect(find.text('Empezar'), findsOneWidget);
      expect(find.text('Saltar'), findsOneWidget);

      // ONB-1 → ONB-2 (pro tip).
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(find.text('TIP PRO'), findsOneWidget);
      expect(find.text('Hacer mi primera foto'), findsOneWidget);

      // Saltar → split Home (D26: two zones, whoever skips wants to explore).
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);
    });

    testWidgets('Later launches: no tutorial, and re-accessible from Home',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app(onboarding: await alreadySeen()));
      await tester.pumpAndSettle();

      // Straight to the split Home, no tutorial ("Saltar" is its marker:
      // "Empezar" now also lives on the Home zones' affordances).
      expect(find.text('Saltar'), findsNothing);
      expect(find.text('Mis zapas'), findsOneWidget);
      expect(find.text('Mi pikete'), findsOneWidget);

      // Discreet re-entry: "Cómo hacer la foto".
      await tester.tap(find.byTooltip('Cómo hacer la foto'));
      await tester.pumpAndSettle();
      expect(find.text('Empezar'), findsOneWidget);
    });

    testWidgets('"Hacer mi primera foto" chains into the source sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer mi primera foto'));
      await tester.pumpAndSettle();

      // Source sheet over the Home, with the F13 hint.
      expect(find.text('¿De dónde sacamos la foto?'), findsOneWidget);
      expect(find.text('Hacer una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Fondo liso = colores más finos.'), findsOneWidget);
    });

    testWidgets('Home → sheet → gallery → confirm → analyzing (ad slot)',
        (WidgetTester tester) async {
      final _FakePicker picker = _FakePicker(_testPhoto());
      await tester.pumpWidget(
        _app(onboarding: await alreadySeen(), picker: picker),
      );
      await tester.pumpAndSettle();

      // Split Home (D26): "Mi pikete" is the outfit-flow entry.
      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      // Confirm photo: last cheap exit before the wait.
      expect(picker.calls, <PhotoSource>[PhotoSource.gallery]);
      expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
      expect(find.text('Analizar'), findsOneWidget);
      expect(find.text('Repetir'), findsOneWidget);

      await tester.tap(find.text('Analizar'));
      await tester.pump();
      await tester.pump();

      // Step 4 · analyzing: progress + rewarded slot (first attempt).
      expect(find.text('Leyendo los colores de tu fit…'), findsOneWidget);
      expect(find.text('HUECO REWARDED · F8 · ADMOB'), findsOneWidget);

      await tester.pumpAndSettle(); // drains the progress animation
    });
  });

  group('Ugly states', () {
    testWidgets('E1 · camera denied: the gallery remains an exit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(onboarding: await alreadySeen(), picker: _CameraDeniedPicker()),
      );
      await tester.pumpAndSettle();

      // Split Home (D26): "Mi pikete" is the outfit-flow entry.
      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer una foto'));
      await tester.pumpAndSettle();

      // E1 template. The primary is "Cómo activarla" (#34: no settings
      // plugin in the demo → the CTA promises guidance, not deep-linking).
      expect(find.text('Sin cámara no hay fit.'), findsOneWidget);
      expect(find.text('Cómo activarla'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsNothing);

      // The CTA delivers what it says: the manual path to the permission.
      await tester.tap(find.text('Cómo activarla'));
      await tester.pump();
      expect(
        find.text(
            'Ajustes del sistema → Apps → PiketeMaker → Permisos → Cámara.'),
        findsOneWidget,
      );

      // Never a dead end: gallery from E1 → confirm photo.
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
    });

    /// Drives home → sheet → gallery → confirm → Analizar and settles on the
    /// ugly state the [engine] produces.
    Future<void> pumpToUglyState(
      WidgetTester tester,
      ColorEngine engine,
    ) async {
      await tester.pumpWidget(
        _app(onboarding: await alreadySeen(), engine: engine),
      );
      await tester.pumpAndSettle();
      // Split Home (D26): "Mi pikete" is the outfit-flow entry.
      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      // prepareImageForAnalysis does REAL engine work (decode/re-encode):
      // fake-async pumps do not drive it, so this stretch runs under
      // runAsync, which lets real async complete.
      await tester.runAsync(() async {
        await tester.tap(find.text('Analizar'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    testWidgets(
        'E3 · primary lands on Confirm with the source sheet open (#47)',
        (WidgetTester tester) async {
      await pumpToUglyState(tester, _FailingEngine());
      expect(find.text('No pillamos bien tu fit.'), findsOneWidget);

      // One navigation: Confirm + auto-opened source sheet, no extra tap.
      await tester.tap(find.text('Probar con otra foto'));
      await tester.pumpAndSettle();
      expect(find.text('¿De dónde sacamos la foto?'), findsOneWidget);
      expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
    });

    testWidgets(
        'E4 · primary opens the sheet; dismissing falls back to Confirm (#47)',
        (WidgetTester tester) async {
      await pumpToUglyState(tester, _NoOutfitEngine());
      expect(find.text('Aquí no vemos un outfit claro.'), findsOneWidget);

      await tester.tap(find.text('Hacer otra foto'));
      await tester.pumpAndSettle();
      expect(find.text('¿De dónde sacamos la foto?'), findsOneWidget);
      expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);

      // Dismissing the sheet leaves Confirm-with-old-photo as fallback (the
      // UX-audit F-3 fix keeps an actionable screen, never a dead end).
      await tester.tapAt(const Offset(200, 100)); // barrier
      await tester.pumpAndSettle();
      expect(find.text('¿De dónde sacamos la foto?'), findsNothing);
      expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
    });

    testWidgets('Retry without ad: the slot shows a capture tip (F8 rule)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AnalyzingScreen(
            engine: _HangingEngine(),
            picker: _FakePicker(),
            args: AnalyzingArgs(photo: _testPhoto(), withAd: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HUECO REWARDED · F8 · ADMOB'), findsNothing);
      expect(find.text('TIP'), findsOneWidget);
      expect(
        find.text('Fondo liso y un paso atrás: así te clavo los colores.'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });
  });

  group('#55 · minimum display of analyzing', () {
    /// Drives home → sheet → gallery → confirm → Analizar. The engine work
    /// (image decode + analysis) is REAL async → runAsync, same pattern as
    /// pumpToUglyState. The min-display window, in contrast, is the progress
    /// ticker: fake-clock frames, driven deterministically with
    /// tester.pump(duration).
    Future<void> tapAnalizar(WidgetTester tester, ColorEngine engine) async {
      await tester.pumpWidget(
        _app(onboarding: await alreadySeen(), engine: engine),
      );
      await tester.pumpAndSettle();
      // Split Home (D26): "Mi pikete" is the outfit-flow entry.
      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Analizar'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
    }

    testWidgets('a sub-second result is HELD until the window elapses',
        (WidgetTester tester) async {
      await tapAnalizar(tester, _InstantEngine());

      // The engine already finished, but the screen holds the result.
      expect(find.text('Leyendo los colores de tu fit…'), findsOneWidget);
      expect(find.text('Tu paleta'), findsNothing);

      // Still held after 1 s (well inside the window).
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Tu paleta'), findsNothing);

      // The full window elapses → the result is released.
      await tester.pump(AnalyzingScreen.minDisplayDuration);
      await tester.pumpAndSettle();
      expect(find.text('Tu paleta'), findsOneWidget);
    });

    testWidgets(
        'N1 (D37): the analyzed photo reaches the result screen, in memory',
        (WidgetTester tester) async {
      final Uint8List photo = _testPhoto();
      await tester.pumpWidget(_app(
        onboarding: await alreadySeen(),
        engine: _InstantEngine(),
        picker: _FakePicker(photo),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi pikete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Analizar'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(AnalyzingScreen.minDisplayDuration);
      await tester.pumpAndSettle();

      final ResultScreen screen =
          tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.photo, same(photo),
          reason: 'the story preview can offer "Incluir mi foto"');
    });

    testWidgets('E3 does NOT wait the window: failing fast is honest',
        (WidgetTester tester) async {
      await tapAnalizar(tester, _FailingEngine());

      // Only the route transition (≪ minDisplayDuration) and E3 is there.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No pillamos bien tu fit.'), findsOneWidget);
    });

    testWidgets('E4 does NOT wait the window either',
        (WidgetTester tester) async {
      await tapAnalizar(tester, _NoOutfitEngine());

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Aquí no vemos un outfit claro.'), findsOneWidget);
    });
  });

  group('N1 (D37) · story cache hygiene', () {
    testWidgets(
        'a story PNG left behind (app killed with the sheet open) is DELETED '
        'on app start', (WidgetTester tester) async {
      final Directory tmp = Directory.systemTemp.createTempSync('pk_start_');
      final Directory Function() previous = storyCacheDirectory;
      storyCacheDirectory = () => tmp;
      addTearDown(() {
        storyCacheDirectory = previous;
        tmp.deleteSync(recursive: true);
      });
      storyFile().writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
      expect(storyFile().existsSync(), isTrue);

      await tester.pumpWidget(_app(onboarding: await alreadySeen()));

      expect(storyFile().existsSync(), isFalse,
          reason: '"no la guardamos" stays literally true');
    });

    testWidgets(
        "share_plus's own copy of the last shared story (cacheDir/share_plus) "
        'is DELETED on app start too', (WidgetTester tester) async {
      final Directory tmp = Directory.systemTemp.createTempSync('pk_start_');
      final Directory Function() previous = storyCacheDirectory;
      storyCacheDirectory = () => tmp;
      addTearDown(() {
        storyCacheDirectory = previous;
        tmp.deleteSync(recursive: true);
      });
      final Directory plugin =
          Directory('${tmp.path}/$kSharePluginCacheFolder')..createSync();
      File('${plugin.path}/$kStoryFileName')
          .writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
      // Something else in the cache is NOT ours to delete.
      final File other = File('${tmp.path}/keep.bin')..writeAsBytesSync(<int>[1]);

      await tester.pumpWidget(_app(onboarding: await alreadySeen()));

      expect(plugin.existsSync(), isFalse,
          reason: 'the plugin copy holds the user photo too (D37)');
      expect(other.existsSync(), isTrue, reason: 'only story artifacts go');
    });

    test('deleting when there is no story file is a silent no-op', () {
      final Directory tmp = Directory.systemTemp.createTempSync('pk_start_');
      final Directory Function() previous = storyCacheDirectory;
      storyCacheDirectory = () => tmp;
      addTearDown(() {
        storyCacheDirectory = previous;
        tmp.deleteSync(recursive: true);
      });
      expect(deleteStoryFile, returnsNormally);
    });
  });

  group('Result screen (step 5)', () {
    testWidgets('Renders palette, BASE and harmonies',
        (WidgetTester tester) async {
      const AnalysisResult result = AnalysisResult(
        baseIndex: 0,
        palette: <ColorSample>[
          ColorSample(color: Color(0xFFE13683), weight: 0.6),
          ColorSample(color: Color(0xFF9CA6C6), weight: 0.4),
        ],
        harmonies: <Harmony>[
          Harmony(
            type: HarmonyType.complementary,
            name: 'Complementario',
            description: 'Contraste máximo, 2 colores',
            colors: <Color>[Color(0xFFE13683), Color(0xFF36E194)],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ResultScreen(result: result),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tu paleta'), findsOneWidget);
      expect(find.text('Combina con'), findsOneWidget);
      expect(find.text('BASE'), findsOneWidget);
      expect(find.text('#E13683'), findsOneWidget); // HEX in mono
      expect(find.text('Complementario'), findsOneWidget);
      // Skeleton CTAs (visual stubs until F5-lite/F6).
      expect(find.text('Ver looks así'), findsOneWidget);
      expect(find.text('Súbela a tu story'), findsOneWidget);
    });
  });

  group('OnboardingService', () {
    test('OnboardingServicePrefs persists the flag across instances', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final OnboardingServicePrefs service = OnboardingServicePrefs();

      expect(await service.seen(), isFalse);
      await service.markSeen();
      // Another instance reads the same store: the tutorial does not repeat.
      expect(await OnboardingServicePrefs().seen(), isTrue);
    });
  });
}
