// ABOUTME: Repository for video categories from the Funnelcake REST API.
// ABOUTME: Owns category metadata and first-page video snapshot caches.

import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:categories_repository/src/discovery_category_policy.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

/// Returns `true` when content from [pubkey] should be hidden.
typedef CategoryVideoBlockFilter = bool Function(String pubkey);

/// A page of category videos plus pagination metadata.
final class CategoryVideosPage {
  /// Creates a [CategoryVideosPage].
  const CategoryVideosPage({required this.videos, required this.hasMore});

  /// The filtered videos for this page.
  final List<VideoEvent> videos;

  /// Whether the API returned a full page and may have more results.
  final bool hasMore;
}

/// Repository for fetching and caching video categories.
///
/// Wraps [FunnelcakeApiClient.getCategories] and applies
/// featured-first ordering. Results are cached in memory for
/// 10 minutes so repeated screen opens do not fire redundant
/// network requests, and can be observed through [watchCategoriesCached]
/// for disk-backed stale-while-revalidate loading across app starts.
class CategoriesRepository {
  /// Creates a [CategoriesRepository].
  CategoriesRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    CategoryVideoBlockFilter? blockFilter,
    Duration cacheDuration = const Duration(minutes: 10),
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _blockFilter = blockFilter,
       _cacheDuration = cacheDuration;

  final FunnelcakeApiClient _funnelcakeApiClient;
  final CategoryVideoBlockFilter? _blockFilter;
  final Duration _cacheDuration;

  List<VideoCategory>? _cache;
  DateTime? _cachedAt;

  static const _categoriesCacheKey = 'global:categories:v1';

  /// The oldest category video snapshot that may still be shown.
  static const _videoSnapshotMaxAge = Duration(hours: 24);

  bool get _isCacheValid =>
      _cache != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheDuration;

