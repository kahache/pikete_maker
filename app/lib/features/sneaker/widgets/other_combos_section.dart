import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/result_blocks.dart';

/// "Otras combis" (spec §5.3): the 3 REMAINING harmonies, relabelled — the
/// complementary is the hero and is not repeated. Row anatomy unchanged from
/// the outfit result. Hidden entirely in canvas mode.
///
/// Internal to the `sneaker` feature.
class OtherCombosSection extends StatelessWidget {
  const OtherCombosSection({
    super.key,
    required this.result,
    required this.selected,
    required this.onSelect,
  });

  final AnalysisResult result;

  /// F5 selection (#82): the selected scheme (null = the hero combo).
  final HarmonyType? selected;
  final ValueChanged<HarmonyType> onSelect;

  /// Display labels per engine scheme (spec §5 table / copy map §6), in the
  /// ACTIVE locale.
  static List<(HarmonyType, String, String)> _rows(AppLocalizations l10n) =>
      <(HarmonyType, String, String)>[
        (
          HarmonyType.analogous,
          l10n.sneakerHarmonyAnalogousName,
          l10n.sneakerHarmonyAnalogousSub,
        ),
        (
          HarmonyType.triadic,
          l10n.sneakerHarmonyTriadicName,
          l10n.sneakerHarmonyTriadicSub,
        ),
        (
          HarmonyType.splitComplementary,
          l10n.sneakerHarmonySplitName,
          l10n.sneakerHarmonySplitSub,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.sneakerSectionTitle,
            style: AppType.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.xs),
        Text(l10n.sneakerSectionSub,
            style: AppType.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.lg),
        for (final (HarmonyType type, String name, String sub) in _rows(l10n))
          for (final Harmony harmony in result.harmonies)
            if (harmony.type == type)
              _ComboRow(
                name: name,
                sub: sub,
                colors: harmony.colors,
                selected: type == selected,
                onTap: () => onSelect(type),
              ),
      ],
    );
  }
}

/// One "Otras combis" row: relabelled name left, 132×44 swatch strip closing
/// the row (#94 item 3 removed the trailing mint chevron).
/// Tap SELECTS the scheme for the primary CTA's deep-link (F5 v0, #82);
/// selected = action-fill chip with white text ([SchemeNameChip]).
class _ComboRow extends StatelessWidget {
  const _ComboRow({
    required this.name,
    required this.sub,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String sub;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.touchTargetMin),
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SchemeNameChip(label: name, selected: selected),
                  Text(sub,
                      style: AppType.caption.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: Space.lg),
            // #94 item 3: dead trailing mint `›` removed (see HarmonyRow) —
            // it only selected the row (#82), never navigated. Tap unchanged.
            SwatchStrip(colors: colors),
          ],
        ),
      ),
    );
  }
}
