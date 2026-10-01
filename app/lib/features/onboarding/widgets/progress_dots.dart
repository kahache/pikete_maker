import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/dimens.dart';

/// Sequence indicator of 2 (esqueleto-5-pantallas §2): reinforces brevity.
///
/// Internal to the `onboarding` feature.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.active});

  final int active;

  static const int _total = 2;
  static const double _dotSize = 6;
  static const double _activeWidth = 20;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < _total; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: Space.sm),
          AnimatedContainer(
            duration: AppMotion.base,
            width: i == active ? _activeWidth : _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: i == active ? c.action : c.borderStrong,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
        ],
      ],
    );
  }
}
