// ABOUTME: Animated indicator bar for draw tool selection.
// ABOUTME: Slides horizontally to align with the currently selected tool button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Animated indicator bar that shows which draw tool is selected.
///
/// Slides horizontally to align with the currently selected tool button.
class VideoEditorDrawItemIndicator extends StatelessWidget {
  const VideoEditorDrawItemIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final tool = context.select<VideoEditorDrawBloc, DrawToolType>(
      (bloc) => bloc.state.selectedTool,
    );

    final double itemFactor = switch (tool) {
      .pencil => 0,
      .marker => 1,
      .arrow => 2,
      .eraser => 3,
    };

    return Align(
      alignment: .topLeft,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: Offset(itemFactor, 0),
        child: Container(
          width: VideoEditorConstants.drawItemWidth,
          height: 4,
          color: context.vineColors.accentPositive,
        ),
      ),
    );
  }
}
