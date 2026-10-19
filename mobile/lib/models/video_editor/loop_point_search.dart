// ABOUTME: Where the loop helper looks for a better end of the last clip, and
// ABOUTME: the trim that ends the clip there (#10249).

import 'package:equatable/equatable.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// Where to look for a cut that lets the video loop without a visible jump.
///
/// A video's seam sits between the last frame of its last clip and the first
/// frame of its first clip. Only the end of the last clip moves: earlier,
/// within the last [VideoEditorConstants.loopPointSearchBack], or later, into
/// footage trimmed off before, as far as the video may be long. All times are
/// source times in the clip's own file.
class LoopPointSearch extends Equatable {
  const LoopPointSearch({
    required this.clipId,
    required this.endVideo,
    required this.start,
    required this.end,
    required this.endFrom,
    required this.endTo,
    this.startVideo,
  });

  /// The last clip, whose end the search moves.
  final String clipId;

  /// The last clip's footage.
  final EditorVideo endVideo;

  /// The first clip's footage when the video has more than one clip; `null`
  /// when the loop starts and ends in [endVideo].
  final EditorVideo? startVideo;

  /// The first frame of the video, in the first clip's footage.
  final Duration start;

  /// Where the video ends now, in the last clip's footage: where its loop
  /// starts over.
  final Duration end;

  /// The earliest end the search may suggest.
  final Duration endFrom;

  /// The latest end the search may suggest.
  final Duration endTo;

  @override
  List<Object?> get props => [
    clipId,
    endVideo,
    startVideo,
    start,
    end,
    endFrom,
    endTo,
  ];
}

/// Where the loop helper looks for a better end of [clips]' last clip, or
/// `null` when it has nothing to compare: the first or last clip has no
/// footage of its own (a stop-motion sequence), or the last clip is a still,
/// whose frames all look alike.
///
/// The loop keeps at least [VideoEditorConstants.loopPointMinLoop], the last
/// clip at least [TimelineConstants.minTrimDuration], and the video no more
/// than [VideoEditorConstants.maxDuration]: an export stops there, so a
/// video that runs longer starts over at that point already.
LoopPointSearch? loopPointSearchFor(List<DivineVideoClip> clips) {
  if (clips.isEmpty) return null;
  final first = clips.first;
  final last = clips.last;
  final endVideo = last.video;
  final startVideo = first.video;
  if (endVideo == null || startVideo == null) return null;
  if (last.isFreezeFrame || last.isPlaceholder) return null;

  final output = TransitionTimelineMap.fromClips(clips).outputDuration;
  final visibleStart = last.trimStart;
  final visibleEnd = last.duration - last.trimEnd;
  // What the video may still grow by, as footage of the last clip; less
  // than nothing when it already runs past the longest export.
  final headroom = last.playbackDurationToSourceDuration(
    VideoEditorConstants.maxDuration - output,
  );
  final end = _min(visibleEnd, visibleEnd + headroom);
  final endTo = _min(last.duration, visibleEnd + headroom);

  final others = output - last.playbackDuration;
  final shortestLast = last.playbackDurationToSourceDuration(
    VideoEditorConstants.loopPointMinLoop - others,
  );
  final shortestEnd =
      visibleStart + _max(TimelineConstants.minTrimDuration, shortestLast);
  final loop = _min(output, VideoEditorConstants.maxDuration);
  final searchBack = last.playbackDurationToSourceDuration(
    _min(VideoEditorConstants.loopPointSearchBack, loop ~/ 2),
  );
  final endFrom = _max(shortestEnd, end - searchBack);
  if (end <= visibleStart || endTo < endFrom) return null;

  return LoopPointSearch(
    clipId: last.id,
    endVideo: endVideo,
    startVideo: clips.length == 1 ? null : startVideo,
    start: first.trimStart,
    end: end,
    endFrom: endFrom,
    endTo: endTo,
  );
}

/// [clip] trimmed to end right before [end] of its footage.
///
/// A clip is stored with whole-millisecond trims, so the trim is rounded up
/// to one: rounded down when the editor saves it, the end would move past
/// [end] and show that frame again.
DivineVideoClip clipEndingAt(DivineVideoClip clip, Duration end) {
  final trimEnd = clip.duration - end;
  if (trimEnd <= Duration.zero) return clip.copyWith(trimEnd: Duration.zero);
  const perMillisecond = Duration.microsecondsPerMillisecond;
  return clip.copyWith(
    trimEnd: Duration(
      milliseconds:
          (trimEnd.inMicroseconds + perMillisecond - 1) ~/ perMillisecond,
    ),
  );
}

Duration _min(Duration a, Duration b) => a < b ? a : b;

Duration _max(Duration a, Duration b) => a > b ? a : b;
