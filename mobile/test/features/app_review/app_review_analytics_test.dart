// ABOUTME: Tests for app_review_analytics helpers. Verifies event names,
// ABOUTME: privacy-safe bucketing, and that the video count is never logged
// ABOUTME: exactly.

import 'package:analytics/analytics.dart';
import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/app_review/app_review_analytics.dart';

/// Records every event logged through the sink for assertion.
class _RecordingSink implements AnalyticsEventSink {
  final List<({String name, Map<String, Object> parameters})> events = [];

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
  group('app_review_analytics', () {
    late _RecordingSink sink;

    setUp(() {
      sink = _RecordingSink();
    });

    group('trackInAppReviewEligible', () {
      test('logs the eligible event with install source and engagement', () {
        trackInAppReviewEligible(
          analytics: sink,
          installSource: InstallSource.playStore,
          videoCount: 50,
          sessionCount: 20,
          daysSinceFirstLaunch: 30,
        );

        expect(sink.events, hasLength(1));
        expect(sink.events.single.name, 'in_app_review_eligible');
        expect(sink.events.single.parameters['install_source'], 'playStore');
        expect(sink.events.single.parameters['session_count_bucket'], '10-20');
        expect(
          sink.events.single.parameters['days_since_first_launch_bucket'],
          '14-30',
        );
      });

      test('buckets the video count, never logs the exact value', () {
        for (final count in [11, 15, 25, 50, 75, 100, 250]) {
          trackInAppReviewEligible(
            analytics: sink,
            installSource: InstallSource.appStore,
            videoCount: count,
            sessionCount: 10,
            daysSinceFirstLaunch: 14,
          );
        }

        final buckets = sink.events
            .map((e) => e.parameters['video_count_bucket'])
            .toSet();

        // No bucket may be a raw integer-string of the actual count.
        for (final bucket in buckets) {
          expect(
            int.tryParse('$bucket'),
            isNull,
            reason: 'bucket "$bucket" leaks the exact video count',
          );
        }
        expect(buckets, containsAll(['11-25', '26-50', '51-100', '100+']));
      });

      test('video_count_bucket boundaries', () {
        String bucketFor(int count) {
          trackInAppReviewEligible(
            analytics: sink,
            installSource: InstallSource.playStore,
            videoCount: count,
            sessionCount: 1,
            daysSinceFirstLaunch: 1,
          );
          final last = sink.events.last.parameters['video_count_bucket'];
          sink.events.clear();
          return '$last';
        }

        expect(bucketFor(0), '0');
        expect(bucketFor(3), '1-5');
        expect(bucketFor(5), '1-5');
        expect(bucketFor(8), '6-10');
        expect(bucketFor(10), '6-10');
        expect(bucketFor(11), '11-25');
        expect(bucketFor(25), '11-25');
        expect(bucketFor(26), '26-50');
        expect(bucketFor(50), '26-50');
        expect(bucketFor(51), '51-100');
        expect(bucketFor(100), '51-100');
        expect(bucketFor(101), '100+');
      });

      test('engagement counts are bucketed, never logged exactly', () {
        trackInAppReviewEligible(
          analytics: sink,
          installSource: InstallSource.playStore,
          videoCount: 50,
          sessionCount: 47,
          daysSinceFirstLaunch: 88,
        );

        final parameters = sink.events.single.parameters;
        expect(parameters, isNot(contains('session_count')));
        expect(parameters, isNot(contains('days_since_first_launch')));
        expect(parameters['session_count_bucket'], '21-50');
        expect(parameters['days_since_first_launch_bucket'], '31-90');
      });
    });

    group('trackInAppReviewPrompted', () {
      test('logs the prompted event', () {
        trackInAppReviewPrompted(analytics: sink);

        expect(sink.events, hasLength(1));
        expect(sink.events.single.name, 'in_app_review_prompted');
      });
    });

    group('trackInAppReviewRequestFailed', () {
      test('logs only the error runtime type, never the message', () {
        trackInAppReviewRequestFailed(
          analytics: sink,
          error: StateError('sensitive detail here'),
        );

        expect(sink.events, hasLength(1));
        expect(sink.events.single.name, 'in_app_review_request_failed');
        expect(sink.events.single.parameters['error_type'], 'StateError');
        // The raw message must never appear in the payload.
        for (final value in sink.events.single.parameters.values) {
          expect('$value', isNot(contains('sensitive detail')));
        }
      });
    });
  });
}
