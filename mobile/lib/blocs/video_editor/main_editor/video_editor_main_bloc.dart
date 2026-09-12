import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_main_event.dart';
part 'video_editor_main_state.dart';

/// BLoC for managing the video editor main screen state.
///
/// Handles:
/// - Undo/Redo availability and actions
/// - Layer interaction state (scaling/rotating)
/// - Sub-editor open state and navigation
/// - Close/Done actions
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
  }

  /// Updates undo/redo/subEditor state based on editor capabilities.
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

  void _onPositionChanged(
    VideoEditorPositionChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(currentPosition: event.position));
  }

  void _onDurationChanged(
    VideoEditorDurationChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(totalDuration: event.duration));
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
}
