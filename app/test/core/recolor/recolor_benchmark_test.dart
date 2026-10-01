import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/recolor/recolor_service.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';

import 'recolor_scene.dart';

/// I2 (D38) timing on the HOST (`flutter test`, Dart JIT on the dev PC).
/// It prints the numbers for the pass-1 report and only fails on a gross
/// regression (a generous bound, so CI noise never flakes it). The device
/// number (M33, AOT) is a HYPOTHESIS until the pass-2 on-device check.

const int _runs = 5;

int _medianMs(void Function() body) {
  body(); // warm-up (JIT)
  final List<int> laps = <int>[];
  for (int i = 0; i < _runs; i++) {
    final Stopwatch sw = Stopwatch()..start();
    body();
    laps.add(sw.elapsedMilliseconds);
  }
  laps.sort();
  return laps[_runs ~/ 2];
}

void main() {
  final SegmentationClassMap map = SegmentationClassMap(
    width: 256,
    height: 256,
    classes: sceneModelMap(),
    frameWidth: 384,
    frameHeight: 512,
  );
  const List<GarmentRegion> both = <GarmentRegion>[
    GarmentRegion.upper,
    GarmentRegion.lower
  ];
  const List<int> teal = <int>[38, 160, 150];

  test('assess (384x512) and render (story 779x1038 / fallback 384x512)', () {
    final Uint8List frame = scenePhotoRgba(384, 512);
    final int assessMs = _medianMs(() => assessRecolor(map, frame, 384, 512));

    final Map<GarmentRegion, List<int>> sources =
        assessRecolor(map, frame, 384, 512).sources;
    final Uint8List story = scenePhotoRgba(779, 1038);
    final int storyMs = _medianMs(
        () => renderRecolorRegions(map, story, 779, 1038, both, teal, sources));
    final int smallMs = _medianMs(
        () => renderRecolorRegions(map, frame, 384, 512, both, teal, sources));

    // ignore: avoid_print
    print('RECOLOR BENCH (host JIT, median of $_runs): assess 384x512 '
        '${assessMs}ms | render both regions 779x1038 ${storyMs}ms | '
        'render both regions 384x512 ${smallMs}ms');
    expect(assessMs, lessThan(5000));
    expect(storyMs, lessThan(10000));
  });
}
