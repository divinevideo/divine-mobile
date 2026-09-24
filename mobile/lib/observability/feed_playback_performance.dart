// ABOUTME: Exports completed fullscreen-feed first-frame timings to Firebase.
// ABOUTME: Uses measured custom metrics and never exports video identifiers.

import 'dart:async';

import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/startup_performance_service.dart';

class FeedPlaybackPerformance {
  /// The first sample after launch also completes the startup `video_ready`
  /// milestone; [StartupPerformanceService.markVideoReady] ignores the rest.
  FeedPlaybackPerformance(
    Stream<FeedFirstFrameMetric> events,
    PerformanceTraceMonitor monitor,
    StartupPerformanceService startup,
  ) {
    _subscription = events.listen((sample) {
      PerformanceOperation(monitor, 'video_first_frame').finish(
        attributes: {
          'cache': sample.loadedFromCache ? 'hit' : 'miss',
          'position': sample.index == 0 ? 'initial' : 'subsequent',
        },
        metrics: {
          'ttff_ms': sample.duration.inMilliseconds,
          if (sample.controllerInitializedAt case final duration?)
            'controller_initialized_ms': duration.inMilliseconds,
          if (sample.sourceReadyAt case final duration?)
            'source_ready_ms': duration.inMilliseconds,
          if (sample.playbackRequestedAt case final duration?)
            'playback_requested_ms': duration.inMilliseconds,
        },
      );
      startup.markVideoReady();
    });
  }

  late final StreamSubscription<FeedFirstFrameMetric> _subscription;

  Future<void> dispose() => _subscription.cancel();
}
