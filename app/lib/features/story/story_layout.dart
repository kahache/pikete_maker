import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

/// Geometry of the shared 9:16 story (N1 / D37), in LOGICAL px of the
/// 432 × 768 story frame (× [StoryGeometry.pixelRatio] = 1080 × 1920).
///
/// Pure functions only (no widgets), so every number in the design spec
/// (`docs/design/2026-09-29_1830_F2_share-photo-story-proposal.md` §2.1) is
/// unit-testable without rendering.
abstract final class StoryGeometry {
  /// 9:16 in logical px; × [pixelRatio] = 1080×1920, the native story size.
  /// 432 logical wide ≈ a real phone width (M33 ≈ 411 dp), so on-screen
  /// widgets lay out like they do on a phone. Both values are exact in binary
  /// floating point (432 × 2.5 = 1080, 768 × 2.5 = 1920): no off-by-one pixel.
  static const Size logicalSize = Size(432, 768);
  static const double pixelRatio = 2.5;

  /// Story-unsafe strips (top 0–80, bottom 688–768; ~10.4% each):
  /// Instagram/TikTok overlay their progress bar, avatar and reply bar there.
  /// No text, band or logo is placed inside them.
  static const double safeInsetV = 80;

  /// Top of the headline when the group is as tall as it gets (spec: 92).
  static const double groupTopMin = 92;

  /// Content width: frame minus the 20 px screen margins (392).
  static const double contentWidth = 392;

  /// Photo box max height with a 1-line / 2-line headline.
  static const double photoMaxHeightOneLine = 415;
  static const double photoMaxHeightTwoLines = 377;

  /// The photo's aspect (w/h) is clamped to [5:8, 16:9]. Inside that range
  /// the photo is scaled, never cropped; outside it the excess is cut evenly
  /// from both ends (a centred cover).
  static const double minAspect = 5 / 8;
  static const double maxAspect = 16 / 9;

  /// Headline line height (display 32/38) and the gap under it.
  static const double headlineLineHeight = 38;
  static const double headlineGap = 16;

  /// The recommendation band glued under the photo.
  static const double bandHeight = 72;

  /// Logo: full-colour lockup 28 tall, 20 below the card (USAGE §6, N4).
  static const double logoGap = 20;
  static const double logoHeight = 28;

  /// Bottom of the story-safe band (768 − 80 = 688).
  static double get safeBottom => logicalSize.height - safeInsetV;

  /// Photo box for an oriented photo of [aspect] (w/h) with a headline of
  /// [headlineLines] lines (1 or 2). Spec rule: clamp the aspect; if it is at
  /// least as wide as the max box, the width is 392; otherwise the height is
  /// the max height and the width follows the aspect.
  static Size photoBox(double aspect, {int headlineLines = 1}) {
    final double maxH = headlineLines >= 2
        ? photoMaxHeightTwoLines
        : photoMaxHeightOneLine;
    final double a = clampAspect(aspect);
    if (a >= contentWidth / maxH) {
      return Size(contentWidth, contentWidth / a);
    }
    return Size(maxH * a, maxH);
  }

  /// [aspect] clamped to [[minAspect], [maxAspect]] (a non-finite or
  /// non-positive aspect falls back to 3:4, the phone camera default).
  static double clampAspect(double aspect) {
    if (!aspect.isFinite || aspect <= 0) return 3 / 4;
    return aspect.clamp(minAspect, maxAspect);
  }
}

/// Resolved positions of the photo story's four blocks (headline, photo,
/// band, logo) inside the 432 × 768 frame.
@immutable
class PhotoStoryLayout {
  const PhotoStoryLayout({
    required this.headlineTop,
    required this.headlineHeight,
    required this.photo,
    required this.band,
    required this.logoTop,
  });

  /// Lays the group out for a photo of [photoAspect] (w/h, of the ORIENTED
  /// image) and a headline of [headlineLines] lines.
  ///
  /// The group (headline + card + logo) is vertically centred in the safe
  /// band 80–688, but never starts above [StoryGeometry.groupTopMin] (92):
  /// at the max photo height the group spans exactly 92 → 681.
  factory PhotoStoryLayout.compute({
    required double photoAspect,
    int headlineLines = 1,
  }) {
    final int lines = headlineLines >= 2 ? 2 : 1;
    final Size box = StoryGeometry.photoBox(photoAspect, headlineLines: lines);
    final double headlineHeight = lines * StoryGeometry.headlineLineHeight;
    final double groupHeight = headlineHeight +
        StoryGeometry.headlineGap +
        box.height +
        StoryGeometry.bandHeight +
        StoryGeometry.logoGap +
        StoryGeometry.logoHeight;
    const double safeTop = StoryGeometry.safeInsetV;
    final double safeHeight = StoryGeometry.safeBottom - safeTop;
    final double top = math.max(
      StoryGeometry.groupTopMin,
      safeTop + (safeHeight - groupHeight) / 2,
    );
    final double cardTop = top + headlineHeight + StoryGeometry.headlineGap;
    final double left = (StoryGeometry.logicalSize.width - box.width) / 2;
    final Rect photo = Rect.fromLTWH(left, cardTop, box.width, box.height);
    final Rect band = Rect.fromLTWH(
        left, photo.bottom, box.width, StoryGeometry.bandHeight);
    return PhotoStoryLayout(
      headlineTop: top,
      headlineHeight: headlineHeight,
      photo: photo,
      band: band,
      logoTop: band.bottom + StoryGeometry.logoGap,
    );
  }

  final double headlineTop;
  final double headlineHeight;

  /// The photo, top part of the card.
  final Rect photo;

  /// The recommendation band, flush under the photo (same width).
  final Rect band;

  /// Top of the 28 px lockup.
  final double logoTop;

  /// The whole card (photo + band): one object.
  Rect get card => Rect.fromLTRB(photo.left, photo.top, photo.right, band.bottom);

  /// Bottom of the lockup: must stay above [StoryGeometry.safeBottom].
  double get logoBottom => logoTop + StoryGeometry.logoHeight;
}
