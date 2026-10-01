import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/telemetry/retention_state.dart';
import 'package:piketemaker/core/telemetry/telemetry_controller.dart';
import 'package:piketemaker/core/telemetry/telemetry_transport.dart';

/// D33 controller: simulated-clock retention transitions (day 0/7/14),
/// at-most-once sent-flags, loss-over-duplication flush rules, opt-out
/// purge and the endpoint-empty total no-op.
void main() {
  const String endpoint = 'https://ingest.test/v1/signals';

  late DateTime now;
  late InMemoryRetentionStore store;
  late _FakeTransport transport;
  late TelemetryController controller;

  /// Day-0 anchor of every scenario.
  final DateTime day0 = DateTime(2026, 7, 20, 10, 30);

  void advanceToDay(int day) => now = day0.add(Duration(days: day));

  TelemetryController build({String url = endpoint, RetentionStore? s}) {
    return TelemetryController(
      store: s ?? store,
      transport: transport,
      endpoint: url,
      clock: () => now,
      platform: 'android',
      locale: 'es',
    );
  }

  setUp(() {
    now = day0;
    store = InMemoryRetentionStore();
    transport = _FakeTransport();
    controller = build();
  });

  group('retention transitions (simulated clock)', () {
    test(
        'day 0: install card queues at first open, flushes only after the '
        'notice (nothing before the notice is shown)', () async {
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, isEmpty); // notice gate holds

      await controller.markNoticeSeen();
      await controller.idle();
      expect(transport.batches, hasLength(1));
      final Map<String, Object?> card = transport.batches.single.single;
      expect(card['kind'], 'install');
      expect(card['source'], 'organic-unattributed');
      expect(card['cohort'], 'organic');
      expect(store.record!.sentInstall, isTrue);
      expect(store.record!.queue, isEmpty);
    });

    test(
        'full lifecycle: analyses in week 1 → day-7 week1 card → day-14 '
        'week2 card', () async {
      await controller.markNoticeSeen();
      await controller.recordAppOpen(); // day 0 → install

      advanceToDay(2);
      await controller.recordAnalysis('outfit');
      await controller.recordAnalysis('outfit');
      await controller.recordAnalysis('outfit');
      await controller.recordAnalysis('zapas');
      await controller.idle();
      expect(transport.batches, hasLength(1)); // nothing else due yet

      advanceToDay(7); // week-1 boundary + inside the week-2 return window
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(2));
      final Map<String, Object?> week1 = transport.batches[1].single;
      expect(week1['kind'], 'week1');
      expect(week1['retained_w1'], true); // 4 ≥ 3
      expect(week1['analyses_bucket'], '3-5');
      expect(week1['mode_bucket'], 'mixed');

      advanceToDay(14);
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(3));
      final Map<String, Object?> week2 = transport.batches[2].single;
      expect(week2['kind'], 'week2');
      expect(week2['returned_w2'], true); // the day-7 open was in [7,14)
    });

    test('analyses AFTER day 7 do not count into the week-1 bucket', () async {
      await controller.markNoticeSeen();
      await controller.recordAppOpen();
      advanceToDay(8);
      await controller.recordAnalysis('outfit');
      await controller.idle();
      final Map<String, Object?> week1 = transport.batches
          .expand((List<Map<String, Object?>> b) => b)
          .singleWhere((Map<String, Object?> c) => c['kind'] == 'week1');
      expect(week1['analyses_bucket'], '0');
      expect(week1['retained_w1'], false);
    });

    test(
        'churner who reopens at day 20: week1 (not retained) + week2 (not '
        'returned) flush together, install already counted', () async {
      await controller.markNoticeSeen();
      await controller.recordAppOpen(); // day 0
      advanceToDay(20); // never opened during [7,14)
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(2));
      final List<Map<String, Object?>> late = transport.batches[1];
      expect(late, hasLength(2));
      expect(late[0]['kind'], 'week1');
      expect(late[0]['retained_w1'], false);
      expect(late[1]['kind'], 'week2');
      expect(late[1]['returned_w2'], false);
    });

    test('at-most-once: a boundary crossed twice emits ONE card', () async {
      await controller.markNoticeSeen();
      await controller.recordAppOpen();
      advanceToDay(7);
      await controller.recordAppOpen();
      await controller.recordAppOpen();
      await controller.recordAppOpen();
      await controller.idle();
      final Iterable<Map<String, Object?>> week1Cards = transport.batches
          .expand((List<Map<String, Object?>> b) => b)
          .where((Map<String, Object?> c) => c['kind'] == 'week1');
      expect(week1Cards, hasLength(1));
    });

    test(
        'state survives a "process restart" (new controller over the same '
        'store): sent-flags keep holding', () async {
      await controller.markNoticeSeen();
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(1));

      final TelemetryController second = build(); // same store, fresh memory
      await second.recordAppOpen();
      await second.idle();
      expect(transport.batches, hasLength(1)); // install NOT re-sent
    });
  });

  group('flush rules: loss over duplication (contract §2/§3)', () {
    setUp(() async {
      await controller.markNoticeSeen();
      await controller.idle();
    });

    test(
        'notSent (request never left) is the one safe retry: cards stay '
        'queued and go out on the next tick', () async {
      transport.script.add(TelemetrySendOutcome.notSent);
      await controller.recordAppOpen();
      await controller.idle();
      expect(store.record!.queue, hasLength(1)); // kept
      expect(store.record!.sentInstall, isFalse);

      await controller.recordAppOpen(); // next tick → delivered (fallback)
      await controller.idle();
      expect(transport.batches, hasLength(2));
      expect(store.record!.queue, isEmpty);
      expect(store.record!.sentInstall, isTrue);
    });

    test('ambiguous (response unknown) is NEVER resent: prefer loss', () async {
      transport.script.add(TelemetrySendOutcome.ambiguous);
      await controller.recordAppOpen();
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(1)); // no second attempt
      expect(store.record!.queue, isEmpty);
      expect(store.record!.sentInstall, isTrue); // resolved, not retried
    });

    test('rejected (4xx) is dropped, never retried', () async {
      transport.script.add(TelemetrySendOutcome.rejected);
      await controller.recordAppOpen();
      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(1));
      expect(store.record!.queue, isEmpty);
    });

    test('rate-limited keeps the cards queued', () async {
      transport.script.add(TelemetrySendOutcome.rateLimited);
      await controller.recordAppOpen();
      await controller.idle();
      expect(store.record!.queue, hasLength(1));
      expect(store.record!.sentInstall, isFalse);
    });

    test('5xx: one retry, then give up (accept loss)', () async {
      transport.script.addAll(<TelemetrySendOutcome>[
        TelemetrySendOutcome.serverError,
        TelemetrySendOutcome.serverError,
      ]);
      await controller.recordAppOpen();
      await controller.idle();
      expect(store.record!.queue, hasLength(1)); // first 5xx → keep

      await controller.recordAppOpen(); // the single retry
      await controller.idle();
      expect(store.record!.queue, isEmpty); // second 5xx → give up
      expect(store.record!.sentInstall, isTrue); // never composed again

      await controller.recordAppOpen();
      await controller.idle();
      expect(transport.batches, hasLength(2)); // no third attempt
    });
  });

  group('notice + opt-out (legal surface)', () {
    test('shouldShowNotice: true once, false after seen', () async {
      expect(await controller.shouldShowNotice(), isTrue);
      await controller.markNoticeSeen();
      expect(await controller.shouldShowNotice(), isFalse);
      expect(store.record!.noticeVersion, 'notice-v1');
    });

    test('opt-out purges the queue and blocks every future send', () async {
      transport.script.add(TelemetrySendOutcome.notSent); // strand a card
      await controller.markNoticeSeen();
      await controller.recordAppOpen();
      await controller.idle();
      expect(store.record!.queue, hasLength(1));

      await controller.setEnabled(false);
      await controller.idle();
      expect(store.record!.queue, isEmpty); // purged
      expect(await controller.isEnabled(), isFalse);
      expect(await controller.shouldShowNotice(), isFalse);

      advanceToDay(7);
      await controller.recordAppOpen();
      await controller.recordAnalysis('outfit');
      await controller.idle();
      expect(transport.batches, hasLength(1)); // only the pre-opt-out attempt
      expect(store.record!.queue, isEmpty); // nothing composed while off
    });

    test(
        'source seam: a referrer tag stamps future cards, but never after '
        'a card exists (consistency across cards)', () async {
      await controller.setSource('creator_x', cohort: 'paid');
      await controller.markNoticeSeen();
      await controller.recordAppOpen();
      await controller.idle();
      final Map<String, Object?> card = transport.batches.single.single;
      expect(card['source'], 'creator_x');
      expect(card['cohort'], 'paid');

      await controller.setSource('creator_y'); // too late: install exists
      await controller.idle();
      expect(store.record!.source, 'creator_x');
    });
  });

  group('endpoint EMPTY ⇒ telemetry fully OFF', () {
    test('no storage access, no network, no notice — ever', () async {
      final TelemetryController off =
          build(url: '', s: ThrowingRetentionStore());
      await off.recordAppOpen();
      await off.recordAnalysis('outfit');
      await off.markNoticeSeen();
      await off.setEnabled(true);
      await off.idle();
      expect(await off.shouldShowNotice(), isFalse);
      expect(await off.isEnabled(), isFalse);
      expect(off.active, isFalse);
      expect(transport.batches, isEmpty);
      // The throwing store proves storage was never touched (it would have
      // failed the test loudly).
    });

    test('the analytics decorator stays a pure pass-through', () {
      final InMemoryAnalyticsService inner = InMemoryAnalyticsService();
      final TelemetryController off =
          build(url: '', s: ThrowingRetentionStore());
      final TelemetryAnalyticsService seam =
          TelemetryAnalyticsService(inner: inner, controller: off);
      seam.log(const AnalyticsEvent(AnalyticsEvents.firstLaunch));
      seam.log(const AnalyticsEvent(AnalyticsEvents.analysisCompleted));
      expect(inner.events, hasLength(2));
      expect(transport.batches, isEmpty);
    });
  });

  group('analytics decorator (telemetry ON)', () {
    test('derives the retention signals from the seam events', () async {
      final InMemoryAnalyticsService inner = InMemoryAnalyticsService();
      final TelemetryAnalyticsService seam =
          TelemetryAnalyticsService(inner: inner, controller: controller);
      await controller.markNoticeSeen();

      seam.log(const AnalyticsEvent(AnalyticsEvents.firstLaunch));
      await controller.idle();
      expect(transport.batches.single.single['kind'], 'install');

      seam.log(const AnalyticsEvent(AnalyticsEvents.analysisCompleted));
      seam.log(const AnalyticsEvent(AnalyticsEvents.sneakerAnalysisCompleted));
      seam.log(const AnalyticsEvent(AnalyticsEvents.resultViewed)); // ignored
      await controller.idle();
      expect(store.record!.analysesOutfitW1, 1);
      expect(store.record!.analysesSneakerW1, 1);
      expect(inner.events, hasLength(4)); // everything passed through
    });
  });
}

/// Records every batch; outcomes come from [script] (FIFO) then [fallback].
class _FakeTransport implements TelemetryTransport {
  final List<List<Map<String, Object?>>> batches =
      <List<Map<String, Object?>>>[];
  final List<TelemetrySendOutcome> script = <TelemetrySendOutcome>[];
  TelemetrySendOutcome fallback = TelemetrySendOutcome.delivered;

  @override
  Future<TelemetrySendOutcome> send(List<Map<String, Object?>> cards) async {
    batches.add(List<Map<String, Object?>>.from(cards));
    return script.isNotEmpty ? script.removeAt(0) : fallback;
  }
}
