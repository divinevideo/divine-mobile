// ABOUTME: Service for infinite scroll video feeds (trending, popular now)
// ABOUTME: Handles continuous loading of new videos as users scroll through feeds

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/feed_type.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for infinite scroll video feeds
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class InfiniteFeedService {
  InfiniteFeedService({
    required INostrService nostrService,
    required VideoEventService videoEventService,
    http.Client? httpClient,
  }) : _nostrService = nostrService,
       _videoEventService = videoEventService,
       _httpClient = httpClient ?? http.Client();

  final INostrService _nostrService;
  final VideoEventService _videoEventService;
  final http.Client _httpClient;

  // Store feeds by type
  final Map<FeedType, List<VideoEvent>> _feeds = {};
  final Map<FeedType, bool> _isLoading = {};
  final Map<FeedType, bool> _hasMore = {};
  final Map<FeedType, int> _currentPage = {};
  final Map<FeedType, Set<String>> _seenVideoIds = {};

  static const int _pageSize = 20;
  static const String _analyticsEndpoint = 'https://api.openvine.co';

  /// Get videos for a specific feed type
  List<VideoEvent> getVideosForFeed(FeedType feedType) =>
      _feeds[feedType] ?? [];

  /// Check if a feed is currently loading
  bool isLoadingFeed(FeedType feedType) => _isLoading[feedType] ?? false;

  /// Check if a feed has more content to load
  bool hasMoreContent(FeedType feedType) => _hasMore[feedType] ?? true;

  /// Initialize a feed
  Future<void> initializeFeed(FeedType feedType) async {
    if (_feeds[feedType] != null) return; // Already initialized

    _feeds[feedType] = [];
    _isLoading[feedType] = false;
    _hasMore[feedType] = true;
    _currentPage[feedType] = 0;
    _seenVideoIds[feedType] = {};

    // Load initial content
    await loadMoreContent(feedType);
  }

  /// Load more content for a feed
  Future<void> loadMoreContent(FeedType feedType) async {
    if (_isLoading[feedType] == true || _hasMore[feedType] == false) {
      return;
    }

    _isLoading[feedType] = true;

    try {
      List<VideoEvent> newVideos = [];

      switch (feedType) {
        case FeedType.trending:
          newVideos = await _loadTrendingVideos();
          break;
        case FeedType.popularNow:
          newVideos = await _loadPopularNowVideos();
          break;
        case FeedType.recent:
          newVideos = await _loadRecentVideos();
          break;
      }

      // Filter out videos we've already seen
      final seenIds = _seenVideoIds[feedType]!;
      final uniqueNewVideos = newVideos
          .where((video) => !seenIds.contains(video.id))
          .toList();

      if (uniqueNewVideos.isEmpty) {
        // If we got no new unique videos, try to get more from Nostr
        final fallbackVideos = await _loadFallbackVideos(feedType);
        final uniqueFallback = fallbackVideos
            .where((video) => !seenIds.contains(video.id))
            .toList();
        uniqueNewVideos.addAll(
          uniqueFallback.take(10),
        ); // Add up to 10 fallback videos
      }

      // Add new videos to the feed
      if (uniqueNewVideos.isNotEmpty) {
        _feeds[feedType]!.addAll(uniqueNewVideos);
        for (final video in uniqueNewVideos) {
          seenIds.add(video.id);
        }
        _currentPage[feedType] = (_currentPage[feedType] ?? 0) + 1;
      }

      // Check if we should continue loading (if we got less than expected, we might be at the end)
      if (uniqueNewVideos.length < _pageSize ~/ 2) {
        _hasMore[feedType] = false;
      }

      Log.info(
        'Loaded ${uniqueNewVideos.length} new videos for ${feedType.displayName}',
        name: 'InfiniteFeedService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error loading content for ${feedType.displayName}: $e',
        name: 'InfiniteFeedService',
        category: LogCategory.system,
      );
    } finally {
      _isLoading[feedType] = false;
    }
  }

  /// Load trending videos from analytics API
  Future<List<VideoEvent>> _loadTrendingVideos() async {
    try {
      final page = _currentPage[FeedType.trending] ?? 0;
      final offset = page * _pageSize;

      final response = await _httpClient
          .get(
            Uri.parse(
              '$_analyticsEndpoint/analytics/trending?limit=$_pageSize&offset=$offset',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final vinesData = data['vines'] as List<dynamic>? ?? [];

        final trendingVideos = <VideoEvent>[];
        final missingEventIds = <String>[];

        for (final vineData in vinesData) {
          final eventId = vineData['eventId'] as String?;
          if (eventId != null) {
            // Try to find the video in our local cache first
            final localVideo = _videoEventService.discoveryVideos.firstWhere(
              (video) => video.id == eventId,
              orElse: () => VideoEvent(
                id: '',
                pubkey: '',
                createdAt: 0,
                content: '',
                timestamp: DateTime.now(),
              ),
            );

            if (localVideo.id.isNotEmpty) {
              trendingVideos.add(localVideo);
            } else {
              missingEventIds.add(eventId);
            }
          }
        }

        // Fetch missing videos from Nostr relays
        if (missingEventIds.isNotEmpty && missingEventIds.length <= 10) {
          final fetchedVideos = await _fetchVideosFromNostr(missingEventIds);
          trendingVideos.addAll(fetchedVideos);
        }

        return trendingVideos;
      }
    } catch (e) {
      Log.warning(
        'Failed to load trending from API: $e',
        name: 'InfiniteFeedService',
        category: LogCategory.system,
      );
    }

    // Fallback to local videos if API fails
    return _loadFallbackVideos(FeedType.trending);
  }

  /// Load popular now videos (similar to trending but with different sorting)
  Future<List<VideoEvent>> _loadPopularNowVideos() async {
    // For now, use recent videos sorted by a popularity metric
    // In the future, this could use a different API endpoint
    return _loadFallbackVideos(FeedType.popularNow);
  }

  /// Load recent videos from Nostr
  Future<List<VideoEvent>> _loadRecentVideos() async {
    return _loadFallbackVideos(FeedType.recent);
  }

  /// Load fallback videos from local cache and Nostr
  Future<List<VideoEvent>> _loadFallbackVideos(FeedType feedType) async {
    final allVideos = List<VideoEvent>.from(_videoEventService.discoveryVideos);
    final seenIds = _seenVideoIds[feedType] ?? {};

    // Filter out already seen videos
    final unseenVideos = allVideos
        .where((video) => !seenIds.contains(video.id))
        .toList();

    // Sort based on feed type
    switch (feedType) {
      case FeedType.trending:
      case FeedType.popularNow:
        // Popular/Trending: prioritize by loops (new vines without loops first, then by loop count desc, then newest)
        unseenVideos.sort(VideoEvent.compareByLoopsThenTime);
        break;
      case FeedType.recent:
        unseenVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    // If we don't have enough local videos, try to fetch more from Nostr
    if (unseenVideos.length < _pageSize) {
      final moreVideos = await _fetchMoreFromNostr(feedType);
      final uniqueMore = moreVideos
          .where((video) => !seenIds.contains(video.id))
          .toList();
      unseenVideos.addAll(uniqueMore);
    }

    return unseenVideos.take(_pageSize).toList();
  }

  /// Fetch specific videos from Nostr by IDs
  Future<List<VideoEvent>> _fetchVideosFromNostr(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];

    try {
      final filter = Filter(ids: eventIds);
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);

      final fetchedVideos = <VideoEvent>[];
      await for (final event in eventStream.timeout(
        const Duration(seconds: 30),
      )) {
        try {
          final video = VideoEvent.fromNostrEvent(event);
          fetchedVideos.add(video);
          // Also add to video event service cache
          _videoEventService.addVideoEvent(video);
        } catch (e) {
          Log.warning(
            'Failed to parse video event: $e',
            name: 'InfiniteFeedService',
            category: LogCategory.system,
          );
        }
      }

      return fetchedVideos;
    } catch (e) {
      Log.warning(
        'Failed to fetch videos from Nostr: $e',
        name: 'InfiniteFeedService',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Fetch more videos from Nostr
  Future<List<VideoEvent>> _fetchMoreFromNostr(FeedType feedType) async {
    try {
      // Get older videos by using a timestamp before our oldest video
      final existingVideos = _feeds[feedType] ?? [];
      int? since;

      if (existingVideos.isNotEmpty) {
        final oldestVideo = existingVideos.last;
        since = oldestVideo.createdAt - 3600; // 1 hour before oldest video
      }

      final filter = Filter(
        kinds: [34236], // Kind 34236 addressable short video events
        limit: _pageSize,
        until: since,
      );

      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);

      final newVideos = <VideoEvent>[];
      await for (final event in eventStream.timeout(
        const Duration(seconds: 30),
      )) {
        try {
          final video = VideoEvent.fromNostrEvent(event);
          newVideos.add(video);
          // Also add to video event service cache
          _videoEventService.addVideoEvent(video);
        } catch (e) {
          Log.warning(
            'Failed to parse video event: $e',
            name: 'InfiniteFeedService',
            category: LogCategory.system,
          );
        }
      }

      return newVideos;
    } catch (e) {
      Log.warning(
        'Failed to fetch more videos from Nostr: $e',
        name: 'InfiniteFeedService',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Refresh a feed (fetch new videos and prepend to existing)
  Future<void> refreshFeed(FeedType feedType) async {
    if (_isLoading[feedType] == true) return;

    _isLoading[feedType] = true;

    try {
      // Temporarily reset page to 0 to get latest videos
      final savedPage = _currentPage[feedType] ?? 0;
      _currentPage[feedType] = 0;

      List<VideoEvent> newVideos = [];

      switch (feedType) {
        case FeedType.trending:
          newVideos = await _loadTrendingVideos();
          break;
        case FeedType.popularNow:
          newVideos = await _loadPopularNowVideos();
          break;
        case FeedType.recent:
          newVideos = await _loadRecentVideos();
          break;
      }

      // Restore the page counter
      _currentPage[feedType] = savedPage;

      // Filter out videos we've already seen
      final seenIds = _seenVideoIds[feedType] ?? <String>{};
      final uniqueNewVideos = newVideos
          .where((video) => !seenIds.contains(video.id))
          .toList();

      if (uniqueNewVideos.isNotEmpty) {
        // Prepend new videos to the beginning of the feed
        final existingVideos = _feeds[feedType] ?? [];
        _feeds[feedType] = [...uniqueNewVideos, ...existingVideos];

        // Mark new videos as seen
        for (final video in uniqueNewVideos) {
          seenIds.add(video.id);
        }

        Log.info(
          'Refreshed feed with ${uniqueNewVideos.length} new videos for ${feedType.displayName}',
          name: 'InfiniteFeedService',
          category: LogCategory.system,
        );
      } else {
        Log.info(
          'No new videos found during refresh for ${feedType.displayName}',
          name: 'InfiniteFeedService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Error refreshing feed for ${feedType.displayName}: $e',
        name: 'InfiniteFeedService',
        category: LogCategory.system,
      );
    } finally {
      _isLoading[feedType] = false;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
