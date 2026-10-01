import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the preview sheet's "Incluir mi foto" choice (N1 / D37, spec
/// §3.4): default ON; a user who turned it off for privacy should not have to
/// do it again on every share. Stored LOCALLY only (one bool); nothing is sent
/// anywhere. One key for both modes.
abstract interface class StoryPreferences {
  /// The last choice, or `true` (the CEO default) if never set.
  Future<bool> includePhoto();

  /// Remembers [value].
  Future<void> setIncludePhoto(bool value);
}

/// Real implementation: SharedPreferences (persists across launches), the
/// same store the onboarding flag uses. Never throws: a storage failure just
/// falls back to the default (ON) / forgets the choice.
class StoryPreferencesPrefs implements StoryPreferences {
  const StoryPreferencesPrefs();

  /// Key named in the spec (§3.4).
  static const String key = 'story_include_photo';

  /// CEO decision C2: the switch starts ON.
  static const bool defaultIncludePhoto = true;

  @override
  Future<bool> includePhoto() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ??
          defaultIncludePhoto;
    } on Object {
      return defaultIncludePhoto;
    }
  }

  @override
  Future<void> setIncludePhoto(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } on Object {
      // Not remembering a UI preference is harmless.
    }
  }
}

/// In-memory implementation: widget tests (hermetic, no plugin).
class StoryPreferencesInMemory implements StoryPreferences {
  StoryPreferencesInMemory({bool? includePhoto})
      : _includePhoto = includePhoto;

  bool? _includePhoto;

  /// What was last stored (null = never written).
  bool? get stored => _includePhoto;

  @override
  Future<bool> includePhoto() async =>
      _includePhoto ?? StoryPreferencesPrefs.defaultIncludePhoto;

  @override
  Future<void> setIncludePhoto(bool value) async => _includePhoto = value;
}
