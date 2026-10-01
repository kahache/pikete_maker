import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/color_engine/models.dart';
import '../../core/recolor/recolor_service.dart';
import '../../core/segmentation/garment_segmenter.dart';
import '../../l10n/l10n.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import '../recolor/recolor_screen.dart';
import '../recolor/recolor_slot.dart';
import '../recolor/recolor_target.dart';
import '../sneaker/color_names.dart';
import '../sneaker/widgets/hero_combo.dart';
import '../sneaker/widgets/other_combos_section.dart';
import '../story/story_export.dart';
import '../story/story_photo.dart';
import '../story/story_preferences.dart';
import '../story/story_share_sheet.dart';
import 'looks_search.dart';
import 'widgets/canvas_section.dart';
import 'widgets/harmonies_section.dart';
import 'widgets/outfit_result_keys.dart';
import 'widgets/outfit_share_canvas.dart';
import 'widgets/outfit_story_frame.dart';

/// Arguments of the outfit result route (N1 / D37), mirroring
/// `SneakerResultArgs`: the analysis AND the photo that was analyzed, so the
/// shared story can carry the user's own photo.
@immutable
class ResultArgs {
  const ResultArgs({required this.result, this.photo});

  final AnalysisResult result;

  /// The original picker bytes (≤ 1600 px JPEG), kept IN MEMORY only. Null
  /// (tests / legacy) → the story preview hides "Incluir mi foto" and shares
  /// the card-only image.
  final Uint8List? photo;
}

