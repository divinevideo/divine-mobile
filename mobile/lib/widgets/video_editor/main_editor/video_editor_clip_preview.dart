// ABOUTME: Preview surface for the clip currently open in the video editor
// ABOUTME: Picks the normal player or the position-driven stop-motion player

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
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
/// shown frame follows play/pause and timeline scrubbing. The video branch lays
/// the surface out at the frame ratio of the clip under [playTime] — a library
/// clip or a crop / rotate transform gives one clip a differently shaped file
/// than the rest of the composition — and rebuilds only when that ratio
/// changes, so a normal clip never rebuilds on position ticks.
class VideoEditorClipPreview extends StatelessWidget {
  /// Creates a [VideoEditorClipPreview].
  const VideoEditorClipPreview({
    required this.clip,
    required this.controller,
    required this.bodySize,
    required this.renderSize,
    required this.playTime,
    this.frameBuilder,
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

  /// Timeline position of the frame on screen, advanced every frame while
  /// playing (see `VideoEditorScope.playTimeNotifier`).
  final ValueListenable<Duration> playTime;

  /// See [VideoEditorPlayer.frameBuilder].
  final Widget Function(Widget frame)? frameBuilder;

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
        builder: (context, liveClips) => _PlayheadVideoAspectRatio(
          clips: liveClips,
          fallbackClip: clip,
          playTime: playTime,
          builder: (context, videoAspectRatio) => VideoEditorPlayer(
            controller: controller,
            targetAspectRatio: clip.targetAspectRatio,
            videoAspectRatio: videoAspectRatio,
            bodySize: bodySize,
            renderSize: renderSize,
            frameBuilder: frameBuilder,
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
            frameBuilder: frameBuilder,
          ),
        );
      },
    );
  }
}

/// Builds with the frame ratio of the clip under [playTime].
///
/// The native preview plays every clip on one track, so its frames change
/// shape on the very frame the playhead enters a differently shaped clip. The
/// editor bloc's position only moves on the player's reports, about five times
/// a second, and following it left the new clip squeezed into the previous
/// clip's box for up to 200 ms. [playTime] advances every frame, and this only
/// rebuilds when the ratio it lands on changes.
class _PlayheadVideoAspectRatio extends StatefulWidget {
  const _PlayheadVideoAspectRatio({
    required this.clips,
    required this.fallbackClip,
    required this.playTime,
    required this.builder,
  });

  /// The live timeline clips.
  final List<DivineVideoClip> clips;

  /// Clip whose ratio applies when no timeline clip sits under the playhead.
  final DivineVideoClip fallbackClip;

  /// Timeline position of the frame on screen.
  final ValueListenable<Duration> playTime;

  /// Builds the surface for the resolved ratio.
  final Widget Function(BuildContext context, double videoAspectRatio) builder;

  @override
  State<_PlayheadVideoAspectRatio> createState() =>
      _PlayheadVideoAspectRatioState();
}

class _PlayheadVideoAspectRatioState extends State<_PlayheadVideoAspectRatio> {
  late double _videoAspectRatio;

  @override
  void initState() {
    super.initState();
    _videoAspectRatio = _ratioAtPlayhead();
    widget.playTime.addListener(_onPlayTime);
  }

  @override
  void didUpdateWidget(_PlayheadVideoAspectRatio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playTime != widget.playTime) {
      oldWidget.playTime.removeListener(_onPlayTime);
      widget.playTime.addListener(_onPlayTime);
    }
    // A transform, trim or reorder can change the clip under the playhead.
    _videoAspectRatio = _ratioAtPlayhead();
  }

  @override
  void dispose() {
    widget.playTime.removeListener(_onPlayTime);
    super.dispose();
  }

  double _ratioAtPlayhead() =>
      (clipAtTimelinePosition(widget.clips, widget.playTime.value) ??
              widget.fallbackClip)
          .videoAspectRatio;

  void _onPlayTime() {
    final ratio = _ratioAtPlayhead();
    if (ratio == _videoAspectRatio) return;
    setState(() => _videoAspectRatio = ratio);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _videoAspectRatio);
}
