// ABOUTME: Outline and shadow panel of the text editor, shown in place of the
// ABOUTME: keyboard; keeps the bloc and the live TextEditor in step (#9558).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/text_effects_controls.dart';

/// The outline and shadow controls of the text editor.
///
/// Every change is written to the [TextEditorState] behind
/// [VideoTextEditorScope], so the text being typed shows it at once and the
/// layer the editor returns carries it, and to [VideoEditorTextBloc], which
/// the controls read.
class VideoEditorTextEffectsPanel extends StatelessWidget {
  /// Creates the panel.
  const VideoEditorTextEffectsPanel({super.key});

  void _apply(BuildContext context, TextEffects effects) {
    final editor = VideoTextEditorScope.of(context).editor;
    editor
      ..setOutline(width: effects.outlineWidth, color: effects.outlineColor)
      ..setTextStyle(effects.applyToStyle(editor.selectedTextStyle));
    context.read<VideoEditorTextBloc>().add(
      VideoEditorTextEffectsChanged(effects),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effects = context.select(
      (VideoEditorTextBloc bloc) => bloc.state.effects,
    );
    // No horizontal padding: the color rows scroll out to the screen edge.
    return SingleChildScrollView(
      padding: .only(
        top: 24,
        bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: TextEffectsControls(
        horizontalPadding: 16,
        effects: effects,
        onChanged: (effects) => _apply(context, effects),
      ),
    );
  }
}
