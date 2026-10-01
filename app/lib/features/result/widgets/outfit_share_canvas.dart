import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/result_blocks.dart';
import '../../sneaker/widgets/combo_caption.dart';
import '../../sneaker/widgets/hero_combo.dart';
import '../../sneaker/widgets/hero_combo_band.dart';
import 'base_line.dart';
import 'outfit_fit_strip.dart';
import 'outfit_hero_combo_spec.dart';
import 'outfit_result_keys.dart';
import 'palette_bands.dart';

/// Shareable area (F6): the 9:16 object designed to survive without the
/// surrounding UI.
///
/// TWO layouts share this container:
///  - **D36 recommendation-first** (segmented path, `segmentationLayout` set —
///    every production outfit render): meta + headline "Toma tu pikete" + hero
///    kicker + hero combo band (or canvas pops) + caption + the DEMOTED "tu
///    fit" strip (ARRIBA/ABAJO evidence) + watermark. The recommendation is the
///    protagonist, mirroring the sneaker result's D27 inverted hierarchy.
///  - **Legacy** (`segmentationLayout == null` — the whole-photo safety
///    fallback / flag-off path, only reached by legacy fixtures now): today's
///    extraction-led layout, byte-identical ("Tu paleta" + palette bands + base
///    line). Kept so the S4 whole-photo degrade guarantee never regresses.
///
/// Internal to the `result` feature; the sneaker flow has its own canvas.
class OutfitShareCanvas extends StatelessWidget {
  const OutfitShareCanvas({
    super.key,
    required this.result,
    this.selectedAccentIndex,
    this.onAccentTap,
    this.showWatermark = true,
    this.selectedScheme,
  });

  final AnalysisResult result;

  /// D39: the combo selected in "Otras combis" (null = the hero
  /// complementary). The band, its caption and the kicker swap IN PLACE to
  /// it. Ignored in canvas mode and on the legacy layout.
  final HarmonyType? selectedScheme;

  /// Canvas-mode accent selection (#82), threaded down to the pops (D36 hero).
  final int? selectedAccentIndex;
  final ValueChanged<int>? onAccentTap;

  /// The in-card text watermark. On screen it stays (unchanged); the shared
  /// story (A3) turns it off because `OutfitStoryFrame` signs the image with
  /// the real logo lockup instead — one brand signature, never two.
  final bool showWatermark;

  /// D36 applies on the production (segmented) path; a null layout is the
  /// legacy whole-photo safety fallback that keeps today's screen.
  bool get _reco => result.segmentationLayout != null;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
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
      child: _reco ? _recoContent(context) : _legacyContent(context),
    );
  }

  /// D36 recommendation-first content (hero above the demoted "tu fit" strip).
  Widget _recoContent(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final bool canvas = result.isCanvas;
    // D31-A: outfit swatches are shown RAW (the display snap is product-mode).
    final HeroCombo? combo = canvas
        ? null
        : HeroCombo.of(result, l10n.localeName,
            snapForDisplay: false, scheme: selectedScheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.resultMeta(localizedShortDate(DateTime.now(), l10n.localeName)),
          style: AppType.caption.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: Space.sm),
        Text(canvas ? l10n.resultCanvasHeadline : l10n.resultRecoHeadline,
            style: AppType.display.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.lg),
        // Hero kicker: names the hero scheme, ties to "Otras combis". Neutral
        // by design (label style; not a purple dose).
        Text(
          (canvas
                  ? l10n.resultCanvasKicker
                  : outfitHeroKicker(l10n, selectedScheme))
              .toUpperCase(),
          style: AppType.label.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: Space.sm),
        // PROTAGONIST (D36): the recommended combo — or, for neutral outfits,
        // the curated canvas pops (D10) promoted to the hero position.
        if (canvas)
          CanvasAccentsWrap(
            key: OutfitResultKeys.canvasAccents,
            accents: result.canvasAccents,
            selectedIndex: selectedAccentIndex,
            onAccentTap: onAccentTap,
          )
        else
          HeroComboBand(combo: combo!, spec: outfitHeroBandSpec),
        const SizedBox(height: Space.md),
        ComboCaption(combo: combo, copy: outfitCaptionCopy),
        // SECONDARY: the demoted ARRIBA/ABAJO extraction (evidence).
        OutfitFitStrip(result: result),
        if (showWatermark) ...const <Widget>[
          SizedBox(height: Space.lg),
          BrandWatermark(),
        ],
      ],
    );
  }

  /// Legacy extraction-led content (byte-identical to the pre-D36 screen).
  Widget _legacyContent(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.resultHeadlineLegacy,
            style: AppType.display.copyWith(color: c.textPrimary)),
        const SizedBox(height: Space.xs),
        Text(
            l10n.resultMeta(localizedShortDate(DateTime.now(), l10n.localeName)),
            style: AppType.caption.copyWith(color: c.textTertiary)),
        const SizedBox(height: Space.xl),
        PaletteBands(samples: result.palette, baseIndex: result.baseIndex),
        if (result.base != null) ...<Widget>[
          const SizedBox(height: Space.xl),
          BaseLine(base: result.base!),
        ],
        if (showWatermark) ...const <Widget>[
          SizedBox(height: Space.lg),
          BrandWatermark(),
        ],
      ],
    );
  }
}
