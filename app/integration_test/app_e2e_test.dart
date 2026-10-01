import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E2E quality gate (#41, pre-beta): drives BOTH real flows (outfit and
/// sneaker, Phase 2S) on a real device/emulator with the REAL Dart engine,
/// REAL SharedPreferences plugin, real routing and real rendering (Skia /
/// Impeller) — the r3 blank-swatch bug class only reproduces here, never in
/// widget tests, so painted swatches are asserted at the PIXEL level via
/// RepaintBoundary.toImage().
///
/// THE ONLY FAKE (documented, lowest seam possible): [PhotoPicker]. The real
/// `image_picker` opens the OS photo picker / camera app, which cannot be
/// driven headlessly from `integration_test`. [_SyntheticGalleryPicker]
/// replaces it with deterministic, engine-realistic photos rendered with
/// dart:ui and PNG-encoded — everything downstream (prepare-image decode /
/// re-encode, isolate-based K-means, LAB merge, base election, harmonies,
/// navigation, rendering) is the production code path.
///
/// NOT exercised here (needs a human run on a device, see the #41 issue):
///  - the image_picker plugin itself (system photo picker / camera intent);
///  - the camera-permission E1 route (OS dialog);
///  - the signed-release runtime (this runs a debug build; r3-class shader
///    issues surface in either, but keep one human pass on the signed APK).
///
/// Run (Windows box, toolchain of the 2026-07-11 build saga):
///   $env:JAVA_HOME = (Get-ChildItem C:\dev\jdk17 -Directory | Select -First 1).FullName
///   $env:GRADLE_OPTS = '-Djavax.net.ssl.trustStore=C:\dev\java-truststore\cacerts -Djavax.net.ssl.trustStorePassword=changeit'
///   C:\dev\flutter332\flutter\bin\flutter.bat test integration_test -d <deviceId>

/// Renders [draw] onto a [width]x[height] canvas and returns PNG bytes: a
/// deterministic "photo" that exercises the full decode → analyze pipeline.
Future<Uint8List> _paintPhoto(
  int width,
  int height,
  void Function(ui.Canvas canvas, Size size) draw,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  draw(canvas, Size(width.toDouble(), height.toDouble()));
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  try {
    final ByteData? png =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// "Outfit selfie": light wall + red top (~35%) + navy bottom (~25%). The
/// Dart MVP engine is whole-photo (D1), so the expected palette is exactly
/// {light neutral, red, navy} and the base MUST be chromatic (decision #6),
/// never the wall.
Future<Uint8List> _outfitPhoto() {
  return _paintPhoto(480, 640, (ui.Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, ui.Paint()..color = const Color(0xFFF2F0EC));
    // Top (red, chromatic — must win the base).
    canvas.drawRect(const Rect.fromLTWH(90, 130, 300, 230),
        ui.Paint()..color = const Color(0xFFC22B33));
    // Bottom (navy).
    canvas.drawRect(const Rect.fromLTWH(120, 360, 240, 210),
        ui.Paint()..color = const Color(0xFF2B3A8C));
  });
}

/// "Sneaker product shot": clean white background + red sneaker body + dark
/// sole — the Phase 2S happy case (no person, no attribution problem). The
/// red body is well above POP_ON_NEUTRAL_MIN, so product mode must produce a
/// chromatic base (hero band), not canvas mode.
Future<Uint8List> _sneakerPhoto() {
  return _paintPhoto(480, 360, (ui.Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, ui.Paint()..color = const Color(0xFFF5F4F1));
    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(80, 120, 320, 130), const Radius.circular(48)),
      ui.Paint()..color = const Color(0xFFD6352E),
    );
    // Sole.
    canvas.drawRect(const Rect.fromLTWH(70, 250, 340, 40),
        ui.Paint()..color = const Color(0xFF23211F));
  });
}

/// The ONLY fake of the suite (see the library doc above): stands in for the
/// un-drivable OS photo picker and returns a deterministic synthetic photo.
class _SyntheticGalleryPicker implements PhotoPicker {
  _SyntheticGalleryPicker(this._photo);

  final Future<Uint8List> _photo;

  @override
  Future<Uint8List?> pick(PhotoSource source) => _photo;
}

