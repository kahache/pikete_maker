import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mode_glyphs.dart';

/// The three capture situations of the sneaker source selector (#83).
enum SneakerTipCase { casa, tienda, web }

/// Thumbnail illustration of a sneaker mini-tutorial (#83, spec §5).
///
/// Faithful [CustomPainter] port of the inline SVGs in the ux-designer mockup
/// `docs/design/mockups/2026-07-11_1400_F2S_sneaker-source-selector.html`
/// (160×120 viewBox). Same rationale as [TipIllustration] / `logo_mark.dart`:
/// flat token-color shapes do not earn flutter_svg its APK weight (gate G1) and
/// re-theme for free at paint time. The sneaker in all three scenes is the
/// app's own glyph ([sneakerGlyphBody]/[sneakerGlyphDetails]) so they read
/// native.
class SneakerTipIllustration extends StatelessWidget {
  const SneakerTipIllustration({super.key, required this.tipCase});

  final SneakerTipCase tipCase;

  /// aria-labels of the source SVGs (localized — screen readers are
  /// user-facing copy too).
  String _semanticsLabel(AppLocalizations l10n) => switch (tipCase) {
        SneakerTipCase.casa => l10n.sneakerIllustrationCasa,
        SneakerTipCase.tienda => l10n.sneakerIllustrationTienda,
        SneakerTipCase.web => l10n.sneakerIllustrationWeb,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: _semanticsLabel(context.l10n),
      child: CustomPaint(
        painter: _SneakerTipPainter(colors: context.colors, tipCase: tipCase),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SneakerTipPainter extends CustomPainter {
  const _SneakerTipPainter({required this.colors, required this.tipCase});

  final AppColors colors;
  final SneakerTipCase tipCase;

  // viewBox of the master SVGs.
  static const double _sceneW = 160;
  static const double _sceneH = 120;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the 160×120 scene inside the canvas (contain); the surfaceSubtle
    // fill extends edge-to-edge so any letterbox is invisible (it IS the card
    // background).
    final double scale = math.min(size.width / _sceneW, size.height / _sceneH);
    final double dx = (size.width - _sceneW * scale) / 2;
    final double dy = (size.height - _sceneH * scale) / 2;

    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surfaceSubtle);

    canvas.translate(dx, dy);
    canvas.scale(scale);

    switch (tipCase) {
      case SneakerTipCase.casa:
        _paintCasa(canvas);
      case SneakerTipCase.tienda:
        _paintTienda(canvas);
      case SneakerTipCase.web:
        _paintWeb(canvas);
    }
  }

  // ------------------------------------------------------------------- casa
  /// Big centered sneaker nearly touching four mint "fill it" corner brackets.
  void _paintCasa(Canvas canvas) {
    _drawSneaker(canvas, tx: 35, ty: 26, s: 1.85, strokeWidth: 2.2);

    final Paint brackets = Paint()
      ..color = colors.action
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(14, 30)
        ..lineTo(14, 16)
        ..lineTo(28, 16)
        ..moveTo(146, 30)
        ..lineTo(146, 16)
        ..lineTo(132, 16)
        ..moveTo(14, 90)
        ..lineTo(14, 104)
        ..lineTo(28, 104)
        ..moveTo(146, 90)
        ..lineTo(146, 104)
        ..lineTo(132, 104),
      brackets,
    );
  }

