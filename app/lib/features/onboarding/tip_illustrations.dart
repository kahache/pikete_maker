import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

/// BIEN/MAL tip illustrations of the ONB-2 pro-tip cards (#52 · audit F-2).
///
/// Faithful [CustomPainter] port of the ux-designer assets
/// `docs/design/logo/assets/illus-tip-bien.svg` (plain wall) and
/// `illus-tip-mal.svg` (cluttered room). Same rationale as
/// `widgets/logo_mark.dart`: flat token-color shapes do not earn flutter_svg
/// its APK weight (gate G1) nor raster assets their @2x/@3x bytes — and by
/// reading [AppColors] at paint time the scene re-themes for free the day
/// dark mode lands (a PNG would not).
///
/// The two scenes share wall, floor, shadow and the SAME neutral figure (the
/// point of the tip is the background, not the person); [cluttered] adds the
/// crooked frame, shelf, poster and clothes on the floor of the MAL version.
class TipIllustration extends StatelessWidget {
  const TipIllustration({super.key, required this.cluttered});

  /// false → BIEN (plain wall) · true → MAL (cluttered room).
  final bool cluttered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      // aria-labels of the source SVGs (localized — screen readers are
      // user-facing copy too).
      label: cluttered
          ? context.l10n.onbIllustrationBad
          : context.l10n.onbIllustrationGood,
      child: CustomPaint(
        painter: _TipScenePainter(
          colors: context.colors,
          cluttered: cluttered,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TipScenePainter extends CustomPainter {
  const _TipScenePainter({required this.colors, required this.cluttered});

  final AppColors colors;
  final bool cluttered;

  // viewBox of the master SVGs.
  static const double _sceneW = 160;
  static const double _sceneH = 120;

  /// Mid clutter shade of illus-tip-mal.svg (#C9C2DB). Illustration-only
  /// value between borderStrong and textDisabled; it is NOT a tokens.json
  /// token, so it lives here as the asset's own constant.
  static const Color _clutterMid = Color(0xFFC9C2DB);

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the 160×120 scene inside the canvas; wall and floor extend
    // edge-to-edge so any letterbox is invisible (the wall IS surfaceSubtle,
    // the card background).
    final double scale = math.min(size.width / _sceneW, size.height / _sceneH);
    final double dx = (size.width - _sceneW * scale) / 2;
    final double dy = (size.height - _sceneH * scale) / 2;

    // Wall (surfaceSubtle) + floor (border), full-bleed.
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surfaceSubtle);
    canvas.drawRect(
      Rect.fromLTRB(0, dy + 102 * scale, size.width, size.height),
      Paint()..color = colors.border,
    );

    canvas.translate(dx, dy);
    canvas.scale(scale);

    if (cluttered) _paintClutter(canvas);

    // Soft shadow + neutral full-body figure (textSecondary; no skin tone —
    // onboarding §2.3). Identical in BOTH scenes.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(80, 104), width: 36, height: 7),
      Paint()..color = colors.borderStrong,
    );
    final Paint figure = Paint()..color = colors.textSecondary;
    canvas.drawCircle(const Offset(80, 30), 8.5, figure);
    canvas.drawRRect(_rrect(68.5, 42, 23, 34, 10), figure); // torso
    canvas.drawRRect(_rrect(72, 72, 6.6, 32, 3.3), figure); // left leg
    canvas.drawRRect(_rrect(81.4, 72, 6.6, 32, 3.3), figure); // right leg
  }

  /// The mess of illus-tip-mal.svg, behind the figure.
  void _paintClutter(Canvas canvas) {
    final Paint surface = Paint()..color = colors.surface;
    final Paint frameStroke = Paint()
      ..color = colors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final Paint mid = Paint()..color = _clutterMid;
    final Paint strong = Paint()..color = colors.borderStrong;
    final Paint purpleTint = Paint()..color = colors.accentTint;
    final Paint mintTint = Paint()..color = colors.actionTint;

    // Crooked picture frame: rotate(-8°) around (30, 28).
    canvas.save();
    canvas.translate(30, 28);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-30, -28);
    canvas.drawRRect(_rrect(16, 16, 28, 22, 2), surface);
    canvas.drawRRect(_rrect(16, 16, 28, 22, 2), frameStroke);
    canvas.drawRRect(_rrect(21, 22, 18, 10, 1.5), purpleTint);
    canvas.restore();

    // Shelf with books/knick-knacks.
    canvas.drawRRect(_rrect(106, 38, 44, 4, 2), strong);
    canvas.drawRRect(_rrect(110, 22, 7, 16, 1.5), mid);
    canvas.drawRRect(_rrect(119, 18, 7, 20, 1.5), purpleTint);
    canvas.drawRRect(_rrect(128, 25, 7, 13, 1.5), mintTint);
    canvas.drawRRect(_rrect(137, 20, 9, 18, 4.5), strong);

    // Small poster with two text lines.
    canvas.drawRRect(_rrect(120, 56, 22, 16, 2), surface);
    canvas.drawRRect(_rrect(120, 56, 22, 16, 2), frameStroke);
    final Paint posterLine = Paint()
      ..color = _clutterMid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(124, 61), const Offset(138, 61), posterLine);
    canvas.drawLine(const Offset(124, 66), const Offset(134, 66), posterLine);

    // Clothes scattered on the floor.
    canvas.drawOval(_ellipse(26, 102, 16, 6), mid);
    canvas.drawOval(_ellipse(38, 99, 10, 5), purpleTint);
    canvas.drawOval(_ellipse(136, 103, 13, 5.5), mintTint);
    canvas.drawOval(_ellipse(126, 100, 8, 4), strong);
  }

  static RRect _rrect(double x, double y, double w, double h, double radius) =>
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), Radius.circular(radius));

  static Rect _ellipse(double cx, double cy, double rx, double ry) =>
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

  @override
  bool shouldRepaint(_TipScenePainter oldDelegate) =>
      oldDelegate.cluttered != cluttered || oldDelegate.colors != colors;
}