  /// Returns the ordered list of categories.
  ///
  /// Returns the in-memory cached result when available and not expired.
  /// When [forceRefresh] is `true` the cache is bypassed and a fresh request
  /// is made. On success the cache is updated.
  ///
  /// Throws:
  /// - [FunnelcakeNotConfiguredException] if the API is not configured.
  /// - [FunnelcakeApiException] on server error.
  /// - [FunnelcakeTimeoutException] on timeout.
  /// - [FunnelcakeException] for other errors.
  Future<List<VideoCategory>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) {
      return _cache!;
    }

    final categories = (await _funnelcakeApiClient.getCategories(
      limit: 100,
    )).where(_isBrowsableCategory).toList();

    final indexedCategories = categories.indexed.toList()
      ..sort((left, right) {
        final featuredComparison = left.$2.featuredRank.compareTo(
          right.$2.featuredRank,
        );
        if (featuredComparison != 0) {
          return featuredComparison;
        }
        return left.$1.compareTo(right.$1);
      });

    final ordered = indexedCategories.map((entry) => entry.$2).toList();

    _cache = ordered;
    _cachedAt = DateTime.now();

    return ordered;
  }

  /// Watches the ordered category list through [CacheSync].
  ///
  /// Emits cached categories immediately when available, then emits the live
  /// Funnelcake result once it resolves. The cache intentionally has no TTL:
  /// categories are safe to show stale while the background refresh catches up.
  Stream<CacheResult<List<VideoCategory>>> watchCategoriesCached({
    bool forceRefresh = false,
  }) {
    return CacheSync.watchOne<List<VideoCategory>>(
      key: _categoriesCacheKey,
      fetch: () => getCategories(forceRefresh: forceRefresh),
      fromJson: _categoriesFromJson,
      toJson: _categoriesToJson,
      policy: forceRefresh
          ? CacheFetchPolicy.networkOnly
          : CacheFetchPolicy.cacheAndNetwork,
    );
  }

  /// Watches the first page of a public category feed, then refreshes it.
  ///
  /// Snapshots are scoped to [viewerPubkey], canonical category, API sort and
  /// platform. [viewerPubkey] is the signed-in viewer's hex pubkey, the prefix
  /// sign-out clears; null uses a shared anonymous scope that nothing clears.
  /// They can be served across gallery/app restarts for 24 hours and share
  /// CacheSync's global size limit and oldest-entry eviction. Every opening
  /// still fetches live data. Personalized recommendations deliberately use
  /// [getRecommendedVideos] instead of this cache.
  ///
  /// The current block filter and NIP-40 expiry run again on every cached and
  /// live emission. [CategoryVideosPage.hasMore] reflects the unfiltered API
  /// page size.
  ///
  /// A failed live fetch arrives as a stream error after any snapshot, so a
  /// caller can keep the snapshot on screen. The error is whatever the live
  /// request threw, usually a [FunnelcakeException].
  Stream<CacheResult<CategoryVideosPage>> watchVideosForCategoryCached({
    required String category,
    required String? viewerPubkey,
    String sort = 'trending',
    String? platform,
  }) {
    final canonicalCategory = category.trim().toLowerCase();
    if (DiscoveryCategoryPolicy.isDenied(canonicalCategory)) {
      return Stream.value(
        const CacheResult.live(CategoryVideosPage(videos: [], hasMore: false)),
      );
    }

    final key =
        '${viewerPubkey ?? 'anonymous'}:category-videos:v1:'
        '${jsonEncode([canonicalCategory, sort, platform])}';
    return CacheSync.watchOne<CategoryVideosPage>(
      key: key,
      fetch: () => getVideosForCategory(
        category: canonicalCategory,
        sort: sort,
        platform: platform,
      ),
      fromJson: _videosPageFromJson,
      toJson: _videosPageToJson,
    ).map((result) {
      // A snapshot can outlive a video's NIP-40 expiration.
      final unexpired = result.data.videos
          .where((video) => !video.isExpired)
          .toList();
      final page = CategoryVideosPage(
        videos: _filterVideos(unexpired),
        hasMore: result.data.hasMore,
      );
      return result.isLive ? CacheResult.live(page) : CacheResult.cached(page);
    });
  }

  static CategoryVideosPage _videosPageFromJson(String payload) {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(decoded['cachedAt'] as String);
    final age = DateTime.now().difference(cachedAt);
    // A negative age means the device clock moved back since the write, so
    // the snapshot's real age is unknown.
    if (age.isNegative || age > _videoSnapshotMaxAge) {
      // CacheSync removes rejected snapshots and continues with the live fetch.
      throw const FormatException('Category video snapshot expired');
    }
    return CategoryVideosPage(
      videos: (decoded['videos'] as List<dynamic>)
          .map((video) => VideoEvent.fromJson(video as Map<String, dynamic>))
          .toList(growable: false),
      hasMore: decoded['hasMore'] as bool,
    );
  }

  static String _videosPageToJson(CategoryVideosPage page) => jsonEncode({
    'cachedAt': DateTime.now().toUtc().toIso8601String(),
    'videos': page.videos
        .map((video) => video.toJson())
        .toList(growable: false),
    'hasMore': page.hasMore,
  });

  /// Returns a filtered page of videos for [category].
  ///
  /// Denied discovery categories return an empty terminal page without
  /// touching Funnelcake.
  Future<CategoryVideosPage> getVideosForCategory({
    required String category,
    int? before,
    String sort = 'trending',
    String? platform,
  }) async {
    if (DiscoveryCategoryPolicy.isDenied(category)) {
      return const CategoryVideosPage(videos: [], hasMore: false);
    }

    final videoStats = await _funnelcakeApiClient.getVideosByCategory(
      category: category,
      before: before,
      sort: sort,
      platform: platform,
    );

    return CategoryVideosPage(
      videos: _filterVideos(videoStats.toVideoEvents()),
      hasMore: videoStats.length >= 50,
    );
  }

  /// Returns filtered personalized recommendations for [pubkey].
  ///
  /// Recommendation responses can carry the same addressable video more than
  /// once in a single page: the server's emitted-id cursor dedupes by event
  /// id, so a republished coordinate (same kind:pubkey:d-tag, fresh event id)
  /// slips through. Dedupe by [VideoEvent.feedDedupKey] here so the category
  /// gallery never shows the same video twice.
  Future<List<VideoEvent>> getRecommendedVideos({
    required String pubkey,
    String? category,
    int limit = 50,
  }) async {
    if (category != null && DiscoveryCategoryPolicy.isDenied(category)) {
      return const [];
    }

    final response = await _funnelcakeApiClient.getRecommendations(
      pubkey: pubkey,
      category: category,
      limit: limit,
    );
    return _dedupeByFeedKey(_filterVideos(response.videos.toVideoEvents()));
  }

  List<VideoEvent> _filterVideos(List<VideoEvent> videos) {
    final blockFilter = _blockFilter;
    if (blockFilter == null) return videos;
    return videos.where((video) => !blockFilter(video.pubkey)).toList();
  }

  bool _isBrowsableCategory(VideoCategory category) {
    return category.name.isNotEmpty &&
        category.videoCount > 0 &&
        !DiscoveryCategoryPolicy.isDenied(category.name);
  }

  /// Removes videos whose [VideoEvent.feedDedupKey] has already been seen,
  /// preserving first-occurrence order.
  List<VideoEvent> _dedupeByFeedKey(List<VideoEvent> videos) {
    final seen = <String>{};
    return videos
        .where((video) => seen.add(video.feedDedupKey))
        .toList(growable: false);
  }

  /// Clears the in-memory cache so the next call fetches fresh data.
  void invalidateCache() {
    _cache = null;
    _cachedAt = null;
  }

  static List<VideoCategory> _categoriesFromJson(String payload) {
    final decoded = jsonDecode(payload) as List<dynamic>;
    return decoded
        .map((item) => VideoCategory.fromJson(item as Map<String, dynamic>))
        .where((category) => !DiscoveryCategoryPolicy.isDenied(category.name))
        .toList(growable: false);
  }

  static String _categoriesToJson(List<VideoCategory> categories) {
    return jsonEncode(
      categories
          .map(
            (category) => {
              'name': category.name,
              'video_count': category.videoCount,
            },
          )
          .toList(growable: false),
    );
  }
}
