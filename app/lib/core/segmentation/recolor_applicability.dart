import 'dart:typed_data';

import '../recolor/opencv_lab.dart';
import 'garment_segmenter.dart';
import 'mask_hardening.dart';
import 'mask_hygiene.dart';
import 'raster_ops.dart';

/// I2 v1 scope (D38): the recolor is offered only for ONE person in DECENT
/// light with a usable mask. The engine DETECTS and REPORTS "not applicable"
/// so the UI can show a tip instead of painting garbage — Dart port of
/// `check_applicability` in `cv_core/src/colorlab/segmentation.py` (the
/// canonical reference; parity pinned by `recolor_parity_I2.json`).
///
/// Every rule is a cheap statistic of the RAW class map (+ the photo for the
/// light rule, + the hardened un-eroded regions for the size rule).

/// Why a photo (or a region) does not qualify for the recolor — the first
/// rule that fires, in this order (Python `REASON_*`).
enum RecolorBlocker {
  /// A second person component (`several_people`).
  severalPeople,

  /// A dim frame / a person with no highlights in a dim scene
  /// (`poor_light`).
  poorLight,

  /// The raw clothes class is swiss cheese / speckled / mostly detached
  /// (`mask_unreliable`).
  maskUnreliable,

  /// The garment region is under [kRecolorMinRegionFraction] of the frame
  /// (`region_too_small`; photo-level only when EVERY region is).
  regionTooSmall,

  /// Dart-only (no Python rule): there is no segmentation class map at all —
  /// the S4 whole-photo degrade, the legacy flag-off engine or product mode.
  /// The recolor has nothing to paint with (`no_mask` in the gate harness).
  noSegmentation,
}

/// Python's reason string of a [RecolorBlocker] (fixtures, diagnostics).
String recolorBlockerId(RecolorBlocker reason) => switch (reason) {
      RecolorBlocker.severalPeople => 'several_people',
      RecolorBlocker.poorLight => 'poor_light',
      RecolorBlocker.maskUnreliable => 'mask_unreliable',
      RecolorBlocker.regionTooSmall => 'region_too_small',
      RecolorBlocker.noSegmentation => 'no_mask',
    };

/// 2nd-largest / largest person component at or above this ratio = a second
/// person (SECOND_PERSON_MIN_RATIO; VERIFIED margin in Python: two-person
/// photo 0.29, single-person photos <= 0.09).
const double kSecondPersonMinRatio = 0.15;

/// Closing radius bridging 1-px gaps in the person mask (PERSON_CLOSE_PX).
const int kPersonClosePx = 2;

/// Frame median L* below this = a dim frame (POOR_LIGHT_FRAME_MEDIAN_L).
const double kPoorLightFrameMedianL = 20.0;

/// Person 90th-percentile L* below this = no highlights
/// (POOR_LIGHT_PERSON_P90_L)…
const double kPoorLightPersonP90L = 45.0;

/// …which only counts in a scene whose median is below this
/// (POOR_LIGHT_DIM_SCENE_MEDIAN_L): dark garments / dark skin in a lit room
/// must not be flagged (PRD §9 bias).
const double kPoorLightDimSceneMedianL = 40.0;

/// Minimum hardened un-eroded region, fraction of the frame
/// (RECOLOR_MIN_REGION_FRACTION).
const double kRecolorMinRegionFraction = 0.02;

/// Raw-mask reliability: enclosed holes above this fraction of the clothes
/// area = swiss cheese (MASK_HOLE_MAX).
const double kMaskHoleMax = 0.10;

/// Speckle components above this fraction (MASK_SPECKLE_MAX).
const double kMaskSpeckleMax = 0.05;

/// Detached components above this fraction (MASK_DETACHED_MAX).
const double kMaskDetachedMax = 0.25;

/// Result of [checkRecolorApplicability] (Python `Applicability`).
class RecolorApplicability {
  /// Creates a verdict.
  const RecolorApplicability({
    required this.reason,
    required this.regions,
    required this.metrics,
  });

  /// Null = applicable; else the first rule that fired.
  final RecolorBlocker? reason;

  /// Per region: null = usable, [RecolorBlocker.regionTooSmall] = not.
  /// Empty when no regions were given.
  final Map<GarmentRegion, RecolorBlocker?> regions;

  /// Every statistic the rules looked at (Python metric names), for tuning.
  final Map<String, double> metrics;

  /// True when no photo-level rule fired.
  bool get applicable => reason == null;

  /// The regions the UI may offer, upper first (none when not applicable).
  List<GarmentRegion> get qualifyingRegions => <GarmentRegion>[
        if (applicable)
          for (final GarmentRegion region in <GarmentRegion>[
            GarmentRegion.upper,
            GarmentRegion.lower
          ])
            if (regions.containsKey(region) && regions[region] == null) region,
      ];
}

Uint8List _personMask(Uint8List classMap) {
  final Uint8List person = Uint8List(classMap.length);
  for (int i = 0; i < classMap.length; i++) {
    final int c = classMap[i];
    if (c == SegClass.clothes ||
        c == SegClass.hair ||
        c == SegClass.bodySkin ||
        c == SegClass.faceSkin) {
      person[i] = 1;
    }
  }
  return person;
}

/// Area of the 2nd-largest person component / the largest (0 = one person)
/// — `person_component_ratio`.
double personComponentRatio(Uint8List classMap, int width, int height) {
  final Uint8List person = _personMask(classMap);
  final Uint8List closed = erodeMask(
      dilateMask(person, width, height, kPersonClosePx),
      width,
      height,
      kPersonClosePx);
  final Components cc =
      labelComponents(closed, width, height, eightConnected: true);
  if (cc.count <= 1) return 0.0;
  final List<int> areas = cc.areas.toList()..sort((int a, int b) => b - a);
  return areas[1] / areas[0];
}

