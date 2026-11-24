// ABOUTME: Exports one Firebase sample per ended fullscreen-feed activation.
// ABOUTME: Uses measured custom metrics and never exports video identifiers.

import 'dart:async';

import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/startup_performance_service.dart';

class FeedPlaybackPerformance {
  /// Sends `video_first_frame` once per ended activation in [sessions].
  ///
  /// [firstFrames] only completes the startup `video_ready` milestone, at the
  /// first rendered frame after launch; [StartupPerformanceService.markVideoReady]
  /// ignores the rest.
  FeedPlaybackPerformance({
    required Stream<FeedFirstFrameMetric> firstFrames,
    required Stream<FeedPlaybackSessionMetric> sessions,
    required PerformanceTraceMonitor monitor,
    required StartupPerformanceService startup,
  }) {
    _firstFrames = firstFrames.listen((_) => startup.markVideoReady());
    _sessions = sessions.listen((sample) => _export(monitor, sample));
  }

  late final StreamSubscription<FeedFirstFrameMetric> _firstFrames;
  late final StreamSubscription<FeedPlaybackSessionMetric> _sessions;

  static void _export(
    PerformanceTraceMonitor monitor,
    FeedPlaybackSessionMetric sample,
  ) {
    PerformanceOperation(monitor, 'video_first_frame').finish(
      attributes: {
        'outcome': sample.outcome.name,
        'end': sample.end.name,
        'cache': sample.loadedFromCache ? 'hit' : 'miss',
        'position': sample.index == 0 ? 'initial' : 'subsequent',
        if (sample.error case final error?) 'error': error.name,
      },
      metrics: {
        'active_ms': sample.active.inMilliseconds,
        if (sample.timeToFirstFrame case final duration?)
          'ttff_ms': duration.inMilliseconds,
        if (sample.controllerInitializedAt case final duration?)
          'controller_initialized_ms': duration.inMilliseconds,
        if (sample.sourceReadyAt case final duration?)
          'source_ready_ms': duration.inMilliseconds,
        if (sample.playbackRequestedAt case final duration?)
          'playback_requested_ms': duration.inMilliseconds,
        if (sample.watched case final duration?)
          'watched_ms': duration.inMilliseconds,
        'stall_count': ?sample.stallCount,
        if (sample.stalled case final duration?)
          'stall_ms': duration.inMilliseconds,
      },
    );
  }

  Future<void> dispose() async {
    await _firstFrames.cancel();
    await _sessions.cancel();
  }
}