/// Polls real frames until [finder] matches (live binding: pumpAndSettle can
/// hang on the analyzing screen's continuous progress animation, and the #55
/// minimum display window holds results for 3.5 REAL seconds).
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out after $timeout waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Rasterizes the nearest [RenderRepaintBoundary] ancestor of [finder] —
/// REAL painted pixels out of the production render tree (both result
/// screens keep the F6 RepaintBoundary around their share canvas, and every
/// route body has the ModalRoute boundary as a further fallback).
Future<ui.Image> _rasterizeAround(WidgetTester tester, Finder finder) async {
  RenderObject? node = tester.renderObject(finder);
  while (node != null && node is! RenderRepaintBoundary) {
    node = node.parent;
  }
  expect(node, isNotNull,
      reason: 'No RepaintBoundary ancestor found for $finder');
  return (node! as RenderRepaintBoundary).toImage();
}

/// Raw RGBA bytes of [image] (pixel-level evidence, r3 bug class).
Future<Uint8List> _rgba(ui.Image image) async {
  final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

/// True if any sampled opaque pixel satisfies [test] (r, g, b).
bool _hasPixelWhere(Uint8List rgba, bool Function(int r, int g, int b) test) {
  for (int i = 0; i + 3 < rgba.length; i += 16) {
    if (rgba[i + 3] < 200) continue;
    if (test(rgba[i], rgba[i + 1], rgba[i + 2])) return true;
  }
  return false;
}

/// Number of distinct colors (quantized to 4 bits/channel) among sampled
/// pixels: a blank/unpainted canvas collapses to 1-2 buckets.
int _distinctColorCount(Uint8List rgba) {
  final Set<int> buckets = <int>{};
  for (int i = 0; i + 3 < rgba.length; i += 16) {
    if (rgba[i + 3] < 200) continue;
    buckets.add(
        ((rgba[i] >> 4) << 8) | ((rgba[i + 1] >> 4) << 4) | (rgba[i + 2] >> 4));
  }
  return buckets.length;
}

/// G1 latency budget (PRD): photo confirmed → result on screen < 10 s. This
/// INCLUDES the deliberate #55 minimum display window (3.5 s): the budget is
/// the user-perceived wait, not the raw engine time. Measured with a real
/// Stopwatch on the device clock — the number this suite prints on a real
/// ARM phone is the G1 evidence (#41); an x86_64 emulator run is a smoke
/// bound, not the gate measurement.
const Duration kG1PhotoToResultBudget = Duration(seconds: 10);

/// Taps [analyzeCta] and measures the REAL wall-clock time until
/// [resultMarker] renders, asserting the G1 budget and printing the number.
Future<void> _tapAnalyzeAndAssertBudget(
  WidgetTester tester, {
  required String analyzeCta,
  required String analyzingMarker,
  required String resultMarker,
}) async {
  final Stopwatch watch = Stopwatch()..start();
  await tester.tap(find.text(analyzeCta));
  // The analyzing screen (with its F8 ad slot) must show along the way.
  await _pumpUntilFound(tester, find.text(analyzingMarker));
  await _pumpUntilFound(tester, find.text(resultMarker));
  watch.stop();
  debugPrint('[#41 G1] "$analyzeCta" -> "$resultMarker" in '
      '${watch.elapsedMilliseconds} ms (budget '
      '${kG1PhotoToResultBudget.inMilliseconds} ms, incl. #55 window)');
  expect(watch.elapsed, lessThan(kG1PhotoToResultBudget),
      reason: 'G1 budget blown: photo->result took '
          '${watch.elapsedMilliseconds} ms');
  await tester.pumpAndSettle(); // reveal transition (motion.reveal)
}

bool _isReddish(int r, int g, int b) => r > 130 && r - g > 50 && r - b > 50;
bool _isBluish(int r, int g, int b) => b > 90 && b - r > 40;

/// Complement of the sneaker red ≈ teal/cyan family (green+blue over red).
bool _isTealish(int r, int g, int b) => g - r > 30 && b - r > 10 && g > 100;

/// Pumps a production-composed app: REAL engine (both modes), REAL
/// SharedPreferences onboarding, real analytics/crash seams — only the
/// picker is synthetic.
Future<void> _pumpApp(WidgetTester tester, Future<Uint8List> photo) async {
  await tester
      .pumpWidget(PiketeMakerApp(picker: _SyntheticGalleryPicker(photo)));
  await tester.pumpAndSettle();
}

/// Marks onboarding as seen through the REAL prefs service (exercises the
/// plugin) so non-onboarding journeys start on the split Home.
Future<void> _onboardingSeen() => OnboardingServicePrefs().markSeen();

/// Dismisses a bottom sheet by tapping its barrier (top of the screen).
Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 80));
  await tester.pumpAndSettle();
}

