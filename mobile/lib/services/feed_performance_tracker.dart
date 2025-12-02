// ABOUTME: Feed performance and user engagement analytics
// ABOUTME: Tracks video feed load times, scroll behavior, and video discovery metrics

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for tracking feed performance and user engagement
class FeedPerformanceTracker {
  static final FeedPerformanceTracker _instance =
      FeedPerformanceTracker._internal();
  factory FeedPerformanceTracker() => _instance;
  FeedPerformanceTracker._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, _FeedLoadSession> _activeSessions = {};

  /// Start tracking feed load
  void startFeedLoad(String feedType, {Map<String, dynamic>? params}) {
    final session = _FeedLoadSession(
      feedType: feedType,
      startTime: DateTime.now(),
      params: params ?? {},
    );

    _activeSessions[feedType] = session;

    UnifiedLogger.info(
      '📺 Feed load started: $feedType',
      name: 'FeedPerformance',
    );
  }

  /// Mark when first videos arrive from Nostr
  void markFirstVideosReceived(String feedType, int count) {
    final session = _activeSessions[feedType];
    if (session == null) return;

    session.firstVideosReceivedTime = DateTime.now();
    session.firstBatchCount = count;

    final timeToFirstVideos = session.firstVideosReceivedTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '📬 First $count videos received for $feedType in ${timeToFirstVideos}ms',
      name: 'FeedPerformance',
    );

    _analytics.logEvent(
      name: 'feed_first_batch_received',
      parameters: {
        'feed_type': feedType,
        'time_to_first_ms': timeToFirstVideos,
        'video_count': count,
        ...session.params,
      },
    );
  }

  /// Mark when feed is fully loaded and displayed
  void markFeedDisplayed(String feedType, int totalCount) {
    final session = _activeSessions[feedType];
    if (session == null) return;

    session.displayedTime = DateTime.now();
    session.totalVideosDisplayed = totalCount;

    final totalLoadTime = session.displayedTime!
        .difference(session.startTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '✅ Feed displayed: $feedType with $totalCount videos in ${totalLoadTime}ms',
      name: 'FeedPerformance',
    );

    _analytics.logEvent(
      name: 'feed_load_complete',
      parameters: {
        'feed_type': feedType,
        'total_load_time_ms': totalLoadTime,
        'total_videos': totalCount,
        'first_batch_count': session.firstBatchCount ?? 0,
        ...session.params,
      },
    );

    // Clean up session
    _activeSessions.remove(feedType);
  }

  /// Track feed refresh action
  void trackFeedRefresh(String feedType, {String? trigger}) {
    _analytics.logEvent(
      name: 'feed_refresh',
      parameters: {
        'feed_type': feedType,
        if (trigger != null) 'trigger': trigger,
      },
    );

    UnifiedLogger.info(
      '🔄 Feed refreshed: $feedType ${trigger != null ? "($trigger)" : ""}',
      name: 'FeedPerformance',
    );
  }

  /// Track pagination load more
  void trackLoadMore(
    String feedType, {
    required int currentCount,
    required int newCount,
    required int loadTimeMs,
  }) {
    _analytics.logEvent(
      name: 'feed_load_more',
      parameters: {
        'feed_type': feedType,
        'current_count': currentCount,
        'new_count': newCount,
        'load_time_ms': loadTimeMs,
      },
    );

    UnifiedLogger.info(
      '📄 Load more: $feedType loaded $newCount videos in ${loadTimeMs}ms (total: ${currentCount + newCount})',
      name: 'FeedPerformance',
    );
  }

  /// Track scroll depth in feed
  void trackScrollDepth(
    String feedType, {
    required int videosViewed,
    required int totalVideos,
    required double scrollPercentage,
  }) {
    _analytics.logEvent(
      name: 'feed_scroll_depth',
      parameters: {
        'feed_type': feedType,
        'videos_viewed': videosViewed,
        'total_videos': totalVideos,
        'scroll_percentage': scrollPercentage,
      },
    );
  }

  /// Track video engagement in feed
  void trackVideoEngagement(
    String feedType, {
    required String videoId,
    required String engagementType, // 'viewed', 'liked', 'shared', 'skipped'
    required int positionInFeed,
    int? watchDurationMs,
  }) {
    _analytics.logEvent(
      name: 'feed_video_engagement',
      parameters: {
        'feed_type': feedType,
        'engagement_type': engagementType,
        'position_in_feed': positionInFeed,
        'video_id': videoId,
        if (watchDurationMs != null) 'watch_duration_ms': watchDurationMs,
      },
    );
  }

  /// Track empty feed state
  void trackEmptyFeed(String feedType, {String? reason}) {
    _analytics.logEvent(
      name: 'feed_empty',
      parameters: {'feed_type': feedType, if (reason != null) 'reason': reason},
    );

    UnifiedLogger.warning(
      '📭 Empty feed: $feedType ${reason != null ? "- $reason" : ""}',
      name: 'FeedPerformance',
    );
  }

  /// Track feed error
  void trackFeedError(
    String feedType, {
    required String errorType,
    required String errorMessage,
  }) {
    _analytics.logEvent(
      name: 'feed_error',
      parameters: {
        'feed_type': feedType,
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
      },
    );

    UnifiedLogger.error(
      '❌ Feed error: $feedType - $errorType: $errorMessage',
      name: 'FeedPerformance',
    );
  }

  /// Track feed filtering/sorting
  void trackFeedFilter(
    String feedType, {
    required String filterType,
    required int resultCount,
  }) {
    _analytics.logEvent(
      name: 'feed_filter',
      parameters: {
        'feed_type': feedType,
        'filter_type': filterType,
        'result_count': resultCount,
      },
    );
  }

  /// Track video discovery source
  void trackVideoDiscovery({
    required String videoId,
    required String
    discoverySource, // 'home_feed', 'explore', 'hashtag', 'profile', 'search'
    int? positionInList,
  }) {
    _analytics.logEvent(
      name: 'video_discovered',
      parameters: {
        'video_id': videoId,
        'discovery_source': discoverySource,
        if (positionInList != null) 'position': positionInList,
      },
    );
  }
}

/// Internal session tracking for feed loading
class _FeedLoadSession {
  _FeedLoadSession({
    required this.feedType,
    required this.startTime,
    required this.params,
  });

  final String feedType;
  final DateTime startTime;
  final Map<String, dynamic> params;

  DateTime? firstVideosReceivedTime;
  DateTime? displayedTime;
  int? firstBatchCount;
  int? totalVideosDisplayed;
}
