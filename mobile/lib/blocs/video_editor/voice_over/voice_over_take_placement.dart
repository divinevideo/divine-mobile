// ABOUTME: Pure placement math for laying recorded voice-over takes onto the
// ABOUTME: editor timeline back-to-back, wrapping and clamping to the clip,
// ABOUTME: plus the available-duration and prior-take-count inputs it consumes.

import 'package:models/models.dart' show AudioEvent;

/// Resolves the timeline length available for laying out voice-over takes.
///
/// Uses the clip's own [clipDuration] when it is positive and shorter than
/// [maxDuration]; otherwise falls back to [maxDuration]. This keeps takes laid
/// out against the real clip length without ever exceeding the editor's cap
/// (a zero/negative or over-cap clip duration is treated as "use the cap").
Duration resolveVoiceOverAvailableDuration({
  required Duration clipDuration,
  required Duration maxDuration,
}) {
  return clipDuration > Duration.zero && clipDuration < maxDuration
      ? clipDuration
      : maxDuration;
}

/// Counts the voice-over takes already present in [audioTracks].
///
/// Used to continue the "Recording N" numbering across re-opens instead of
/// restarting at 1. Matches tracks whose id starts with [voiceOverIdPrefix].
int countPriorVoiceOverTakes({
  required Iterable<AudioEvent> audioTracks,
  required String voiceOverIdPrefix,
}) {
  return audioTracks.where((t) => t.id.startsWith(voiceOverIdPrefix)).length;
}

/// Lays [takes] back-to-back onto a timeline of length [availableDuration].
///
/// Each take starts where the previous one ended. Once the cursor reaches the
/// end of the video it wraps back to zero so later takes stay visible (and
/// editable) instead of landing off the end. Every window is clamped to
/// [availableDuration], and zero-width windows — a take with no resolved
/// duration, or one that lands exactly on the end — are skipped. Returned
/// events carry a unique id derived from [nowMs] and the take index so
/// multiple takes never collide on the timeline.
///
/// [takeDurationsSecs] must be parallel to [takes]; each entry is the take's
/// real on-disk duration in seconds.
List<AudioEvent> placeVoiceOverTakes({
  required List<AudioEvent> takes,
  required List<double> takeDurationsSecs,
  required Duration availableDuration,
  required int nowMs,
}) {
  assert(
    takes.length == takeDurationsSecs.length,
    'takeDurationsSecs must be parallel to takes',
  );
  final placed = <AudioEvent>[];
  var cursor = Duration.zero;
  for (var i = 0; i < takes.length; i++) {
    final take = takes[i];
    final secs = takeDurationsSecs[i];
    final takeDuration = Duration(milliseconds: (secs * 1000).round());
    // When the previous take already filled the video, restart at the
    // beginning so this take stays visible within the timeline instead of
    // landing off the end (where it couldn't be seen or edited).
    final start = cursor < availableDuration ? cursor : Duration.zero;
    final endTime = start + takeDuration < availableDuration
        ? start + takeDuration
        : availableDuration;
    if (endTime <= start) continue;
    placed.add(
      take.copyWith(
        id: '${take.id}-$nowMs-$i',
        startTime: start,
        endTime: endTime,
        duration: secs > 0 ? secs : null,
      ),
    );
    cursor = endTime;
  }
  return placed;
}
