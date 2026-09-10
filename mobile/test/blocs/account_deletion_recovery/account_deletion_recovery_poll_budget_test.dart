// ABOUTME: Tests durable account-deletion recovery polling budget storage.
// ABOUTME: Pins attempt isolation, earliest-wins behavior, and relaunch safety.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_poll_budget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(SharedPreferencesAccountDeletionRecoveryPollBudgetStore, () {
    late SharedPreferences prefs;
    late SharedPreferencesAccountDeletionRecoveryPollBudgetStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      store = SharedPreferencesAccountDeletionRecoveryPollBudgetStore(prefs);
    });

    test('reports no start before one is recorded', () async {
      expect(await store.startedAt('attempt-a'), isNull);
    });

    test('keeps the first start for an attempt', () async {
      final first = DateTime.utc(2026, 9, 10, 12);
      await store.recordStartIfAbsent('attempt-a', first);
      await store.recordStartIfAbsent(
        'attempt-a',
        first.add(const Duration(minutes: 30)),
      );

      expect(await store.startedAt('attempt-a'), first);
    });

    test('isolates attempts and clears only the resolved one', () async {
      final at = DateTime.utc(2026, 9, 10, 12);
      await store.recordStartIfAbsent('attempt-a', at);
      await store.recordStartIfAbsent('attempt-b', at);

      await store.clear('attempt-a');

      expect(await store.startedAt('attempt-a'), isNull);
      expect(await store.startedAt('attempt-b'), at);
    });

    test('survives a new store over the same preferences', () async {
      final at = DateTime.utc(2026, 9, 10, 12);
      await store.recordStartIfAbsent('attempt-a', at);

      final relaunched =
          SharedPreferencesAccountDeletionRecoveryPollBudgetStore(prefs);

      expect(await relaunched.startedAt('attempt-a'), at);
    });
  });
}
