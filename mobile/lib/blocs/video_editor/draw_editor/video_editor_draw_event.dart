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

/// Triggered when the creator sets how strongly the selected censor tool
/// hides an area, from 0 to 1.
class VideoEditorDrawCensorIntensityChanged extends VideoEditorDrawEvent {
  const VideoEditorDrawCensorIntensityChanged(this.intensity);

  final double intensity;

  @override
  List<Object?> get props => [intensity];
}

/// Triggered when the creator sets how thick the selected drawing tool draws,
/// from 0 to 1 on its slider.
class VideoEditorDrawBrushSizeChanged extends VideoEditorDrawEvent {
  const VideoEditorDrawBrushSizeChanged(this.brushSize);

  final double brushSize;

  @override
  List<Object?> get props => [brushSize];
}

/// Triggered when the draw editor opens to reset undo/redo capabilities.
class VideoEditorDrawReset extends VideoEditorDrawEvent {
  const VideoEditorDrawReset();
}

/// Triggered right before the draw editor opens, to draw on the video or, with
/// [censor], to hide areas of it.
///
/// Keeps the last tool of that kind and otherwise picks its first one, so
/// opening one kind never starts with the other kind's tool.
class VideoEditorDrawOpened extends VideoEditorDrawEvent {
  const VideoEditorDrawOpened({required this.censor});

  final bool censor;

  @override
  List<Object?> get props => [censor];
}
