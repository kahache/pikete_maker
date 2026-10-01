import 'package:flutter/widgets.dart';

/// Widget keys of the D36 recommendation-first outfit result, kept in their own
/// library so the extracted sub-widgets can reference them without importing
/// the screen back (mirrors `SneakerResultKeys`).
///
/// `ResultScreen` re-exposes them as static members: the D36 inverted hierarchy
/// (hero band ABOVE the demoted "tu fit" strip) is asserted by geometry against
/// these keys in the widget tests.
abstract final class OutfitResultKeys {
  static const Key heroBand = Key('outfit_hero_band');
  static const Key fitStrip = Key('outfit_fit_strip');
  static const Key canvasAccents = Key('outfit_canvas_accents');
}
