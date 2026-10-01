import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show immutable;

/// Minimal product instrumentation (#4, Phase 2) — NO analytics SDK, NO
/// backend, NO network (D15: the demo is 100% offline). It exists to answer the
/// funnel questions a closed beta needs (does the analysis complete? do people
/// export their palette? do they come back?) with the lightest possible seam,
/// injected the same way as the [ColorEngine] (see `app.dart`).
///
/// When a real backend/SDK is chosen (Phase 2+), only the registered
/// implementation changes; the call sites stay put.

/// The event names fired across the app. Kept as constants so the call sites
/// and the tests reference the SAME string (no stray typos in a funnel).
abstract final class AnalyticsEvents {
  /// First ever launch (the onboarding gate finds `onboardingSeen == false`).
  static const String firstLaunch = 'first_launch';

  /// A subsequent launch (onboarding already seen). Retention signal.
  static const String appReopened = 'app_reopened';

  /// A mode was picked on the split Home (F11/D26): which wedge resonates is
  /// THE question gate G2 reads. Params: `{'mode': 'sneaker' | 'outfit'}`.
  static const String modeSelected = 'mode_selected';

  /// The analysis succeeded and a result was produced (fired in analyzing).
  static const String analysisCompleted = 'analysis_completed';

  /// The SNEAKER-mode analysis succeeded (Phase 2S · F11): fired in analyzing
  /// instead of [analysisCompleted] when the flow runs in sneaker/product
  /// mode, so the G2 (outfit) and G2S (sneaker) funnels stay separable. Same
  /// params as [analysisCompleted] (`colors`, `canvas`).
  static const String sneakerAnalysisCompleted = 'sneaker_analysis_completed';

  /// A capture-situation card was tapped on the sneaker source selector
  /// (Phase 2S · #83), BEFORE the mini-tutorial and once per selection. Param:
  /// `{'source': 'casa' | 'tienda' | 'web'}`. Answers which situation sneaker
  /// users actually shoot from — the read on whether the web-crop coaching
  /// lands (fewer canvas-mode misroutes) and where the G2S error concentrates.
  static const String sneakerSourceSelected = 'sneaker_source_selected';

  /// The result screen was shown (the payoff moment). When the analysis ran
  /// the Phase 2.5 per-garment path, the event carries `{'layout': 'garments'
  /// | 'single' | 'whole'}` (per-garment UX spec §6) — the F&F beta needs it
  /// to size how often the degrades actually fire. The legacy whole-photo
  /// path keeps the historical param-less event.
  static const String resultViewed = 'result_viewed';

  /// The Phase 2.5 segmented analysis DEGRADED (silently, per the U4 spec
  /// rule: the user never sees an error). Fired in analyzing when the engine
  /// hands back a degraded result. Params: `{'reason': 'no_person' |
  /// 'region_too_small' | 'model_failed', 'to': 'single' | 'whole'}`.
  static const String segmentationDegraded = 'segmentation_degraded';

  /// The shareable palette was exported to a PNG (F6 story export).
  static const String storyExported = 'story_exported';

  /// A harmony/combi row (or a canvas accent pop) was SELECTED on a result
  /// screen (F5 v0, #82): WHICH schemes users pick is the goldmine the CEO
  /// called out — it feeds the G2 reading. Params: `{'mode': 'outfit' |
  /// 'sneaker', 'scheme': 'complementary' | 'analogous' | 'triadic' |
  /// 'split_complementary' | 'canvas'}` plus `'accent': '<ES name>'` when the
  /// selection is a canvas pop.
  static const String harmonySelected = 'harmony_selected';

  /// The "Ver looks así" deep-link opened the system browser with the
  /// pre-written search (F5 v0, #82; deep-link ONLY, decision #3). Fired only
  /// when the launch SUCCEEDS. Params: `{'mode', 'scheme', 'query'}`.
  static const String looksSearchLaunched = 'looks_search_launched';
}

/// One analytics event: a [name] and a tiny, JSON-ish [params] payload.
@immutable
class AnalyticsEvent {
  /// Creates an event called [name] with an optional [params] payload.
  const AnalyticsEvent(this.name, [this.params = const <String, Object?>{}]);

  /// Event name, e.g. `result_viewed`. Literal string in the funnel contract.
  final String name;

  /// Small JSON-ish payload attached to the event.
  final Map<String, Object?> params;

  @override
  String toString() => params.isEmpty ? name : '$name $params';
}

/// The instrumentation seam. Implementations MUST be cheap and never throw
/// (instrumentation is never allowed to break a user flow).
abstract interface class AnalyticsService {
  /// Records [event]. Must never throw and must never block a user flow.
  void log(AnalyticsEvent event);
}

/// Default production implementation: logs to the dev console via
/// `dart:developer` (visible in `flutter run`/`logcat`), stores nothing, calls
/// nobody. Safe as the app-wide default.
class LogAnalyticsService implements AnalyticsService {
  /// Creates the console-logging analytics service.
  const LogAnalyticsService();

  @override
  void log(AnalyticsEvent event) {
    developer.log(event.toString(), name: 'analytics');
  }
}

/// In-memory implementation for tests (and future in-app debug overlay): keeps
/// every event so a test can assert an event fired at the right moment.
class InMemoryAnalyticsService implements AnalyticsService {
  /// Every event logged so far, in order.
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  void log(AnalyticsEvent event) => events.add(event);

  /// The events recorded under [name], in order.
  Iterable<AnalyticsEvent> named(String name) =>
      events.where((AnalyticsEvent e) => e.name == name);

  /// Whether an event named [name] was ever fired.
  bool fired(String name) => events.any((AnalyticsEvent e) => e.name == name);
}
