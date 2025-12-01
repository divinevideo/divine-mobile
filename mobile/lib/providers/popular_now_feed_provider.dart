// ABOUTME: PopularNow feed provider showing newest videos using VideoFeedBuilder helper
// ABOUTME: Subscribes to SubscriptionType.popularNow and sorts by timestamp (newest first)

import 'package:openvine/helpers/video_feed_builder.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popular_now_feed_provider.g.dart';

/// PopularNow feed provider - shows newest videos (sorted by creation time)
///
/// Rebuilds when:
/// - Poll interval elapses (uses same auto-refresh as home feed)
/// - User pulls to refresh
/// - VideoEventService updates with new videos
/// - appReady gate becomes true (triggers rebuild to start subscription)
@Riverpod(keepAlive: true) // Keep alive to prevent state loss on tab switches
class PopularNowFeed extends _$PopularNowFeed {
  VideoFeedBuilder? _builder;

  @override
  Future<VideoFeedState> build() async {
    // Watch appReady gate - provider rebuilds when this changes
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🆕 PopularNowFeed: Building feed for newest videos (appReady: $isAppReady)',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    final videoEventService = ref.watch(videoEventServiceProvider);

    // If app is not ready, return empty state - will rebuild when appReady becomes true
    if (!isAppReady) {
      Log.info(
        '🆕 PopularNowFeed: App not ready, returning empty state (will rebuild when ready)',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: true, // Assume there's content to load when ready
        isLoadingMore: false,
      );
    }

    _builder = VideoFeedBuilder(videoEventService);

    // Configure feed for popularNow subscription type
    final config = VideoFeedConfig(
      subscriptionType: SubscriptionType.popularNow,
      subscribe: (service) async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: 100,
          sortBy: VideoSortField.createdAt, // Newest videos first
        );
      },
      getVideos: (service) => service.popularNowVideos,
      filterVideos: (videos) {
        // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
        return videos.where((v) => v.isSupportedOnCurrentPlatform).toList();
      },
      sortVideos: (videos) {
        final sorted = List<VideoEvent>.from(videos);
        sorted.sort((a, b) {
          final timeCompare = b.timestamp.compareTo(a.timestamp);
          if (timeCompare != 0) return timeCompare;
          // Secondary sort by ID for stable ordering
          return a.id.compareTo(b.id);
        });
        return sorted;
      },
    );

    // Build feed using helper
    final state = await _builder!.buildFeed(config: config);

    // Check if still mounted after async gap
    if (!ref.mounted) {
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      );
    }

    // Set up continuous listener for updates
    _builder!.setupContinuousListener(
      config: config,
      onUpdate: (newState) {
        if (ref.mounted) {
          this.state = AsyncData(newState);
        }
      },
    );

    // Clean up on dispose
    ref.onDispose(() {
      _builder?.cleanup();
      _builder = null;
      Log.info(
        '🆕 PopularNowFeed: Disposed',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );
    });

    Log.info(
      '✅ PopularNowFeed: Feed built with ${state.videos.length} videos',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    return state;
  }

  /// Load more historical events
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videoEventService = ref.read(videoEventServiceProvider);
      final eventCountBefore = videoEventService.getEventCount(
        SubscriptionType.popularNow,
      );

      // Load more events for popularNow subscription type
      await videoEventService.loadMoreEvents(
        SubscriptionType.popularNow,
        limit: 50,
      );

      if (!ref.mounted) return;

      final eventCountAfter = videoEventService.getEventCount(
        SubscriptionType.popularNow,
      );
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        '🆕 PopularNowFeed: Loaded $newEventsLoaded new events (total: $eventCountAfter)',
        name: 'PopularNowFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via listener
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
        '🆕 PopularNowFeed: Error loading more: $e',
        name: 'PopularNowFeedProvider',
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

  /// Refresh the feed
  Future<void> refresh() async {
    Log.info(
      '🆕 PopularNowFeed: Refreshing feed',
      name: 'PopularNowFeedProvider',
      category: LogCategory.video,
    );

    final videoEventService = ref.read(videoEventServiceProvider);

    // Force new subscription to get fresh data from relay
    await videoEventService.subscribeToVideoFeed(
      subscriptionType: SubscriptionType.popularNow,
      limit: 100,
      sortBy: VideoSortField.createdAt,
      force: true, // Force refresh bypasses duplicate detection
    );

    // Invalidate self to rebuild with fresh data
    ref.invalidateSelf();
  }
}

/// Provider to check if popularNow feed is loading
@riverpod
bool popularNowFeedLoading(Ref ref) {
  final asyncState = ref.watch(popularNowFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current popularNow feed video count
@riverpod
int popularNowFeedCount(Ref ref) {
  final asyncState = ref.watch(popularNowFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}
