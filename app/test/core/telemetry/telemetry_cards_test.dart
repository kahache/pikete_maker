import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/telemetry/retention_state.dart';
import 'package:piketemaker/core/telemetry/telemetry_cards.dart';

/// D33 anonymous cards: bucketing + wire shape + the NO-PII invariant.
///
/// The hard constraint (ADR §2.2 / contract §7): a serialized card carries
/// NOTHING able to link two sends or identify a device — no id of any kind,
/// no timestamp, no raw counter, only allow-listed coarse fields. These
/// tests pin that by construction, so a future field addition that would
/// break anonymity fails loudly here.
void main() {
  const CardContext context =
      CardContext(platform: 'android', appVersion: '0.1', locale: 'es');

  RetentionRecord record({int outfit = 0, int zapas = 0, bool w2 = false}) =>
      RetentionRecord(
        firstOpenEpochDay: 20654,
        analysesOutfitW1: outfit,
        analysesSneakerW1: zapas,
        returnedW2: w2,
      );

  group('analyses_bucket (coarse, never a raw count)', () {
    test('boundaries match the ADR enum', () {
      expect(analysesBucket(0), '0');
      expect(analysesBucket(1), '1-2');
      expect(analysesBucket(2), '1-2');
      expect(analysesBucket(3), '3-5');
      expect(analysesBucket(5), '3-5');
      expect(analysesBucket(6), '6-10');
      expect(analysesBucket(10), '6-10');
      expect(analysesBucket(11), '10+');
      expect(analysesBucket(999), '10+');
    });

    test('every produced value is in the fixed enum', () {
      for (int n = 0; n <= 30; n++) {
        expect(kAnalysesBuckets, contains(analysesBucket(n)));
      }
    });
  });

  group('mode_bucket', () {
    test('single-mode weeks', () {
      expect(modeBucket(outfit: 3, zapas: 0), 'outfit');
      expect(modeBucket(outfit: 0, zapas: 2), 'zapas');
    });

    test(
        'both modes → mixed; zero-zero degenerates to mixed (bucket "0" '
        'carries the meaning)', () {
      expect(modeBucket(outfit: 1, zapas: 1), 'mixed');
      expect(modeBucket(outfit: 0, zapas: 0), 'mixed');
    });
  });

  group('card shapes (wire contract §2)', () {
    test('install card: exact key set, coarse values only', () {
      final Map<String, Object?> card = buildInstallCard(record(), context);
      expect(card.keys.toSet(), <String>{
        'schema', 'kind', 'source', 'cohort', //
        'platform', 'app_version', 'locale',
      });
      expect(card['schema'], 'g2r/v1');
      expect(card['kind'], 'install');
      expect(card['source'], 'organic-unattributed');
      expect(card['cohort'], 'organic');
      expect(card['platform'], 'android');
      expect(card['app_version'], '0.1');
      expect(card['locale'], 'es');
    });

    test('week1 card: retained boolean + coarse buckets, never counters', () {
      final Map<String, Object?> card =
          buildWeek1Card(record(outfit: 3, zapas: 1), context);
      expect(card.keys.toSet(), <String>{
        'schema', 'kind', 'source', 'cohort', //
        'retained_w1', 'analyses_bucket', 'mode_bucket',
        'platform', 'app_version', 'locale',
      });
      expect(card['kind'], 'week1');
      expect(card['retained_w1'], true); // 4 total ≥ 3 (G2-R bar)
      expect(card['analyses_bucket'], '3-5');
      expect(card['mode_bucket'], 'mixed');
    });

    test('week1 below the G2-R bar', () {
      final Map<String, Object?> card =
          buildWeek1Card(record(outfit: 2), context);
      expect(card['retained_w1'], false);
      expect(card['analyses_bucket'], '1-2');
      expect(card['mode_bucket'], 'outfit');
    });

    test('week2 card: single returned boolean', () {
      final Map<String, Object?> card =
          buildWeek2Card(record(w2: true), context);
      expect(card.keys.toSet(), <String>{
        'schema', 'kind', 'source', 'cohort', //
        'returned_w2', 'platform', 'app_version', 'locale',
      });
      expect(card['kind'], 'week2');
      expect(card['returned_w2'], true);
    });
  });

  group('NO PII / no identifier in any payload (the D33 hard rule)', () {
    /// Every card the subsystem can ever produce, serialized as it would go
    /// over the wire.
    List<Map<String, Object?>> allCards() => <Map<String, Object?>>[
          buildInstallCard(record(), context),
          buildWeek1Card(record(outfit: 7, zapas: 4, w2: true), context),
          buildWeek2Card(record(w2: true), context),
        ];

    test('no UUID-shaped or long-token value anywhere', () {
      final String wire = jsonEncode(<String, Object?>{'signals': allCards()});
      // UUID (any version, any case).
      expect(
          RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
                  r'-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
              .hasMatch(wire),
          isFalse);
      // Any long opaque token (a stable id in disguise): no value longer
      // than a source label could legitimately be.
      for (final Map<String, Object?> card in allCards()) {
        for (final Object? value in card.values) {
          expect(value, anyOf(isA<bool>(), isA<String>()));
          if (value is String) {
            expect(value.length, lessThan(48));
          }
        }
      }
    });

    test('no key smells like an id, a timestamp or a device field', () {
      const List<String> forbidden = <String>[
        'id', 'uuid', 'device', 'install_id', 'event', //
        'time', 'date', 'stamp', 'token', 'session',
      ];
      for (final Map<String, Object?> card in allCards()) {
        for (final String key in card.keys) {
          for (final String bad in forbidden) {
            expect(key.toLowerCase().contains(bad), isFalse,
                reason: 'card key "$key" matches forbidden fragment "$bad"');
          }
        }
      }
    });

    test('no numeric value at all (raw counters can never leak)', () {
      for (final Map<String, Object?> card in allCards()) {
        expect(card.values.whereType<num>(), isEmpty);
      }
    });
  });
}
