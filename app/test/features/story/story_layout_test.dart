import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/features/story/story_layout.dart';
import 'package:piketemaker/features/story/story_photo.dart';

/// N1 / D37 — the photo story geometry (spec §2.1), pure numbers.
void main() {
  group('photo size rule (392 × 415 box, aspect clamped to [5:8, 16:9])', () {
    void box(double aspect, Size expected, {int lines = 1}) {
      final Size s = StoryGeometry.photoBox(aspect, headlineLines: lines);
      expect(s.width, closeTo(expected.width, 0.5), reason: 'width @ $aspect');
      expect(s.height, closeTo(expected.height, 0.5),
          reason: 'height @ $aspect');
    }

    test('3:4 phone camera → 311 × 415, uncropped', () {
      box(3 / 4, const Size(311, 415));
    });
    test('4:5 IG download → 332 × 415', () => box(4 / 5, const Size(332, 415)));
    test('1:1 → 392 × 392', () => box(1, const Size(392, 392)));
    test('4:3 landscape → 392 × 294', () => box(4 / 3, const Size(392, 294)));
    test('9:16 full-screen capture → clamped to 5:8 = 259 × 415', () {
      box(9 / 16, const Size(259, 415));
    });
    test('9:20 screenshot → clamped to 5:8 too', () {
      box(9 / 20, const Size(259, 415));
    });
    test('21:9 ultra-wide → clamped to 16:9 = 392 × 220.5', () {
      box(21 / 9, const Size(392, 220.5));
    });
    test('2-line headline: the max height drops to 377 (3:4 → 283 × 377)', () {
      box(3 / 4, const Size(283, 377), lines: 2);
      box(5 / 8, const Size(236, 377), lines: 2);
      box(4 / 3, const Size(392, 294), lines: 2);
    });
    test('a broken aspect falls back to 3:4', () {
      box(double.nan, const Size(311, 415));
      box(0, const Size(311, 415));
    });
  });

  group('group placement', () {
    test('at max height the group spans 92 → 681 (spec worked example)', () {
      final PhotoStoryLayout l = PhotoStoryLayout.compute(photoAspect: 3 / 4);
      expect(l.headlineTop, 92);
      expect(l.photo.top, 146);
      expect(l.photo.left, closeTo(60.5, 0.5));
      expect(l.logoTop, closeTo(653, 0.01));
      expect(l.logoBottom, closeTo(681, 0.01));
    });

    test('4:3 landscape is vertically centred: headline 150, card 204, logo '
        '590', () {
      final PhotoStoryLayout l = PhotoStoryLayout.compute(photoAspect: 4 / 3);
      expect(l.headlineTop, closeTo(150, 0.01));
      expect(l.photo.top, closeTo(204, 0.01));
      expect(l.logoTop, closeTo(590, 0.01));
      expect(l.photo.left, 20);
    });

    test('2-line headline: the card sits at 184', () {
      final PhotoStoryLayout l =
          PhotoStoryLayout.compute(photoAspect: 3 / 4, headlineLines: 2);
      expect(l.headlineTop, 92);
      expect(l.headlineHeight, 76);
      expect(l.photo.top, 184);
      expect(l.logoBottom, lessThanOrEqualTo(StoryGeometry.safeBottom));
    });

    for (final double aspect in <double>[
      9 / 20, 9 / 16, 5 / 8, 3 / 4, 4 / 5, 1, 4 / 3, 16 / 9, 21 / 9,
    ]) {
      for (final int lines in <int>[1, 2]) {
        test('aspect ${aspect.toStringAsFixed(3)} · $lines line(s): nothing '
            'in the unsafe strips, card width == band width, centred', () {
          final PhotoStoryLayout l = PhotoStoryLayout.compute(
              photoAspect: aspect, headlineLines: lines);
          expect(l.headlineTop, greaterThanOrEqualTo(StoryGeometry.safeInsetV));
          expect(l.logoBottom, lessThanOrEqualTo(StoryGeometry.safeBottom));
          expect(l.band.width, l.photo.width);
          expect(l.band.top, l.photo.bottom, reason: 'band glued under photo');
          expect(l.band.height, 72);
          expect(l.logoTop - l.band.bottom, 20);
          expect(l.card.center.dx, closeTo(216, 0.001), reason: 'centred');
          expect(l.photo.width, lessThanOrEqualTo(392));
          expect(l.photo.width, greaterThanOrEqualTo(lines == 1 ? 259 : 235));
        });
      }
    }
  });

  group('sized decode (r13 coverDecodeSize reused)', () {
    test('a 1200 × 1600 photo decodes to the 3:4 box at export size', () {
      // 311.25 × 415 logical × 2.5 = 778.1 × 1037.5 → cover width 779.
      expect(storyPhotoDecodeSize(1200, 1600).width, 779);
    });
    test('a small photo is never upscaled', () {
      expect(storyPhotoDecodeSize(300, 400).width, isNull);
    });
    test('a 9:16 photo covers its clamped 5:8 box', () {
      // Box 259.4 × 415 → 649 × 1038 px; cover scale = max(649/900, 1038/1600).
      final int? w = storyPhotoDecodeSize(900, 1600).width;
      expect(w, isNotNull);
      expect(w! / 900 * 1600, greaterThanOrEqualTo(1037));
    });
  });
}
