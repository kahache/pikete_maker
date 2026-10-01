import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/dimens.dart';

/// PiketeMaker primary CTA: filled in action (mint), pill, 56px, full width.
/// The style lives in the theme (app_theme.dart); this only fixes the width
/// and the usage pattern so `SizedBox(width: double.infinity)` is not
/// repeated.
class PkPrimaryButton extends StatelessWidget {
  const PkPrimaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

/// Accent CTA: filled in accent (purple) with white text, same size and
/// shape as the primary. Exactly ONE use, by CEO decision (2026-09-30): the
/// "Súbela a tu story" CTA of the outfit result, between two mint CTAs
/// (Vérmelo puesto · Súbela a tu story · Ver looks así). A deliberate,
/// ratified exception to D8's "accent in minimal doses"; do not reuse it
/// elsewhere without a new decision. White on #6C3FD1 = 6.4:1 (AA).
class PkAccentButton extends StatelessWidget {
  const PkAccentButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.actionOnFill,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Tertiary CTA: a text button — `cta` 16/700 in action ink, no container,
/// full width with a 44 px touch target, label centred (N1 / D37: "Otras
/// zapas" under the two pills of the sneaker result).
class PkTextButton extends StatelessWidget {
  const PkTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.touchTargetMin),
          // Exactly 44 (not Material's padded 48): the spec's stack is
          // 56 + 12 + 56 + 4 + 44.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Secondary CTA: outline, text in action. Same size as the primary.
class PkSecondaryButton extends StatelessWidget {
  const PkSecondaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
