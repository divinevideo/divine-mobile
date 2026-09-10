// ABOUTME: Tests seed-only persistence for timestamp-free following snapshots.
// ABOUTME: Protects newer cache records and account-specific cache keys.

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('seedFollowingCacheIfAbsent', () {
    test('seeds an absent cache', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final written = await seedFollowingCacheIfAbsent(
        prefs: prefs,
        pubkeyHex:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        pubkeys: const [
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ],
      );

      final encoded = prefs.getString(
        FollowingCacheRecord.storageKey(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      expect(written, isTrue);
      expect(FollowingCacheRecord.decode(encoded!).pubkeys, const [
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ]);
    });

    test('preserves an existing record and its provenance', () async {
      const account =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final existing = FollowingCacheRecord(
        pubkeys: const [
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ],
        createdAt: 1234,
        eventId:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      );
      SharedPreferences.setMockInitialValues({
        FollowingCacheRecord.storageKey(account): existing.encode(),
      });
      final prefs = await SharedPreferences.getInstance();

      final written = await seedFollowingCacheIfAbsent(
        prefs: prefs,
        pubkeyHex: account,
        pubkeys: const [
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        ],
      );

      final persisted = FollowingCacheRecord.decode(
        prefs.getString(FollowingCacheRecord.storageKey(account))!,
      );
      expect(written, isFalse);
      expect(persisted.pubkeys, existing.pubkeys);
      expect(persisted.createdAt, 1234);
      expect(persisted.eventId, existing.eventId);
    });

    test('does not create a record for an empty snapshot', () async {
      const account =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final written = await seedFollowingCacheIfAbsent(
        prefs: prefs,
        pubkeyHex: account,
        pubkeys: const [],
      );

      expect(written, isFalse);
      expect(
        prefs.getString(FollowingCacheRecord.storageKey(account)),
        isNull,
      );
    });

    test('does not let another account record block seeding', () async {
      const firstAccount =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const secondAccount =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      SharedPreferences.setMockInitialValues({
        FollowingCacheRecord.storageKey(firstAccount): FollowingCacheRecord(
          pubkeys: const [
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          ],
        ).encode(),
      });
      final prefs = await SharedPreferences.getInstance();

      final written = await seedFollowingCacheIfAbsent(
        prefs: prefs,
        pubkeyHex: secondAccount,
        pubkeys: const [
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        ],
      );

      expect(written, isTrue);
      expect(
        prefs.containsKey(FollowingCacheRecord.storageKey(firstAccount)),
        isTrue,
      );
      expect(
        FollowingCacheRecord.decode(
          prefs.getString(FollowingCacheRecord.storageKey(secondAccount))!,
        ).pubkeys,
        const [
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        ],
      );
    });
  });
}
