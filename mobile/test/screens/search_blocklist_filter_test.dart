// ABOUTME: Tests for search filtering of blocked users
// ABOUTME: Verifies that blocked users' content doesn't appear in search results

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('Search Blocklist Filtering', () {
    late ContentBlocklistRepository blocklistRepository;

    setUp(() {
      blocklistRepository = ContentBlocklistRepository();
    });

    test('shouldFilterFromFeeds returns true for blocked users', () async {
      const blockedPubkey = 'blocked_user_pubkey_hex';

      // Block the user
      await blocklistRepository.blockUser(blockedPubkey);

      // Verify they should be filtered
      expect(
        blocklistRepository.shouldFilterFromFeeds(blockedPubkey),
        isTrue,
        reason: 'Blocked users should be filtered from feeds and search',
      );
    });

    test('shouldFilterFromFeeds returns false for non-blocked users', () {
      const normalPubkey = 'normal_user_pubkey_hex';

      // Verify non-blocked users are not filtered
      expect(
        blocklistRepository.shouldFilterFromFeeds(normalPubkey),
        isFalse,
        reason: 'Non-blocked users should not be filtered',
      );
    });

    test('filterContent removes blocked users content', () async {
      const blockedPubkey = 'blocked_user_pubkey';
      const normalPubkey1 = 'normal_user_1_pubkey';
      const normalPubkey2 = 'normal_user_2_pubkey';

      // Block one user
      await blocklistRepository.blockUser(blockedPubkey);

      // Create mock content items
      final contentItems = [
        {'id': '1', 'pubkey': normalPubkey1},
        {'id': '2', 'pubkey': blockedPubkey},
        {'id': '3', 'pubkey': normalPubkey2},
        {'id': '4', 'pubkey': blockedPubkey},
      ];

      // Filter content
      final filteredContent = blocklistRepository.filterContent(
        contentItems,
        (item) => item['pubkey']!,
      );

      // Verify only non-blocked content remains
      expect(filteredContent.length, equals(2));
      expect(
        filteredContent.every((item) => item['pubkey'] != blockedPubkey),
        isTrue,
        reason: 'Filtered content should not contain blocked user items',
      );
    });

    test('runtimeBlockedUsers returns set of blocked pubkeys', () async {
      const pubkey1 = 'blocked_pubkey_1';
      const pubkey2 = 'blocked_pubkey_2';

      await blocklistRepository.blockUser(pubkey1);
      await blocklistRepository.blockUser(pubkey2);

      final blockedUsers = blocklistRepository.runtimeBlockedUsers;

      expect(blockedUsers.contains(pubkey1), isTrue);
      expect(blockedUsers.contains(pubkey2), isTrue);
    });

    test('unblockUser removes user from runtimeBlockedUsers', () async {
      const pubkey = 'user_to_unblock';

      // Block then unblock
      await blocklistRepository.blockUser(pubkey);
      expect(blocklistRepository.runtimeBlockedUsers.contains(pubkey), isTrue);

      await blocklistRepository.unblockUser(pubkey);
      expect(blocklistRepository.runtimeBlockedUsers.contains(pubkey), isFalse);

      // Should no longer be filtered
      expect(blocklistRepository.shouldFilterFromFeeds(pubkey), isFalse);
    });
  });
}
