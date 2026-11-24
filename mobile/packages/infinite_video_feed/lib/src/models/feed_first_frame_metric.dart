import 'dart:async';

import 'package:clock/clock.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:infinite_video_feed/src/models/feed_playback_session_metric.dart';
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
  static final _sessionController =
      StreamController<FeedPlaybackSessionMetric>.broadcast(sync: true);
  static final _activePlaybackAttempts = <FeedFirstFrameTimer>{};

  /// Completed measurements from every mounted fullscreen feed widget.
  static Stream<FeedFirstFrameMetric> get events => _controller.stream;

  /// One measurement per ended activation, published when it ends.
  ///
  /// Unlike [events], it includes activations that never rendered a frame.
  static Stream<FeedPlaybackSessionMetric> get sessions =>
      _sessionController.stream;

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

  static void _recordSession(String videoId, FeedPlaybackSessionMetric metric) {
    _sessionController.add(metric);
    Log.info(
      'videoId=$videoId index=${metric.index} '
      'outcome=${metric.outcome.name} end=${metric.end.name} '
      'activeMs=${metric.active.inMilliseconds} '
      'ttffMs=${metric.timeToFirstFrame?.inMilliseconds} '
      'watchedMs=${metric.watched?.inMilliseconds} '
      'stalls=${metric.stallCount} '
      'stallMs=${metric.stalled?.inMilliseconds} '
      'error=${metric.error?.name} '
      'cache=${metric.loadedFromCache ? 'hit' : 'miss'}',
      name: 'FeedPlaybackSession',
      category: LogCategory.video,
    );
  }
}

/// Measures one activation created by [FeedFirstFrameMetrics.start]: its
/// first frame, then its playback until [end].
class FeedFirstFrameTimer {
  FeedFirstFrameTimer._({required this.videoId, required this.index})
    : _stopwatch = clock.stopwatch()..start(),
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
    if (!_ended && outcome == FeedPlaybackOutcome.error) {
      _failure = errorCategory;
    }
    _finishAttempt(
      outcome: outcome,
      elapsed: _stopwatch.elapsed,
      errorCategory: errorCategory,
      localCache: localCache,
    );
  }

  void _finishAttempt({
    required FeedPlaybackOutcome outcome,
    required Duration elapsed,
    FeedPlaybackError errorCategory = FeedPlaybackError.none,
    String localCache = 'unknown',
  }) {
    _timeout?.cancel();
    FeedFirstFrameMetrics._activePlaybackAttempts.remove(this);
    _attempt?.finish(
      outcome: outcome,
      elapsed: elapsed,
      localCache: localCache,
      error: errorCategory,
      controllerInitialized: _controllerInitializedAt,
      sourceReady: _sourceReadyAt,
      playbackRequested: _playbackRequestedAt,
    );
  }

  bool _completed = false;
  bool _ended = false;
  bool _autoPlayBlocked = false;
  FeedPlaybackError? _failure;
  Duration? _firstFrameAt;
  bool? _firstFrameLoadedFromCache;
  _PlaybackClock? _playback;
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

  /// Records whether the feed let this video start playing on its own.
  ///
  /// An activation that the feed held back, such as a video behind a
  /// content warning, and that ended without a frame is not reported.
  void markAutoPlay({required bool allowed}) {
    if (_ended) return;
    _autoPlayBlocked = !allowed;
  }

  /// Publishes the first-frame measurement once.
  FeedFirstFrameMetric? complete({required bool loadedFromCache}) {
    if (_completed || _ended) return null;
    _completed = true;
    final elapsed = _stopwatch.elapsed;
    _firstFrameAt = elapsed;
    _firstFrameLoadedFromCache = loadedFromCache;
    _finishAttempt(
      outcome: FeedPlaybackOutcome.firstFrame,
      elapsed: elapsed,
      localCache: loadedFromCache ? 'hit' : 'unknown',
    );
    final metric = FeedFirstFrameMetric(
      videoId: videoId,
      index: index,
      duration: elapsed,
      loadedFromCache: loadedFromCache,
      controllerInitializedAt: _controllerInitializedAt,
      sourceReadyAt: _sourceReadyAt,
      playbackRequestedAt: _playbackRequestedAt,
    );
    FeedFirstFrameMetrics._record(metric);
    return metric;
  }

  /// Follows [controller], the player showing this video, once it rendered
  /// its first frame.
  ///
  /// Counts the time it reports playing and, when [reportsStalls], the
  /// buffering after playback started. Following a replacement controller
  /// moves the measurement over to it.
  void observePlayback(
    DivineVideoPlayerController controller, {
    required bool reportsStalls,
  }) {
    if (_ended || _firstFrameAt == null) return;
    (_playback ??= _PlaybackClock(
      () => _stopwatch.elapsed,
      reportsStalls: reportsStalls,
    )).follow(controller);
  }

  /// Ends this activation and publishes its playback session once.
  ///
  /// [loadedFromCache] applies when no first frame rendered; otherwise the
  /// value given to [complete] is kept. Returns `null` when it already ended,
  /// or when autoplay was held back and no frame rendered.
  FeedPlaybackSessionMetric? end(
    FeedPlaybackSessionEnd reason, {
    required bool loadedFromCache,
  }) {
    if (_ended) return null;
    _stopwatch.stop();
    final active = _stopwatch.elapsed;
    _finishAttempt(outcome: FeedPlaybackOutcome.cancelled, elapsed: active);
    _ended = true;
    final playback = _playback?..close();
    final firstFrame = _firstFrameAt;
    if (firstFrame == null && _autoPlayBlocked) return null;
    final played = firstFrame != null;
    final failure = played ? null : _failure;
    final stallsReported = played && (playback?.reportsStalls ?? false);
    final metric = FeedPlaybackSessionMetric(
      index: index,
      outcome: played
          ? FeedPlaybackSessionOutcome.played
          : failure != null
          ? FeedPlaybackSessionOutcome.failed
          : FeedPlaybackSessionOutcome.abandoned,
      end: reason,
      loadedFromCache: _firstFrameLoadedFromCache ?? loadedFromCache,
      active: active,
      error: failure,
      timeToFirstFrame: firstFrame,
      controllerInitializedAt: _controllerInitializedAt,
      sourceReadyAt: _sourceReadyAt,
      playbackRequestedAt: _playbackRequestedAt,
      watched: played ? playback?.watched ?? Duration.zero : null,
      stallCount: stallsReported ? playback?.stalls : null,
      stalled: stallsReported ? playback?.stalled : null,
    );
    FeedFirstFrameMetrics._recordSession(videoId, metric);
    return metric;
  }
}

