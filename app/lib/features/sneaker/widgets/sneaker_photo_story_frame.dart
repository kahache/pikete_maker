import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../story/story_layout.dart';
import '../../story/widgets/story_canvas_band.dart';
import '../../story/widgets/story_frame.dart';
import 'hero_combo.dart';
import 'hero_combo_band.dart';
import 'sneaker_hero_combo_spec.dart';

/// The sneaker PHOTO story (N1 / D37 spec §5.1, default ON): the title
/// "Combina tu ropa con estas zapas" on TWO lines at 32 px (CEO decision
/// 2026-09-29: same size as the outfit headline, not a 1-line scale-down) ·
/// the user's whole photo with the sneaker hero band glued under it
/// ("tus zapas / tu ropa / + {neutro}", flex 115:155:90) · the lockup. With a
/// 2-line headline the photo box max is 392 × 377 (a 3:4 shot → 283 × 377).
///
/// Canvas kicks (D10): the five curated pops; a pop picked on screen takes
/// 40% with the "súmale" tag (spec §2.2).
///
/// [photo] must already be decoded (`decodeStoryPhoto`); painted
/// synchronously by the offscreen render.
class SneakerPhotoStoryFrame extends StatelessWidget {
  const SneakerPhotoStoryFrame({
    super.key,
    required this.result,
    required this.photo,
    this.selectedAccentIndex,
  });

  final AnalysisResult result;
  final ui.Image photo;
  final int? selectedAccentIndex;

  /// The sneaker title always takes two lines (spec §5.1).
  static const int headlineLines = 2;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return StoryFrame.photo(
      headline: l10n.sneakerResultTitle,
      headlineLines: headlineLines,
      photo: photo,
      band: result.isCanvas
          ? StoryCanvasBand(
              accents: result.canvasAccents,
              height: StoryGeometry.bandHeight,
              selectedIndex: selectedAccentIndex,
              selectedTag: l10n.resultTagAdd.toUpperCase(),
            )
          // Same combo as the on-screen hero: product mode keeps the display
          // snap (D31-A), so what you see is what you share.
          : HeroComboBand(
              combo: HeroCombo.of(result, l10n.localeName),
              spec: sneakerHeroBandSpec,
              height: StoryGeometry.bandHeight,
              framed: false,
            ),
    );
  }
}
