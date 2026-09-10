// ABOUTME: Riverpod provider for content curation with reactive updates
// ABOUTME: Manages only editor picks - trending/popular handled by infinite feeds

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/state/curation_state.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'curation_providers.g.dart';

/// Provider for FunnelcakeApiClient (typed client for Funnelcake REST API)
@riverpod
FunnelcakeApiClient funnelcakeApiClient(Ref ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final baseUrl = resolveApiBaseUrlFromRelays(
    configuredRelays: nostrService.configuredRelays,
    fallbackBaseUrl: environmentConfig.apiBaseUrl,
  );
  // Injecting the client makes the API client a non-owner, so the close that
  // its own dispose() would have done has to happen here instead.
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(httpClient.close);
  return FunnelcakeApiClient(
    baseUrl: baseUrl,
    httpClient: httpClient,
    appVersion: ref.watch(appVersionProvider),
  );
}

/// Single source of truth for Funnelcake REST API availability.
///
/// Uses capability detection - actually probes the API to verify it works.
/// Re-checks when environment or relay configuration changes.
///
/// All feed providers should watch this instead of checking
/// `client.isAvailable` directly.
@Riverpod(keepAlive: true)
class FunnelcakeAvailable extends _$FunnelcakeAvailable {
  @override
  Future<bool> build() async {
    final client = ref.watch(funnelcakeApiClientProvider);

    // Quick check: is the API configured at all?
    if (!client.isAvailable) {
      Log.debug(
        '🔌 Funnelcake: API not configured',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return false;
    }

    // Watch relay changes to re-probe when relays change
    final nostrService = ref.watch(nostrServiceProvider);
    // Access relayStatuses to establish dependency (triggers rebuild on change)
    final relayCount = nostrService.relayStatuses.length;

    // Fast path: our relay is always Funnelcake - skip the network probe
    final environmentConfig = ref.watch(currentEnvironmentProvider);
    final baseUrl = resolveApiBaseUrlFromRelays(
      configuredRelays: nostrService.configuredRelays,
      fallbackBaseUrl: environmentConfig.apiBaseUrl,
    );

    if (baseUrl.contains('divine.video')) {
      Log.debug(
        '🔌 Funnelcake: Known Divine relay - skipping probe '
        '(relays: $relayCount)',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return true;
    }

    // Fallback: probe unknown relays to check Funnelcake compatibility
    try {
      Log.debug(
        '🔌 Funnelcake: Probing API availability (relays: $relayCount)',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      // Use recent endpoint with limit=1 as lightweight probe
      // (trending endpoint may 500 on staging due to scoring query issues)
      // Use a short 3s timeout so the probe doesn't block startup
      await client
          .getRecentVideos(limit: 1)
          .timeout(const Duration(seconds: 3));
      Log.info(
        '✅ Funnelcake: API available',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return true;
    } catch (e) {
      Log.info(
        '❌ Funnelcake: API unavailable - $e',
        name: 'FunnelcakeAvailable',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Force re-check of Funnelcake availability
  void refresh() {
    ref.invalidateSelf();
  }
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

    return _initialCurationState();
  }

  /// Reads the caches [CurationRepository] populates in its constructor.
  ///
  /// Returned rather than assigned to `state`: the read is synchronous, so an
  /// assignment here is immediately overwritten by whatever `build` returns.
  CurationState _initialCurationState() {
    try {
      final service = ref.read(curationRepositoryProvider);

      Log.debug(
        'Curation: Initializing curation sets',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      final editorsPicks = service.getVideosForSetType(
        CurationSetType.editorsPicks,
      );

      Log.info(
        'Curation: Loaded ${editorsPicks.length} editor picks',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      return CurationState(editorsPicks: editorsPicks, isLoading: false);
    } catch (e) {
      Log.error(
        'Curation: Initialization error: $e',
        name: 'CurationProvider',
        category: LogCategory.system,
      );

      return CurationState(
        editorsPicks: const [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _refreshCurationSets() async {
    final service = ref.read(curationRepositoryProvider);

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
      final service = ref.read(curationRepositoryProvider);

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

/// Provider for analytics-based trending videos with cursor pagination
@riverpod
class AnalyticsTrending extends _$AnalyticsTrending {
  int? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  List<VideoEvent> build() {
    // Initialize empty list, will be populated on refresh
    _nextCursor = null;
    _hasMore = true;
    _isLoading = false;
    return [];
  }

  /// Refresh trending videos from analytics API
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;

    Log.info(
      'AnalyticsTrending: Refreshing trending videos from analytics API',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      final client = ref.read(funnelcakeApiClientProvider);
      final stats = await client.getTrendingVideos();
      final videos = stats.toVideoEvents();

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      // Reset pagination state
      _nextCursor = _getOldestTimestamp(videos);
      _hasMore = videos.length >= AppConstants.paginationBatchSize;

      // Update state with new trending videos
      state = videos;

      Log.info(
        'AnalyticsTrending: Loaded ${state.length} trending videos, hasMore: $_hasMore',
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
    } finally {
      _isLoading = false;
    }
  }

  /// Load more trending videos using cursor-based pagination
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) {
      Log.debug(
        'AnalyticsTrending: Skipping loadMore (isLoading: $_isLoading, hasMore: $_hasMore)',
        name: 'AnalyticsTrendingProvider',
        category: LogCategory.system,
      );
      return;
    }

    _isLoading = true;
    final currentCount = state.length;

    Log.info(
      'AnalyticsTrending: Loading more trending videos (current: $currentCount, cursor: $_nextCursor)',
      name: 'AnalyticsTrendingProvider',
      category: LogCategory.system,
    );

    try {
      final client = ref.read(funnelcakeApiClientProvider);

      // Use cursor-based pagination with 'before' parameter (limit default: 50)
      final stats = _nextCursor != null
          ? await client.getTrendingVideos(before: _nextCursor)
          : await client.getTrendingVideos();
      final videos = stats.toVideoEvents();

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      if (videos.isNotEmpty) {
        // Deduplicate and merge by addressable identity, so a republished
        // coordinate (same kind:pubkey:d-tag, fresh event id) is not appended
        // as a duplicate.
        final newVideos = dedupeByFeedKey(
          videos,
          alreadySeen: state.map((v) => v.feedDedupKey),
        );

        if (newVideos.isNotEmpty) {
          state = [...state, ...newVideos];
          _nextCursor = _getOldestTimestamp(videos);
          _hasMore = videos.length >= AppConstants.paginationBatchSize;

          Log.info(
            'AnalyticsTrending: Loaded ${newVideos.length} more videos (total: ${state.length})',
            name: 'AnalyticsTrendingProvider',
            category: LogCategory.system,
          );
        } else {
          _hasMore = false;
          Log.info(
            'AnalyticsTrending: All returned videos already in state, stopping pagination',
            name: 'AnalyticsTrendingProvider',
            category: LogCategory.system,
          );
        }
      } else {
        _hasMore = false;
        Log.info(
          'AnalyticsTrending: No more videos available',
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
    } finally {
      _isLoading = false;
    }
  }

  /// Get oldest timestamp from videos for cursor pagination
  int? _getOldestTimestamp(List<VideoEvent> videos) {
    if (videos.isEmpty) return null;
    return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
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
      final client = ref.read(funnelcakeApiClientProvider);
      // Popular uses the trending videos API
      final stats = await client.getTrendingVideos();
      final videos = stats.toVideoEvents();

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
    final repo = ref.watch(hashtagRepositoryProvider);
    return repo.getTrendingHashtags();
  }

  /// Refresh trending hashtags from REST API, bypassing the repository cache.
  Future<void> refresh() async {
    final repo = ref.read(hashtagRepositoryProvider);
    final hashtags = await repo.getTrendingHashtags(forceRefresh: true);
    state = AsyncData(hashtags);
  }
}
