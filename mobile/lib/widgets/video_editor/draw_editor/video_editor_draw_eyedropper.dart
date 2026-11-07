// ABOUTME: The draw editor's eyedropper: picks the drawing color off what the
// ABOUTME: canvas shows — the video, its layers and the strokes drawn so far.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/widgets/video_editor/eyedropper/color_eyedropper.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Lays a [ColorEyedropper] over the canvas while
/// [VideoEditorDrawState.isPickingColor] is set, and hands the pick to the
/// draw state and the paint editor alike.
///
/// Picks from [VideoEditorScope.canvasBodyKey]; without one there is nothing
/// to pick from, and the draw bar does not offer the eyedropper.
class VideoEditorDrawEyedropper extends StatelessWidget {
  const VideoEditorDrawEyedropper({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    final sourceKey = scope.canvasBodyKey;
    final bloc = context.read<VideoEditorDrawBloc>();
    if (sourceKey == null) return const SizedBox.shrink();

    return ColorEyedropper(
      sourceKey: sourceKey,
      onColorPicked: (color) {
        bloc.add(VideoEditorDrawColorSelected(color));
        scope.paintEditor?.setColor(color);
      },
      onCancel: () => bloc.add(const VideoEditorDrawEyedropperCancelled()),
    );
  }
}
