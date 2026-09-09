// ABOUTME: Popular Videos feed provider showing age-decayed popular videos.
// ABOUTME: Uses VideosRepository's v2 Popular path for Explore pagination.

import 'package:flutter_riverpod/legacy.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/feed_viewer_preference_hints.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'popular_videos_feed_provider.g.dart';

/// Selected source for the Popular tab's v2 feed.
final popularVideosVariantProvider = StateProvider<PopularVideosVariant>(
  (ref) => PopularVideosVariant.native,
);

/// The Popular variant represented by the currently rendered feed data.
///
/// Riverpod can retain the previous AsyncValue while a dependency-triggered
/// rebuild is loading. The Popular tab uses this marker to avoid presenting a
/// stale Native page as Classic (or vice versa) during variant switches.
final popularVideosLoadedVariantProvider = StateProvider<PopularVideosVariant?>(
  (ref) => null,
);

/// Popular Videos feed provider - shows trending videos by recent engagement.
///
/// Delegates video fetching to [VideosRepository.getPopularVideos] with the
/// selected native/classic variant.
///
/// Rebuilds when:
/// - Pull to refresh
/// - appReady gate becomes true
/// - Content filter preferences change
@Riverpod(keepAlive: true)
class PopularVideosFeed extends _$PopularVideosFeed {
  String? _nextCursor;
  PopularVideosVariant? _pendingLoadedVariant;
  void Function()? _removeLoadedVariantListener;
  final _enrichmentAttemptTracker = NostrTagEnrichmentAttemptTracker();

