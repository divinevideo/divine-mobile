// ABOUTME: Tests durable database recovery breadcrumbs used by support reports.
// ABOUTME: Covers valid, absent, and malformed SharedPreferences records.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/database_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(DatabaseRecoveryStore, () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    test('persists the outcome and UTC timestamp', () async {
      final store = DatabaseRecoveryStore(
        preferences: preferences,
        now: () => DateTime.parse('2026-08-29T12:34:56-05:00'),
      );

      await store.record(DatabaseRecoveryOutcome.recreatedKeyLoss);

      expect(store.read()?.toDiagnostics(), {
        'outcome': 'recreatedKeyLoss',
        'occurredAt': '2026-08-29T17:34:56.000Z',
      });
    });

    test('returns null when recovery has never run', () {
      final store = DatabaseRecoveryStore(preferences: preferences);

      expect(store.read(), isNull);
    });

    test('ignores malformed or future records', () async {
      await preferences.setString(
        'db.recovery.latest.v1',
        jsonEncode({
          'outcome': 'futureOutcome',
          'occurredAt': '2026-08-29T17:34:56Z',
        }),
      );

      expect(
        DatabaseRecoveryStore(preferences: preferences).read(),
        isNull,
      );
    });

    group('claimUnrecoverableCipherKeyReport', () {
      test('grants the report once per install', () async {
        final first = await DatabaseRecoveryStore(
          preferences: preferences,
        ).claimUnrecoverableCipherKeyReport();
        // A later launch builds a new store over the same preferences.
        final second = await DatabaseRecoveryStore(
          preferences: preferences,
        ).claimUnrecoverableCipherKeyReport();

        expect(first, isTrue);
        expect(second, isFalse);
      });
    });
  });
}
