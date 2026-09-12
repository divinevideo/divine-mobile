// ABOUTME: Top overlay controls for the draw editor screen.
// ABOUTME: Displays close, undo, redo, and done buttons with accessibility.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

/// Top overlay controls for the draw editor screen.
///
/// Displays close, undo, redo, and done buttons with proper accessibility.
class VideoEditorDrawOverlayControls extends StatelessWidget {
  const VideoEditorDrawOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

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
                    .videoEditorDiscardToolChangesSemanticLabel(
                      context.l10n.videoEditorDrawLabel,
                    ),
                doneSemanticLabel: context.l10n
                    .videoEditorApplyToolChangesSemanticLabel(
                      context.l10n.videoEditorDrawLabel,
                    ),
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
