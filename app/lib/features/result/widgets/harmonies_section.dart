import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/result_blocks.dart';

/// "Combina con" section: the 4 harmonies (F4). Tapping one SELECTS it and
/// parameterizes the "Ver looks así" deep-link (F5 v0, #82).
///
/// Internal to the `result` feature.
class HarmoniesSection extends StatelessWidget {
  const HarmoniesSection({
    super.key,
    required this.harmonies,
    required this.selected,
    required this.onSelect,
  });

  final List<Harmony> harmonies;
  final HarmonyType? selected;
  final ValueChanged<HarmonyType> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(context.l10n.harmoniesTitle,
            style: AppType.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.xs),
        Text(context.l10n.harmoniesSub,
            style: AppType.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.lg),
        for (final Harmony harmony in harmonies)
          HarmonyRow(
            harmony: harmony,
            selected: harmony.type == selected,
            onTap: () => onSelect(harmony.type),
          ),
      ],
    );
  }
}

/// One selectable harmony row: localized scheme name chip + description on the
/// left, the swatch strip closing the row.
///
/// Internal to the `result` feature.
class HarmonyRow extends StatelessWidget {
  const HarmonyRow({
    super.key,
    required this.harmony,
    required this.selected,
    required this.onTap,
  });

  final Harmony harmony;
  final bool selected;
  final VoidCallback onTap;

  /// UI name/description of a scheme in the ACTIVE locale, keyed by
  /// [HarmonyType]. The ENGINE's `Harmony.name/description` stay the es
  /// literals (they double as the `harmonies()` dict keys — engine internals
  /// this screen only consumes); the es ARB mirrors them verbatim, so the
  /// Spanish render is byte-identical to `harmony.name`.
  static String _name(AppLocalizations l10n, HarmonyType type) =>
      switch (type) {
        HarmonyType.complementary => l10n.harmonyComplementaryName,
        HarmonyType.analogous => l10n.harmonyAnalogousName,
        HarmonyType.triadic => l10n.harmonyTriadicName,
        HarmonyType.splitComplementary => l10n.harmonySplitName,
      };

  static String _description(AppLocalizations l10n, HarmonyType type) =>
      switch (type) {
        HarmonyType.complementary => l10n.harmonyComplementaryDesc,
        HarmonyType.analogous => l10n.harmonyAnalogousDesc,
        HarmonyType.triadic => l10n.harmonyTriadicDesc,
        HarmonyType.splitComplementary => l10n.harmonySplitDesc,
      };

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
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
                  SchemeNameChip(
                      label: _name(l10n, harmony.type), selected: selected),
                  Text(_description(l10n, harmony.type),
                      style: AppType.caption.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: Space.lg),
            // #94 item 3: the trailing mint `›` was a navigation cue that only
            // ever SELECTED the row (radio behaviour for #82) — removed so the
            // swatch strip (the actual color) closes the row (Principle 1) and
            // a stray mint dose drops (D8). Row tap/selection is unchanged.
            SwatchStrip(colors: harmony.colors),
          ],
        ),
      ),
    );
  }
}
