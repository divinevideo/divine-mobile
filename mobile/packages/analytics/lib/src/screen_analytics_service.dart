// ABOUTME: Screen navigation and performance analytics service
// ABOUTME: Tracks screen load times, navigation patterns, and user engagement metrics

import 'dart:async';

import 'package:analytics/src/analytics_event_sink.dart';
import 'package:analytics/src/firebase_analytics_event_sink.dart';
import 'package:analytics/src/page_load_history.dart';
import 'package:unified_logger/unified_logger.dart';

/// Maximum age for a session before it is considered stale and discarded.
///
/// Mirrors [FeedPerformanceTracker]'s threshold. Sessions older than this
/// are silently dropped to avoid recording load times inflated by
/// background/resume cycles.
const _maxScreenSessionAge = Duration(seconds: 60);

/// Service for tracking screen navigation, performance, and user engagement
///
/// Sessions are keyed by screen name and shared across consumers — the
/// navigator observer starts a load that a screen later completes — so the app
/// resolves one instance through `screenAnalyticsServiceProvider` rather than
/// constructing this per widget.
class ScreenAnalyticsService {
  /// Creates a service writing timing records into [history].
  ///
  /// Defaults to the Firebase analytics sink in production; pass a [sink]
  /// (e.g. [NoOpAnalyticsEventSink]) in tests.
  ScreenAnalyticsService({
    required PageLoadHistory history,
    AnalyticsEventSink? sink,
  }) : _history = history,
       _sink = sink ?? FirebaseAnalyticsEventSink();

  final PageLoadHistory _history;
  final AnalyticsEventSink _sink;

  final Map<String, _ScreenSession> _activeSessions = {};

  String? _currentScreen;
  DateTime? _currentScreenStartTime;

  /// Number of active tracking sessions (exposed for testing).
  int get activeSessionCount => _activeSessions.length;

  /// Clear all active sessions.
  ///
  /// Call this when the app resumes from background to prevent stale
  /// start times from producing wildly inaccurate load-time measurements.
  void resetAllSessions() {
    if (_activeSessions.isNotEmpty) {
      UnifiedLogger.info(
        'Resetting ${_activeSessions.length} stale screen '
        'analytics sessions on app resume',
        name: 'ScreenAnalytics',
      );
      _activeSessions.clear();
    }
  }

  /// Start tracking a screen load
  void startScreenLoad(String screenName, {Map<String, dynamic>? params}) {
    final session = _ScreenSession(
      screenName: screenName,
      loadStartTime: DateTime.now(),
      params: params ?? {},
    );

    _activeSessions[screenName] = session;

    UnifiedLogger.info(
      '📱 Screen load started: $screenName',
      name: 'ScreenAnalytics',
    );
  }

  /// Mark when initial content is visible (screen rendered)
  void markContentVisible(String screenName) {
    final session = _activeSessions[screenName];
    if (session == null) return;

    if (_isStale(session)) {
      _discardStaleSession(screenName);
      return;
    }

    session.contentVisibleTime = DateTime.now();
    final loadTime = session.contentVisibleTime!
        .difference(session.loadStartTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '✅ Screen content visible: $screenName in ${loadTime}ms',
      name: 'ScreenAnalytics',
    );

    unawaited(
      _sink.logEvent(
        name: 'screen_load',
        parameters: _parameters({
          'screen_name': screenName,
          'load_time_ms': loadTime,
          ...session.params,
        }),
      ),
    );

    // Record to page load history
    _history.addOrUpdate(
      PageLoadRecord(
        screenName: screenName,
        timestamp: session.loadStartTime,
        contentVisibleMs: loadTime,
      ),
    );

    // PERF summary log
    final slowFlag = loadTime > 1000 ? ' [SLOW]' : '';
    UnifiedLogger.info(
      'PERF: $screenName — visible: ${loadTime}ms$slowFlag',
      name: 'PagePerf',
    );
  }

  /// Mark when screen data is fully loaded (async data fetched).
  ///
  /// Records once per session: callers mark from `build`, and every later
  /// rebuild would otherwise log another event measured from the same start.
  void markDataLoaded(String screenName, {Map<String, dynamic>? dataMetrics}) {
    final session = _activeSessions[screenName];
    if (session == null || session.dataLoadedTime != null) return;

    if (_isStale(session)) {
      _discardStaleSession(screenName);
      return;
    }

    session.dataLoadedTime = DateTime.now();
    final dataLoadTime = session.dataLoadedTime!
        .difference(session.loadStartTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '📊 Screen data loaded: $screenName in ${dataLoadTime}ms',
      name: 'ScreenAnalytics',
    );

    unawaited(
      _sink.logEvent(
        name: 'screen_data_loaded',
        parameters: _parameters({
          'screen_name': screenName,
          'data_load_time_ms': dataLoadTime,
          ...?dataMetrics,
          ...session.params,
        }),
      ),
    );

    // Record to page load history
    final contentVisibleMs = session.contentVisibleTime
        ?.difference(session.loadStartTime)
        .inMilliseconds;
    _history.addOrUpdate(
      PageLoadRecord(
        screenName: screenName,
        timestamp: session.loadStartTime,
        contentVisibleMs: contentVisibleMs,
        dataLoadedMs: dataLoadTime,
        dataMetrics: dataMetrics ?? {},
      ),
    );

    // PERF summary log
    final visibleStr = contentVisibleMs != null
        ? 'visible: ${contentVisibleMs}ms, '
        : '';
    final slowFlag = dataLoadTime > 3000 ? ' [SLOW]' : '';
    UnifiedLogger.info(
      'PERF: $screenName — ${visibleStr}data: ${dataLoadTime}ms$slowFlag',
      name: 'PagePerf',
    );
  }

