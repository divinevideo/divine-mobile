// ABOUTME: Widget-driven playhead for a frames-only stop-motion composition,
// ABOUTME: which has no native player to report position from.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:openvine/utils/video_editor_playhead.dart';

/// Follows the clock's play time into the sounds scheduled against it.
///
/// [isSeek] marks a discontinuous jump (play, scrub) so active sounds re-seek
/// even when the delta is small enough to pass for a normal tick.
typedef StopMotionAudioSync = void Function(
  Duration position, {
  required bool isPlaying,
  required bool isSeek,
});

/// Drives playback of a frames-only stop-motion clip.
///
/// Such a clip has no mp4, so no native player is ever created — a [Ticker]
/// advances the playhead instead, looping over [totalDuration], so the same
/// play/pause + scrub controls that drive video also drive stop-motion.
///
/// Two consumers follow the clock at different cadences:
///
///  * frame rate — [onPlayTime] (timed layers) and [onAudioSync] (the audio
///    engine needs every wrap / window transition);
///  * throttled to [emitInterval] — [onPositionChanged], because the timeline
///    animates between updates and a frame-rate stream would only flood the
///    bloc. A wrap back to the start always passes so the loop reset is never
///    swallowed.
///
/// [onAdvancingChanged] and [onPlayingChanged] bracket every [play] / [pause]
/// so the owner's notifiers are written in the order its consumers expect.
class StopMotionPlaybackClock {
  /// Creates a clock ticking on [vsync].
  ///
  /// [totalDuration] is read on every play / seek / tick rather than captured,
  /// because frame holds change the loop length mid-session.
  ///
  /// [createStopwatch] is the seam for driving the clock from fake time in
  /// tests (`clock.stopwatch`); production keeps the monotonic [Stopwatch].
  StopMotionPlaybackClock({
    required TickerProvider vsync,
    required this.totalDuration,
    required this.emitInterval,
    required this.onAdvancingChanged,
    required this.onPlayTime,
    required this.onAudioSync,
    required this.onAudioPause,
    required this.onPositionChanged,
    required this.onPlayingChanged,
    Stopwatch Function() createStopwatch = Stopwatch.new,
  }) : _vsync = vsync,
       _stopwatch = createStopwatch();

  /// Wall-clock length of the stop-motion loop.
  final ValueGetter<Duration> totalDuration;

  /// Minimum advance between two [onPositionChanged] emits.
  final Duration emitInterval;

  /// Whether this clock is advancing the playhead.
  final ValueChanged<bool> onAdvancingChanged;

  /// The play time timed layers follow, at frame rate.
  final ValueChanged<Duration> onPlayTime;

  /// The play time the audio engine follows, at frame rate.
  final StopMotionAudioSync onAudioSync;

  /// Pauses every scheduled sound.
  final VoidCallback onAudioPause;

  /// The throttled playhead position for the timeline.
  final ValueChanged<Duration> onPositionChanged;

  /// Playback started ([play]) or stopped ([pause]).
  final ValueChanged<bool> onPlayingChanged;

  final TickerProvider _vsync;
  final Stopwatch _stopwatch;
  Ticker? _ticker;

  /// Position the clock resumes from; re-anchored on play / seek.
  Duration _anchor = Duration.zero;

  /// Last position pushed through [onPositionChanged], for throttling.
  Duration _lastEmit = Duration.zero;

  /// Whether the clock is running.
  bool get isPlaying => _stopwatch.isRunning;

  /// Starts (or re-anchors) playback at [from], wrapping to the start when
  /// [from] is at or past the end of the loop. Ignored while the loop is empty.
  void play({required Duration from}) {
    final total = totalDuration();
    if (total <= Duration.zero) return;

    _anchor = from >= total ? Duration.zero : from;
    _lastEmit = _anchor;
    _stopwatch
      ..reset()
      ..start();
    // Ticker.start() asserts the ticker is idle; re-anchoring while already
    // playing (e.g. external unpause) must not double-start it.
    final ticker = _ticker ??= _vsync.createTicker(_onTick);
    if (!ticker.isActive) ticker.start();
    onAdvancingChanged(true);

    onPlayTime(_anchor);
    // Re-anchoring is a clock set, not a tick: a resume that lands mid-window
    // must re-seek even when it re-anchors only slightly ahead.
    onAudioSync(_anchor, isPlaying: true, isSeek: true);

    onPositionChanged(_anchor);
    onPlayingChanged(true);
  }

  /// Stops the clock where it is. Safe to call when already paused.
  void pause() {
    _stopwatch.stop();
    if (_ticker?.isActive ?? false) _ticker!.stop();
    onAdvancingChanged(false);
    onAudioPause();
    onPlayingChanged(false);
  }

  /// Jumps the playhead to [position] (timeline scrubbing), re-anchoring the
  /// clock so playback continues from there if it was running.
  void seek(Duration position) {
    final total = totalDuration();
    final clamped = total <= Duration.zero
        ? Duration.zero
        : Duration(
            microseconds: position.inMicroseconds.clamp(
              0,
              total.inMicroseconds,
            ),
          );

    _anchor = clamped;
    _lastEmit = clamped;
    if (_stopwatch.isRunning) {
      _stopwatch
        ..reset()
        ..start();
    }
    onPlayTime(clamped);
    onAudioSync(clamped, isPlaying: _stopwatch.isRunning, isSeek: true);
    onPositionChanged(clamped);
  }

  /// Releases the ticker. The instance cannot be reused afterwards.
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration _) {
    final total = totalDuration();
    if (total <= Duration.zero) {
      pause();
      return;
    }

    final looped = stopMotionLoopPosition(
      anchor: _anchor,
      elapsed: _stopwatch.elapsed,
      total: total,
    );

    // Frame-rate consumers first, so a wrap reaches the audio engine even
    // when the throttled emit below swallows it.
    onPlayTime(looped);
    onAudioSync(looped, isPlaying: true, isSeek: false);

    if (!playheadEmitDue(
      last: _lastEmit,
      next: looped,
      interval: emitInterval,
    )) {
      return;
    }
    _lastEmit = looped;
    onPositionChanged(looped);
  }
}
