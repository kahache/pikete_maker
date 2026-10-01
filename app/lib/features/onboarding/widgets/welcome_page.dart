import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/logo_mark.dart';
import '../../../widgets/pk_buttons.dart';
import 'onboarding_keys.dart';

/// ONB-1 · Welcome. Zero purple accent (reserved). Mint only on the CTA.
///
/// Brand presence per CEO pick E3 on the r5-visual-decisions sheet (#51):
/// big symbol + wordmark stacked below, centered — "solo logo y bien
/// grande". The headline stays the text hero (CEO's word, sheet §2a). The
/// flex spacers around the block give it well over the USAGE.md §3
/// clearspace (the piquete's diameter, ~21% of symbol height ≈ 24 px here).
///
/// Internal to the `onboarding` feature.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onStart});

  final VoidCallback onStart;

  /// Symbol side — #58b (CEO pick 2026-07-10): 112 → 128 px. The trio below
  /// scales together (×1.143) to freeze the 61% wordmark ratio (USAGE §4).
  static const double _symbolSize = 128;

  /// Gap between symbol and wordmark inside the stacked block (#58b: 18 → 20).
  static const double _brandGap = 20;

  /// Wordmark font size — #58b: 27 → 31, keeps the 61% cap-height ratio and
  /// stays just under the 32 px headline so it does not dethrone the text hero.
  static const double _wordmarkFontSize = 31;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screenMargin,
        Space.xxxl,
        Space.screenMargin,
        Space.thumbZoneCta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LogoMark(
                  key: OnboardingKeys.brandSymbol,
                  size: _symbolSize,
                ),
                SizedBox(height: _brandGap),
                LogoWordmark(
                  key: OnboardingKeys.brandWordmark,
                  fontSize: _wordmarkFontSize,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            context.l10n.onbWelcomeHeadline,
            style: AppType.display.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: Space.md),
          Text(
            context.l10n.onbWelcomeBody,
            style: AppType.body.copyWith(color: c.textSecondary),
          ),
          const Spacer(flex: 2),
          PkPrimaryButton(
              label: context.l10n.onbWelcomeCta, onPressed: onStart),
          // #95 (CEO): photo-privacy reassurance UP FRONT, at app start —
          // the two promises (stays on-device + not stored) sit under the
          // start CTA so the user reads them before ever handing over a photo.
          // Text-only caption (D7 radical simplicity, no new color dose).
          const SizedBox(height: Space.md),
          Text(
            context.l10n.onbWelcomePrivacy,
            style: AppType.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}
