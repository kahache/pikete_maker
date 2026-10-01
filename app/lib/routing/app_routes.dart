/// Route names of the 5-step skeleton (D12).
///
/// Navigation with Flutter's own named routes (Navigator 1.0), WITHOUT a
/// routing package (gate G1: zero dependencies that do not pull their
/// weight). Enough for the demo's linear path; if it grows, go_router gets
/// evaluated.
///
/// The D12 critical path:  home → onboarding(F13) → capture → analyzing → result
/// Phase 2S (D24/D26) branches at the Home: "Mis zapas" runs the SAME
/// capture/analyzing routes in sneaker mode (FlowMode in the args) and lands
/// on its own result route.
abstract final class AppRoutes {
  /// Step 1 · "open app": split Home (D26) — the user picks "Mis zapas"
  /// (sneaker mode, F11) or "Mi pikete" (outfit flow). On first launch it
  /// pushes the tutorial on top (`onboardingSeen` gate, user-flows §0).
  static const String home = '/';

  /// Step 2 · F13 tutorial (ONB-1 welcome + ONB-2 pro tip). ALWAYS lives on
  /// top of the Home; returns `OnboardingScreen.resultTakePhoto` when exiting
  /// via "Hacer mi primera foto".
  static const String onboarding = '/onboarding';

  /// Step 3 · "upload photo": confirm the photo chosen in the source sheet.
  /// Arguments: `Uint8List` (encoded bytes of the photo).
  static const String capture = '/capture';

  /// Step 4 · "analyzing": progress + rewarded ad slot (F8).
  /// Arguments: `AnalyzingArgs` (photo + ad rule).
  static const String analyzing = '/analyzing';

  /// Step 5 · result: palette + BASE + harmonies.
  /// Arguments: `ResultArgs` (the analysis + the analyzed photo, N1 / D37).
  static const String result = '/result';

  /// Phase 2S · F11 sneaker result (D27 inverted hierarchy: recommendation
  /// hero + demoted palette strip). Arguments: `SneakerResultArgs`.
  static const String sneakerResult = '/sneaker/result';

  /// Ugly states (E1–E4): single template parameterized by copy.
  /// Arguments: `FeedbackArgs`.
  static const String feedback = '/feedback';

  /// "Ajustes" (D33 telemetry opt-out, legal doc §3). Reachable ONLY while
  /// telemetry is active — the Home hides the entry point otherwise (no
  /// settings surface exists in an endpoint-empty build).
  static const String settings = '/settings';
}
