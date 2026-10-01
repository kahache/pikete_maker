import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';

/// "Saltar" link — caption/textTertiary, 44px touch target (onboarding §6).
///
/// Internal to the `onboarding` feature.
class SkipLink extends StatelessWidget {
  const SkipLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: Sizes.touchTargetMin,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Center(
            child: Text(
              context.l10n.onbSkip,
              style:
                  AppType.caption.copyWith(color: context.colors.textTertiary),
            ),
          ),
        ),
      ),
    );
  }
}
