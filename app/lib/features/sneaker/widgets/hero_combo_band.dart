import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/dimens.dart';
import 'hero_combo.dart';

/// The three role micro-labels of a hero band, in segment order.
typedef HeroComboTags = ({String base, String complement, String neutral});

/// Per-flow constants of a [HeroComboBand] (A6 / review F18): the sneaker
/// (D27) and outfit (D36) bands are the same widget and differ ONLY in these
/// values. Each flow owns its spec (`sneaker_hero_combo_spec.dart`,
/// `result/widgets/outfit_hero_combo_spec.dart`).
@immutable
class HeroComboBandSpec {
  const HeroComboBandSpec({
    required this.bandKey,
    required this.height,
    required this.baseFlex,
    required this.complementFlex,
    required this.neutralFlex,
    required this.tags,
  });

  /// Test key on the band container (geometry assertions).
  final Key bandKey;

  /// Band height in logical px (on screen; the story overrides it).
  final double height;

  /// Segment flex ratios ×100 (base · complement · neutral).
  final int baseFlex;
  final int complementFlex;
  final int neutralFlex;

  /// Resolves the localized role micro-labels for [combo].
  final HeroComboTags Function(AppLocalizations l10n, HeroCombo combo) tags;

  List<int> get flexes => <int>[baseFlex, complementFlex, neutralFlex];
}

/// The hero combo band — the complementary combo as color segments with role
/// micro-labels, the most colorful thing on screen (the recommendation is the
/// protagonist). Shared by the sneaker (spec §7, D27) and outfit (D36) results
/// AND by the shared photo story (N1 / D37); the per-flow height/flex/labels
/// come from [spec].
///
/// N3 fix (2026-09-29, spec §7.2): tags NEVER wrap. Segment widths start from
/// the flex shares, and any segment narrower than its own tag pill (+ 2 × 8
/// padding) is grown to that minimum, taking the deficit from the others in
/// proportion to their flex, never below their own minimum (the way CSS
/// flexbox resolves `min-width: auto`). Only if the three minimums don't fit
/// the band at all do the pills shrink (FittedBox), as a last resort.
class HeroComboBand extends StatelessWidget {
  const HeroComboBand({
    super.key,
    required this.combo,
    required this.spec,
    this.height,
    this.framed = true,
  });

  final HeroCombo combo;
  final HeroComboBandSpec spec;

  /// Height override (the story band is 72 tall); null → [spec] height.
  final double? height;

