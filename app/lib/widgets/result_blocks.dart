import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';

/// Result-screen building blocks SHARED by the outfit result (F4/D12) and the
/// sneaker result (F11/D27). Extracted verbatim from
/// `features/result/result_screen.dart` when the sneaker spec's reuse table
/// (§7) required the same components on both screens — widget trees are
/// unchanged, only their visibility.

/// Swatch strip of a harmony scheme (132×44, hairline ring).
class SwatchStrip extends StatelessWidget {
  const SwatchStrip({super.key, required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      width: 132,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.border),
      ),
      child: Row(
        // stretch: a childless ColoredBox has no intrinsic size; with the
        // default `center` alignment the loose cross constraint collapses it
        // to height 0 and the strip renders BLANK (bug seen on device, r3).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final Color color in colors)
            Expanded(child: ColoredBox(color: color)),
        ],
      ),
    );
  }
}

/// Canvas mode (D10, #21): the wrap of curated accent "pops" proposed for a
/// 100% neutral subject. Same component on the outfit result's canvas section
/// and on the sneaker result's canvas state (spec §5).
///
/// F5 v0 (#82): a pop is SELECTABLE when [onAccentTap] is provided — the
/// selected one carries an action-color ring + white check and parameterizes
/// the "Ver looks así" query ("outfit negro, blanco y rojo").
class CanvasAccentsWrap extends StatelessWidget {
  const CanvasAccentsWrap({
    super.key,
    required this.accents,
    this.selectedIndex,
    this.onAccentTap,
  });

  final List<Color> accents;

  /// Index of the selected pop within [accents]; null = none selected.
  final int? selectedIndex;

  /// Selection callback (#82). Null → plain, non-interactive swatches.
  final ValueChanged<int>? onAccentTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.md,
      children: <Widget>[
        for (int i = 0; i < accents.length; i++)
          _AccentPop(
            color: accents[i],
            selected: i == selectedIndex,
            onTap: onAccentTap == null ? null : () => onAccentTap!(i),
          ),
      ],
    );
  }
}

/// One curated accent "pop": a swatch that, when tappable, parameterizes
/// F5-lite (#82) with that color.
class _AccentPop extends StatelessWidget {
  const _AccentPop({required this.color, required this.selected, this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  /// Selected ring width (the pops are colored, so the selected state is an
  /// action-color RING + white check, not the fill+white-text of the scheme
  /// chips — the fill IS the content here).
  static const double _selectedRingWidth = 3;
  static const double _checkSize = 20;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Widget swatch = Container(
      width: Sizes.touchTargetMin,
      height: Sizes.touchTargetMin,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: selected
            ? Border.all(color: c.action, width: _selectedRingWidth)
            : Border.all(color: c.border),
      ),
      child: selected
          ? Icon(Icons.check, size: _checkSize, color: c.actionOnFill)
          : null,
    );
    if (onTap == null) return swatch;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: swatch,
    );
  }
}

/// Selectable-scheme name chip (F5 v0, #82): the harmony name reads as plain
/// heading text until its row is selected, when it fills with the ACTION
/// color and flips to white ink — the CEO's spec verbatim ("action-color fill
/// with white text"). Padding is constant in both states so selecting never
/// shifts the row layout.
class SchemeNameChip extends StatelessWidget {
  const SchemeNameChip(
      {super.key, required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? c.action : null,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: AppType.heading
            .copyWith(color: selected ? c.actionOnFill : c.textPrimary),
      ),
    );
  }
}

/// Watermark: the accent signs the shareable card (one of purple's 2 doses).
class BrandWatermark extends StatelessWidget {
  const BrandWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Align(
      alignment: Alignment.centerRight,
      child: Text.rich(
        TextSpan(
          style: AppType.caption.copyWith(
            color: c.textDisabled,
            fontWeight: FontWeight.w700,
          ),
          children: <TextSpan>[
            const TextSpan(text: 'piketemaker'),
            TextSpan(text: '.', style: TextStyle(color: c.accent)),
          ],
        ),
      ),
    );
  }
}

/// Short date as in the mockups ("11 jul 2026") without the `intl` package
/// (gate G1). Month abbreviations are Spanish UI copy.
String shortSpanishDate(DateTime date) {
  const List<String> months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Month abbreviations per Latin locale (i18n round, D18 extended). Deliberate
/// NON-use of `intl.DateFormat`: CLDR's es abbreviations carry a trailing dot
/// ("jul.", "sept.") that would break the byte-identical es guarantee, and a
/// 12-entry table per locale is cheaper than dragging ICU data into the
/// result screens. CJK locales use numeric patterns instead (below).
const Map<String, List<String>> _shortMonths = <String, List<String>>{
  'en': <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ],
  'ca': <String>[
    'gen',
    'febr',
    'març',
    'abr',
    'maig',
    'juny',
    'jul',
    'ag',
    'set',
    'oct',
    'nov',
    'des',
  ],
  'fr': <String>[
    'janv',
    'févr',
    'mars',
    'avr',
    'mai',
    'juin',
    'juil',
    'août',
    'sept',
    'oct',
    'nov',
    'déc',
  ],
};

/// The share-canvas date in the ACTIVE locale ("14 jul 2026", "Jul 14, 2026",
/// "2026年7月14日", "2026년 7월 14일"). [language] is a `l10n.localeName`
/// value; unknown languages fall back to canonical es (same rule as the
/// color vocabulary). The es path IS [shortSpanishDate] — byte-identical.
String localizedShortDate(DateTime date, String language) {
  final String lang = language.split(RegExp('[_-]')).first;
  switch (lang) {
    case 'en':
      return '${_shortMonths['en']![date.month - 1]} ${date.day}, ${date.year}';
    case 'ca':
    case 'fr':
      return '${date.day} ${_shortMonths[lang]![date.month - 1]} ${date.year}';
    case 'zh':
    case 'ja':
      return '${date.year}年${date.month}月${date.day}日';
    case 'ko':
      return '${date.year}년 ${date.month}월 ${date.day}일';
    default:
      return shortSpanishDate(date);
  }
}
