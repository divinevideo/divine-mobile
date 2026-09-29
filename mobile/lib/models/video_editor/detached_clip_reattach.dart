// ABOUTME: Turns a clip detached onto the canvas back into a timeline clip —
// ABOUTME: which stretch of it comes back, and where on the timeline it lands

import 'package:openvine/models/divine_video_clip.dart';

/// [clip] trimmed to the stretch its canvas layer shows.
///
/// A layer plays the clip from [sourceOffset] — non-zero for the tail of a
/// split — for as long as its bar runs, [window], or to the clip's end when
/// the bar reaches past it. That stretch is what goes back onto the timeline,
/// as trim: the rest of the footage stays in the file, so the trim handles can
/// pull it back out.
///
/// [sourceOffset] and [window] are playback time, like the layer carrying
/// them, while trim is source time, so both go through the clip's speed. A
/// `null` [window] means the layer runs to the clip's end.
DivineVideoClip detachedClipTrimmedToLayer({
  required DivineVideoClip clip,
  Duration sourceOffset = Duration.zero,
  Duration? window,
}) {
  final offset = sourceOffset > Duration.zero ? sourceOffset : Duration.zero;
  final remaining = clip.playbackDuration - offset;
  // Only a corrupt offset gets here; a zero-length clip would put an empty
  // slot on the timeline, so the whole clip comes back instead.
  if (remaining <= Duration.zero) return clip;

  final shown = window != null && window > Duration.zero && window < remaining
      ? window
      : remaining;
  final runsToEnd = shown == remaining;
  if (offset == Duration.zero && runsToEnd) return clip;

  final trimStart =
      clip.trimStart + clip.playbackDurationToSourceDuration(offset);
  // Running to the end keeps the clip's own trim exactly, rather than a value
  // recomputed through the speed conversion and off by a rounding step.
  final trimEnd = runsToEnd
      ? clip.trimEnd
      : clip.duration -
            trimStart -
            clip.playbackDurationToSourceDuration(shown);
  return clip.copyWith(
    trimStart: trimStart,
    trimEnd: trimEnd < clip.trimEnd ? clip.trimEnd : trimEnd,
  );
}

/// Where a clip put back at [playhead] joins [clips].
///
/// On a seam it goes in at that seam. Inside a clip it goes in right after
/// that clip, so the clip under the playhead is never cut in two — the rule
/// stills captured into a stop-motion clip follow too. Past the end it
/// follows the last clip.
int reattachInsertIndex(List<DivineVideoClip> clips, Duration playhead) {
  var clipStart = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    if (playhead <= clipStart) return i;
    final clipEnd = clipStart + clips[i].playbackDuration;
    if (playhead < clipEnd) return i + 1;
    clipStart = clipEnd;
  }
  return clips.length;
}
