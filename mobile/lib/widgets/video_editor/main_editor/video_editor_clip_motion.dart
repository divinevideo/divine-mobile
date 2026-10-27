// ABOUTME: Moves the preview's clip surface by the keyframes of the timeline
// ABOUTME: clip under the playhead, frame by frame, as the export moves it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/extensions/clip_keyframes.dart';
import 'package:openvine/models/divine_video_clip.dart';

/// Lays [child], the preview's clip surface, out moved by the keyframes of
/// the timeline clip [playTime] is in.
///
/// The surface shows the clip's whole frame, which the keyframes' shifts are
/// shares of, so it is moved around its own center; the canvas clips it to
/// the exported frame. What the moved picture no longer covers is black, as
/// in the export.
class ClipMotionSurface extends StatelessWidget {
  /// Creates a [ClipMotionSurface].
  const ClipMotionSurface({
    required this.clips,
    required this.playTime,
    required this.child,
    this.liveKeyframes,
    super.key,
  });

  /// The timeline clips.
  final List<DivineVideoClip> clips;

  /// The editor timeline position of the frame on screen.
  final ValueListenable<Duration> playTime;

  /// Keyframes being changed in the motion editor, shown in place of their
  /// clip's own.
  final ValueListenable<LiveClipKeyframes?>? liveKeyframes;

  /// The clip surface.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final live = liveKeyframes;
    // One tree whether or not the picture moves: rebuilding it would mount
    // the player again.
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge([playTime, ?live]),
        builder: (context, child) {
          final motion = clipMotionAtPlayTime(
            clips,
            playTime.value,
            live: live?.value,
          );
          // Fixed media chrome: the export fills the uncovered part black.
          return ColoredBox(
            color: VineTheme.backgroundColor,
            child: Transform(
              transform: clipMotionMatrix(motion, constraints.biggest),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Where the keyframes of the clip under [time] on the editor timeline put
/// its picture there; [live] replaces the keyframes of the clip it names.
@visibleForTesting
ClipMotion clipMotionAtPlayTime(
  List<DivineVideoClip> clips,
  Duration time, {
  LiveClipKeyframes? live,
}) {
  final frame = clipFrameAtTimelinePosition(clips, time);
  if (frame == null) return stillClipMotion;
  final keyframes = live != null && live.clipId == frame.clip.id
      ? live.keyframes
      : frame.clip.keyframes;
  return clipMotionAt(keyframes, frame.sourceTime) ?? stillClipMotion;
}
