import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/onboarding/onboarding_screen.dart';
import 'package:piketemaker/features/onboarding/tip_illustrations.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// #52 (CEO bug r5, audit F-2): the BIEN and MAL tutorial cards rendered the
/// SAME glyph. These tests pin the fix at both levels: the wiring (each card
/// gets its own scene) and the actual PAINT (the two scenes rasterize to
/// different pixels — the r3 lesson: test what paints, not just the model).

/// Rasterizes one scene at the SVG's native 160×120 and returns raw RGBA.
Future<Uint8List> _rasterize(WidgetTester tester, bool cluttered) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 160,
            height: 120,
            child: TipIllustration(cluttered: cluttered),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  // toImage/toByteData are REAL async (GPU/raster thread): runAsync.
  final ByteData data = (await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  }))!;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  testWidgets('ONB-2 wires the plain-wall scene to BIEN and the clutter to MAL',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingScreen(onboarding: OnboardingServiceInMemory()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    // The pro-tip page shows BOTH scenes, in BIEN → MAL order (tree order
    // follows the Row: BIEN card first).
    final List<TipIllustration> scenes = tester
        .widgetList<TipIllustration>(find.byType(TipIllustration))
        .toList();
    expect(scenes, hasLength(2));
    expect(scenes.first.cluttered, isFalse,
        reason: 'the BIEN card must show the plain wall');
    expect(scenes.last.cluttered, isTrue,
        reason: 'the MAL card must show the cluttered room');
    expect(find.text('BIEN'), findsOneWidget);
    expect(find.text('MAL'), findsOneWidget);
  });

  testWidgets('BIEN and MAL PAINT differently (the exact r5 bug)',
      (WidgetTester tester) async {
    final Uint8List bien = await _rasterize(tester, false);
    final Uint8List mal = await _rasterize(tester, true);

    expect(bien.length, mal.length);
    int differing = 0;
    for (int i = 0; i < bien.length; i++) {
      if (bien[i] != mal[i]) differing++;
    }
    // The clutter (frame, shelf, poster, clothes) must change a substantial
    // share of the pixels — not an anti-aliasing rounding artifact.
    expect(differing, greaterThan(bien.length ~/ 20),
        reason: 'MAL renders (near) identical to BIEN: '
            '$differing/${bien.length} differing bytes');
  });
}
