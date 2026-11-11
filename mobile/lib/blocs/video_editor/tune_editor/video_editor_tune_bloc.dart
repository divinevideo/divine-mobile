import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_editor_tune_event.dart';
part 'video_editor_tune_state.dart';

/// BLoC for managing tune-adjustment state in the video editor.
///
/// This BLoC only manages the state that drives the custom tune bottom bar
/// (which adjustment is selected and its per-adjustment value). The actual
/// image adjustment is applied through the pro_image_editor `TuneEditorState`
/// via [VideoEditorScope]; the two are kept in sync by dispatching an event
/// here and calling the editor from the UI on the same interaction.
class VideoEditorTuneBloc
    extends Bloc<VideoEditorTuneEvent, VideoEditorTuneState> {
  VideoEditorTuneBloc()
    : super(
        VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
        ),
      ) {
    on<VideoEditorTuneSessionStarted>(_onSessionStarted);
    on<VideoEditorTuneEditorInitialized>(_onEditorInitialized);
    on<VideoEditorTuneAdjustmentSelected>(_onAdjustmentSelected);
    on<VideoEditorTuneColorBandSelected>(_onColorBandSelected);
    on<VideoEditorTuneCurveChannelSelected>(_onCurveChannelSelected);
    on<VideoEditorTuneValueChanged>(_onValueChanged);
    on<VideoEditorTuneCancelled>(_onCancelled);
    on<VideoEditorTuneConfirmed>(_onConfirmed);
  }

  void _onSessionStarted(
    VideoEditorTuneSessionStarted event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    // The bar opens on the first slider, not on the section the previous
    // session ended in.
    emit(
      state.copyWith(
        selectedIndex: 0,
        values: event.values,
        editingSetId: event.setId,
        clearEditingSetId: event.setId == null,
      ),
    );
  }

  void _onEditorInitialized(
    VideoEditorTuneEditorInitialized event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    // Seed the session values from the adjustments already applied to the
    // clip (mirrors how the editor seeds itself from
    // `stateManager.activeTuneAdjustments`), and snapshot them so a cancel
    // can restore the pre-open state.
    final values = {for (final m in event.activeAdjustments) m.id: m.value};
    emit(
      state.copyWith(
        selectedIndex: 0,
        values: values,
        initialValues: values,
      ),
    );
  }

  void _onAdjustmentSelected(
    VideoEditorTuneAdjustmentSelected event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    if (event.index < 0 || event.index >= state.adjustments.length) return;
    emit(state.copyWith(selectedIndex: event.index));
  }

  void _onColorBandSelected(
    VideoEditorTuneColorBandSelected event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    final index = state.indexOf(event.band.kindOf(AdjustColorProperty.hue));
    if (index < 0) return;
    emit(state.copyWith(selectedIndex: index, colorBand: event.band));
  }

  void _onCurveChannelSelected(
    VideoEditorTuneCurveChannelSelected event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    final index = state.indexOf(event.channel.kindOf(AdjustCurvePoint.blacks));
    if (index < 0) return;
    emit(state.copyWith(selectedIndex: index, curveChannel: event.channel));
  }

  void _onValueChanged(
    VideoEditorTuneValueChanged event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    final id = event.id ?? state.selectedAdjustment.id;
    final index = state.indexOf(id);
    if (index < 0) return;
    emit(
      state.copyWith(
        selectedIndex: index,
        values: {...state.values, id: event.value},
      ),
    );
  }

  void _onCancelled(
    VideoEditorTuneCancelled event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    Log.debug(
      '🎚️ Tune adjustments cancelled',
      name: 'VideoEditorTuneBloc',
      category: LogCategory.video,
    );
    emit(
      state.copyWith(values: state.initialValues, clearEditingSetId: true),
    );
  }

  void _onConfirmed(
    VideoEditorTuneConfirmed event,
    Emitter<VideoEditorTuneState> emit,
  ) {
    Log.debug(
      '🎚️ Tune adjustments applied',
      name: 'VideoEditorTuneBloc',
      category: LogCategory.video,
    );
    // The applied values become the new baseline so a later re-open (which
    // re-seeds from the editor) and cancel share the same reference point.
    emit(
      state.copyWith(initialValues: state.values, clearEditingSetId: true),
    );
  }
}
