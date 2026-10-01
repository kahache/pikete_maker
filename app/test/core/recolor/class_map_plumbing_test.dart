import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/color_engine_dart.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/mediapipe_garment_segmenter.dart';

import 'recolor_scene.dart';

/// I2 (D38) plumbing: the model class map survives the analysis (memory
/// only) so the recolor can rebuild smooth masks — and carrying it changes
/// NOTHING in the masks or the palette.

/// One-hot scores of the synthetic scene's 256 map (top-level: it runs in
/// the segmenter's worker isolate).
Float32List _sceneInference(int address, Float32List input) {
  final Uint8List map = sceneModelMap();
  final Float32List scores = Float32List(map.length * 6);
  for (int i = 0; i < map.length; i++) {
    scores[i * 6 + map[i]] = 1;
  }
  return scores;
}

class _FixedSegmenter implements GarmentSegmenter {
  _FixedSegmenter({required this.keepClassMap});

  final bool keepClassMap;

  @override
  Future<GarmentSegmentation> segment(
      Uint8List rgba, int width, int height) async {
    final GarmentSegmentation seg = MediaPipeGarmentSegmenter.segmentFrame(
        rgba, width, height, 0, _sceneInference);
    return keepClassMap
        ? seg
        : GarmentSegmentation(width: width, height: height, masks: seg.masks);
  }
}

void main() {
  test('segmentFrame keeps the 256 map; masks identical to the old path', () {
    final Uint8List rgba = scenePhotoRgba(384, 512);
    final GarmentSegmentation seg = MediaPipeGarmentSegmenter.segmentFrame(
        rgba, 384, 512, 0, _sceneInference);
    final SegmentationClassMap map = seg.classMap!;
    expect((map.width, map.height), (256, 256));
    expect((map.frameWidth, map.frameHeight), (384, 512));
    expect(map.classes, sceneModelMap());

    // The pre-I2 composition: buildMasks(classifyFrame(...)).
    final GarmentSegmentation old = MediaPipeGarmentSegmenter.buildMasks(
        MediaPipeGarmentSegmenter.classifyFrame(
            rgba, 384, 512, 0, _sceneInference),
        384,
        512);
    expect(seg.masks.keys, old.masks.keys);
    for (final GarmentRegion r in old.masks.keys) {
      expect(seg.masks[r], old.masks[r], reason: 'mask $r byte-identical');
    }
  });

  test('the engine attaches the class map; the palette is unchanged', () async {
    final Uint8List png = await encodePng(scenePhotoRgba(384, 512), 384, 512);
    final AnalysisResult withMap = await ColorEngineDart(
      segmenter: _FixedSegmenter(keepClassMap: true),
      garmentAnalysis: true,
    ).analyze(png);
    final AnalysisResult without = await ColorEngineDart(
      segmenter: _FixedSegmenter(keepClassMap: false),
      garmentAnalysis: true,
    ).analyze(png);

    expect(withMap.segmentationClassMap, isNotNull);
    expect(withMap.segmentationClassMap!.classes, sceneModelMap());
    expect(without.segmentationClassMap, isNull);

    expect(withMap.baseIndex, without.baseIndex);
    expect(withMap.segmentationLayout, without.segmentationLayout);
    expect(withMap.palette.length, without.palette.length);
    for (int i = 0; i < withMap.palette.length; i++) {
      expect(withMap.palette[i].color, without.palette[i].color);
      expect(withMap.palette[i].weight, without.palette[i].weight);
    }
    expect(withMap.garments.length, without.garments.length);
    expect(withMap.swatchRegions, without.swatchRegions);
  });

  test('withSegmentationClassMap copies every other field', () {
    const AnalysisResult base = AnalysisResult(
      palette: <ColorSample>[],
      baseIndex: -1,
      harmonies: <Harmony>[],
      segmentationLayout: SegmentationLayouts.single,
      segmentationDegradeReason: SegmentationDegradeReasons.regionTooSmall,
    );
    final SegmentationClassMap map = SegmentationClassMap(
        width: 1,
        height: 1,
        classes: Uint8List(1),
        frameWidth: 1,
        frameHeight: 1);
    final AnalysisResult copy = base.withSegmentationClassMap(map);
    expect(copy.segmentationClassMap, same(map));
    expect(copy.baseIndex, base.baseIndex);
    expect(copy.segmentationLayout, base.segmentationLayout);
    expect(copy.segmentationDegradeReason, base.segmentationDegradeReason);
    expect(copy.canvasAccents, same(base.canvasAccents));
    expect(copy.garments, same(base.garments));
    expect(copy.swatchRegions, same(base.swatchRegions));
  });
}
