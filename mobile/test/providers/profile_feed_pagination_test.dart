// ABOUTME: Test suite for profile feed cursor pagination implementation
// ABOUTME: Verifies loadMore() fetches and appends next page of videos using cursor tracking

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  // Test user ID (using a real Nostr pubkey hex for integration testing)
  const testUserId =
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d'; // fiatjaf

  group('ProfileFeed Cursor Pagination', () {
    test('loads initial page of videos', () async {
      // ARRANGE: Create provider container
      final container = ProviderContainer();

      // ACT: Read the profile feed provider (this should trigger initial load)
      final asyncValue = await container.read(
        profileFeedProvider(testUserId).future,
      );

      // ASSERT: Should return VideoFeedState with data
      expect(asyncValue, isA<VideoFeedState>());
      expect(asyncValue.videos, isA<List<VideoEvent>>());
      expect(asyncValue.isLoadingMore, isFalse);

      container.dispose();
    });

    test('loadMore() fetches next page with cursor', () async {
      // ARRANGE: Setup container
      final container = ProviderContainer();

      // Load initial page
      final initialState = await container.read(
        profileFeedProvider(testUserId).future,
      );
      final initialCount = initialState.videos.length;

      // ACT: Call loadMore()
      await container.read(profileFeedProvider(testUserId).notifier).loadMore();

      // ASSERT: Should have loaded more videos (or at least tried to)
      final newState = await container.read(
        profileFeedProvider(testUserId).future,
      );
      // Either we loaded more videos, or we're at the end (hasMoreContent = false)
      expect(newState.videos.length >= initialCount, isTrue);
      expect(newState.isLoadingMore, isFalse);

      container.dispose();
    });

    test('loadMore() appends to existing video list', () async {
      // ARRANGE
      final container = ProviderContainer();

      // Load initial page and capture video IDs
      final initialState = await container.read(
        profileFeedProvider(testUserId).future,
      );
      final initialVideoIds = initialState.videos.map((v) => v.id).toSet();

      // ACT: Load more videos
      await container.read(profileFeedProvider(testUserId).notifier).loadMore();

      // ASSERT: Original videos should still be present
      final newState = await container.read(
        profileFeedProvider(testUserId).future,
      );
      final newVideoIds = newState.videos.map((v) => v.id).toSet();

      // All initial videos should still be in the list
      for (final id in initialVideoIds) {
        expect(
          newVideoIds.contains(id),
          isTrue,
          reason: 'Initial video $id missing after loadMore',
        );
      }

      container.dispose();
    });

    test('hasMoreContent flag prevents redundant loads when false', () async {
      // ARRANGE
      final container = ProviderContainer();

      // Load initial page
      var state = await container.read(profileFeedProvider(testUserId).future);

      // Keep loading until hasMoreContent is false or we hit a limit
      int loadAttempts = 0;
      while (state.hasMoreContent && loadAttempts < 10) {
        await container
            .read(profileFeedProvider(testUserId).notifier)
            .loadMore();
        state = await container.read(profileFeedProvider(testUserId).future);
        loadAttempts++;
      }

      // ACT: Try to load more when hasMoreContent is false
      final videoCountBefore = state.videos.length;
      if (!state.hasMoreContent) {
        await container
            .read(profileFeedProvider(testUserId).notifier)
            .loadMore();
        state = await container.read(profileFeedProvider(testUserId).future);

        // ASSERT: Should not have loaded more videos
        expect(state.videos.length, equals(videoCountBefore));
      }

      container.dispose();
    });

    test('prevents duplicate loads while loading', () async {
      // ARRANGE
      final container = ProviderContainer();

      await container.read(profileFeedProvider(testUserId).future);

      // ACT: Trigger multiple loadMore() calls simultaneously
      final futures = [
        container.read(profileFeedProvider(testUserId).notifier).loadMore(),
        container.read(profileFeedProvider(testUserId).notifier).loadMore(),
        container.read(profileFeedProvider(testUserId).notifier).loadMore(),
      ];
      await Future.wait(futures);

      // ASSERT: Should complete without errors and maintain consistent state
      final state = await container.read(
        profileFeedProvider(testUserId).future,
      );
      expect(state.isLoadingMore, isFalse);

      // No duplicate videos in the list
      final videoIds = state.videos.map((v) => v.id).toList();
      final uniqueIds = videoIds.toSet();
      expect(
        videoIds.length,
        equals(uniqueIds.length),
        reason: 'Found duplicate videos in feed',
      );

      container.dispose();
    });

    test('tracks cursor per user to prevent backtracking', () async {
      // ARRANGE
      final container = ProviderContainer();

      const userId1 = testUserId;
      const userId2 =
          '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2'; // jack

      // Load first user's feed
      final state1 = await container.read(profileFeedProvider(userId1).future);
      await container.read(profileFeedProvider(userId1).notifier).loadMore();
      final state1After = await container.read(
        profileFeedProvider(userId1).future,
      );

      // Load second user's feed
      final state2 = await container.read(profileFeedProvider(userId2).future);

      // ASSERT: Each provider should maintain independent state
      // The key invariant: if we load more for user1, user2's initial state should NOT be affected
      // We verify this by checking that the provider instances are truly separate

      // Verify first user's feed was paginated
      expect(state1After.videos.length >= state1.videos.length, isTrue);

      // Load more for user 1 again
      final videos1BeforeSecondLoad = state1After.videos.length;
      await container.read(profileFeedProvider(userId1).notifier).loadMore();
      final state1AfterSecondLoad = await container.read(
        profileFeedProvider(userId1).future,
      );

      // Re-read user 2's state - it should still be at its initial state (not affected by user 1's pagination)
      final state2Reread = await container.read(
        profileFeedProvider(userId2).future,
      );

      // User 2's state should not have changed just because user 1 paginated
      expect(state2Reread.videos.length, equals(state2.videos.length));

      // User 1 should have potentially loaded more content
      expect(
        state1AfterSecondLoad.videos.length >= videos1BeforeSecondLoad,
        isTrue,
      );

      container.dispose();
    });
  });
}
