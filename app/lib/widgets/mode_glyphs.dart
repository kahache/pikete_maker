import 'package:flutter/material.dart';

/// Closed sneaker BODY outline in the 48-unit glyph space, shared by the
/// split-Home glyph and the F2S source-tip illustrations (#83). The split-Home
/// glyph only strokes it; the tip illustrations FILL it (`actionTint`) and
/// stroke it, so the two consumers stay pixel-identical to the ux-designer's
/// SVG (`mode_glyphs` path, reused per the #83 spec §5).
Path sneakerGlyphBody() {
  const Radius corner = Radius.circular(2);
  return Path()
    ..moveTo(4, 30)
    ..lineTo(4, 23)
    ..arcToPoint(const Offset(6, 21), radius: corner)
    ..lineTo(13, 21)
    ..lineTo(19, 26)
    ..lineTo(30, 28)
    ..relativeCubicTo(7, 1, 12, 3, 12, 6)
    ..lineTo(42, 35)
    ..arcToPoint(const Offset(40, 37), radius: corner)
    ..lineTo(6, 37)
    ..arcToPoint(const Offset(4, 35), radius: corner)
    ..close();
}

/// Laces + sole detail strokes of the sneaker glyph. [laces] off → only the
/// sole line (the web thumbnail's smaller sneaker drops the laces, per mockup).
Path sneakerGlyphDetails({bool laces = true}) {
  final Path p = Path();
  if (laces) {
    p
      ..moveTo(13, 21)
      ..lineTo(16, 27)
      ..moveTo(19, 26)
      ..lineTo(22, 31);
  }
  return p
    ..moveTo(4, 33)
    ..lineTo(42, 33);
}

/// Line glyphs of the two Home modes (split Home, F2S · D26).
///
/// Faithful [CustomPainter] port of the inline SVGs in the ux-designer mockup
/// `docs/design/mockups/2026-07-10_2130_F2S_split-home.html` (48×48 viewBox,
/// 2.2 stroke, round caps/joins). Same rationale as `logo_mark.dart`: two
/// stroked paths do not earn flutter_svg its APK weight (gate G1), and taking
/// the color as a parameter re-tints them for free (each Home zone paints its
/// glyph in its own ink; the sneaker placeholder reuses the glyph in a
/// neutral).
class ModeGlyph extends StatelessWidget {
  const ModeGlyph.sneaker({super.key, required this.color, required this.size})
      : _sneaker = true;

  const ModeGlyph.tshirt({super.key, required this.color, required this.size})
      : _sneaker = false;

  final Color color;

  /// Side of the square (the source viewBox is 48×48).
  final double size;

  final bool _sneaker;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ModeGlyphPainter(color: color, sneaker: _sneaker),
      ),
    );
  }
}

class _ModeGlyphPainter extends CustomPainter {
  const _ModeGlyphPainter({required this.color, required this.sneaker});

  final Color color;
  final bool sneaker;

  // viewBox and stroke of the master SVGs (mockup).
  static const double _viewBox = 48;
  static const double _strokeWidth = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _viewBox);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(sneaker ? _sneakerPath() : _tshirtPath(), stroke);
  }

  /// Sneaker outline + laces + sole line (mockup zone 1 glyph). Composed from
  /// the shared body + detail paths so the split-Home glyph and the #83 tip
  /// illustrations render the exact same sneaker.
  static Path _sneakerPath() =>
      sneakerGlyphBody()..addPath(sneakerGlyphDetails(), Offset.zero);

  /// T-shirt outline (mockup zone 2 glyph).
  static Path _tshirtPath() {
    // M18 7 l-4 2 l-8 5 l4 7 l4 -3 v22 h20 v-22 l4 3 l4 -7 l-8 -5 l-4 -2
    // c0 4 -12 4 -12 0 Z
    return Path()
      ..moveTo(18, 7)
      ..lineTo(14, 9)
      ..lineTo(6, 14)
      ..lineTo(10, 21)
      ..lineTo(14, 18)
      ..lineTo(14, 40)
      ..lineTo(34, 40)
      ..lineTo(34, 18)
      ..lineTo(38, 21)
      ..lineTo(42, 14)
      ..lineTo(34, 9)
      ..lineTo(30, 7)
      ..relativeCubicTo(0, 4, -12, 4, -12, 0)
      ..close();
  }

  @override
  bool shouldRepaint(_ModeGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.sneaker != sneaker;
}
