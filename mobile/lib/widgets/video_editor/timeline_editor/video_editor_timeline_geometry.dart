// ABOUTME: Pure geometry helpers for the video editor timeline.
// ABOUTME: Converts between playback positions and scroll offsets,
// ABOUTME: accounting for the 1-px gap between adjacent clip strips.

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';

/// Converts a [sourcePosition] inside one untrimmed clip to the matching
/// composite playback position on the full timeline.
///
/// Clip trim previews seek the native player in source time because the
/// preview player is temporarily switched to a single untrimmed clip.
/// Visual overlays, however, are keyed by composite timeline time. This helper
/// bridges those coordinate spaces while respecting clip trims and speed.
Duration? clipSourcePositionToTimelinePosition(
  List<DivineVideoClip> clips, {
  required String clipId,
  required Duration sourcePosition,
}) {
  var precedingDuration = Duration.zero;
  for (final clip in clips) {
    if (clip.id == clipId) {
      final relative = sourcePosition - clip.trimStart;
      if (relative < Duration.zero || relative > clip.trimmedDuration) {
        return null;
      }

      final speed = clip.playbackSpeed ?? 1.0;
      final relativePlayback = speed <= 0 || speed == 1.0
          ? relative
          : Duration(microseconds: (relative.inMicroseconds / speed).round());
      return precedingDuration + relativePlayback;
    }

    precedingDuration += clip.playbackDuration;
  }

  return null;
}

/// Returns the source offset and anchor state for an audio track after its
/// timeline start handle moves to [newStartTime].
///
/// Left-trimming a sound should consume or reveal audio source content rather
/// than sliding the same source frame to a new timeline position. Keeping this
/// offset in step with the timeline start also preserves the anchored-audio
/// alignment invariant used by [rebaseAnchoredAudioForClipState].
AudioLeftTrimResult audioLeftTrimResult(
  AudioEvent track, {
  required Duration newStartTime,
}) {
  final nextOffset = track.startOffset + (newStartTime - track.startTime);
  if (nextOffset < Duration.zero) {
    return const AudioLeftTrimResult(
      startOffset: Duration.zero,
      anchorStillValid: false,
    );
  }

  final duration = track.duration;
  if (duration == null) {
    return AudioLeftTrimResult(startOffset: nextOffset);
  }

  final maxOffset = Duration(milliseconds: (duration * 1000).round());
  if (nextOffset > maxOffset) {
    return AudioLeftTrimResult(startOffset: maxOffset, anchorStillValid: false);
  }
  return AudioLeftTrimResult(startOffset: nextOffset);
}

/// Result of applying a left trim to an audio track's source offset.
class AudioLeftTrimResult {
  const AudioLeftTrimResult({
    required this.startOffset,
    this.anchorStillValid = true,
  });

  /// Source offset to apply to the track.
  final Duration startOffset;

  /// Whether the requested timeline start can still be represented by the
  /// anchored-audio alignment invariant.
  final bool anchorStillValid;
}

/// Reprojects marker positions after clip order, trim, or speed changes.
///
/// Timeline markers are stored as absolute composition times because the
/// ruler, snapping, and painter all operate in timeline coordinates. The user
/// experience is clip-source based, though: a marker placed on source second 5
/// of clip B should follow clip B when reordered, and disappear if source
/// second 5 is trimmed out. This converts:
///
///   old absolute time -> old clip id + source position -> new absolute time
List<Duration> rebaseTimelineMarkersForClipState({
  required List<DivineVideoClip> oldClips,
  required List<DivineVideoClip> newClips,
  required List<Duration> markers,
}) {
  if (markers.isEmpty || oldClips.isEmpty || newClips.isEmpty) {
    return const [];
  }

  final newClipStarts = <String, Duration>{};
  final newClipsById = <String, DivineVideoClip>{};
  var newCursor = Duration.zero;
  for (final clip in newClips) {
    newClipStarts[clip.id] = newCursor;
    newClipsById[clip.id] = clip;
    newCursor += clip.playbackDuration;
  }

  final rebased = <Duration>{};
  for (final marker in markers) {
    final anchor = _timelineMarkerAnchorForPosition(oldClips, marker);
    if (anchor == null) continue;

    final newStart = newClipStarts[anchor.clipId];
    final newClip = newClipsById[anchor.clipId];
    if (newStart == null || newClip == null) continue;

    final playbackOffset = _sourcePositionToPlaybackOffset(
      newClip,
      anchor.sourcePosition,
    );
    if (playbackOffset == null) continue;

    rebased.add(newStart + playbackOffset);
  }

  return rebased.toList()..sort();
}

