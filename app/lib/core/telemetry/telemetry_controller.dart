import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../analytics/analytics_service.dart';
import 'retention_state.dart';
import 'telemetry_cards.dart';
import 'telemetry_config.dart';
import 'telemetry_transport.dart';

/// D33 (amended) telemetry brains: on-device retention state → anonymous
/// outcome cards → fire-and-forget flush.
///
/// Lifecycle per install (ADR §2.2/§2.4):
///  * first open      → `install` card (the honest denominator),
///  * first activity at/after day 7  → `week1` card (retained/bucket/mode),
///  * first activity at/after day 14 → `week2` card (returned in [7,14)?).
/// A device that never opens again after a boundary simply never emits that
/// card — accepted loss, the install card keeps the denominator honest.
///
/// Hard rules enforced here:
///  * ENDPOINT EMPTY ⇒ TOTAL NO-OP: no storage read/write, no network, ever
///    (the endpoint-empty test uses a throwing store to prove it).
///  * At-most-once per card via local sent-flags (never transmitted); an
///    ambiguous flush prefers LOSS over duplication (contract §3).
///  * Nothing is sent before the first-run notice was shown, and nothing
///    while opted out (opt-out also purges the queue) — legal doc §3/§4.
///  * NEVER throws, never blocks a user flow (the analytics-seam contract).
class TelemetryController {
  /// Creates a controller over [store] and [transport]. [clock] is injectable
  /// so tests can travel to week 1 / week 2 without waiting.
  TelemetryController({
    required RetentionStore store,
    required TelemetryTransport transport,
    this.endpoint = kTelemetryEndpoint,
    DateTime Function()? clock,
    String? platform,
    String? locale,
  })  : _store = store,
        _transport = transport,
        _clock = clock ?? DateTime.now,
        _platform = platform ??
            (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        _locale = locale ?? PlatformDispatcher.instance.locale.languageCode;

  final RetentionStore _store;
  final TelemetryTransport _transport;

  /// Ingest URL. Empty ⇒ the whole controller is inert ([active] false).
  final String endpoint;

  final DateTime Function() _clock;
  final String _platform;
  final String _locale;

  /// Whether telemetry exists at all in this build.
  bool get active => endpoint.isNotEmpty;

  /// Contract §2 5xx rule: retry at most once per app session, then give up.
  bool _serverErrorRetried = false;

  /// All state mutations run through this chain: the record is one
  /// read-modify-write JSON blob, so two interleaved async ops must never
  /// race (e.g. an analysis completing while the app-open tick still runs).
  Future<void> _serial = Future<void>.value();

  /// Local-calendar day index (days since 1970-01-01 of the WALL-CLOCK date)
  /// — day-granular on purpose, no precise timestamp exists in the subsystem.
  static int _epochDay(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Serialized, throw-proof runner: instrumentation must never break a
  /// user flow, so every public entry point funnels through here.
  Future<void> _run(Future<void> Function(RetentionRecord r) op) {
    if (!active) return Future<void>.value();
    return _serial = _serial.then((_) async {
      try {
        final RetentionRecord record = await _store.load() ?? RetentionRecord();
        await op(record);
        await _store.save(record);
      } catch (_) {
        // Swallow everything: a broken flush/store loses a card, never a flow.
      }
    });
  }

  // --- Retention events (driven by TelemetryAnalyticsService) ---

  /// An app open (first launch or reopen). Anchors day-0, marks the week-2
  /// return window, then ticks the card windows.
  Future<void> recordAppOpen() => _run((RetentionRecord r) async {
        final int today = _epochDay(_clock());
        r.firstOpenEpochDay ??= today;
        final int day = today - r.firstOpenEpochDay!;
        if (day >= 7 && day < 14) r.returnedW2 = true;
        await _tick(r, day);
      });

  /// A completed analysis. [mode] is `outfit` | `zapas` (the card enum).
  Future<void> recordAnalysis(String mode) => _run((RetentionRecord r) async {
        final int today = _epochDay(_clock());
        r.firstOpenEpochDay ??= today; // defensive: open always precedes this
        final int day = today - r.firstOpenEpochDay!;
        if (day >= 0 && day < 7) {
          if (mode == 'zapas') {
            r.analysesSneakerW1++;
          } else {
            r.analysesOutfitW1++;
          }
        }
        await _tick(r, day);
      });

  // --- Notice + opt-out (legal surface) ---

  /// Whether the first-run notice is due: telemetry exists, the user has not
  /// opted out, and the notice was never shown.
  Future<bool> shouldShowNotice() async {
    if (!active) return false;
    bool due = false;
    await _run((RetentionRecord r) async {
      due = r.enabled && !r.noticeSeen;
    });
    return due;
  }

  /// The notice was shown (single "Entendido" — it is a notice, not a
  /// consent gate). Unblocks flushing; records the version for the audit
  /// trail (legal doc §4).
  Future<void> markNoticeSeen() => _run((RetentionRecord r) async {
        r.noticeSeen = true;
        r.noticeVersion = kTelemetryNoticeVersion;
        // The install card queued at app-open can flush now.
        if (r.firstOpenEpochDay != null) {
          await _tick(r, _epochDay(_clock()) - r.firstOpenEpochDay!);
        }
      });

  /// Current opt-out switch position (settings screen).
  Future<bool> isEnabled() async {
    if (!active) return false;
    bool enabled = true;
    await _run((RetentionRecord r) async {
      enabled = r.enabled;
    });
    return enabled;
  }

  /// Opt-out toggle. OFF ⇒ purge the queue and never compose/send again
  /// (the legal copy's "dejamos de enviar nada" must be literally true).
  Future<void> setEnabled(bool enabled) => _run((RetentionRecord r) async {
        r.enabled = enabled;
        if (!enabled) r.queue.clear();
      });

  /// Attribution seam (ADR §3): a future install-referrer / deep-link
  /// integration stamps the creator source ONCE at first run. No-op if any
  /// card was already composed (the tag must be consistent across cards).
  Future<void> setSource(String source, {String? cohort}) =>
      _run((RetentionRecord r) async {
        if (r.sentInstall || r.queue.isNotEmpty) return;
        r.source = source;
        if (cohort != null) r.cohort = cohort;
      });

  // --- Card composition + flush ---

  CardContext get _context => CardContext(
        platform: _platform,
        locale: _locale,
      );

  /// Composes whatever cards became due, then attempts a flush. Runs inside
  /// [_run], so [r] is the single authoritative record.
  Future<void> _tick(RetentionRecord r, int day) async {
    if (!r.enabled) return; // opted out: compose nothing, send nothing
    if (!r.sentInstall && !r.queued(kKindInstall) && day >= 0) {
      r.queue.add(buildInstallCard(r, _context));
    }
    if (!r.sentWeek1 && !r.queued(kKindWeek1) && day >= 7) {
      r.queue.add(buildWeek1Card(r, _context));
    }
    if (!r.sentWeek2 && !r.queued(kKindWeek2) && day >= 14) {
      r.queue.add(buildWeek2Card(r, _context));
    }
    await _flush(r);
  }

  /// Fire-and-forget flush of the queued cards, mapping each transport
  /// outcome to the contract's client rule. "Resolved" (sent-flag set +
  /// dequeued) covers delivered AND deliberate give-ups — at-most-once,
  /// loss over duplication.
  Future<void> _flush(RetentionRecord r) async {
    if (r.queue.isEmpty || !r.noticeSeen) return;
    final List<Map<String, Object?>> batch =
        List<Map<String, Object?>>.unmodifiable(r.queue);
    final TelemetrySendOutcome outcome = await _transport.send(batch);
    switch (outcome) {
      case TelemetrySendOutcome.delivered:
      case TelemetrySendOutcome.ambiguous: // maybe counted → never resend
      case TelemetrySendOutcome.rejected: // malformed → never retry
        _resolve(r, batch);
      case TelemetrySendOutcome.notSent:
      case TelemetrySendOutcome.rateLimited:
        break; // provably not counted → keep queued for a later tick
      case TelemetrySendOutcome.serverError:
        if (_serverErrorRetried) {
          _resolve(r, batch); // second 5xx: give up, accept loss
        } else {
          _serverErrorRetried = true; // keep queued for ONE more attempt
        }
    }
  }

  void _resolve(RetentionRecord r, List<Map<String, Object?>> batch) {
    for (final Map<String, Object?> card in batch) {
      switch (card['kind']) {
        case kKindInstall:
          r.sentInstall = true;
        case kKindWeek1:
          r.sentWeek1 = true;
        case kKindWeek2:
          r.sentWeek2 = true;
      }
    }
    r.queue.clear();
  }

  /// Test hook: everything queued through [_run] has completed.
  Future<void> idle() => _serial;
}

/// [AnalyticsService] decorator (ADR §7): the one-line seam swap in
/// `app.dart`. Call sites are untouched — the decorator forwards every event
/// to [inner] (today's log/in-memory sink) and derives the D33 retention
/// signals from the few events that matter. With telemetry OFF it is a pure
/// pass-through.
class TelemetryAnalyticsService implements AnalyticsService {
  /// Wraps [inner], additionally feeding retention signals to [controller].
  const TelemetryAnalyticsService({
    required this.inner,
    required this.controller,
  });

  /// The wrapped sink every event is forwarded to unchanged.
  final AnalyticsService inner;

  /// Derives the D33 retention signals from the events worth counting.
  final TelemetryController controller;

  @override
  void log(AnalyticsEvent event) {
    inner.log(event);
    if (!controller.active) return;
    // Fire-and-forget: the controller serializes + swallows internally.
    switch (event.name) {
      case AnalyticsEvents.firstLaunch:
      case AnalyticsEvents.appReopened:
        unawaited(controller.recordAppOpen());
      case AnalyticsEvents.analysisCompleted:
        unawaited(controller.recordAnalysis('outfit'));
      case AnalyticsEvents.sneakerAnalysisCompleted:
        unawaited(controller.recordAnalysis('zapas'));
    }
  }
}
