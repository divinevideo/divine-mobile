import 'package:models/models.dart' show AudioEvent;
import 'package:pro_video_editor/pro_video_editor.dart' show VideoSpeedRamp;

/// The speed a sound plays at, and where each moment of it lands on the
/// timeline: at [AudioEvent.playbackSpeed], or along [speedRamp].
///
/// A ramp is spread over the track's whole window — the stretch of the sound
/// from [AudioEvent.startOffset] that plays from [AudioEvent.startTime] to
/// [AudioEvent.endTime] — the way a clip's ramp is spread over its trim, and
/// the export plays it the same way. Lengthening or shortening the window
/// spreads the ramp over the new one; only a split cuts it.
extension AudioEventSpeed on AudioEvent {
  static final _ramps = Expando<VideoSpeedRamp>('AudioEvent.speedRamp');

  /// The ramp the sound plays along, or `null` at one constant speed.
  ///
  /// Read once per stored map, so painting and dragging do not parse it again.
  VideoSpeedRamp? get speedRamp {
    final map = speedRampMap;
    if (map == null) return null;
    return _ramps[map] ??= VideoSpeedRamp.fromMap(map);
  }

  /// This track along [ramp], or at one constant speed with `null`.
  AudioEvent withSpeedRamp(VideoSpeedRamp? ramp) => ramp == null
      ? copyWith(playbackSpeed: 1)
      : copyWith(speedRampMap: ramp.toMap());

  /// Whether the sound plays at anything other than its own speed.
  bool get changesSpeed => speedRamp != null || playbackSpeed != 1;

  /// The constant speed that plays the window in the same time.
  double get averageSpeed => speedRamp?.averageSpeed ?? playbackSpeed;

  /// How much of the sound a window lasting [timeline] plays.
  Duration sourceSpanOf(Duration timeline) => _scaled(timeline, averageSpeed);

  /// How long a window lasts on the timeline that plays [source] of the sound.
  Duration timelineSpanOf(Duration source) => _scaled(source, 1 / averageSpeed);

  /// The stretch of the sound the window plays from [AudioEvent.startOffset],
  /// or `null` when it runs to the sound's end and that is unknown.
  Duration? get playedSourceSpan {
    final end = endTime;
    if (end != null) {
      return end <= startTime ? Duration.zero : sourceSpanOf(end - startTime);
    }
    final seconds = duration;
    if (seconds == null || seconds <= 0) return null;
    final remaining =
        Duration(milliseconds: (seconds * 1000).round()) - startOffset;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// How far into the sound, from [AudioEvent.startOffset], the track has
  /// played [timelineOffset] after [AudioEvent.startTime].
  ///
  /// An offset outside the window plays at the speed of the ramp's nearest
  /// end, as a clip's does.
  Duration sourceOffsetAt(Duration timelineOffset) {
    final ramp = speedRamp;
    final span = playedSourceSpan;
    if (ramp == null || span == null || span <= Duration.zero) {
      return sourceSpanOf(timelineOffset);
    }
    final played = ramp.outputDuration(span);
    if (timelineOffset.isNegative) {
      return _scaled(timelineOffset, ramp.points.first.speed);
    }
    if (timelineOffset > played) {
      return span + _scaled(timelineOffset - played, ramp.points.last.speed);
    }
    return ramp.outputToSource(timelineOffset, sourceDuration: span);
  }

  /// Where [sourceOffset] of the sound, counted from
  /// [AudioEvent.startOffset], plays on the timeline from
  /// [AudioEvent.startTime]; the inverse of [sourceOffsetAt].
  Duration timelineOffsetOf(Duration sourceOffset) {
    final ramp = speedRamp;
    final span = playedSourceSpan;
    if (ramp == null || span == null || span <= Duration.zero) {
      return timelineSpanOf(sourceOffset);
    }
    if (sourceOffset.isNegative) {
      return _scaled(sourceOffset, 1 / ramp.points.first.speed);
    }
    if (sourceOffset > span) {
      return ramp.outputDuration(span) +
          _scaled(sourceOffset - span, 1 / ramp.points.last.speed);
    }
    return ramp.sourceToOutput(sourceOffset, sourceDuration: span);
  }

  /// The speed the window plays at [sourceOffset] of the sound, counted
  /// from [AudioEvent.startOffset]: the step of [speedRamp] the render plays
  /// there, or [AudioEvent.playbackSpeed].
  double speedAtSourceOffset(Duration sourceOffset) {
    final ramp = speedRamp;
    final span = playedSourceSpan;
    if (ramp == null || span == null || span <= Duration.zero) {
      return playbackSpeed;
    }
    final position = sourceOffset.inMicroseconds / span.inMicroseconds;
    for (final step in ramp.steps) {
      if (position < step.end) return step.speed;
    }
    return ramp.steps.last.speed;
  }

  /// The ramp of the part of the window from [from] to [to] of the sound,
  /// both counted from [AudioEvent.startOffset]: what a track cut down to
  /// that part plays, so each moment keeps its speed. `null` without a ramp.
  VideoSpeedRamp? speedRampBetween(Duration from, Duration to) {
    final ramp = speedRamp;
    final span = playedSourceSpan?.inMicroseconds ?? 0;
    if (ramp == null || span <= 0) return ramp;
    final start = (from.inMicroseconds / span).clamp(0.0, 1.0);
    final end = (to.inMicroseconds / span).clamp(0.0, 1.0);
    if (end <= start) return ramp;
    return ramp.cropped(start, end);
  }

  static Duration _scaled(Duration duration, double factor) =>
      Duration(microseconds: (duration.inMicroseconds * factor).round());
}
