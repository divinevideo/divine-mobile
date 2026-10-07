// ABOUTME: Applies a drawing tool's stroke width to the paint editor, as the
// ABOUTME: eraser's radius when the tool is the eraser.

import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Sets how thick the paint editor draws with a [DrawToolType].
extension PaintEditorStrokeWidth on PaintEditorState {
  /// Draws the next strokes of [tool] [strokeWidth] logical pixels of the
  /// editor body wide; the canvas is scaled from the body by [fittedBoxScale].
  ///
  /// The eraser erases within a radius rather than along a stroke.
  void setToolStrokeWidth(
    DrawToolType tool,
    double strokeWidth, {
    required double fittedBoxScale,
  }) {
    final width = strokeWidth / fittedBoxScale;
    if (tool == .eraser) eraserRadius = width / 2;
    setStrokeWidth(width);
  }
}
