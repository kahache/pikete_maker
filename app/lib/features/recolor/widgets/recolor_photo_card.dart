import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../story/story_layout.dart';

/// The recolor view's card (I2, UX §2.3): the SAME object the story shares —
/// the photo (scaled, never cropped inside the story's 5:8–16:9 range) with
/// the recommendation [band] flush under it — at screen size.
///
/// The photo layer shows, bottom to top: a `surfaceSubtle` placeholder, the
/// [original] once decoded, and the [recolored] image, cross-faded in
/// ([AppMotion.base], 200 ms) when it is ready and while not [held]. The
/// hold chip ("Mantén para ver el original" / "Original") is SCREEN-ONLY:
/// it lives here, never in the story frame. While the recolor renders, a
/// 2 px progress line runs along the photo's bottom edge (the subtle
/// progress state; no spinner).
class RecolorPhotoCard extends StatelessWidget {
  /// Creates the card for a photo of [aspect] (w/h).
  const RecolorPhotoCard({
    super.key,
    required this.aspect,
    required this.maxHeight,
    required this.original,
    required this.recolored,
    required this.recoloredKey,
    required this.held,
    required this.loading,
    required this.band,
    required this.onHoldChanged,
  });

  /// Photo aspect (width / height), from the analysed frame.
  final double aspect;

  /// Height available for the whole card (photo + band).
  final double maxHeight;

  /// The original photo, null until decoded.
  final ui.Image? original;

  /// The recolored photo of the active region, null until rendered.
  final ui.Image? recolored;

  /// Identity of [recolored] (the region), so a region switch cross-fades.
  final Key recoloredKey;

  /// True while the finger is down (the original is shown).
  final bool held;

  /// True while the recolor renders.
  final bool loading;

  /// The recommendation band under the photo.
  final Widget band;

  /// Press-and-hold anywhere on the photo: true on down, false on up/cancel.
  final ValueChanged<bool> onHoldChanged;

  /// Photo box maximum (mockup: 279 × 372 for a 3:4 photo).
  static const double photoMaxWidth = 279;
  static const double photoMaxHeight = 372;

  /// Band height on screen (the story's is 72).
  static const double bandHeight = 64;

  /// Hold chip geometry (mockup `.hold`).
  static const double _chipHeight = 24;
  static const double _chipInset = 10;
  static const double _chipPadH = 9;

  /// Opacity of the chip's ink background (mockup `rgba(28,24,38,.55)` =
  /// textPrimary at 55 %).
  static const double _chipInkOpacity = 0.55;

  /// Progress line thickness.
  static const double _progressHeight = 2;

  /// Test keys.
  static const Key photoKey = Key('recolor_photo');
  static const Key chipKey = Key('recolor_hold_chip');
  static const Key progressKey = Key('recolor_progress');
  static const Key originalKey = Key('recolor_original_layer');

  /// Photo box for [aspect] inside the max box, scaled down to leave room for
  /// the band within [maxHeight].
  static Size photoSize(double aspect, double maxHeight) {
    final double a = StoryGeometry.clampAspect(aspect);
    Size box = a >= photoMaxWidth / photoMaxHeight
        ? Size(photoMaxWidth, photoMaxWidth / a)
        : Size(photoMaxHeight * a, photoMaxHeight);
    final double room = math.max(0, maxHeight - bandHeight);
    if (box.height > room && box.height > 0) {
      final double s = room / box.height;
      box = Size(box.width * s, box.height * s);
    }
    return box;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final Size photo = photoSize(aspect, maxHeight);
    final bool showRecolor = recolored != null && !held;
    return Semantics(
      label: l10n.recolorPreviewLabel,
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: <BoxShadow>[AppShadows.ring(c.border), ...AppShadows.sm],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Listener(
                key: photoKey,
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => onHoldChanged(true),
                onPointerUp: (_) => onHoldChanged(false),
                onPointerCancel: (_) => onHoldChanged(false),
                child: SizedBox.fromSize(
                  size: photo,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(color: c.surfaceSubtle),
                      if (original != null)
                        RawImage(
                          key: originalKey,
                          image: original,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      AnimatedSwitcher(
                        duration: AppMotion.base,
                        switchInCurve: AppMotion.standard,
                        switchOutCurve: AppMotion.standard,
                        // EXPAND every child to the photo box, exactly like
                        // the original layer under it. The default layout is
                        // a loose Stack: the recolored RawImage then sized
                        // itself to its own aspect (contain) while the
                        // original was cover-cropped, so press-and-hold
                        // jumped (emulator pass r18: ~15 % zoom + shift).
                        layoutBuilder: _expandedSwitcherLayout,
                        child: showRecolor
                            ? RawImage(
                                key: recoloredKey,
                                image: recolored,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              )
                            : const SizedBox.expand(
                                key: ValueKey<String>('no_recolor')),
                      ),
                      if (recolored != null)
                        Positioned(
                          right: _chipInset,
                          bottom: _chipInset,
                          child: _chip(
                              c,
                              held
                                  ? l10n.recolorHoldActive
                                  : l10n.recolorHoldHint),
                        ),
                      if (loading)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            key: progressKey,
                            minHeight: _progressHeight,
                            color: c.actionBright,
                            backgroundColor: c.actionTint,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: photo.width, height: bandHeight, child: band),
            ],
          ),
        ),
      ),
    );
  }

  /// [AnimatedSwitcher.layoutBuilder] that keeps the outgoing and incoming
  /// layers at the full photo box (StackFit.expand), so the recolored and the
  /// original photo share one paint rect and one fit.
  static Widget _expandedSwitcherLayout(
          Widget? current, List<Widget> previous) =>
      Stack(
        fit: StackFit.expand,
        children: <Widget>[...previous, if (current != null) current],
      );

  Widget _chip(AppColors c, String text) => Container(
        key: chipKey,
        height: _chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: _chipPadH),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.textPrimary.withValues(alpha: _chipInkOpacity),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          text.toUpperCase(),
          style: AppType.label.copyWith(color: c.actionOnFill),
        ),
      );
}
