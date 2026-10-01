import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Hairline between the two zones. The mockup uses ink at 10% (not the
/// `border` token: it must read over BOTH tints), so it is DERIVED from
/// `textPrimary` instead of hardcoding a hex.
///
/// Internal to the `home` feature.
class ZoneDivider extends StatelessWidget {
  const ZoneDivider({super.key});

  static const double _thickness = 1;
  static const double _inkOpacity = 0.10; // mockup rgba(28,24,38,0.10)

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _thickness,
      color: context.colors.textPrimary.withValues(alpha: _inkOpacity),
    );
  }
}
