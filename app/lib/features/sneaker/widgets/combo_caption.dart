import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import 'hero_combo.dart';

/// Per-flow copy of a [ComboCaption] (A6 / review F18): the sneaker (D27) and
/// outfit (D36) captions are the same widget and differ ONLY in their ARB
/// keys. Each flow owns its copy (`sneaker_hero_combo_spec.dart`,
/// `result/widgets/outfit_hero_combo_spec.dart`).
@immutable
class ComboCaptionCopy {
  const ComboCaptionCopy({
    required this.lead,
    required this.rest,
    required this.canvasRest,
    this.canvasLead,
  });

  /// Chromatic combo: the lead phrase (600 textPrimary) and the rest.
  final String Function(AppLocalizations l10n, HeroCombo combo) lead;
  final String Function(AppLocalizations l10n, HeroCombo combo) rest;

  /// Canvas mode (no combo): lead + rest like the chromatic caption, or — when
  /// [canvasLead] is null — [canvasRest] alone as a single plain line.
  final String Function(AppLocalizations l10n)? canvasLead;
  final String Function(AppLocalizations l10n) canvasRest;
}

/// Caption under the hero: lead phrase in 600 textPrimary + rest in
/// textSecondary — the one-liner that explains why the combo works. Canvas
/// mode ([combo] == null) gets its own copy. Shared by the sneaker and outfit
/// results; the per-flow strings come from [copy].
class ComboCaption extends StatelessWidget {
  const ComboCaption({super.key, required this.combo, required this.copy});

  final HeroCombo? combo;
  final ComboCaptionCopy copy;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final TextStyle base = AppType.caption.copyWith(color: c.textSecondary);
    final HeroCombo? hero = combo;
    final String Function(AppLocalizations)? canvasLead = copy.canvasLead;
    if (hero == null && canvasLead == null) {
      // Single honest line (outfit canvas mode reuses `canvasBody`, D36 §5).
      return Text(copy.canvasRest(l10n), style: base);
    }
    final String lead =
        hero == null ? canvasLead!(l10n) : copy.lead(l10n, hero);
    final String rest =
        hero == null ? copy.canvasRest(l10n) : copy.rest(l10n, hero);
    return Text.rich(
      TextSpan(
        style: base,
        children: <TextSpan>[
          TextSpan(
            text: lead,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: rest),
        ],
      ),
    );
  }
}
