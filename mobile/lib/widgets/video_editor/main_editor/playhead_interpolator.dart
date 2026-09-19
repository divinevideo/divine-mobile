// ABOUTME: Frame-rate playhead clock between the native player's coarse
// ABOUTME: position reports, so timed layers animate instead of stepping.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:openvine/utils/video_editor_playhead.dart';

/// Advances the layer-overlay play time at display refresh rate between the
/// native player's position reports.
///
/// The native player reports position only ~5×/s (`addPeriodicTimeObserver`,
/// 0.2 s), and the overlay's enter/leave animations are driven solely by the
/// play time — so at the raw report rate they visibly step. Each report
/// re-[anchor]s this clock (correcting drift); between reports a [Ticker]
/// interpolates forward from the anchor by the wall-clock elapsed, scaled by
/// playback speed and clamped to the composition's duration — or, when the
/// anchor asks for it, wrapped around the duration like the looping player.
///
/// Runs only while playing. The owner calls [stop] the moment playback ends or
/// a seek / trim / drag gesture takes over the play time, so the interpolator
/// can never overwrite a target those paths pinned.
///
/// Positions in and out are in the player's own (composite) space; mapping to
/// editor-timeline space is the owner's job.
class PlayheadInterpolator {
  /// Creates an interpolator ticking on [vsync].
  ///
  /// [createStopwatch] is the seam for driving the clock from fake time in
  /// tests (`clock.stopwatch`); production keeps the monotonic [Stopwatch].
  PlayheadInterpolator({
    required TickerProvider vsync,
    required this.onTick,
    required this.onAdvancingChanged,
    Stopwatch Function() createStopwatch = Stopwatch.new,
  }) : _vsync = vsync,
       _stopwatch = createStopwatch();

  /// Receives the interpolated player-space position once per frame.
  final ValueChanged<Duration> onTick;

  /// Reports whether this clock is advancing the playhead: `true` on every
  /// [anchor], `false` on every [stop] — including redundant ones, so the
  /// owner's notifier is always written from the same place.
  final ValueChanged<bool> onAdvancingChanged;

  final TickerProvider _vsync;
  final Stopwatch _stopwatch;
  Ticker? _ticker;

  /// Authoritative player position captured at the last [anchor].
  Duration _anchor = Duration.zero;

  /// Player playback-speed multiplier captured at the last [anchor].
  double _speed = 1;

  /// Player duration captured at the last [anchor], clamping interpolation.
  Duration _maxDuration = Duration.zero;

  /// Whether interpolation wraps around [_maxDuration] instead of stopping.
  bool _wrap = false;

  /// Whether the ticker is running.
  bool get isActive => _ticker?.isActive ?? false;

  /// Captures an authoritative player report as the interpolation anchor,
  /// restarts the wall-clock used to advance from it, and (re)starts ticking.
  ///
  /// A non-positive [speed] is treated as 1×: the player reports `0` while
  /// paused, and interpolating at 0× would freeze the overlay.
  ///
  /// With [wrap] the clock loops around [maxDuration] instead of parking
  /// there until the next report: on a loop of a few frames the park would
  /// be most of the loop.
  void anchor({
    required Duration position,
    required double speed,
    required Duration maxDuration,
    bool wrap = false,
  }) {
    _anchor = position;
    _speed = speed > 0 ? speed : 1;
    _maxDuration = maxDuration;
    _wrap = wrap;
    _stopwatch
      ..reset()
      ..start();
    // Ticker.start() asserts the ticker is idle; anchor() re-runs on every
    // player report while playing (~5×/s) and must not double-start it.
    final ticker = _ticker ??= _vsync.createTicker(_onTick);
    if (!ticker.isActive) ticker.start();
    onAdvancingChanged(true);
  }

  /// Stops advancing the play time. Safe to call when already stopped.
  void stop() {
    _stopwatch.stop();
    if (_ticker?.isActive ?? false) _ticker!.stop();
    onAdvancingChanged(false);
  }

  /// Releases the ticker. The instance cannot be reused afterwards.
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration _) {
    onTick(
      interpolatePlayheadPosition(
        anchor: _anchor,
        elapsed: _stopwatch.elapsed,
        speed: _speed,
        maxDuration: _maxDuration,
        wrap: _wrap,
      ),
    );
  }
}
