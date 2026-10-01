import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import 'flow_mode.dart';
import 'photo_picker.dart';

/// PHOTO SOURCE sheet (step 3 of D12, spec in
/// docs/design/2026-07-07_1434_F1_esqueleto-5-pantallas.md §3; sneaker copy
/// map per the Phase 2S final spec §3 — same layout, mode-keyed strings).
///
/// Bottom sheet over a tinted scrim (D9): title + on-device privacy
/// reinforcement (D15) + 2 large options + plain-background hint (F13 safety
/// net for whoever skipped the tutorial).
///
/// Returns the chosen [PhotoSource], or `null` if the user closed the sheet.
Future<PhotoSource?> showPhotoSourceSheet(
  BuildContext context, {
  FlowMode mode = FlowMode.outfit,
}) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    barrierColor: context.colors.scrim,
    builder: (BuildContext sheetContext) =>
        _PhotoSourceSheet(copy: FlowCopy.of(mode, sheetContext.l10n)),
  );
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet({required this.copy});

  final FlowCopy copy;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
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
            // Grabber.
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
              copy.sheetTitle,
              style: AppType.title.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.xs),
            // Reinforces privacy + on-device (D15) right where the user hands
            // over the photo.
            Text(
              context.l10n.privacyNote,
              style: AppType.caption.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: Space.lg),
            _SourceOption(
              icon: Icons.photo_camera_outlined,
              title: context.l10n.sheetCameraTitle,
              subtitle: copy.sheetCameraCaption,
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            const SizedBox(height: Space.md),
            _SourceOption(
              icon: Icons.photo_library_outlined,
              title: context.l10n.sheetGalleryTitle,
              subtitle: copy.sheetGalleryCaption,
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
            const SizedBox(height: Space.lg),
            // F13 hint: band in action.tint, text in action ink.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              decoration: BoxDecoration(
                color: c.actionTint,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                context.l10n.sheetPlainBgHint,
                style: AppType.caption.copyWith(
                  color: c.action,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Option row of the sheet: 2 large targets (≥64px), icon on action tint,
/// mint chevron (whatever is tappable is always in action, D8).
class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Row height per the sheet spec (§3, "fila 64px").
  static const double _rowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.actionTint,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, size: 22, color: c.action),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: AppType.heading.copyWith(color: c.textPrimary)),
                  Text(subtitle,
                      style: AppType.caption.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.action),
          ],
        ),
      ),
    );
  }
}