/// Re-aligns anchored (extracted, not-yet-moved) audio tracks to their
/// source clips after a clip edit (trim, reorder, or ripple from an earlier
/// clip's trim).
///
/// For each [AudioEvent] whose [AudioEvent.anchorClipId] still resolves to a
/// clip in [clips], the audio is translated on the timeline so its source
/// content stays aligned with the clip's source content. This implements the
/// J-Cut behaviour: the audio keeps its [AudioEvent.startOffset] and its span
/// (so its full content survives — the head simply leads), while only its
/// [AudioEvent.startTime]/[AudioEvent.endTime] move. If that lead would start
/// before timeline zero, the impossible pre-roll is clipped by advancing
/// [AudioEvent.startOffset] and shortening the audible span.
///
/// The alignment invariant preserved is, for the anchored clip:
///
///   startTime == clipTimelineStart
///       - playbackDuration(clip.trimStart)
///       + audio.startOffset
///
/// `clipTimelineStart` is accumulated in playback time so earlier clip speed
/// changes still ripple anchored audio correctly. [AudioEvent.startOffset] is
/// measured in the extracted audio file's own time, so a source trim offset is
/// converted through the anchor clip's [DivineVideoClip.playbackSpeed].
///
/// Tracks with no anchor, or whose anchor clip was removed or split into new
/// clip IDs, are returned unchanged. The original list instance is returned
/// when nothing moved, so callers can cheaply detect a no-op via `identical`.
List<AudioEvent> rebaseAnchoredAudioForClipState(
  List<DivineVideoClip> clips,
  List<AudioEvent> audioTracks,
) {
  if (audioTracks.isEmpty) return audioTracks;

  final clipStarts = <String, Duration>{};
  final clipsById = <String, DivineVideoClip>{};
  var cursor = Duration.zero;
  for (final clip in clips) {
    clipStarts[clip.id] = cursor;
    clipsById[clip.id] = clip;
    cursor += clip.playbackDuration;
  }

  var changed = false;
  final result = <AudioEvent>[];
  for (final track in audioTracks) {
    final anchorId = track.anchorClipId;
    final clipStart = anchorId == null ? null : clipStarts[anchorId];
    final clip = anchorId == null ? null : clipsById[anchorId];
    if (clipStart == null || clip == null) {
      result.add(track);
      continue;
    }

    final span = (track.endTime ?? track.startTime) - track.startTime;
    final clipTrimStartInAudioTime = clip.sourceDurationToPlaybackDuration(
      clip.trimStart,
    );
    final newStartRaw =
        clipStart + track.startOffset - clipTrimStartInAudioTime;
    var newStart = newStartRaw;
    var newStartOffset = track.startOffset;
    var newSpan = span;

    if (newStartRaw < Duration.zero) {
      final clippedLead = Duration.zero - newStartRaw;
      newStart = Duration.zero;
      newStartOffset += clippedLead;
      newSpan -= clippedLead;
      if (newSpan < Duration.zero) {
        newSpan = Duration.zero;
      }
    }

    final newEnd = track.endTime == null ? null : newStart + newSpan;

    if (newStart == track.startTime &&
        newEnd == track.endTime &&
        newStartOffset == track.startOffset) {
      result.add(track);
      continue;
    }
    changed = true;
    result.add(
      track.copyWith(
        startOffset: newStartOffset,
        startTime: newStart,
        endTime: newEnd,
      ),
    );
  }

  return changed ? result : audioTracks;
}

/// Granularity an audio window survives a history/draft round-trip at.
///
/// [AudioEvent] serializes its window in whole milliseconds while a stop-motion
/// composition is microsecond-accurate (a 1/30s hold is 33334µs), so a window
/// restored from history sits up to a millisecond short of the composition end
/// it was clamped to. Comparisons against the composition end carry that slack.
const _audioWindowResolution = Duration(milliseconds: 1);

