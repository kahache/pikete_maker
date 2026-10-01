import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';

/// Color bands proportional to weight + hex/% index in mono.
///
/// Parameterized for Phase 2.5 (spec §6 "parameterize" table): the defaults
/// are the whole-photo values. Today's only caller is the legacy whole-photo
/// layout of `OutfitShareCanvas` (the per-garment blocks that passed smaller
/// budgets were retired in r13, A6), so the knobs are kept but unused.
///
/// Internal to the `result` feature.
class PaletteBands extends StatelessWidget {
  const PaletteBands({
    super.key,
    required this.samples,
    required this.baseIndex,
    this.totalHeight = 280,
    this.minHeight = 12,
    this.rowGap = Space.md,
  });

  final List<ColorSample> samples;

  /// Index of the bold-hex (base) row within [samples]; -1 = none.
  final int baseIndex;

  // Relative heights of the mockup: the minimum band remains visible.
  final double totalHeight;
  final double minHeight;
  final double rowGap;

  /// Fixed width of the trailing hex/percent index column.
  static const double _indexColumnWidth = 96;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      children: List<Widget>.generate(samples.length, (int i) {
        final ColorSample sample = samples[i];
        final bool isBase = i == baseIndex;
        final double height =
            (sample.weight * totalHeight).clamp(minHeight, totalHeight);
        final BorderRadius radius = BorderRadius.vertical(
          top: i == 0 ? Radii.rSm : Radius.zero,
          bottom: i == samples.length - 1 ? Radii.rSm : Radius.zero,
        );
        // The band defines the row height (mockup: .plate-row with fixed
        // height and a centered index). CAREFUL: no stretch here — inside
        // the scroll the height is unbounded and would blow up the layout.
        return Padding(
          padding: EdgeInsets.only(bottom: rowGap),
          child: SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: sample.color, borderRadius: radius),
                  ),
                ),
                const SizedBox(width: Space.md),
                SizedBox(
                  width: _indexColumnWidth,
                  child: Row(
                    children: <Widget>[
                      // FittedBox: with the real font it fits and does not
                      // scale; avoids overflow with wide fonts (e.g. the
                      // test font).
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(sample.hex,
                              style: AppType.dataMono.copyWith(
                                color: isBase ? c.textPrimary : c.textSecondary,
                                fontWeight:
                                    isBase ? FontWeight.w700 : FontWeight.w500,
                              )),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Text('${sample.percent}%',
                          style:
                              AppType.dataMono.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
