import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/color_engine/garments.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mask_hygiene.dart';
import 'package:piketemaker/core/segmentation/mediapipe_garment_segmenter.dart';

/// A4 (r13) HARD CONSTRAINT: moving the per-garment work off the UI isolate
/// must not change a single output bit.
///
/// For every case of the Python-generated `garment_analysis_F25.json` (the
/// same fixture `garment_parity_test.dart` checks against colorlab — read
/// here, never modified), the REAL engine (`ColorEngineDart.analyze`, codec +
/// worker isolates) is compared FIELD BY FIELD, with exact equality, against
/// the pre-A4 on-isolate composition replayed inline on the test isolate:
/// guards → per-region extraction → [buildGarmentAnalysis]. The no-person
/// cases must degrade exactly like the flag-off engine (S4), with the typed
/// [SegmentationException] crossing back from the worker isolate.

Map<String, dynamic> _load(String name) {
  final File file = File('test/core/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

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

/// Lossless PNG of a raw RGBA frame, so the engine can decode it.
Future<Uint8List> _png(Uint8List rgba, int width, int height) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

/// Replays the fixture's class map through the spike split, recording the
/// decoded frame the engine actually handed over.
class _FixtureSegmenter implements GarmentSegmenter {
  _FixtureSegmenter(this.classMap);

  final Uint8List classMap;
  Uint8List? seenRgba;

  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    seenRgba = Uint8List.fromList(rgba);
    return MediaPipeGarmentSegmenter.buildMasks(classMap, width, height);
  }
}

/// The PRE-A4 body of `_analyzeGarments`, verbatim, on the calling isolate.
AnalysisResult _onIsolate(Uint8List frameRgba, GarmentSegmentation seg) {
  final GarmentSegmentation guarded = applyGarmentGuards(seg);
  final int framePixels = seg.width * seg.height;
  final List<GarmentPixels> regions = <GarmentPixels>[];
  for (final GarmentRegion region in <GarmentRegion>[
    GarmentRegion.upper,
    GarmentRegion.lower
  ]) {
    final Uint8List? mask = guarded.maskFor(region);
    if (mask == null) {
      continue;
    }
    final Float64List regionPixels = extractRgbaPixels(frameRgba, mask: mask);
    if (regionPixels.isEmpty) {
      continue;
    }
    regions.add(GarmentPixels(
      region: region,
      pixels: regionPixels,
      pixelFraction: maskPixelCount(mask) / framePixels,
    ));
  }
  return buildGarmentAnalysis(regions);
}

List<int> _argb(List<ui.Color> colors) => <int>[
      // ignore: deprecated_member_use  (Color.value: universal across 3.19+)
      for (final ui.Color c in colors) c.value,
    ];

void _expectSamples(List<ColorSample> got, List<ColorSample> want, String l) {
  expect(_argb(<ui.Color>[for (final ColorSample s in got) s.color]),
      _argb(<ui.Color>[for (final ColorSample s in want) s.color]),
      reason: '$l colors');
  // Exact double equality on purpose: byte-identical, not "close".
  expect(<double>[for (final ColorSample s in got) s.weight],
      <double>[for (final ColorSample s in want) s.weight],
      reason: '$l weights');
}

/// Exact, field-by-field equality of two results.
void _expectIdentical(AnalysisResult got, AnalysisResult want) {
  _expectSamples(got.palette, want.palette, 'palette');
  expect(got.baseIndex, want.baseIndex, reason: 'baseIndex');
  expect(got.harmonies.length, want.harmonies.length);
  for (int i = 0; i < want.harmonies.length; i++) {
    expect(got.harmonies[i].type, want.harmonies[i].type);
    expect(got.harmonies[i].name, want.harmonies[i].name);
    expect(_argb(got.harmonies[i].colors), _argb(want.harmonies[i].colors),
        reason: 'harmony $i colors');
  }
  expect(_argb(got.canvasAccents), _argb(want.canvasAccents));
  expect(got.swatchRegions, want.swatchRegions);
  expect(got.segmentationLayout, want.segmentationLayout);
  expect(got.segmentationDegradeReason, want.segmentationDegradeReason);
  expect(got.garments.length, want.garments.length);
  for (int i = 0; i < want.garments.length; i++) {
    final GarmentBlockData g = got.garments[i];
    final GarmentBlockData w = want.garments[i];
    expect(g.region, w.region);
    _expectSamples(g.palette, w.palette, 'garment ${w.region}');
    expect(g.baseIndex, w.baseIndex);
    expect(g.globalBaseIndex, w.globalBaseIndex);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> f = _load('garment_analysis_F25.json');
  for (final dynamic caseDyn in f['cases'] as List<dynamic>) {
    final Map<String, dynamic> c = caseDyn as Map<String, dynamic>;
    test('off-isolate engine == on-isolate composition: ${c['nombre']}',
        () async {
      final int width = c['width'] as int;
      final int height = c['height'] as int;
      final Uint8List rgba = _rgba(c['pixeles'] as List<dynamic>);
      final Uint8List classMap = _classMap(c['mapa_clases'] as List<dynamic>);
      final Uint8List png = await _png(rgba, width, height);

      final _FixtureSegmenter segmenter = _FixtureSegmenter(classMap);
      final AnalysisResult engine = await ColorEngineDart(
        segmenter: segmenter,
        garmentAnalysis: true,
      ).analyze(png);

      // The codec round-trip is lossless: the engine saw the fixture frame.
      expect(segmenter.seenRgba, rgba);

      if (c['espera_no_person'] as bool) {
        // S4: identical to the flag-off engine, tagged no_person — whether
        // the split (segmenter, UI isolate) or the guards (worker isolate)
        // raised it.
        final AnalysisResult flagOff = await const ColorEngineDart().analyze(png);
        _expectSamples(engine.palette, flagOff.palette, 'S4 palette');
        expect(engine.baseIndex, flagOff.baseIndex);
        expect(engine.garments, isEmpty);
        expect(engine.segmentationLayout, SegmentationLayouts.whole);
        expect(engine.segmentationDegradeReason,
            SegmentationDegradeReasons.noPerson);
        return;
      }

      final GarmentSegmentation seg =
          MediaPipeGarmentSegmenter.buildMasks(classMap, width, height);
      final AnalysisResult inline = _onIsolate(rgba, seg);
      _expectIdentical(engine, inline);

      // And the extracted pure function, run explicitly in a worker isolate,
      // matches too (the exact hop the engine makes).
      final AnalysisResult worker =
          await Isolate.run(() => analyzeSegmentedFrame(rgba, seg));
      _expectIdentical(worker, inline);
    });
  }

  test('guards killing every region inside the worker → typed isNoPerson',
      () async {
    // The fixture case the #89 guards (not the coverage check) reject.
    final Map<String, dynamic> c = (f['cases'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> c) =>
            c['nombre'] == 'no_person_guards_kill_all');
    final Uint8List rgba = _rgba(c['pixeles'] as List<dynamic>);
    final GarmentSegmentation seg = MediaPipeGarmentSegmenter.buildMasks(
        _classMap(c['mapa_clases'] as List<dynamic>),
        c['width'] as int,
        c['height'] as int);
    await expectLater(
      Isolate.run(() => analyzeSegmentedFrame(rgba, seg)),
      throwsA(isA<SegmentationException>().having(
          (SegmentationException e) => e.isNoPerson, 'isNoPerson', isTrue)),
    );
  });
}
