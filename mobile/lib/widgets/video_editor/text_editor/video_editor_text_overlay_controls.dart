// ABOUTME: Top overlay controls for the text editor screen.
// ABOUTME: Displays close/done buttons.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

/// Top overlay controls for the text editor screen.
///
/// Displays close and done buttons at the top. Text has no size control here:
/// it is resized by pinching it on the editor canvas.
///
/// Note: The style bar, font selector and color picker panels are rendered
/// outside the editor in the parent screen to maintain correct editor sizing.
class VideoEditorTextOverlayControls extends StatelessWidget {
  const VideoEditorTextOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final textEditor = VideoTextEditorScope.of(context).editor;
    final isEmpty = context.select(
      (VideoEditorTextBloc bloc) => bloc.state.text.isEmpty,
    );

    return Stack(
      fit: .expand,
      children: [
        if (isEmpty)
          GestureDetector(
            behavior: .opaque,
            onTap: textEditor.focusNode.requestFocus,
            child: const IgnorePointer(child: SizedBox.expand()),
          ),
        // Close/Done buttons at the top
        Align(
          alignment: .topCenter,
          child: VideoEditorToolbar(
            closeSemanticLabel: context.l10n
                .videoEditorDiscardToolChangesSemanticLabel(
                  context.l10n.videoEditorTextLabel,
                ),
            doneSemanticLabel: context.l10n
                .videoEditorApplyToolChangesSemanticLabel(
                  context.l10n.videoEditorTextLabel,
                ),
            // This screen paints a fixed 61 % black scrim over everything
            // (`VideoEditorConstants.textEditorBackground`), so the close
            // button cannot follow the palette into light mode.
            closeType: .ghostOverMedia,
            onClose: () => VideoTextEditorScope.of(context).editor.close(),
            onDone: () => VideoTextEditorScope.of(context).editor.done(),
          ),
        ),
      ],
    );
  }
}
