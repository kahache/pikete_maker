import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/color_engine/garments.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';

/// End-to-end gating of the Phase 2.5 per-garment engine path (#88/#89):
///
///  1. `garmentAnalysis: true` + a segmenter emitting upper/lower masks →
///     a result WITH garment blocks (layout `garments`).
///  2. Any [SegmentationException] → SILENT whole-photo degrade whose
///     palette is IDENTICAL to the default (flag-off) engine on the same
///     bytes — the S4 "pixel-identical" guarantee — tagged for telemetry.
///  3. The min-region guard → single-block result (S3) with its reason.
///  4. Flag OFF (default): no segmentation metadata at all, byte-identical
///     behavior (the beta posture, #87).

const ui.Color _wall = ui.Color(0xFFCDCDCD);
const ui.Color _green = ui.Color(0xFF3C8C3C);
const ui.Color _purple = ui.Color(0xFF9B59D0);

const int _side = 60;

/// 60×60 PNG: green "upper garment" band + purple "lower garment" band on a
/// gray wall, no antialiasing (same technique as the product-mode test).
Future<Uint8List> _outfitPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..isAntiAlias = false;
  paint.color = _wall;
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 60, 60), paint);
  paint.color = _green;
  canvas.drawRect(const ui.Rect.fromLTWH(10, 10, 40, 20), paint);
  paint.color = _purple;
  canvas.drawRect(const ui.Rect.fromLTWH(10, 32, 40, 24), paint);
  final ui.Image image = await recorder.endRecording().toImage(_side, _side);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

Uint8List _rectMask(int r0, int r1, int c0, int c1) {
  final Uint8List mask = Uint8List(_side * _side);
  for (int y = r0; y < r1; y++) {
    for (int x = c0; x < c1; x++) {
      mask[y * _side + x] = 1;
    }
  }
  return mask;
}

/// Emits fixed upper/lower masks matching the painted garment bands.
class _TwoGarmentSegmenter implements GarmentSegmenter {
  const _TwoGarmentSegmenter({this.tinyLower = false});

  /// When true, the lower mask is a sliver the min-region guard must drop.
  final bool tinyLower;

  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    return GarmentSegmentation(
      width: width,
      height: height,
      masks: <GarmentRegion, Uint8List>{
        GarmentRegion.upper: _rectMask(10, 30, 10, 50),
        GarmentRegion.lower: tinyLower
            ? _rectMask(40, 46, 26, 34) // 6×8 → 8 px post-erosion < 0.5%
            : _rectMask(32, 56, 10, 50),
      },
    );
  }
}

/// Fails with an UNTYPED error (anything but [SegmentationException]) —
/// the r13 A1 gap: these must degrade to S4, not reach the E3 screen.
class _UntypedFailingSegmenter implements GarmentSegmenter {
  _UntypedFailingSegmenter(this.fail);

  /// Produces the failure (may itself hop through a real worker isolate).
  final Future<Never> Function() fail;
  int calls = 0;

  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    calls++;
    return fail();
  }
}

class _ThrowingSegmenter implements GarmentSegmenter {
  const _ThrowingSegmenter({required this.noPerson});
  final bool noPerson;
  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    throw SegmentationException(
      noPerson ? 'no dressed person' : 'model asset missing',
      isNoPerson: noPerson,
    );
  }
}

/// Flattened RGB `[n*3]` buffer from `(rgb, count)` runs — the shape
/// `dominantColors`/[GarmentPixels] consume. Duplicate points make the K-means
/// centroids land exactly on the input colors, so the palette is deterministic.
Float64List _pixels(List<(List<int>, int)> runs) {
  final List<double> out = <double>[];
  for (final (List<int> rgb, int count) in runs) {
    for (int i = 0; i < count; i++) {
      out
        ..add(rgb[0].toDouble())
        ..add(rgb[1].toDouble())
        ..add(rgb[2].toDouble());
    }
  }
  return Float64List.fromList(out);
}

List<String> _hexes(AnalysisResult r) =>
    <String>[for (final ColorSample s in r.palette) s.hex];

