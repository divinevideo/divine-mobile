// ABOUTME: Overlay controls for the draw editor screen: close, undo, redo and
// ABOUTME: done on top, and a slider for the brush size or censor strength.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/widgets/video_editor/draw_editor/paint_editor_stroke_width.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_brush_preview.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

/// Overlay controls for the draw editor screen.
///
/// Displays close, undo, redo, and done buttons with proper accessibility,
/// and a slider for how thick the selected tool draws or, while the editor
/// hides areas, how strongly it does.
class VideoEditorDrawOverlayControls extends StatelessWidget {
  const VideoEditorDrawOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final isCensorMode = context.select(
      (VideoEditorDrawBloc b) => b.state.isCensorMode,
    );
    return Stack(
      fit: .expand,
      children: [
        if (isCensorMode)
          const Align(
            alignment: .centerRight,
            child: _CensorStrengthSlider(),
          )
        else
          const _BrushSizeControls(),
        _TopBar(isCensorMode: isCensorMode),
      ],
    );
  }
}

/// The brush size slider and, while it is dragged, a preview of the brush in
/// the middle of the canvas.
class _BrushSizeControls extends StatefulWidget {
  const _BrushSizeControls();

  @override
  State<_BrushSizeControls> createState() => _BrushSizeControlsState();
}

class _BrushSizeControlsState extends State<_BrushSizeControls> {
  /// Whether the slider is being dragged.
  bool _isAdjusting = false;

  /// Where the preview is centered; it keeps its place while it fades out.
  Offset? _previewCenter;

  /// The middle of the canvas, which is laid out apart from these controls.
  Offset _canvasCenter() {
    final box = context.findRenderObject()! as RenderBox;
    final canvasRect = VideoEditorScope.of(context).canvasBodyRect;
    return canvasRect == null
        ? box.size.center(Offset.zero)
        : box.globalToLocal(canvasRect.center);
  }

  void _onChanged(double value) {
    // The slider reports no drag start, so its first change is one.
    if (!_isAdjusting) {
      setState(() {
        _isAdjusting = true;
        _previewCenter = _canvasCenter();
      });
    }
    final bloc = context.read<VideoEditorDrawBloc>()
      ..add(VideoEditorDrawBrushSizeChanged(value));
    final scope = VideoEditorScope.of(context);
    scope.paintEditor?.setToolStrokeWidth(
      bloc.state.selectedTool,
      drawStrokeWidthOf(value),
      fittedBoxScale: scope.fittedBoxScale,
    );
  }

  void _onChangeEnd(double _) => setState(() => _isAdjusting = false);

  @override
  Widget build(BuildContext context) {
    final brushSize = context.select(
      (VideoEditorDrawBloc b) => b.state.brushSize,
    );
    final previewCenter = _previewCenter;
    return Stack(
      fit: .expand,
      children: [
        if (previewCenter != null)
          Positioned(
            left: previewCenter.dx,
            top: previewCenter.dy,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              // The slider already announces the size.
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: Duration.zero,
                    reverseDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : VideoEditorConstants.drawBrushPreviewFadeDuration,
                    // No child rather than an empty one: the default
                    // transition keys both alike and drops the fading dot.
                    child: _isAdjusting
                        ? const VideoEditorDrawBrushPreview()
                        : null,
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: .centerRight,
          child: _SideSlider(
            value: brushSize,
            semanticLabel: context.l10n.videoEditorBrushSizeSemanticLabel,
            onChanged: _onChanged,
            onChangeEnd: _onChangeEnd,
          ),
        ),
      ],
    );
  }
}

/// Sets how strongly the selected censor tool hides an area: the areas drawn
/// next and the one drawn last with that tool.
class _CensorStrengthSlider extends StatelessWidget {
  const _CensorStrengthSlider();

  @override
  Widget build(BuildContext context) {
    final intensity = context.select(
      (VideoEditorDrawBloc b) => b.state.censorIntensity,
    );
    return _SideSlider(
      value: intensity,
      onChanged: (value) {
        final bloc = context.read<VideoEditorDrawBloc>()
          ..add(VideoEditorDrawCensorIntensityChanged(value));
        VideoEditorScope.of(context).paintEditor?.setCensorStrength(
          censorStrengthOf(bloc.state.selectedTool.config.mode, value),
        );
      },
    );
  }
}

/// The vertical slider at the right edge of the draw editor.
class _SideSlider extends StatelessWidget {
  const _SideSlider({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: min(300, constraints.maxHeight * 0.8),
          value: value,
          semanticLabel: semanticLabel,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isCensorMode});

  final bool isCensorMode;

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    final toolName = isCensorMode
        ? context.l10n.videoEditorCensorLabel
        : context.l10n.videoEditorDrawLabel;

    return Align(
      alignment: Alignment.topCenter,
      child:
          BlocSelector<
            VideoEditorDrawBloc,
            VideoEditorDrawState,
            ({bool canUndo, bool canRedo})
          >(
            selector: (state) =>
                (canUndo: state.canUndo, canRedo: state.canRedo),
            builder: (context, state) {
              return VideoEditorToolbar(
                closeSemanticLabel: context.l10n
                    .videoEditorDiscardToolChangesSemanticLabel(toolName),
                doneSemanticLabel: context.l10n
                    .videoEditorApplyToolChangesSemanticLabel(toolName),
                onClose: () => scope.editor?.closeSubEditor(),
                onDone: () => scope.paintEditor?.done(),
                center: Row(
                  spacing: 8,
                  children: [
                    DivineIconButton(
                      icon: .arrowArcLeft,
                      semanticLabel: context.l10n.videoEditorUndoSemanticLabel,
                      size: .small,
                      type: .ghostSecondary,
                      onPressed: state.canUndo
                          ? () => scope.paintEditor?.undoAction()
                          : null,
                    ),
                    DivineIconButton(
                      icon: .arrowArcRight,
                      semanticLabel: context.l10n.videoEditorRedoSemanticLabel,
                      size: .small,
                      type: .ghostSecondary,
                      onPressed: state.canRedo
                          ? () => scope.paintEditor?.redoAction()
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
