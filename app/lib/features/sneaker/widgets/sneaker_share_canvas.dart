import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/result_blocks.dart';
import 'combo_caption.dart';
import 'hero_combo.dart';
import 'hero_combo_band.dart';
import 'palette_strip.dart';
import 'sneaker_hero_combo_spec.dart';
import 'sneaker_result_keys.dart';

/// The shareable card (spec §5.2): meta + title + hero kicker + hero combo
/// band (or canvas accents) + caption + demoted palette strip + watermark.
/// It is also the sneaker's card-only story ("Incluir mi foto" OFF, N1 /
/// D37), rendered with [showWatermark] off inside `StoryFrame.card`.
///
/// Internal to the `sneaker` feature; the outfit flow has its own canvas.
class SneakerShareCanvas extends StatelessWidget {
  const SneakerShareCanvas({
    super.key,
    required this.result,
    required this.selectedAccentIndex,
    this.onAccentTap,
    this.showWatermark = true,
  });

  final AnalysisResult result;

  /// Canvas-mode accent selection (#82), threaded down to the pops. A null
  /// callback renders plain, non-interactive pops (the exported story).
  final int? selectedAccentIndex;
  final ValueChanged<int>? onAccentTap;

  /// The in-card text watermark. On screen it stays; the shared story turns
  /// it off because the story frame signs the image with the real lockup —
  /// one brand signature, never two (USAGE §6).
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final HeroCombo? combo =
        result.isCanvas ? null : HeroCombo.of(result, l10n.localeName);
    return Container(
      padding:
          const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x141C1826), // tinted shadow.sm (D9)
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.sneakerResultMeta(
                localizedShortDate(DateTime.now(), l10n.localeName)),
            style: AppType.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.sm),
          Text(l10n.sneakerResultTitle,
              style: AppType.display.copyWith(color: c.textPrimary)),
          const SizedBox(height: Space.lg),
          // Hero kicker: names the hero scheme, ties to "Otras combis".
          // Neutral by design (label style; not a purple dose).
          Text(
            (combo == null
                    ? l10n.sneakerCanvasKicker
                    : l10n.sneakerResultHeroKicker)
                .toUpperCase(),
            style: AppType.label.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.sm),
          // PROTAGONIST (D27): the recommended combo — or, for neutral kicks,
          // the curated canvas pops (D10).
          if (combo == null)
            CanvasAccentsWrap(
              key: SneakerResultKeys.canvasAccents,
              accents: result.canvasAccents,
              selectedIndex: selectedAccentIndex,
              onAccentTap: onAccentTap,
            )
          else
            HeroComboBand(combo: combo, spec: sneakerHeroBandSpec),
          const SizedBox(height: Space.md),
          ComboCaption(combo: combo, copy: sneakerCaptionCopy),
          const SizedBox(height: Space.lg),
          PaletteStrip(result: result),
          if (showWatermark) ...const <Widget>[
            SizedBox(height: Space.lg),
            BrandWatermark(),
          ],
        ],
      ),
    );
  }
}
