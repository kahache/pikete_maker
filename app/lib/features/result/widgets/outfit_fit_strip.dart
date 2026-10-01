import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import 'outfit_result_keys.dart';

/// SECONDARY (D36): the DEMOTED extracted palette — the ARRIBA/ABAJO garment
/// colours as compact 26px strips with the BASE point + attribution. The
/// differentiator vs Powsty (per-garment reading) is kept, but as EVIDENCE
/// under the recommendation, not as the headline.
///
/// Region labels are REGIONS, never garment types (U2); a single surviving
/// block is "TU ROPA" (U5); a whole-photo degrade (no blocks) shows one
/// unlabeled strip (design §4). Canvas mode shows the neutral strips with the
/// honest "no base → we send color" caption.
///
/// Internal to the `result` feature.
class OutfitFitStrip extends StatelessWidget {
  const OutfitFitStrip({super.key, required this.result});

  final AnalysisResult result;

  /// Compact strip height (mockup `.mini-strip { height: 26px }`).
  static const double _stripHeight = 26;

  /// Width of the region-label column (mockup `.mini-row .region`).
  static const double _regionWidth = 52;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final bool canvas = result.isCanvas;
    final List<GarmentBlockData> garments = result.garments;

    // The mini-rows: one per garment block, or a single unlabeled row from the
    // combined palette when the segmented flow degraded to whole-photo (S4) or
    // never ran (legacy is handled elsewhere — this widget is D36-only).
    final List<Widget> rows = <Widget>[];
    if (garments.isEmpty) {
      rows.add(_MiniRow(
        label: null,
        colors: <Color>[for (final ColorSample s in result.palette) s.color],
        baseIndexInStrip: canvas ? -1 : result.baseIndex,
      ));
    } else {
      final bool single = garments.length == 1;
      for (final GarmentBlockData g in garments) {
        rows.add(_MiniRow(
          label: single
              ? l10n.garmentSingleLabel
              : (g.region == GarmentRegion.upper
                  ? l10n.garmentUpperLabel
                  : l10n.garmentLowerLabel),
          colors: <Color>[for (final ColorSample s in g.palette) s.color],
          // The base dot lives in the block that owns the GLOBAL base.
          baseIndexInStrip: g.globalBaseIndex,
        ));
      }
    }

    return Container(
      key: OutfitResultKeys.fitStrip,
      margin: const EdgeInsets.only(top: Space.lg),
      padding: const EdgeInsets.only(top: Space.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            (canvas ? l10n.resultPaletteLabelCanvas : l10n.resultPaletteLabel)
                .toUpperCase(),
            style: AppType.label.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.sm),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: Space.sm),
            rows[i],
          ],
          const SizedBox(height: Space.md),
          canvas ? _canvasCaption(context) : _baseCaption(context),
        ],
      ),
    );
  }

  /// Chromatic caption: BASE badge (purple dose 1 of 2) + "Tu color dominante"
  /// with the region attribution — the EXISTING copy, reused verbatim (D36
  /// keeps the current attribution sentences).
  Widget _baseCaption(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final List<GarmentBlockData> garments = result.garments;
    final GarmentBlockData? baseBlock = result.baseBlock;
    final String? attribution = (garments.length >= 2 && baseBlock != null)
        ? (baseBlock.region == GarmentRegion.upper
            ? l10n.resultBaseAttributionUpper
            : l10n.resultBaseAttributionLower)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
          decoration: BoxDecoration(
            color: c.accentTint,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Text(l10n.resultBaseBadge,
              style: AppType.label.copyWith(color: c.accent)),
        ),
        const SizedBox(height: Space.xs),
        Text.rich(
          TextSpan(
            style: AppType.caption.copyWith(color: c.textSecondary),
            children: <TextSpan>[
              TextSpan(
                text: l10n.resultBaseLead,
                style: TextStyle(
                    color: c.textPrimary, fontWeight: FontWeight.w600),
              ),
              if (attribution != null) TextSpan(text: attribution),
              TextSpan(text: l10n.resultBaseRest),
            ],
          ),
        ),
      ],
    );
  }

  /// Canvas caption: no chromatic base → the honest "we send color, not
  /// harmonies" line (D36 §5).
  Widget _canvasCaption(BuildContext context) {
    final AppColors c = context.colors;
    return Text(context.l10n.resultCanvasBaseCap,
        style: AppType.caption.copyWith(color: c.textSecondary));
  }
}

/// One demoted mini-row: optional region label + a 26px swatch strip. The base
/// swatch (if any) carries the white dot ringed in purple.
class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.label,
    required this.colors,
    required this.baseIndexInStrip,
  });

  final String? label;
  final List<Color> colors;

  /// Index within [colors] of the global base, or -1 when this strip owns no
  /// base (the non-base garment, or canvas mode).
  final int baseIndexInStrip;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (label != null)
          SizedBox(
            width: OutfitFitStrip._regionWidth,
            child: Text(label!.toUpperCase(),
                style: AppType.label.copyWith(color: c.textTertiary)),
          ),
        Expanded(
          child: Container(
            height: OutfitFitStrip._stripHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < colors.length; i++)
                  Expanded(
                    child: _MiniSwatch(
                      color: colors[i],
                      isBase: i == baseIndexInStrip,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One compact swatch of the demoted strip; the base carries the white dot
/// ringed in purple (mockup `.mini-strip i.base::after`).
class _MiniSwatch extends StatelessWidget {
  const _MiniSwatch({required this.color, required this.isBase});

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