/// Stretches audio windows that ran to the end of the composition so they keep
/// covering it after an edit made the composition longer.
///
/// A sound is added with its window clamped to the composition end (see
/// `_openMusicLibrary`). Growing the composition afterwards used to leave that
/// window frozen at the old, shorter end — a stop-motion hold change that
/// stretches nine stills from 0.3s to 6.6s published a 6.6s video muxed with a
/// 0.3s audio track (#6401).
///
/// Only tracks whose window *ended at* [previousDuration] follow the new end.
/// A window the user deliberately trimmed shorter keeps its length, and so does
/// one that overhangs the old end — after a shrink-then-grow (lower the hold,
/// raise it again) a trimmed window sits past the shorter composition, and a
/// one-sided "did it reach the end" test would read that overhang as coverage
/// and silently undo the trim. The cost of the symmetric test is that a window
/// left overhanging a shrunken composition keeps its old end instead of being
/// re-extended; the sound strip's trim handle is the affordance for that.
///
/// The new end is bounded by the audio the track still has left after its
/// [AudioEvent.startOffset] and by [maxDuration], matching the ceiling the
/// track would have been given had the sound been added at the new composition
/// length. Windows are never shortened here — a composition that shrank is
/// clamped for display by the timeline and for output by the render.
///
/// Returns the original list instance when nothing moved.
List<AudioEvent> growAudioToCompositionEnd(
  List<AudioEvent> audioTracks, {
  required Duration previousDuration,
  required Duration duration,
  required Duration maxDuration,
}) {
  if (audioTracks.isEmpty || duration <= previousDuration) return audioTracks;

  final ceiling = duration < maxDuration ? duration : maxDuration;
  var changed = false;
  final result = <AudioEvent>[];
  for (final track in audioTracks) {
    final endTime = track.endTime;
    // No window: the track already plays to its own end, and the render clamps
    // that to the video. A window that ends anywhere but the old composition
    // end — short of it or past it — was placed by the user, not by the clamp.
    if (endTime == null ||
        (endTime - previousDuration).abs() > _audioWindowResolution) {
      result.add(track);
      continue;
    }

    final sourceEnd = _audioSourceEnd(track);
    final newEnd = sourceEnd != null && sourceEnd < ceiling
        ? sourceEnd
        : ceiling;
    if (newEnd <= endTime) {
      result.add(track);
      continue;
    }
    changed = true;
    result.add(track.copyWith(endTime: newEnd));
  }

  return changed ? result : audioTracks;
}

/// Timeline position at which [track] runs out of source audio, or `null` when
/// its source length is unknown.
///
/// A non-positive duration counts as unknown, matching the sound timeline item
/// and the duration-heal path, so a persisted-but-zero duration cannot collapse
/// a window instead of leaving it uncapped.
Duration? _audioSourceEnd(AudioEvent track) {
  final duration = track.duration;
  if (duration == null || duration <= 0) return null;
  final remaining =
      Duration(milliseconds: (duration * 1000).toInt()) - track.startOffset;
  if (remaining <= Duration.zero) return null;
  return track.startTime + remaining;
}

/// The clip under the playhead at the timeline [position], or `null` when
/// [clips] is empty.
///
/// Walks the clips in playback time, the axis the playhead and timeline
/// markers share. A position on a boundary belongs to the clip that starts
/// there; the last clip absorbs anything past the composition end, so a
/// playhead resting on the final frame still resolves.
DivineVideoClip? clipAtTimelinePosition(
  List<DivineVideoClip> clips,
  Duration position,
) {
  var cursor = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final end = cursor + clip.playbackDuration;
    if (position < end || i == clips.length - 1) return clip;
    cursor = end;
  }
  return null;
}

_TimelineMarkerAnchor? _timelineMarkerAnchorForPosition(
  List<DivineVideoClip> clips,
  Duration marker,
) {
  var cursor = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final duration = clip.playbackDuration;
    final end = cursor + duration;
    final isLast = i == clips.length - 1;

    if (marker < end || isLast) {
      return _TimelineMarkerAnchor(
        clip.id,
        _playbackOffsetToSourcePosition(
          clip,
          _clampDuration(marker - cursor, duration),
        ),
      );
    }

    cursor = end;
  }

  return null;
}

