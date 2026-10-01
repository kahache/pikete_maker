import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import 'home_keys.dart';

/// One half of the split: a full-bleed tint wash that is ONE big tap target —
/// glyph + label (`display`) + caption + "Empezar ›" pill, as a single block.
///
/// #81 (CEO r8 review): the block is aligned toward the CENTER DIVIDER
/// ([dividerBelow] picks the edge) with a fixed [_dividerGap], so the two
/// zones mirror around the middle of the screen instead of each block
/// floating at its zone's center (which read as "Mi pikete" hanging low,
/// pushed further by the nav-bar inset). The affordance is no longer pinned
/// to the zone's bottom edge — it closes the block as an outlined 44 px pill
/// in the zone ink (bigger, reads tappable; the whole zone stays the target).
///
/// Internal to the `home` feature.
class ModeZone extends StatelessWidget {
  const ModeZone({
    super.key,
    required this.background,
    required this.ink,
    required this.glyph,
    required this.label,
    required this.caption,
    required this.dividerBelow,
    required this.onTap,
  });

  final Color background;

  /// Zone ink (`mint.ink` / `purple.ink`): glyph + "Empezar" affordance.
  final Color ink;
  final Widget glyph;
  final String label;
  final String caption;

  /// True when the center divider sits UNDER this zone (top zone): the block
  /// bottom-aligns toward it. False for the bottom zone (top-aligns).
  final bool dividerBelow;
  final VoidCallback onTap;

  /// Mockup `.zone .glyph`: 84×84.
  static const double glyphSize = 84;

  /// #81: air between each content block and the center divider. Bumped
  /// `Space.xl` (24) → `Space.xxxl` (48) (#94 item 2, CEO 2026-07-19, the
  /// looser option): symmetric by design — it pushes the top zone up AND the
  /// bottom zone down by the same amount, so the #81 mirror is preserved.
  static const double _dividerGap = Space.xxxl;

  /// #81: "Empezar ›" chevron, 16 → 20 px alongside the caption → cta bump.
  static const double _goChevronSize = 20;

  /// Outline weight of the "Empezar ›" pill.
  static const double _goBorderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Align(
          alignment:
              dividerBelow ? Alignment.bottomCenter : Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: Space.xxl,
              right: Space.xxl,
              top: dividerBelow ? 0 : _dividerGap,
              bottom: dividerBelow ? _dividerGap : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                glyph,
                const SizedBox(height: Space.lg),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppType.display.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.lg),
                Container(
                  key: HomeKeys.goPill,
                  height: Sizes.touchTargetMin,
                  padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                  decoration: BoxDecoration(
                    border: Border.all(color: ink, width: _goBorderWidth),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        context.l10n.homeGoPill,
                        style: AppType.cta.copyWith(color: ink),
                      ),
                      const SizedBox(width: Space.xs),
                      Icon(Icons.chevron_right,
                          color: ink, size: _goChevronSize),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
