// ABOUTME: Tests for FeedPerformanceTracker swipe convenience methods.
// ABOUTME: Verifies video swipe tracking delegates to correct feed types.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

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
  group(FeedPerformanceTracker, () {
    group('feed load phases', () {
      late _RecordingAnalyticsEventSink sink;
      late FeedPerformanceTracker tracker;

      setUp(() {
        sink = _RecordingAnalyticsEventSink();
        tracker = FeedPerformanceTracker(sink: sink);
      });

      test('records initiation reason and keeps cache-first session open', () {
        final handle = tracker.startFeedLoad(
          'forYou',
          reason: FeedLoadReason.sourceSwitch,
        );
        tracker.markFirstVisibleContent(handle, 5, servedFromCache: true);

        expect(tracker.activeSessionCount, 1);
        expect(sink.events.first.name, 'feed_load_started');
        expect(sink.events.first.parameters, {
          'feed_type': 'forYou',
          'load_reason': 'sourceSwitch',
        });
        expect(sink.events[1].parameters, containsPair('served_from_cache', 1));
      });

      test('records fresh completion separately with traversal counts', () {
        final handle = tracker.startFeedLoad('forYou');
        tracker
          ..markFirstVisibleContent(handle, 4, servedFromCache: false)
          ..markFreshResultCompleted(
            handle,
            12,
            recommendationPageCount: 3,
          );

        expect(tracker.activeSessionCount, 0);
        final completion = sink.events.firstWhere(
          (event) => event.name == 'feed_fresh_result_complete',
        );
        expect(
          completion.parameters,
          containsPair('recommendation_page_count', 3),
        );
        expect(completion.parameters, containsPair('following_page_count', 0));
        expect(
          completion.parameters,
          containsPair('time_to_first_visible_ms', isA<int>()),
        );
        expect(
          completion.parameters,
          containsPair('fresh_result_time_ms', isA<int>()),
        );
      });

      test('only records the first visible-content milestone', () {
        final handle = tracker.startFeedLoad('following');
        tracker
          ..markFirstVisibleContent(handle, 3, servedFromCache: true)
          ..markFirstVisibleContent(handle, 8, servedFromCache: false);

        expect(
          sink.events.where(
            (event) => event.name == 'feed_first_content_visible',
          ),
          hasLength(1),
        );
      });

      test('keeps overlapping loads for the same feed independent', () {
        var now = DateTime(2026, 9, 10, 12);
        tracker = FeedPerformanceTracker(sink: sink, now: () => now);

        final first = tracker.startFeedLoad(
          'forYou',
          reason: FeedLoadReason.refresh,
        );
        now = now.add(const Duration(milliseconds: 10));
        final second = tracker.startFeedLoad(
          'forYou',
          reason: FeedLoadReason.pagination,
        );
        now = now.add(const Duration(milliseconds: 20));
        tracker.markFreshResultCompleted(first, 4);

        expect(tracker.activeSessionCount, 1);
        final firstCompletion = sink.events.firstWhere(
          (event) => event.name == 'feed_fresh_result_complete',
        );
        expect(
          firstCompletion.parameters,
          containsPair('load_reason', 'refresh'),
        );
        expect(
          firstCompletion.parameters,
          containsPair('fresh_result_time_ms', 30),
        );

        now = now.add(const Duration(milliseconds: 15));
        tracker.markFirstVisibleContent(
          second,
          8,
          servedFromCache: false,
        );
        now = now.add(const Duration(milliseconds: 5));
        tracker.markFreshResultCompleted(second, 8);

        expect(tracker.activeSessionCount, 0);
        final secondVisible = sink.events.firstWhere(
          (event) =>
              event.name == 'feed_first_content_visible' &&
              event.parameters['load_reason'] == 'pagination',
        );
        expect(
          secondVisible.parameters,
          containsPair('time_to_first_visible_ms', 35),
        );
        final completions = sink.events
            .where((event) => event.name == 'feed_fresh_result_complete')
            .toList();
        expect(completions, hasLength(2));
        expect(
          completions.last.parameters,
          containsPair('fresh_result_time_ms', 40),
        );
      });

      test('completed and abandoned handles are idempotent no-ops', () {
        final completed = tracker.startFeedLoad('forYou');
        tracker.markFreshResultCompleted(completed, 4);
        final eventCountAfterCompletion = sink.events.length;

        tracker
          ..markFreshResultCompleted(completed, 4)
          ..abandonFeedLoad(completed);
        expect(sink.events, hasLength(eventCountAfterCompletion));

        final abandoned = tracker.startFeedLoad('following');
        final eventCountAfterStart = sink.events.length;
        tracker
          ..abandonFeedLoad(abandoned)
          ..markFeedDisplayed(abandoned, 3);

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, hasLength(eventCountAfterStart));
      });
    });

    group('video swipe tracking', () {
      const videoId =
          'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';

      late _RecordingAnalyticsEventSink sink;
      late FeedPerformanceTracker tracker;

      setUp(() {
        sink = _RecordingAnalyticsEventSink();
        tracker = FeedPerformanceTracker(sink: sink);
      });

      test('startVideoSwipeTracking opens a session for the video', () {
        tracker.startVideoSwipeTracking(videoId);

        expect(tracker.activeSessionCount, 1);
      });

      test('markVideoSwipeComplete closes the session it opened', () {
        tracker
          ..startVideoSwipeTracking(videoId)
          ..markVideoSwipeComplete(videoId);

        expect(tracker.activeSessionCount, 0);
      });

      test('swipe tracking reports a video_swipe_ prefixed feed type', () {
        tracker
          ..startVideoSwipeTracking(videoId)
          ..markVideoSwipeComplete(videoId);

        expect(sink.events, hasLength(1));
        expect(sink.events.single.name, 'feed_load_complete');
        expect(
          sink.events.single.parameters,
          containsPair('feed_type', 'video_swipe_$videoId'),
        );
      });
    });

    group('trackSearchSource', () {
      late _RecordingAnalyticsEventSink sink;
      late FeedPerformanceTracker tracker;

      setUp(() {
        sink = _RecordingAnalyticsEventSink();
        tracker = FeedPerformanceTracker(sink: sink);
      });

      test('logs one event per terminal status and skips pending', () {
        tracker
          ..trackSearchSource(
            SearchSource.localCache,
            const SearchSourcePending(),
          )
          ..trackSearchSource(
            SearchSource.localCache,
            const SearchSourceSkipped(),
          )
          ..trackSearchSource(
            SearchSource.funnelcakeApi,
            const SearchSourceSuccess(resultCount: 3, latencyMs: 42),
          )
          ..trackSearchSource(
            SearchSource.nip50Relay,
            const SearchSourceFailed(
              reason: SearchSourceFailureReason.timeout,
              latencyMs: 5000,
            ),
          );

        // Pending adds no signal, so only the three terminal statuses log.
        expect(
          sink.events.map((e) => e.name),
          everyElement('user_search_source'),
        );
        expect(sink.events.map((e) => e.parameters), [
          {'source': SearchSource.localCache.name, 'status': 'skipped'},
          {
            'source': SearchSource.funnelcakeApi.name,
            'status': 'success',
            'result_count': 3,
            'latency_ms': 42,
          },
          {
            'source': SearchSource.nip50Relay.name,
            'status': 'failed',
            'reason': SearchSourceFailureReason.timeout.name,
            'latency_ms': 5000,
          },
        ]);
      });
    });
  });
}
