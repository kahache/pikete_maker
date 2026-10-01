import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/core/recolor/recolor_service.dart';
import 'package:piketemaker/core/segmentation/garment_segmenter.dart';
import 'package:piketemaker/core/segmentation/recolor_applicability.dart';

/// Shared fixtures of the I2 recolor widget tests (not a test file).
/// PRIVACY: every image here is a synthetic solid colour drawn at test time.

const Color kRust = Color(0xFFC4562B);
const Color kDenim = Color(0xFF2B6CC4);
const Color kOffWhite = Color(0xFFEDEAE4);
const Color kOlive = Color(0xFF6B7A2B);
const Color kPlum = Color(0xFF8A2B6C);
const Color kMustard = Color(0xFFD9A21E);

/// Colours of the fake bitmaps (far from the band / logo colours).
const Color kOriginalInk = Color(0xFF808080);
const Color kUpperInk = Color(0xFF00C800); // "recolored ARRIBA"
const Color kLowerInk = Color(0xFFC800C8); // "recolored ABAJO"

/// A 3:4 frame map (the class ids do not matter: the opener is faked).
final SegmentationClassMap kFakeClassMap = SegmentationClassMap(
  width: 4,
  height: 4,
  classes: Uint8List(16),
  frameWidth: 384,
  frameHeight: 512,
);

/// The D36 outfit of the story tests: rust trousers (the BASE, lower) + an
/// off-white top; the hero recommends denim.
AnalysisResult outfitResult({SegmentationClassMap? map, bool legacy = false}) =>
    AnalysisResult(
      baseIndex: 0,
      palette: const <ColorSample>[
        ColorSample(color: kRust, weight: 0.55),
        ColorSample(color: kOffWhite, weight: 0.45),
      ],
      swatchRegions: const <GarmentRegion>[
        GarmentRegion.lower,
        GarmentRegion.upper
      ],
      harmonies: const <Harmony>[
        Harmony(
          type: HarmonyType.complementary,
          name: 'Complementario',
          description: 'Contraste máximo, 2 colores',
          colors: <Color>[kRust, kDenim],
        ),
        Harmony(
          type: HarmonyType.analogous,
          name: 'Análogo',
          description: 'Vecinos de rueda, suave',
          colors: <Color>[kRust, kMustard, kPlum],
        ),
        Harmony(
          type: HarmonyType.triadic,
          name: 'Triádico',
          description: '3 colores, atrevida',
          colors: <Color>[kRust, kOlive, kDenim],
        ),
      ],
      garments: const <GarmentBlockData>[
        GarmentBlockData(
          region: GarmentRegion.upper,
          palette: <ColorSample>[ColorSample(color: kOffWhite, weight: 1.0)],
          baseIndex: -1,
          globalBaseIndex: -1,
        ),
        GarmentBlockData(
          region: GarmentRegion.lower,
          palette: <ColorSample>[ColorSample(color: kRust, weight: 1.0)],
          baseIndex: 0,
          globalBaseIndex: 0,
        ),
      ],
      segmentationLayout: legacy ? null : SegmentationLayouts.garments,
      segmentationClassMap: map,
    );

/// An all-neutral (canvas mode, D10) outfit with three curated pops.
AnalysisResult canvasResult({SegmentationClassMap? map}) => AnalysisResult(
      baseIndex: -1,
      palette: const <ColorSample>[
        ColorSample(color: Color(0xFF222222), weight: 0.6),
        ColorSample(color: Color(0xFFEEEEEE), weight: 0.4),
      ],
      harmonies: const <Harmony>[],
      canvasAccents: const <Color>[kMustard, kPlum, kOlive],
      garments: const <GarmentBlockData>[
        GarmentBlockData(
          region: GarmentRegion.upper,
          palette: <ColorSample>[
            ColorSample(color: Color(0xFF222222), weight: 1.0)
          ],
          baseIndex: -1,
          globalBaseIndex: -1,
        ),
      ],
      segmentationLayout: SegmentationLayouts.single,
      segmentationClassMap: map,
    );

