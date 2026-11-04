// ABOUTME: Bottom bar for the video editor draw screen.
// ABOUTME: Shows drawing tools and color picker, or the tools that hide an area.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/widgets/video_editor/draw_editor/paint_editor_stroke_width.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_brushes.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_eraser.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_marker.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_censor_tools.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_indicator.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';

/// Bottom bar for the video editor draw screen.
///
/// Shows the [DrawToolType.drawingTools] in a row that scrolls sideways and
/// the color picker, or — while the editor hides areas — the blur and
/// pixelate tools.
class VideoEditorDrawBottomBar extends StatelessWidget {
  const VideoEditorDrawBottomBar({super.key});

  Future<void> _showColorPicker(
    BuildContext context,
    VideoEditorDrawBloc bloc,
    VideoEditorDrawState state,
  ) async {
    final scope = VideoEditorScope.of(context);
    final navigator = Navigator.of(context);

    await VineBottomSheet.show<void>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoEditorColorPickerSheet(
        selectedColor: state.selectedColor,
        onColorSelected: (color) {
          bloc.add(VideoEditorDrawColorSelected(color));
          scope.paintEditor?.setColor(color);
          navigator.pop();
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
        ..setToolStrokeWidth(
          tool,
          bloc.state.strokeWidthOf(tool),
          fittedBoxScale: scope.fittedBoxScale,
        );
      if (tool.isCensor) {
        paintEditor.setCensorStrength(
          censorStrengthOf(config.mode, bloc.state.censorIntensityOf(tool)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoEditorDrawBloc, VideoEditorDrawState>(
      builder: (context, state) {
        if (state.isCensorMode) {
          return VideoEditorDrawCensorTools(
            onToolSelected: (tool) => _onToolSelected(context, tool),
          );
        }

        final bloc = context.read<VideoEditorDrawBloc>();

        return Row(
          crossAxisAlignment: .end,
          children: [
            Expanded(
              child: _FadedEdges(
                child: SingleChildScrollView(
                  scrollDirection: .horizontal,
                  padding: const .only(left: 16, right: 12),
                  child: Stack(
                    children: [
                      const Positioned(
                        top: 0,
                        left: 0,
                        child: VideoEditorDrawItemIndicator(),
                      ),
                      Row(
                        crossAxisAlignment: .end,
                        children: [
                          for (final tool in DrawToolType.drawingTools)
                            _DrawToolButton(
                              tool: tool,
                              isSelected: state.selectedTool == tool,
                              color: state.selectedColor,
                              onTap: () => _onToolSelected(context, tool),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Color picker
            SafeArea(
              top: false,
              right: false,
              left: false,
              child: Padding(
                padding: const .only(bottom: 12, right: 16),
                child: _ColorPickerButton(
                  color: state.selectedColor,
                  onTap: () => _showColorPicker(context, bloc, state),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fades [child] out at its left and right edges, so tools that scroll past
/// an edge show that the row goes on.
class _FadedEdges extends StatelessWidget {
  const _FadedEdges({required this.child});

  final Widget child;

  /// How wide each faded edge is.
  static const double _fadeWidth = 16;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: .dstIn,
      shaderCallback: (bounds) {
        final fade = (_fadeWidth / bounds.width).clamp(0.0, 0.5);
        const opaque = VineTheme.whiteText;
        final clear = opaque.withValues(alpha: 0);
        return LinearGradient(
          colors: [clear, opaque, opaque, clear],
          stops: [0, fade, 1 - fade, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// The button of one drawing [tool], showing its icon.
class _DrawToolButton extends StatelessWidget {
  const _DrawToolButton({
    required this.tool,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final DrawToolType tool;
  final bool isSelected;

  /// The selected drawing color, which tools that draw in it show.
  final Color color;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return switch (tool) {
      .pencil => DrawToolPencil(
        isSelected: isSelected,
        color: color,
        onTap: onTap,
      ),
      .marker => DrawToolMarker(
        isSelected: isSelected,
        color: color,
        onTap: onTap,
      ),
      .neon => DrawToolNeon(isSelected: isSelected, color: color, onTap: onTap),
      .rainbow => DrawToolRainbow(isSelected: isSelected, onTap: onTap),
      .calligraphy => DrawToolCalligraphy(
        isSelected: isSelected,
        color: color,
        onTap: onTap,
      ),
      .eraser => DrawToolEraser(isSelected: isSelected, onTap: onTap),
      // The hide tools have their own bar.
      .blur || .pixelate => const SizedBox.shrink(),
    };
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
