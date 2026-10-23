// ABOUTME: Color panel of the text editor, shown in place of the keyboard: a
// ABOUTME: single color from the palette, or a color gradient across the
// ABOUTME: letters (#10398); keeps the bloc and the live TextEditor in step.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/text_gradient_controls.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

/// The color controls of the text editor: a Solid | Gradient toggle over the
/// palette or the gradient controls.
///
/// Every change is written to the [TextEditorState] behind
/// [VideoTextEditorScope], so the text being typed shows it at once and the
/// layer the editor returns carries it, and to [VideoEditorTextBloc], which
/// the controls read.
class VideoEditorTextColorPanel extends StatelessWidget {
  /// Creates the panel.
  const VideoEditorTextColorPanel({super.key});

  void _setColor(BuildContext context, Color color) {
    VideoTextEditorScope.of(context).editor.primaryColor = color;
    context.read<VideoEditorTextBloc>().add(
      VideoEditorTextColorSelected(color),
    );
  }

  void _setGradient(BuildContext context, TextGradient? gradient) {
    VideoTextEditorScope.of(context).editor.setGradient(gradient);
    context.read<VideoEditorTextBloc>().add(
      VideoEditorTextGradientChanged(gradient),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (color, gradient) = context.select(
      (VideoEditorTextBloc bloc) => (bloc.state.color, bloc.state.gradient),
    );
    return Column(
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const .fromLTRB(16, 24, 16, 0),
          child: _FillToggle(
            gradient: gradient != null,
            onChanged: (useGradient) => _setGradient(
              context,
              useGradient
                  ? context.read<VideoEditorTextBloc>().state.gradientToRestore
                  : null,
            ),
          ),
        ),
        if (gradient != null)
          SingleChildScrollView(
            // No horizontal padding: the rows scroll out to the screen edge.
            padding: .only(
              top: 24,
              bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: TextGradientControls(
              horizontalPadding: 16,
              gradient: gradient,
              onChanged: (gradient) => _setGradient(context, gradient),
            ),
          )
        else
          VideoEditorColorPickerSheet(
            selectedColor: color,
            onColorSelected: (color) => _setColor(context, color),
          ),
      ],
    );
  }
}

/// Solid | Gradient segmented toggle.
class _FillToggle extends StatelessWidget {
  const _FillToggle({required this.gradient, required this.onChanged});

  /// Whether the letters are filled with a gradient.
  final bool gradient;

  /// Called with whether the letters should be filled with a gradient, when
  /// the user picks the other segment.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.controlFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.controlOutline),
      ),
      child: Row(
        children: [
          _FillSegment(
            label: l10n.videoEditorTextFillSolid,
            selected: !gradient,
            onTap: () => onChanged(false),
          ),
          _FillSegment(
            label: l10n.videoEditorTextFillGradient,
            selected: gradient,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FillSegment extends StatelessWidget {
  const _FillSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// The accessibility floor for a tap target.
  static const double _minTapTarget = 48;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    // Picking the segment in use changes nothing.
    final onTap = selected ? null : this.onTap;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: _minTapTarget),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.controlSelectedFill : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colors.accentBrand : VineTheme.transparent,
              ),
            ),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: VineTheme.labelMediumFont(
                  color: selected ? colors.accentBrand : colors.mutedText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
