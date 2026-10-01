import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/color_engine/models.dart';
import '../../core/recolor/recolor_service.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import '../result/widgets/outfit_hero_combo_spec.dart';
import '../result/widgets/outfit_story_frame.dart';
import '../sneaker/widgets/hero_combo.dart';
import '../sneaker/widgets/hero_combo_band.dart';
import '../story/story_export.dart';
import '../story/story_photo.dart';
import '../story/story_preferences.dart';
import '../story/story_share_sheet.dart';
import '../story/widgets/story_canvas_band.dart';
import 'recolor_target.dart';
import 'widgets/recolor_photo_card.dart';
import 'widgets/region_selector.dart';

/// Decodes the ORIGINAL photo for the view (production: the story decoder,
/// upright, story-sized). A seam so widget tests can hand a ready image.
typedef RecolorPhotoDecoder = Future<ui.Image> Function(Uint8List bytes);

/// How the recolor view ended (the result screen shows
/// `recolorFailedSnack` on [failed]).
enum RecolorViewOutcome {
  /// The user went back.
  closed,

  /// The recolor could not be computed ([RecolorException]).
  failed,
}

/// "Vérmelo puesto" — the recolor view (I2, D38; UX §2.2 / §2.3, mockup
/// `docs/design/mockups/2026-09-30_I2-recolor.html` §2). Outfit mode only.
///
/// No scroll: headline "Así te quedaría" · kicker "{Región} · {color}" · the
/// story-card object (the photo, recolored, with the hero band flush under
/// it) · the expectation line · the ARRIBA / ABAJO selector (hidden when one
/// region qualifies) · "Súbela a tu story" in the thumb zone.
///
///  - Entering: the original photo shows at once; the recolor of BOTH
///    regions starts immediately off the UI isolate ([RecolorSession
///    .renderImages]); a 2 px progress line runs until it lands, then a
///    200 ms cross-fade. Switching regions afterwards is instant (cached).
///  - Press-and-hold anywhere on the photo = the original while held.
///  - "Súbela a tu story" opens the D37 sheet UNCHANGED, parameterised with
///    the recolored bitmap of the active region and this view's headline
///    (switch / privacy line / deletion rules exactly as r14; OFF = the
///    card-only image). Disabled until the recolor is ready.
///  - Back (chevron or system) pops and DISPOSES everything: the session
///    zero-fills its buffers, the GPU images are released. Nothing is ever
///    written to disk here; the only file is the story PNG of the D37 flow.
///  - No telemetry of any kind (D38).
class RecolorScreen extends StatefulWidget {
  /// Creates the view. The screen OWNS [session] and disposes it.
  const RecolorScreen({
    super.key,
    required this.session,
    required this.result,
    required this.photo,
    required this.target,
    required this.frameAspect,
    this.selectedAccentIndex,
    this.selectedScheme,
    this.decodePhoto = decodeStoryPhoto,
    this.shareStory = shareStoryWithSystemSheet,
    this.storyPreferences = const StoryPreferencesPrefs(),
    this.writeStoryFile = writeStoryPng,
  });

  /// The recolor session (already bound to [target]).
  final RecolorSession session;

  /// The analysis (the band and the card-only story come from it).
  final AnalysisResult result;

  /// The picker bytes (memory only).
  final Uint8List photo;

  /// The painted colour and its name (kicker).
  final RecolorTarget target;

  /// Aspect (w/h) of the analysed, upright frame: sizes the card before any
  /// bitmap exists (no layout jump).
  final double frameAspect;

  /// Canvas mode: the pop in play (band + card-only story).
  final int? selectedAccentIndex;

  /// D39: the "Otras combis" combo in play (null = the hero): the band, the
  /// card-only story and the photo story all show it ([target] is its
  /// "súmale" colour).
  final HarmonyType? selectedScheme;

  /// Original-photo decoder seam.
  final RecolorPhotoDecoder decodePhoto;

  /// D37 seams, threaded from the result screen.
  final StorySharer shareStory;
  final StoryPreferences storyPreferences;
  final StoryFileWriter writeStoryFile;

  /// Test keys.
  static const Key ctaKey = Key('recolor_story_cta');
  static const Key kickerKey = Key('recolor_kicker');

  @override
  State<RecolorScreen> createState() => _RecolorScreenState();
}

class _RecolorScreenState extends State<RecolorScreen> {
  late GarmentRegion _region;
  ui.Image? _original;
  Map<GarmentRegion, ui.Image>? _images;
  bool _held = false;
  bool _sharing = false;
  bool _disposed = false;

  RecolorAvailability get _availability => widget.session.availability;

  @override
  void initState() {
    super.initState();
    _region = _availability.defaultRegion ?? _availability.regions.first;
    unawaited(_loadOriginal());
    unawaited(_render());
  }

