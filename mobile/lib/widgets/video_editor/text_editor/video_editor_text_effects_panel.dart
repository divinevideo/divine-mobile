// ABOUTME: Text style panel of the text editor — formatting, outline and
// ABOUTME: shadow — shown in place of the keyboard; keeps the bloc and the
// ABOUTME: live TextEditor in step (#9558).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/models/video_editor/text_formatting.dart';
import 'package:openvine/widgets/video_editor/text_editor/text_formatting_controls.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/text_effects_controls.dart';

/// The formatting, outline and shadow controls of the text editor.
///
/// Every change is written to the [TextEditorState] behind
/// [VideoTextEditorScope], so the text being typed shows it at once and the
/// layer the editor returns carries it, and to [VideoEditorTextBloc], which
/// the controls read.
class VideoEditorTextEffectsPanel extends StatelessWidget {
  /// Creates the panel.
  const VideoEditorTextEffectsPanel({super.key});

  void _applyEffects(BuildContext context, TextEffects effects) {
    final editor = VideoTextEditorScope.of(context).editor;
    editor
      ..setOutline(width: effects.outlineWidth, color: effects.outlineColor)
      ..setTextStyle(effects.applyToStyle(editor.selectedTextStyle));
    context.read<VideoEditorTextBloc>().add(
      VideoEditorTextEffectsChanged(effects),
    );
  }

  void _applyFormatting(BuildContext context, TextFormatting formatting) {
    final editor = VideoTextEditorScope.of(context).editor;
    editor
      ..setUppercase(formatting.uppercase)
      ..setCurvature(formatting.curvature)
      ..setTextStyle(formatting.applyToStyle(editor.selectedTextStyle));
    context.read<VideoEditorTextBloc>().add(
      VideoEditorTextFormattingChanged(formatting),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (effects, formatting, font) = context.select(
      (VideoEditorTextBloc bloc) => (
        bloc.state.effects,
        bloc.state.formatting,
        bloc.state.selectedFont,
      ),
    );
    // No horizontal padding: the color rows scroll out to the screen edge.
    return SingleChildScrollView(
      padding: .only(
        top: 24,
        bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 24,
        children: [
          TextFormattingControls(
            horizontalPadding: 16,
            formatting: formatting,
            fontLineHeight: _fontLineHeight(font()),
            onChanged: (formatting) => _applyFormatting(context, formatting),
          ),
          TextEffectsControls(
            horizontalPadding: 16,
            effects: effects,
            onChanged: (effects) => _applyEffects(context, effects),
          ),
        ],
      ),
    );
  }
}

/// The line height [font] sets itself, as a multiple of its size.
double _fontLineHeight(TextStyle font) {
  const size = 100.0;
  final painter = TextPainter(
    text: TextSpan(
      text: 'Ag',
      style: font.copyWith(fontSize: size),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final height = painter.preferredLineHeight / size;
  painter.dispose();
  return height;
}