/// Step 5 of D12 · result (canonical mockup result.html, screen 1).
///
/// "Súbela a tu story" (A3 r13 → N1 / D37) opens the story PREVIEW SHEET: the
/// exact 9:16 PNG, an "Incluir mi foto" switch (default ON, remembered
/// locally) and "Compartir", which hands the PNG to the OS share sheet. ON =
/// the user's whole photo with the hero band under it ([OutfitPhotoStoryFrame]);
/// OFF = r13's card-only image ([OutfitStoryFrame]). Both are rendered
/// OFFSCREEN; the photo only leaves the phone through the user's own share.
///
/// D36 (2026-07-23): on the production (segmented) path the screen is
/// RECOMMENDATION-FIRST, mirroring the sneaker result's D27 inverted hierarchy
/// — the hero combo (complementary) leads inside the share canvas, the
/// extracted ARRIBA/ABAJO palette demotes to the "tu fit" strip, and the
/// harmony list below is "Otras combis" (the 3 REMAINING schemes, sneaker
/// slang). The legacy whole-photo fallback (`segmentationLayout == null`) keeps
/// today's extraction-led "Tu paleta" screen byte-identical.
///
/// F5 v0 (#82): the DEFAULT selection is the hero combo itself; tapping an
/// "Otras combis" row selects that scheme (re-tap deselects, back to the hero)
/// and "Ver looks así" deep-links a pre-written Google Images search built from
/// the ES color names of the selection. Canvas mode (D10) selects an accent
/// pop. Deep-link ONLY (decision #3): nothing is embedded in-app.
///
/// The reveal enters with `motion.reveal` (600 ms): it is THE moment of the
/// app.
///
/// Stateful for three reasons: it fires the `result_viewed` event once on
/// mount (#4), it holds the F5 selection (which the shared story mirrors), and
/// it guards the story export against double taps.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    this.photo,
    this.analytics,
    this.launchSearch = launchLooksSearch,
    this.shareStory = shareStoryWithSystemSheet,
    this.storyPreferences = const StoryPreferencesPrefs(),
    this.writeStoryFile = writeStoryPng,
    this.openRecolor = openRecolorSession,
    this.decodeRecolorPhoto = decodeStoryPhoto,
  });

  final AnalysisResult result;

  /// The analyzed photo (N1): enables the photo story. Null → card-only.
  final Uint8List? photo;

  /// Instrumentation seam (#4). Optional: null → not recorded (tests).
  final AnalyticsService? analytics;

  /// Deep-link seam (#82): production default opens the system browser; tests
  /// inject a fake to capture the URL or simulate offline.
  final LooksSearchLauncher launchSearch;

  /// Share seam (A3): production default opens the OS share sheet
  /// (share_plus); tests inject a fake to capture the PNG without a platform
  /// channel.
  final StorySharer shareStory;

  /// Remembered "Incluir mi foto" choice (N1): SharedPreferences in
  /// production, in-memory in tests.
  final StoryPreferences storyPreferences;

  /// Story file seam (N1): tests capture the exact bytes that get written.
  final StoryFileWriter writeStoryFile;

  /// I2 "Vérmelo puesto" (D38) seam: opens the recolor session (production:
  /// the on-device [RecolorService]; tests inject a fake).
  final RecolorOpener openRecolor;

  /// I2 seam: decodes the original photo for the recolor view.
  final RecolorPhotoDecoder decodeRecolorPhoto;

  /// Test keys: the D36 inverted hierarchy (hero band ABOVE the demoted "tu
  /// fit" strip) is asserted by geometry against these keys.
  static const Key heroBandKey = OutfitResultKeys.heroBand;
  static const Key fitStripKey = OutfitResultKeys.fitStrip;
  static const Key canvasAccentsKey = OutfitResultKeys.canvasAccents;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  /// True while the story preview sheet is open (double-tap guard).
  bool _exportingStory = false;

  /// F5 selection (#82). Null = default: the hero combo (complementary).
  HarmonyType? _selectedScheme;

  /// Canvas-mode selection (#82): index of the chosen accent pop, or null.
  int? _selectedAccentIndex;

  /// I2 (D38): the assessed recolor session (verdict only; each visit of the
  /// recolor view gets its own [RecolorSession.withTarget] copy that owns
  /// the bitmaps). Null until assessed, or when not eligible / refused.
  RecolorSession? _recolor;

  /// True while the off-isolate assessment runs (the slot is reserved).
  bool _recolorPending = false;

  /// Double-tap guard of "Vérmelo puesto".
  bool _openingRecolor = false;

  AnalysisResult get result => widget.result;

  /// I2 is offered on the D36 (segmented) outfit path only, with the photo
  /// and the segmentation map in hand. Without a map (S4 whole-photo
  /// fallback, flag off) the feature does not exist for this result: no
  /// pill, no tip (PM, r15).
  bool get _recolorEligible =>
      _reco && widget.photo != null && result.segmentationClassMap != null;

  /// D36 recommendation-first applies on the production (segmented) path; a
  /// null layout is the legacy whole-photo fallback that keeps today's screen.
  bool get _reco => result.segmentationLayout != null;

  /// The harmony the legacy CTA deep-links (radio behavior, defaults to the
  /// first — complementary). Null only in canvas mode / no harmonies.
  Harmony? get _selectedHarmony {
    if (result.harmonies.isEmpty) return null;
    for (final Harmony harmony in result.harmonies) {
      if (harmony.type == _selectedScheme) return harmony;
    }
    return result.harmonies.first;
  }

  @override
  void initState() {
    super.initState();
    // The payoff moment reached the user (#4). When the Phase 2.5 segmented
    // path ran, the event is tagged with the layout it produced (spec §6);
    // the legacy path keeps the historical param-less event byte-identical.
    final String? layout = result.segmentationLayout;
    widget.analytics?.log(layout == null
        ? const AnalyticsEvent(AnalyticsEvents.resultViewed)
        : AnalyticsEvent(
            AnalyticsEvents.resultViewed, <String, Object?>{'layout': layout}));
    if (_recolorEligible) {
      _recolorPending = true;
      // After the first frame: the result renders first, never blocked; the
      // assessment runs off the UI isolate and fills the reserved slot.
      WidgetsBinding.instance.addPostFrameCallback((_) => _assessRecolor());
    }
  }

  @override
  void dispose() {
    _recolor?.dispose();
    super.dispose();
  }

  /// D39 (amends D37/D38): the combo the app ACTS on — the one selected in
  /// "Otras combis", or null for the hero (complementary). SINGLE SOURCE for
  /// the hero band on screen, "Vérmelo puesto", both story frames and the
  /// recolor view ("Ver looks así" reads [_selectedScheme] itself). Only on
  /// the D36 chromatic path: canvas mode keeps its pop selection, and the
  /// legacy layout never had a hero.
  HarmonyType? get _actingScheme =>
      (_reco && !result.isCanvas) ? _selectedScheme : null;

  RecolorTarget _recolorTarget() =>
      RecolorTarget.of(result, context.l10n.localeName,
          selectedAccentIndex: _selectedAccentIndex, scheme: _actingScheme);

  /// I2 stage 1 (D38): applicability + qualifying regions. Any refusal
  /// (e.g. the EXIF / frame mismatch guard) leaves the slot empty. No
  /// telemetry (D38).
  Future<void> _assessRecolor() async {
    if (!mounted) return;
    RecolorSession? session;
    try {
      session = await widget.openRecolor(
        photo: widget.photo!,
        analysis: result,
        target: _recolorTarget().color,
      );
    } catch (_) {
      session = null;
    }
    if (!mounted) {
      session?.dispose();
      return;
    }
    setState(() {
      _recolor = session;
      _recolorPending = false;
    });
  }

  /// "Vérmelo puesto" → the recolor view, bound to the colour on screen
  /// right now (the hero "súmale", or the selected canvas pop).
  Future<void> _openRecolorView() async {
    final RecolorSession? base = _recolor;
    final SegmentationClassMap? map = result.segmentationClassMap;
    if (_openingRecolor ||
        base == null ||
        map == null ||
        !base.availability.isAvailable) {
      return;
    }
    _openingRecolor = true;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    final RecolorTarget target = _recolorTarget();
    try {
      final RecolorViewOutcome? outcome =
          await Navigator.of(context).push<RecolorViewOutcome>(
        MaterialPageRoute<RecolorViewOutcome>(
          builder: (BuildContext _) => RecolorScreen(
            session: base.withTarget(target.color),
            result: result,
            photo: widget.photo!,
            target: target,
            frameAspect: map.frameWidth / map.frameHeight,
            selectedAccentIndex: _selectedAccentIndex,
            selectedScheme: _actingScheme,
            decodePhoto: widget.decodeRecolorPhoto,
            shareStory: widget.shareStory,
            storyPreferences: widget.storyPreferences,
            writeStoryFile: widget.writeStoryFile,
          ),
        ),
      );
      if (outcome == RecolorViewOutcome.failed) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.recolorFailedSnack)));
      }
    } finally {
      _openingRecolor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Brand rule (CEO, 2026-07-09): the wordmark is always "PiketeMaker",
      // never all-caps. See docs/design/logo/LOGO.md.
      appBar: AppBar(title: const Text('PiketeMaker')),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: Space.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // RepaintBoundary: the canvas repaints on its own layer
                    // (pop selection) without dirtying the list below. The
                    // accent selection is threaded down: on the D36 path the
                    // curated pops ARE the hero (inside the canvas).
                    RepaintBoundary(
                      child: OutfitShareCanvas(
                        result: result,
                        selectedAccentIndex: _selectedAccentIndex,
                        onAccentTap: _selectAccent,
                        // D39: the band swaps in place to the selected combo.
                        selectedScheme: _actingScheme,
                      ),
                    ),
                    _sectionBelowCanvas(),
                  ],
                ),
              ),
            ),
            // CTAs in the thumb zone. CEO amendment (2026-09-30, on device):
            // "Vérmelo puesto" is the FIRST CTA of this block (under the card
            // it sat below the fold), then the story, then the looks; all
            // three share the outlined style — no filled primary here.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.screenMargin,
                Space.lg,
                Space.screenMargin,
                Space.thumbZoneCta,
              ),
              child: Column(
                children: <Widget>[
                  // I2 (D38): disabled while assessing, the tip when
                  // blocked, absent when not eligible / no segmentation.
                  if (_recolorEligible)
                    RecolorSlot(
                      pending: _recolorPending,
                      availability: _recolor?.availability,
                      onPressed: _openRecolorView,
                    ),
                  // CEO 2026-09-30 (r17): mint · purple · mint, all filled
                  // with white text.
                  PkAccentButton(
                    label: context.l10n.resultCtaStory,
                    onPressed: _exportStory,
                  ),
                  const SizedBox(height: Space.md),
                  PkPrimaryButton(
                    label: context.l10n.resultCtaLooks,
                    onPressed: _openLooks,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What renders under the share canvas:
  ///  - D36 chromatic → "Otras combis" (the 3 remaining harmonies, sneaker
  ///    slang; the hero already owns the complementary).
  ///  - D36 canvas → nothing (the curated pops live in the hero).
  ///  - Legacy → today's "Combina con" harmonies (or the canvas section).
  Widget _sectionBelowCanvas() {
    if (_reco) {
      if (result.isCanvas) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: Space.xxl),
        child: OtherCombosSection(
          result: result,
          selected: _selectedScheme,
          onSelect: _selectCombo,
        ),
      );
    }
    // Legacy (segmentationLayout == null): today's screen verbatim.
    return Padding(
      padding: const EdgeInsets.only(top: Space.xxl),
      child: result.isCanvas
          ? CanvasSection(
              accents: result.canvasAccents,
              selectedIndex: _selectedAccentIndex,
              onAccentTap: _selectAccent,
            )
          : HarmoniesSection(
              harmonies: result.harmonies,
              selected: _selectedHarmony?.type,
              onSelect: _selectHarmony,
            ),
    );
  }

  /// "Súbela a tu story" (N1 / D37): open the preview sheet. The ON state
  /// (photo story) exists only on the D36 path with the photo in hand; the
  /// legacy layout and a missing photo share the card-only image with the
  /// switch hidden (spec §2.4). Rendering/share failures degrade to the
  /// existing "couldn't generate" SnackBar.
  Future<void> _exportStory() async {
    if (_exportingStory) return;
    _exportingStory = true;
    // Captured before the awaits (widget may unmount while the sheet is open).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    final Uint8List? photo = widget.photo;
    final int? accent = _selectedAccentIndex;
    final HarmonyType? scheme = _actingScheme; // D39: what you see is shared
    try {
      final StoryShareOutcome outcome = await showStorySharePreview(
        context: context,
        cardOnly: (BuildContext host) => renderStoryPng(
          host,
          OutfitStoryFrame(
            result: result,
            selectedAccentIndex: accent,
            selectedScheme: scheme,
          ),
        ),
        withPhoto: (photo == null || !_reco)
            ? null
            : (BuildContext host) => renderPhotoStoryPng(
                  host,
                  photo,
                  (ui.Image image) => OutfitPhotoStoryFrame(
                    result: result,
                    photo: image,
                    selectedAccentIndex: accent,
                    selectedScheme: scheme,
                  ),
                ),
        sharer: widget.shareStory,
        preferences: widget.storyPreferences,
        writeFile: widget.writeStoryFile,
        // Booleans/enums and a byte count only: never the image or a path.
        onShared: ({
          required String status,
          required int bytes,
          required bool photo,
          required int? previewMs,
        }) =>
            widget.analytics?.log(AnalyticsEvent(
          AnalyticsEvents.storyExported,
          <String, Object?>{
            'bytes': bytes,
            'status': status,
            'photo': photo,
            'mode': 'outfit',
            'preview_ms': previewMs,
          },
        )),
      );
      if (outcome == StoryShareOutcome.failed) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.storyFailedSnack)));
      }
    } finally {
      _exportingStory = false;
    }
  }

  /// Legacy radio selection over the "Combina con" rows (#82): re-tapping the
  /// selected one is a no-op (there is always a selection, so the CTA always
  /// has a target).
  void _selectHarmony(HarmonyType type) {
    if (_selectedHarmony?.type == type) return;
    setState(() => _selectedScheme = type);
    widget.analytics?.log(AnalyticsEvent(
      AnalyticsEvents.harmonySelected,
      <String, Object?>{'mode': 'outfit', 'scheme': harmonySchemeId(type)},
    ));
  }

  /// D36 toggle selection over the "Otras combis" rows (#82): tap selects the
  /// scheme, re-tap deselects it — back to the hero combo (the default).
  void _selectCombo(HarmonyType type) {
    final bool deselect = _selectedScheme == type;
    setState(() => _selectedScheme = deselect ? null : type);
    widget.analytics?.log(AnalyticsEvent(
      AnalyticsEvents.harmonySelected,
      <String, Object?>{
        'mode': 'outfit',
        // Deselecting lands back on the hero (complementary, D36).
        'scheme': harmonySchemeId(deselect ? HarmonyType.complementary : type),
      },
    ));
  }

  /// Canvas-mode selection (#82): tap a pop to pick it, tap it again to go
  /// back to the plain neutral look.
  void _selectAccent(int index) {
    final bool deselect = _selectedAccentIndex == index;
    setState(() => _selectedAccentIndex = deselect ? null : index);
    if (deselect) return;
    widget.analytics?.log(AnalyticsEvent(
      AnalyticsEvents.harmonySelected,
      <String, Object?>{
        'mode': 'outfit',
        'scheme': 'canvas',
        'accent': spanishColorName(result.canvasAccents[index]),
      },
    ));
  }

  /// F5 v0 (#82): deep-link the system browser to the pre-written search for
  /// the current selection. Offline/no-browser degrades to a SnackBar (the
  /// only networked touchpoint of an otherwise offline app, D15).
  Future<void> _openLooks() async {
    // Captured before the await (widget may unmount while launching).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    // #82 i18n: the query speaks the ACTIVE locale — its color vocabulary
    // AND its pattern ("outfit negro y blanco" / market ordering, see
    // looks_search.dart).
    final String language = l10n.localeName;
    final String scheme;
    final String query;
    if (result.isCanvas) {
      // Canvas mode (or defensive: no harmonies): search the neutral look
      // itself, plus the chosen accent pop if any ("outfit negro y blanco" /
      // "outfit negro, blanco y rojo").
      scheme = 'canvas';
      query = looksSearchQuery(<Color>[
        for (final ColorSample sample in result.palette.take(2)) sample.color,
        if (_selectedAccentIndex != null &&
            _selectedAccentIndex! < result.canvasAccents.length)
          result.canvasAccents[_selectedAccentIndex!],
      ], language: language);
    } else if (_reco &&
        (_selectedScheme == null ||
            _selectedScheme == HarmonyType.complementary)) {
      // D36 hero combo IS the recommendation: reuse its own localized names —
      // including the "crema"/"negro" neutral the caption promises.
      final HeroCombo combo =
          HeroCombo.of(result, language, snapForDisplay: false);
      scheme = harmonySchemeId(HarmonyType.complementary);
      query = looksSearchQueryFromNames(<String>[
        combo.baseName,
        combo.complementName,
        combo.neutralName,
      ], language: language);
    } else {
      // Legacy default (complementary) or a D36-selected non-complementary
      // scheme: search that scheme's own colors.
      final Harmony harmony = _selectedHarmony!;
      scheme = harmonySchemeId(harmony.type);
      query = looksSearchQuery(harmony.colors, language: language);
    }
    bool ok;
    try {
      ok = await widget.launchSearch(looksSearchUri(query));
    } catch (_) {
      ok = false; // no browser / plugin missing: same graceful path
    }
    if (ok) {
      widget.analytics?.log(AnalyticsEvent(
        AnalyticsEvents.looksSearchLaunched,
        <String, Object?>{'mode': 'outfit', 'scheme': scheme, 'query': query},
      ));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.looksSearchFailed)));
    }
  }
}
