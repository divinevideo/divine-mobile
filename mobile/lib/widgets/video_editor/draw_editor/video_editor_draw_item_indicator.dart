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

    // The hide tools have their own bar without this indicator.
    final double itemFactor = DrawToolType.drawingTools
        .indexOf(tool)
        .clamp(0, DrawToolType.drawingTools.length)
        .toDouble();

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
