import 'package:flutter/widgets.dart';

/// Widget keys of the sneaker result screen, kept in their own library so the
/// extracted sub-widgets can reference them without importing the screen back
/// (which would form an import cycle).
///
/// `SneakerResultScreen` re-exposes them as static members, which is the API
/// the widget tests use: the D27 inverted hierarchy (hero band ABOVE the
/// demoted palette strip) is asserted by geometry against these keys.
abstract final class SneakerResultKeys {
  static const Key heroBand = Key('sneaker_hero_band');
  static const Key paletteStrip = Key('sneaker_palette_strip');
  static const Key canvasAccents = Key('sneaker_canvas_accents');
}
