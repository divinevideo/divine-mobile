// ABOUTME: Helper to open the effects sub-editor, for a new effect or for one
// ABOUTME: already on the timeline, with the video playing.

import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';

/// Opens the effects sub-editor and starts playback if the video stands
/// still; [pausePlaybackStartedByEffectsEditor] pauses it again on close.
///
/// Pass [effectId] to change that effect in place, keeping its window on the
/// timeline; omit it to add a new effect over the whole video.
///
/// Most effects move — flashes, bursts, grain — and a paused frame shows
/// only one moment of them, often one in which the intensity slider changes
/// nothing visible, so the editor opens on a playing video.
void openEffectsEditor(
  VideoEditorMainBloc mainBloc,
  VideoEditorEffectsCubit effectsCubit, {
  String? effectId,
}) {
  final startsPlayback = !mainBloc.state.isPlaying;
  effectsCubit.startEditing(
    effectId: effectId,
    startedPlayback: startsPlayback,
  );
  mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.effects));
  if (startsPlayback) {
    mainBloc.add(const VideoEditorPlaybackToggleRequested());
  }
}

/// Pauses the video again if opening the effects editor started it and it
/// is still playing, so closing the editor leaves the video as it found it.
///
/// Call once the effects editor has closed, whichever way it was closed.
void pausePlaybackStartedByEffectsEditor(
  VideoEditorMainBloc mainBloc,
  VideoEditorEffectsCubit effectsCubit,
) {
  if (effectsCubit.state.startedPlayback && mainBloc.state.isPlaying) {
    mainBloc.add(const VideoEditorPlaybackToggleRequested());
  }
}