/// Splits an activation's time after its first frame into playing and
/// stalled spans, from the status its player reports.
final class _PlaybackClock {
  _PlaybackClock(this._now, {required this.reportsStalls});

  final Duration Function() _now;

  /// Whether the player reports a wait for data as buffering.
  final bool reportsStalls;

  DivineVideoPlayerController? _controller;
  StreamSubscription<DivineVideoPlayerState>? _subscription;
  bool _started = false;
  Duration? _playingSince;
  Duration? _stalledSince;
  Duration watched = Duration.zero;
  Duration stalled = Duration.zero;
  int stalls = 0;

  void follow(DivineVideoPlayerController controller) {
    if (identical(controller, _controller)) return;
    _controller = controller;
    unawaited(_subscription?.cancel());
    _apply(controller.state);
    _subscription = controller.stateStream.listen(
      _apply,
      onDone: () => _apply(const DivineVideoPlayerState()),
    );
  }

  void _apply(DivineVideoPlayerState state) {
    final now = _now();
    if (state.isPlaying) {
      _started = true;
      _playingSince ??= now;
    } else if (_playingSince case final since?) {
      watched += now - since;
      _playingSince = null;
    }
    // Buffering before playback first started is the start-up wait, which
    // the first-frame milestones already describe.
    if (reportsStalls && _started && state.isBuffering) {
      if (_stalledSince == null) {
        _stalledSince = now;
        stalls++;
      }
    } else if (_stalledSince case final since?) {
      stalled += now - since;
      _stalledSince = null;
    }
  }

  void close() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _apply(const DivineVideoPlayerState());
  }
}
