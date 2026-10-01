import 'package:flutter/material.dart';

import '../../sneaker/widgets/hero_combo_band.dart';

/// The photo story's band in CANVAS mode (100% neutral fit or kicks, D10;
/// spec §2.2): the five curated pops, equal widths, no tags.
///
/// If the user picked a pop on screen (#82), that pop takes [selectedShare]
/// (40%) of the band and carries [selectedTag] ("súmale"); the other pops
/// share the rest equally. What you picked is what you share.
class StoryCanvasBand extends StatelessWidget {
  const StoryCanvasBand({
    super.key,
    required this.accents,
    required this.height,
    this.selectedIndex,
    this.selectedTag,
  });

  final List<Color> accents;
  final double height;

  /// Index of the pop picked on screen, or null.
  final int? selectedIndex;

  /// Tag of the picked pop (already uppercased by the caller).
  final String? selectedTag;

  /// Share of the band the picked pop takes.
  static const double selectedShare = 0.40;

  /// Flex resolution for the share split (integer flexes for [Expanded]).
  static const int _flexScale = 1000;

  @override
  Widget build(BuildContext context) {
    final int n = accents.length;
    final int? picked =
        (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < n)
            ? selectedIndex
            : null;
    // With a pick: picked = 40%, the others split 60% equally.
    final int pickedFlex = (selectedShare * _flexScale).round();
    final int otherFlex = n > 1
        ? (((1 - selectedShare) * _flexScale) / (n - 1)).round()
        : _flexScale;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < n; i++)
            Expanded(
              flex: picked == null ? 1 : (i == picked ? pickedFlex : otherFlex),
              child: ComboSegment(
                color: accents[i],
                tag: i == picked ? selectedTag : null,
              ),
            ),
        ],
      ),
    );
  }
}
