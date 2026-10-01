import 'package:flutter/widgets.dart';

/// Widget keys of the onboarding flow, kept in their own library so the
/// extracted pages can reference them without importing the screen back
/// (which would form an import cycle).
///
/// `OnboardingScreen` re-exposes them as static members — the API the widget
/// tests use.
abstract final class OnboardingKeys {
  /// Test keys of the ONB-1 stacked brand block (#51, option E3).
  static const Key brandSymbol = Key('onb1_brand_symbol');
  static const Key brandWordmark = Key('onb1_brand_wordmark');

  /// Test key of tutorial phrase [index] (#53 highlight loop).
  static Key tipText(int index) => Key('tip_text_$index');
}
