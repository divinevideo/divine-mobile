import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_main_event.dart';
part 'video_editor_main_state.dart';

/// BLoC for managing the video editor main screen state.
///
/// Handles:
/// - Undo/Redo availability
/// - Layer interaction state (scaling/rotating)
/// - Sub-editor open state and navigation
/// - Playback, seek and timeline mode state
class VideoEditorMainBloc
    extends Bloc<VideoEditorMainEvent, VideoEditorMainState> {
  VideoEditorMainBloc() : super(const VideoEditorMainState()) {
    on<VideoEditorMainCapabilitiesChanged>(_onCapabilitiesChanged);
    on<VideoEditorLayerInteractionStarted>(_onLayerInteractionStarted);
    on<VideoEditorLayerInteractionEnded>(_onLayerInteractionEnded);
    on<VideoEditorLayerOverRemoveAreaChanged>(_onLayerOverRemoveAreaChanged);
    on<VideoEditorMainOpenSubEditor>(_onOpenSubEditor);
    on<VideoEditorMainSubEditorClosed>(_onSubEditorClosed);
    on<VideoEditorPlaybackChanged>(_onPlaybackChanged);
    on<VideoEditorPlayerReady>(_onPlayerReady);
    on<VideoEditorExternalPauseRequested>(_onExternalPauseRequested);
    on<VideoEditorPlaybackRestartRequested>(_onPlaybackRestartRequested);
    on<VideoEditorPlaybackToggleRequested>(_onPlaybackToggleRequested);
    on<VideoEditorSeekRequested>(_onSeekRequested);
    on<VideoEditorAuditionStarted>(_onAuditionStarted);
    on<VideoEditorAuditionEnded>(_onAuditionEnded);
    on<VideoEditorPositionChanged>(
      _onPositionChanged,
      transformer: restartable(),
    );
    on<VideoEditorDurationChanged>(_onDurationChanged);
    on<VideoEditorVolumeEditModeToggled>(_onVolumeEditModeToggled);
    on<VideoEditorReorderingChanged>(_onReorderingChanged);
    on<VideoEditorTimelineVisibilityToggled>(_onTimelineVisibilityToggled);
    on<VideoEditorMarkerModeChanged>(_onMarkerModeChanged);
    on<VideoEditorSlidePointPlacementChanged>(_onSlidePointPlacementChanged);
    on<VideoEditorTrackRegionMarkingChanged>(_onTrackRegionMarkingChanged);
    on<VideoEditorMaskEditingChanged>(_onMaskEditingChanged);
    on<VideoEditorClipMotionEditingChanged>(_onClipMotionEditingChanged);
    on<VideoEditorDetachedClipOpacityPreviewChanged>(
      _onDetachedClipOpacityPreviewChanged,
    );
    on<VideoEditorFinishingChanged>(_onFinishingChanged);
  }

  int _finishGeneration = 0;
  int? _activeFinishGeneration;

  /// Reserves Done synchronously, before the finishing event is processed.
  /// Returns an owner token, or null when another handover already owns it.
  int? claimFinishing() {
    if (isClosed || _activeFinishGeneration != null || state.isFinishing) {
      return null;
    }
    final generation = ++_finishGeneration;
    _activeFinishGeneration = generation;
    add(const VideoEditorFinishingChanged(isFinishing: true));
    return generation;
  }

  /// Whether an asynchronous handover may still complete its action.
  bool ownsFinishing(int generation) =>
      !isClosed && _activeFinishGeneration == generation;

  /// Releases only this handover; an obsolete completion cannot clear a new one.
  void releaseFinishing(int generation) {
    if (_activeFinishGeneration != generation) return;
    _activeFinishGeneration = null;
    if (!isClosed) {
      add(const VideoEditorFinishingChanged(isFinishing: false));
    }
  }

  /// Cancels a pending Done when Close or system back leaves the edit flow.
  void cancelFinishing() {
    final generation = _activeFinishGeneration;
    if (generation != null) releaseFinishing(generation);
  }

  /// Updates undo/redo state based on editor capabilities.
  void _onCapabilitiesChanged(
    VideoEditorMainCapabilitiesChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(canUndo: event.canUndo, canRedo: event.canRedo));
  }

  void _onLayerInteractionStarted(
    VideoEditorLayerInteractionStarted event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isLayerInteractionActive: true));
  }

  void _onLayerInteractionEnded(
    VideoEditorLayerInteractionEnded event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        isLayerInteractionActive: false,
        isLayerOverRemoveArea: false,
      ),
    );
  }

  void _onLayerOverRemoveAreaChanged(
    VideoEditorLayerOverRemoveAreaChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    if (state.isLayerOverRemoveArea != event.isOver) {
      emit(state.copyWith(isLayerOverRemoveArea: event.isOver));
    }
  }

  void _onOpenSubEditor(
    VideoEditorMainOpenSubEditor event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(openSubEditor: event.type));
  }

  void _onSubEditorClosed(
    VideoEditorMainSubEditorClosed event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(clearOpenSubEditor: true));
  }

  void _onPlaybackChanged(
    VideoEditorPlaybackChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isPlaying: event.isPlaying));
  }

  void _onPlayerReady(
    VideoEditorPlayerReady event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isPlayerReady: event.isReady));
  }

  void _onExternalPauseRequested(
    VideoEditorExternalPauseRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isExternalPauseRequested: event.isPaused));
  }

  void _onPlaybackRestartRequested(
    VideoEditorPlaybackRestartRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        playbackRestartCounter: state.playbackRestartCounter + 1,
        isExternalPauseRequested: false,
      ),
    );
  }

  void _onPlaybackToggleRequested(
    VideoEditorPlaybackToggleRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        playbackToggleCounter: state.playbackToggleCounter + 1,
        isExternalPauseRequested: false,
      ),
    );
  }

  void _onSeekRequested(
    VideoEditorSeekRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        seekPosition: event.position,
        seekCounter: state.seekCounter + 1,
      ),
    );
  }

  void _onAuditionStarted(
    VideoEditorAuditionStarted event,
    Emitter<VideoEditorMainState> emit,
  ) {
    if (event.end == event.start) return;
    final audition = (start: event.start, end: event.end);
    final isInside = auditionContains(audition, state.currentPosition);
    final startsPlayback = !state.isPlaying;
    // The seek goes out before the play, so the player starts where the
    // audition does rather than sounding a moment of where it was.
    emit(
      state.copyWith(
        audition: audition,
        auditionOwner: event.owner,
        pausesAfterAudition: startsPlayback,
        isAuditionSeekPending: !isInside,
        seekPosition: isInside ? null : event.start,
        seekCounter: isInside ? null : state.seekCounter + 1,
      ),
    );
    if (!startsPlayback) return;
    emit(
      state.copyWith(
        playbackToggleCounter: state.playbackToggleCounter + 1,
        isExternalPauseRequested: false,
      ),
    );
  }

  void _onAuditionEnded(
    VideoEditorAuditionEnded event,
    Emitter<VideoEditorMainState> emit,
  ) {
    if (state.audition == null ||
        (event.owner != null && event.owner != state.auditionOwner)) {
      return;
    }
    final pauses = state.pausesAfterAudition && state.isPlaying;
    emit(
      state.copyWith(
        clearAudition: true,
        pausesAfterAudition: false,
        isAuditionSeekPending: false,
        playbackToggleCounter: pauses ? state.playbackToggleCounter + 1 : null,
      ),
    );
  }

  /// Takes the player's position and, during an audition, sends playback
  /// that has left the auditioned stretch back to its start — once per
  /// departure, as the player reports the old position until the seek lands.
  ///
  /// A seek can also be dropped: on iOS one sent as the player's loop moves
  /// on to its next lap, which an audition ending where the video ends always
  /// is. Playback then comes round from the start of the video, before the
  /// stretch, and is sent back again.
  void _onPositionChanged(
    VideoEditorPositionChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    final audition = state.audition;
    final position = event.position;
    if (audition == null) {
      emit(state.copyWith(currentPosition: position));
      return;
    }
    final isInside = auditionContains(audition, position);
    final isSeekLost =
        state.isAuditionSeekPending &&
        position < audition.start &&
        position < state.currentPosition;
    if (isInside ||
        (state.isAuditionSeekPending && !isSeekLost) ||
        !state.isPlaying) {
      emit(
        state.copyWith(
          currentPosition: position,
          isAuditionSeekPending: isInside ? false : null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        currentPosition: position,
        isAuditionSeekPending: true,
        seekPosition: audition.start,
        seekCounter: state.seekCounter + 1,
      ),
    );
  }

  void _onDurationChanged(
    VideoEditorDurationChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        totalDuration: event.duration,
        isShortLoop: event.isShortLoop,
      ),
    );
  }

  void _onVolumeEditModeToggled(
    VideoEditorVolumeEditModeToggled event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isVolumeEditMode: !state.isVolumeEditMode));
  }

  void _onReorderingChanged(
    VideoEditorReorderingChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isReordering: event.isReordering));
  }

  void _onTimelineVisibilityToggled(
    VideoEditorTimelineVisibilityToggled event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isTimelineHiddenByUser: !state.isTimelineHiddenByUser));
  }

  void _onMarkerModeChanged(
    VideoEditorMarkerModeChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isMarkerMode: event.isActive));
  }

  void _onSlidePointPlacementChanged(
    VideoEditorSlidePointPlacementChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isPlacingSlidePoint: event.isPlacing));
  }

  void _onTrackRegionMarkingChanged(
    VideoEditorTrackRegionMarkingChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isMarkingTrackRegion: event.isMarking));
  }

  void _onFinishingChanged(
    VideoEditorFinishingChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isFinishing: event.isFinishing));
  }

  void _onMaskEditingChanged(
    VideoEditorMaskEditingChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isEditingMask: event.isEditing));
  }

  void _onClipMotionEditingChanged(
    VideoEditorClipMotionEditingChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isEditingClipMotion: event.isEditing));
  }

  void _onDetachedClipOpacityPreviewChanged(
    VideoEditorDetachedClipOpacityPreviewChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    final preview = event.preview;
    emit(
      preview == null
          ? state.copyWith(clearDetachedClipOpacityPreview: true)
          : state.copyWith(detachedClipOpacityPreview: preview),
    );
  }
}
