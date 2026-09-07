import 'dart:async';

import 'package:unified_logger/unified_logger.dart';

/// A measured activation-to-first-frame interval in the fullscreen feed.
class FeedFirstFrameMetric {
  /// Creates a completed feed first-frame measurement.
  const FeedFirstFrameMetric({
    required this.videoId,
    required this.index,
    required this.duration,
    required this.loadedFromCache,
  });

  /// Full Nostr event id for the video that rendered.
  final String videoId;

  /// Index occupied by the video when it became active.
  final int index;

  /// Time from feed activation until the native player rendered a frame.
  final Duration duration;

  /// Whether the player opened a file from the local media cache.
  final bool loadedFromCache;
}

/// Process-wide stream of completed fullscreen-feed first-frame measurements.
///
/// The stream is intentionally always available: production diagnostics and
/// device integration tests observe the same boundary instead of maintaining
/// test-only timing code or scraping console text.
abstract final class FeedFirstFrameMetrics {
  static final _controller = StreamController<FeedFirstFrameMetric>.broadcast(
    sync: true,
  );

  /// Completed measurements from every mounted fullscreen feed widget.
  static Stream<FeedFirstFrameMetric> get events => _controller.stream;

  /// Starts a monotonic measurement for one active feed item.
  static FeedFirstFrameTimer start({
    required String videoId,
    required int index,
  }) {
    return FeedFirstFrameTimer._(videoId: videoId, index: index);
  }

  static void _record(FeedFirstFrameMetric metric) {
    _controller.add(metric);
    Log.info(
      'videoId=${metric.videoId} index=${metric.index} '
      'durationMs=${metric.duration.inMilliseconds} '
      'cache=${metric.loadedFromCache ? 'hit' : 'miss'}',
      name: 'FeedFirstFrame',
      category: LogCategory.video,
    );
  }
}

/// A one-shot monotonic timer created by [FeedFirstFrameMetrics.start].
class FeedFirstFrameTimer {
  FeedFirstFrameTimer._({required this.videoId, required this.index})
    : _stopwatch = Stopwatch()..start();

  /// Full Nostr event id for the video being measured.
  final String videoId;

  /// Feed index occupied when measurement began.
  final int index;

  final Stopwatch _stopwatch;
  bool _completed = false;

  /// Stops and publishes this measurement once.
  FeedFirstFrameMetric? complete({required bool loadedFromCache}) {
    if (_completed) return null;
    _completed = true;
    _stopwatch.stop();
    final metric = FeedFirstFrameMetric(
      videoId: videoId,
      index: index,
      duration: _stopwatch.elapsed,
      loadedFromCache: loadedFromCache,
    );
    FeedFirstFrameMetrics._record(metric);
    return metric;
  }
}
