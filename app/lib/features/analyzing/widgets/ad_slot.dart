import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';

/// Rewarded ad slot (F8): subtle surface, lg radius, DASHED border (canonical
/// mockup), container max 4:5. Two variants, same layout (the user-flows §3
/// rule: "the layout does not jump"):
///  - [withAd] = true  → marked ad placeholder (AdMob arrives in Phase 5).
///  - [withAd] = false → retry/no inventory: capture tip.
///
/// Internal to the `analyzing` feature.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key, required this.withAd});

  final bool withAd;

  /// Container max 4:5 over 390 − margins (tokens.json → adSlot).
  static const double _maxHeight = 438;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: c.borderStrong),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: c.borderStrong),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                // The ad marker is a DEV placeholder (AdMob replaces it in
                // Phase 5) — deliberately not localized; the TIP badge and
                // both captions are user copy and are.
                withAd
                    ? 'HUECO REWARDED · F8 · ADMOB'
                    : context.l10n.adSlotTipBadge,
                style: AppType.label.copyWith(color: c.textTertiary),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              withAd
                  ? context.l10n.adSlotAdCaption
                  : context.l10n.adSlotTipCaption,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed border of the ad slot (the mockup's `border: dashed`; Flutter does
/// not ship it and it does not deserve a package).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radii.rLg).deflate(0.5),
      );
    for (final ui.PathMetric segment in outline.computeMetrics()) {
      double d = 0;
      while (d < segment.length) {
        canvas.drawPath(
          segment.extractPath(d, math.min(d + _dash, segment.length)),
          stroke,
        );
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
