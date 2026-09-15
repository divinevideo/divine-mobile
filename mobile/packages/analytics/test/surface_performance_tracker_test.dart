// ABOUTME: Tests for user-visible surface performance analytics.
// ABOUTME: Verifies terminal surface_load events and stale session cleanup.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingAnalyticsEventSink implements AnalyticsEventSink {
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
  group(SurfacePerformanceTracker, () {
    late RecordingAnalyticsEventSink sink;
    late DateTime now;
    late PageLoadHistory history;
    late SurfacePerformanceTracker tracker;

    void elapse(Duration duration) {
      now = now.add(duration);
    }

    setUp(() {
      history = PageLoadHistory();
      sink = RecordingAnalyticsEventSink();
      now = DateTime(2026, 6, 12, 12);
      tracker = SurfacePerformanceTracker(
        history: history,
        sink: sink,
        now: () => now,
      );
    });

    test('logs one surface_load event with semantic parameters', () async {
      tracker.startSurfaceLoad(
        'Comments Sheet',
        params: const {
          AnalyticsParam.entryPoint: 'feed_button',
          AnalyticsParam.initialCount: 12,
          AnalyticsParam.featureFlag: false,
        },
      );
      elapse(const Duration(milliseconds: 120));

      tracker.markSurfaceVisible('Comments Sheet');
      elapse(const Duration(milliseconds: 680));

      await tracker.completeSurfaceLoad(
        'Comments Sheet',
        result: SurfaceLoadResult.success,
        metrics: {
          AnalyticsParam.itemCount: 10,
          AnalyticsParam.hasMore: true,
          AnalyticsParam.sortMode: DateTime(2026),
        },
      );
      await tracker.completeSurfaceLoad(
        'Comments Sheet',
        result: SurfaceLoadResult.success,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'surface_load');
      expect(sink.events.single.parameters, {
        AnalyticsParam.surfaceName: AnalyticsSurface.commentsSheet,
        AnalyticsParam.result: SurfaceLoadResult.success,
        AnalyticsParam.visibleMs: 120,
        AnalyticsParam.dataMs: 800,
        AnalyticsParam.totalMs: 800,
        AnalyticsParam.slowBucket: 'under_1s',
        AnalyticsParam.entryPoint: 'feed_button',
        AnalyticsParam.initialCount: 12,
        AnalyticsParam.itemCount: 10,
        AnalyticsParam.hasMore: 1,
        AnalyticsParam.featureFlag: 0,
      });
      expect(tracker.activeSessionCount, 0);
    });

    test('records completed surface loads in page load history', () async {
      final startedAt = now;
      tracker.startSurfaceLoad(
        'Comments Sheet',
        params: const {AnalyticsParam.entryPoint: 'feed_button'},
      );
      elapse(const Duration(milliseconds: 90));

      tracker.markSurfaceVisible('Comments Sheet');
      elapse(const Duration(milliseconds: 3160));

      await tracker.completeSurfaceLoad(
        'Comments Sheet',
        result: SurfaceLoadResult.success,
        metrics: const {AnalyticsParam.itemCount: 7},
      );

      final record = history.records.single;
      expect(record.screenName, AnalyticsSurface.commentsSheet);
      expect(record.timestamp, startedAt);
      expect(record.contentVisibleMs, 90);
      expect(record.dataLoadedMs, 3250);
      expect(record.result, SurfaceLoadResult.success);
      expect(record.source, PageLoadSource.surface);
      expect(record.dataMetrics, {
        AnalyticsParam.slowBucket: '3_5s',
        AnalyticsParam.entryPoint: 'feed_button',
        AnalyticsParam.itemCount: 7,
      });
    });

    test(
      'completing dismissed removes the session and logs dismissed',
      () async {
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
        elapse(const Duration(milliseconds: 50));

        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.dismissed,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, hasLength(1));
        expect(
          sink.events.single.parameters[AnalyticsParam.result],
          SurfaceLoadResult.dismissed,
        );
        expect(sink.events.single.parameters[AnalyticsParam.visibleMs], -1);
        expect(sink.events.single.parameters[AnalyticsParam.dataMs], -1);
        expect(sink.events.single.parameters[AnalyticsParam.totalMs], 50);
      },
    );

    test(
      'dismissed before data completes records dismissal timing only',
      () async {
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
        elapse(const Duration(milliseconds: 40));

        tracker.markSurfaceVisible(AnalyticsSurface.commentsSheet);
        elapse(const Duration(milliseconds: 90));

        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.dismissed,
        );

        expect(sink.events, hasLength(1));
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.visibleMs, 40),
        );
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.dataMs, -1),
        );
        expect(
          sink.events.single.parameters,
          containsPair(AnalyticsParam.totalMs, 130),
        );
      },
    );

    test(
      'resetAllSessions clears active sessions and later completion is no-op',
      () async {
        tracker
          ..startSurfaceLoad(AnalyticsSurface.commentsSheet)
          ..startSurfaceLoad(AnalyticsSurface.profile);

        expect(tracker.activeSessionCount, 2);

        tracker.resetAllSessions();
        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.success,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, isEmpty);
      },
    );

    test(
      'stale sessions older than 60s are discarded without logging',
      () async {
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
        elapse(const Duration(seconds: 61));

        tracker.markSurfaceVisible(AnalyticsSurface.commentsSheet);
        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.success,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, isEmpty);
      },
    );

    test(
      'completeSurfaceLoad discards stale sessions without visible mark',
      () async {
        tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
        elapse(const Duration(seconds: 61));

        await tracker.completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.success,
        );

        expect(tracker.activeSessionCount, 0);
        expect(sink.events, isEmpty);
      },
    );
  });
}
