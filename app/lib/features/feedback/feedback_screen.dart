import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';

/// The ugly states of the critical path (user-flows.md §2). CLAUDE.md
/// demands they are always implemented. They share ONE template
/// ([FeedbackScreen]): icon + headline + short line + primary CTA +
/// optional secondary CTA. "Never a dead end": all of them offer an
/// actionable exit.
enum UglyState {
  /// E1 · camera permission denied.
  cameraPermission,

  // E2 (no connection) was removed in r13 (A6, review F17): the app has no
  // user-facing network path — the analysis is on-device (D15), the looks
  // deep-link opens the external browser, which handles being offline, and
  // telemetry is silent background work. Restore it from git history (enum
  // value + spec + the `feedbackOffline*` ARB keys) if a feature ever makes
  // the user wait on the network.

  /// E3 · analysis failed (pipeline error / timeout).
  analysisFailed,

  /// E4 · photo without outfit / unreliable palette.
  noOutfit,

  /// Sneaker-mode analysis failed (Phase 2S spec §5): E3 and E4 collapse into
  /// ONE state with a single exit CTA. E1/E2 stay the shared states above
  /// (spec: "identical reuse of outfit ugly states").
  sneakerAnalysisFailed,
}

/// Copy and CTAs of each state (source: user-flows.md §2). Defined once.
@immutable
class _FeedbackSpec {
  const _FeedbackSpec({
    required this.icon,
    required this.headline,
    required this.detail,
    required this.primaryCta,
    this.secondaryCta,
    this.isError = true,
  });

  final IconData icon;
  final String headline;
  final String detail;
  final String primaryCta;

  /// null → the state has a single exit (the sneaker error, spec §5); the
  /// secondary button is simply not built.
  final String? secondaryCta;

  /// true → the icon is tinted with `error`; false → neutral (E4 does not
  /// blame the user).
  final bool isError;

  static _FeedbackSpec of(UglyState state, AppLocalizations l10n) {
    switch (state) {
      case UglyState.cameraPermission:
        // #34 pre-distribution condition (UX audit, point b): the demo has no
        // settings plugin, so the CTA guides instead of opening the system
        // settings. "Cómo activarla" promises exactly what it delivers
        // (UX-approved relabel); if `app_settings` ever gets approved, restore
        // the spec copy "Abrir ajustes" and open settings for real.
        return _FeedbackSpec(
          icon: Icons.no_photography_outlined,
          headline: l10n.feedbackCameraHeadline,
          detail: l10n.feedbackCameraDetail,
          primaryCta: l10n.feedbackCameraCtaPrimary,
          secondaryCta: l10n.feedbackCameraCtaSecondary,
        );
      case UglyState.analysisFailed:
        return _FeedbackSpec(
          icon: Icons.error_outline,
          headline: l10n.feedbackFailedHeadline,
          detail: l10n.feedbackFailedDetail,
          primaryCta: l10n.feedbackFailedCtaPrimary,
          secondaryCta: l10n.feedbackFailedCtaSecondary,
        );
      case UglyState.noOutfit:
        return _FeedbackSpec(
          icon: Icons.image_search_outlined,
          headline: l10n.feedbackNoOutfitHeadline,
          detail: l10n.feedbackNoOutfitDetail,
          primaryCta: l10n.feedbackNoOutfitCtaPrimary,
          secondaryCta: l10n.feedbackNoOutfitCtaSecondary,
          isError: false, // E4 is advice, not a user error
        );
      case UglyState.sneakerAnalysisFailed:
        // Sneaker flow (Phase 2S spec §5): one honest error, one exit.
        return _FeedbackSpec(
          icon: Icons.error_outline,
          headline: l10n.sneakerErrorTitle,
          detail: l10n.sneakerErrorBody,
          primaryCta: l10n.sneakerErrorCta,
        );
    }
  }
}

/// Route arguments for [AppRoutes.feedback].
@immutable
class FeedbackArgs {
  const FeedbackArgs({
    required this.state,
    this.onPrimary,
    this.onSecondary,
  });

  final UglyState state;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
}

/// Single ugly-state template.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key, required this.args});

  final FeedbackArgs args;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final _FeedbackSpec spec = _FeedbackSpec.of(args.state, context.l10n);
    final Color iconColor = spec.isError ? c.error : c.textTertiary;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screenMargin,
            Space.screenMargin,
            Space.screenMargin,
            Space.thumbZoneCta,
          ),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Icon(spec.icon, size: 56, color: iconColor),
              const SizedBox(height: Space.xl),
              Text(
                spec.headline,
                textAlign: TextAlign.center,
                style: AppType.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              Text(
                spec.detail,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              PkPrimaryButton(
                label: spec.primaryCta,
                onPressed: args.onPrimary ?? () => Navigator.of(context).pop(),
              ),
              if (spec.secondaryCta != null) ...<Widget>[
                const SizedBox(height: Space.md),
                PkSecondaryButton(
                  label: spec.secondaryCta!,
                  onPressed:
                      args.onSecondary ?? () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
