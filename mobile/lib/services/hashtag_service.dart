// ABOUTME: Service for managing and tracking hashtags from video events
// ABOUTME: Provides hashtag statistics, trending data, and filtered video queries

import 'dart:async';
import 'package:models/models.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';

/// Model for hashtag statistics
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class HashtagStats {
  HashtagStats({
    required this.hashtag,
    required this.videoCount,
    required this.recentVideoCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.uniqueAuthors,
  });
  final String hashtag;
  final int videoCount;
  final int recentVideoCount; // Videos in last 24 hours
  final DateTime firstSeen;
  final DateTime lastSeen;
  final Set<String> uniqueAuthors;

  int get authorCount => uniqueAuthors.length;

  // Calculate trending score based on recency and engagement
  double get trendingScore {
    final recencyWeight = recentVideoCount / videoCount;
    final engagementWeight = authorCount / 100; // Normalize by 100 authors
    final hoursSinceLastSeen = DateTime.now().difference(lastSeen).inHours;
    final freshnessWeight = hoursSinceLastSeen < 24
        ? 1.0
        : 1.0 / (hoursSinceLastSeen / 24);

    return (recencyWeight * 0.5 +
            engagementWeight * 0.3 +
            freshnessWeight * 0.2) *
        100;
  }
}

/// Service for managing hashtag data and statistics
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class HashtagService {
  HashtagService(this._videoService, [this._cacheService]) {
    // REFACTORED: Service no longer extends ChangeNotifier - use Riverpod ref.watch instead
    _updateHashtagStats();

    // Update stats every minute
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateHashtagStats();
    });
  }
  final VideoEventService _videoService;
  final HashtagCacheService? _cacheService;
  final Map<String, HashtagStats> _hashtagStats = {};
  Timer? _updateTimer;

  void dispose() {
    _updateTimer?.cancel();
    // REFACTORED: Service no longer needs manual listener cleanup
  }

  /// Force refresh hashtag statistics
  void refreshHashtagStats() {
    _updateHashtagStats();
  }

  /// Update hashtag statistics from video events
  void _updateHashtagStats() {
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
    final newStats = <String, HashtagStats>{};

    // Combine videos from all sources to get complete hashtag statistics
    final allVideos = <VideoEvent>{
      ..._videoService.discoveryVideos,
      ..._videoService.homeFeedVideos,
      // Also include hashtag-specific videos if available
      if (_videoService.getEventCount(SubscriptionType.hashtag) > 0)
        ..._videoService.getVideos(SubscriptionType.hashtag),
    };

    for (final video in allVideos) {
      for (final hashtag in video.hashtags) {
        if (hashtag.isEmpty) continue;

        final existing = newStats[hashtag];
        final videoTime = DateTime.fromMillisecondsSinceEpoch(
          video.createdAt * 1000,
        );
        final isRecent = videoTime.isAfter(twentyFourHoursAgo);

        if (existing == null) {
          newStats[hashtag] = HashtagStats(
            hashtag: hashtag,
            videoCount: 1,
            recentVideoCount: isRecent ? 1 : 0,
            firstSeen: videoTime,
            lastSeen: videoTime,
            uniqueAuthors: {video.pubkey},
          );
        } else {
          newStats[hashtag] = HashtagStats(
            hashtag: hashtag,
            videoCount: existing.videoCount + 1,
            recentVideoCount: existing.recentVideoCount + (isRecent ? 1 : 0),
            firstSeen: videoTime.isBefore(existing.firstSeen)
                ? videoTime
                : existing.firstSeen,
            lastSeen: videoTime.isAfter(existing.lastSeen)
                ? videoTime
                : existing.lastSeen,
            uniqueAuthors: {...existing.uniqueAuthors, video.pubkey},
          );
        }
      }
    }

    _hashtagStats.clear();
    _hashtagStats.addAll(newStats);
  }

  /// Get all hashtags sorted by video count
  List<String> get allHashtags {
    final sorted = _hashtagStats.entries.toList()
      ..sort((a, b) => b.value.videoCount.compareTo(a.value.videoCount));
    return sorted.map((e) => e.key).toList();
  }

  /// Get trending hashtags based on trending score
  List<String> getTrendingHashtags({int limit = 25}) {
    final sorted = _hashtagStats.entries.toList()
      ..sort((a, b) => b.value.trendingScore.compareTo(a.value.trendingScore));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Get popular hashtags based on total video count
  List<String> getPopularHashtags({int limit = 25}) {
    // Try to get from cache first
    if (_cacheService != null && _cacheService.isInitialized) {
      final cachedHashtags = _cacheService.getCachedPopularHashtags();
      if (cachedHashtags != null && cachedHashtags.isNotEmpty) {
        return cachedHashtags.take(limit).toList();
      }
    }

    // Generate fresh list
    final sorted = _hashtagStats.entries.toList()
      ..sort((a, b) => b.value.videoCount.compareTo(a.value.videoCount));
    final hashtags = sorted.take(limit).map((e) => e.key).toList();

    // Cache the result asynchronously
    if (_cacheService != null &&
        _cacheService.isInitialized &&
        hashtags.isNotEmpty) {
      _cacheService.cachePopularHashtags(hashtags);
    }

    return hashtags;
  }

  /// Get statistics for a specific hashtag
  HashtagStats? getHashtagStats(String hashtag) {
    return _hashtagStats[hashtag];
  }

  /// Get editor's picks - curated selection of interesting hashtags
  List<String> getEditorsPicks({int limit = 25}) {
    // For now, return hashtags with good engagement (multiple authors)
    final sorted =
        _hashtagStats.entries
            .where(
              (e) => e.value.authorCount >= 3,
            ) // At least 3 different authors
            .toList()
          ..sort((a, b) => b.value.authorCount.compareTo(a.value.authorCount));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Get videos for specific hashtags
  List<VideoEvent> getVideosByHashtags(List<String> hashtags) =>
      _videoService.getVideoEventsByHashtags(hashtags);

  /// Subscribe to videos with specific hashtags
  Future<void> subscribeToHashtagVideos(
    List<String> hashtags, {
    int limit = 50,
    int? until,
  }) => _videoService.subscribeToVideoFeed(
    subscriptionType: SubscriptionType.hashtag,
    hashtags: hashtags,
    limit: limit,
    until: until,
    replace: false, // Don't replace - support multiple hashtag subscriptions
  );

  /// Search hashtags by prefix
  List<String> searchHashtags(String query) {
    if (query.isEmpty) return [];

    final lowercase = query.toLowerCase();
    return _hashtagStats.keys
        .where((tag) => tag.toLowerCase().contains(lowercase))
        .toList()
      ..sort((a, b) {
        // Prioritize exact matches and prefix matches
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();

        if (aLower == lowercase) return -1;
        if (bLower == lowercase) return 1;
        if (aLower.startsWith(lowercase) && !bLower.startsWith(lowercase)) {
          return -1;
        }
        if (!aLower.startsWith(lowercase) && bLower.startsWith(lowercase)) {
          return 1;
        }

        // Then sort by popularity
        return _hashtagStats[b]!.videoCount.compareTo(
          _hashtagStats[a]!.videoCount,
        );
      });
  }
}
