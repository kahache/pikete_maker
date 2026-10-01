import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/recolor/widgets/recolor_photo_card.dart';
import 'package:piketemaker/theme/app_theme.dart';

import 'recolor_test_helpers.dart';

/// r18 emulator pass, defect 2: press-and-hold showed the ORIGINAL ~15 %
/// more zoomed and shifted than the recolored photo. Cause: the recolored
/// layer sat in [AnimatedSwitcher]'s default LOOSE stack, so its RawImage
/// sized itself to its own aspect (whole photo visible) while the original,
/// expanded to the box, was cover-cropped. A tall photo (aspect 0.45, below
/// the 5:8 clamp) makes the two fits differ. Both layers must share one
/// paint rect and one fit.

const Key _recolored = ValueKey<String>('recolored');

Future<void> _pump(WidgetTester tester, ui.Image original, ui.Image recolored,
    {required bool held}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: RecolorPhotoCard(
          aspect: 0.45,
          maxHeight: 600,
          original: original,
          recolored: recolored,
          recoloredKey: _recolored,
          held: held,
          loading: false,
          band: const SizedBox.expand(),
          onHoldChanged: (bool _) {},
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
      'a tall photo: the recolored and the original layers share the SAME '
      'paint rect and the same cover fit (no jump on press-and-hold)',
      (WidgetTester tester) async {
    late ui.Image original;
    late ui.Image recolored;
    await tester.runAsync(() async {
      // Same aspect (0.45), different pixel sizes — like the story-decoded
      // original vs the render-box recolor on device.
      original = await solidImage(kOriginalInk, width: 90, height: 200);
      recolored = await solidImage(kUpperInk, width: 45, height: 100);
    });

    await _pump(tester, original, recolored, held: false);
    final Rect box = tester.getRect(find.byKey(RecolorPhotoCard.photoKey));
    final Rect orig = tester.getRect(find.byKey(RecolorPhotoCard.originalKey));
    final Rect reco = tester.getRect(find.byKey(_recolored));
    expect(orig, box, reason: 'the original fills the photo box');
    expect(reco, orig, reason: 'the recolored layer has the SAME rect');
    expect(tester.widget<RawImage>(find.byKey(_recolored)).fit, BoxFit.cover);
    expect(
        tester.widget<RawImage>(find.byKey(RecolorPhotoCard.originalKey)).fit,
        BoxFit.cover);
    // The box is clamped to 5:8, wider than the photo: cover (crop), as in
    // the shared story.
    expect(box.width / box.height, closeTo(5 / 8, 0.01));

    await _pump(tester, original, recolored, held: true);
    expect(find.byKey(_recolored), findsNothing, reason: 'held = original');
    expect(tester.getRect(find.byKey(RecolorPhotoCard.originalKey)), orig,
        reason: 'the original does not move while held');

    original.dispose();
    recolored.dispose();
  });
}
