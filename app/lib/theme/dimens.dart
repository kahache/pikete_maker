/// Spacing, radii and sizes — source: docs/design/tokens.json (space/radius/size).
///
/// Repo convention: magic numbers → named constants. No widget hardcodes a
/// padding or a radius; everything comes from here.
library;

import 'package:flutter/widgets.dart';

/// Spacing scale (base 4). tokens.json → space.scale.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32; // "2xl"
  static const double xxxl = 48; // "3xl"
  static const double xxxxl = 64; // "4xl"

  // Layout (space.layout)
  /// Side screen margin (viewport 390).
  static const double screenMargin = 20;

  /// Air between blocks. When in doubt, more air (minimalism).
  static const double sectionGap = 32;

  /// Minimum separation of the primary CTA from the bottom edge (thumb zone).
  static const double thumbZoneCta = 24;
}

/// Corner radii. tokens.json → radius.
abstract final class Radii {
  static const double sm = 8; // chips, small swatches
  static const double md = 14; // cards, harmony strips
  static const double lg = 20; // shareable card, ad slot, sheets
  static const double pill = 999; // buttons (always pill)

  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
}

/// Component sizes. tokens.json → size.
abstract final class Sizes {
  /// Height of the primary/secondary button. Big and obvious.
  static const double ctaHeight = 56;

  /// Absolute minimum of any touch area.
  static const double touchTargetMin = 44;
}
