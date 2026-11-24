import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';

/// Detects videos whose playback position stops advancing while they
/// claim to be playing, and escalates from a seek-kick recovery to source
/// failover when seeks fail to unstick the decoder.
///
/// A single timer is active at a time — call [start] for the current
/// video and [stop] when leaving it.
class StalePlaybackDetector {
  /// Creates a detector. [onSeekRecovery] is invoked first when a stall is
  /// detected; only after [maxRecoveryAttempts] failed seeks does
  /// [onSourceFailover] fire.
  ///
  /// With [watchesBuffering], buffering after playback started keeps the
  /// heartbeat running, so a wait for data whose position stops goes through
  /// the same recovery as playback whose position stops. AVPlayer used to
  /// report those waits as playing, which is how this recovery came to cover
  /// them on iOS and macOS. Buffering before playback starts is left to the
  /// slow-load watchdog.
  StalePlaybackDetector({
    required void Function(int index, int positionMs) onSeekRecovery,
    required void Function(int index) onSourceFailover,
    required void Function(String message) log,
    bool watchesBuffering = false,
  }) : _onSeekRecovery = onSeekRecovery,
       _onSourceFailover = onSourceFailover,
       _log = log,
       _watchesBuffering = watchesBuffering;

  /// Polling interval for the position heartbeat.
  static const interval = Duration(milliseconds: 250);

  /// Consecutive non-advancing heartbeats before a recovery seek is tried.
  /// 8 × 250 ms = 2 s of frozen video.
  static const heartbeatThreshold = 8;

  /// Maximum seek-recovery attempts before triggering source failover.
  static const maxRecoveryAttempts = 2;

  /// Heartbeats to skip after a `play()` or source switch so initial
  /// buffering isn't mistaken for a stall. 5 × 250 ms = 1.25 s.
  static const graceAfterPlay = 5;

  final void Function(int index, int positionMs) _onSeekRecovery;
  final void Function(int index) _onSourceFailover;
  final void Function(String) _log;
  final bool _watchesBuffering;

  Timer? _timer;
  StreamSubscription<DivineVideoPlayerState>? _stateSubscription;
  int? _lastPositionMs;
  int _heartbeats = 0;
  int _graceHeartbeats = 0;

  /// Whether the current source reported playing since [start] or
  /// [resetGrace].
  bool _played = false;
  final _recoveryAttempts = <int, int>{};

  /// Starts monitoring [controller] for [index]. Cancels any previous monitor.
  ///
  /// The [interval] heartbeat runs only while [controller] is actively
  /// playing, or buffering after it played when this detector watches
  /// buffering — otherwise the timer is cancelled and re-armed reactively
  /// via `controller.stateStream` once playback resumes.
  void start(int index, DivineVideoPlayerController? controller) {
    stop();
    if (controller == null) return;

    _lastPositionMs = null;
    _heartbeats = 0;
    _graceHeartbeats = graceAfterPlay;
    _played = false;
    _recoveryAttempts[index] = 0;

    if (_watches(controller.state)) {
      _startHeartbeatTimer(index, controller);
    }

    _stateSubscription = controller.stateStream.listen((state) {
      if (_watches(state)) {
        if (_timer == null) {
          _startHeartbeatTimer(index, controller);
        }
      } else {
        _pauseHeartbeatTimer();
      }
    });
  }

  bool _watches(DivineVideoPlayerState state) {
    if (state.isPlaying) _played = true;
    return state.isPlaying ||
        (_watchesBuffering && _played && state.isBuffering);
  }

  void _startHeartbeatTimer(int index, DivineVideoPlayerController controller) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final state = controller.state;

      if (_graceHeartbeats > 0) {
        _graceHeartbeats--;
        _lastPositionMs = state.position.inMilliseconds;
        return;
      }

      final posMs = state.position.inMilliseconds;
      final last = _lastPositionMs;

      if (last != null && posMs <= last) {
        _heartbeats++;
        if (_heartbeats >= heartbeatThreshold) {
          _heartbeats = 0;
          _graceHeartbeats = graceAfterPlay;
          _handleStale(index, posMs);
        }
      } else {
        _heartbeats = 0;
      }

      _lastPositionMs = posMs;
    });
  }

  void _pauseHeartbeatTimer() {
    _timer?.cancel();
    _timer = null;
    _lastPositionMs = null;
    _heartbeats = 0;
  }

  /// Stops monitoring, both the heartbeat and the state subscription, without
  /// forgetting per-index recovery counters.
  void stop() {
    unawaited(_stateSubscription?.cancel());
    _stateSubscription = null;
    _pauseHeartbeatTimer();
  }

  /// Resets the post-`play()` grace period. Call after a source switch so
  /// stale detection doesn't fire during the new source's initial buffer.
  void resetGrace() {
    _graceHeartbeats = graceAfterPlay;
    _played = false;
  }

  /// Forgets recovery counters for [index].
  void forget(int index) => _recoveryAttempts.remove(index);

  /// Stops the heartbeat and clears all per-index state. Safe to call
  /// from `State.dispose`.
  void disposeAll() {
    stop();
    _recoveryAttempts.clear();
  }

  void _handleStale(int index, int posMs) {
    final attempts = (_recoveryAttempts[index] ?? 0) + 1;
    _recoveryAttempts[index] = attempts;

    _log('Stale position index $index: posMs=$posMs attempt=$attempts');

    if (attempts > maxRecoveryAttempts) {
      _log('Stale max retries exceeded index $index — trying next source');
      stop();
      _onSourceFailover(index);
      return;
    }

    _onSeekRecovery(index, posMs);
  }
}
