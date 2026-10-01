/// Anonymous outcome cards (ADR §2.2 / wire contract §2) — PURE functions
/// from the local [RetentionRecord] to the exact wire maps.
///
/// The privacy guarantee lives HERE, by construction: a card is built from an
/// explicit allow-list of coarse fields and nothing else. No id of any kind,
/// no timestamp, no raw counter — the `no PII in any payload` test pins the
/// key sets and value enums of everything this file can produce.
library;

import 'retention_state.dart';
import 'telemetry_config.dart';

/// `schema` stamped on every card (contract §1: the card self-describes its
/// version on top of the path-versioned `/v1/`).
const String kCardSchema = 'g2r/v1';

/// `kind` values — the fixed card catalogue.
const String kKindInstall = 'install';

/// `kind` of the week-1 activation card.
const String kKindWeek1 = 'week1';

/// `kind` of the week-2 retention card.
const String kKindWeek2 = 'week2';

/// `analyses_bucket` enum (ADR §2.2): COARSE buckets, never a raw count.
const List<String> kAnalysesBuckets = <String>[
  '0',
  '1-2',
  '3-5',
  '6-10',
  '10+',
];

/// `mode_bucket` enum (ADR §2.2).
const List<String> kModeBuckets = <String>['outfit', 'zapas', 'mixed'];

/// G2-R week-1 retention bar: ≥3 analyses in week 1 (ADR §1).
const int kRetainedW1MinAnalyses = 3;

/// Coarse bucket for a week-1 analysis count.
String analysesBucket(int n) {
  if (n <= 0) return '0';
  if (n <= 2) return '1-2';
  if (n <= 5) return '3-5';
  if (n <= 10) return '6-10';
  return '10+';
}

/// Coarse mode split of the week-1 analyses. `mixed` when both modes were
/// used — and, degenerately, when NO analysis ran (the `analyses_bucket`
/// `"0"` already says everything in that case; the enum has no "none" value
/// by design, to keep cardinality minimal).
String modeBucket({required int outfit, required int zapas}) {
  if (outfit > 0 && zapas == 0) return 'outfit';
  if (zapas > 0 && outfit == 0) return 'zapas';
  return 'mixed';
}

/// Context stamped on every card: the coarse environment triple. Values are
/// LOW-CARDINALITY on purpose (contract §5 rejects free-form values —
/// nothing here can become a fingerprint).
class CardContext {
  /// Creates the low-cardinality context triple stamped on every card.
  const CardContext({
    required this.platform,
    this.appVersion = kTelemetryAppVersion,
    required this.locale,
  });

  /// `android` | `ios`.
  final String platform;

  /// major.minor only.
  final String appVersion;

  /// Language code only (`es`, not `es-ES`).
  final String locale;
}

Map<String, Object?> _base(
    String kind, RetentionRecord record, CardContext context) {
  return <String, Object?>{
    'schema': kCardSchema,
    'kind': kind,
    'source': record.source,
    'cohort': record.cohort,
    'platform': context.platform,
    'app_version': context.appVersion,
    'locale': context.locale,
  };
}

/// Card 1 — `install`: the honest denominator (ADR §2.4). Fired at/after
/// first open; a device that churns on day 3 still counted here.
Map<String, Object?> buildInstallCard(
        RetentionRecord record, CardContext context) =>
    _base(kKindInstall, record, context);

/// Card 2 — `week1`: the day-7 outcome. Coarse bucket + boolean only.
Map<String, Object?> buildWeek1Card(
    RetentionRecord record, CardContext context) {
  final int total = record.analysesOutfitW1 + record.analysesSneakerW1;
  return <String, Object?>{
    ..._base(kKindWeek1, record, context),
    'retained_w1': total >= kRetainedW1MinAnalyses,
    'analyses_bucket': analysesBucket(total),
    'mode_bucket': modeBucket(
        outfit: record.analysesOutfitW1, zapas: record.analysesSneakerW1),
  };
}

/// Card 3 — `week2`: the day-14 outcome.
Map<String, Object?> buildWeek2Card(
    RetentionRecord record, CardContext context) {
  return <String, Object?>{
    ..._base(kKindWeek2, record, context),
    'returned_w2': record.returnedW2,
  };
}
