import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/color_engine/models.dart';
import '../../l10n/l10n.dart';
import '../../routing/app_routes.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import '../capture/capture_screen.dart';
import '../capture/flow_mode.dart';
import '../result/looks_search.dart';
import '../story/story_export.dart';
import '../story/story_preferences.dart';
import '../story/story_share_sheet.dart';
import '../story/widgets/story_frame.dart';
import 'color_names.dart';
import 'sneaker_tip_case_data.dart';
import 'sneaker_tip_illustrations.dart';
import 'widgets/hero_combo.dart';
import 'widgets/other_combos_section.dart';
import 'widgets/sneaker_photo_story_frame.dart';
import 'widgets/sneaker_result_keys.dart';
import 'widgets/sneaker_share_canvas.dart';

/// Route arguments for [AppRoutes.sneakerResult].
@immutable
class SneakerResultArgs {
  const SneakerResultArgs({
    required this.result,
    required this.photo,
    this.situation,
  });

  final AnalysisResult result;

  /// The analyzed photo: "Otras zapas" returns to a fresh capture with the
  /// source sheet open, keeping this one underneath as fallback (#47
  /// pattern). It is also the photo of the shared story (N1 / D37), kept in
  /// memory only. Empty bytes (tests) → the story is card-only.
  final Uint8List photo;

  /// The source situation the photo came from (N1 / D37 spec §5.3). A web
  /// screenshot is a third party's image: the story preview opens with
  /// "Incluir mi foto" OFF and does not remember the choice. Null = unknown
  /// (treated as the user's own photo).
  final SneakerTipCase? situation;
}

/// Sneaker result (Phase 2S · F11, spec §5) — INVERTED hierarchy (D27): the
/// recommendation is the protagonist (hero combo band = the COMPLEMENTARY
/// scheme, with "tus zapas"/"tu ropa" role tags), the raw palette demotes to a
/// secondary strip with the BASE badge (D5). NO save UI (saving folds into
/// F7). SHARING: D37 (2026-09-29) supersedes D27/D25 for sharing only — the
/// result has "Súbela a tu story" as its secondary pill (same slot as the
/// outfit result) and "Otras zapas" became a text button under it. The story
/// preview sheet and frame are the shared `features/story/` ones.
///
/// Brand budget (D8): mint only on tappables (back, chevrons, 3 CTAs); purple
/// exactly 2 doses (BASE badge, watermark). The hero kicker and segment tags
/// are neutral. Inner screens do NOT inherit the Home tint exception.
///
/// Canvas mode (D10): 100% neutral kicks → the hero band is replaced by the
/// curated accent pops ([CanvasAccentsWrap], same component as outfit), the
/// kicker reads "La combi · Lienzo" and "Otras combis" is hidden (no chromatic
/// base → no harmonies).
///
/// F5 v0 (#82): the DEFAULT selection is the hero combo itself; tapping an
/// "Otras combis" row selects that scheme instead (action-fill chip, white
/// text — re-tap deselects, back to the hero), and the primary CTA
/// ("Enséñame otros piketes") deep-links the system browser to a pre-written
/// Google Images search with the ES color names of the selection. Canvas mode
/// selects an accent pop. Deep-link ONLY (decision #3).
class SneakerResultScreen extends StatefulWidget {
  const SneakerResultScreen({
    super.key,
    required this.args,
    this.analytics,
    this.launchSearch = launchLooksSearch,
    this.shareStory = shareStoryWithSystemSheet,
    this.storyPreferences = const StoryPreferencesPrefs(),
    this.writeStoryFile = writeStoryPng,
  });

  final SneakerResultArgs args;

  /// Share seam (N1 / D37): production default opens the OS share sheet.
  final StorySharer shareStory;

  /// Remembered "Incluir mi foto" choice (one key for both modes).
  final StoryPreferences storyPreferences;

  /// Story file seam: tests capture the exact bytes that get written.
  final StoryFileWriter writeStoryFile;

  /// Instrumentation seam (#4). Optional: null → not recorded (tests).
  final AnalyticsService? analytics;

  /// Deep-link seam (#82): production default opens the system browser; tests
  /// inject a fake to capture the URL or simulate offline.
  final LooksSearchLauncher launchSearch;