Duration _playbackOffsetToSourcePosition(
  DivineVideoClip clip,
  Duration playbackOffset,
) {
  final speed = clip.playbackSpeed ?? 1.0;
  final sourceOffset = speed <= 0 || speed == 1.0
      ? playbackOffset
      : Duration(microseconds: (playbackOffset.inMicroseconds * speed).round());

  return clip.trimStart + _clampDuration(sourceOffset, clip.trimmedDuration);
}

Duration? _sourcePositionToPlaybackOffset(
  DivineVideoClip clip,
  Duration sourcePosition,
) {
  final visibleStart = clip.trimStart;
  final visibleEnd = clip.duration - clip.trimEnd;
  if (sourcePosition < visibleStart || sourcePosition > visibleEnd) {
    return null;
  }

  final sourceOffset = sourcePosition - visibleStart;
  final speed = clip.playbackSpeed ?? 1.0;
  if (speed <= 0 || speed == 1.0) return sourceOffset;

  return Duration(microseconds: (sourceOffset.inMicroseconds / speed).round());
}

Duration _clampDuration(Duration value, Duration max) {
  if (value < Duration.zero) return Duration.zero;
  if (value > max) return max;
  return value;
}

class _TimelineMarkerAnchor {
  const _TimelineMarkerAnchor(this.clipId, this.sourcePosition);

  final String clipId;
  final Duration sourcePosition;
}

/// Converts a composite playback [position] to the corresponding scroll
/// offset in the timeline content, accounting for the
/// [TimelineConstants.clipGap]-wide gap between adjacent clip strips.
///
/// Without this correction the scroll target is up to
/// `(clipsPassedCount × clipGap)` pixels short of the trim-handle
/// marker's actual visual position.
/// A loop transition draws the first/last clips shortened by the wrap-consumed
/// head/tail (see [LoopWrapDisplay]), so the strip's clip boundaries — and the
/// [TimelineConstants.clipGap]s at them — sit on the display axis. [position] is
/// already a display-axis position (the playhead comes from
/// `SeamTimeline.compositeToTimeline`), so pass [wrap] to count gaps at the
/// display boundaries; otherwise the boundaries fall on the raw-duration axis
/// and the playhead drifts from the strip by a gap width near each boundary.
double timelinePositionToScrollOffset(
  List<DivineVideoClip> clips,
  Duration position,
  double pixelsPerSecond, {
  LoopWrapDisplay wrap = LoopWrapDisplay.none,
}) {
  var acc = Duration.zero;
  var gapPixels = 0.0;
  for (var i = 0; i < clips.length; i++) {
    final display = wrap.displayDuration(
      clips[i],
      isFirst: i == 0,
      isLast: i == clips.length - 1,
    );
    if (acc + display > position) break;
    acc += display;
    if (i < clips.length - 1) {
      gapPixels += TimelineConstants.clipGap;
    }
  }
  return position.inMicroseconds / 1_000_000.0 * pixelsPerSecond + gapPixels;
}

/// Converts a timeline [scrollOffset] to the corresponding playback
/// position — the exact inverse of [timelinePositionToScrollOffset].
///
/// The result is clamped to `[Duration.zero, totalDuration]`.
/// Pass [wrap] so the clip boundaries (and their gaps) are measured on the
/// display axis the strip draws — the returned position is then a display-axis
/// position, matching what [timelinePositionToScrollOffset] expects and what
/// `SeamTimeline` produces. Without a loop transition [wrap] is
/// [LoopWrapDisplay.none] and the mapping is the plain raw-duration one.
Duration timelineScrollOffsetToPosition(
  List<DivineVideoClip> clips,
  double scrollOffset,
  double pixelsPerSecond,
  Duration totalDuration, {
  LoopWrapDisplay wrap = LoopWrapDisplay.none,
}) {
  var acc = Duration.zero;
  var gapPixels = 0.0;
  for (var i = 0; i < clips.length; i++) {
    final display = wrap.displayDuration(
      clips[i],
      isFirst: i == 0,
      isLast: i == clips.length - 1,
    );
    final clipEndPx =
        (acc + display).inMicroseconds / 1_000_000.0 * pixelsPerSecond +
        gapPixels;
    if (scrollOffset <= clipEndPx) break;
    final gapEndPx = clipEndPx + TimelineConstants.clipGap;
    if (i < clips.length - 1 && scrollOffset < gapEndPx) {
      return acc + display;
    }
    acc += display;
    if (i < clips.length - 1) {
      gapPixels += TimelineConstants.clipGap;
    }
  }
  final seconds = (scrollOffset - gapPixels) / pixelsPerSecond;
  final ms = (seconds * 1000).round().clamp(0, totalDuration.inMilliseconds);
  return Duration(milliseconds: ms);
}

