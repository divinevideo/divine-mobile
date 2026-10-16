// ABOUTME: The clip a layer follows an object in: its footage, the stretch of
// ABOUTME: the timeline to track, and the clock between timeline and file.

import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// The clip under a layer that an object is tracked in, and the stretch of
/// the editor timeline the layer follows it for (#9848).
///
/// Tracking reads one clip's footage: a cut to the next clip shows something
/// else, so the layer follows the object to the clip's edge at most. Times
/// named `start`, `end` and `anchor` are on the editor timeline, the axis the
/// playhead and a layer's keyframes share; [sourceTimeAt] and [editorTimeAt]
/// map them onto the clip's file and back.
@immutable
class LayerTrackTarget {
  /// Creates a [LayerTrackTarget].
  const LayerTrackTarget({
    required this.clipId,
    required this.video,
    required this.clipStart,
    required this.trimStart,
    required this.speed,
    required this.start,
    required this.end,
    required this.anchor,
    required this.videoAspectRatio,
    required this.targetAspectRatio,
  });

  /// The id of the clip the object is tracked in.
  final String clipId;

  /// The clip's footage, as the preview plays it.
  final EditorVideo video;

  /// Where the clip starts on the editor timeline.
  final Duration clipStart;

  /// Where the clip's visible part starts in its file.
  final Duration trimStart;

  /// How much faster than the file the clip plays.
  final double speed;

  /// The first moment the layer follows the object.
  final Duration start;

  /// The last moment the layer follows the object.
  final Duration end;

  /// The moment the object is marked at: the frame on screen when tracking
  /// started.
  final Duration anchor;

  /// Width over height of the frames in [video].
  final double videoAspectRatio;

  /// Width over height of the part of every frame the video keeps.
  final double targetAspectRatio;

  /// The position in the clip's file shown at [editorTime].
  Duration sourceTimeAt(Duration editorTime) =>
      trimStart +
      Duration(
        microseconds: ((editorTime - clipStart).inMicroseconds * speed).round(),
      );

  /// When the frame at [sourceTime] in the clip's file shows on the editor
  /// timeline.
  Duration editorTimeAt(Duration sourceTime) =>
      clipStart +
      Duration(
        microseconds: ((sourceTime - trimStart).inMicroseconds / speed).round(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerTrackTarget &&
          other.clipId == clipId &&
          other.video == video &&
          other.clipStart == clipStart &&
          other.trimStart == trimStart &&
          other.speed == speed &&
          other.start == start &&
          other.end == end &&
          other.anchor == anchor &&
          other.videoAspectRatio == videoAspectRatio &&
          other.targetAspectRatio == targetAspectRatio;

  @override
  int get hashCode => Object.hash(
    clipId,
    video,
    clipStart,
    trimStart,
    speed,
    start,
    end,
    anchor,
    videoAspectRatio,
    targetAspectRatio,
  );
}

/// The [LayerTrackTarget] for a layer showing from [layerStart] to
/// [layerEnd] on the timeline of [clips], marked at [anchor].
///
/// The clip under [anchor] is the one tracked, from wherever the layer and
/// that clip both show to wherever either ends. Returns `null` when there is
/// nothing to follow there: no clip, one still rendering or without a video
/// file (stop motion), a freeze frame or the still that holds a detached
/// clip's slot, which never move.
LayerTrackTarget? layerTrackTargetFor({
  required List<DivineVideoClip> clips,
  required Duration anchor,
  required Duration layerStart,
  required Duration layerEnd,
}) {
  var cursor = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final clipEnd = cursor + clip.playbackDuration;
    final isLast = i == clips.length - 1;
    if (anchor < clipEnd || isLast) {
      final video = clip.video;
      if (video == null ||
          clip.isProcessing ||
          clip.isFreezeFrame ||
          clip.isPlaceholder ||
          clip.playbackDuration <= Duration.zero) {
        return null;
      }
      final start = layerStart > cursor ? layerStart : cursor;
      final end = layerEnd < clipEnd ? layerEnd : clipEnd;
      if (end <= start) return null;
      final speed = clip.playbackSpeed ?? 1.0;
      return LayerTrackTarget(
        clipId: clip.id,
        video: video,
        clipStart: cursor,
        trimStart: clip.trimStart,
        speed: speed > 0 ? speed : 1.0,
        start: start,
        end: end,
        anchor: anchor < start ? start : (anchor > end ? end : anchor),
        videoAspectRatio: clip.videoAspectRatio,
        targetAspectRatio: clip.targetAspectRatio.value,
      );
    }
    cursor = clipEnd;
  }
  return null;
}
