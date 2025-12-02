// ABOUTME: Service for interacting with divine Analytics API endpoints
// ABOUTME: Handles trending videos, hashtags, creators, and metrics with viral scoring

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/hashtag_extractor.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

/// Analytics API response models
class TrendingVideo {
  final String eventId;
  final int views;
  final double completionRate;
  final int uniqueViewers;
  final double viralScore;
  final VideoEvent? localVideo;

  TrendingVideo({
    required this.eventId,
    required this.views,
    required this.completionRate,
    required this.uniqueViewers,
    required this.viralScore,
    this.localVideo,
  });

  factory TrendingVideo.fromJson(Map<String, dynamic> json) {
    return TrendingVideo(
      eventId: json['eventId'] ?? '',
      views: json['views'] ?? 0,
      completionRate: (json['completionRate'] ?? 0.0).toDouble(),
      uniqueViewers: json['uniqueViewers'] ?? 0,
      viralScore: (json['score'] ?? json['viralScore'] ?? 0.0).toDouble(),
    );
  }
}

class TrendingHashtag {
  final String tag;
  final int views;
  final int videoCount;
  final double avgViralScore;

  TrendingHashtag({
    required this.tag,
    required this.views,
    required this.videoCount,
    required this.avgViralScore,
  });

  factory TrendingHashtag.fromJson(Map<String, dynamic> json) {
    return TrendingHashtag(
      tag: json['tag'] ?? '',
      views: json['views'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      avgViralScore: (json['avgViralScore'] ?? 0.0).toDouble(),
    );
  }
}

class TopCreator {
  final String pubkey;
  final int totalViews;
  final int videoCount;
  final double avgViralScore;
  final String? name;
  final String? avatarUrl;

  TopCreator({
    required this.pubkey,
    required this.totalViews,
    required this.videoCount,
    required this.avgViralScore,
    this.name,
    this.avatarUrl,
  });