/// Converts an overlay-item edge at [positionMs] to its pixel offset in
/// the overlay layer, accounting for the [TimelineConstants.clipGap]
/// between adjacent clips.
///
/// Overlay strips share the clip strip's coordinate space, so an edge
/// must include the cumulative gap pixels of every clip boundary at or
/// before [positionMs]. Without this correction an overlay drifts left
/// of the matching clip end by `(clipsPassed × clipGap)` px — a drift
/// that grows with the number of clips, so layers can never be snapped
/// exactly to a clip end on a busy timeline.
///
/// [clipEdgesMs] is the cumulative clip-boundary list `[0, e1, …, eN]`
/// (gap-free milliseconds), matching `_computeEdges` in the timeline
/// body. This is the edge-based counterpart of
/// [timelinePositionToScrollOffset] and shares its boundary convention:
/// a position exactly on a clip boundary maps to the start of the next
/// clip (the gap is included).
double timelineMsToOverlayOffset(
  List<int> clipEdgesMs,
  int positionMs,
  double pixelsPerSecond,
) {
  var gapPixels = 0.0;
  // clipEdgesMs[i] is the end of clip (i-1). A gap follows every clip
  // except the last, i.e. internal boundaries e1…e(N-1).
  for (var i = 1; i < clipEdgesMs.length - 1; i++) {
    if (clipEdgesMs[i] > positionMs) break;
    gapPixels += TimelineConstants.clipGap;
  }
  return positionMs / 1000.0 * pixelsPerSecond + gapPixels;
}

/// Converts an overlay-layer pixel [offset] back to milliseconds — the
/// exact inverse of [timelineMsToOverlayOffset].
///
/// Offsets that fall inside a clip gap clamp to the preceding clip
/// boundary. The result is clamped to `[0, totalDurationMs]`.
int timelineOverlayOffsetToMs(
  List<int> clipEdgesMs,
  double offset,
  double pixelsPerSecond,
  int totalDurationMs,
) {
  var gapPixels = 0.0;
  for (var i = 1; i < clipEdgesMs.length; i++) {
    final clipEndPx = clipEdgesMs[i] / 1000.0 * pixelsPerSecond + gapPixels;
    if (offset <= clipEndPx) break;
    final isInternal = i < clipEdgesMs.length - 1;
    if (isInternal && offset < clipEndPx + TimelineConstants.clipGap) {
      return clipEdgesMs[i];
    }
    if (isInternal) gapPixels += TimelineConstants.clipGap;
  }
  final ms = ((offset - gapPixels) / pixelsPerSecond * 1000).round();
  return ms.clamp(0, totalDurationMs);
}

/// Initial timeline zoom for a frames-first stop-motion session.
///
/// Stop-motion stills are held for a handful of output frames (tens of ms),
/// so the video default of [TimelineConstants.pixelsPerSecond] renders them a
/// couple of pixels wide. This scales the zoom so the *average* still gets
/// [TimelineConstants.stopMotionTargetTileWidth] of tappable width, clamped
/// between the video default and the stop-motion zoom ceiling.
double stopMotionInitialPixelsPerSecond(List<StopMotionClipFrame> frames) {
  if (frames.isEmpty) return TimelineConstants.pixelsPerSecond;
  final total = frames.fold(
    Duration.zero,
    (sum, frame) => sum + frame.duration,
  );
  if (total <= Duration.zero) return TimelineConstants.pixelsPerSecond;
  final averageSeconds =
      total.inMicroseconds / frames.length / Duration.microsecondsPerSecond;
  return (TimelineConstants.stopMotionTargetTileWidth / averageSeconds).clamp(
    TimelineConstants.pixelsPerSecond,
    TimelineConstants.stopMotionMaxPixelsPerSecond,
  );
}
