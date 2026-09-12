// ABOUTME: Bottom bar for the video editor draw screen.
// ABOUTME: Shows drawing tools (pencil, marker, arrow, eraser) and color picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_arrow.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_eraser.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_marker.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_indicator.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';

/// Bottom bar for the video editor draw screen.
///
/// Shows available drawing tools (pencil, marker, neon, eraser) and color picker.
class VideoEditorDrawBottomBar extends StatelessWidget {
  const VideoEditorDrawBottomBar({super.key});

  Future<void> _showColorPicker(
    BuildContext context,
    VideoEditorDrawBloc bloc,
    VideoEditorDrawState state,
  ) async {
    final scope = VideoEditorScope.of(context);

    VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoEditorColorPickerSheet(
        selectedColor: state.selectedColor,
        onColorSelected: (color) {
          bloc.add(VideoEditorDrawColorSelected(color));
          scope.paintEditor?.setColor(color);
          context.pop();
        },
      ),
    );
  }

  void _onToolSelected(BuildContext context, DrawToolType tool) {
    final bloc = context.read<VideoEditorDrawBloc>();
    final scope = VideoEditorScope.of(context);
    final paintEditor = scope.paintEditor;

    bloc.add(VideoEditorDrawToolSelected(tool));

    if (paintEditor != null) {
      final config = tool.config;
      paintEditor
        ..setMode(config.mode)
        ..setOpacity(config.opacity)
        ..setStrokeWidth(config.strokeWidth / scope.fittedBoxScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoEditorDrawBloc, VideoEditorDrawState>(
      builder: (context, state) {
        final bloc = context.read<VideoEditorDrawBloc>();

        return Padding(
          padding: const .only(left: 28, right: 16),
          child: Stack(
            children: [
              const VideoEditorDrawItemIndicator(),
              Row(
                crossAxisAlignment: .end,
                children: [
                  // Drawing tools
                  DrawToolPencil(
                    isSelected: state.selectedTool == .pencil,
                    color: state.selectedColor,
                    onTap: () => _onToolSelected(context, .pencil),
                  ),
                  DrawToolMarker(
                    isSelected: state.selectedTool == .marker,
                    color: state.selectedColor,
                    onTap: () => _onToolSelected(context, .marker),
                  ),
                  DrawToolArrow(
                    isSelected: state.selectedTool == .arrow,
                    onTap: () => _onToolSelected(context, .arrow),
                  ),
                  DrawToolEraser(
                    isSelected: state.selectedTool == .eraser,
                    onTap: () => _onToolSelected(context, .eraser),
                  ),

                  const Spacer(),

                  // Color picker
                  SafeArea(
                    top: false,
                    right: false,
                    left: false,
                    child: Padding(
                      padding: const .only(bottom: 12),
                      child: _ColorPickerButton(
                        color: state.selectedColor,
                        onTap: () => _showColorPicker(context, bloc, state),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Color picker button that shows the currently selected color.
class _ColorPickerButton extends StatelessWidget {
  const _ColorPickerButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.videoEditorColorPickerSemanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          padding: const .all(2),
          decoration: BoxDecoration(
            borderRadius: .circular(18),
            border: .all(color: context.vineColors.onSurface, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: .circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
