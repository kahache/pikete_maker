import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/onboarding/onboarding_service.dart';
import '../../theme/app_motion.dart';
import '../../theme/dimens.dart';
import 'widgets/onboarding_keys.dart';
import 'widgets/pro_tip_page.dart';
import 'widgets/progress_dots.dart';
import 'widgets/skip_link.dart';
import 'widgets/welcome_page.dart';

/// Step 2 of D12 · F13 tutorial (onboarding-tutorial.md).
///
/// Two pages in a [PageView]: ONB-1 Welcome + ONB-2 Pro tip. Skippable from
/// both (low-hierarchy "Saltar" link). The `onboardingSeen` flag is set on
/// completing OR skipping; it never repeats. 2-dot indicator (skeleton §2:
/// communicates "this is short").
///
/// Exits (onboarding-tutorial §1.3) — the tutorial ALWAYS lives on top of the
/// Home, so it exits with `pop(result)` and the Home decides:
///  - "Hacer mi primera foto" → pop([resultTakePhoto]) → the Home opens the
///    source sheet (the user is warmed up: shoot, not explore).
///  - "Saltar" → pop(null) → stays on Home (wants to explore).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onboarding});

  /// Route result: the user wants to take their first photo NOW.
  static const bool resultTakePhoto = true;

  /// Test keys of the ONB-1 stacked brand block (#51, option E3). The values
  /// live in [OnboardingKeys] so the extracted pages can use them without
  /// importing this screen back.
  static const Key brandSymbolKey = OnboardingKeys.brandSymbol;
  static const Key brandWordmarkKey = OnboardingKeys.brandWordmark;

  /// Test key of tutorial phrase [index] (#53 highlight loop).
  static Key tipTextKey(int index) => OnboardingKeys.tipText(index);

  final OnboardingService onboarding;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    await widget.onboarding.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop(); // no result: the Home chains nothing
  }

  Future<void> _takeFirstPhoto() async {
    await widget.onboarding.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop(OnboardingScreen.resultTakePhoto);
  }

  void _nextPage() {
    _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.standard);
  }

  /// System back (gesture / button) is a third way out and means the same as
  /// "Saltar": the spec sets the flag on completing OR skipping, so the
  /// tutorial never repeats (review F9 — before this, back left the flag unset
  /// and the tutorial + `first_launch` came back on every cold start). The
  /// route still pops normally; the flag is persisted fire-and-forget because
  /// nothing downstream waits on it (the Home only reads it on a cold start).
  /// It also fires after the explicit exits' own pop, which is harmless:
  /// [OnboardingService.markSeen] is idempotent.
  void _onPop(bool didPop, Object? result) {
    if (didPop) unawaited(widget.onboarding.markSeen());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      onPopInvokedWithResult: _onPop,
      child: _buildTutorial(context),
    );
  }

  Widget _buildTutorial(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            PageView(
              controller: _controller,
              onPageChanged: (int i) => setState(() => _page = i),
              children: <Widget>[
                WelcomePage(onStart: _nextPage),
                ProTipPage(onTakePhoto: _takeFirstPhoto),
              ],
            ),
            // 2-dot indicator, centered on top (active pill in action).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: Sizes.touchTargetMin,
                  child: Center(child: ProgressDots(active: _page)),
                ),
              ),
            ),
            // Persistent "Saltar" link at the top right (low hierarchy).
            Positioned(
              top: 0,
              right: Space.sm,
              child: SkipLink(onTap: _skip),
            ),
          ],
        ),
      ),
    );
  }
}
