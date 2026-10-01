// foundation provides @immutable (painting only re-exports dart:ui, not meta).
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../segmentation/garment_segmenter.dart'
    show GarmentRegion, SegmentationClassMap;

// Consumers of the per-garment models (result screen, tests) need the region
// enum without importing the segmentation seam directly.
export '../segmentation/garment_segmenter.dart' show GarmentRegion;

/// Domain models of the color analysis.
///
/// They are the CONTRACT between the UI (this scaffold) and the color core
/// reimplemented in Dart (D15, canonical reference: `cv_core/colorlab`). The
/// UI is built against these types; the port only has to produce them. If the
/// port needs to change the shape, it changes here and the compiler flags
/// every affected spot in the UI.

/// One color sample of the palette extracted from the outfit.
@immutable
class ColorSample {
  /// Creates a palette sample of [color] covering [weight] of the photo.
  const ColorSample({required this.color, required this.weight});

  /// The color of the garment/area.
  final Color color;

  /// Relative weight in the photo (0..1). Determines the band height.
  final double weight;

  /// Uppercase HEX (#RRGGBB) for the mono index of the palette.
  String get hex {
    // ignore: deprecated_member_use  (Color.value: universal across Flutter 3.19+)
    final int rgb = color.value & 0xFFFFFF;
    return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  /// Integer percentage for the index ("36%").
  int get percent => (weight * 100).round();
}

/// Harmony types (F4). UI names live in [Harmony.name].
enum HarmonyType {
  /// Base + its opposite hue: maximum contrast, 2 colors.
  complementary,

  /// Base + its two hue neighbours: low-contrast, harmonious.
  analogous,

  /// Three hues evenly spaced around the wheel: vivid but balanced.
  triadic,

  /// Base + the two hues flanking its complement: contrast, softer.
  splitComplementary,
}

/// One harmony proposal that matches the base color (D5).
@immutable
class Harmony {
  /// Creates a harmony proposal of [type] built from the outfit's base color.
  const Harmony({
    required this.type,
    required this.name,
    required this.description,
    required this.colors,
  });

  /// Which scheme this is.
  final HarmonyType type;

  /// Engine-side es name, e.g. "Complementario". Doubles as the `harmonies()`
  /// dict key; the UI renders the localized name from the ARB instead.
  final String name;

  /// Engine-side es one-liner, e.g. "Contraste máximo, 2 colores".
  final String description;

  /// The colors of the scheme, in swatch-strip order (base first).
  final List<Color> colors;
}

/// Segmentation layouts a result can carry (Phase 2.5, per-garment UX spec
/// §6 telemetry contract): the values are the literal `result_viewed
/// {layout}` / `segmentation_degraded {to}` strings — do not rename.
abstract final class SegmentationLayouts {
  /// Two garment blocks (ARRIBA/ABAJO) — the S1/S2 happy paths.
  static const String garments = 'garments';

  /// One surviving region ("TU ROPA", state S3).
  static const String single = 'single';

  /// Whole-photo degrade (state S4): today's layout, produced by the
  /// segmented flow after a loud [SegmentationException].
  static const String whole = 'whole';
}

/// Degrade reasons for `segmentation_degraded {reason}` (spec §6). Literal
/// event-param strings — do not rename.
abstract final class SegmentationDegradeReasons {
  /// The segmenter found no person in the photo.
  static const String noPerson = 'no_person';

  /// A garment region survived but was too small to analyze reliably.
  static const String regionTooSmall = 'region_too_small';

  /// The TFLite model itself failed to run.
  static const String modelFailed = 'model_failed';
}

/// The display data of ONE garment block on the per-garment result screen
/// (Phase 2.5, states S1-S3 of the UX spec). Weights in [palette] are
/// normalized WITHIN the garment (each block's mono index sums to ~100%).
@immutable
class GarmentBlockData {
  /// Creates the display data of one garment block.
  const GarmentBlockData({
    required this.region,
    required this.palette,
    required this.baseIndex,
    required this.globalBaseIndex,
  });

  /// Which garment region this block describes (upper / lower).
  final GarmentRegion region;

  /// This garment's palette, sorted by descending per-garment weight.
  final List<ColorSample> palette;

  /// Per-garment base (D5 on this garment alone); -1 = the garment is 100%
  /// neutral → the block shows the "neutro — combina con todo" caption (U7).
  final int baseIndex;

