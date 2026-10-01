import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/telemetry/telemetry_config.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';

/// First-run telemetry NOTICE (D33 amended · `docs/legal/consent-copy-first-run.md`).
///
/// A transparency notice, NOT a consent gate: the transmitted data is
/// genuinely anonymous, so a single "Entendido" is the whole interaction
/// (legal doc §2 — if the lawyer later requires consent, this sheet grows a
/// second equal-prominence button and the controller gates on the choice).
/// Dismissing by swipe counts as seen too — it is a notice.
///
/// Shown ONLY when telemetry is active (endpoint configured): with the
/// endpoint empty nothing is collected, so no notice appears — no consent
/// theater (legal doc §1, "the copy must match that reality").
Future<void> showTelemetryNoticeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: context.colors.scrim,
    builder: (BuildContext _) => const TelemetryNoticeSheet(),
  );
}

class TelemetryNoticeSheet extends StatelessWidget {
  const TelemetryNoticeSheet({super.key});

  /// Test key of the "Entendido" action.
  static const Key ctaKey = Key('telemetry_notice_cta');

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final TextStyle body = AppType.body.copyWith(color: c.textSecondary);
    final TextStyle strong = AppType.body
        .copyWith(color: c.textPrimary, fontWeight: FontWeight.w700);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.screenMargin,
          Space.sm,
          Space.screenMargin,
          Space.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Grabber (same pattern as the source sheet).
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(
              l10n.telemetryNoticeTitle,
              style: AppType.title.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.md),
            // "Tu foto no sale del móvil." — the strong, still-true D2 claim.
            Text.rich(TextSpan(children: <InlineSpan>[
              TextSpan(text: l10n.telemetryNoticeBody1Strong, style: strong),
              const TextSpan(text: ' '),
              TextSpan(text: l10n.telemetryNoticeBody1Rest, style: body),
            ])),
            const SizedBox(height: Space.md),
            // The honest telemetry split + the opt-out pointer.
            Text.rich(TextSpan(children: <InlineSpan>[
              TextSpan(text: l10n.telemetryNoticeBody2Intro, style: body),
              const TextSpan(text: ' '),
              TextSpan(text: l10n.telemetryNoticeBody2Strong, style: strong),
              const TextSpan(text: ' '),
              TextSpan(text: l10n.telemetryNoticeBody2Rest, style: body),
            ])),
            const SizedBox(height: Space.lg),
            PkPrimaryButton(
              key: ctaKey,
              label: l10n.telemetryNoticeCta,
              onPressed: () => Navigator.of(context).pop(),
            ),
            // Secondary link → privacy policy. Hidden until a policy URL is
            // baked into the build (no dead links in the legal surface).
            if (kPrivacyPolicyUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: Space.sm),
              Center(
                child: TextButton(
                  onPressed: _openPrivacyPolicy,
                  child: Text(
                    l10n.telemetryNoticeLink,
                    style: AppType.caption.copyWith(color: c.action),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> _openPrivacyPolicy() async {
    try {
      await launchUrl(Uri.parse(kPrivacyPolicyUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      // A dead link must never crash the notice.
    }
  }
}
