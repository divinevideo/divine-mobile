// ABOUTME: For You recommendations provider - ML-powered personalized video feed
// ABOUTME: Uses Funnelcake REST API for Gorse-based recommendations (staging only)

import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/feed_viewer_preference_hints.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'for_you_provider.g.dart';

/// For You recommendations feed provider - ML-powered personalized videos
///
/// Uses Gorse-based recommendations from Funnelcake REST API.
/// Falls back to popular videos when personalization isn't available.
/// Currently only enabled on staging environment for testing.
@Riverpod(keepAlive: true)
class ForYouFeed extends _$ForYouFeed {
  static const int _pageSize = 50;

  String? _nextCursor;
  int _feedGeneration = 0;

  @override
  Future<VideoFeedState> build() async {
    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(languagePreferenceVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🎯 ForYouFeed: Building feed (appReady: $isAppReady)',
      name: 'ForYouFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      // Preserve existing data during background — don't wipe the feed
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          Log.info(
            '🎯 ForYouFeed: App not ready, preserving ${existing.videos.length} cached videos',
            name: 'ForYouFeedProvider',
            category: LogCategory.video,
          );
          return existing.copyWith(videos: _filterVideos(existing.videos));
        }
      }
      Log.info(
        '🎯 ForYouFeed: App not ready, no cached data yet',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    // Get current user pubkey
    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    if (currentUserPubkey == null) {
      Log.warning(
        '🎯 ForYouFeed: No user logged in, returning empty state',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

    Log.info(
      '🎯 ForYouFeed: Funnelcake available: $funnelcakeAvailable',
      name: 'ForYouFeedProvider',
      category: LogCategory.video,
    );

    if (!funnelcakeAvailable) {
      Log.warning(
        '🎯 ForYouFeed: Funnelcake not available, returning empty state',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    return _fetchRecommendations();
  }

  Future<VideoFeedState> _fetchRecommendations({
    bool preserveExistingOnError = false,
    bool skipCache = false,
  }) async {
    final generation = _feedGeneration + 1;
    _feedGeneration = generation;
    try {
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        return const VideoFeedState(videos: [], hasMoreContent: false);
      }

      final hints = await readFeedViewerPreferenceHints(ref.read);
      final result = await ref
          .read(videosRepositoryProvider)
          .getRecommendedVideos(
            userPubkey: currentUserPubkey,
            limit: _pageSize,
            skipCache: skipCache,
            preferredLanguages: hints.preferredLanguages,
            viewerCountry: hints.viewerCountry,
          );

      Log.info(
        '✅ ForYouFeed: Got ${result.videos.length} recommendations',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) {
        return const VideoFeedState(videos: [], hasMoreContent: false);
      }
      if (_feedGeneration != generation) {
        return state.asData?.value ??
            const VideoFeedState(videos: [], hasMoreContent: false);
      }

      return _stateFromResult(result);
    } catch (e) {
      Log.error(
        '🎯 ForYouFeed: Error fetching recommendations: $e',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );
      if (preserveExistingOnError) rethrow;
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: e.toString(),
      );
    }
  }

  /// Load more recommendations
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final funnelcakeAvailable =
          ref.read(funnelcakeAvailableProvider).asData?.value ?? false;
      if (!funnelcakeAvailable) {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final cursor = _nextCursor;
      final generation = _feedGeneration;
      if (cursor == null) {
        state = AsyncData(
          currentState.copyWith(isLoadingMore: false, hasMoreContent: false),
        );
        return;
      }
      final hints = await readFeedViewerPreferenceHints(ref.read);
      final result = await ref
          .read(videosRepositoryProvider)
          .getRecommendedVideos(
            userPubkey: currentUserPubkey,
            limit: _pageSize,
            cursor: cursor,
            preferredLanguages: hints.preferredLanguages,
            viewerCountry: hints.viewerCountry,
          );

      if (!ref.mounted) return;
      if (_feedGeneration != generation || _nextCursor != cursor) {
        return;
      }

      final newVideos = dedupeByFeedKey(
        _filterVideos(result.videos),
        alreadySeen: currentState.videos.map((video) => video.feedDedupKey),
      );
      final mergedVideos = [...currentState.videos, ...newVideos];
      final newEventsLoaded = newVideos.length;

      Log.info(
        '🎯 ForYouFeed: Loaded $newEventsLoaded more recommendations (total: ${mergedVideos.length})',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );

      _nextCursor = result.paginationCursor;

      state = AsyncData(
        VideoFeedState(
          videos: mergedVideos,
          hasMoreContent: result.hasMore == true && _nextCursor != null,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        '🎯 ForYouFeed: Error loading more: $e',
        name: 'ForYouFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the For You feed
  Future<void> refresh() async {
    Log.info(
      '🎯 ForYouFeed: Refreshing feed - fetching fresh recommendations',
      name: 'ForYouFeedProvider',
      category: LogCategory.video,
    );

    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: () =>
          _fetchRecommendations(preserveExistingOnError: true, skipCache: true),
    );
  }

  VideoFeedState _stateFromResult(HomeFeedResult result) {
    _nextCursor = result.paginationCursor;
    return VideoFeedState(
      videos: dedupeByFeedKey(_filterVideos(result.videos)),
      hasMoreContent: result.hasMore == true && _nextCursor != null,
      lastUpdated: DateTime.now(),
    );
  }

  List<VideoEvent> _filterVideos(List<VideoEvent> videos) {
    final videoEventService = ref.read(videoEventServiceProvider);
    return videoEventService.filterVideoList(
      videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
    );
  }
}

/// Provider to check if For You tab should be visible
///
/// Available when Funnelcake REST API is available (has recommendations endpoint).
@riverpod
bool forYouAvailable(Ref ref) {
  final funnelcakeAvailable =
      ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

  // Show when Funnelcake is available (production, staging, or dev with Funnelcake)
  return funnelcakeAvailable;
}

/// Provider to check if For You feed is loading
@riverpod
bool forYouFeedLoading(Ref ref) {
  final asyncState = ref.watch(forYouFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current For You feed video count
@riverpod
int forYouFeedCount(Ref ref) {
  final asyncState = ref.watch(forYouFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}
