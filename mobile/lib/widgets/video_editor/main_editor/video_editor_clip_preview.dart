// ABOUTME: Preview surface for the clip currently open in the video editor
// ABOUTME: Picks the normal player or the position-driven stop-motion player

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';

/// The preview surface for the current clip: a [DivineVideoPlayer] for a normal
/// clip, or a controlled `StopMotionPlayer` for a frames-only stop-motion clip.
///
/// The stop-motion branch subscribes to the editor's `currentPosition` so the
/// shown frame follows play/pause and timeline scrubbing. The video branch only
/// selects the frame ratio of the clip under the playhead from it — a crop /
/// rotate transform gives one clip a differently shaped file than the rest of
/// the composition — so a normal clip never rebuilds on position ticks.
class VideoEditorClipPreview extends StatelessWidget {
  /// Creates a [VideoEditorClipPreview].
  const VideoEditorClipPreview({
    required this.clip,
    required this.controller,
    required this.bodySize,
    required this.renderSize,
    super.key,
  });

  /// The clip to preview.
  final DivineVideoClip clip;

  /// Player driving a normal clip; `null` until the player is ready.
  final DivineVideoPlayerController? controller;

  /// Size of the editor body the preview is laid out in.
  final Size bodySize;

  /// Size of the editor's render space.
  final Size renderSize;

  @override
  Widget build(BuildContext context) {
    final clipManagerFrames = clip.stopMotionFrames;
    if (clipManagerFrames == null) {
      // The live clip list, for the same reason as the frames below: a
      // transform lands in ClipEditorBloc first, and the clip manager only
      // learns of it through the history path a post-frame later.
      return BlocSelector<
        ClipEditorBloc,
        ClipEditorState,
        List<DivineVideoClip>
      >(
        selector: (state) => state.clips,
        builder: (context, liveClips) =>
            BlocSelector<VideoEditorMainBloc, VideoEditorMainState, double>(
              selector: (state) =>
                  (clipAtTimelinePosition(liveClips, state.currentPosition) ??
                          clip)
                      .videoAspectRatio,
              builder: (context, videoAspectRatio) => VideoEditorPlayer(
                controller: controller,
                targetAspectRatio: clip.targetAspectRatio,
                videoAspectRatio: videoAspectRatio,
                bodySize: bodySize,
                renderSize: renderSize,
              ),
            ),
      );
    }

    // Read the live frame list from the clip editor, not the clip-manager copy:
    // frame edits (delete / reorder / frames-per-image) land in ClipEditorBloc
    // immediately, whereas the clip-manager copy syncs one post-frame later
    // through the history path.
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      List<StopMotionClipFrame>?
    >(
      selector: (state) {
        for (final c in state.clips) {
          if (c.id == clip.id) return c.stopMotionFrames;
        }
        return null;
      },
      builder: (context, liveFrames) {
        final frames = liveFrames ?? clipManagerFrames;
        return BlocSelector<
          VideoEditorMainBloc,
          VideoEditorMainState,
          Duration
        >(
          selector: (state) => state.currentPosition,
          builder: (context, position) => VideoEditorPlayer(
            controller: controller,
            targetAspectRatio: clip.targetAspectRatio,
            videoAspectRatio: clip.videoAspectRatio,
            bodySize: bodySize,
            renderSize: renderSize,
            stopMotionFrames: frames,
            stopMotionPosition: position,
          ),
        );
      },
    );
  }
}
