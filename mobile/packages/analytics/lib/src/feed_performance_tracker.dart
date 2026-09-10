// ABOUTME: Feed performance and user engagement analytics
// ABOUTME: Tracks video feed load times, scroll behavior, and video discovery metrics

import 'package:analytics/src/analytics_event_sink.dart';
import 'package:analytics/src/firebase_analytics_event_sink.dart';
import 'package:profile_repository/profile_repository.dart'
    show
        SearchSource,
        SearchSourceFailed,
        SearchSourcePending,
        SearchSourceSkipped,
        SearchSourceStatus,
        SearchSourceSuccess;
import 'package:unified_logger/unified_logger.dart';

/// Maximum age for a session before it is considered stale and discarded.
///
/// After the app is backgrounded and resumed, providers may re-fire and
/// attempt to complete sessions that were started hours ago. Any session
/// older than this threshold is silently discarded to avoid logging absurd
/// load times (e.g. 27+ hours).
const _maxSessionAge = Duration(seconds: 60);

/// Why a user-visible feed load began.
enum FeedLoadReason { appStart, sourceSwitch, refresh, pagination }

/// Service for tracking feed performance and user engagement
///
/// Feed-load sessions are keyed by feed type and shared across consumers — one
/// widget starts a load that another completes — so the app resolves one
/// instance through `feedPerformanceTrackerProvider` rather than constructing
/// this per widget.
class FeedPerformanceTracker {
  /// Creates a tracker. Defaults to the Firebase analytics sink in production;
  /// pass a [sink] (e.g. [NoOpAnalyticsEventSink]) in tests.
  FeedPerformanceTracker({AnalyticsEventSink? sink})
    : _analytics = sink ?? FirebaseAnalyticsEventSink();

  final AnalyticsEventSink _analytics;

  final Map<String, _FeedLoadSession> _activeSessions = {};

  /// Number of active tracking sessions (exposed for testing).
  int get activeSessionCount => _activeSessions.length;

  /// Clear all active sessions.
  ///
  /// Call this when the app resumes from background to prevent stale
  /// start times from producing wildly inaccurate load-time measurements.
  void resetAllSessions() {
    if (_activeSessions.isNotEmpty) {
      UnifiedLogger.info(
        'Resetting ${_activeSessions.length} stale feed '
        'performance sessions on app resume',
        name: 'FeedPerformance',
      );
      _activeSessions.clear();
    }
  }

  /// Start tracking feed load
  void startFeedLoad(
    String feedType, {
    FeedLoadReason reason = FeedLoadReason.appStart,
    Map<String, dynamic>? params,
  }) {
    final session = _startSession(
      feedType,
      {'load_reason': reason.name, ...?params},
    );

    _analytics.logEvent(
      name: 'feed_load_started',
      parameters: {'feed_type': feedType, ...session.params},
    );
  }

  _FeedLoadSession _startSession(
    String feedType,
    Map<String, dynamic> params,
  ) {
    final session = _FeedLoadSession(
      feedType: feedType,
      startTime: DateTime.now(),
      params: params,
    );
    _activeSessions[feedType] = session;
    UnifiedLogger.info(
      '📺 Feed load started: $feedType',
      name: 'FeedPerformance',
    );
    return session;
  }

  /// Records the first content a person can actually see.
  ///
  /// This does not close the session: a cache-first load remains active until
  /// [markFreshResultCompleted] records the later network result.
  void markFirstVisibleContent(
    String feedType,
    int count, {
    required bool servedFromCache,
  }) {
    final session = _activeSessions[feedType];
    if (session == null || session.firstVisibleTime != null) return;
    if (_isStale(session)) {
      _discardStaleSession(feedType);
      return;
    }

    session
      ..firstVisibleTime = DateTime.now()
      ..servedFromCache = servedFromCache;
    final elapsed = session.firstVisibleTime!
        .difference(session.startTime)
        .inMilliseconds;
    _analytics.logEvent(
      name: 'feed_first_content_visible',
      parameters: {
        'feed_type': feedType,
        'time_to_first_visible_ms': elapsed,
        'video_count': count,
        'served_from_cache': servedFromCache ? 1 : 0,
        ...session.params,
      },
    );
  }

