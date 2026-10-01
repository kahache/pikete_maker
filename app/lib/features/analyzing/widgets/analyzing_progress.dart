import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../capture/flow_mode.dart';

/// The honest progress zone of the analyzing screen: current step line, the
/// bar itself, and the mono label/percentage row.
///
/// Driven by the screen's progress [animation] — which doubles as the clock of
/// the #55 minimum-display window — and capped below 100% so the bar never
/// claims completion without a result (perceived honesty).
///
/// Internal to the `analyzing` feature.
class AnalyzingProgress extends StatelessWidget {
  const AnalyzingProgress({
    super.key,
    required this.animation,
    required this.copy,
    required this.cap,
  });

  final Animation<double> animation;

  /// Mode copy map (Phase 2S): supplies the localized step lines.
  final FlowCopy copy;

  /// Progress never shows 100% without a result.
  final double cap;

  static const double _barHeight = 6;
  static const double _barRadius = 3;
  static const int _percentScale = 100;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, _) {
        final double value = math.min(
          Curves.easeOutCubic.transform(animation.value),
          cap,
        );
        // Steps pace on the LINEAR clock (#55): with the eased value
        // all of them fired in the first second of the window.
        final List<String> steps = copy.analyzingSteps;
        final String step = steps[math.min(
          (animation.value * steps.length).floor(),
          steps.length - 1,
        )];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              step,
              style: AppType.caption.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(_barRadius),
              child: LinearProgressIndicator(
                value: value,
                minHeight: _barHeight,
                backgroundColor: c.actionTint,
                valueColor: AlwaysStoppedAnimation<Color>(c.actionBright),
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(context.l10n.analyzingMonoLabel,
                    style: AppType.dataMono.copyWith(color: c.textTertiary)),
                Text('${(value * _percentScale).round()}%',
                    style: AppType.dataMono.copyWith(
                        color: c.action, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        );
      },
    );
  }
}
