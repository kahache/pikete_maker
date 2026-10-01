import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/color_engine/garments.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mask_hygiene.dart';
import 'package:piketemaker/core/segmentation/mediapipe_garment_segmenter.dart';

/// PYTHON PARITY for the Phase 2.5 per-garment analysis layer (#89).
///
/// Replays, per fixture case, the EXACT on-device composition the engine runs
/// on the segmented path:
///
///   synthetic class map → [MediaPipeGarmentSegmenter.buildMasks] (spike
///   coverage check + bbox mid-row split) → [applyGarmentGuards] (#89
///   erosion 5×5 + min-region guard) → [extractRgbaPixels] per region →
///   [buildGarmentAnalysis] (per-garment K-means, combined palette, global
///   base)
///
/// and compares against the output of the CANONICAL
/// `colorlab.pipeline.analyze_garments` baked into
/// `garment_analysis_F25.json` by `cv_core/tools/gen_garment_fixtures_dart.py`
/// — same RGB/weight tolerance philosophy as the product-mode fixtures.
/// Mask-stage diagnostics (surviving regions + eroded pixel counts) are
/// compared EXACTLY: the split and the erosion are integer-deterministic, so
/// any drift there is a real parity break.
///
/// Fixture file name and JSON keys are FROZEN (generated from Python): do not
/// rename them here.

