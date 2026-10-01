import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/recolor/recolor_service.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/recolor_applicability.dart';

import 'recolor_scene.dart';

/// The pass-2 seam of I2 (D38): [RecolorService] on synthetic scenes.

const ui.Color _teal = ui.Color(0xFF26A096); // (38, 160, 150)

AnalysisResult _analysis(SegmentationClassMap? map,
    {GarmentRegion baseRegion = GarmentRegion.upper}) {
  ColorSample sample(List<int> c, double w) =>
      ColorSample(color: ui.Color.fromARGB(255, c[0], c[1], c[2]), weight: w);
  return AnalysisResult(
    palette: <ColorSample>[sample(kSceneTop, 0.6), sample(kSceneTrousers, 0.4)],
    baseIndex: 0,
    harmonies: const <Harmony>[],
    garments: <GarmentBlockData>[
      GarmentBlockData(
        region: GarmentRegion.upper,
        palette: <ColorSample>[sample(kSceneTop, 1)],
        baseIndex: 0,
        globalBaseIndex: baseRegion == GarmentRegion.upper ? 0 : -1,
      ),
      GarmentBlockData(
        region: GarmentRegion.lower,
        palette: <ColorSample>[sample(kSceneTrousers, 1)],
        baseIndex: 0,
        globalBaseIndex: baseRegion == GarmentRegion.lower ? 0 : -1,
      ),
    ],
    segmentationLayout: SegmentationLayouts.garments,
    segmentationClassMap: map,
  );
}

SegmentationClassMap _map({bool twoPeople = false}) => SegmentationClassMap(
      width: 256,
      height: 256,
      classes: sceneModelMap(twoPeople: twoPeople),
      frameWidth: 384,
      frameHeight: 512,
    );

int _dist(List<int> a, List<int> b) =>
    (a[0] - b[0]).abs() + (a[1] - b[1]).abs() + (a[2] - b[2]).abs();

List<int> _px(Uint8List rgba, int width, int x, int y) {
  final int p = (y * width + x) * 4;
  return <int>[rgba[p], rgba[p + 1], rgba[p + 2]];
}

