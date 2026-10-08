// ABOUTME: A dot as thick as the next stroke of the selected drawing tool,
// ABOUTME: shown while the creator changes the brush size.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';

/// A dot as thick as the next stroke of the selected drawing tool, in the
/// selected color at the tool's opacity.
///
/// The eraser has no color, so it outlines the area it erases instead.
class VideoEditorDrawBrushPreview extends StatelessWidget {
  const VideoEditorDrawBrushPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final (:strokeWidth, :tool, :color) = context.select(
      (VideoEditorDrawBloc b) => (
        strokeWidth: b.state.strokeWidth,
        tool: b.state.selectedTool,
        color: b.state.selectedColor,
      ),
    );
    final isEraser = tool == .eraser;

    return SizedBox.square(
      dimension: strokeWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: .circle,
          // The same alpha the paint editor gives the stroke.
          color: isEraser
              ? null
              : color.withValues(alpha: color.a * tool.config.opacity),
          border: isEraser
              ? .all(color: VineTheme.whiteText, width: 1.5)
              : null,
          // Blurred outside the dot only, so a dot in the color of the video
          // behind it still stands out without looking any thicker.
          boxShadow: const [
            BoxShadow(
              color: VineTheme.scrim30,
              blurRadius: 3,
              blurStyle: .outer,
            ),
          ],
        ),
      ),
    );
  }
}