  /// Test keys: the D27 inverted hierarchy (hero band ABOVE the demoted
  /// palette strip) is asserted by geometry in the widget tests. The values
  /// live in [SneakerResultKeys] so the extracted sub-widgets can use them
  /// without importing this screen back.
  static const Key heroBandKey = SneakerResultKeys.heroBand;
  static const Key paletteStripKey = SneakerResultKeys.paletteStrip;
  static const Key canvasAccentsKey = SneakerResultKeys.canvasAccents;

  /// CTA keys (order/geometry tests of the D37 CTA stack).
  static const Key storyCtaKey = Key('sneaker_story_cta');
  static const Key otherSneakersKey = Key('sneaker_other_sneakers');

  @override
  State<SneakerResultScreen> createState() => _SneakerResultScreenState();
}

class _SneakerResultScreenState extends State<SneakerResultScreen> {
  /// F5 selection (#82). Null = the hero combo (complementary, D27).
  HarmonyType? _selectedScheme;

  /// Canvas-mode selection (#82): index of the chosen accent pop, or null.
  int? _selectedAccentIndex;

  /// True while the story preview sheet is open (double-tap guard).
  bool _exportingStory = false;

  SneakerResultArgs get args => widget.args;

  AnalysisResult get result => args.result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Contextual kicker, NOT the wordmark (D27-Q6). The app-bar theme
      // already renders titles in the `label` style on textTertiary and the
      // back chevron in mint.
      appBar: AppBar(title: Text(context.l10n.sneakerAppBarKicker)),
      body: SafeArea(
        top: false,
        // Spec §5: the CTA block scrolls WITH the content (order 1–4 inside
        // the scroll), unlike the outfit result's pinned CTAs.
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Space.thumbZoneCta),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Space.screenMargin),
                // The shareable card on its own layer (pop selection repaints
                // without dirtying the list below). The shared story renders
                // its own offscreen frame (D37), not this widget.
                child: RepaintBoundary(
                  child: SneakerShareCanvas(
                    result: result,
                    selectedAccentIndex: _selectedAccentIndex,
                    onAccentTap: _selectAccent,
                  ),
                ),
              ),
              if (!result.isCanvas)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.screenMargin, Space.xxl, Space.screenMargin, 0),
                  child: OtherCombosSection(
                    result: result,
                    selected: _selectedScheme,
                    onSelect: _selectCombo,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.screenMargin, Space.xxl, Space.screenMargin, 0),
                child: Column(
                  children: <Widget>[
                    PkPrimaryButton(
                      label: context.l10n.sneakerResultCtaPrimary,
                      // F5 v0 (#82): deep-link with the SELECTED combi
                      // (default: the hero complementary, D27).
                      onPressed: _openLooks,
                    ),
                    const SizedBox(height: Space.md),
                    // D37: the story share takes the secondary pill slot —
                    // same two pills, same order as the outfit result.
                    PkSecondaryButton(
                      key: SneakerResultScreen.storyCtaKey,
                      label: context.l10n.resultCtaStory,
                      onPressed: _exportStory,
                    ),
                    const SizedBox(height: Space.xs),
                    // "Scan the next pair": stays in the thumb zone as a
                    // text button (spec §5.2). NO save/bookmark UI (D27-Q4).
                    PkTextButton(
                      key: SneakerResultScreen.otherSneakersKey,
                      label: context.l10n.sneakerResultCtaSecondary,
                      onPressed: () => _otherSneakers(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Otras zapas" → fresh capture over a clean stack (home → confirm) with
  /// the source sheet already open; the current photo stays underneath as
  /// fallback if the sheet is dismissed (#47 pattern, sneaker mode).
  void _otherSneakers(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.capture,
      ModalRoute.withName(AppRoutes.home),
      arguments: CaptureArgs(
        photo: args.photo,
        openSourceSheetOnEntry: true,
        mode: FlowMode.sneaker,
        sneakerSituation: args.situation,
      ),
    );
  }

  /// "Súbela a tu story" (N1 / D37): the shared preview sheet. ON = the
  /// user's whole photo with the sneaker hero band ([SneakerPhotoStoryFrame]);
  /// OFF = the sneaker result card. A shop screenshot ("Captura de pantalla")
  /// opens OFF and never remembers the choice (third-party image, §5.3).
  Future<void> _exportStory() async {
    if (_exportingStory) return;
    _exportingStory = true;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    final Uint8List photo = args.photo;
    final int? accent = _selectedAccentIndex;
    final bool thirdParty = args.situation?.isThirdPartyImage ?? false;
    try {
      final StoryShareOutcome outcome = await showStorySharePreview(
        context: context,
        cardOnly: (BuildContext host) => renderStoryPng(
          host,
          StoryFrame.card(
            card: SneakerShareCanvas(
              result: result,
              selectedAccentIndex: accent,
              showWatermark: false,
            ),
          ),
        ),
        withPhoto: photo.isEmpty
            ? null
            : (BuildContext host) => renderPhotoStoryPng(
                  host,
                  photo,
                  (ui.Image image) => SneakerPhotoStoryFrame(
                    result: result,
                    photo: image,
                    selectedAccentIndex: accent,
                  ),
                ),
        sharer: widget.shareStory,
        preferences: widget.storyPreferences,
        initialIncludePhoto: thirdParty ? false : null,
        rememberChoice: !thirdParty,
        writeFile: widget.writeStoryFile,
        // Booleans/enums and numbers only: never the image or a path.
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
            'mode': 'sneaker',
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

  /// Toggle selection over the "Otras combis" rows (#82): tap selects the
  /// scheme, re-tap deselects it — back to the hero combo (the default).
  void _selectCombo(HarmonyType type) {
    final bool deselect = _selectedScheme == type;
    setState(() => _selectedScheme = deselect ? null : type);
    widget.analytics?.log(AnalyticsEvent(
      AnalyticsEvents.harmonySelected,
      <String, Object?>{
        'mode': 'sneaker',
        // Deselecting lands back on the hero (complementary, D27).
        'scheme': harmonySchemeId(deselect ? HarmonyType.complementary : type),
      },
    ));
  }

  /// Canvas-mode selection (#82): tap a pop to pick it, re-tap to clear.
  void _selectAccent(int index) {
    final bool deselect = _selectedAccentIndex == index;
    setState(() => _selectedAccentIndex = deselect ? null : index);
    if (deselect) return;
    widget.analytics?.log(AnalyticsEvent(
      AnalyticsEvents.harmonySelected,
      <String, Object?>{
        'mode': 'sneaker',
        'scheme': 'canvas',
        'accent': spanishColorName(result.canvasAccents[index]),
      },
    ));
  }

  /// F5 v0 (#82): deep-link the system browser to the pre-written search for
  /// the current selection. Offline/no-browser degrades to a SnackBar.
  Future<void> _openLooks() async {
    // Captured before the await (widget may unmount while launching).
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = context.l10n;
    // #82 i18n: query in the ACTIVE locale — color vocabulary AND pattern
    // (looks_search.dart; e.g. es "outfit negro y rojo", ja "黒 赤 コーデ").
    final String language = l10n.localeName;
    final String scheme;
    final String query;
    if (result.isCanvas) {
      // Neutral kicks: search the neutral base itself plus the chosen accent
      // pop, if any ("outfit negro" / "outfit negro con rojo" reads worse than
      // the plain list, so the same "y" joiner is used).
      scheme = 'canvas';
      query = looksSearchQuery(<Color>[
        for (final ColorSample sample in result.palette.take(2)) sample.color,
        if (_selectedAccentIndex != null &&
            _selectedAccentIndex! < result.canvasAccents.length)
          result.canvasAccents[_selectedAccentIndex!],
      ], language: language);
    } else if (_selectedScheme == null ||
        _selectedScheme == HarmonyType.complementary) {
      // The hero combo IS the recommendation (D27): reuse its own localized
      // names — including the "crema"/"negro" neutral the caption promises.
      final HeroCombo combo = HeroCombo.of(result, language);
      scheme = harmonySchemeId(HarmonyType.complementary);
      query = looksSearchQueryFromNames(<String>[
        combo.baseName,
        combo.complementName,
        combo.neutralName,
      ], language: language);
    } else {
      final Harmony harmony = result.harmonies.firstWhere(
        (Harmony h) => h.type == _selectedScheme,
        orElse: () => result.harmonies.first,
      );
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
        <String, Object?>{'mode': 'sneaker', 'scheme': scheme, 'query': query},
      ));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.looksSearchFailed)));
    }
  }
}
