import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry_config.dart';

/// On-device retention record (ADR §2.1) — the D33 telemetry's ONLY state.
///
/// This is ordinary local app state (same class of thing as `onboardingSeen`):
/// it is used ON-DEVICE to decide the retention booleans and it NEVER leaves
/// the phone as-is. The only things that ever leave are the anonymous cards
/// composed FROM it (see `telemetry_cards.dart`), which carry no id, no
/// timestamp and no raw counter — the sent-flags and the day anchor below are
/// deliberately local-only.
class RetentionRecord {
  /// Creates a retention record; every field defaults to its fresh-install
  /// value, so `RetentionRecord()` is the day-0 state.
  RetentionRecord({
    this.firstOpenEpochDay,
    this.analysesOutfitW1 = 0,
    this.analysesSneakerW1 = 0,
    this.returnedW2 = false,
    this.source = kTelemetryDefaultSource,
    this.cohort = kTelemetryDefaultCohort,
    this.sentInstall = false,
    this.sentWeek1 = false,
    this.sentWeek2 = false,
    this.enabled = true,
    this.noticeSeen = false,
    this.noticeVersion,
    List<Map<String, Object?>>? queue,
  }) : queue = queue ?? <Map<String, Object?>>[];

  /// Rebuilds a record from its persisted [json] blob, tolerating missing
  /// keys (a partially written or older blob degrades to defaults).
  factory RetentionRecord.fromJson(Map<String, Object?> json) {
    return RetentionRecord(
      firstOpenEpochDay: json['firstOpenEpochDay'] as int?,
      analysesOutfitW1: (json['analysesOutfitW1'] as int?) ?? 0,
      analysesSneakerW1: (json['analysesSneakerW1'] as int?) ?? 0,
      returnedW2: (json['returnedW2'] as bool?) ?? false,
      source: (json['source'] as String?) ?? kTelemetryDefaultSource,
      cohort: (json['cohort'] as String?) ?? kTelemetryDefaultCohort,
      sentInstall: (json['sentInstall'] as bool?) ?? false,
      sentWeek1: (json['sentWeek1'] as bool?) ?? false,
      sentWeek2: (json['sentWeek2'] as bool?) ?? false,
      enabled: (json['enabled'] as bool?) ?? true,
      noticeSeen: (json['noticeSeen'] as bool?) ?? false,
      noticeVersion: json['noticeVersion'] as String?,
      queue: (json['queue'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> c) => Map<String, Object?>.from(c))
          .toList(),
    );
  }

  /// Day-0 anchor as a LOCAL-calendar day index (days since 1970-01-01 of the
  /// user's wall-clock date). Day-granular on purpose: no precise timestamp
  /// exists anywhere in the subsystem. `null` until the first app open.
  int? firstOpenEpochDay;

  /// Analyses completed inside `[day0, day0+7)`, split by mode so the week-1
  /// card can compute its coarse `mode_bucket`. Raw counts stay local; only
  /// the bucket string ever leaves.
  int analysesOutfitW1;

  /// Same counter for sneaker-mode analyses inside week 1.
  int analysesSneakerW1;

  /// Any app open inside `[day0+7, day0+14)`.
  bool returnedW2;

  /// Attribution tag stamped on every card (ADR §3). Captured at most once;
  /// defaults to [kTelemetryDefaultSource] until an install-referrer /
  /// deep-link integration lands.
  String source;

  /// Coarse organic|paid tag of this install.
  String cohort;

  /// At-most-once sent-flags (contract §3): local-only, NEVER transmitted.
  /// Set when a card's flush resolves (delivered, or deliberately given up
  /// on) so the card can never be composed again.
  bool sentInstall;

  /// Whether the week-1 card was already sent.
  bool sentWeek1;

  /// Whether the week-2 card was already sent.
  bool sentWeek2;

  /// Opt-out switch (legal doc §3). `false` ⇒ nothing is composed, queued or
  /// sent, and the queue is purged. Default ON because the transmitted data
  /// is genuinely anonymous (notice-not-consent posture, lawyer-pending).
  bool enabled;

  /// First-run notice bookkeeping (legal doc §4). Nothing is flushed before
  /// [noticeSeen] — "nothing before the notice is shown".
  bool noticeSeen;

  /// Version string of the notice the user actually saw, or null.
  String? noticeVersion;

  /// Offline queue of composed-but-unflushed cards (already in wire shape).
  final List<Map<String, Object?>> queue;

  /// Whether a card of [kind] is already waiting in the queue (guards against
  /// double-queueing between two ticks before a successful flush).
  bool queued(String kind) =>
      queue.any((Map<String, Object?> c) => c['kind'] == kind);

  /// The persisted shape of this record (round-trips via [fromJson]).
  Map<String, Object?> toJson() => <String, Object?>{
        'firstOpenEpochDay': firstOpenEpochDay,
        'analysesOutfitW1': analysesOutfitW1,
        'analysesSneakerW1': analysesSneakerW1,
        'returnedW2': returnedW2,
        'source': source,
        'cohort': cohort,
        'sentInstall': sentInstall,
        'sentWeek1': sentWeek1,
        'sentWeek2': sentWeek2,
        'enabled': enabled,
        'noticeSeen': noticeSeen,
        'noticeVersion': noticeVersion,
        'queue': queue,
      };
}

/// Persistence seam for the retention record. Same pattern as
/// [OnboardingService]: a prefs-backed production implementation + an
/// in-memory one for hermetic tests.
abstract interface class RetentionStore {
  /// The stored record, or `null` when none exists yet (fresh install).
  Future<RetentionRecord?> load();

  /// Persists [record], replacing any previous one.
  Future<void> save(RetentionRecord record);
}

/// Real implementation: one JSON blob in SharedPreferences (a single
/// read-modify-write unit — the controller serializes access on top).
class PrefsRetentionStore implements RetentionStore {
  static const String _key = 'telemetryRetentionState';

  @override
  Future<RetentionRecord?> load() async {
    final String? raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    try {
      return RetentionRecord.fromJson(
          Map<String, Object?>.from(jsonDecode(raw) as Map<String, dynamic>));
    } on FormatException {
      return null; // corrupted blob → start over (loss over crash)
    }
  }

  @override
  Future<void> save(RetentionRecord record) async {
    // The write IS awaited (fixed 2026-07-20): callers `await save(...)` and
    // must be able to assume the record is durably flushed when it returns.
    // It worked unawaited only because SharedPreferences updates its in-memory
    // cache synchronously — but the retention counters this persists are the
    // G2-R denominator, and a write lost to an app kill would silently
    // mis-count a cohort. Correctness beats the microseconds.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(record.toJson()));
  }
}

/// In-memory implementation for tests.
class InMemoryRetentionStore implements RetentionStore {
  /// The currently stored record, or null when nothing was saved yet.
  RetentionRecord? record;

  /// Snapshot of every save, so a test can assert on persistence timing.
  int saves = 0;

  @override
  Future<RetentionRecord?> load() async => record;

  @override
  Future<void> save(RetentionRecord r) async {
    record = r;
    saves++;
  }
}

/// Store that fails the test if the subsystem touches storage — used to prove
/// the endpoint-empty build never reads or writes anything.
class ThrowingRetentionStore implements RetentionStore {
  @override
  Future<RetentionRecord?> load() =>
      throw StateError('telemetry touched storage while OFF');

  @override
  Future<void> save(RetentionRecord record) =>
      throw StateError('telemetry touched storage while OFF');
}