  factory TopCreator.fromJson(Map<String, dynamic> json) {
    return TopCreator(
      pubkey: json['pubkey'] ?? '',
      totalViews: json['totalViews'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      avgViralScore: (json['avgViralScore'] ?? 0.0).toDouble(),
      name: json['name'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

/// Service for analytics API interactions
class AnalyticsApiService {
  static const String baseUrl = 'https://api.openvine.co';
  static const Duration cacheTimeout = Duration(minutes: 5);

  final INostrService _nostrService;
  final VideoEventService _videoEventService;

  // Cache for trending data
  List<TrendingVideo> _trendingVideosCache = [];
  List<TrendingHashtag> _trendingHashtagsCache = [];
  List<TopCreator> _topCreatorsCache = [];
  DateTime? _lastTrendingVideosFetch;
  DateTime? _lastTrendingHashtagsFetch;
  DateTime? _lastTopCreatorsFetch;

  // Track missing videos to avoid repeated fetch attempts
  final Set<String> _missingVideoIds = {};

  AnalyticsApiService({
    required INostrService nostrService,
    required VideoEventService videoEventService,
  }) : _nostrService = nostrService,
       _videoEventService = videoEventService;

  /// Fetch trending videos with viral scoring
  Future<List<VideoEvent>> getTrendingVideos({
    String timeWindow = '7d', // Use 7 days for broader time window
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh &&
        _lastTrendingVideosFetch != null &&
        DateTime.now().difference(_lastTrendingVideosFetch!).inMinutes < 5 &&
        _trendingVideosCache.isNotEmpty) {
      Log.debug(
        '📊 Using cached trending videos (${_trendingVideosCache.length} items)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _trendingVideosCache
          .where((tv) => tv.localVideo != null)
          .map((tv) => tv.localVideo!)
          .toList();
    }

    try {
      Log.info(
        '📊 Fetching trending videos from API (window: $timeWindow, limit: $limit)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      Log.info(
        '📊 URL: $baseUrl/analytics/trending/vines?window=$timeWindow&limit=$limit',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/analytics/trending/vines?window=$timeWindow&limit=$limit',
            ),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Log.debug(
          '📊 Response data keys: ${data.keys}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        final videosData = data['vines'] as List<dynamic>? ?? [];

        Log.info(
          '📊 Received ${videosData.length} trending videos from API',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        if (videosData.isNotEmpty) {
          Log.debug(
            '📊 First video data: ${videosData.first}',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
        }

        // Parse trending videos
        _trendingVideosCache = videosData
            .map((v) => TrendingVideo.fromJson(v))
            .toList();

        // Find local videos and fetch missing ones
        await _populateLocalVideos();

        _lastTrendingVideosFetch = DateTime.now();

        // Return only videos we have locally
        final localVideos = _trendingVideosCache
            .where((tv) => tv.localVideo != null)
            .map((tv) => tv.localVideo!)
            .toList();

        Log.info(
          '✅ Returning ${localVideos.length} trending videos with local data',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return localVideos;
      } else {
        final url =
            '$baseUrl/analytics/trending/vines?window=$timeWindow&limit=$limit';
        Log.error(
          '❌ Failed to fetch trending videos: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   Request URL: $url',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      final url =
          '$baseUrl/analytics/trending/vines?window=$timeWindow&limit=$limit';
      Log.error(
        '❌ Error fetching trending videos: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      Log.error(
        '   Request URL: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Fetch trending hashtags
  Future<List<TrendingHashtag>> getTrendingHashtags({
    String timeWindow = '24h',
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh &&
        _lastTrendingHashtagsFetch != null &&
        DateTime.now().difference(_lastTrendingHashtagsFetch!).inMinutes < 5 &&
        _trendingHashtagsCache.isNotEmpty) {
      Log.debug(
        '📊 Using cached trending hashtags (${_trendingHashtagsCache.length} items)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _trendingHashtagsCache;
    }

    try {
      Log.info(
        '📊 Fetching trending hashtags from API (window: $timeWindow, limit: $limit)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/analytics/trending/hashtags?window=$timeWindow&limit=$limit',
            ),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hashtagsData = data['hashtags'] as List<dynamic>? ?? [];

        Log.info(
          '📊 Received ${hashtagsData.length} trending hashtags from API',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        _trendingHashtagsCache = hashtagsData
            .map((h) => TrendingHashtag.fromJson(h))
            .toList();

        _lastTrendingHashtagsFetch = DateTime.now();

        return _trendingHashtagsCache;
      } else {
        final url =
            '$baseUrl/analytics/trending/hashtags?window=$timeWindow&limit=$limit';
        Log.warning(
          '⚠️ Trending hashtags API unavailable (${response.statusCode}), using fallback defaults',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.debug(
          '   Request URL: $url',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        // Return default hashtags as fallback
        return _getDefaultTrendingHashtags(limit);
      }
    } catch (e) {
      final url =
          '$baseUrl/analytics/trending/hashtags?window=$timeWindow&limit=$limit';
      Log.warning(
        '⚠️ Error fetching trending hashtags: $e, using fallback defaults',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      Log.debug(
        '   Request URL: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      // Return default hashtags as fallback
      return _getDefaultTrendingHashtags(limit);
    }
  }

  /// Get default trending hashtags as fallback when API is unavailable
  List<TrendingHashtag> _getDefaultTrendingHashtags(int limit) {
    // Use suggested hashtags from HashtagExtractor
    final defaultTags = HashtagExtractor.suggestedHashtags.take(limit).toList();

    Log.info(
      '📊 Using ${defaultTags.length} default trending hashtags',
      name: 'AnalyticsApiService',
      category: LogCategory.video,
    );

    // Convert to TrendingHashtag objects with placeholder stats
    return defaultTags.asMap().entries.map((entry) {
      final index = entry.key;
      final tag = entry.value;

      // Generate decreasing stats to simulate trending order
      final views = 1000 - (index * 50);
      final videoCount = 50 - (index * 2);
      final avgViralScore = 0.8 - (index * 0.03);

      return TrendingHashtag(
        tag: tag,
        views: views,
        videoCount: videoCount,
        avgViralScore: avgViralScore.clamp(0.0, 1.0),
      );
    }).toList();
  }

  /// Fetch top creators
  Future<List<TopCreator>> getTopCreators({
    String timeWindow = '7d',
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh &&
        _lastTopCreatorsFetch != null &&
        DateTime.now().difference(_lastTopCreatorsFetch!).inMinutes < 5 &&
        _topCreatorsCache.isNotEmpty) {
      Log.debug(
        '📊 Using cached top creators (${_topCreatorsCache.length} items)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return _topCreatorsCache;
    }

    try {
      Log.info(
        '📊 Fetching top creators from API (window: $timeWindow, limit: $limit)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/analytics/trending/creators?window=$timeWindow&limit=$limit',
            ),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final creatorsData = data['creators'] as List<dynamic>? ?? [];

        Log.info(
          '📊 Received ${creatorsData.length} top creators from API',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        _topCreatorsCache = creatorsData
            .map((c) => TopCreator.fromJson(c))
            .toList();

        _lastTopCreatorsFetch = DateTime.now();

        return _topCreatorsCache;
      } else {
        final url =
            '$baseUrl/analytics/trending/creators?window=$timeWindow&limit=$limit';
        Log.error(
          '❌ Failed to fetch top creators: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   Request URL: $url',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      final url =
          '$baseUrl/analytics/trending/creators?window=$timeWindow&limit=$limit';
      Log.error(
        '❌ Error fetching top creators: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      Log.error(
        '   Request URL: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Get related videos for a specific video
  Future<List<VideoEvent>> getRelatedVideos({
    required String videoId,
    String algorithm = 'hashtag',
    int limit = 20,
  }) async {
    try {
      Log.info(
        '📊 Fetching related videos for $videoId (algorithm: $algorithm)',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/analytics/vines/$videoId/related?algorithm=$algorithm&limit=$limit',
            ),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videosData = data['vines'] as List<dynamic>? ?? [];

        Log.info(
          '📊 Received ${videosData.length} related videos from API',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        // Parse and fetch videos
        final relatedIds = videosData
            .map((v) => v['eventId'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();

        if (relatedIds.isEmpty) return [];

        // Find local videos and fetch missing ones
        final localVideos = await _fetchVideosByIds(relatedIds);

        Log.info(
          '✅ Returning ${localVideos.length} related videos with local data',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );

        return localVideos;
      } else {
        final url =
            '$baseUrl/analytics/vines/$videoId/related?algorithm=$algorithm&limit=$limit';
        Log.error(
          '❌ Failed to fetch related videos: ${response.statusCode}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   Request URL: $url',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        return [];
      }
    } catch (e) {
      final url =
          '$baseUrl/analytics/vines/$videoId/related?algorithm=$algorithm&limit=$limit';
      Log.error(
        '❌ Error fetching related videos: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      Log.error(
        '   Request URL: $url',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Populate local videos for trending cache
  Future<void> _populateLocalVideos() async {
    final allVideos = _videoEventService.discoveryVideos;
    final missingIds = <String>[];

    // First pass: find local videos
    for (final trendingVideo in _trendingVideosCache) {
      if (_missingVideoIds.contains(trendingVideo.eventId)) {
        continue; // Skip known missing videos
      }

      final localVideo = allVideos.firstWhere(
        (v) => v.id == trendingVideo.eventId,
        orElse: () => VideoEvent(
          id: '',
          pubkey: '',
          createdAt: 0,
          content: '',
          timestamp: DateTime.now(),
        ),
      );

      if (localVideo.id.isNotEmpty) {
        // Update cache with local video
        final index = _trendingVideosCache.indexOf(trendingVideo);
        _trendingVideosCache[index] = TrendingVideo(
          eventId: trendingVideo.eventId,
          views: trendingVideo.views,
          completionRate: trendingVideo.completionRate,
          uniqueViewers: trendingVideo.uniqueViewers,
          viralScore: trendingVideo.viralScore,
          localVideo: localVideo,
        );
      } else {
        missingIds.add(trendingVideo.eventId);
      }
    }

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty) {
      Log.info(
        '📡 Fetching ${missingIds.length} missing trending videos from relays',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final fetchedVideos = await _fetchVideosByIds(missingIds);

      // Update cache with fetched videos
      for (final video in fetchedVideos) {
        final trendingVideo = _trendingVideosCache.firstWhere(
          (tv) => tv.eventId == video.id,
          orElse: () => TrendingVideo(
            eventId: '',
            views: 0,
            completionRate: 0,
            uniqueViewers: 0,
            viralScore: 0,
          ),
        );

        if (trendingVideo.eventId.isNotEmpty) {
          final index = _trendingVideosCache.indexOf(trendingVideo);
          _trendingVideosCache[index] = TrendingVideo(
            eventId: trendingVideo.eventId,
            views: trendingVideo.views,
            completionRate: trendingVideo.completionRate,
            uniqueViewers: trendingVideo.uniqueViewers,
            viralScore: trendingVideo.viralScore,
            localVideo: video,
          );
        }
      }

      // Mark permanently missing videos
      final fetchedIds = fetchedVideos.map((v) => v.id).toSet();
      final actuallyMissing = missingIds.where(
        (id) => !fetchedIds.contains(id),
      );
      _missingVideoIds.addAll(actuallyMissing);

      if (actuallyMissing.isNotEmpty) {
        Log.warning(
          '🚫 Marked ${actuallyMissing.length} videos as permanently missing',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Fetch videos by IDs from relays
  Future<List<VideoEvent>> _fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    Log.info(
      '🔄 Attempting to fetch ${ids.length} videos from relays',
      name: 'AnalyticsApiService',
      category: LogCategory.video,
    );
    Log.info(
      '   First few IDs: ${ids.take(3).join(', ')}',
      name: 'AnalyticsApiService',
      category: LogCategory.video,
    );

    try {
      // Check relay connection status first
      final connectedRelays = _nostrService.connectedRelays;
      Log.info(
        '📡 Connected relays: $connectedRelays',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final defaultRelay = AppConstants.defaultRelayUrl;
      if (!connectedRelays.contains(defaultRelay)) {
        Log.warning(
          '⚠️ Not connected to $defaultRelay - attempting to add',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        await _nostrService.addRelay(defaultRelay);
      }

      final filter = Filter(ids: ids);
      Log.info(
        '📤 Creating subscription for event IDs',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);

      final fetchedVideos = <VideoEvent>[];
      final completer = Completer<void>();
      late StreamSubscription<Event> subscription;

      subscription = eventStream.listen(
        (event) {
          try {
            final video = VideoEvent.fromNostrEvent(event);
            fetchedVideos.add(video);
            _videoEventService.addVideoEvent(video); // Cache it

            Log.info(
              '📹 Fetched video from relay: ${video.title ?? video.id}',
              name: 'AnalyticsApiService',
              category: LogCategory.video,
            );
            Log.info(
              '   Event ID: ${video.id}',
              name: 'AnalyticsApiService',
              category: LogCategory.video,
            );
            Log.info(
              '   Thumbnail URL: ${video.thumbnailUrl}',
              name: 'AnalyticsApiService',
              category: LogCategory.video,
            );
            Log.info(
              '   Blurhash: ${video.blurhash}',
              name: 'AnalyticsApiService',
              category: LogCategory.video,
            );

            if (fetchedVideos.length >= ids.length ||
                fetchedVideos.length >= 10) {
              subscription.cancel();
              if (!completer.isCompleted) completer.complete();
            }
          } catch (e) {
            Log.error(
              'Failed to parse video event: $e',
              name: 'AnalyticsApiService',
              category: LogCategory.video,
            );
          }
        },
        onError: (error) {
          Log.error(
            'Stream error fetching videos: $error',
            name: 'AnalyticsApiService',
            category: LogCategory.video,
          );
          subscription.cancel();
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          subscription.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for completion or timeout (increase timeout for relay sync)
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 10)), // Increased timeout
      ]);

      await subscription.cancel();

      Log.info(
        '✅ Fetched ${fetchedVideos.length}/${ids.length} videos from relays',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );

      if (fetchedVideos.isEmpty && ids.isNotEmpty) {
        Log.error(
          '❌ CRITICAL: No videos fetched despite having ${ids.length} IDs to fetch',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
        Log.error(
          '   This suggests the embedded relay is not syncing with external relays',
          name: 'AnalyticsApiService',
          category: LogCategory.video,
        );
      }

      return fetchedVideos;
    } catch (e) {
      Log.error(
        'Failed to fetch videos from relays: $e',
        name: 'AnalyticsApiService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Clear all caches
  void clearCache() {
    _trendingVideosCache.clear();
    _trendingHashtagsCache.clear();
    _topCreatorsCache.clear();
    _lastTrendingVideosFetch = null;
    _lastTrendingHashtagsFetch = null;
    _lastTopCreatorsFetch = null;
    _missingVideoIds.clear();

    Log.info(
      '🧹 Cleared all analytics cache',
      name: 'AnalyticsApiService',
      category: LogCategory.system,
    );
  }
}
