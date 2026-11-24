// ABOUTME: Settles the clips the camera left in the clip manager once its route
// ABOUTME: returned to the editor, then syncs them into the editor if still open.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Brings the clip manager in line with how the camera opened over the editor
/// ended, then syncs the clips into [clipEditorBloc] and the [editor]'s
/// history.
///
/// A cancelled camera (`recorded` false) has the clips it added after
/// [initialIds] removed again. Over a stop-motion composition, the stills shot
/// are spliced into [stopMotionTarget] at [playhead].
///
/// Both await the clip manager or the clip library. Leaving the editor
/// meanwhile disposes [ref] and closes [clipEditorBloc]; the cleanup still
/// finishes, and the closed editor is left alone.
Future<void> settleEditorCameraReturn(
  BuildContext context,
  WidgetRef ref, {
  required bool recorded,
  required Set<String> initialIds,
  required DivineVideoClip? stopMotionTarget,
  required Duration playhead,
  required ClipEditorBloc clipEditorBloc,
  required ValueGetter<ProImageEditorState?> editor,
}) async {
  final notifier = ref.read(clipManagerProvider.notifier);
  if (!recorded) {
    final newClips = notifier.clips
        .where((c) => !initialIds.contains(c.id))
        .toList();
    for (final clip in newClips) {
      await notifier.removeClipById(clip.id);
    }
  } else if (stopMotionTarget != null) {
    await _insertCapturedStopMotionFrames(
      ref,
      notifier: notifier,
      target: stopMotionTarget,
      initialIds: initialIds,
      playhead: playhead,
    );
  }

  if (!context.mounted) return;
  _syncClipsToEditor(ref, clipEditorBloc: clipEditorBloc, editor: editor());
}

/// Splices stills captured over a stop-motion composition into its frames
/// clip [target] at the [playhead] position, then drops the throwaway clip
/// (and its library row) the recorder created for the capture session.
Future<void> _insertCapturedStopMotionFrames(
  WidgetRef ref, {
  required ClipManagerNotifier notifier,
  required DivineVideoClip target,
  required Set<String> initialIds,
  required Duration playhead,
}) async {
  final clips = notifier.clips;
  final added = clips
      .where((c) => !initialIds.contains(c.id) && c.isStopMotion)
      .toList();
  final capturedFrames = [for (final clip in added) ...?clip.stopMotionFrames];
  if (capturedFrames.isEmpty) return;

  final targetFrames = target.stopMotionFrames ?? const [];
  // Fresh captures arrive stretched to fill a second on their own
  // ([StopMotionFrameOps.initialHold]) — one still added from here would
  // splice into a long clip at a 1s hold — so the session's global default
  // is re-applied, both to undo that stretch and to keep the new stills from
  // drifting from the ones already in the clip.
  final newFrames = StopMotionFrameOps.setGlobalHold(
    capturedFrames,
    StopMotionFrameOps.globalDefaultFramesPerImage(targetFrames),
  );
  final index = StopMotionFrameOps.insertIndexAtPosition(
    targetFrames,
    playhead,
  );
  final merged = StopMotionFrameOps.clipWithFrames(
    target,
    StopMotionFrameOps.insertFramesAt(targetFrames, index, newFrames),
  );

  final addedIds = added.map((c) => c.id).toSet();
  notifier.replaceClips([
    for (final clip in clips)
      if (clip.id == target.id)
        merged
      else if (!addedIds.contains(clip.id))
        clip,
  ]);

  // The recorder saved each capture session as its own library set; those
  // stills now live in [target], so drop the throwaway rows (files kept).
  final libraryService = ref.read(clipLibraryServiceProvider);
  for (final id in addedIds) {
    await libraryService.deleteClipRow(id);
  }
}

/// Syncs the current clip list from [clipManagerProvider] into the
/// [ClipEditorBloc] and appends a history entry to the pro_image_editor.
///
/// The camera adds content — clips or stills shot from the editor — so the
/// composition can end up longer than the one a sound was clamped to when
/// it was added. [VideoEditorExtensions.setLengthenedClipState] carries a
/// window that ran to the old end onto the new one (#6401); a window the
/// user trimmed short is left alone. The clips picker takes the other
/// route: its import lands in the bloc first, and the scaffold's result
/// listener commits the same lengthened history entry from there.
void _syncClipsToEditor(
  WidgetRef ref, {
  required ClipEditorBloc clipEditorBloc,
  required ProImageEditorState? editor,
}) {
  // Read before the dispatch: this is the composition the audio windows were
  // last clamped against.
  final previousClips = clipEditorBloc.state.clips;

  final updatedClips = ref.read(clipManagerProvider).clips;
  clipEditorBloc.add(ClipEditorInitialized(updatedClips));

  editor?.setLengthenedClipState(
    previousClips: previousClips,
    clips: updatedClips,
  );
}
