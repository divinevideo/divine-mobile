// ABOUTME: Tests the known-empty following cache seeded for new accounts.
// ABOUTME: Verifies the record uses the repository's versioned cache format.

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/services/auth/following_cache_seed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('seedEmptyFollowingCache', () {
    test('writes a versioned known-empty record for the account', () async {
      SharedPreferences.setMockInitialValues({});

      await seedEmptyFollowingCache('account-pubkey');

      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(
        FollowingCacheRecord.storageKey('account-pubkey'),
      );
      expect(encoded, isNotNull);
      expect(FollowingCacheRecord.decode(encoded!).pubkeys, isEmpty);
    });
  });
}
