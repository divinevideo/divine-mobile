// ABOUTME: Tests for error analytics event names and semantic parameters.
// ABOUTME: Verifies the extracted tracker can be exercised without Firebase.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  group(ErrorAnalyticsTracker, () {
    late _RecordingAnalyticsEventSink sink;
    late ErrorAnalyticsTracker tracker;

    setUp(() {
      sink = _RecordingAnalyticsEventSink();
      tracker = ErrorAnalyticsTracker(sink: sink);
    });

    test('trackError logs app_error and counts repeated occurrences', () {
      tracker
        ..trackError(
          errorType: 'parse_error',
          errorMessage: '${'x' * 205}tail',
          location: 'ExploreScreen',
          context: const {'feed_type': 'popular'},
          isFatal: true,
        )
        ..trackError(
          errorType: 'parse_error',
          errorMessage: 'second failure',
          location: 'ExploreScreen',
        );

      expect(sink.events, hasLength(2));
      expect(sink.events.first.name, 'app_error');
      expect(sink.events.first.parameters, {
        'error_type': 'parse_error',
        'error_message': 'x' * 200,
        'location': 'ExploreScreen',
        'occurrence_count': 1,
        'is_fatal': true,
        'feed_type': 'popular',
      });
      expect(sink.events.last.parameters['occurrence_count'], 2);
      expect(tracker.getErrorCount('ExploreScreen', 'parse_error'), 2);
      expect(tracker.getAllErrorCounts(), {'ExploreScreen:parse_error': 2});

      tracker.resetErrorCounts();

      expect(tracker.getErrorCount('ExploreScreen', 'parse_error'), 0);
      expect(tracker.getAllErrorCounts(), isEmpty);
    });

    test('trackFeedLoadError logs feed_load_error with optional metrics', () {
      tracker.trackFeedLoadError(
        feedType: 'popular',
        errorType: 'timeout',
        errorMessage: '${'network ' * 30}tail',
        expectedCount: 20,
        actualCount: 0,
        loadTimeMs: 5000,
        additionalContext: const {'entry_point': 'pull_to_refresh'},
      );

      expect(sink.events.single.name, 'feed_load_error');
      expect(sink.events.single.parameters, {
        'feed_type': 'popular',
        'error_type': 'timeout',
        'error_message': ('network ' * 30).substring(0, 150),
        'expected_count': 20,
        'actual_count': 0,
        'load_time_ms': 5000,
        'entry_point': 'pull_to_refresh',
      });
    });

    test('trackTimeout logs operation_timeout', () {
      tracker.trackTimeout(
        operation: 'feed_load',
        timeoutMs: 3000,
        location: 'HomeFeed',
        context: const {'feed_type': 'home'},
      );

      expect(sink.events.single.name, 'operation_timeout');
      expect(sink.events.single.parameters, {
        'operation': 'feed_load',
        'timeout_ms': 3000,
        'location': 'HomeFeed',
        'feed_type': 'home',
      });
    });

    test('trackNetworkError logs network_error with parsed URL domain', () {
      tracker.trackNetworkError(
        operation: 'video_fetch',
        errorType: 'connection_failed',
        errorMessage: '${'socket ' * 30}tail',
        url: 'https://cdn.example.com/video.mp4',
        statusCode: 503,
        retryAttempt: 2,
      );

      expect(sink.events.single.name, 'network_error');
      expect(sink.events.single.parameters, {
        'operation': 'video_fetch',
        'error_type': 'connection_failed',
        'error_message': ('socket ' * 30).substring(0, 150),
        'url_domain': 'cdn.example.com',
        'status_code': 503,
        'retry_attempt': 2,
      });
    });

    test('trackRelayError logs relay_error with relay host', () {
      tracker.trackRelayError(
        relayUrl: 'wss://relay.example.com',
        errorType: 'subscription_failed',
        errorMessage: 'closed',
        subscriptionType: 'profile_feed',
      );

      expect(sink.events.single.name, 'relay_error');
      expect(sink.events.single.parameters, {
        'relay_url': 'relay.example.com',
        'error_type': 'subscription_failed',
        'error_message': 'closed',
        'subscription_type': 'profile_feed',
      });
    });

    test('trackVideoPlaybackError logs video_playback_error', () {
      tracker.trackVideoPlaybackError(
        videoId:
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
        errorType: 'load_failed',
        errorMessage: 'unsupported codec',
        videoUrl: 'https://videos.example.com/file.mp4',
        attemptTimeMs: 120,
      );

      expect(sink.events.single.name, 'video_playback_error');
      expect(sink.events.single.parameters, {
        'video_id':
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
        'error_type': 'load_failed',
        'error_message': 'unsupported codec',
        'video_url_domain': 'videos.example.com',
        'attempt_time_ms': 120,
      });
    });

    test('trackSlowOperation logs slow_operation', () {
      tracker.trackSlowOperation(
        operation: 'hydrate_profile',
        durationMs: 750,
        thresholdMs: 250,
        location: 'ProfileScreen',
        context: const {'source': 'cache_miss'},
      );

      expect(sink.events.single.name, 'slow_operation');
      expect(sink.events.single.parameters, {
        'operation': 'hydrate_profile',
        'duration_ms': 750,
        'threshold_ms': 250,
        'slowness_ratio': '3.00',
        'location': 'ProfileScreen',
        'source': 'cache_miss',
      });
    });

    test('trackUserFacingError logs user_facing_error', () {
      tracker.trackUserFacingError(
        errorType: 'delete_failed',
        userMessage: '${'Please retry. ' * 12}tail',
        location: 'VideoDetail',
        actionTaken: 'retry_shown',
      );

      expect(sink.events.single.name, 'user_facing_error');
      expect(sink.events.single.parameters, {
        'error_type': 'delete_failed',
        'user_message': ('Please retry. ' * 12).substring(0, 100),
        'location': 'VideoDetail',
        'action_taken': 'retry_shown',
      });
    });
  });
}
