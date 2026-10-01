import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../routing/app_routes.dart';
import '../feedback/feedback_screen.dart';
import '../sneaker/sneaker_source_selector.dart';
import '../sneaker/sneaker_tip_illustrations.dart';
import 'flow_mode.dart';
import 'photo_picker.dart';
import 'photo_source_sheet.dart';

/// A photo the user just picked, plus where it came from.
@immutable
class PickedPhoto {
  const PickedPhoto(this.bytes, {this.sneakerSituation});

  /// Encoded bytes (JPEG) from the picker.
  final Uint8List bytes;

  /// Sneaker mode only: the situation card the user picked (casa / tienda /
  /// web screenshot). Null in outfit mode. N1 / D37: a web screenshot is a
  /// third party's image, so the story preview opens with the photo OFF.
  final SneakerTipCase? sneakerSituation;
}

/// Orchestrates "pick a photo": choose source → picker → (E1 if needed).
///
/// Shared by BOTH Home zones (D26: "Mis zapas" passes [FlowMode.sneaker],
/// "Mi pikete" the default), the tutorial exit ("Hacer mi primera foto") and
/// the retake of the confirm screen. The E1 resolution below is mode-agnostic
/// by spec ("identical reuse of outfit ugly states; no sneaker-specific
/// variants").
///
/// How the source is chosen depends on the mode:
///  - OUTFIT → the camera/gallery source sheet (unchanged).
///  - SNEAKER (#83, CEO flow-merge) → the situation SELECTOR, which folds the
///    source question into the coaching card and, on the way, shows a
///    situation-specific mini-tutorial whose CTA is the capture trigger. It
///    fires `sneaker_source_selected` when a card is tapped, so it needs
///    [analytics].
///
/// Returns the photo (bytes + sneaker situation), or `null` if the user
/// cancelled at any point (goes back to where they were, user-flows §1: "no
/// photo chosen → back to home").
Future<PickedPhoto?> pickPhotoWithSource(
  BuildContext context,
  PhotoPicker picker, {
  FlowMode mode = FlowMode.outfit,
  AnalyticsService? analytics,
}) async {
  final PhotoSource? source;
  SneakerTipCase? situation;
  if (mode == FlowMode.sneaker) {
    final SneakerSourceChoice? choice =
        await Navigator.of(context).push<SneakerSourceChoice>(
      MaterialPageRoute<SneakerSourceChoice>(
        builder: (BuildContext _) =>
            SneakerSourceSelectorScreen(analytics: analytics),
      ),
    );
    source = choice?.source;
    situation = choice?.situation;
  } else {
    source = await showPhotoSourceSheet(context, mode: mode);
  }
  if (source == null || !context.mounted) return null;

  Uint8List? bytes;
  try {
    bytes = await picker.pick(source);
  } on CameraPermissionDeniedException {
    if (!context.mounted) return null;
    bytes = await _resolvePermissionDenied(context, picker);
  }
  return bytes == null ? null : PickedPhoto(bytes, sneakerSituation: situation);
}

/// E1 · camera permission denied (user-flows §2).
///
/// We never re-ask in a loop: we go straight to the ugly-state template with
/// the gallery ALWAYS visible as alternative. If the user picks the gallery
/// from E1 and the photo comes out, E1 closes returning it to the normal
/// flow.
Future<Uint8List?> _resolvePermissionDenied(
  BuildContext context,
  PhotoPicker picker,
) async {
  // NavigatorState captured BEFORE: the callbacks run when this context may
  // be covered by the feedback route. Same for the localized settings path.
  final NavigatorState nav = Navigator.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String settingsPath = context.l10n.feedbackCameraSettingsPath;

  final Object? result = await nav.pushNamed(
    AppRoutes.feedback,
    arguments: FeedbackArgs(
      state: UglyState.cameraPermission,
      // DECIDED (#34, UX audit point b): no settings plugin in the demo APK
      // (zero extra native deps while E1 is near-unreachable on Android — the
      // system camera needs no app-side permission). The CTA is labeled
      // "Cómo activarla" and delivers exactly that: the manual path below.
      onPrimary: () => messenger.showSnackBar(
        SnackBar(content: Text(settingsPath)),
      ),
      onSecondary: () async {
        final Uint8List? bytes = await picker.pick(PhotoSource.gallery);
        if (bytes != null) nav.pop(bytes); // closes E1 with the photo
      },
    ),
  );
  return result is Uint8List ? result : null;
}
