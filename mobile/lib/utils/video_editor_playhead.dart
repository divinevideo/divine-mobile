// ABOUTME: Playhead position math for the video editor timeline
// ABOUTME: Interpolates between coarse player reports and loops stop-motion

import 'package:openvine/constants/video_editor_constants.dart';

/// Interpolates a composite playback position forward from [anchor] by the
/// wall-clock [elapsed] since the anchor was captured, scaled by playback
/// [speed], and clamped to `[Duration.zero, maxDuration]`.
///
/// Drives the layer overlay's play time at display refresh rate between the
/// native player's coarse (~5 Hz) position reports so enter/leave animations
/// animate smoothly during playback instead of stepping.
///
/// With [wrap] the position wraps around [maxDuration] instead of stopping
/// there, the way a looping player does. Parking at the end is harmless on a
/// loop of several seconds, where the next report lands within a fraction of
/// a percent of it, but on a loop of a few frames it is most of the loop.
Duration interpolatePlayheadPosition({
  required Duration anchor,
  required Duration elapsed,
  required double speed,
  required Duration maxDuration,
  bool wrap = false,
}) {
  final raw = anchor + elapsed * speed;
  if (raw < Duration.zero) return Duration.zero;
  if (raw > maxDuration) {
    if (!wrap || maxDuration <= Duration.zero) return maxDuration;
    return Duration(
      microseconds: raw.inMicroseconds % maxDuration.inMicroseconds,
    );
  }
  return raw;
}

/// Advances the frames-only stop-motion playhead forward from [anchor] by the
/// wall-clock [elapsed], wrapping around [total] so playback loops seamlessly.
///
/// A frames-only stop-motion clip has no native player to report position, so
/// this drives the editor timeline directly. Returns [Duration.zero] when
/// [total] is non-positive.
Duration stopMotionLoopPosition({
  required Duration anchor,
  required Duration elapsed,
  required Duration total,
}) {
  if (total <= Duration.zero) return Duration.zero;
  final raw = (anchor + elapsed).inMicroseconds;
  return Duration(microseconds: raw % total.inMicroseconds);
}

/// Whether a display-rate playhead ticker should push [next] into the
/// timeline, given the [last] position it pushed and the throttle
/// [interval].
///
/// A step forward shorter than the interval is skipped; a step backwards is
/// always pushed, because it is the loop wrapping and the timeline has to
/// follow it back to the start.
bool playheadEmitDue({
  required Duration last,
  required Duration next,
  required Duration interval,
}) {
  final advanced = next - last;
  return advanced < Duration.zero || advanced >= interval;
}

/// Whether a composition of [duration] is too short a loop for the native
/// player's position reports to describe, so the timeline follows the
/// playhead ticker instead and jumps to each position rather than gliding.
///
/// The one predicate behind both decisions, so the canvas and the timeline
/// can never disagree about which loops are short. The canvas derives it from
/// the native player's composite duration and carries the result to the
/// timeline.
bool isShortLoop(Duration duration) =>
    duration < VideoEditorConstants.shortLoopThreshold;
