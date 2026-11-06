import 'dart:async';

import 'package:infinite_video_feed/src/models/feed_playback_telemetry.dart';
import 'package:unified_logger/unified_logger.dart';

/// A measured activation-to-first-frame interval in the fullscreen feed.
class FeedFirstFrameMetric {
  /// Creates a completed feed first-frame measurement.
  const FeedFirstFrameMetric({
    required this.videoId,
    required this.index,
    required this.duration,
    required this.loadedFromCache,
    this.controllerInitializedAt,
    this.sourceReadyAt,
    this.playbackRequestedAt,
  });

  /// Full Nostr event id for the video that rendered.
  final String videoId;

  /// Index occupied by the video when it became active.
  final int index;

  /// Time from feed activation until the native player rendered a frame.
  final Duration duration;

  /// Whether the player opened a file from the local media cache.
  final bool loadedFromCache;

  /// Time from activation until the native controller was initialized.
  final Duration? controllerInitializedAt;

  /// Time from activation until the media source was ready.
  final Duration? sourceReadyAt;

  /// Time from activation until playback was requested.
  final Duration? playbackRequestedAt;
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
  static final _activePlaybackAttempts = <FeedFirstFrameTimer>{};

  /// Completed measurements from every mounted fullscreen feed widget.
  static Stream<FeedFirstFrameMetric> get events => _controller.stream;

  /// Ends active operational attempts before ordinary collection suspension.
  ///
  /// Success measurements remain available for a later actual first frame.
  /// Privacy withdrawal must invalidate telemetry instead of calling this.
  static void cancelActivePlaybackAttempts() {
    for (final timer in _activePlaybackAttempts.toList()) {
      timer.finish(outcome: FeedPlaybackOutcome.cancelled);
    }
  }

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
      'controllerInitializedMs='
      '${metric.controllerInitializedAt?.inMilliseconds} '
      'sourceReadyMs=${metric.sourceReadyAt?.inMilliseconds} '
      'playbackRequestedMs=${metric.playbackRequestedAt?.inMilliseconds} '
      'cache=${metric.loadedFromCache ? 'hit' : 'miss'}',
      name: 'FeedFirstFrame',
      category: LogCategory.video,
    );
  }
}

/// A one-shot monotonic timer created by [FeedFirstFrameMetrics.start].
class FeedFirstFrameTimer {
  FeedFirstFrameTimer._({required this.videoId, required this.index})
    : _stopwatch = Stopwatch()..start(),
      _attempt = FeedPlaybackTelemetry.startAttempt() {
    if (_attempt != null) {
      FeedFirstFrameMetrics._activePlaybackAttempts.add(this);
      _timeout = Timer(const Duration(seconds: 60), () {
        finish(
          outcome: FeedPlaybackOutcome.noFrame,
          errorCategory: FeedPlaybackError.timeout,
        );
      });
    }
  }

  /// Full Nostr event id for the video being measured.
  final String videoId;

  /// Feed index occupied when measurement began.
  final int index;

  final Stopwatch _stopwatch;
  final FeedPlaybackAttempt? _attempt;
  Timer? _timeout;

  /// Binds this activation to an observed source load in the same context.
  void attachLoad(FeedPlaybackLoad? load) {
    if (_completed) return;
    _attempt?.attachLoad(load);
  }

  /// Terminates operational telemetry without creating a success trace.
  ///
  /// A retry or late first frame can still [complete] the success measurement.
  void finish({
    required FeedPlaybackOutcome outcome,
    FeedPlaybackError errorCategory = FeedPlaybackError.none,
    String localCache = 'unknown',
  }) {
    _timeout?.cancel();
    FeedFirstFrameMetrics._activePlaybackAttempts.remove(this);
    _attempt?.finish(
      outcome: outcome,
      elapsed: _stopwatch.elapsed,
      localCache: localCache,
      error: errorCategory,
      controllerInitialized: _controllerInitializedAt,
      sourceReady: _sourceReadyAt,
      playbackRequested: _playbackRequestedAt,
    );
  }

  bool _completed = false;
  Duration? _controllerInitializedAt;
  Duration? _sourceReadyAt;
  Duration? _playbackRequestedAt;

  /// Records that platform-controller initialization completed.
  void markControllerInitialized() {
    _controllerInitializedAt ??= _stopwatch.elapsed;
  }

  /// Records that the player accepted and prepared its media source.
  void markSourceReady() {
    _sourceReadyAt ??= _stopwatch.elapsed;
  }

  /// Records that playback was requested from the initialized player.
  void markPlaybackRequested() {
    _playbackRequestedAt ??= _stopwatch.elapsed;
  }

  /// Stops and publishes this measurement once.
  FeedFirstFrameMetric? complete({required bool loadedFromCache}) {
    if (_completed) return null;
    _completed = true;
    _stopwatch.stop();
    finish(
      outcome: FeedPlaybackOutcome.firstFrame,
      localCache: loadedFromCache ? 'hit' : 'unknown',
    );
    final metric = FeedFirstFrameMetric(
      videoId: videoId,
      index: index,
      duration: _stopwatch.elapsed,
      loadedFromCache: loadedFromCache,
      controllerInitializedAt: _controllerInitializedAt,
      sourceReadyAt: _sourceReadyAt,
      playbackRequestedAt: _playbackRequestedAt,
    );
    FeedFirstFrameMetrics._record(metric);
    return metric;
  }
}
