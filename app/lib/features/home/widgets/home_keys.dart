import 'package:flutter/widgets.dart';

/// Widget keys of the split Home, kept in their own library so the extracted
/// zone widgets can reference them without importing the screen back (which
/// would form an import cycle).
///
/// `HomeScreen` re-exposes them as static members — the API the widget tests
/// use.
abstract final class HomeKeys {
  /// The two mode zones.
  static const Key sneakerZone = Key('home_zone_sneaker');
  static const Key outfitZone = Key('home_zone_outfit');

  /// The "Empezar ›" pill (#81) — one per zone.
  static const Key goPill = Key('home_zone_go');

  /// The "Ajustes" top-bar entry (telemetry-active builds only).
  static const Key settingsButton = Key('home_settings_button');
}
