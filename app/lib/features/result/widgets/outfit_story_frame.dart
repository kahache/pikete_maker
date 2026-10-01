import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../sneaker/widgets/hero_combo.dart';
import '../../sneaker/widgets/hero_combo_band.dart';
import '../../story/story_layout.dart';
import '../../story/widgets/story_canvas_band.dart';
import '../../story/widgets/story_frame.dart';
import 'outfit_hero_combo_spec.dart';
import 'outfit_share_canvas.dart';

/// The outfit's CARD-ONLY story (A3, r13; the "Incluir mi foto" OFF image of
/// N1 / D37): the same [OutfitShareCanvas] the user sees on screen, its text
/// watermark OFF, signed with the real brand lockup below it, inside a true
/// 9:16 frame. Byte-identical to r13 (it is now the shared
/// [StoryFrame.card] layout).
///
/// Internal to the `result` feature.
class OutfitStoryFrame extends StatelessWidget {
  const OutfitStoryFrame({
    super.key,
    required this.result,
    this.selectedAccentIndex,
    this.selectedScheme,
  });

  final AnalysisResult result;

  /// Canvas-mode pop the user picked on screen (#82): the story shows the
  /// same selection (what you see is what you share).
  final int? selectedAccentIndex;

  /// D39: the selected "Otras combis" combo (null = the hero).
  final HarmonyType? selectedScheme;

  /// Kept for r13 call sites / tests: the shared story geometry.
  static const Size logicalSize = StoryGeometry.logicalSize;
  static const double pixelRatio = StoryGeometry.pixelRatio;
  static const double safeInsetV = StoryGeometry.safeInsetV;

  @override
  Widget build(BuildContext context) {
    return StoryFrame.card(
      card: OutfitShareCanvas(
        result: result,
        selectedAccentIndex: selectedAccentIndex,
        selectedScheme: selectedScheme,
        showWatermark: false,
      ),
    );
  }
}

/// The outfit's PHOTO story (N1 / D37, default ON): headline "Toma tu pikete"
/// (canvas: "Tu fit pide color") · the user's whole photo with the hero band
/// glued under it · the full-colour lockup. Date, kicker, caption and the
/// ARRIBA/ABAJO strip are NOT in it: the photo is the evidence now.
///
/// [photo] must already be decoded (see `decodeStoryPhoto`); the frame paints
/// it synchronously.
class OutfitPhotoStoryFrame extends StatelessWidget {
  const OutfitPhotoStoryFrame({
    super.key,
    required this.result,
    required this.photo,
    this.selectedAccentIndex,
    this.headline,
    this.selectedScheme,
  });

  final AnalysisResult result;
  final ui.Image photo;

  /// Headline override (I2, D38): the recolor view shares its own
  /// conditional headline ("Así te quedaría") with the RECOLORED photo; null
  /// = the D37 default ("Toma tu pikete" / canvas "Tu fit pide color").
  final String? headline;

  /// D39: the selected "Otras combis" combo the band shows (null = the hero).
  final HarmonyType? selectedScheme;

  /// Canvas-mode pop the user picked on screen (#82): it takes 40% of the
  /// band with the "súmale" tag.
  final int? selectedAccentIndex;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canvas = result.isCanvas;
    return StoryFrame.photo(
      headline: headline ??
          (canvas ? l10n.resultCanvasHeadline : l10n.resultRecoHeadline),
      photo: photo,
      band: canvas
          ? StoryCanvasBand(
              accents: result.canvasAccents,
              height: StoryGeometry.bandHeight,
              selectedIndex: selectedAccentIndex,
              selectedTag: l10n.resultTagAdd.toUpperCase(),
            )
          // The hero combo (complementary) by default; D39 (amends D37 §2.3):
          // the combo selected in "Otras combis" when there is one. D31-A:
          // raw.
          : HeroComboBand(
              combo: HeroCombo.of(result, l10n.localeName,
                  snapForDisplay: false, scheme: selectedScheme),
              spec: outfitHeroBandSpec,
              height: StoryGeometry.bandHeight,
              framed: false,
            ),
    );
  }
}
