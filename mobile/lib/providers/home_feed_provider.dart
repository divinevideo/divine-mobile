// ABOUTME: Home feed provider that shows videos only from people you follow
// ABOUTME: Filters video events by the user's following list for a personalized feed

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_feed_provider.g.dart';

/// Auto-refresh interval for home feed (10 minutes in production, overridable in tests)
@Riverpod(keepAlive: true)
Duration homeFeedPollInterval(Ref ref) => const Duration(minutes: 10);

/// Home feed provider - shows videos only from people you follow
///
/// Rebuilds occur when:
/// - Contact list changes (follow/unfollow)
/// - Poll interval elapses (default 10 minutes, injectable via homeFeedPollIntervalProvider)
/// - User pulls to refresh
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose
@Riverpod(keepAlive: false) // Auto-dispose when no listeners
class HomeFeed extends _$HomeFeed {
  Timer? _profileFetchTimer;
  Timer? _autoRefreshTimer;
  static int _buildCounter = 0;
  static DateTime? _lastBuildTime;

  @override
  Future<VideoFeedState> build() async {
    // Prevent auto-dispose during async operations
    final keepAliveLink = ref.keepAlive();

    _buildCounter++;
    final buildId = _buildCounter;
    final now = DateTime.now();
    final timeSinceLastBuild = _lastBuildTime != null
        ? now.difference(_lastBuildTime!).inMilliseconds
        : null;

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId START at ${now.millisecondsSinceEpoch}ms'
      '${timeSinceLastBuild != null ? ' (${timeSinceLastBuild}ms since last build)' : ''}',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (timeSinceLastBuild != null && timeSinceLastBuild < 2000) {
      Log.warning(
        '⚠️  HomeFeed: RAPID REBUILD DETECTED! Only ${timeSinceLastBuild}ms since last build. '
        'This may indicate a provider dependency issue.',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    _lastBuildTime = now;

    // Get injectable poll interval (overridable in tests)
    final pollInterval = ref.read(homeFeedPollIntervalProvider);

    // Timer lifecycle management
    void startAutoRefresh() {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer(pollInterval, () {
        Log.info(
          '🏠 HomeFeed: Auto-refresh triggered after ${pollInterval.inMinutes} minutes',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        if (ref.mounted) {
          ref.invalidateSelf();
        }
      });
    }

    void stopAutoRefresh() {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }

    // Start timer when provider is first watched or resumed
    ref.onResume(() {
      Log.debug(
        '🏠 HomeFeed: Resuming auto-refresh timer',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      startAutoRefresh();
    });

    // Pause timer when all listeners detach
    ref.onCancel(() {
      Log.debug(
        '🏠 HomeFeed: Pausing auto-refresh timer (no listeners)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      stopAutoRefresh();
    });

    // Clean up timers on dispose
    ref.onDispose(() {
      Log.info(
        '🏠 HomeFeed: BUILD #$buildId DISPOSED',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      stopAutoRefresh();
      _profileFetchTimer?.cancel();
    });

    // Start timer immediately for first build
    startAutoRefresh();

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId watching socialProvider...',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Read social provider to get following list
    // Use ref.read() instead of ref.watch() to avoid rebuilding on every social state change
    // We'll use ref.listen() below to invalidate only when following list changes
    final socialData = ref.read(social.socialProvider);
    final followingPubkeys = socialData.followingPubkeys;

    // Listen to social provider and invalidate ONLY when following list changes
    ref.listen(social.socialProvider, (prev, next) {
      // Only invalidate if the following list actually changed
      if (prev?.followingPubkeys != next.followingPubkeys) {
        Log.info(
          '🏠 HomeFeed: Following list changed (${prev?.followingPubkeys.length ?? 0} → ${next.followingPubkeys.length}), invalidating...',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        ref.invalidateSelf();
      }
    });

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId - User is following ${followingPubkeys.length} people',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (followingPubkeys.isEmpty) {
      // Return empty state if not following anyone
      keepAliveLink.close();
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      );
    }

    // Get video event service and subscribe to following feed
    final videoEventService = ref.watch(videoEventServiceProvider);

    // Subscribe to home feed videos from followed authors using dedicated subscription type
    // NostrService now handles deduplication automatically
    // Request server-side sorting by created_at (newest first) if relay supports it
    await videoEventService.subscribeToHomeFeed(
      followingPubkeys,
      limit: 100,
      sortBy: VideoSortField.createdAt, // Newest videos first (timeline order)
    );

    // Wait for initial batch of videos to arrive from relay
    // Videos arrive in rapid succession, so we wait for the count to stabilize
    final completer = Completer<void>();
    int stableCount = 0;
    Timer? stabilityTimer;

    void checkStability() {
      final currentCount = videoEventService.homeFeedVideos.length;
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
      keepAliveLink.close();
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      );
    }

    // Get videos from the dedicated home feed list (server-side filtered to only following)
    var followingVideos = List<VideoEvent>.from(
      videoEventService.homeFeedVideos,
    );

    Log.info(
      '🏠 HomeFeed: Server-side filtered to ${followingVideos.length} videos from following',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
    final beforeFilter = followingVideos.length;
    followingVideos = followingVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();
    if (beforeFilter != followingVideos.length) {
      Log.info(
        '🏠 HomeFeed: Filtered out ${beforeFilter - followingVideos.length} unsupported videos (WebM on iOS/macOS)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    // DEBUG: Dump all events with cdn.divine.video thumbnails
    videoEventService.debugDumpCdnDivineVideoThumbnails();

    // Sort by creation time (newest first) with stable secondary sort by ID
    // This prevents videos with identical timestamps from jumping around
    followingVideos.sort((a, b) {
      final timeCompare = b.createdAt.compareTo(a.createdAt);
      if (timeCompare != 0) return timeCompare;
      // Secondary sort by ID for stable ordering when timestamps match
      return a.id.compareTo(b.id);
    });

    Log.info(
      '🏠 HomeFeed: Sorted ${followingVideos.length} videos by creation time (newest first)',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Auto-fetch profiles for new videos and wait for completion
    await _scheduleBatchProfileFetch(followingVideos);

    // Check if provider is still mounted after async gap
    if (!ref.mounted) {
      keepAliveLink.close();
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      );
    }

    final feedState = VideoFeedState(
      videos: followingVideos,
      hasMoreContent: followingVideos.length >= 10,
      isLoadingMore: false,
      error: null,
      lastUpdated: DateTime.now(),
    );

    final buildDuration = DateTime.now().difference(now).inMilliseconds;

    Log.info(
      '✅ HomeFeed: BUILD #$buildId COMPLETE - ${followingVideos.length} videos from following in ${buildDuration}ms',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Close keepAlive link to allow auto-dispose after build completes
    keepAliveLink.close();

    return feedState;
  }

  Future<void> _scheduleBatchProfileFetch(List<VideoEvent> videos) async {
    // Cancel any existing timer
    _profileFetchTimer?.cancel();

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    // Fetch profiles immediately - no delay needed as provider handles batching internally
    final profilesProvider = ref.read(userProfileProvider.notifier);

    final newPubkeys = videos
        .map((v) => v.pubkey)
        .where((pubkey) => !profilesProvider.hasProfile(pubkey))
        .toSet()
        .toList();

    if (newPubkeys.isNotEmpty) {
      Log.debug(
        'HomeFeed: Fetching ${newPubkeys.length} new profiles immediately and waiting for completion',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Wait for profiles to be fetched before continuing
      await profilesProvider.fetchMultipleProfiles(newPubkeys);

      Log.debug(
        'HomeFeed: Profile fetching completed for ${newPubkeys.length} profiles',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        'HomeFeed: All ${videos.length} video profiles already cached',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }
  }

  /// Load more historical events from followed authors
  Future<void> loadMore() async {
    final currentState = await future;

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    Log.info(
      'HomeFeed: loadMore() called - isLoadingMore: ${currentState.isLoadingMore}',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videoEventService = ref.read(videoEventServiceProvider);
      final socialData = ref.read(social.socialProvider);
      final followingPubkeys = socialData.followingPubkeys;

      if (followingPubkeys.isEmpty) {
        // No one to load more from
        if (!ref.mounted) return;
        state = AsyncData(
          currentState.copyWith(isLoadingMore: false, hasMoreContent: false),
        );
        return;
      }

      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.homeFeed,
      );

      // Load more events for home feed subscription type
      await videoEventService.loadMoreEvents(
        SubscriptionType.homeFeed,
        limit: 50,
      );

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.homeFeed,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        'HomeFeed: Loaded $newEventsLoaded new events from following (total: $eventCountAfter)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via dependencies
      final newState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        newState.copyWith(
          isLoadingMore: false,
          hasMoreContent: newEventsLoaded > 0,
        ),
      );
    } catch (e) {
      Log.error(
        'HomeFeed: Error loading more: $e',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      final currentState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the home feed
  Future<void> refresh() async {
    Log.info(
      'HomeFeed: Refreshing home feed (following only)',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Get video event service and force a fresh subscription
    final videoEventService = ref.read(videoEventServiceProvider);
    final socialData = ref.read(social.socialProvider);
    final followingPubkeys = socialData.followingPubkeys;

    if (followingPubkeys.isNotEmpty) {
      // Force new subscription to get fresh data from relay
      await videoEventService.subscribeToHomeFeed(
        followingPubkeys,
        limit: 100,
        sortBy: VideoSortField.createdAt,
        force: true, // Force refresh bypasses duplicate detection
      );
    }

    // Invalidate self to rebuild with fresh data
    ref.invalidateSelf();
  }
}

/// Provider to check if home feed is loading
@riverpod
bool homeFeedLoading(Ref ref) {
  final asyncState = ref.watch(homeFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current home feed video count
@riverpod
int homeFeedCount(Ref ref) {
  final asyncState = ref.watch(homeFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}

/// Provider to check if we have home feed videos
@riverpod
bool hasHomeFeedVideos(Ref ref) {
  final count = ref.watch(homeFeedCountProvider);
  return count > 0;
}