List<double> _weights(AnalysisResult r) =>
    <double>[for (final ColorSample s in r.palette) s.weight];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('garmentAnalysis flag ON', () {
    test('two masked garments → per-garment result, layout garments', () async {
      const ColorEngineDart engine = ColorEngineDart(
        segmenter: _TwoGarmentSegmenter(),
        garmentAnalysis: true,
      );
      final AnalysisResult res = await engine.analyze(await _outfitPng());

      expect(res.segmentationLayout, SegmentationLayouts.garments);
      expect(res.segmentationDegradeReason, isNull);
      expect(res.garments, hasLength(2));
      expect(res.garments[0].region, GarmentRegion.upper);
      expect(res.garments[1].region, GarmentRegion.lower);
      // Attribution: every combined swatch names its owner.
      expect(res.swatchRegions, hasLength(res.palette.length));
      // The wall gray is masked out BY CONSTRUCTION: no neutral swatch.
      for (final ColorSample s in res.palette) {
        expect(s.hex, isNot('#CDCDCD'),
            reason: 'wall pixels must never be sampled on the mask path');
      }
      // Both garments are chromatic solids → each block has a base.
      for (final GarmentBlockData block in res.garments) {
        expect(block.isCanvas, isFalse);
        expect(block.palette, isNotEmpty);
      }
      // Global base is owned by exactly one block.
      expect(res.baseBlock, isNotNull);
      expect(res.harmonies, hasLength(4));
    });

    test('min-region guard → single block (S3), reason region_too_small',
        () async {
      const ColorEngineDart engine = ColorEngineDart(
        segmenter: _TwoGarmentSegmenter(tinyLower: true),
        garmentAnalysis: true,
      );
      final AnalysisResult res = await engine.analyze(await _outfitPng());

      expect(res.segmentationLayout, SegmentationLayouts.single);
      expect(res.segmentationDegradeReason,
          SegmentationDegradeReasons.regionTooSmall);
      expect(res.garments, hasLength(1));
      expect(res.garments.single.region, GarmentRegion.upper);
    });

    test(
        'segmenter failure → whole-photo degrade IDENTICAL to the default '
        'engine, tagged model_failed', () async {
      final Uint8List photo = await _outfitPng();
      const ColorEngineDart flagOn = ColorEngineDart(
        segmenter: _ThrowingSegmenter(noPerson: false),
        garmentAnalysis: true,
      );
      const ColorEngineDart flagOff = ColorEngineDart();

      final AnalysisResult degraded = await flagOn.analyze(photo);
      final AnalysisResult baseline = await flagOff.analyze(photo);

      // S4 guarantee: the palette/base/harmonies are the flag-off output.
      expect(_hexes(degraded), _hexes(baseline));
      expect(_weights(degraded), _weights(baseline));
      expect(degraded.baseIndex, baseline.baseIndex);
      expect(degraded.garments, isEmpty);
      // Only the telemetry tags differ.
      expect(degraded.segmentationLayout, SegmentationLayouts.whole);
      expect(degraded.segmentationDegradeReason,
          SegmentationDegradeReasons.modelFailed);
    });

    test('no-person → whole-photo degrade tagged no_person', () async {
      const ColorEngineDart engine = ColorEngineDart(
        segmenter: _ThrowingSegmenter(noPerson: true),
        garmentAnalysis: true,
      );
      final AnalysisResult res = await engine.analyze(await _outfitPng());
      expect(res.segmentationLayout, SegmentationLayouts.whole);
      expect(
          res.segmentationDegradeReason, SegmentationDegradeReasons.noPerson);
      expect(res.garments, isEmpty);
    });
  });

  group('untyped segmentation failure → S4 whole-photo degrade (r13)', () {
    final Map<String, Future<Never> Function()> failures =
        <String, Future<Never> Function()>{
      'RemoteError': () async => throw RemoteError('worker died', ''),
      'IsolateSpawnException': () async =>
          throw IsolateSpawnException('cannot spawn'),
      'StateError from a real worker isolate': () =>
          Isolate.run<Never>(() => throw StateError('mask building blew up')),
      'ArgumentError': () async => throw ArgumentError('bad tensor'),
    };
    for (final MapEntry<String, Future<Never> Function()> failure
        in failures.entries) {
      test('${failure.key} → whole-photo result IDENTICAL to the flag-off '
          'engine, tagged model_failed', () async {
        final Uint8List photo = await _outfitPng();
        final _UntypedFailingSegmenter segmenter =
            _UntypedFailingSegmenter(failure.value);
        final AnalysisResult degraded = await ColorEngineDart(
          segmenter: segmenter,
          garmentAnalysis: true,
        ).analyze(photo);
        final AnalysisResult baseline =
            await const ColorEngineDart().analyze(photo);

        expect(segmenter.calls, 1);
        expect(_hexes(degraded), _hexes(baseline));
        expect(_weights(degraded), _weights(baseline));
        expect(degraded.baseIndex, baseline.baseIndex);
        expect(degraded.garments, isEmpty);
        expect(degraded.segmentationLayout, SegmentationLayouts.whole);
        expect(degraded.segmentationDegradeReason,
            SegmentationDegradeReasons.modelFailed);
      });
    }
  });

  group('whole-photo engine errors still propagate (→ E3)', () {
    test('undecodable bytes throw, the segmenter is never reached', () async {
      final _UntypedFailingSegmenter segmenter = _UntypedFailingSegmenter(
          () async => throw StateError('must not run'));
      await expectLater(
        ColorEngineDart(segmenter: segmenter, garmentAnalysis: true)
            .analyze(Uint8List.fromList(<int>[1, 2, 3, 4])),
        throwsA(isA<ColorEngineException>()),
      );
      expect(segmenter.calls, 0);
    });

    test('a fully transparent photo is still E4 (isNoOutfit), not degraded',
        () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder); // nothing drawn: every pixel transparent
      final ui.Image image = await recorder.endRecording().toImage(40, 40);
      final ByteData? png =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final _UntypedFailingSegmenter segmenter = _UntypedFailingSegmenter(
          () async => throw StateError('must not run'));
      await expectLater(
        ColorEngineDart(segmenter: segmenter, garmentAnalysis: true)
            .analyze(png!.buffer.asUint8List()),
        throwsA(isA<ColorEngineException>().having(
            (ColorEngineException e) => e.isNoOutfit, 'isNoOutfit', isTrue)),
      );
      expect(segmenter.calls, 0);
    });

    test('the engine\'s typed ColorEngineException is never swallowed',
        () async {
      final _UntypedFailingSegmenter segmenter = _UntypedFailingSegmenter(
          () async =>
              throw const ColorEngineException('palette extraction failed'));
      await expectLater(
        ColorEngineDart(segmenter: segmenter, garmentAnalysis: true)
            .analyze(await _outfitPng()),
        throwsA(isA<ColorEngineException>()),
      );
    });
  });

  test('flag OFF (default): no segmentation metadata, blocks empty', () async {
    const ColorEngineDart engine = ColorEngineDart();
    final AnalysisResult res = await engine.analyze(await _outfitPng());
    expect(res.segmentationLayout, isNull);
    expect(res.segmentationDegradeReason, isNull);
    expect(res.garments, isEmpty);
    expect(res.swatchRegions, isEmpty);
  });

  // Bug B-G25-1 (gate G2.5 FAIL→PASS): the per-garment DISPLAY base must be the
  // garment's OWN dominant colour, not the most-chromatic swatch. The solid
  // fixtures can't distinguish the two rules (single-colour garments) — these
  // pin the divergence directly on buildGarmentAnalysis with a multi-colour
  // garment. Mirrors pipeline.py `harm if harm < 0 else int(np.argmax(weights))`.
  group('B-G25-1 per-garment display base', () {
    test(
        'dominant neutral + minority chromatic contaminant → block base is '
        'the dominant neutral; combined harmony base stays most-chromatic', () {
      // Grey garment (dominant, neutral) with a red edge-bleed contaminant
      // (minority, chromatic, above the #57 pop-on-neutral floor of 0.10).
      final GarmentPixels garment = GarmentPixels(
        region: GarmentRegion.upper,
        pixels: _pixels(<(List<int>, int)>[
          (<int>[107, 106, 117], 800), // dominant neutral grey  → #6B6A75
          (<int>[208, 52, 44], 200), //  minority chromatic red → #D0342C
        ]),
        pixelFraction: 0.5,
      );
      final AnalysisResult res = buildGarmentAnalysis(<GarmentPixels>[garment]);
      final GarmentBlockData block = res.garments.single;

      // The block palette is grey (dominant) then red.
      expect(block.palette.map((ColorSample s) => s.hex).toList(),
          <String>['#6B6A75', '#D0342C']);
      // FIX: per-garment display base = the dominant grey (argmax weight),
      // NOT the red contaminant the old most-chromatic rule would have chosen.
      expect(block.baseIndex, 0, reason: 'per-garment display base (B-G25-1)');
      expect(block.palette[block.baseIndex].hex, '#6B6A75');
      // UNCHANGED: the combined/harmony base (rule #6) still leads with the
      // most-chromatic colour — the red.
      expect(res.baseIndex, isNonNegative);
      expect(res.base!.hex, '#D0342C',
          reason: 'combined harmony base must stay most-chromatic');
    });

    test('all-neutral garment keeps the -1 canvas sentinel', () {
      final GarmentPixels garment = GarmentPixels(
        region: GarmentRegion.upper,
        pixels: _pixels(<(List<int>, int)>[
          (<int>[107, 106, 117], 600), // grey       → neutral
          (<int>[35, 33, 40], 400), //    near-black → neutral
        ]),
        pixelFraction: 0.5,
      );
      final AnalysisResult res = buildGarmentAnalysis(<GarmentPixels>[garment]);
      final GarmentBlockData block = res.garments.single;

      // No chromatic colour → pickHarmonyBase returns -1 → the fix KEEPS -1
      // (the U7 "neutro — combina con todo" caption / canvas signal).
      expect(block.baseIndex, -1, reason: 'canvas sentinel preserved');
      expect(block.isCanvas, isTrue);
      // A fully-neutral single-region outfit → global canvas mode (D10).
      expect(res.baseIndex, -1);
      expect(res.canvasAccents, hasLength(5));
    });
  });
}
