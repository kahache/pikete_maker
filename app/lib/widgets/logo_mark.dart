import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// "P-Palette" logo mark of PiketeMaker ("isotipo", D14 ·
/// docs/design/logo/LOGO.md).
///
/// Faithfully reproduces the geometry of the master SVG
/// (assets/logo/isotipo.svg) with a [CustomPainter] — offline and with NO
/// dependencies (we avoid flutter_svg: gate G1, APK size). A single
/// turquoise at all sizes (rule frozen in r7).
///
/// [monochrome] variant (LOGO.md rule 3): everything in ink with a hollow
/// eye, for splash over color or single-ink uses.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96, this.monochrome = false});

  /// Side of the square (viewBox 96×96). Works from 15px to 512px (r7).
  final double size;

  /// If true, draws in a single ink with the hollow dot (embroidery/screen
  /// printing).
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LogoMarkPainter(monochrome: monochrome)),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  const _LogoMarkPainter({required this.monochrome});

  final bool monochrome;

  // viewBox of the master SVG.
  static const double _viewBox = 96;
  // The SVG group is translated by (6,0).
  static const double _offsetX = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _viewBox;
    canvas.scale(scale);
    canvas.translate(_offsetX, 0);

    // stem: rectangle 20..38 × 12..75 with a semicircular bottom cap (r9).
    final Path stem = Path()
      ..moveTo(20, 12)
      ..lineTo(38, 12)
      ..lineTo(38, 75)
      ..arcToPoint(const Offset(29, 84), radius: const Radius.circular(9))
      ..arcToPoint(const Offset(20, 75), radius: const Radius.circular(9))
      ..close();

    // bowl: right half-ring (outer r26, inner r10). Flat edge at x=37.6, a
    // 0.4u technical overlap under the stem (anti-hairline, CEO-approved
    // 2026-07-09 — LOGO.md geometry note). The bowl is painted BEFORE the
    // stem so the purple covers the overlap and no mint ever shows on it.
    final Path bowl = Path()
      ..moveTo(37.6, 12)
      ..arcToPoint(const Offset(37.6, 64), radius: const Radius.circular(26))
      ..lineTo(37.6, 48)
      ..arcToPoint(
        const Offset(37.6, 28),
        radius: const Radius.circular(10),
        clockwise: false,
      )
      ..close();

    const Offset eyeCenter = Offset(37.6, 38);
    const double eyeRadius = 10;

    if (monochrome) {
      final Paint ink = Paint()..color = const Color(0xFF1C1826);
      // Body of the P (stem + bowl) in ink, with the eye cut out (hollow).
      final Path body = Path.combine(
        PathOperation.union,
        stem,
        bowl,
      );
      final Path withHollowEye = Path.combine(
        PathOperation.difference,
        body,
        Path()..addOval(Rect.fromCircle(center: eyeCenter, radius: eyeRadius)),
      );
      canvas.drawPath(withHollowEye, ink);
      return;
    }

    // Color version (D14): bowl under stem (anti-hairline order), then dot.
    canvas.drawPath(bowl, Paint()..color = BrandColors.logoTurquoise);
    canvas.drawPath(stem, Paint()..color = BrandColors.purpleInk);
    canvas.drawCircle(
      eyeCenter,
      eyeRadius,
      Paint()..color = const Color(0xFF1C1826),
    );
  }

  @override
  bool shouldRepaint(_LogoMarkPainter oldDelegate) =>
      oldDelegate.monochrome != monochrome;
}

/// "PiketeMaker" wordmark alone, in the frozen logo colors (`Pikete` purple
/// + `Maker` turquoise — LOGO.md). Casing frozen: always "PiketeMaker"
/// (USAGE.md rule 6; never "Pikete" alone, never all-caps).
///
/// Used inside [LogoLockup] and in the stacked brand blocks (option E3 of
/// the r5-visual-decisions sheet, #51).
///
/// Provisional typography: system stack 800 (the licensed display font is
/// fixed in the assets round, issue #31).
class LogoWordmark extends StatelessWidget {
  const LogoWordmark({super.key, this.fontSize = 16});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.01 * fontSize,
        ),
        children: const <TextSpan>[
          TextSpan(
            text: 'Pikete',
            style: TextStyle(color: BrandColors.purpleInk),
          ),
          TextSpan(
            text: 'Maker',
            style: TextStyle(color: BrandColors.logoTurquoise),
          ),
        ],
      ),
    );
  }
}

/// Horizontal lockup: logo mark + "PiketeMaker" wordmark ([LogoWordmark]).
class LogoLockup extends StatelessWidget {
  const LogoLockup({super.key, this.height = 32});

  final double height;

  /// Wordmark font size relative to the symbol side (type weight ≈ font
  /// size), tuned so the text optically matches the mark in the row.
  static const double _wordmarkFontRatio = 0.62;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LogoMark(size: height),
        SizedBox(width: height * 0.22),
        LogoWordmark(fontSize: height * _wordmarkFontRatio),
      ],
    );
  }
}
