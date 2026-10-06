// ABOUTME: Overlay controls for the draw editor screen: close, undo, redo and
// ABOUTME: done on top, and the strength slider while it hides areas.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

/// Overlay controls for the draw editor screen.
///
/// Displays close, undo, redo, and done buttons with proper accessibility,
/// and while the editor hides areas, a slider for how strongly they do.
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
          const Align(alignment: .centerRight, child: _CensorStrengthSlider()),
        _TopBar(isCensorMode: isCensorMode),
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
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: min(300, constraints.maxHeight * 0.8),
          value: intensity,
          onChanged: (value) {
            final bloc = context.read<VideoEditorDrawBloc>()
              ..add(VideoEditorDrawCensorIntensityChanged(value));
            VideoEditorScope.of(context).paintEditor?.setCensorStrength(
              censorStrengthOf(bloc.state.selectedTool.config.mode, value),
            );
          },
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
