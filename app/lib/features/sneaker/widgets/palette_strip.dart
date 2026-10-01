import 'package:flutter/material.dart';

import '../../../core/color_engine/display.dart';
import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../color_names.dart';
import 'sneaker_result_keys.dart';

/// SECONDARY (D27): the demoted raw sneaker palette — compact 108×30 strip
/// with the base marked by the white dot + purple ring, next to the BASE
/// badge (purple dose 1 of 2) and its one-line description.
///
/// Internal to the `sneaker` feature.
class PaletteStrip extends StatelessWidget {
  const PaletteStrip({super.key, required this.result});

  final AnalysisResult result;

  static const double _stripWidth = 108;
  static const double _stripHeight = 30;

  /// Up to 5 swatches (spec §5) — the engine may emit more clusters.
  static const int _maxSwatches = 5;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    // Canvas mode has no chromatic base (baseIndex -1); the badge then names
    // the dominant NEUTRAL (palette is weight-sorted, so index 0) — spec:
    // "base will be a neutral; badge shows Base · {neutro}".
    final int baseIndex = result.baseIndex >= 0 ? result.baseIndex : 0;
    // Display snap (#85, D31-A): the strip shows the SNAPPED colors (a diluted
    // #3C3937 black renders as pure black, a #D0CCC9 white as pure white) and
    // the namer reads the snapped color too, so the badge says "negro" (or
    // the active locale's word) for a shoe shown black. The analysis palette
    // itself stays raw.
    final List<Color> swatches = <Color>[
      for (final ColorSample s in result.palette.take(_maxSwatches))
        snapColorForDisplay(s.color),
    ];
    final String baseName = localizedColorName(
        snapColorForDisplay(result.palette[baseIndex].color), l10n.localeName);

    return Container(
      key: SneakerResultKeys.paletteStrip,
      padding: const EdgeInsets.only(top: Space.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: _stripWidth,
            height: _stripHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < swatches.length; i++)
                  Expanded(
                    child: _PaletteSwatch(
                      color: swatches[i],
                      isBase: i == baseIndex,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accentTint,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Text(
                    l10n.sneakerBaseBadge(baseName).toUpperCase(),
                    style: AppType.label.copyWith(color: c.accent),
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text.rich(
                  TextSpan(
                    style: AppType.caption.copyWith(color: c.textSecondary),
                    children: <TextSpan>[
                      TextSpan(text: l10n.sneakerBaseDescPre),
                      TextSpan(
                        text: l10n.sneakerBaseDescBold,
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: l10n.sneakerBaseDescRest(baseName)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact palette swatch; the BASE carries the white dot ringed in
/// purple (existing pattern, mockup `.strip i.base::after`).
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.color, required this.isBase});

  final Color color;
  final bool isBase;

  static const double _dotSize = 5;
  static const double _dotBottomInset = 3;
  static const double _dotRingWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: color)),
        if (isBase)
          Positioned(
            left: 0,
            right: 0,
            bottom: _dotBottomInset,
            child: Center(
              child: Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    // 0 0 0 1.5px purple ring (mockup box-shadow).
                    BoxShadow(color: c.accent, spreadRadius: _dotRingWidth),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
