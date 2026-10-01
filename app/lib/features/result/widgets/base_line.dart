import 'package:flutter/material.dart';

import '../../../core/color_engine/models.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';

/// Base color line (D5). BASE badge in ACCENT (purple) — 1st of its 2 doses.
///
/// [attribution] (Phase 2.5, U3): one honest sentence naming the garment the
/// global base came from ("Sale de tu parte de arriba. "), inserted between
/// the bold lead and the closing line. Null (legacy / S3 / S4) keeps today's
/// copy verbatim.
///
/// Internal to the `result` feature.
class BaseLine extends StatelessWidget {
  const BaseLine({super.key, required this.base, this.attribution});

  final ColorSample base;

  final String? attribution;

  /// Diameter of the leading color dot.
  static const double _dotSize = 28;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      padding: const EdgeInsets.only(top: Space.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: base.color,
              shape: BoxShape.circle,
              border: Border.all(color: c.borderStrong),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accentTint,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Text(context.l10n.resultBaseBadge,
                      style: AppType.label.copyWith(color: c.accent)),
                ),
                const SizedBox(height: Space.xs),
                Text.rich(
                  TextSpan(
                    style: AppType.caption.copyWith(color: c.textSecondary),
                    children: <TextSpan>[
                      TextSpan(
                        text: context.l10n.resultBaseLead,
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      if (attribution != null) TextSpan(text: attribution),
                      TextSpan(text: context.l10n.resultBaseRest),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