void main() {
  late Uint8List photo; // 600 x 800 -> analysis frame 384 x 512

  setUpAll(() async {
    photo = await encodePng(scenePhotoRgba(600, 800), 600, 800);
  });

  test('no class map (S4 / flag off) -> noSegmentation, nothing to render',
      () async {
    final RecolorSession session = await const RecolorService()
        .open(photo: photo, analysis: _analysis(null), target: _teal);
    expect(session.availability.isAvailable, isFalse);
    expect(session.availability.blocker, RecolorBlocker.noSegmentation);
    expect(session.availability.regions, isEmpty);
    await expectLater(session.renderAll(), throwsA(isA<RecolorException>()));
  });

  test('one person, lit: both regions, default = the non-base region',
      () async {
    final RecolorSession session = await const RecolorService()
        .open(photo: photo, analysis: _analysis(_map()), target: _teal);
    final RecolorAvailability a = session.availability;
    expect(a.blocker, isNull, reason: '${a.metrics}');
    expect(
        a.regions, <GarmentRegion>[GarmentRegion.upper, GarmentRegion.lower]);
    expect(a.defaultRegion, GarmentRegion.lower); // base is on the top
    // Sources = each region's own dominant colour on the hardened split.
    expect(
        _dist(session.sources[GarmentRegion.upper]!, kSceneTop), lessThan(60));
    expect(_dist(session.sources[GarmentRegion.lower]!, kSceneTrousers),
        lessThan(60));
    expect(session.targetRgb, <int>[38, 160, 150]);

    final RecolorSession lowerBase = await const RecolorService().open(
        photo: photo,
        analysis: _analysis(_map(), baseRegion: GarmentRegion.lower),
        target: _teal);
    expect(lowerBase.availability.defaultRegion, GarmentRegion.upper);
  });

  test('renders both regions at the render size, other pixels untouched',
      () async {
    final RecolorSession session = await const RecolorService()
        .open(photo: photo, analysis: _analysis(_map()), target: _teal);
    final Map<GarmentRegion, RecolorFrame> frames = await session.renderAll();
    expect(
        frames.keys, <GarmentRegion>[GarmentRegion.upper, GarmentRegion.lower]);
    // 600 x 800 fits the 980 x 1038 box: never enlarged.
    final RecolorFrame upper = frames[GarmentRegion.upper]!;
    expect((upper.width, upper.height), (600, 800));
    // Middle of the top (u 0.5, v 0.35) moved to teal-ish; the wall and the
    // trousers are exactly as shot.
    final List<int> top = _px(upper.rgba, 600, 300, 280);
    expect(top[1], greaterThan(top[0]), reason: 'top recolored to teal: $top');
    expect(_px(upper.rgba, 600, 20, 400), kSceneWall);
    final RecolorFrame lower = frames[GarmentRegion.lower]!;
    final List<int> legs = _px(lower.rgba, 600, 300, 620);
    expect(legs[1], greaterThan(legs[2]), reason: 'trousers to teal: $legs');
    expect(identical(await session.render(GarmentRegion.lower), lower), isTrue,
        reason: 'cached, single-flight');
    final ui.Image image = await lower.toImage();
    expect((image.width, image.height), (600, 800));
    image.dispose();
  });

  test('the render is capped at the story photo box', () async {
    final Uint8List big =
        await encodePng(scenePhotoRgba(1200, 1600), 1200, 1600);
    final RecolorSession session = await const RecolorService()
        .open(photo: big, analysis: _analysis(_map()), target: _teal);
    final RecolorFrame f = await session.render(GarmentRegion.upper);
    expect(f.width, lessThanOrEqualTo(kRecolorRenderBox.width));
    expect(f.height, kRecolorRenderBox.height); // 3:4 -> 779 x 1038
    expect(f.width, 779);
  });

  test('two people -> severalPeople, no pill', () async {
    final Uint8List two =
        await encodePng(scenePhotoRgba(600, 800, twoPeople: true), 600, 800);
    final RecolorSession session = await const RecolorService().open(
        photo: two, analysis: _analysis(_map(twoPeople: true)), target: _teal);
    expect(session.availability.blocker, RecolorBlocker.severalPeople);
    expect(session.availability.isAvailable, isFalse);
  });

  test('a dark photo -> poorLight', () async {
    final Uint8List dark =
        await encodePng(scenePhotoRgba(600, 800, exposure: 0.1), 600, 800);
    final RecolorSession session = await const RecolorService()
        .open(photo: dark, analysis: _analysis(_map()), target: _teal);
    expect(session.availability.blocker, RecolorBlocker.poorLight);
  });

  test('a photo that is not the analysed frame is refused, typed', () async {
    final Uint8List other = await encodePng(scenePhotoRgba(800, 600), 800, 600);
    await expectLater(
        const RecolorService()
            .open(photo: other, analysis: _analysis(_map()), target: _teal),
        throwsA(isA<RecolorException>()));
  });

  test('dispose drops the frames and refuses later renders', () async {
    final RecolorSession session = await const RecolorService()
        .open(photo: photo, analysis: _analysis(_map()), target: _teal);
    final RecolorFrame f = await session.render(GarmentRegion.upper);
    session.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(f.rgba.every((int v) => v == 0), isTrue, reason: 'zero-filled');
    await expectLater(session.renderAll(), throwsA(isA<RecolorException>()));
    session.dispose(); // idempotent
  });

  group('defaultRecolorRegion', () {
    const List<GarmentRegion> both = <GarmentRegion>[
      GarmentRegion.upper,
      GarmentRegion.lower
    ];
    test('the region that is NOT the base', () {
      expect(
          defaultRecolorRegion(both, GarmentRegion.upper), GarmentRegion.lower);
      expect(
          defaultRecolorRegion(both, GarmentRegion.lower), GarmentRegion.upper);
    });
    test('canvas mode (no base) -> the first region', () {
      expect(defaultRecolorRegion(both, null), GarmentRegion.upper);
    });
    test('one region -> that region, even if it holds the base', () {
      expect(
          defaultRecolorRegion(
              <GarmentRegion>[GarmentRegion.lower], GarmentRegion.lower),
          GarmentRegion.lower);
      expect(defaultRecolorRegion(<GarmentRegion>[], null), isNull);
    });
  });
}
