import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../routing/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import '../analyzing/analyzing_screen.dart';
import '../sneaker/sneaker_tip_illustrations.dart';
import 'cover_sized_memory_image.dart';
import 'flow_mode.dart';
import 'photo_flow.dart';
import 'photo_picker.dart';

/// Route arguments for [AppRoutes.capture].
@immutable
class CaptureArgs {
  const CaptureArgs({
    required this.photo,
    this.openSourceSheetOnEntry = false,
    this.mode = FlowMode.outfit,
    this.sneakerSituation,
  });

  /// Encoded bytes (JPEG) of the photo chosen before entering here.
  final Uint8List photo;

  /// Sneaker mode: the situation [photo] was taken in (N1 / D37 hand-off to
  /// the result's story preview). Null in outfit mode.
  final SneakerTipCase? sneakerSituation;

  /// Which flow this confirm serves (Phase 2S): swaps the copy map and rides
  /// downstream (analyzing engine + result screen). Default keeps every
  /// existing outfit call site untouched.
  final FlowMode mode;

  /// #47 (UX audit F-3): when arriving from an E3/E4 primary CTA ("Probar con
  /// otra foto" / "Hacer otra foto") the source sheet opens by itself — the
  /// user asked for ANOTHER photo, so showing only the one that just failed
  /// would cost an extra tap and contradict the headline. If the sheet is
  /// dismissed, Confirm with the previous photo is the sensible fallback.
  final bool openSourceSheetOnEntry;
}

/// The confirm preview's image provider for a box of [logicalSize] on a
/// screen with [devicePixelRatio]: decodes at the physical box size (A5).
/// Public for the widget test that pins the DPR-aware sizing.
@visibleForTesting
CoverSizedMemoryImage previewImageFor(
  Uint8List photo,
  Size logicalSize,
  double devicePixelRatio,
) {
  // An unbounded axis (never the case inside the Expanded, but cheap to
  // guard) maps to 0, which coverDecodeSize reads as "decode at full size".
  int physical(double logical) =>
      logical.isFinite ? (logical * devicePixelRatio).ceil() : 0;
  return CoverSizedMemoryImage(
    photo,
    boxWidth: physical(logicalSize.width),
    boxHeight: physical(logicalSize.height),
  );
}

/// Step 3 of D12 · CONFIRM PHOTO ("¿Se ve bien tu fit?", user-flows §1).
///
/// A REAL photo arrives here, already chosen (camera or gallery, via the
/// source sheet). This screen exists because the cost of a bad analysis
/// (wait + ad) is higher than one extra tap: it is the last cheap exit.
///
///  - Analizar → step 4 (analyzing) with the photo bytes.
///  - Repetir  → reopens the source sheet (the new photo replaces this one).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.args,
    required this.picker,
    this.analytics,
  });

  final CaptureArgs args;

  final PhotoPicker picker;

  /// Threaded to the retake flow so the sneaker selector (#83) can fire
  /// `sneaker_source_selected` on "Otra foto"/"Otras zapas" retakes too.
  /// Optional: null → not recorded (outfit retake never touches the selector).
  final AnalyticsService? analytics;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late Uint8List _photo = widget.args.photo;

  /// The situation of [_photo]; a retake replaces both together.
  late SneakerTipCase? _situation = widget.args.sneakerSituation;

  @override
  void initState() {
    super.initState();
    if (widget.args.openSourceSheetOnEntry) {
      // Post-frame: the sheet needs this route to be laid out and current.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retake();
      });
    }
  }

  Future<void> _retake() async {
    final PickedPhoto? next = await pickPhotoWithSource(
      context,
      widget.picker,
      mode: widget.args.mode,
      analytics: widget.analytics,
    );
    if (!mounted || next == null) return; // cancelled: keeps the current one
    setState(() {
      _photo = next.bytes;
      _situation = next.sneakerSituation;
    });
  }

  void _analyze() {
    // First attempt for this photo → the ad slot participates (F8).
    Navigator.of(context).pushNamed(
      AppRoutes.analyzing,
      arguments: AnalyzingArgs(
        photo: _photo,
        mode: widget.args.mode,
        sneakerSituation: _situation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    // Mode copy map, resolved in the ACTIVE locale (i18n round).
    final FlowCopy copy = FlowCopy.of(widget.args.mode, context.l10n);
    return Scaffold(
      // Outfit: the wordmark. Sneaker: the contextual "MIS ZAPAS" kicker
      // (D27-Q6) — the app-bar theme already styles it as the label token.
      appBar: AppBar(title: Text(copy.appBarTitle)),
      body: SafeArea(
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
              Text(
                copy.confirmTitle,
                style: AppType.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.lg),
              // Real preview of the photo. The photo is the protagonist.
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) =>
                        Image(
                      // Decoded at the box's physical size, not the photo's
                      // full resolution (A5, review F14).
                      image: previewImageFor(
                        _photo,
                        box.biggest,
                        MediaQuery.devicePixelRatioOf(context),
                      ),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true, // no white flash on Repetir
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              // Persistent F13 hint (a reminder, not an order).
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.lightbulb_outline, size: 16, color: c.action),
                  const SizedBox(width: Space.xs),
                  // Flexible (i18n round): long-locale hints WRAP instead of
                  // overflowing the row; when the hint fits (es today) the
                  // layout is identical.
                  Flexible(
                    child: Text(
                      copy.confirmHint,
                      style: AppType.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              PkPrimaryButton(
                  label: copy.confirmCtaPrimary, onPressed: _analyze),
              const SizedBox(height: Space.md),
              PkSecondaryButton(
                  label: copy.confirmCtaSecondary, onPressed: _retake),
            ],
          ),
        ),
      ),
    );
  }
}