  Future<void> _loadOriginal() async {
    try {
      final ui.Image image = await widget.decodePhoto(widget.photo);
      if (_disposed) {
        image.dispose();
        return;
      }
      setState(() => _original = image);
    } catch (_) {
      // The placeholder stays; the recolor still lands on top of it.
    }
  }

  Future<void> _render() async {
    try {
      final Map<GarmentRegion, ui.Image> images =
          await widget.session.renderImages();
      if (_disposed) {
        for (final ui.Image image in images.values) {
          image.dispose();
        }
        return;
      }
      setState(() => _images = images);
    } catch (_) {
      // RecolorException (or anything else): back to the result + snack.
      if (!_disposed && mounted) {
        Navigator.of(context).pop(RecolorViewOutcome.failed);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.session.dispose();
    for (final ui.Image image in _images?.values ?? const <ui.Image>[]) {
      image.dispose();
    }
    _images = null;
    _original?.dispose();
    _original = null;
    super.dispose();
  }

  void _setHeld(bool held) {
    if (_held != held) setState(() => _held = held);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final List<GarmentRegion> regions = _availability.regions;
    final ui.Image? recolored = _images?[_region];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeOutfitLabel)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: Space.md),
              Text(l10n.recolorHeadline,
                  style: AppType.display.copyWith(color: c.textPrimary)),
              const SizedBox(height: Space.xs),
              Text(
                l10n
                    .recolorKicker(
                        recolorRegionLabel(l10n, _region), widget.target.name)
                    .toUpperCase(),
                key: RecolorScreen.kickerKey,
                style: AppType.label.copyWith(color: c.textTertiary),
              ),
              const SizedBox(height: Space.md),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) => Align(
                    alignment: Alignment.topCenter,
                    child: RecolorPhotoCard(
                      aspect: widget.frameAspect,
                      maxHeight: box.maxHeight,
                      original: _original,
                      recolored: recolored,
                      recoloredKey: ValueKey<GarmentRegion>(_region),
                      held: _held,
                      loading: _images == null,
                      band: _band(l10n),
                      onHoldChanged: _setHeld,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                l10n.recolorExpectation,
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: c.textTertiary),
              ),
              const SizedBox(height: Space.xl),
              if (regions.length > 1) ...<Widget>[
                RegionSelector(
                  regions: regions,
                  selected: _region,
                  onSelect: (GarmentRegion r) => setState(() => _region = r),
                ),
                const SizedBox(height: Space.md),
              ],
              PkPrimaryButton(
                key: RecolorScreen.ctaKey,
                label: l10n.resultCtaStory,
                onPressed: recolored == null ? null : _shareStory,
              ),
              const SizedBox(height: Space.thumbZoneCta),
            ],
          ),
        ),
      ),
    );
  }

  /// The recommendation band under the photo: the D36 hero band (the same
  /// widget and spec as the result card, D31-A raw), or the canvas pops with
  /// the selected one tagged "súmale".
  Widget _band(AppLocalizations l10n) {
    final AnalysisResult result = widget.result;
    if (result.isCanvas || result.harmonies.isEmpty) {
      return StoryCanvasBand(
        accents: result.canvasAccents,
        height: RecolorPhotoCard.bandHeight,
        selectedIndex: widget.selectedAccentIndex ?? 0,
        selectedTag: l10n.resultTagAdd.toUpperCase(),
      );
    }
    return HeroComboBand(
      combo: HeroCombo.of(result, l10n.localeName,
          snapForDisplay: false, scheme: widget.selectedScheme),
      spec: outfitHeroBandSpec,
      height: RecolorPhotoCard.bandHeight,
      framed: false,
    );
  }

  /// "Súbela a tu story": the D37 sheet, unchanged, with the recolored
  /// bitmap of the active region + "Así te quedaría". No telemetry (D38).
  Future<void> _shareStory() async {
    final ui.Image? image = _images?[_region];
    if (_sharing || image == null) return;
    _sharing = true;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    final AnalysisResult result = widget.result;
    final int? accent = widget.selectedAccentIndex ??
        ((result.isCanvas || result.harmonies.isEmpty) ? 0 : null);
    try {
      final StoryShareOutcome outcome = await showStorySharePreview(
        context: context,
        cardOnly: (BuildContext host) => renderStoryPng(
          host,
          OutfitStoryFrame(
            result: result,
            selectedAccentIndex: accent,
            selectedScheme: widget.selectedScheme,
          ),
        ),
        withPhoto: (BuildContext host) => renderStoryPng(
          host,
          OutfitPhotoStoryFrame(
            result: result,
            photo: image,
            selectedAccentIndex: accent,
            headline: l10n.recolorHeadline,
            selectedScheme: widget.selectedScheme,
          ),
        ),
        sharer: widget.shareStory,
        preferences: widget.storyPreferences,
        writeFile: widget.writeStoryFile,
      );
      if (outcome == StoryShareOutcome.failed) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.storyFailedSnack)));
      }
    } finally {
      _sharing = false;
    }
  }
}
