part of 'video_editor_draw_bloc.dart';

/// Base class for all video editor draw events.
sealed class VideoEditorDrawEvent extends Equatable {
  const VideoEditorDrawEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when draw capabilities change (e.g., after drawing, undo, redo).
///
/// The UI is responsible for calling the actual undo/redo/done actions
/// via [VideoEditorScope].
class VideoEditorDrawCapabilitiesChanged extends VideoEditorDrawEvent {
  const VideoEditorDrawCapabilitiesChanged({
    required this.canUndo,
    required this.canRedo,
  });

  final bool canUndo;
  final bool canRedo;

  @override
  List<Object?> get props => [canUndo, canRedo];
}

/// Triggered when a drawing tool is selected.
class VideoEditorDrawToolSelected extends VideoEditorDrawEvent {
  const VideoEditorDrawToolSelected(this.tool);

  final DrawToolType tool;

  @override
  List<Object?> get props => [tool];
}

/// Triggered when a drawing color is selected.
class VideoEditorDrawColorSelected extends VideoEditorDrawEvent {
  const VideoEditorDrawColorSelected(this.color);

  final Color color;

  @override
  List<Object?> get props => [color];
}

/// Triggered when the draw editor opens to reset undo/redo capabilities.
class VideoEditorDrawReset extends VideoEditorDrawEvent {
  const VideoEditorDrawReset();
}
