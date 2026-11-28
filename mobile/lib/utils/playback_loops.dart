// ABOUTME: How many loops a stretch of playback is worth, with a floor on the
// ABOUTME: loop length so a clip under a second adds at most one loop a second.

/// Shortest playback counted as one loop.
///
/// A clip shorter than this wraps several times a second, so its loops are
/// counted at most once per this much playback, on screen and in every
/// report. A single-frame clip would otherwise add about 15 loops for every
/// second it is watched.
const minimumLoopDuration = Duration(seconds: 1);

/// Loops in [watched] playback of a clip [clipLength] long.
///
/// A clip shorter than [minimumLoopDuration] counts as that long, so the
/// result never exceeds one loop per second watched.
double loopsInPlayback({
  required Duration watched,
  required Duration clipLength,
}) {
  final loopLength = clipLength < minimumLoopDuration
      ? minimumLoopDuration
      : clipLength;
  return watched.inMilliseconds / loopLength.inMilliseconds;
}
