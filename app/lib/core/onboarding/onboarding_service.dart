import 'package:shared_preferences/shared_preferences.dart';

/// Manages the `onboardingSeen` flag (F13 / user-flows §0).
///
/// The flag is PURELY UI, no backend (onboarding-tutorial.md §1.3). It is set
/// to `true` both on completing and on skipping the tutorial; it never
/// repeats.
abstract interface class OnboardingService {
  /// Has the user already seen the onboarding?
  Future<bool> seen();

  /// Marks the onboarding as seen (completed or skipped).
  Future<void> markSeen();
}

/// Real implementation: SharedPreferences (persists across launches).
class OnboardingServicePrefs implements OnboardingService {
  /// Flag name per user-flows §0 / onboarding-tutorial §1.3.
  static const String _key = 'onboardingSeen';

  @override
  Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}

/// In-memory implementation: for widget tests (hermetic, no plugin).
class OnboardingServiceInMemory implements OnboardingService {
  bool _seen = false;

  @override
  Future<bool> seen() async => _seen;

  @override
  Future<void> markSeen() async => _seen = true;
}