  /// Records the fresh repository result and closes the user-visible load.
  void markFreshResultCompleted(
    String feedType,
    int totalCount, {
    int recommendationPageCount = 0,
    int followingPageCount = 0,
  }) {
    final session = _activeSessions[feedType];
    if (session == null) return;
    if (_isStale(session)) {
      _discardStaleSession(feedType);
      return;
    }

    final now = DateTime.now();
    final freshResultTimeMs = now.difference(session.startTime).inMilliseconds;
    final firstVisibleTimeMs = session.firstVisibleTime
        ?.difference(session.startTime)
        .inMilliseconds;
    final parameters = <String, Object>{
      'feed_type': feedType,
      'fresh_result_time_ms': freshResultTimeMs,
      'total_videos': totalCount,
      'served_from_cache': session.servedFromCache ? 1 : 0,
      'recommendation_page_count': recommendationPageCount,
      'following_page_count': followingPageCount,
      ...session.params,
    };
    if (firstVisibleTimeMs != null) {
      parameters['time_to_first_visible_ms'] = firstVisibleTimeMs;
    }
    _analytics.logEvent(
      name: 'feed_fresh_result_complete',
      parameters: parameters,
    );
    _analytics.logEvent(
      name: 'feed_load_complete',
      parameters: {
        'feed_type': feedType,
        'total_load_time_ms': freshResultTimeMs,
        'total_videos': totalCount,
        'first_batch_count': session.firstBatchCount ?? 0,
        ...session.params,
      },
    );
    _activeSessions.remove(feedType);
  }

  /// Mark when first videos arrive from Nostr
  void markFirstVideosReceived(String feedType, int count) {
    final session = _activeSessions[feedType];
    if (session == null) return;

    if (_isStale(session)) {
      _discardStaleSession(feedType);
      return;
    }

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

    if (_isStale(session)) {
      _discardStaleSession(feedType);
      return;
    }

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
      parameters: {'feed_type': feedType, 'trigger': ?trigger},
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
        'watch_duration_ms': ?watchDurationMs,
      },
    );
  }

  /// Track empty feed state
  void trackEmptyFeed(String feedType, {String? reason}) {
    _analytics.logEvent(
      name: 'feed_empty',
      parameters: {'feed_type': feedType, 'reason': ?reason},
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

  /// Start tracking time-to-play for a video swipe transition.
  ///
  /// Called when the user swipes to a new video. The session completes
  /// when [markVideoSwipeComplete] is called.
  void startVideoSwipeTracking(String videoId) {
    final feedType = 'video_swipe_$videoId';
    _startSession(feedType, const {});
  }

  /// Mark a video swipe as complete (video is now playing).
  ///
  /// Closes the session started by [startVideoSwipeTracking].
  void markVideoSwipeComplete(String videoId) {
    final feedType = 'video_swipe_$videoId';
    markFeedDisplayed(feedType, 1);
  }

  /// Track terminal outcome of one source in user-profile search.
  ///
  /// Called by `UserSearchBloc` once per source per query, when the
  /// source transitions from pending into a terminal state
  /// ([SearchSourceSuccess], [SearchSourceFailed], or
  /// [SearchSourceSkipped]). Pending statuses are intentionally not
  /// tracked — they would inflate the event count without adding signal.
  void trackSearchSource(SearchSource source, SearchSourceStatus status) {
    final parameters = <String, Object>{'source': source.name};
    switch (status) {
      case SearchSourcePending():
        return;
      case SearchSourceSkipped():
        parameters['status'] = 'skipped';
      case SearchSourceSuccess(:final resultCount, :final latencyMs):
        parameters['status'] = 'success';
        parameters['result_count'] = resultCount;
        parameters['latency_ms'] = latencyMs;
      case SearchSourceFailed(:final reason, :final latencyMs):
        parameters['status'] = 'failed';
        parameters['reason'] = reason.name;
        parameters['latency_ms'] = latencyMs;
    }
    _analytics.logEvent(name: 'user_search_source', parameters: parameters);
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
        'position': ?positionInList,
      },
    );
  }

  /// Whether a session's start time is older than [_maxSessionAge].
  bool _isStale(_FeedLoadSession session) {
    return DateTime.now().difference(session.startTime) > _maxSessionAge;
  }

  /// Remove a stale session and log a warning instead of recording garbage
  /// data.
  void _discardStaleSession(String feedType) {
    final session = _activeSessions.remove(feedType);
    if (session != null) {
      final age = DateTime.now().difference(session.startTime);
      UnifiedLogger.warning(
        'Discarding stale feed session "$feedType" '
        '(started ${age.inSeconds}s ago)',
        name: 'FeedPerformance',
      );
    }
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
  DateTime? firstVisibleTime;
  bool servedFromCache = false;
}
