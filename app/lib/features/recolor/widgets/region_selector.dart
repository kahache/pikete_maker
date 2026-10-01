import 'package:flutter/material.dart';

import '../../../core/segmentation/garment_segmenter.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../recolor_target.dart';

/// The two-segment ARRIBA / ABAJO control of the recolor view (I2, UX §2.2):
/// 48 tall, `label` typography, `surfaceSubtle` track; the active segment is
/// white with `shadow.sm` and a 1.5 px `action` ring + `action` text. Shown
/// only when BOTH regions qualify (the view hides it otherwise).
class RegionSelector extends StatelessWidget {
  /// Creates the selector over [regions] (upper first).
  const RegionSelector({
    super.key,
    required this.regions,
    required this.selected,
    required this.onSelect,
  });

  /// The offered regions (two).
  final List<GarmentRegion> regions;

  /// The active region.
  final GarmentRegion selected;

  /// Called with the tapped region (never with the active one).
  final ValueChanged<GarmentRegion> onSelect;

  /// Control height (UX §2.2).
  static const double height = 48;

  /// Track padding and gap between the segments.
  static const double _inset = Space.xs;

  /// Active ring width (mockup `inset 0 0 0 1.5px action`).
  static const double _ringWidth = 1.5;

  /// Test key of one segment.
  static Key segmentKey(GarmentRegion region) =>
      Key('recolor_segment_${region.name}');

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    return Container(
      height: height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < regions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: _inset),
            Expanded(child: _segment(c, l10n, regions[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment(AppColors c, AppLocalizations l10n, GarmentRegion region) {
    final bool on = region == selected;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        key: segmentKey(region),
        behavior: HitTestBehavior.opaque,
        onTap: on ? null : () => onSelect(region),
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.bg : c.surfaceSubtle,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: on ? Border.all(color: c.action, width: _ringWidth) : null,
            boxShadow: on ? AppShadows.sm : null,
          ),
          child: Text(
            recolorRegionLabel(l10n, region).toUpperCase(),
            style:
                AppType.label.copyWith(color: on ? c.action : c.textSecondary),
          ),
        ),
      ),
    );
  }
}
