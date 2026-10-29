import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_editor_filter_event.dart';
part 'video_editor_filter_state.dart';

/// BLoC for managing filter selection state in the video editor.
///
/// This BLoC only manages state. Editor interactions (applying filters,
/// closing sub-editors) should be done through [VideoEditorScope] in the UI.
class VideoEditorFilterBloc
    extends Bloc<VideoEditorFilterEvent, VideoEditorFilterState> {
  VideoEditorFilterBloc() : super(const VideoEditorFilterState()) {
    on<VideoEditorFilterEditorInitialized>(_onEditorInitialized);
    on<VideoEditorFilterSelected>(_onFilterSelected);
    on<VideoEditorFilterOpacityChanged>(_onOpacityChanged);
    on<VideoEditorFilterCancelled>(_onCancelled);
    on<VideoEditorFilterConfirmed>(_onFilterConfirmed);
  }

  void _onEditorInitialized(
    VideoEditorFilterEditorInitialized event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    // Store current values as initial values for potential cancel
    emit(
      state.copyWith(
        initialSelectedFilter: state.selectedFilter,
        initialOpacity: state.opacity,
        initialAppliedFilters: state.appliedFilters,
      ),
    );
  }

  void _onFilterSelected(
    VideoEditorFilterSelected event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    Log.debug(
      '🎨 Filter selected: ${event.filter.name}',
      name: 'VideoEditorFilterBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(selectedFilter: event.filter));
  }

  void _onOpacityChanged(
    VideoEditorFilterOpacityChanged event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    emit(state.copyWith(opacity: event.opacity));
  }

  void _onCancelled(
    VideoEditorFilterCancelled event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    // Restore to initial values from when the editor was opened
    final initial = state.initialSelectedFilter;
    emit(
      state.copyWith(
        selectedFilter: initial,
        clearSelectedFilter: initial == null,
        opacity: state.initialOpacity,
        appliedFilters: state.initialAppliedFilters,
      ),
    );
  }

  void _onFilterConfirmed(
    VideoEditorFilterConfirmed event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    final filter = state.selectedFilter;
    if (filter == null) return;

    emit(
      state.copyWith(
        appliedFilters: [...state.appliedFilters, filter],
        clearSelectedFilter: true,
      ),
    );
  }
}
