// ABOUTME: Comprehensive error and exception analytics tracking
// ABOUTME: Tracks errors, exceptions, network failures, and user-facing issues with full context

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for tracking errors and exceptions across the app
class ErrorAnalyticsTracker {
  static final ErrorAnalyticsTracker _instance =
      ErrorAnalyticsTracker._internal();
  factory ErrorAnalyticsTracker() => _instance;
  ErrorAnalyticsTracker._internal();

  // Lazy initialization to avoid Firebase dependency during construction
  FirebaseAnalytics? _analytics;
  FirebaseAnalytics get analytics => _analytics ??= FirebaseAnalytics.instance;

  final Map<String, int> _errorCounts = {};

  /// Track a general application error
  void trackError({
    required String errorType,
    required String errorMessage,
    required String location, // Screen/service where error occurred
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
    bool isFatal = false,
  }) {
    // Increment error count for this type
    final errorKey = '$location:$errorType';
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;

    final sanitizedMessage = errorMessage.length > 200
        ? errorMessage.substring(0, 200)
        : errorMessage;

    UnifiedLogger.error(
      '❌ Error in $location: $errorType - $sanitizedMessage',
      name: 'ErrorAnalytics',
    );

    // Log to Firebase Analytics
    analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': sanitizedMessage,
        'location': location,
        'occurrence_count': _errorCounts[errorKey]!,
        'is_fatal': isFatal,
        if (context != null) ...context,
      },
    );

    // Log to Crashlytics if available
    try {
      FirebaseCrashlytics.instance.recordError(
        Exception('$errorType: $sanitizedMessage'),
        stackTrace,
        reason: 'Error in $location',
        fatal: isFatal,
      );
    } catch (e) {
      // Crashlytics not available or failed
      debugPrint('Could not log to Crashlytics: $e');
    }
  }

  /// Track feed loading errors (CRITICAL for Popular/Trending/Hashtag issues)
  void trackFeedLoadError({
    required String feedType, // 'popular', 'trending', 'hashtag', 'home'
    required String
    errorType, // 'no_events', 'timeout', 'network_error', 'parse_error'
    required String errorMessage,
    int? expectedCount,
    int? actualCount,
    int? loadTimeMs,
    Map<String, dynamic>? additionalContext,
  }) {
    UnifiedLogger.error(
      '📭 Feed load error: $feedType - $errorType - $errorMessage',
      name: 'ErrorAnalytics',
    );

    analytics.logEvent(
      name: 'feed_load_error',
      parameters: {
        'feed_type': feedType,
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 150 ? 150 : errorMessage.length,
        ),
        if (expectedCount != null) 'expected_count': expectedCount,
        if (actualCount != null) 'actual_count': actualCount,
        if (loadTimeMs != null) 'load_time_ms': loadTimeMs,
        if (additionalContext != null) ...additionalContext,
      },
    );
  }

  /// Track timeout errors specifically
  void trackTimeout({
    required String operation, // 'feed_load', 'video_fetch', 'relay_connection'
    required int timeoutMs,
    required String location,
    Map<String, dynamic>? context,
  }) {
    UnifiedLogger.warning(
      '⏱️  Timeout: $operation in $location after ${timeoutMs}ms',
      name: 'ErrorAnalytics',
    );

    analytics.logEvent(
      name: 'operation_timeout',
      parameters: {
        'operation': operation,
        'timeout_ms': timeoutMs,
        'location': location,
        if (context != null) ...context,
      },
    );
  }

  /// Track network errors
  void trackNetworkError({
    required String operation,
    required String
    errorType, // 'connection_failed', 'dns_error', 'ssl_error', 'timeout'
    required String errorMessage,
    String? url,
    int? statusCode,
    int? retryAttempt,
  }) {
    UnifiedLogger.error(
      '🌐 Network error: $operation - $errorType - $errorMessage',
      name: 'ErrorAnalytics',
    );

    analytics.logEvent(
      name: 'network_error',
      parameters: {
        'operation': operation,
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 150 ? 150 : errorMessage.length,
        ),
        if (url != null) 'url_domain': Uri.tryParse(url)?.host ?? 'unknown',
        if (statusCode != null) 'status_code': statusCode,
        if (retryAttempt != null) 'retry_attempt': retryAttempt,
      },
    );
  }

  /// Track Nostr relay errors
  void trackRelayError({
    required String relayUrl,
    required String
    errorType, // 'connection_failed', 'subscription_failed', 'timeout', 'auth_failed'
    required String errorMessage,
    String? subscriptionType,
  }) {
    UnifiedLogger.error(
      '📡 Relay error: ${Uri.tryParse(relayUrl)?.host ?? relayUrl} - $errorType - $errorMessage',
      name: 'ErrorAnalytics',
    );

    analytics.logEvent(
      name: 'relay_error',
      parameters: {
        'relay_url': Uri.tryParse(relayUrl)?.host ?? 'unknown',
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 150 ? 150 : errorMessage.length,
        ),
        if (subscriptionType != null) 'subscription_type': subscriptionType,
      },
    );
  }

  /// Track video playback errors
  void trackVideoPlaybackError({
    required String videoId,
    required String
    errorType, // 'load_failed', 'playback_error', 'format_unsupported'
    required String errorMessage,
    String? videoUrl,
    int? attemptTimeMs,
  }) {
    analytics.logEvent(
      name: 'video_playback_error',
      parameters: {
        'video_id': videoId,
        'error_type': errorType,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 150 ? 150 : errorMessage.length,
        ),
        if (videoUrl != null)
          'video_url_domain': Uri.tryParse(videoUrl)?.host ?? 'unknown',
        if (attemptTimeMs != null) 'attempt_time_ms': attemptTimeMs,
      },
    );
  }

  /// Track slow operations (not errors, but performance issues)
  void trackSlowOperation({
    required String operation,
    required int durationMs,
    required int thresholdMs,
    String? location,
    Map<String, dynamic>? context,
  }) {
    UnifiedLogger.warning(
      '🐌 Slow operation: $operation took ${durationMs}ms (threshold: ${thresholdMs}ms)',
      name: 'ErrorAnalytics',
    );

    analytics.logEvent(
      name: 'slow_operation',
      parameters: {
        'operation': operation,
        'duration_ms': durationMs,
        'threshold_ms': thresholdMs,
        'slowness_ratio': (durationMs / thresholdMs).toStringAsFixed(2),
        if (location != null) 'location': location,
        if (context != null) ...context,
      },
    );
  }

  /// Track user-facing error messages
  void trackUserFacingError({
    required String errorType,
    required String userMessage,
    required String location,
    String? actionTaken, // 'retry_shown', 'dismissed', 'error_page'
  }) {
    analytics.logEvent(
      name: 'user_facing_error',
      parameters: {
        'error_type': errorType,
        'user_message': userMessage.substring(
          0,
          userMessage.length > 100 ? 100 : userMessage.length,
        ),
        'location': location,
        if (actionTaken != null) 'action_taken': actionTaken,
      },
    );

    UnifiedLogger.info(
      '👤 User saw error: $errorType in $location',
      name: 'ErrorAnalytics',
    );
  }

  /// Get error count for a specific type/location
  int getErrorCount(String location, String errorType) {
    return _errorCounts['$location:$errorType'] ?? 0;
  }

  /// Get all error counts for bug reports
  Map<String, int> getAllErrorCounts() {
    return Map.from(_errorCounts);
  }

  /// Reset error counts (useful for testing or debugging)
  void resetErrorCounts() {
    _errorCounts.clear();
  }
}