/// Available on both regions (default = upper: the base is on the lower).
const RecolorAvailability kBoth = RecolorAvailability(
  blocker: null,
  regions: <GarmentRegion>[GarmentRegion.upper, GarmentRegion.lower],
  defaultRegion: GarmentRegion.upper,
);

/// Available on the upper region only.
const RecolorAvailability kUpperOnly = RecolorAvailability(
  blocker: null,
  regions: <GarmentRegion>[GarmentRegion.upper],
  defaultRegion: GarmentRegion.upper,
);

/// A solid-colour image. Real async: call inside `runAsync`.
Future<ui.Image> solidImage(Color color, {int width = 30, int height = 40}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color);
  return recorder.endRecording().toImage(width, height);
}

/// The test images, created once per test inside `runAsync`.
class FakeImages {
  late ui.Image original;
  late ui.Image upper;
  late ui.Image lower;

  /// Creates the three images (call inside `runAsync`).
  Future<void> create() async {
    original = await solidImage(kOriginalInk);
    upper = await solidImage(kUpperInk);
    lower = await solidImage(kLowerInk);
  }
}

/// A scripted [RecolorSession]: no engine, no isolate. Records the targets,
/// the render calls and the disposal of every session it spawned.
class FakeRecolorSession implements RecolorSession {
  FakeRecolorSession(
    this.availability, {
    this.images,
    this.fail = false,
    this.gate,
    List<FakeRecolorSession>? spawned,
  }) : spawned = spawned ?? <FakeRecolorSession>[];

  @override
  final RecolorAvailability availability;

  /// Rendered images (cloned per call: the caller owns and disposes them).
  final FakeImages? images;

  /// renderImages throws a [RecolorException].
  final bool fail;

  /// When set, renderImages waits for it (the loading state).
  final Completer<void>? gate;

  /// Every session created through [withTarget] (shared list).
  final List<FakeRecolorSession> spawned;

  ui.Color? target;
  bool disposed = false;
  int renders = 0;

  /// The images handed out by [renderImages] (to check they get disposed).
  final List<ui.Image> handedOut = <ui.Image>[];

  @override
  List<int> get targetRgb => const <int>[0, 0, 0];

  @override
  Map<GarmentRegion, List<int>> get sources =>
      const <GarmentRegion, List<int>>{};

  @override
  RecolorSession withTarget(ui.Color target) {
    final FakeRecolorSession child = FakeRecolorSession(availability,
        images: images, fail: fail, gate: gate, spawned: spawned)
      ..target = target;
    spawned.add(child);
    return child;
  }

  @override
  Future<Map<GarmentRegion, RecolorFrame>> renderAll() =>
      throw UnimplementedError('the UI uses renderImages');

  @override
  Future<RecolorFrame> render(GarmentRegion region) =>
      throw UnimplementedError('the UI uses renderImages');

  @override
  Future<Map<GarmentRegion, ui.Image>> renderImages() async {
    renders++;
    if (gate != null) await gate!.future;
    if (fail) throw const RecolorException('scripted failure');
    final FakeImages imgs = images!;
    final Map<GarmentRegion, ui.Image> out = <GarmentRegion, ui.Image>{
      for (final GarmentRegion r in availability.regions)
        r: r == GarmentRegion.upper ? imgs.upper.clone() : imgs.lower.clone(),
    };
    handedOut.addAll(out.values);
    return out;
  }

  @override
  void dispose() => disposed = true;
}

/// A [RecolorOpener] returning [session] (and recording the call).
class FakeOpener {
  FakeOpener(this.session, {this.error, this.gate});

  final RecolorSession? session;
  final Object? error;
  final Completer<void>? gate;
  int calls = 0;
  ui.Color? target;

  Future<RecolorSession> call({
    required Uint8List photo,
    required AnalysisResult analysis,
    required ui.Color target,
  }) async {
    calls++;
    this.target = target;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return session!;
  }
}

/// Blocker-only availability.
RecolorAvailability blocked(RecolorBlocker b) =>
    RecolorAvailability.unavailable(b);
