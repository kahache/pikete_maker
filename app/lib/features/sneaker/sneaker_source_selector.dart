import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import '../capture/photo_picker.dart';
import 'sneaker_tip_case_data.dart';
import 'sneaker_tip_illustrations.dart';
import 'widgets/source_card.dart';

/// What the selector resolves to: the situation the user picked (N1 / D37:
/// it rides to the result so a shop screenshot opens the story preview with
/// the photo OFF) and the source it implies.
typedef SneakerSourceChoice = ({SneakerTipCase situation, PhotoSource source});

/// Sneaker "photo source selector" + mini-tutorials (Phase 2S · F11 · #83).
///
/// Spec: `docs/design/2026-07-11_1400_F2S_sneaker-source-selector-tutorial.md`.
/// CEO decision (flow-merge §7): this REPLACES the camera/gallery source sheet
/// in sneaker mode — each card already implies the source (casa/tienda =
/// camera, web = gallery), so the privacy line moved onto the selector and the
/// two "where from?" questions collapse into one.
///
/// Navigation contract: [SneakerSourceSelectorScreen] is a pushed route that
/// resolves to a [SneakerSourceChoice] (or `null` if the user backs out).
/// Tapping a card fires `sneaker_source_selected` and pushes the matching
/// mini-tutorial; the tutorial's primary CTA IS the capture trigger — it pops
/// the chosen [PhotoSource], which the selector hands back to
/// `pickPhotoWithSource` together with the situation.

/// privacy footer. Built from the source-sheet option row promoted to a full
/// screen (emoji tile on `surfaceSubtle`, mint only on the chevron — D8).
class SneakerSourceSelectorScreen extends StatelessWidget {
  const SneakerSourceSelectorScreen({super.key, this.analytics});

  /// Fires `sneaker_source_selected` on card tap (optional: null in tests that
  /// do not assert the event).
  final AnalyticsService? analytics;

  Future<void> _onCard(BuildContext context, SneakerTipCase tipCase) async {
    // Fires BEFORE the mini-tutorial, once per selection (spec §7 analytics).
    analytics?.log(AnalyticsEvent(
      AnalyticsEvents.sneakerSourceSelected,
      <String, Object?>{'source': tipCase.analyticsValue},
    ));
    // The mini-tutorial's CTA pops the chosen source; hand it straight back to
    // the caller (`pickPhotoWithSource`) WITH the situation, then the caller
    // opens camera/gallery.
    final PhotoSource? chosen = await Navigator.of(context).push<PhotoSource>(
      MaterialPageRoute<PhotoSource>(
        builder: (BuildContext _) => SneakerSourceTipScreen(tipCase: tipCase),
      ),
    );
    if (chosen != null && context.mounted) {
      Navigator.of(context)
          .pop<SneakerSourceChoice>((situation: tipCase, source: chosen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    // Contextual kicker, NOT the wordmark (D27); the app-bar theme renders it
    // in the `label` style with the mint back chevron.
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sneakerAppBarKicker)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screenMargin,
            Space.sm,
            Space.screenMargin,
            Space.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.sneakerSourceTitle,
                style: AppType.display.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              Text(
                context.l10n.sneakerSourceSub,
                style: AppType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.xl),
              for (final SneakerTipCase tipCase
                  in SneakerTipCase.values) ...<Widget>[
                if (tipCase != SneakerTipCase.values.first)
                  const SizedBox(height: Space.md),
                SourceCard(
                  tipCase: tipCase,
                  onTap: () => _onCard(context, tipCase),
                ),
              ],
              const Spacer(),
              Center(
                child: Text(
                  context.l10n.privacyNote,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(color: c.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen B · Mini-tutorial (REUSED tutorial anatomy, spec §4): «EL TRUCO»
/// badge → `display` headline → illustration card → body → primary CTA. Same
/// paddings/type ramp/button as the onboarding pro-tip page; the ONLY new asset
/// is the per-case [SneakerTipIllustration]. The CTA pops the chosen
/// [PhotoSource] — it is the capture launch, not a detour, so there is no
/// secondary CTA and no "Saltar".
class SneakerSourceTipScreen extends StatelessWidget {
  const SneakerSourceTipScreen({super.key, required this.tipCase});

  final SneakerTipCase tipCase;

  /// Test key of the illustration card (asserts the right case rendered).
  static const Key illustrationKey = Key('sneaker_tip_illustration');

  /// Cap on the illustration height: on a phone (~350 pt content width) the 4:3
  /// scene is ~262 pt tall and renders full-width (matching the mockup); the
  /// cap only bites on wide/short viewports so the non-scrolling tip screen
  /// never overflows.
  static const double _illustrationMaxHeight = 280;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sneakerAppBarKicker)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screenMargin,
            Space.sm,
            Space.screenMargin,
            Space.thumbZoneCta,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // «EL TRUCO» badge — 1 (of ≤2) purple dose (spec §4).
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  context.l10n.sneakerTipBadge,
                  style: AppType.label.copyWith(color: c.accent),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                tipCase.tipTitle(context.l10n),
                style: AppType.display.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.xl),
              // Illustration card: surfaceSubtle fill, 1px border, 4:3 scene
              // (same footprint as TipIllustration), full-width on a phone,
              // height-capped so it never overflows a wide/short viewport.
              ConstrainedBox(
                constraints: const BoxConstraints(
                    maxHeight: SneakerSourceTipScreen._illustrationMaxHeight),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceSubtle,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: c.border),
                    ),
                    child: AspectRatio(
                      aspectRatio: 160 / 120,
                      child: SneakerTipIllustration(
                        key: SneakerSourceTipScreen.illustrationKey,
                        tipCase: tipCase,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(
                tipCase.tipBody(context.l10n),
                style: AppType.body.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              PkPrimaryButton(
                label: tipCase.tipCta(context.l10n),
                // The CTA IS the capture trigger: pop the chosen source back to
                // the selector, which hands it to pickPhotoWithSource.
                onPressed: () => Navigator.of(context).pop(tipCase.photoSource),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
