// ABOUTME: Comments-specific adapter for surface performance analytics.

import 'package:analytics/analytics.dart';

class CommentsSurfacePerformanceTelemetry {
  CommentsSurfacePerformanceTelemetry.withTracker(this._tracker);

  final SurfacePerformanceTracker _tracker;

  void start({
    int? initialCount,
  }) {
    _tracker.startSurfaceLoad(
      AnalyticsSurface.commentsSheet,
      params: {
        AnalyticsParam.entryPoint: 'feed_comment_button',
        AnalyticsParam.initialCount: ?initialCount,
        AnalyticsParam.featureFlag: 'video_replies_enabled',
      },
    );
  }

  void markVisible() {
    _tracker.markSurfaceVisible(AnalyticsSurface.commentsSheet);
  }

  Future<void> completeDataLoaded({
    required int itemCount,
    required bool hasMore,
    required String sortMode,
  }) {
    return _tracker.completeSurfaceLoad(
      AnalyticsSurface.commentsSheet,
      result: itemCount == 0
          ? SurfaceLoadResult.empty
          : SurfaceLoadResult.success,
      metrics: {
        AnalyticsParam.itemCount: itemCount,
        AnalyticsParam.hasMore: hasMore,
        AnalyticsParam.sortMode: sortMode,
      },
    );
  }

  Future<void> completeFailure() {
    return _tracker.completeSurfaceLoad(
      AnalyticsSurface.commentsSheet,
      result: SurfaceLoadResult.failure,
    );
  }

  Future<void> completeDismissed() {
    return _tracker.completeSurfaceLoad(
      AnalyticsSurface.commentsSheet,
      result: SurfaceLoadResult.dismissed,
    );
  }
}