  @override
  Future<VideoFeedState> build() async {
    _listenForLoadedVariantState();
    ref.listen(popularVideosVariantProvider, (previous, next) {
      if (previous == next) return;
      _pendingLoadedVariant = null;
      ref.read(popularVideosLoadedVariantProvider.notifier).state = null;
    });

    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(languagePreferenceVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

    // Watch the user-selected native/classic split.
    final variant = ref.watch(popularVideosVariantProvider);
    _nextCursor = null;

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      'PopularVideosFeed: Building (appReady: $isAppReady, variant: ${variant.name})',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      // Preserve existing data during background — don't wipe the feed
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          return existing.copyWith(
            videos: _filterVideos(existing.videos, variant),
          );
        }
      }
      return const VideoFeedState(videos: [], hasMoreContent: true);
    }

    return _loadFirstPage(variant);
  }

  Future<VideoFeedState> _loadFirstPage(
    PopularVideosVariant variant, {
    bool skipCache = false,
    bool preserveExistingOnError = false,
  }) async {
    try {
      final page = await _fetchFirstPage(variant, skipCache: skipCache);

      if (!ref.mounted) {
        return const VideoFeedState(videos: [], hasMoreContent: true);
      }

      if (page.videos.isNotEmpty) {
        _applyPage(page);

        final filteredVideos = _filterVideos(page.videos, variant);
        _scheduleEnrichment(filteredVideos);

        Log.info(
          'PopularVideosFeed: Got ${filteredVideos.length} trending videos',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );

        final feedState = VideoFeedState(
          videos: filteredVideos,
          hasMoreContent: _pageHasMoreContent(page),
          lastUpdated: DateTime.now(),
        );
        _markLoadedWhenPublished(variant);
        return feedState;
      }

      Log.warning(
        'PopularVideosFeed: No videos returned',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      _markLoadedWhenPublished(variant);
      return const VideoFeedState(videos: [], hasMoreContent: false);
    } catch (e) {
      Log.error(
        'PopularVideosFeed: Error loading videos: $e',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );
      if (preserveExistingOnError) rethrow;
      _markLoadedWhenPublished(variant);
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: e.toString(),
      );
    }
  }

  Future<PopularVideosPage> _fetchFirstPage(
    PopularVideosVariant variant, {
    required bool skipCache,
  }) async {
    final videosRepository = ref.read(videosRepositoryProvider);
    final hints = await readFeedViewerPreferenceHints(ref.read);
    return videosRepository.getPopularVideosPage(
      limit: AppConstants.paginationBatchSize,
      variant: variant,
      skipCache: skipCache,
      preferredLanguages: hints.preferredLanguages,
      viewerCountry: hints.viewerCountry,
    );
  }

  /// Warms the repository-backed first page for [variant] without changing the
  /// visible feed when another variant is selected.
  Future<void> preloadVariant(PopularVideosVariant variant) async {
    try {
      await _fetchFirstPage(variant, skipCache: false);
    } catch (e) {
      Log.warning(
        'PopularVideosFeed: Failed to preload ${variant.name} variant: $e',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );
    }
  }

  /// Load more videos for pagination.
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) return;
    if (!currentState.hasMoreContent) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final variant = ref.read(popularVideosVariantProvider);
      final newVideos = await _fetchNextPage();

      if (!ref.mounted) return;

      if (newVideos.videos.isEmpty) {
        state = AsyncData(
          currentState.copyWith(hasMoreContent: false, isLoadingMore: false),
        );
        return;
      }

      _applyPage(newVideos);

      // Deduplicate against existing videos by addressable identity.
      final dedupedNew = dedupeByFeedKey(
        newVideos.videos,
        alreadySeen: currentState.videos.map((v) => v.feedDedupKey),
      );

      final filteredNew = _filterVideos(dedupedNew, variant);

      if (filteredNew.isEmpty) {
        state = AsyncData(
          currentState.copyWith(
            hasMoreContent: _pageHasMoreContent(newVideos),
            isLoadingMore: false,
          ),
        );
        return;
      }
      final allVideos = [...currentState.videos, ...filteredNew];

      Log.info(
        'PopularVideosFeed: Loaded ${filteredNew.length} more videos '
        '(total: ${allVideos.length})',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      state = AsyncData(
        VideoFeedState(
          videos: allVideos,
          hasMoreContent: _pageHasMoreContent(newVideos),
          lastUpdated: DateTime.now(),
        ),
      );

      _scheduleEnrichment(filteredNew);
    } catch (e) {
      Log.error(
        'PopularVideosFeed: Error loading more: $e',
        name: 'PopularVideosFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  Future<PopularVideosPage> _fetchNextPage() async {
    final videosRepository = ref.read(videosRepositoryProvider);
    final hints = await readFeedViewerPreferenceHints(ref.read);
    return videosRepository.getPopularVideosPage(
      limit: AppConstants.paginationBatchSize,
      cursor: _nextCursor,
      variant: ref.read(popularVideosVariantProvider),
      preferredLanguages: hints.preferredLanguages,
      viewerCountry: hints.viewerCountry,
    );
  }

  /// Refresh the feed while preserving visible videos during revalidation.
  Future<void> refresh() async {
    Log.info(
      'PopularVideosFeed: Refreshing',
      name: 'PopularVideosFeedProvider',
      category: LogCategory.video,
    );

    final variant = ref.read(popularVideosVariantProvider);
    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: () => _loadFirstPage(
        variant,
        skipCache: true,
        preserveExistingOnError: true,
      ),
    );
  }

  /// Applies platform compatibility, content preference,
  /// and blocked user filters.
  List<VideoEvent> _filterVideos(
    List<VideoEvent> videos,
    PopularVideosVariant variant,
  ) {
    final videoEventService = ref.read(videoEventServiceProvider);
    final compatibleVideos = videos.where(
      (v) => v.isSupportedOnCurrentPlatform,
    );
    final platformVideos = variant == PopularVideosVariant.native
        ? compatibleVideos.where((v) => !v.isOriginalVine)
        : compatibleVideos;
    return videoEventService.filterVideoList(platformVideos.toList());
  }

  void _applyPage(PopularVideosPage page) {
    _nextCursor = page.nextCursor;
  }

  bool _pageHasMoreContent(PopularVideosPage page) {
    return page.hasMore;
  }

  void _listenForLoadedVariantState() {
    if (_removeLoadedVariantListener != null) return;
    _removeLoadedVariantListener = listenSelf((_, next) {
      if (!next.hasValue) return;
      final variant = _pendingLoadedVariant;
      if (variant == null) return;
      _pendingLoadedVariant = null;
      _markLoadedIfActive(variant);
    });
    ref.onDispose(() {
      _removeLoadedVariantListener?.call();
      _removeLoadedVariantListener = null;
    });
  }

  void _markLoadedWhenPublished(PopularVideosVariant variant) {
    _pendingLoadedVariant = variant;
  }

  void _markLoadedIfActive(PopularVideosVariant variant) {
    if (!ref.mounted) return;
    if (ref.read(popularVideosVariantProvider) != variant) return;
    ref.read(popularVideosLoadedVariantProvider.notifier).state = variant;
  }

  void _scheduleEnrichment(List<VideoEvent> videos) {
    if (videos.isEmpty) return;

    enrichVideosInBackground(
      videos,
      nostrService: ref.read(nostrServiceProvider),
      callerName: 'PopularVideosFeedProvider',
      attemptTracker: _enrichmentAttemptTracker,
      onEnriched: (enrichedVideos) {
        if (!ref.mounted || !state.hasValue) return;

        final currentState = state.value;
        if (currentState == null || currentState.videos.isEmpty) return;

        final mergedVideos = mergeEnrichedVideos(
          existing: currentState.videos,
          enriched: enrichedVideos,
        );

        if (videoListsEqual(currentState.videos, mergedVideos)) {
          return;
        }

        state = AsyncData(
          currentState.copyWith(
            videos: mergedVideos,
            lastUpdated: DateTime.now(),
          ),
        );

        Log.info(
          'PopularVideosFeed: Applied background Nostr enrichment to ${enrichedVideos.length} videos',
          name: 'PopularVideosFeedProvider',
          category: LogCategory.video,
        );
      },
    );
  }
}
