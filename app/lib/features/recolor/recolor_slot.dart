import 'package:flutter/material.dart';

import '../../core/recolor/recolor_service.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import 'recolor_target.dart';

/// The result screen's "Vérmelo puesto" slot (I2, D38 — UX §2.4): the FIRST
/// CTA of the bottom thumb-zone block, above "Súbela a tu story" and "Ver
/// looks así" (CEO amendment 2026-09-30, on device: under the card it sat
/// below the fold). Followed by the block's 12 px gap when shown.
///
///  - [pending] (the off-isolate assessment is running): the outlined pill,
///    DISABLED, at full size — nothing jumps when it enables;
///  - offered → the outlined pill, enabled;
///  - blocked for a teachable reason → the one-line caption tip, centred in
///    the same 56 px slot;
///  - no segmentation / refused ([availability] null and not pending) →
///    nothing at all (the block keeps its two other buttons).
class RecolorSlot extends StatelessWidget {
  /// Creates the slot.
  const RecolorSlot({
    super.key,
    required this.pending,
    required this.availability,
    required this.onPressed,
  });

  /// True while the assessment runs.
  final bool pending;

  /// The verdict, or null (not eligible / refused).
  final RecolorAvailability? availability;

  /// Opens the recolor view.
  final VoidCallback onPressed;

  /// Test keys.
  static const Key slotKey = Key('recolor_slot');
  static const Key pillKey = Key('recolor_pill');
  static const Key tipKey = Key('recolor_tip');

  @override
  Widget build(BuildContext context) {
    final AvailabilityView view = _view(context);
    if (view == AvailabilityView.none) return const SizedBox.shrink();
    final AppColors c = context.colors;
    final RecolorAvailability? a = availability;
    Widget child = const SizedBox.shrink();
    if (view == AvailabilityView.pill || view == AvailabilityView.reserved) {
      child = PkPrimaryButton(
        key: pillKey,
        label: context.l10n.recolorCta,
        onPressed: view == AvailabilityView.pill ? onPressed : null,
      );
    } else if (view == AvailabilityView.tip) {
      child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        child: Text(
          recolorTipFor(context.l10n, a!.blocker!)!,
          key: tipKey,
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: c.textTertiary),
        ),
      );
    }
    return Padding(
      key: slotKey,
      padding: const EdgeInsets.only(bottom: Space.md),
      child: ConstrainedBox(
        // The pill's height from the first frame (the tip's own minimum is
        // 44: it sits centred in the same 56).
        constraints: const BoxConstraints(minHeight: Sizes.ctaHeight),
        child: Center(child: child),
      ),
    );
  }

  AvailabilityView _view(BuildContext context) {
    if (pending) return AvailabilityView.reserved;
    final RecolorAvailability? a = availability;
    if (a == null) return AvailabilityView.none;
    if (a.isAvailable) return AvailabilityView.pill;
    final String? tip =
        a.blocker == null ? null : recolorTipFor(context.l10n, a.blocker!);
    return tip == null ? AvailabilityView.none : AvailabilityView.tip;
  }
}

/// What the slot shows (internal; visible for tests).
enum AvailabilityView {
  /// Assessment running: the pill, disabled.
  reserved,

  /// The "Vérmelo puesto" pill.
  pill,

  /// The one-line tip.
  tip,

  /// Nothing (the slot collapses).
  none,
}