  /// On screen the band is its own object (radius md + hairline ring). In the
  /// photo story it is glued under the photo inside ONE card that owns the
  /// radius and the ring, so the band itself is unframed.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final HeroComboTags tags = spec.tags(context.l10n, combo);
    final List<Color> colors = <Color>[
      combo.base,
      combo.complement,
      combo.neutral,
    ];
    final List<String> labels = <String>[
      tags.base.toUpperCase(),
      tags.complement.toUpperCase(),
      tags.neutral.toUpperCase(),
    ];
    return Container(
      key: spec.bandKey,
      height: height ?? spec.height,
      clipBehavior: framed ? Clip.antiAlias : Clip.hardEdge,
      decoration: framed
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border), // hairline ring
            )
          : const BoxDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TextScaler scaler = MediaQuery.textScalerOf(context);
          final TextStyle base = DefaultTextStyle.of(context).style;
          final List<double> mins = <double>[
            for (final String label in labels)
              ComboTagPill.measureWidth(label, base: base, textScaler: scaler) +
                  2 * ComboTagPill.segmentPadding,
          ];
          final List<double> widths = comboSegmentWidths(
            total: constraints.maxWidth,
            flexes: spec.flexes,
            minWidths: mins,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < colors.length; i++)
                SizedBox(
                  width: widths[i],
                  child: ComboSegment(color: colors[i], tag: labels[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Segment widths of a band of [total] px (N3, spec §7.2).
///
/// 1. Start from the [flexes] shares.
/// 2. Any segment below its [minWidths] entry is frozen at its minimum and the
///    remaining width is re-split among the others by flex; repeat until no
///    segment is below its minimum (≤ n passes).
/// 3. Last resort: if the minimums don't fit at all, split [total] in
///    proportion to the minimums (the tag pills then shrink via FittedBox).
///
/// The widths always sum to [total].
List<double> comboSegmentWidths({
  required double total,
  required List<int> flexes,
  required List<double> minWidths,
}) {
  assert(flexes.length == minWidths.length,
      'one minimum width per segment');
  final int n = flexes.length;
  if (n == 0 || !total.isFinite || total <= 0) {
    return List<double>.filled(n, 0);
  }
  final double sumMin = minWidths.fold(0, (double a, double b) => a + b);
  if (sumMin >= total) {
    return <double>[for (final double m in minWidths) total * m / sumMin];
  }
  final List<bool> frozen = List<bool>.filled(n, false);
  List<double> widths = _flexSplit(total, flexes, frozen, minWidths);
  for (int pass = 0; pass < n; pass++) {
    bool changed = false;
    for (int i = 0; i < n; i++) {
      if (!frozen[i] && widths[i] < minWidths[i]) {
        frozen[i] = true;
        changed = true;
      }
    }
    if (!changed) break;
    widths = _flexSplit(total, flexes, frozen, minWidths);
  }
  return widths;
}

/// Frozen segments get their minimum; the rest share what is left by flex.
List<double> _flexSplit(
  double total,
  List<int> flexes,
  List<bool> frozen,
  List<double> minWidths,
) {
  double left = total;
  int flexSum = 0;
  for (int i = 0; i < flexes.length; i++) {
    if (frozen[i]) {
      left -= minWidths[i];
    } else {
      flexSum += flexes[i];
    }
  }
  return <double>[
    for (int i = 0; i < flexes.length; i++)
      frozen[i]
          ? minWidths[i]
          : (flexSum == 0 ? 0 : math.max(0, left) * flexes[i] / flexSum),
  ];
}

/// One segment of a combo band: solid color + a role micro-label pill pinned
/// bottom-left, its ink picked by the segment's luminance (spec §5). A null
/// [tag] paints the color only (story canvas pops).
class ComboSegment extends StatelessWidget {
  const ComboSegment({super.key, required this.color, this.tag});

  final Color color;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(ComboTagPill.segmentPadding),
      child: tag == null
          ? null
          // N3: the pill never wraps; it only scales DOWN (last resort) when
          // the segment is narrower than the pill.
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: ComboTagPill(label: tag!, onColor: color),
            ),
    );
  }
}

/// The role micro-label pill (mockup `.combo .seg .tag`): 10/700, uppercase
/// applied by the caller, 0.06em tracking, 2×7 padding, ONE line.
class ComboTagPill extends StatelessWidget {
  const ComboTagPill({super.key, required this.label, required this.onColor});

  /// The (already uppercased) label.
  final String label;

  /// The segment color underneath: picks the veil and the ink.
  final Color onColor;

  static const double _fontSize = 10;
  static const double _trackingEm = 0.06;
  static const EdgeInsets _padding =
      EdgeInsets.symmetric(horizontal: 7, vertical: 2);

  /// Air between the pill and the segment edges (spec: 2 × Space.sm).
  static const double segmentPadding = Space.sm;

  /// Rounding slack so a measured pill always fits the segment it sized.
  static const double _measureSlack = 1;

  /// Luminance at/above this → light segment → dark ink on a light veil;
  /// below → white ink on a dark veil.
  static const double _lightLuminance = 0.5;
  static const Color _darkVeil = Color(0x38000000); // rgba(0,0,0,0.22)
  static const Color _lightVeil = Color(0x8CFFFFFF); // rgba(255,255,255,0.55)
  static const Color _inkOnLight = Color(0xFF3A3730);

  /// The pill text style (color excluded: it depends on the segment).
  static const TextStyle textStyle = TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: _trackingEm * _fontSize,
  );

  /// Natural width of the pill for [label] (text + horizontal padding),
  /// measured with the same style and [textScaler] it renders with.
  static double measureWidth(
    String label, {
    TextStyle? base,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: (base ?? const TextStyle()).merge(textStyle)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width.ceilToDouble() + _padding.horizontal + _measureSlack;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = onColor.computeLuminance() >= _lightLuminance;
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: isLight ? _lightVeil : _darkVeil,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: textStyle.copyWith(
          color: isLight ? _inkOnLight : Colors.white,
        ),
      ),
    );
  }
}
