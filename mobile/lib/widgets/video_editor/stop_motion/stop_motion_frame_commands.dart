// ABOUTME: Commits stop-motion frame-list edits to the clip editor + history
// ABOUTME: Shared by the frame strip, the action bar, and the toolbar control

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/screens/video_editor/stop_motion_frame_transform_screen.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frames_per_image_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';

/// Commits a new stop-motion frame list for the single stop-motion clip
/// [clipId].
///
/// Updates the [ClipEditorBloc], rebases timeline markers, stretches audio that
/// ran to the end of the composition onto the new (longer) end, and writes the
/// change to editor history (undo/redo) — mirroring the clip-level edit commit
/// in `TimelineClipControls` (`_deleteClip` / `_setPlaybackSpeed`). A no-op edit
/// (the frame-ops helpers return the source list unchanged) is skipped so it
/// never records an empty history entry.
///
/// Returns whether the edit was committed. Bails with `false` when the
/// [ProImageEditorState] is gone — a tap can resolve after the
/// editor route is popped, and force-unwrapping it there is a release-mode
/// crash (#5799). Bailing before the bloc dispatch keeps the frame list and
/// the editor history from diverging.
bool commitStopMotionFrames(
  BuildContext context, {
  required String clipId,
  required List<StopMotionClipFrame> frames,
}) {
  final bloc = context.read<ClipEditorBloc>();
  final overlayBloc = context.read<TimelineOverlayBloc>();
  final editor = VideoEditorScope.of(context).editor;
  if (editor == null) return false;

  final state = bloc.state;
  final index = state.clips.indexWhere((clip) => clip.id == clipId);
  if (index == -1) return false;

  final clip = state.clips[index];
  if (identical(frames, clip.stopMotionFrames)) return false;

  final updated = StopMotionFrameOps.clipWithFrames(clip, frames);
  final newClips = [
    for (final c in state.clips)
      if (c.id == clipId) updated else c,
  ];
  final rebasedMarkers = rebaseTimelineMarkersForClipState(
    oldClips: state.clips,
    newClips: newClips,
    markers: overlayBloc.state.timelineMarkers,
  );

  bloc.add(ClipEditorClipUpdated(clipId: clipId, clip: updated));
  overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
  // A hold change restretches the whole composition, so a sound that covered it
  // has to grow with it (#6401).
  editor.setLengthenedClipState(
    previousClips: state.clips,
    clips: newClips,
    timelineMarkers: rebasedMarkers,
  );
  return true;
}

DivineVideoClip? _clip(BuildContext context, String clipId) {
  for (final clip in context.read<ClipEditorBloc>().state.clips) {
    if (clip.id == clipId) return clip;
  }
  return null;
}

List<StopMotionClipFrame>? _stopMotionFrames(
  BuildContext context,
  String clipId,
) => _clip(context, clipId)?.stopMotionFrames;

/// Opens the still at [frameIndex] of the stop-motion clip [clipId] in the
/// crop / rotate / flip editor and points that still at the transformed image.
///
/// The editor rasterizes the still itself, so unlike the clip-level transform
/// — which queues a native re-render — the pixels come straight back. Writing
/// them and repointing the frame is the bloc's job
/// ([ClipEditorStopMotionFrameTransformed]); this only opens the editor and
/// hands over what it produced.
Future<void> transformStopMotionFrame(
  BuildContext context, {
  required String clipId,
  required int frameIndex,
}) async {
  final clip = _clip(context, clipId);
  final frames = clip?.stopMotionFrames;
  if (clip == null ||
      frames == null ||
      frameIndex < 0 ||
      frameIndex >= frames.length) {
    return;
  }

  final bytes = await Navigator.of(context).push<Uint8List>(
    PageRouteBuilder<Uint8List>(
      settings: const RouteSettings(name: 'stop_motion_frame_transform'),
      opaque: false,
      barrierColor: context.vineColors.surfaceContainerHigh,
      pageBuilder: (_, _, _) => StopMotionFrameTransformScreen(
        framePath: frames[frameIndex].path,
        targetAspectRatio: clip.targetAspectRatio,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  // `null` is Cancel and stays silent. Empty bytes are not: they mean the
  // editor gave up rasterizing and closed anyway, so they travel on and the
  // bloc turns them into the failure snackbar rather than a silent no-op.
  if (bytes == null || !context.mounted) return;

  // The bloc owns the write and the frame swap: persisting the pixels is
  // data-layer work, and it also puts the change in editor history through the
  // same hook every other clip render uses, so undo restores the old still.
  context.read<ClipEditorBloc>().add(
    ClipEditorStopMotionFrameTransformed(
      clipId: clipId,
      frameIndex: frameIndex,
      imageBytes: bytes,
    ),
  );
}

/// Opens the frames-per-image wheel sheet and applies the chosen hold to every
/// still in the stop-motion clip [clipId].
Future<void> editStopMotionGlobalHold(
  BuildContext context, {
  required String clipId,
}) async {
  final frames = _stopMotionFrames(context, clipId);
  if (frames == null || frames.isEmpty) return;
  final current = StopMotionFrameOps.globalDefaultFramesPerImage(frames);

  final result = await _showFramesPerImageSheet(context, current);
  if (result == null || !context.mounted) return;

  final latest = _stopMotionFrames(context, clipId);
  if (latest == null) return;
  commitStopMotionFrames(
    context,
    clipId: clipId,
    frames: StopMotionFrameOps.setGlobalHold(latest, result),
  );
}

/// Opens the frames-per-image wheel sheet and applies the chosen hold to every
/// still at [frameIndexes] of the stop-motion clip [clipId] (frame
/// multi-select). The sheet opens on the first selected still's current hold.
Future<void> editStopMotionFramesHold(
  BuildContext context, {
  required String clipId,
  required Set<int> frameIndexes,
}) async {
  final frames = _stopMotionFrames(context, clipId);
  if (frames == null || frameIndexes.isEmpty) return;
  final firstIndex = frameIndexes.reduce((a, b) => a < b ? a : b);
  if (firstIndex < 0 || firstIndex >= frames.length) return;
  final current = StopMotionFrameOps.durationToFramesPerImage(
    frames[firstIndex].duration,
  );

  final result = await _showFramesPerImageSheet(context, current);
  if (result == null || !context.mounted) return;

  final latest = _stopMotionFrames(context, clipId);
  if (latest == null) return;
  commitStopMotionFrames(
    context,
    clipId: clipId,
    frames: StopMotionFrameOps.setFramesHold(latest, frameIndexes, result),
  );
}

/// Opens the frames-per-image wheel sheet and applies the chosen hold to the
/// still at [frameIndex] of the stop-motion clip [clipId].
Future<void> editStopMotionFrameHold(
  BuildContext context, {
  required String clipId,
  required int frameIndex,
}) async {
  final frames = _stopMotionFrames(context, clipId);
  if (frames == null || frameIndex < 0 || frameIndex >= frames.length) return;
  final current = StopMotionFrameOps.durationToFramesPerImage(
    frames[frameIndex].duration,
  );

  final result = await _showFramesPerImageSheet(context, current);
  if (result == null || !context.mounted) return;

  final latest = _stopMotionFrames(context, clipId);
  if (latest == null || frameIndex >= latest.length) return;
  commitStopMotionFrames(
    context,
    clipId: clipId,
    frames: StopMotionFrameOps.setFrameHold(latest, frameIndex, result),
  );
}

Future<int?> _showFramesPerImageSheet(BuildContext context, int initialValue) {
  return VineBottomSheet.show<int>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: StopMotionFramesPerImageSheet(initialValue: initialValue),
  );
}
