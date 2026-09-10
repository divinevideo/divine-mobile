// ABOUTME: Pins the durable half of the deletion-recovery polling budget.
// ABOUTME: The cubit tests use the in-memory store, so this covers prefs.

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

    test('records a start and reads it back', () async {
      final at = DateTime.utc(2026, 3, 4, 5, 6, 7);
      await store.recordStartIfAbsent('attempt-a', at);

      expect(await store.startedAt('attempt-a'), at);
    });

    test(
      'keeps the earliest start, so a relaunch cannot push the deadline out',
      () async {
        final first = DateTime.utc(2026, 3, 4, 5);
        await store.recordStartIfAbsent('attempt-a', first);
        await store.recordStartIfAbsent(
          'attempt-a',
          first.add(const Duration(minutes: 30)),
        );

        expect(await store.startedAt('attempt-a'), first);
      },
    );

    test('scopes the start to one attempt', () async {
      final at = DateTime.utc(2026, 3, 4, 5);
      await store.recordStartIfAbsent('attempt-a', at);

      expect(await store.startedAt('attempt-b'), isNull);
    });

    test('clear forgets one attempt and leaves the other', () async {
      final at = DateTime.utc(2026, 3, 4, 5);
      await store.recordStartIfAbsent('attempt-a', at);
      await store.recordStartIfAbsent('attempt-b', at);

      await store.clear('attempt-a');

      expect(await store.startedAt('attempt-a'), isNull);
      expect(await store.startedAt('attempt-b'), at);
    });

    test('survives a new store over the same preferences', () async {
      final at = DateTime.utc(2026, 3, 4, 5);
      await store.recordStartIfAbsent('attempt-a', at);

      // What a relaunch looks like: same durable prefs, fresh store object.
      final relaunched =
          SharedPreferencesAccountDeletionRecoveryPollBudgetStore(prefs);

      expect(await relaunched.startedAt('attempt-a'), at);
    });
  });

  group(ReceiptAnchoredPollBudgetStore, () {
    late InMemoryAccountDeletionRecoveryPollBudgetStore fallback;

    setUp(() {
      fallback = InMemoryAccountDeletionRecoveryPollBudgetStore();
    });

    ReceiptAnchoredPollBudgetStore storeWith(
      ({String attemptId, DateTime startedAt})? anchor,
    ) => ReceiptAnchoredPollBudgetStore(
      readReceiptAnchor: () => anchor,
      fallback: fallback,
    );

    test('prefers the receipt anchor for the matching attempt', () async {
      final anchored = DateTime.utc(2026, 3, 4, 5);
      final store = storeWith((attemptId: 'a', startedAt: anchored));

      expect(await store.startedAt('a'), anchored);
    });

    test('writes nothing to preferences when the receipt covers it', () async {
      final anchored = DateTime.utc(2026, 3, 4, 5);
      final store = storeWith((attemptId: 'a', startedAt: anchored));

      await store.recordStartIfAbsent('a', DateTime.utc(2026, 3, 4, 9));

      // The receipt is the anchor; a second key would be a second source of
      // truth for the same fact.
      expect(await fallback.startedAt('a'), isNull);
      expect(await store.startedAt('a'), anchored);
    });

    test(
      'falls back to the keyed store when this install has no receipt, which '
      'is how the screen is reached after a reinstall',
      () async {
        final store = storeWith(null);
        final at = DateTime.utc(2026, 3, 4, 5);

        await store.recordStartIfAbsent('a', at);

        expect(await store.startedAt('a'), at);
        expect(await fallback.startedAt('a'), at);
      },
    );

    test('falls back when the receipt is for a different attempt', () async {
      final store = storeWith((
        attemptId: 'other',
        startedAt: DateTime.utc(2026),
      ));
      final at = DateTime.utc(2026, 3, 4, 5);

      await store.recordStartIfAbsent('a', at);

      expect(await store.startedAt('a'), at);
    });

    test('clear removes the fallback key', () async {
      final store = storeWith(null);
      await store.recordStartIfAbsent('a', DateTime.utc(2026, 3, 4, 5));

      await store.clear('a');

      expect(await store.startedAt('a'), isNull);
    });
  });
}
