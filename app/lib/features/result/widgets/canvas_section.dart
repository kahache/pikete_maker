import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/result_blocks.dart';

/// Canvas mode (D10, #21): the outfit is 100% neutral, so there is no
/// chromatic base to harmonize. Instead of arbitrary-hue schemes (bug B3) we
/// acknowledge the neutral "canvas" honestly and propose a curated set of
/// versatile accent "pops" (fashion curation, not math).
///
/// Internal to the `result` feature.
class CanvasSection extends StatelessWidget {
  const CanvasSection({
    super.key,
    required this.accents,
    required this.selectedIndex,
    required this.onAccentTap,
  });

  final List<Color> accents;
  final int? selectedIndex;
  final ValueChanged<int> onAccentTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.l10n.canvasTitle,
            style: AppType.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.xs),
        Text(context.l10n.canvasBody,
            style: AppType.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.lg),
        CanvasAccentsWrap(
          accents: accents,
          selectedIndex: selectedIndex,
          onAccentTap: onAccentTap,
        ),
      ],
    );
  }
}
