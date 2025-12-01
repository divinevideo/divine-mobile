// ABOUTME: Screen navigation and performance analytics service
// ABOUTME: Tracks screen load times, navigation patterns, and user engagement metrics

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for tracking screen navigation, performance, and user engagement
class ScreenAnalyticsService {
  static final ScreenAnalyticsService _instance =
      ScreenAnalyticsService._internal();
  factory ScreenAnalyticsService() => _instance;
  ScreenAnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, _ScreenSession> _activeSessions = {};

  String? _currentScreen;
  DateTime? _currentScreenStartTime;

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

    session.contentVisibleTime = DateTime.now();
    final loadTime = session.contentVisibleTime!
        .difference(session.loadStartTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '✅ Screen content visible: $screenName in ${loadTime}ms',
      name: 'ScreenAnalytics',
    );

    // Log to Firebase
    _analytics.logEvent(
      name: 'screen_load',
      parameters: {
        'screen_name': screenName,
        'load_time_ms': loadTime,
        ...session.params,
      },
    );
  }

  /// Mark when screen data is fully loaded (async data fetched)
  void markDataLoaded(String screenName, {Map<String, dynamic>? dataMetrics}) {
    final session = _activeSessions[screenName];
    if (session == null) return;

    session.dataLoadedTime = DateTime.now();
    final dataLoadTime = session.dataLoadedTime!
        .difference(session.loadStartTime)
        .inMilliseconds;

    UnifiedLogger.info(
      '📊 Screen data loaded: $screenName in ${dataLoadTime}ms',
      name: 'ScreenAnalytics',
    );

    // Log to Firebase
    _analytics.logEvent(
      name: 'screen_data_loaded',
      parameters: {
        'screen_name': screenName,
        'data_load_time_ms': dataLoadTime,
        if (dataMetrics != null) ...dataMetrics,
        ...session.params,
      },
    );
  }

  /// Track screen view and time spent
  void trackScreenView(String screenName, {Map<String, dynamic>? params}) {
    // End previous screen session if exists
    if (_currentScreen != null && _currentScreenStartTime != null) {
      final timeSpent = DateTime.now()
          .difference(_currentScreenStartTime!)
          .inSeconds;

      _analytics.logEvent(
        name: 'screen_time',
        parameters: {
          'screen_name': _currentScreen!,
          'time_spent_seconds': timeSpent,
        },
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
    _analytics.logScreenView(
      screenName: screenName,
      parameters: params?.cast<String, Object>(),
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
    _analytics.logEvent(
      name: 'user_interaction',
      parameters: {
        'screen_name': screenName,
        'interaction_type': interactionType,
        if (params != null) ...params,
      },
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
    _analytics.logEvent(
      name: 'screen_navigation',
      parameters: {
        'from_screen': from,
        'to_screen': to,
        if (trigger != null) 'trigger': trigger,
      },
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
    _analytics.logEvent(
      name: 'screen_scroll',
      parameters: {
        'screen_name': screenName,
        'scroll_depth': scrollDepth,
        'items_viewed': itemsViewed,
        if (totalItems != null) 'total_items': totalItems,
      },
    );
  }

  /// Track search usage
  void trackSearch({
    required String screenName,
    required String query,
    required int resultsCount,
    required int loadTimeMs,
  }) {
    _analytics.logEvent(
      name: 'search_performed',
      parameters: {
        'screen_name': screenName,
        'query_length': query.length,
        'results_count': resultsCount,
        'load_time_ms': loadTimeMs,
      },
    );

    UnifiedLogger.info(
      '🔍 Search performed: ${query.length} chars, $resultsCount results in ${loadTimeMs}ms',
      name: 'ScreenAnalytics',
    );
  }

  /// Track tab changes
  void trackTabChange({required String screenName, required String tabName}) {
    _analytics.logEvent(
      name: 'tab_changed',
      parameters: {'screen_name': screenName, 'tab_name': tabName},
    );
  }

  /// Track error on screen
  void trackScreenError({
    required String screenName,
    required String errorType,
    required String errorMessage,
    Map<String, dynamic>? context,
  }) {
    _analytics.logEvent(
      name: 'screen_error',
      parameters: {
        'screen_name': screenName,
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
        if (context != null) ...context,
      },
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