  /// Track screen view and time spent
  void trackScreenView(String screenName, {Map<String, dynamic>? params}) {
    // End previous screen session if exists
    if (_currentScreen != null && _currentScreenStartTime != null) {
      final timeSpent = DateTime.now()
          .difference(_currentScreenStartTime!)
          .inSeconds;

      unawaited(
        _sink.logEvent(
          name: 'screen_time',
          parameters: _parameters({
            'screen_name': _currentScreen,
            'time_spent_seconds': timeSpent,
          }),
        ),
      );

      UnifiedLogger.info(
        '⏱️  User spent ${timeSpent}s on $_currentScreen',
        name: 'ScreenAnalytics',
      );
    }

    // Start new screen session
    _currentScreen = screenName;
    _currentScreenStartTime = DateTime.now();

    // Log screen view
    unawaited(
      _sink.logScreenView(
        screenName: screenName,
        parameters: _optionalParameters(params),
      ),
    );

    UnifiedLogger.info(
      '👁️  Screen viewed: $screenName',
      name: 'ScreenAnalytics',
    );
  }

  /// Track user interaction on screen
  void trackInteraction(
    String screenName,
    String interactionType, {
    Map<String, dynamic>? params,
  }) {
    unawaited(
      _sink.logEvent(
        name: 'user_interaction',
        parameters: _parameters({
          'screen_name': screenName,
          'interaction_type': interactionType,
          ...?params,
        }),
      ),
    );

    UnifiedLogger.debug(
      '👆 Interaction: $interactionType on $screenName',
      name: 'ScreenAnalytics',
    );
  }

  /// Track navigation between screens
  void trackNavigation({
    required String from,
    required String to,
    String? trigger,
  }) {
    unawaited(
      _sink.logEvent(
        name: 'screen_navigation',
        parameters: _parameters({
          'from_screen': from,
          'to_screen': to,
          'trigger': trigger,
        }),
      ),
    );

    UnifiedLogger.info(
      '🧭 Navigation: $from → $to ${trigger != null ? "($trigger)" : ""}',
      name: 'ScreenAnalytics',
    );
  }

  /// Track scroll behavior
  void trackScroll(
    String screenName, {
    required double scrollDepth,
    required int itemsViewed,
    int? totalItems,
  }) {
    unawaited(
      _sink.logEvent(
        name: 'screen_scroll',
        parameters: _parameters({
          'screen_name': screenName,
          'scroll_depth': scrollDepth,
          'items_viewed': itemsViewed,
          'total_items': totalItems,
        }),
      ),
    );
  }

  /// Track search usage
  void trackSearch({
    required String screenName,
    required String query,
    required int resultsCount,
    required int loadTimeMs,
  }) {
    unawaited(
      _sink.logEvent(
        name: 'search_performed',
        parameters: _parameters({
          'screen_name': screenName,
          'query_length': query.length,
          'results_count': resultsCount,
          'load_time_ms': loadTimeMs,
        }),
      ),
    );

    UnifiedLogger.info(
      '🔍 Search performed: ${query.length} chars, $resultsCount results in ${loadTimeMs}ms',
      name: 'ScreenAnalytics',
    );
  }

  /// Track tab changes
  void trackTabChange({required String screenName, required String tabName}) {
    unawaited(
      _sink.logEvent(
        name: 'tab_changed',
        parameters: _parameters({
          'screen_name': screenName,
          'tab_name': tabName,
        }),
      ),
    );
  }

  /// Track error on screen
  void trackScreenError({
    required String screenName,
    required String errorType,
    required String errorMessage,
    Map<String, dynamic>? context,
  }) {
    unawaited(
      _sink.logEvent(
        name: 'screen_error',
        parameters: _parameters({
          'screen_name': screenName,
          'error_type': errorType,
          'error_message': errorMessage.substring(
            0,
            errorMessage.length > 100 ? 100 : errorMessage.length,
          ),
          ...?context,
        }),
      ),
    );

    UnifiedLogger.error(
      '❌ Screen error on $screenName: $errorType - $errorMessage',
      name: 'ScreenAnalytics',
    );
  }

  /// End screen session
  void endScreen(String screenName) {
    _activeSessions.remove(screenName);
  }

  static Map<String, Object>? _optionalParameters(
    Map<String, dynamic>? parameters,
  ) {
    if (parameters == null) return null;
    return _parameters(parameters);
  }

  static Map<String, Object> _parameters(Map<String, dynamic> parameters) {
    final filtered = <String, Object>{};
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value != null) {
        filtered[entry.key] = value as Object;
      }
    }
    return filtered;
  }

  /// Whether a session's start time is older than [_maxScreenSessionAge].
  bool _isStale(_ScreenSession session) {
    return DateTime.now().difference(session.loadStartTime) >
        _maxScreenSessionAge;
  }

  /// Remove a stale session and log a warning instead of recording garbage
  /// data.
  void _discardStaleSession(String screenName) {
    final session = _activeSessions.remove(screenName);
    if (session != null) {
      final age = DateTime.now().difference(session.loadStartTime);
      UnifiedLogger.warning(
        'Discarding stale screen session "$screenName" '
        '(started ${age.inSeconds}s ago)',
        name: 'ScreenAnalytics',
      );
    }
  }
}

/// Internal session tracking for a screen
class _ScreenSession {
  _ScreenSession({
    required this.screenName,
    required this.loadStartTime,
    required this.params,
  });

  final String screenName;
  final DateTime loadStartTime;
  final Map<String, dynamic> params;

  DateTime? contentVisibleTime;
  DateTime? dataLoadedTime;
}
