// ABOUTME: Where a freshly detached clip's layer sits on the timeline, kept
// ABOUTME: inside the composition so the layer never lands past its end

import 'dart:math' as math;

/// The time window a clip's layer gets the moment it is detached.
///
/// [slotStart] is where the clip sat on the timeline, [playbackDuration] how
/// long it plays, and [compositionDuration] how long the timeline is *after*
/// the detach. With a placeholder left in the slot the timeline keeps its
/// length and the window is simply the slot. With the slot closed the
/// timeline shrank by the clip's own length, so a clip from the tail end would
/// start at — or past — the new end and never be on screen: the last clip
/// vanished into a window nothing plays. The window is pulled back so it ends
/// on the composition's end instead, overlapping whatever now sits there,
/// which is the closest the layer can get to where the clip was.
///
/// A composition shorter than the clip cuts the window to the composition;
/// the export cuts the clip to its window in turn.
({Duration start, Duration end}) detachedClipWindow({
  required Duration slotStart,
  required Duration playbackDuration,
  required Duration compositionDuration,
}) {
  final latestStart = compositionDuration - playbackDuration;
  final start = Duration(
    microseconds: math.max(
      0,
      math.min(slotStart.inMicroseconds, latestStart.inMicroseconds),
    ),
  );
  final end = Duration(
    microseconds: math.min(
      (start + playbackDuration).inMicroseconds,
      compositionDuration.inMicroseconds,
    ),
  );
  return (start: start, end: end);
}