/// hole / speckle / detached fractions of the RAW clothes class —
/// `mask_reliability_metrics`.
Map<String, double> maskReliabilityMetrics(
    Uint8List classMap, int width, int height) {
  final Uint8List clothes = Uint8List(classMap.length);
  for (int i = 0; i < classMap.length; i++) {
    if (classMap[i] == SegClass.clothes) clothes[i] = 1;
  }
  final int area = maskPixelCount(clothes);
  if (area == 0) {
    return <String, double>{
      'hole_fraction': 0.0,
      'speckle_fraction': 0.0,
      'detached_fraction': 0.0,
    };
  }
  final Uint8List filled =
      fillClothesHoles(classMap, width, height, maxFraction: 1.0);
  final Uint8List kept =
      dropDetachedClothes(classMap, width, height, speckleMinFraction: 0.0);
  final Components cc =
      labelComponents(clothes, width, height, eightConnected: true);
  int speckle = 0;
  for (int k = 0; k < cc.count; k++) {
    if (cc.areas[k] < kSpeckleMinFraction * area) speckle += cc.areas[k];
  }
  int holes = 0, detached = 0;
  for (int i = 0; i < clothes.length; i++) {
    if (filled[i] != 0 && clothes[i] == 0) holes++;
    if (clothes[i] != 0 && kept[i] == 0) detached++;
  }
  return <String, double>{
    'hole_fraction': holes / area,
    'speckle_fraction': speckle / area,
    'detached_fraction': detached / area,
  };
}

/// numpy `percentile(values, q)` with the default linear interpolation, on
/// an already SORTED list.
double _percentileSorted(Float64List sorted, double q) {
  final double pos = (sorted.length - 1) * q / 100.0;
  final int lo = pos.floor();
  final int hi = pos.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// Is a per-region recolor applicable to this photo (`check_applicability`)?
///
/// [classMap] is the RAW (un-hardened) class map at the photo size
/// (`width * height`), [rgba] the photo (null skips the light rule) and
/// [regions] the HARDENED, UN-eroded region masks (null skips the size
/// rule). Pure statistics; never throws on a valid map.
RecolorApplicability checkRecolorApplicability(
  Uint8List classMap,
  int width,
  int height, {
  Uint8List? rgba,
  Map<GarmentRegion, Uint8List>? regions,
}) {
  if (classMap.length != width * height) {
    throw ArgumentError(
        'class map length ${classMap.length} != $width*$height');
  }
  final Map<String, double> metrics = <String, double>{};
  RecolorBlocker? reason;

  final double ratio = personComponentRatio(classMap, width, height);
  metrics['person_component_ratio'] = ratio;
  if (ratio >= kSecondPersonMinRatio) reason = RecolorBlocker.severalPeople;

  if (rgba != null) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError('rgba length ${rgba.length} != $width*$height*4');
    }
    final int n = width * height;
    final Float64List all = Float64List(n);
    final Float64List lab = Float64List(3);
    int personCount = 0;
    for (int i = 0; i < n; i++) {
      final int c = classMap[i];
      if (c == SegClass.clothes ||
          c == SegClass.hair ||
          c == SegClass.bodySkin ||
          c == SegClass.faceSkin) {
        personCount++;
      }
    }
    final Float64List person = Float64List(personCount);
    int p = 0;
    for (int i = 0; i < n; i++) {
      OpenCvLab.rgb8ToLab(
          rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2], lab, 0);
      all[i] = lab[0];
      final int c = classMap[i];
      if (c == SegClass.clothes ||
          c == SegClass.hair ||
          c == SegClass.bodySkin ||
          c == SegClass.faceSkin) {
        person[p++] = lab[0];
      }
    }
    all.sort();
    person.sort();
    final double frameMedian = _percentileSorted(all, 50);
    final double personP90 =
        personCount > 0 ? _percentileSorted(person, 90) : 0.0;
    metrics['frame_median_l'] = frameMedian;
    metrics['person_p90_l'] = personP90;
    final bool dimPerson = personP90 < kPoorLightPersonP90L &&
        frameMedian < kPoorLightDimSceneMedianL;
    if (reason == null && (frameMedian < kPoorLightFrameMedianL || dimPerson)) {
      reason = RecolorBlocker.poorLight;
    }
  }

  final Map<String, double> reliability =
      maskReliabilityMetrics(classMap, width, height);
  metrics.addAll(reliability);
  if (reason == null &&
      (reliability['hole_fraction']! > kMaskHoleMax ||
          reliability['speckle_fraction']! > kMaskSpeckleMax ||
          reliability['detached_fraction']! > kMaskDetachedMax)) {
    reason = RecolorBlocker.maskUnreliable;
  }

  final Map<GarmentRegion, RecolorBlocker?> status =
      <GarmentRegion, RecolorBlocker?>{};
  if (regions != null) {
    final int n = width * height;
    for (final MapEntry<GarmentRegion, Uint8List> entry in regions.entries) {
      final double fraction = maskPixelCount(entry.value) / n;
      metrics['${entry.key.name}_fraction'] = fraction;
      status[entry.key] = fraction >= kRecolorMinRegionFraction
          ? null
          : RecolorBlocker.regionTooSmall;
    }
    if (reason == null &&
        regions.isNotEmpty &&
        status.values.every((RecolorBlocker? s) => s != null)) {
      reason = RecolorBlocker.regionTooSmall;
    }
  }
  return RecolorApplicability(
      reason: reason, regions: status, metrics: metrics);
}
