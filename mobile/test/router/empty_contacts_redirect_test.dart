// ABOUTME: Tests for redirecting users with no contacts to explore feed
// ABOUTME: Verifies the cache checking logic for following list detection

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUserPubkey = 'test_user_pubkey_hex_12345';

  group('Empty contacts redirect logic', () {
    setUp(() async {
      // Reset the static navigation flag before each test
      resetNavigationState();
    });

    group('hasAnyFollowingInCache', () {
      test('returns false when no current_user_pubkey_hex stored', () async {
        SharedPreferences.setMockInitialValues({
          'age_verified_16_plus': true,
          'some_other_key': 'value',
          // No current_user_pubkey_hex
        });

        final prefs = await SharedPreferences.getInstance();
        final hasFollowing = await hasAnyFollowingInCache(prefs);

        expect(hasFollowing, false);
      });

      test(
        'returns false when current user has no following_list cache',
        () async {
          SharedPreferences.setMockInitialValues({
            'age_verified_16_plus': true,
            'current_user_pubkey_hex': testUserPubkey,
            // No following_list for this user
          });

          final prefs = await SharedPreferences.getInstance();
          final hasFollowing = await hasAnyFollowingInCache(prefs);

          expect(hasFollowing, false);
        },
      );

      test(
        'returns false when current user following_list is empty array',
        () async {
          SharedPreferences.setMockInitialValues({
            'age_verified_16_plus': true,
            'current_user_pubkey_hex': testUserPubkey,
            'following_list_$testUserPubkey': '[]',
          });

          final prefs = await SharedPreferences.getInstance();
          final hasFollowing = await hasAnyFollowingInCache(prefs);

          expect(hasFollowing, false);
        },
      );

      test(
        'returns true when current user following_list has contacts',
        () async {
          SharedPreferences.setMockInitialValues({
            'age_verified_16_plus': true,
            'current_user_pubkey_hex': testUserPubkey,
            'following_list_$testUserPubkey': '["pubkey1","pubkey2","pubkey3"]',
          });

          final prefs = await SharedPreferences.getInstance();
          final hasFollowing = await hasAnyFollowingInCache(prefs);

          expect(hasFollowing, true);
        },
      );

      test(
        'ignores other users following_list - only checks current user',
        () async {
          const otherUser = 'other_user_pubkey';
          SharedPreferences.setMockInitialValues({
            'age_verified_16_plus': true,
            'current_user_pubkey_hex': testUserPubkey,
            'following_list_$testUserPubkey': '[]', // Current user empty
            'following_list_$otherUser':
                '["pubkey1"]', // Other user has contacts
          });

          final prefs = await SharedPreferences.getInstance();
          final hasFollowing = await hasAnyFollowingInCache(prefs);

          // Should return false because CURRENT user has empty list
          expect(hasFollowing, false);
        },
      );

      test('handles invalid JSON gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'age_verified_16_plus': true,
          'current_user_pubkey_hex': testUserPubkey,
          'following_list_$testUserPubkey': 'not valid json',
        });

        final prefs = await SharedPreferences.getInstance();
        final hasFollowing = await hasAnyFollowingInCache(prefs);

        // Should not crash, and should return false since JSON is invalid
        expect(hasFollowing, false);
      });
    });

    group('resetNavigationState', () {
      test('can be called without error', () {
        // Just verify the function exists and can be called
        resetNavigationState();
        // If we get here, the test passed
        expect(true, true);
      });
    });
  });
}
