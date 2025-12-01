// ABOUTME: Profile feed provider with cursor pagination support per user
// ABOUTME: Manages video lists for individual user profiles with loadMore() capability

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_feed_provider.g.dart';

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent cursor tracking.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```
@riverpod
class ProfileFeed extends _$ProfileFeed {
  @override
  Future<VideoFeedState> build(String userId) async {
    Log.info(
      'ProfileFeed: BUILD START for user=${userId}...',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    // Get video event service
    final videoEventService = ref.watch(videoEventServiceProvider);

    // Subscribe to this user's videos
    await videoEventService.subscribeToUserVideos(userId, limit: 100);

    // Wait for initial batch of videos to arrive from relay
    final completer = Completer<void>();
    int stableCount = 0;
    Timer? stabilityTimer;

    void checkStability() {
      final currentCount = videoEventService.authorVideos(userId).length;
      if (currentCount != stableCount) {
        // Count changed, reset stability timer
        stableCount = currentCount;
        stabilityTimer?.cancel();
        stabilityTimer = Timer(const Duration(milliseconds: 300), () {
          // Count stable for 300ms, we're done
          if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }
    }

    videoEventService.addListener(checkStability);

    // Also set a maximum wait time
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Trigger initial check
    checkStability();

    await completer.future;

    // Clean up
    videoEventService.removeListener(checkStability);
    stabilityTimer?.cancel();

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    // Get videos for this author
    final authorVideos = List<VideoEvent>.from(
      videoEventService.authorVideos(userId),
    );

    Log.info(
      'ProfileFeed: Initial load complete - ${authorVideos.length} videos for user=${userId}...',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    return VideoFeedState(
      videos: authorVideos,
      hasMoreContent: authorVideos.length >= 10,
      isLoadingMore: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// Load more historical events for this specific user
  Future<void> loadMore() async {
    final currentState = await future;

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    Log.info(
      'ProfileFeed: loadMore() called for user=${userId}... - isLoadingMore: ${currentState.isLoadingMore}',
      name: 'ProfileFeedProvider',
      category: LogCategory.video,
    );

    if (currentState.isLoadingMore) {
      Log.debug(
        'ProfileFeed: Already loading more, skipping',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    if (!currentState.hasMoreContent) {
      Log.debug(
        'ProfileFeed: No more content available, skipping',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videoEventService = ref.read(videoEventServiceProvider);

      // Find the oldest timestamp from current videos to use as cursor
      int? until;
      if (currentState.videos.isNotEmpty) {
        until = currentState.videos
            .map((v) => v.createdAt)
            .reduce((a, b) => a < b ? a : b);

        Log.debug(
          'ProfileFeed: Using cursor until=${DateTime.fromMillisecondsSinceEpoch(until * 1000)}',
          name: 'ProfileFeedProvider',
          category: LogCategory.video,
        );
      }

      final eventCountBefore = videoEventService.authorVideos(userId).length;

      // Query for older events from this specific user
      await videoEventService.queryHistoricalUserVideos(
        userId,
        until: until,
        limit: 50,
      );

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.authorVideos(userId).length;
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        'ProfileFeed: Loaded $newEventsLoaded new events for user=${userId}... (total: $eventCountAfter)',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );

      // Get updated videos
      final updatedVideos = List<VideoEvent>.from(
        videoEventService.authorVideos(userId),
      );

      // Update state with new videos
      if (!ref.mounted) return;
      state = AsyncData(
        VideoFeedState(
          videos: updatedVideos,
          hasMoreContent: newEventsLoaded > 0,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        'ProfileFeed: Error loading more: $e',
        name: 'ProfileFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }
}
