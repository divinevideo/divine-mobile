// ABOUTME: Simple video list provider for discovery/general content
// ABOUTME: Provides basic video listing without global feed mode management

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_feed_provider.g.dart';

/// Simple discovery video feed provider
@riverpod
class VideoFeed extends _$VideoFeed {
  Timer? _profileFetchTimer;

  @override
  Future<VideoFeedState> build() async {
    Log.info(
      '🔄 VideoFeed: Starting discovery feed build',
      name: 'VideoFeedProvider',
      category: LogCategory.video,
    );

    // Clean up timer on dispose
    ref.onDispose(() {
      _profileFetchTimer?.cancel();
    });

    // Get all videos from Nostr
    final videoEventService = ref.watch(videoEventServiceProvider);
    final isExploreActive = ref.watch(isExploreTabActiveProvider);
    if (isExploreActive) {
      // Only trigger discovery stream when Explore tab is visible
      ref.read(videoEventsProvider);
    }

    final sourceVideos = List<VideoEvent>.from(
      videoEventService.discoveryVideos,
    );

    Log.info(
      '✅ VideoFeed: Retrieved ${sourceVideos.length} video events for discovery',
      name: 'VideoFeedProvider',
      category: LogCategory.video,
    );

    // Sort by creation time (newest first)
    final sortedVideos = List<VideoEvent>.from(sourceVideos);
    sortedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Auto-fetch profiles for new videos and wait for completion
    await _scheduleBatchProfileFetch(sortedVideos);

    final feedState = VideoFeedState(
      videos: sortedVideos,
      hasMoreContent: sortedVideos.length >= 20,
      isLoadingMore: false,
      error: null,
      lastUpdated: DateTime.now(),
    );

    Log.info(
      '📋 VideoFeed: Discovery feed complete - ${sortedVideos.length} videos',
      name: 'VideoFeedProvider',
      category: LogCategory.video,
    );

    return feedState;
  }

  Future<void> _scheduleBatchProfileFetch(List<VideoEvent> videos) async {
    // Cancel any existing timer
    _profileFetchTimer?.cancel();

    // Fetch profiles immediately - no delay needed as provider handles batching internally
    final profilesProvider = ref.read(userProfileProvider.notifier);

    final newPubkeys = videos
        .map((v) => v.pubkey)
        .where((pubkey) => !profilesProvider.hasProfile(pubkey))
        .toSet()
        .toList();

    if (newPubkeys.isNotEmpty) {
      Log.debug(
        'VideoFeed: Fetching ${newPubkeys.length} new profiles immediately and waiting for completion',
        name: 'VideoFeedProvider',
        category: LogCategory.video,
      );

      // Wait for profiles to be fetched before continuing
      await profilesProvider.fetchMultipleProfiles(newPubkeys);

      Log.debug(
        'VideoFeed: Profile fetching completed for ${newPubkeys.length} profiles',
        name: 'VideoFeedProvider',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        'VideoFeed: All ${videos.length} video profiles already cached',
        name: 'VideoFeedProvider',
        category: LogCategory.video,
      );
    }
  }

  /// Load more historical events
  Future<void> loadMore() async {
    final currentState = await future;

    Log.info(
      'VideoFeed: loadMore() called - isLoadingMore: ${currentState.isLoadingMore}',
      name: 'VideoFeedProvider',
      category: LogCategory.video,
    );

    if (currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videoEventService = ref.read(videoEventServiceProvider);
      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.discovery,
      );

      await videoEventService.loadMoreEvents(
        SubscriptionType.discovery,
        limit: 50,
      );

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.discovery,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        'VideoFeed: Loaded $newEventsLoaded new events (total: $eventCountAfter)',
        name: 'VideoFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via dependencies
      final newState = await future;
      state = AsyncData(
        newState.copyWith(
          isLoadingMore: false,
          hasMoreContent: newEventsLoaded > 0,
        ),
      );
    } catch (e) {
      Log.error(
        'VideoFeed: Error loading more: $e',
        name: 'VideoFeedProvider',
        category: LogCategory.video,
      );

      final currentState = await future;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the feed
  Future<void> refresh() async {
    Log.info(
      'VideoFeed: Refreshing discovery feed',
      name: 'VideoFeedProvider',
      category: LogCategory.video,
    );

    // Invalidate video events to force refresh
    ref.invalidate(videoEventsProvider);

    // Invalidate self to rebuild
    ref.invalidateSelf();
  }
}

/// Provider to check if video feed is loading
@riverpod
bool videoFeedLoading(Ref ref) {
  final asyncState = ref.watch(videoFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current video count
@riverpod
int videoFeedCount(Ref ref) {
  final asyncState = ref.watch(videoFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}

/// Provider to check if we have videos
@riverpod
bool hasVideos(Ref ref) {
  final count = ref.watch(videoFeedCountProvider);
  return count > 0;
}
