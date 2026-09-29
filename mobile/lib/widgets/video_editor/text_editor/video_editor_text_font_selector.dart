// ABOUTME: Inline font selector that replaces the keyboard.
// ABOUTME: Displays font options in a scrollable list matching keyboard height.

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_font_list.dart';

/// Inline font selector that replaces the keyboard.
///
/// Displays font options in a scrollable list, designed to match
/// the keyboard height for a smooth transition when toggling.
class VideoEditorTextFontSelector extends StatelessWidget {
  const VideoEditorTextFontSelector({super.key, this.onFontSelected});

  /// Callback when a font is selected. Receives the font's TextStyle.
  final ValueChanged<TextStyle>? onFontSelected;

  @override
  Widget build(BuildContext context) {
    final selectedFontIndex = context.select<VideoEditorTextBloc, int>(
      (bloc) => bloc.state.selectedFontIndex,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: min(380, constraints.maxHeight),
          child: VideoEditorFontList(
            selectedIndex: selectedFontIndex,
            onSelected: (index) {
              // Apply font via callback
              onFontSelected?.call(VideoEditorConstants.textFonts[index]());

              // Update BLoC state
              context.read<VideoEditorTextBloc>().add(
                VideoEditorTextFontSelected(index),
              );
            },
          ),
        );
      },
    );
  }
}