/// Drives Home → zone → gallery → confirm → analyze CTA and waits for the
/// REAL engine + #55 window, until [resultMarker] is on screen.
Future<void> _driveToResult(
  WidgetTester tester, {
  required String zone,
  required String analyzeCta,
  required String resultMarker,
}) async {
  await tester.tap(find.text(zone));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Elegir de la galería'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(analyzeCta));
  await _pumpUntilFound(tester, find.text(resultMarker));
  await tester.pumpAndSettle(); // reveal transition (motion.reveal)
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Cold start: onboarding shows once (real prefs), Saltar lands '
      'on the split Home with both zones painted', (WidgetTester tester) async {
    // Real plugin, deterministic start: wipe the persisted flag.
    await (await SharedPreferences.getInstance()).clear();

    await _pumpApp(tester, _outfitPhoto());

    // First launch → the F13 tutorial opens by itself.
    await _pumpUntilFound(tester, find.text('Saltar'));
    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    // Split Home (D26): both zones present.
    expect(find.text('Mis zapas'), findsOneWidget);
    expect(find.text('Mi pikete'), findsOneWidget);

    // Pixel evidence the Home actually painted (not a blank surface).
    final ui.Image home =
        await _rasterizeAround(tester, find.text('Mis zapas'));
    final Uint8List px = await _rgba(home);
    home.dispose();
    expect(_distinctColorCount(px), greaterThanOrEqualTo(4),
        reason: 'Split Home should paint text + tint washes, not a blank');

    // The flag persisted through the REAL plugin: a second app instance in
    // the same launch state must skip the tutorial.
    expect(await OnboardingServicePrefs().seen(), isTrue);
  });

  testWidgets(
      'Outfit journey: gallery photo → real engine → result with '
      'PAINTED swatches (r3 pixel check) and harmonies',
      (WidgetTester tester) async {
    await _onboardingSeen();
    await _pumpApp(tester, _outfitPhoto());

    await tester.tap(find.text('Mi pikete'));
    await tester.pumpAndSettle();
    expect(find.text('¿De dónde sacamos la foto?'), findsOneWidget);

    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);

    // Analyzing (real engine in a real isolate + real #55 window), timed
    // against the G1 budget (#41: measured with a number, not a feeling).
    await _tapAnalyzeAndAssertBudget(
      tester,
      analyzeCta: 'Analizar',
      analyzingMarker: 'Leyendo los colores de tu fit…',
      resultMarker: 'Tu paleta',
    );

    // Structure: palette card + chromatic base (decision #6) + harmonies
    // (a chromatic outfit must NOT route to canvas mode).
    expect(find.text('BASE'), findsOneWidget);
    expect(find.textContaining('#'), findsWidgets); // hex labels
    expect(find.text('Combina con'), findsOneWidget);
    expect(find.text('Complementario'), findsOneWidget);
    expect(find.text('Tu look es un lienzo'), findsNothing);

    // THE r3 check: rasterize the share canvas and prove the swatch bands
    // carry real pigment — the photo's red top and navy bottom must be on
    // screen, with enough distinct colors to rule out blank bands.
    final ui.Image canvas =
        await _rasterizeAround(tester, find.text('Tu paleta'));
    final Uint8List px = await _rgba(canvas);
    canvas.dispose();
    expect(_distinctColorCount(px), greaterThanOrEqualTo(6),
        reason: 'Blank-swatch regression (r3): too few distinct colors');
    expect(_hasPixelWhere(px, _isReddish), isTrue,
        reason: 'The red top never reached the painted palette');
    expect(_hasPixelWhere(px, _isBluish), isTrue,
        reason: 'The navy bottom never reached the painted palette');
  });

  testWidgets(
      'Sneaker journey: product mode → D27 result with hero band '
      'ABOVE the palette strip, both painted', (WidgetTester tester) async {
    await _onboardingSeen();
    await _pumpApp(tester, _sneakerPhoto());

    await tester.tap(find.text('Mis zapas'));
    await tester.pumpAndSettle();
    expect(find.text('¿De dónde sacamos las zapas?'), findsOneWidget);

    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se ven bien tus zapas?'), findsOneWidget);
    expect(find.text('MIS ZAPAS'), findsOneWidget); // contextual kicker

    // Same G1 budget for the sneaker flow (product-mode engine, D24).
    await _tapAnalyzeAndAssertBudget(
      tester,
      analyzeCta: 'Dame el pikete',
      analyzingMarker: 'Sacando los colores de tus zapas…',
      resultMarker: 'Combina tu ropa con estas zapas',
    );

    // D27 inverted hierarchy: hero band above the demoted palette strip.
    // Red kicks are chromatic → hero band, NOT canvas mode.
    final Finder hero = find.byKey(SneakerResultScreen.heroBandKey);
    final Finder strip = find.byKey(SneakerResultScreen.paletteStripKey);
    expect(hero, findsOneWidget);
    expect(strip, findsOneWidget);
    expect(find.byKey(SneakerResultScreen.canvasAccentsKey), findsNothing);
    expect(tester.getRect(hero).top, lessThan(tester.getRect(strip).top));
    expect(find.textContaining('LA COMBI ·'), findsOneWidget);
    expect(find.text('Otras combis'), findsOneWidget);

    // Pixel evidence on the hero band + strip (share canvas boundary): the
    // sneaker red AND a complementary-family (teal/cyan) suggestion painted.
    final ui.Image canvas = await _rasterizeAround(tester, hero);
    final Uint8List px = await _rgba(canvas);
    canvas.dispose();
    expect(_distinctColorCount(px), greaterThanOrEqualTo(6),
        reason: 'Blank-swatch regression (r3) on the sneaker result');
    expect(_hasPixelWhere(px, _isReddish), isTrue,
        reason: 'The sneaker red never reached the hero band/strip');
    expect(_hasPixelWhere(px, _isTealish), isTrue,
        reason: 'No complementary-family pigment painted in the hero band');
  });

  testWidgets(
      'Back-navigation loops: in and out of both flows, sheets and '
      'results, without crashing and always back to a live Home',
      (WidgetTester tester) async {
    await _onboardingSeen();
    await _pumpApp(tester, _outfitPhoto());

    // Loop 1 · open the outfit sheet and bail out.
    await tester.tap(find.text('Mi pikete'));
    await tester.pumpAndSettle();
    await _dismissSheet(tester);
    expect(find.text('Mis zapas'), findsOneWidget);
    expect(find.text('Mi pikete'), findsOneWidget);

    // Loop 2 · full outfit run, then back out: result → confirm → Home.
    await _driveToResult(
      tester,
      zone: 'Mi pikete',
      analyzeCta: 'Analizar',
      resultMarker: 'Tu paleta',
    );
    await tester.pageBack(); // result → confirm (analyzing was replaced)
    await tester.pumpAndSettle();
    expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
    await tester.pageBack(); // confirm → Home
    await tester.pumpAndSettle();
    expect(find.text('Mis zapas'), findsOneWidget);
    expect(find.text('Mi pikete'), findsOneWidget);

    // Loop 3 · sneaker sheet open/close, then a second outfit entry: the
    // stack survives repeated mode switching.
    await tester.tap(find.text('Mis zapas'));
    await tester.pumpAndSettle();
    expect(find.text('¿De dónde sacamos las zapas?'), findsOneWidget);
    await _dismissSheet(tester);
    await tester.tap(find.text('Mi pikete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se ve bien tu fit?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mis zapas'), findsOneWidget);
    expect(find.text('Mi pikete'), findsOneWidget);
  });

  testWidgets(
      'Sneaker "Otras zapas": result → fresh capture with the sheet '
      'open; dismissing leaves the confirm fallback (#47)',
      (WidgetTester tester) async {
    await _onboardingSeen();
    await _pumpApp(tester, _sneakerPhoto());

    await _driveToResult(
      tester,
      zone: 'Mis zapas',
      analyzeCta: 'Dame el pikete',
      resultMarker: 'Combina tu ropa con estas zapas',
    );

    await tester.ensureVisible(find.text('Otras zapas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otras zapas'));
    await tester.pumpAndSettle();
    expect(find.text('¿De dónde sacamos las zapas?'), findsOneWidget);

    await _dismissSheet(tester);
    expect(find.text('¿Se ven bien tus zapas?'), findsOneWidget);

    // Clean stack underneath (#47: home → confirm): one back = Home.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mis zapas'), findsOneWidget);
    expect(find.text('Mi pikete'), findsOneWidget);
  });
}