Map<String, dynamic> _load(String name) {
  final File file = File('test/core/fixtures/$name');
  if (!file.existsSync()) {
    fail('$name does not exist. Regenerate with: '
        '.venv/Scripts/python.exe cv_core/tools/gen_garment_fixtures_dart.py '
        '(from the repo root).');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Opaque RGBA buffer from the fixture's [r, g, b] triplets.
Uint8List _rgba(List<dynamic> pixels) {
  final Uint8List out = Uint8List(pixels.length * 4);
  for (int i = 0; i < pixels.length; i++) {
    final List<dynamic> px = pixels[i] as List<dynamic>;
    for (int d = 0; d < 3; d++) {
      out[i * 4 + d] = (px[d] as num).toInt();
    }
    out[i * 4 + 3] = 0xFF;
  }
  return out;
}

Uint8List _classMap(List<dynamic> values) => Uint8List.fromList(
    <int>[for (final dynamic v in values) (v as num).toInt()]);

List<int> _rgb(dynamic value) =>
    <int>[for (final dynamic c in value as List<dynamic>) (c as num).toInt()];

List<int> _channels(ui.Color color) {
  // ignore: deprecated_member_use  (Color.value: universal across Flutter 3.19+)
  final int value = color.value;
  return <int>[(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
}

const Map<String, GarmentRegion> _regionByName = <String, GarmentRegion>{
  'upper': GarmentRegion.upper,
  'lower': GarmentRegion.lower,
};

/// The full segmented composition the engine runs (minus the codec/isolate):
/// spike split → #89 guards → per-region extraction → per-garment analysis.
AnalysisResult _replay(
    Uint8List rgba, Uint8List classMap, int width, int height) {
  final GarmentSegmentation split =
      MediaPipeGarmentSegmenter.buildMasks(classMap, width, height);
  final GarmentSegmentation guarded = applyGarmentGuards(split);
  final int frame = width * height;
  final List<GarmentPixels> regions = <GarmentPixels>[
    for (final GarmentRegion region in <GarmentRegion>[
      GarmentRegion.upper,
      GarmentRegion.lower
    ])
      if (guarded.maskFor(region) != null)
        GarmentPixels(
          region: region,
          pixels: extractRgbaPixels(rgba, mask: guarded.maskFor(region)),
          pixelFraction: maskPixelCount(guarded.maskFor(region)!) / frame,
        ),
  ];
  return buildGarmentAnalysis(regions);
}

void _expectPalette(
  List<ColorSample> got,
  List<dynamic> expectedColors,
  List<dynamic> expectedWeights,
  double atolRgb,
  double atolWeight,
  String label,
) {
  expect(got.length, expectedColors.length,
      reason: '$label: color count differs from Python: '
          '${got.map((ColorSample s) => s.hex).toList()} vs $expectedColors');
  for (int i = 0; i < expectedColors.length; i++) {
    final List<int> expectedRgb = _rgb(expectedColors[i]);
    final List<int> gotRgb = _channels(got[i].color);
    for (int d = 0; d < 3; d++) {
      expect(gotRgb[d], closeTo(expectedRgb[d], atolRgb),
          reason: '$label color $i: $gotRgb vs $expectedRgb');
    }
    expect(got[i].weight,
        closeTo((expectedWeights[i] as num).toDouble(), atolWeight),
        reason: '$label weight $i');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('per-garment parity with colorlab (F2.5, #89)', () {
    final Map<String, dynamic> f = _load('garment_analysis_F25.json');
    for (final dynamic caseDyn in f['cases'] as List<dynamic>) {
      final Map<String, dynamic> c = caseDyn as Map<String, dynamic>;
      test(c['nombre'] as String, () {
        final int height = c['height'] as int;
        final int width = c['width'] as int;
        final Uint8List rgba = _rgba(c['pixeles'] as List<dynamic>);
        final Uint8List classMap = _classMap(c['mapa_clases'] as List<dynamic>);

        if (c['espera_no_person'] as bool) {
          // Both loud-degrade paths (coverage check in the spike split, or the
          // #89 guards killing every region) surface as isNoPerson — the
          // engine's S4 whole-photo fallback trigger.
          expect(
            () => _replay(rgba, classMap, width, height),
            throwsA(isA<SegmentationException>().having(
                (SegmentationException e) => e.isNoPerson,
                'isNoPerson',
                isTrue)),
          );
          return;
        }

        final double atolRgb = (c['atol_rgb'] as num).toDouble();
        final double atolWeight = (c['atol_peso'] as num).toDouble();
        final Map<String, dynamic> expected =
            c['esperado'] as Map<String, dynamic>;

        // --- Mask stage (EXACT: split + erosion are integer-deterministic).
        final GarmentSegmentation guarded = applyGarmentGuards(
            MediaPipeGarmentSegmenter.buildMasks(classMap, width, height));
        final List<String> expectedRegions = <String>[
          for (final dynamic r
              in expected['regiones_supervivientes'] as List<dynamic>)
            r as String,
        ];
        expect(
          guarded.regions.toList(),
          <GarmentRegion>[
            for (final String r in expectedRegions) _regionByName[r]!
          ],
          reason: 'surviving regions differ from Python',
        );
        final Map<String, dynamic> expectedCounts =
            expected['pixeles_region'] as Map<String, dynamic>;
        for (final String region in expectedRegions) {
          expect(
            maskPixelCount(guarded.maskFor(_regionByName[region]!)!),
            expectedCounts[region] as int,
            reason: 'eroded pixel count of $region differs from Python '
                '(erosion/border semantics parity break)',
          );
        }

        // --- Analysis stage (same tolerances as the product fixtures).
        final AnalysisResult res = _replay(rgba, classMap, width, height);

        // Per-garment blocks (weights normalized within the garment).
        final Map<String, dynamic> prendas =
            expected['prendas'] as Map<String, dynamic>;
        expect(res.garments.length, prendas.length);
        for (final GarmentBlockData block in res.garments) {
          final String name =
              block.region == GarmentRegion.upper ? 'upper' : 'lower';
          final Map<String, dynamic> g = prendas[name] as Map<String, dynamic>;
          _expectPalette(
            block.palette,
            g['colores'] as List<dynamic>,
            g['pesos'] as List<dynamic>,
            atolRgb,
            atolWeight,
            'garment $name',
          );
          expect(block.baseIndex, g['indice_base'] as int,
              reason: 'per-garment base index of $name (U7 canvas signal)');
          // Pixel fractions are integer counts over the frame: exact.
          final GarmentPixels replayed = GarmentPixels(
            region: block.region,
            pixels: Float64List(0),
            pixelFraction: (g['fraccion'] as num).toDouble(),
          );
          expect(
            maskPixelCount(guarded.maskFor(block.region)!) / (width * height),
            closeTo(replayed.pixelFraction, 1e-9),
            reason: 'pixel fraction of $name',
          );
        }

        // Combined outfit palette + per-swatch attribution (#89 contract).
        _expectPalette(
          res.palette,
          expected['colores'] as List<dynamic>,
          expected['pesos'] as List<dynamic>,
          atolRgb,
          atolWeight,
          'combined',
        );
        expect(
          res.swatchRegions,
          <GarmentRegion>[
            for (final dynamic r in expected['regiones'] as List<dynamic>)
              _regionByName[r as String]!,
          ],
          reason: 'swatch_regions attribution differs from Python',
        );

        // Global base across garments (decision #6 at the outfit level).
        expect(res.baseIndex, expected['indice_base'] as int,
            reason: 'global base index');
        if (res.baseIndex >= 0) {
          final List<int> expectedBase = _rgb(expected['base']);
          final List<int> gotBase = _channels(res.base!.color);
          for (int d = 0; d < 3; d++) {
            expect(gotBase[d], closeTo(expectedBase[d], atolRgb),
                reason: 'global base color: $gotBase vs $expectedBase');
          }
          final String? baseRegion = expected['region_base'] as String?;
          expect(res.baseBlock?.region, _regionByName[baseRegion!],
              reason: 'owning region of the global base (attribution line)');
          expect(
            res.baseBlock!.palette[res.baseBlock!.globalBaseIndex].color,
            res.base!.color,
            reason: 'globalBaseIndex must point at the SAME color inside the '
                'owning block (bold-hex row contract)',
          );
          // ONE harmony set from the global base (U1), same structure as the
          // whole-photo engine (the harmony arithmetic itself is pinned by
          // armonias_casos.json).
          expect(res.harmonies, hasLength(4));
          for (final Harmony h in res.harmonies) {
            expect(h.colors, contains(res.base!.color));
          }
          expect(res.canvasAccents, isEmpty);
        } else {
          // Global canvas mode (D10): every garment neutral.
          expect(expected['region_base'], isNull);
          expect(res.baseBlock, isNull);
          expect(res.harmonies, isEmpty);
          expect(res.canvasAccents, hasLength(5));
          for (final GarmentBlockData block in res.garments) {
            expect(block.isCanvas, isTrue,
                reason: 'global canvas implies every garment is canvas');
          }
        }

        // Layout/telemetry contract (spec §6).
        expect(
          res.segmentationLayout,
          res.garments.length == 1
              ? SegmentationLayouts.single
              : SegmentationLayouts.garments,
        );
        expect(
          res.segmentationDegradeReason,
          res.garments.length == 1
              ? SegmentationDegradeReasons.regionTooSmall
              : isNull,
        );
      });
    }
  });
}