  // ----------------------------------------------------------------- tienda
  /// Sneaker on a floor band; a phone above with a downward mint chevron.
  void _paintTienda(Canvas canvas) {
    // Floor band.
    canvas.drawRect(
      const Rect.fromLTWH(0, 92, _sceneW, 28),
      Paint()..color = colors.border,
    );

    // Phone shooting down (top), centered at (80,20) in the SVG group.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(69, 9, 22, 34), const Radius.circular(4)),
      Paint()..color = colors.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(69, 9, 22, 34), const Radius.circular(4)),
      Paint()
        ..color = colors.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
        const Offset(80, 16), 3, Paint()..color = colors.textSecondary);

    // Downward mint chevron = shoot from above.
    final Paint chevron = Paint()
      ..color = colors.action
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(80, 50)
        ..lineTo(80, 66)
        ..moveTo(73, 60)
        ..lineTo(80, 67)
        ..lineTo(87, 60),
      chevron,
    );

    // Soft shadow + sneaker on the floor.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(80, 103), width: 68, height: 12),
      Paint()..color = colors.borderStrong,
    );
    _drawSneaker(canvas, tx: 56, ty: 72, s: 1.15, strokeWidth: 2.2);
  }

  // -------------------------------------------------------------------- web
  /// Browser window holding a small sneaker + faux UI/price lines, with a
  /// dashed mint crop rectangle hugging just the sneaker.
  void _paintWeb(Canvas canvas) {
    // Browser window.
    final RRect window = RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 16, 120, 88), const Radius.circular(6));
    canvas.drawRRect(window, Paint()..color = colors.surface);
    final Paint windowStroke = Paint()
      ..color = colors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(window, windowStroke);

    // Top bar + 3 dots.
    canvas.drawLine(const Offset(20, 28), const Offset(140, 28), windowStroke);
    final Paint dot = Paint()..color = colors.borderStrong;
    for (final double cx in <double>[29, 37, 45]) {
      canvas.drawCircle(Offset(cx, 22), 2, dot);
    }

    // Faux web UI / price lines (the clutter to cut away).
    final Paint uiLine = Paint()..color = colors.border;
    for (final (double y, double w) in <(double, double)>[
      (40, 34),
      (52, 26),
      (64, 30),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(94, y, w, 6), const Radius.circular(3)),
        uiLine,
      );
    }

    // Small sneaker inside (no laces, per mockup — only the sole line).
    _drawSneaker(canvas,
        tx: 30, ty: 52, s: 0.9, strokeWidth: 2.4, laces: false);

    // Dashed mint crop rect hugging the sneaker + 4 corner handles.
    final Paint crop = Paint()
      ..color = colors.action
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    _drawDashedRRect(
      canvas,
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(26, 60, 52, 30), const Radius.circular(2)),
      crop,
      dash: 5,
      gap: 4,
    );
    final Paint handle = Paint()..color = colors.action;
    for (final (double x, double y) in <(double, double)>[
      (23, 57),
      (75, 57),
      (23, 87),
      (75, 87),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 6, 6), const Radius.circular(1)),
        handle,
      );
    }
  }

  // --------------------------------------------------------------- helpers
  /// Draws the shared sneaker glyph FILLED ([AppColors.actionTint]) + stroked
  /// ([AppColors.textSecondary]) at a translate+scale, matching the SVG group
  /// transform (the stroke scales with [s], as in SVG).
  void _drawSneaker(
    Canvas canvas, {
    required double tx,
    required double ty,
    required double s,
    required double strokeWidth,
    bool laces = true,
  }) {
    canvas.save();
    canvas.translate(tx, ty);
    canvas.scale(s);

    final Path body = sneakerGlyphBody();
    canvas.drawPath(body, Paint()..color = colors.actionTint);

    final Paint stroke = Paint()
      ..color = colors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(body, stroke);
    canvas.drawPath(sneakerGlyphDetails(laces: laces), stroke);

    canvas.restore();
  }

  /// Dashed rounded-rect stroke (Flutter ships no dash; same PathMetric trick
  /// as the analyzing ad slot's dashed border).
  void _drawDashedRRect(
    Canvas canvas,
    RRect rrect,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final Path outline = Path()..addRRect(rrect);
    for (final ui.PathMetric segment in outline.computeMetrics()) {
      double d = 0;
      while (d < segment.length) {
        canvas.drawPath(
          segment.extractPath(d, math.min(d + dash, segment.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_SneakerTipPainter oldDelegate) =>
      oldDelegate.tipCase != tipCase || oldDelegate.colors != colors;
}