  /// Index within [palette] of the GLOBAL outfit base when THIS block owns
  /// it (its hex renders bold, spec §3.1), -1 otherwise.
  final int globalBaseIndex;

  /// True when the garment is fully neutral (per-garment canvas signal, U7).
  bool get isCanvas => baseIndex < 0;
}

/// Complete result of an analysis. Consumed by the result screen.
@immutable
class AnalysisResult {
  /// Creates a complete analysis result for the result screen.
  const AnalysisResult({
    required this.palette,
    required this.baseIndex,
    required this.harmonies,
    this.canvasAccents = const <Color>[],
    this.garments = const <GarmentBlockData>[],
    this.swatchRegions = const <GarmentRegion>[],
    this.segmentationLayout,
    this.segmentationDegradeReason,
    this.segmentationClassMap,
  });

  /// Palette sorted by descending weight.
  final List<ColorSample> palette;

  /// Index of the BASE color within [palette] (D5: the most chromatic one,
  /// never a neutral). -1 = 100% neutral outfit ("canvas mode", D10): the UI
  /// hides the chromatic BASE badge and shows [canvasAccents] instead of
  /// [harmonies].
  final int baseIndex;

  /// The 4 harmonies proposed around the base. Empty in canvas mode.
  final List<Harmony> harmonies;

  /// Canvas mode (D10): curated accent "pops" proposed for a neutral outfit,
  /// instead of arbitrary-hue harmonies. Empty unless [isCanvas].
  final List<Color> canvasAccents;

  /// Per-garment display blocks (Phase 2.5). EMPTY on the legacy whole-photo
  /// path (flag off) and on the S4 whole-photo degrade — the result screen
  /// then renders today's single 280px stack, pixel-identical. When
  /// non-empty, [palette]/[baseIndex] describe the COMBINED outfit palette
  /// (weights scaled by pixel share, engine contract #89) and the blocks
  /// carry the per-garment view the share canvas renders.
  final List<GarmentBlockData> garments;

  /// Region attribution of each COMBINED-palette swatch (`swatch_regions` in
  /// the #89 engine contract): `swatchRegions[i]` names the garment that owns
  /// `palette[i]`. Same length as [palette] on the per-garment path, EMPTY on
  /// the legacy whole-photo path.
  final List<GarmentRegion> swatchRegions;

  /// Which layout the segmented flow produced ([SegmentationLayouts]), or
  /// null when the analysis never ran the segmented path (flag off / product
  /// mode) — null keeps the legacy `result_viewed` event byte-identical.
  final String? segmentationLayout;

  /// Why the segmented flow degraded ([SegmentationDegradeReasons]), or null
  /// when it did not (S1/S2) or never ran. The `to` of the
  /// `segmentation_degraded` event is [segmentationLayout] by construction
  /// (region_too_small → single, no_person/model_failed → whole).
  final String? segmentationDegradeReason;

  /// The segmentation class map the per-garment analysis ran on (I2 recolor,
  /// D38), or null when there is none (flag off, product mode, S4 degrade,
  /// whole-photo segmenter). NOT part of the palette math: it is attached
  /// after the analysis ([withSegmentationClassMap]) and read only by the
  /// recolor service. Memory only: never persisted or logged.
  final SegmentationClassMap? segmentationClassMap;

  /// This result with [classMap] attached (every other field unchanged).
  AnalysisResult withSegmentationClassMap(SegmentationClassMap? classMap) =>
      AnalysisResult(
        palette: palette,
        baseIndex: baseIndex,
        harmonies: harmonies,
        canvasAccents: canvasAccents,
        garments: garments,
        swatchRegions: swatchRegions,
        segmentationLayout: segmentationLayout,
        segmentationDegradeReason: segmentationDegradeReason,
        segmentationClassMap: classMap,
      );

  /// True when the outfit is 100% neutral: no chromatic base, so the UI shows
  /// the curated [canvasAccents] rather than [harmonies] (D10).
  bool get isCanvas => baseIndex < 0;

  /// The base sample, or null in canvas mode.
  ColorSample? get base =>
      baseIndex >= 0 && baseIndex < palette.length ? palette[baseIndex] : null;

  /// The garment block that owns the GLOBAL base (bold hex + base-line
  /// attribution, spec §3.1), or null in canvas mode / non-garment layouts.
  GarmentBlockData? get baseBlock {
    for (final GarmentBlockData block in garments) {
      if (block.globalBaseIndex >= 0) {
        return block;
      }
    }
    return null;
  }
}
