import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/onboarding/onboarding_service.dart';
import '../../core/telemetry/telemetry_controller.dart';
import '../../l10n/l10n.dart';
import '../../routing/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/logo_mark.dart';
import '../../widgets/mode_glyphs.dart';
import '../capture/capture_screen.dart';
import '../capture/flow_mode.dart';
import '../capture/photo_flow.dart';
import '../capture/photo_picker.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/telemetry_notice_sheet.dart';
import 'widgets/home_keys.dart';
import 'widgets/mode_zone.dart';
import 'widgets/zone_divider.dart';

/// Split Home (Phase 2S · D26, Variant A "50/50 vertical", tint-wash version).
///
/// Two equal full-height tappable zones, dead-equal weight (D24: the two
/// modes are co-equal wedges; G2 reads which one resonates):
///  - TOP · "Mis zapas" (`mint.tint` wash) → sneaker/product mode (F11).
///  - BOTTOM · "Mi pikete" (`purple.tint` wash) → the existing outfit flow,
///    unchanged downstream (source sheet → capture → analyzing → result).
///
/// The bottom label is **"Mi pikete"** per D27 (2026-07-11), which amends
/// D26's "Mi fit" — the 2026-07-10 mockup is an immutable snapshot; the ADR
/// row is canonical. The half-screen `purple.tint` wash is a D8 exception
/// RATIFIED by D26 (no user content on this screen to compete; it stays a
/// tint, never a full accent).
///
/// What survives from the pre-2S Home (spec §1): the discreet top lockup, the
/// tutorial re-entry icon (top-right, out of the thumb path) and the
/// first-launch onboarding gate (user-flows §0). The 120 px hero mark does
/// NOT survive — Variant A sheds it by design ("the two zones ARE the
/// screen"); brand identity lives in the top lockup only.
///
/// #81 polish (CEO r8 on-device review, 2026-07-11): the two content blocks
/// are pulled TOWARD the center divider (top zone bottom-aligned, bottom zone
/// top-aligned) so they read as mirrored around the middle of the screen —
/// before, each block floated at its zone's center and "Mi pikete" read as
/// hugging the bottom edge. The "Empezar ›" affordance grew from a 13 px
/// caption pinned to the zone's bottom edge into a 44 px outlined pill inside
/// the block (same zone ink, no new color dose — D8 intact).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onboarding,
    required this.picker,
    this.analytics,
    this.telemetry,
  });

  final OnboardingService onboarding;
  final PhotoPicker picker;
  final AnalyticsService? analytics;

  /// D33 telemetry (nullable like [analytics]). When ACTIVE (an endpoint was
  /// baked into the build) the Home grows two things: the first-run NOTICE
  /// (legal doc §2, shown once after the onboarding gate) and the discreet
  /// "Ajustes" entry in the top bar (the opt-out lives there, §3). Inert or
  /// absent ⇒ neither exists and the screen is byte-identical to r10.
  final TelemetryController? telemetry;

  /// Test keys. The values live in [HomeKeys] so the extracted zone widgets
  /// can use them without importing this screen back.
  static const Key sneakerZoneKey = HomeKeys.sneakerZone;
  static const Key outfitZoneKey = HomeKeys.outfitZone;

  /// Test key of the "Empezar ›" pill (#81) — one per zone.
  static const Key goPillKey = HomeKeys.goPill;

  /// Test key of the "Ajustes" top-bar entry (telemetry-active builds only).
  static const Key settingsButtonKey = HomeKeys.settingsButton;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Lockup height in the slim top bar. Bumped 18 → 24 (#94 item 1, CEO
  /// 2026-07-19, the "more assertive" option): the brand mark now out-weighs
  /// the 28 px help glyph across the bar without competing with the two zones.
  /// The lockup stays shorter than the help icon, so the top-bar row height is
  /// unchanged — the logo grows into space that already exists.
  static const double _lockupHeight = 24;

  /// Size of the top-bar glyphs (help, settings).
  static const double _topBarIconSize = 28;

  /// `mode` param values of the `mode_selected` event (G2 funnel).
  static const String _modeSneaker = 'sneaker';
  static const String _modeOutfit = 'outfit';

  @override
  void initState() {
    super.initState();
    // After the first frame: decide whether the tutorial is due (first launch).
    WidgetsBinding.instance.addPostFrameCallback((_) => _gateOnboarding());
  }

  Future<void> _gateOnboarding() async {
    final bool seen = await widget.onboarding.seen();
    // Launch signal (#4): first ever open vs. a return visit (retention).
    widget.analytics?.log(AnalyticsEvent(
        seen ? AnalyticsEvents.appReopened : AnalyticsEvents.firstLaunch));
    if (mounted && !seen) await _openTutorial();
    // D33 first-run notice, AFTER the tutorial gate resolves: it must not
    // fight the onboarding for the first impression, and ONB-1 deliberately
    // carries no telemetry claim (#95/#96 split). Nothing is flushed until
    // the notice was shown (controller gate), so the ordering is safe.
    await _maybeShowTelemetryNotice();
  }

  /// Shows the one-time telemetry notice when due (telemetry active + not
  /// opted out + never shown). Swipe-dismiss counts as seen: it is a NOTICE,
  /// not a consent gate (legal doc §2).
  Future<void> _maybeShowTelemetryNotice() async {
    final TelemetryController? telemetry = widget.telemetry;
    if (telemetry == null || !telemetry.active) return;
    if (!await telemetry.shouldShowNotice() || !mounted) return;
    await showTelemetryNoticeSheet(context);
    await telemetry.markNoticeSeen();
  }

  /// Opens the F13 tutorial. If it exits via "Hacer mi primera foto"
  /// (result == true, onboarding-tutorial §1.3: "the user is warmed up"), it
  /// chains straight into the OUTFIT source sheet (the tutorial teaches the
  /// outfit photo); if it exits via "Saltar", it stays on Home. The chain is
  /// not a Home zone tap, so it does NOT fire `mode_selected` — that event
  /// measures explicit picks on the split (G2).
  Future<void> _openTutorial() async {
    final Object? result =
        await Navigator.of(context).pushNamed(AppRoutes.onboarding);
    if (!mounted) return;
    if (result == OnboardingScreen.resultTakePhoto) {
      await _startFlow(FlowMode.outfit);
    }
  }

  /// "Mis zapas" → the F11 sneaker flow (Phase 2S final spec): same source
  /// sheet → confirm skeleton as outfit, sneaker copy map + product-mode
  /// engine downstream.
  Future<void> _onSneakerZoneTap() async {
    widget.analytics?.log(const AnalyticsEvent(
      AnalyticsEvents.modeSelected,
      <String, Object?>{'mode': _modeSneaker},
    ));
    await _startFlow(FlowMode.sneaker);
  }

  /// "Mi pikete" → the existing outfit flow, unchanged.
  Future<void> _onOutfitZoneTap() async {
    widget.analytics?.log(const AnalyticsEvent(
      AnalyticsEvents.modeSelected,
      <String, Object?>{'mode': _modeOutfit},
    ));
    await _startFlow(FlowMode.outfit);
  }

  /// D12 critical path entry, mode-parameterized (Phase 2S): source sheet →
  /// picker → confirm photo. The mode rides the CaptureArgs downstream.
  Future<void> _startFlow(FlowMode mode) async {
    final PickedPhoto? photo = await pickPhotoWithSource(
      context,
      widget.picker,
      mode: mode,
      analytics: widget.analytics,
    );
    if (!mounted || photo == null) return; // cancelled → stays on Home
    await Navigator.of(context).pushNamed(
      AppRoutes.capture,
      arguments: CaptureArgs(
        photo: photo.bytes,
        mode: mode,
        sneakerSituation: photo.sneakerSituation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      // bottom: false → the purple wash bleeds to the screen edge (mockup);
      // each zone re-adds the bottom inset to its own affordance.
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Slim top bar: discreet lockup + tutorial re-entry (44px target).
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.screenMargin,
                vertical: Space.sm,
              ),
              child: Row(
                children: <Widget>[
                  const LogoLockup(height: _lockupHeight),
                  const Spacer(),
                  // "Ajustes" exists ONLY in telemetry-active builds (the
                  // opt-out home, legal doc §3). Endpoint empty ⇒ nothing is
                  // collected ⇒ no settings surface (D7 simplicity intact).
                  if (widget.telemetry?.active ?? false)
                    IconButton(
                      key: HomeScreen.settingsButtonKey,
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.settings),
                      tooltip: l10n.settingsTooltip,
                      icon: Icon(Icons.settings_outlined,
                          color: c.textTertiary, size: _topBarIconSize),
                    ),
                  IconButton(
                    onPressed: _openTutorial,
                    tooltip: l10n.homeTutorialTooltip,
                    icon: Icon(Icons.help_outline,
                        color: c.textTertiary, size: _topBarIconSize),
                  ),
                ],
              ),
            ),
            // ZONE 1 · Mi pikete (purple.tint wash — the D26-ratified D8
            // exception; label per D27). On top since 2026-09-30 (CEO: the
            // outfit pikete + "Vérmelo puesto" is now the app's best part).
            Expanded(
              child: ModeZone(
                key: HomeScreen.outfitZoneKey,
                background: c.accentTint,
                ink: c.accent,
                glyph:
                    ModeGlyph.tshirt(color: c.accent, size: ModeZone.glyphSize),
                label: l10n.homeOutfitLabel,
                caption: l10n.homeOutfitCaption,
                dividerBelow: true, // #81: block pulls DOWN toward the divider
                onTap: _onOutfitZoneTap,
              ),
            ),
            const ZoneDivider(),
            // ZONE 2 · Mis zapas (mint.tint wash; was on top per D26 until the
            // 2026-09-30 CEO swap).
            Expanded(
              child: ModeZone(
                key: HomeScreen.sneakerZoneKey,
                background: c.actionTint,
                ink: c.action,
                glyph: ModeGlyph.sneaker(
                    color: c.action, size: ModeZone.glyphSize),
                label: l10n.homeSneakerLabel,
                caption: l10n.homeSneakerCaption,
                dividerBelow: false, // #81: block pulls UP toward the divider
                onTap: _onSneakerZoneTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
