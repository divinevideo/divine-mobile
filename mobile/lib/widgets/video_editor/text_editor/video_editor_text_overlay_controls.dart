// ABOUTME: Top overlay controls for the text editor screen.
// ABOUTME: Displays close/done buttons and vertical font size slider.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

/// Top overlay controls for the text editor screen.
///
/// Displays close and done buttons at the top, plus style controls
/// (color, alignment, background) at the bottom.
/// Includes a vertical slider for font size on the right side.
///
/// Note: Font selector and color picker panels are rendered outside
/// the editor in the parent screen to maintain correct editor sizing.
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

        // Vertical slider for font size on the right side
        Align(
          alignment: .centerRight,
          child: Padding(
            padding: .fromLTRB(
              0,
              64 + MediaQuery.viewPaddingOf(context).top,
              10,
              16,
            ),
            child: const _FontSizeSlider(),
          ),
        ),
      ],
    );
  }
}

/// Vertical slider for adjusting font size.
///
/// Syncs the font scale with both the BLoC and the TextEditorState.
class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider();

  @override
  Widget build(BuildContext context) {
    final fontSize = context.select<VideoEditorTextBloc, double>(
      (bloc) => bloc.state.fontSize,
    );

    return VideoEditorVerticalSlider(
      value: fontSize,
      onChanged: (normalizedValue) {
        final textEditor = VideoTextEditorScope.of(context).editor;
        final textEditorConfigs = textEditor.configs.textEditor;

        // Convert normalized value (0-1) to font scale range
        final fontScaleRange =
            textEditorConfigs.maxFontScale - textEditorConfigs.minFontScale;
        final fontScale =
            textEditorConfigs.minFontScale + (normalizedValue * fontScaleRange);

        // Sync with TextEditor
        textEditor.fontScale = fontScale;

        // Update BLoC state
        context.read<VideoEditorTextBloc>().add(
          VideoEditorTextFontSizeChanged(normalizedValue),
        );
      },
    );
  }
}
