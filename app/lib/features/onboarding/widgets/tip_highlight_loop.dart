import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import 'onboarding_keys.dart';

/// The 3 tutorial phrases — #53, CEO pick "b, IN LOOP" (r5-visual-decisions
/// sheet §3): an animated highlight walks the phrases one by one in the
/// reading order that matters (wall → whole fit → light). The active phrase
/// is bold + `textPrimary` with a mint check; the others are `textSecondary`
/// regular with a dimmed check. Each phrase stays lit [phraseDwell] (~2 s),
/// the on/off transition is `motion.base` (200 ms) with `easing.enter`, and
/// the cycle LOOPS continuously while the user stays on the screen (CEO
/// addition — the sheet's live-demo behavior). Nothing moves — only color
/// and weight, so it does not fight D7 and never blocks the CTA.
///
/// MANDATORY degradation (sheet §3 rationale): with
/// `MediaQuery.disableAnimations` (reduced motion) it renders option (a) —
/// all phrases bold, static, zero motion, no ticker.
///
/// Internal to the `onboarding` feature.
class TipHighlightLoop extends StatefulWidget {
  const TipHighlightLoop({super.key});

  /// Number of phrases (the ticker's modulus). The phrases themselves come
  /// from the ARB in the reading order that matters: wall → whole fit →
  /// light ([phrasesOf]).
  static const int phraseCount = 3;

  /// Localized phrases, order preserved (i18n round — was a static const
  /// ES list before the extraction).
  static List<String> phrasesOf(AppLocalizations l10n) => <String>[
        l10n.onbTipPhraseWall,
        l10n.onbTipPhraseFullFit,
        l10n.onbTipPhraseLight,
      ];

  /// How long each phrase stays lit (sheet: ~2 s per phrase, 6 s cycle).
  static const Duration phraseDwell = Duration(seconds: 2);

  @override
  State<TipHighlightLoop> createState() => _TipHighlightLoopState();
}

class _TipHighlightLoopState extends State<TipHighlightLoop> {
  static const double _checkSize = 18;

  Timer? _timer;
  int _active = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // (Re)decide the ticker against the accessibility setting. Reduced
    // motion → no timer at all: static option (a).
    _timer?.cancel();
    _timer = null;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(TipHighlightLoop.phraseDwell, (_) {
        // Continuous loop: 0 → 1 → 2 → 0 → … while the screen is visible.
        setState(
          () => _active = (_active + 1) % TipHighlightLoop.phraseCount,
        );
      });
    }
  }

  @override
  void dispose() {
    // Never leave the ticker running after leaving the screen.
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final List<String> phrases = TipHighlightLoop.phrasesOf(context.l10n);
    final bool isStatic = _timer == null; // reduced motion → option (a)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < phrases.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: _tip(
              i,
              phrase: phrases[i],
              colors: c,
              on: isStatic || i == _active,
              animated: !isStatic,
            ),
          ),
      ],
    );
  }

  Widget _tip(
    int index, {
    required String phrase,
    required AppColors colors,
    required bool on,
    required bool animated,
  }) {
    // Sheet palette: active check = action mint; dimmed check = borderStrong.
    final Color checkColor = on ? colors.action : colors.borderStrong;
    final TextStyle style = AppType.body.copyWith(
      color: on ? colors.textPrimary : colors.textSecondary,
      fontWeight: on ? FontWeight.w600 : FontWeight.w400,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (animated)
          // Implicitly animates towards the new target color each time the
          // highlight moves (200 ms, enter curve). Disposes with the widget.
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(begin: checkColor, end: checkColor),
            duration: AppMotion.base,
            curve: AppMotion.enter,
            builder: (BuildContext _, Color? color, Widget? __) =>
                Icon(Icons.check_circle, size: _checkSize, color: color),
          )
        else
          Icon(Icons.check_circle, size: _checkSize, color: checkColor),
        const SizedBox(width: Space.sm),
        Expanded(
          child: animated
              ? AnimatedDefaultTextStyle(
                  key: OnboardingKeys.tipText(index),
                  duration: AppMotion.base,
                  curve: AppMotion.enter,
                  style: style,
                  child: Text(phrase),
                )
              : Text(
                  phrase,
                  key: OnboardingKeys.tipText(index),
                  style: style,
                ),
        ),
      ],
    );
  }
}
