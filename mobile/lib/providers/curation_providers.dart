// ABOUTME: Riverpod provider for content curation with reactive updates
// ABOUTME: Manages only editor picks - trending/popular handled by infinite feeds

import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/state/curation_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'curation_providers.g.dart';

/// Provider for analytics API service
@riverpod
AnalyticsApiService analyticsApiService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);

  return AnalyticsApiService(
    nostrService: nostrService,
    videoEventService: videoEventService,
  );
}

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation
@Riverpod(keepAlive: true)
class Curation extends _$Curation {
  @override
  CurationState build() {
    // Auto-refresh when video events change
    ref.listen(videoEventsProvider, (previous, next) {
      // Only refresh if we have new video events
      final prevLength = previous?.hasValue == true
          ? (previous!.value?.length ?? 0)
          : 0;
      final nextLength = (next.hasValue) ? (next.value?.length ?? 0) : 0;
      if (next.hasValue && prevLength != nextLength) {
        _refreshCurationSets();
      }
    });

    // Initialize with empty state
    _initializeCuration();

    return CurationState(editorsPicks: [], isLoading: true);
  }

  Future<void> _initializeCuration() async {
    try {
      final service = ref.read(curationServiceProvider);

      Log.debug(
        'Curation: Initializing curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      // CurationService initializes itself in constructor
      // Just get the current data
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        isLoading: false,
      );

      Log.info(
        'Curation: Loaded ${state.editorsPicks.length} editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Initialization error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = CurationState(
        editorsPicks: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _refreshCurationSets() async {
    final service = ref.read(curationServiceProvider);

    try {
      service.refreshIfNeeded();

      // Update state with refreshed data
      state = state.copyWith(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        error: null,
      );

      Log.debug(
        'Curation: Refreshed curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Refresh error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = state.copyWith(error: e.toString());
    }
  }

  /// Refresh all curation sets (currently just Editor's Picks)
  Future<void> refreshAll() async {
    await _refreshCurationSets();
  }

  /// Force refresh all curation sets
  Future<void> forceRefresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final service = ref.read(curationServiceProvider);

      // Force refresh from remote
      await service.refreshCurationSets();

      // Update state
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        isLoading: false,
      );

      Log.info(
        'Curation: Force refreshed editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Curation: Force refresh error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Provider to check if curation is loading
@riverpod
bool curationLoading(Ref ref) => ref.watch(curationProvider).isLoading;

/// Provider to get editor's picks
@riverpod
List<VideoEvent> editorsPicks(Ref ref) =>
    ref.watch(curationProvider.select((state) => state.editorsPicks));

/// Provider for analytics-based trending videos
@riverpod
class AnalyticsTrending extends _$AnalyticsTrending {
  @override
  List<VideoEvent> build() {
    // Initialize empty list, will be populated on refresh
    return [];
  }

  /// Refresh trending videos from analytics API
  Future<void> refresh({String timeWindow = '7d'}) async {
    Log.info(
      'AnalyticsTrending: Refreshing trending videos from analytics API (window: $timeWindow)',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      final service = ref.read(analyticsApiServiceProvider);
      final videos = await service.getTrendingVideos(
        timeWindow: timeWindow,
        forceRefresh: true,
      );

      // Update state with new trending videos
      state = videos;

      Log.info(
        'AnalyticsTrending: Loaded ${state.length} trending videos',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'AnalyticsTrending: Error refreshing: $e',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
      // Keep existing state on error
    }
  }

  /// Load more trending videos for pagination
  Future<void> loadMore() async {
    final currentCount = state.length;

    Log.info(
      'AnalyticsTrending: Loading more trending videos (current: $currentCount)',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      final service = ref.read(analyticsApiServiceProvider);

      // IMPORTANT: The analytics API currently returns a fixed set of trending videos
      // If we already have videos and the API returns the same or fewer videos,
      // don't update state to avoid infinite loops
      final videos = await service.getTrendingVideos(
        limit: currentCount + 50,
        forceRefresh: true,
      );

      if (videos.length > currentCount) {
        state = videos;
        Log.info(
          'AnalyticsTrending: Loaded ${videos.length - currentCount} more videos (total: ${videos.length})',
          name: 'AnalyticsTrendingProvider',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'AnalyticsTrending: No new videos available from API (requested: ${currentCount + 50}, received: ${videos.length})',
          name: 'AnalyticsTrendingProvider',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'AnalyticsTrending: Error loading more: $e',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
    }
  }
}

/// Provider for analytics-based popular videos
@riverpod
class AnalyticsPopular extends _$AnalyticsPopular {
  @override
  List<VideoEvent> build() {
    // Initialize empty list, will be populated on refresh
    return [];
  }

  /// Refresh popular videos from analytics API
  Future<void> refresh() async {
    Log.info(
      'AnalyticsPopular: Refreshing popular videos from analytics API',
      name: 'AnalyticsPopularProvider',
      category: LogCategory.system,
    );

    try {
      final service = ref.read(analyticsApiServiceProvider);
      // Popular uses 7 day window to get recent popular content
      final videos = await service.getTrendingVideos(
        timeWindow: '7d',
        forceRefresh: true,
      );

      // Update state with new popular videos
      state = videos;

      Log.info(
        'AnalyticsPopular: Loaded ${state.length} popular videos',
        name: 'AnalyticsPopularProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'AnalyticsPopular: Error refreshing: $e',
        name: 'AnalyticsPopularProvider',
        category: LogCategory.system,
      );
      // Keep existing state on error
    }
  }
}

/// Provider for trending hashtags
@riverpod
class TrendingHashtags extends _$TrendingHashtags {
  @override
  Future<List<TrendingHashtag>> build() async {
    // Get initial trending hashtags
    final service = ref.watch(analyticsApiServiceProvider);
    return await service.getTrendingHashtags();
  }

  /// Refresh trending hashtags
  Future<void> refresh() async {
    final service = ref.read(analyticsApiServiceProvider);
    final hashtags = await service.getTrendingHashtags(forceRefresh: true);
    state = AsyncValue.data(hashtags);
  }
}

/// Provider for top creators
@riverpod
class TopCreators extends _$TopCreators {
  @override
  Future<List<TopCreator>> build() async {
    // Get initial top creators
    final service = ref.watch(analyticsApiServiceProvider);
    return await service.getTopCreators();
  }

  /// Refresh top creators
  Future<void> refresh() async {
    final service = ref.read(analyticsApiServiceProvider);
    final creators = await service.getTopCreators(forceRefresh: true);
    state = AsyncValue.data(creators);
  }
}
