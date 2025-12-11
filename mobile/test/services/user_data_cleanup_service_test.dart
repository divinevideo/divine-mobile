// ABOUTME: Tests for UserDataCleanupService identity change detection and cleanup
// ABOUTME: Validates that user-specific data is cleared when switching accounts

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserDataCleanupService', () {
    late SharedPreferences prefs;
    late UserDataCleanupService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = UserDataCleanupService(prefs);
    });

    group('shouldClearDataForUser', () {
      test('returns false when same user is logging in', () async {
        const pubkey = 'abc123def456';
        await prefs.setString('current_user_pubkey_hex', pubkey);

        expect(service.shouldClearDataForUser(pubkey), isFalse);
      });

      test('returns true when different user was stored', () async {
        const oldPubkey = 'old_user_pubkey';
        const newPubkey = 'new_user_pubkey';
        await prefs.setString('current_user_pubkey_hex', oldPubkey);

        expect(service.shouldClearDataForUser(newPubkey), isTrue);
      });

      test('returns false on fresh install with no data', () {
        const pubkey = 'brand_new_user';

        expect(service.shouldClearDataForUser(pubkey), isFalse);
      });

      test('returns true when orphaned user data exists without stored pubkey',
          () async {
        // No pubkey stored, but user-specific data exists
        await prefs.setStringList('curated_lists', ['list1', 'list2']);

        expect(service.shouldClearDataForUser('any_pubkey'), isTrue);
      });

      test('returns true when any user-specific key exists without pubkey',
          () async {
        // Test with a different user-specific key
        await prefs.setString('seen_video_ids', 'video1,video2');

        expect(service.shouldClearDataForUser('any_pubkey'), isTrue);
      });
    });

    group('clearUserSpecificData', () {
      test('clears all user-specific keys from SharedPreferences', () async {
        // Set up some user-specific data
        await prefs.setStringList('curated_lists', ['list1']);
        await prefs.setStringList('subscribed_list_ids', ['sub1']);
        await prefs.setString('seen_video_ids', 'video1');
        await prefs.setBool('age_verified_16_plus', true);

        // Also set some device/app settings that should NOT be cleared
        await prefs.setString('relay_url', 'wss://relay.example.com');
        await prefs.setBool('analytics_enabled', false);

        await service.clearUserSpecificData();

        // User-specific data should be gone
        expect(prefs.containsKey('curated_lists'), isFalse);
        expect(prefs.containsKey('subscribed_list_ids'), isFalse);
        expect(prefs.containsKey('seen_video_ids'), isFalse);
        expect(prefs.containsKey('age_verified_16_plus'), isFalse);

        // Device/app settings should remain
        expect(prefs.getString('relay_url'), 'wss://relay.example.com');
        expect(prefs.getBool('analytics_enabled'), isFalse);
      });

      test('handles case when no user-specific data exists', () async {
        // Service should not throw when there's nothing to clear
        await service.clearUserSpecificData();

        // Just verify it completes without error
        expect(true, isTrue);
      });

      test('clears bookmark-related keys', () async {
        await prefs.setStringList('bookmark_sets', ['set1']);
        await prefs.setString('global_bookmarks', 'bookmark_data');

        await service.clearUserSpecificData();

        expect(prefs.containsKey('bookmark_sets'), isFalse);
        expect(prefs.containsKey('global_bookmarks'), isFalse);
      });

      test('clears mute/moderation keys', () async {
        await prefs.setStringList('muted_items', ['user1', 'user2']);
        await prefs.setStringList(
            'content_moderation_local_mutes', ['mute1']);

        await service.clearUserSpecificData();

        expect(prefs.containsKey('muted_items'), isFalse);
        expect(prefs.containsKey('content_moderation_local_mutes'), isFalse);
      });

      test('clears draft-related keys', () async {
        await prefs.setString('vine_drafts', '{"drafts": []}');

        await service.clearUserSpecificData();

        expect(prefs.containsKey('vine_drafts'), isFalse);
      });
    });

    group('userSpecificKeys', () {
      test('contains expected key categories', () {
        final keys = UserDataCleanupService.userSpecificKeys;

        // List-related
        expect(keys, contains('curated_lists'));
        expect(keys, contains('subscribed_list_ids'));
        expect(keys, contains('user_lists'));

        // Bookmark-related
        expect(keys, contains('bookmark_sets'));
        expect(keys, contains('global_bookmarks'));

        // Mute-related
        expect(keys, contains('muted_items'));

        // History
        expect(keys, contains('seen_video_ids'));
        expect(keys, contains('content_reports_history'));

        // Drafts
        expect(keys, contains('vine_drafts'));

        // TOS
        expect(keys, contains('age_verified_16_plus'));
        expect(keys, contains('terms_accepted_at'));
      });

      test('does NOT contain device/app settings', () {
        final keys = UserDataCleanupService.userSpecificKeys;

        // These should NOT be in the cleanup list
        expect(keys, isNot(contains('relay_url')));
        expect(keys, isNot(contains('analytics_enabled')));
        expect(keys, isNot(contains('current_user_pubkey_hex')));
      });
    });
  });
}
