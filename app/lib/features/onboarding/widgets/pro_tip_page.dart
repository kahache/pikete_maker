import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/pk_buttons.dart';
import '../tip_illustrations.dart';
import 'tip_highlight_loop.dart';

/// ONB-2 · Pro tip "Clava los colores". 1 dose of purple (TIP PRO badge).
///
/// Internal to the `onboarding` feature.
class ProTipPage extends StatelessWidget {
  const ProTipPage({super.key, required this.onTakePhoto});

  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screenMargin,
        Space.xxl,
        Space.screenMargin,
        Space.thumbZoneCta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ProTipBadge(),
          const SizedBox(height: Space.md),
          Text(
            context.l10n.onbTipHeadline,
            style: AppType.display.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: Space.xl),
          // Good/bad comparison (schematic silhouettes, no photos).
          const Row(
            children: <Widget>[
              Expanded(child: _ExampleCard(good: true)),
              SizedBox(width: Space.md),
              Expanded(child: _ExampleCard(good: false)),
            ],
          ),
          const SizedBox(height: Space.xl),
          const TipHighlightLoop(),
          const SizedBox(height: Space.md),
          Text(
            context.l10n.onbTipCaption,
            style: AppType.caption.copyWith(color: c.textSecondary),
          ),
          const Spacer(),
          PkPrimaryButton(
              label: context.l10n.onbTipCta, onPressed: onTakePhoto),
        ],
      ),
    );
  }
}

/// "TIP PRO" badge — the single purple dose of ONB-2.
class _ProTipBadge extends StatelessWidget {
  const _ProTipBadge();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: c.accentTint, // 1st of the ≤2 purple doses
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(context.l10n.onbTipBadge,
          style: AppType.label.copyWith(color: c.accent)),
    );
  }
}

/// Good/bad thumbnail with the ux-designer illustrations (#52): BIEN = plain
/// wall, MAL = cluttered room. Illustrated, no real photos (avoids body/skin
/// bias, onboarding §2.3).
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.good});

  final bool good;

  /// Height of the illustrated scene inside the card (the label row below
  /// brings the card back to the ~120px footprint of the previous design).
  static const double _sceneHeight = 88;

  /// Frame width of the BIEN card (the MAL card keeps the hairline).
  static const double _goodFrameWidth = 1.5;

  /// Size of the check/close glyph in the label row.
  static const double _labelIconSize = 14;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color frame = good ? c.success : c.border;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: frame, width: good ? _goodFrameWidth : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: _sceneHeight,
            width: double.infinity,
            child: TipIllustration(cluttered: !good),
          ),
          const SizedBox(height: Space.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                good ? Icons.check : Icons.close,
                size: _labelIconSize,
                color: good ? c.success : c.textTertiary,
              ),
              const SizedBox(width: Space.xs),
              Text(
                good ? context.l10n.onbExampleGood : context.l10n.onbExampleBad,
                style: AppType.label.copyWith(
                  color: good ? c.success : c.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    );
  }
}
