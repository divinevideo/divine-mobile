import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_editor_draw_event.dart';
part 'video_editor_draw_state.dart';

/// BLoC for managing the video editor draw/paint state.
///
/// This BLoC only manages state. Editor interactions (undo, redo, close,
/// done, applying tool settings) should be done through [VideoEditorScope]
/// in the UI.
///
/// Handles:
/// - Tool selection state (pencil, marker, arrow, eraser)
/// - Color selection state
/// - Undo/redo availability state
class VideoEditorDrawBloc
    extends Bloc<VideoEditorDrawEvent, VideoEditorDrawState> {
  /// Creates a [VideoEditorDrawBloc].
  VideoEditorDrawBloc() : super(const VideoEditorDrawState()) {
    on<VideoEditorDrawCapabilitiesChanged>(_onCapabilitiesChanged);
    on<VideoEditorDrawToolSelected>(_onToolSelected);
    on<VideoEditorDrawColorSelected>(_onColorSelected);
    on<VideoEditorDrawReset>(_onReset);
  }

  /// Resets undo/redo capabilities when the draw editor is closed.
  void _onReset(
    VideoEditorDrawReset event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    Log.debug(
      '✏️ Draw editor reset',
      name: 'VideoEditorDrawBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(canUndo: false, canRedo: false));
  }

  /// Updates undo/redo availability state.
  void _onCapabilitiesChanged(
    VideoEditorDrawCapabilitiesChanged event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    emit(state.copyWith(canUndo: event.canUndo, canRedo: event.canRedo));
  }

  /// Updates the drawing color state.
  void _onColorSelected(
    VideoEditorDrawColorSelected event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    Log.debug(
      '🎨 Draw color selected: #${event.color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      name: 'VideoEditorDrawBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(selectedColor: event.color));
  }

  /// Updates the selected tool and its configuration in state.
  void _onToolSelected(
    VideoEditorDrawToolSelected event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    final tool = event.tool;
    final config = tool.config;

    Log.debug(
      '✏️ Draw tool selected: ${tool.name}',
      name: 'VideoEditorDrawBloc',
      category: LogCategory.video,
    );

    emit(
      state.copyWith(
        selectedTool: tool,
        mode: config.mode,
        opacity: config.opacity,
        strokeWidth: config.strokeWidth,
      ),
    );
  }
}
