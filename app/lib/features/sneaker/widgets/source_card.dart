import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../sneaker_tip_case_data.dart';
import '../sneaker_tip_illustrations.dart';

/// One situation card (spec §3): emoji tile on `surfaceSubtle`, title + 1-line
/// hint, mint chevron. Anatomy = the source-sheet `_SourceOption` row, with the
/// icon swapped for a neutral emoji tile (mint budget spent only on the
/// chevron, D8).
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.tipCase, required this.onTap});

  final SneakerTipCase tipCase;
  final VoidCallback onTap;

  /// Card min-height per spec §3.
  static const double _minHeight = 72;

  /// Emoji tile side per spec §3.
  static const double _tileSize = 44;
  static const double _emojiFontSize = 24;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: _minHeight),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: _tileSize,
              height: _tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                tipCase.emoji,
                style: const TextStyle(fontSize: _emojiFontSize, height: 1),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tipCase.cardTitle(context.l10n),
                    style: AppType.heading.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    tipCase.cardHint(context.l10n),
                    style: AppType.caption.copyWith(color: c.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.action),
          ],
        ),
      ),
    );
  }
}
