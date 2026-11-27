import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/video_editor/effect_setting.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
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
    on<VideoEditorFilterSessionStarted>(_onSessionStarted);
    on<VideoEditorFilterSelected>(_onFilterSelected);
    on<VideoEditorFilterOpacityChanged>(_onOpacityChanged);
    on<VideoEditorFilterSettingChanged>(_onSettingChanged);
    on<VideoEditorFilterSettingsReset>(_onSettingsReset);
    on<VideoEditorFilterSettingsToggled>(_onSettingsToggled);
    on<VideoEditorFilterCancelled>(_onSessionEnded);
    on<VideoEditorFilterConfirmed>(_onSessionEnded);
  }

  void _onSessionStarted(
    VideoEditorFilterSessionStarted event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    final filter = event.filter;
    emit(
      VideoEditorFilterState(
        selectedFilter: filter?.preset,
        opacity: filter?.opacity ?? 1,
        settingValues: filter?.values ?? const {},
        editingFilterId: filter == null ? null : event.filterId,
      ),
    );
  }

  /// A new preset starts from its own values.
  void _onFilterSelected(
    VideoEditorFilterSelected event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    Log.debug(
      '🎨 Filter selected: ${event.filter.name}',
      name: 'VideoEditorFilterBloc',
      category: LogCategory.video,
    );
    if (event.filter.name == state.selectedFilter?.name) return;
    emit(state.copyWith(selectedFilter: event.filter, settingValues: const {}));
  }

  void _onOpacityChanged(
    VideoEditorFilterOpacityChanged event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    emit(state.copyWith(opacity: event.opacity));
  }

  /// Brings the value into the setting's range; a value equal to the
  /// preset's own clears the change, so an untouched step keeps its values
  /// exactly. A key the picked filter has no setting for changes nothing.
  void _onSettingChanged(
    VideoEditorFilterSettingChanged event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    final filter = state.selectedFilter;
    final setting = filter == null ? null : filterSettingOf(filter, event.key);
    if (setting == null) return;
    final value = setting.read(event.value);
    emit(
      state.copyWith(
        settingValues: Map.unmodifiable({
          for (final MapEntry(:key, :value) in state.settingValues.entries)
            if (key != event.key) key: value,
          if (value != setting.defaultParam) event.key: value,
        }),
      ),
    );
  }

  void _onSettingsReset(
    VideoEditorFilterSettingsReset event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    final keys = {for (final setting in event.card.settings) setting.key};
    emit(
      state.copyWith(
        settingValues: Map.unmodifiable({
          for (final MapEntry(:key, :value) in state.settingValues.entries)
            if (!keys.contains(key)) key: value,
        }),
      ),
    );
  }

  void _onSettingsToggled(
    VideoEditorFilterSettingsToggled event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    emit(state.copyWith(isSettingsOpen: event.open));
  }

  void _onSessionEnded(
    VideoEditorFilterEvent event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    emit(const VideoEditorFilterState());
  }
}
