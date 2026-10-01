import 'package:flutter/foundation.dart' show immutable;

import '../../l10n/l10n.dart';

/// Which analysis flow the shared capture/analyzing screens are serving
/// (Phase 2S · D24/D26): the two Home wedges reuse the SAME screens — only
/// the copy, the engine (product-mode on/off) and the result screen differ.
enum FlowMode {
  /// "Mi pikete": the original outfit flow (D12), unchanged.
  outfit,

  /// "Mis zapas": sneaker/product mode (F11) — product-mode engine, sneaker
  /// copy map, D27 inverted-hierarchy result.
  sneaker,
}

/// The per-mode copy consumed by the SHARED screens (source sheet, confirm,
/// analyzing). This is the "copy map keyed by mode" of the sneaker spec §3/§4
/// (reuse hand-off table): swapping strings, never layout.
///
/// i18n (D18 extended): the values now come from the ACTIVE locale's ARB —
/// [of] takes the screen's `context.l10n`. The es ARB carries the pre-2S
/// outfit literals and the SneakerStrings copy map verbatim, so the Spanish
/// experience stays byte-identical.
@immutable
class FlowCopy {
  const FlowCopy({
    required this.sheetTitle,
    required this.sheetCameraCaption,
    required this.sheetGalleryCaption,
    required this.appBarTitle,
    required this.confirmTitle,
    required this.confirmHint,
    required this.confirmCtaPrimary,
    required this.confirmCtaSecondary,
    required this.analyzingHeadline,
    required this.analyzingSteps,
    required this.analyzingSkipNotePrefix,
  });

  // Source sheet (photo_source_sheet.dart)
  final String sheetTitle;
  final String sheetCameraCaption;
  final String sheetGalleryCaption;

  // Confirm screen (capture_screen.dart)
  /// App bar: the wordmark for outfit, the contextual "MIS ZAPAS" kicker for
  /// sneaker (D27 — never the wordmark in the sneaker flow).
  final String appBarTitle;
  final String confirmTitle;
  final String confirmHint;
  final String confirmCtaPrimary;
  final String confirmCtaSecondary;

  // Analyzing screen (analyzing_screen.dart)
  final String analyzingHeadline;

  /// Honest step lines paced across the #55 window. The outfit pipeline shows
  /// its 3 stages; the sneaker spec (§4) defines a single step line.
  final List<String> analyzingSteps;

  /// Skip-note prefix; the accent-styled "ya casi" suffix is shared anatomy
  /// (`l10n.analyzingSkipNoteAccent`).
  final String analyzingSkipNotePrefix;

  static FlowCopy of(FlowMode mode, AppLocalizations l10n) => switch (mode) {
        FlowMode.outfit => FlowCopy(
            sheetTitle: l10n.outfitSheetTitle,
            sheetCameraCaption: l10n.outfitSheetCameraCaption,
            sheetGalleryCaption: l10n.outfitSheetGalleryCaption,
            // Brand rule (CEO, 2026-07-09): the wordmark is always
            // "PiketeMaker", never all-caps and never translated. See
            // docs/design/logo/LOGO.md.
            appBarTitle: 'PiketeMaker',
            confirmTitle: l10n.outfitConfirmTitle,
            confirmHint: l10n.outfitConfirmHint,
            confirmCtaPrimary: l10n.outfitConfirmCtaPrimary,
            confirmCtaSecondary: l10n.outfitConfirmCtaSecondary,
            analyzingHeadline: l10n.outfitAnalyzingHeadline,
            // Honest steps of the MVP pipeline (D15: whole-photo palette,
            // WITHOUT background removal — the mockup's "separando la ropa
            // del fondo" was pre-pivot).
            analyzingSteps: <String>[
              l10n.outfitAnalyzingStep1,
              l10n.outfitAnalyzingStep2,
              l10n.outfitAnalyzingStep3,
            ],
            analyzingSkipNotePrefix: l10n.outfitAnalyzingSkipNotePrefix,
          ),
        FlowMode.sneaker => FlowCopy(
            sheetTitle: l10n.sneakerSheetTitle,
            sheetCameraCaption: l10n.sneakerSheetCameraCaption,
            sheetGalleryCaption: l10n.sneakerSheetGalleryCaption,
            appBarTitle: l10n.sneakerAppBarKicker,
            confirmTitle: l10n.sneakerConfirmTitle,
            confirmHint: l10n.sneakerConfirmHint,
            confirmCtaPrimary: l10n.sneakerConfirmCtaPrimary,
            confirmCtaSecondary: l10n.sneakerConfirmCtaSecondary,
            analyzingHeadline: l10n.sneakerAnalyzingHeadline,
            analyzingSteps: <String>[l10n.sneakerAnalyzingStep],
            analyzingSkipNotePrefix: l10n.sneakerAnalyzingSkipNotePrefix,
          ),
      };
}
