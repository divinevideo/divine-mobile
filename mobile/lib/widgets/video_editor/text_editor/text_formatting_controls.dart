// ABOUTME: Bold, italic, underline, strikethrough and capitals toggles, and
// ABOUTME: the line height, letter spacing and curve sliders of the text
// ABOUTME: editor.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_formatting.dart';

/// Edits how the letters of a title are set: a toggle each for bold, italic,
/// underline, strikethrough and capitals, a slider each for the line height
/// and the letter spacing, and a slider that bends the lines into arcs.
class TextFormattingControls extends StatelessWidget {
  /// Creates the controls for [formatting].
  const TextFormattingControls({
    required this.formatting,
    required this.fontLineHeight,
    required this.onChanged,
    this.horizontalPadding = 0,
    super.key,
  });

  /// The sheet margin the controls are inset by.
  final double horizontalPadding;

  /// The formatting shown.
  final TextFormatting formatting;

  /// The line height the font sets itself, as a multiple of its size; the
  /// line height slider rests there while [TextFormatting.lineHeight] is
  /// `null`.
  final double fontLineHeight;

  /// Called with the edited formatting.
  final ValueChanged<TextFormatting> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lineHeight = (formatting.lineHeight ?? fontLineHeight).clamp(
      TextFormatting.minLineHeight,
      TextFormatting.maxLineHeight,
    );
    String lineHeightLabel(double value) => value.toStringAsFixed(1);
    String letterSpacingLabel(double value) =>
        '${(value / TextFormatting.maxLetterSpacing * 100).round()}';
    String curvatureLabel(double value) => '${(value * 100).round()}';

    return Padding(
      padding: .symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 24,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FormattingToggle(
                icon: .textBold,
                semanticLabel: l10n.videoEditorTextBold,
                isOn: formatting.bold,
                onChanged: (value) =>
                    onChanged(formatting.copyWith(bold: value)),
              ),
              _FormattingToggle(
                icon: .textItalic,
                semanticLabel: l10n.videoEditorTextItalic,
                isOn: formatting.italic,
                onChanged: (value) =>
                    onChanged(formatting.copyWith(italic: value)),
              ),
              _FormattingToggle(
                icon: .textUnderline,
                semanticLabel: l10n.videoEditorTextUnderline,
                isOn: formatting.underline,
                onChanged: (value) =>
                    onChanged(formatting.copyWith(underline: value)),
              ),
              _FormattingToggle(
                icon: .textStrikethrough,
                semanticLabel: l10n.videoEditorTextStrikethrough,
                isOn: formatting.strikethrough,
                onChanged: (value) =>
                    onChanged(formatting.copyWith(strikethrough: value)),
              ),
              _FormattingToggle(
                icon: .textUppercase,
                semanticLabel: l10n.videoEditorTextUppercase,
                isOn: formatting.uppercase,
                onChanged: (value) =>
                    onChanged(formatting.copyWith(uppercase: value)),
              ),
            ],
          ),
          _FormattingSlider(
            title: l10n.videoEditorTextLineHeight,
            value: lineHeight,
            min: TextFormatting.minLineHeight,
            max: TextFormatting.maxLineHeight,
            // Steps of 0.1.
            divisions: 16,
            valueLabel: lineHeightLabel,
            onChanged: (value) =>
                onChanged(formatting.copyWith(lineHeight: value)),
          ),
          _FormattingSlider(
            title: l10n.videoEditorTextLetterSpacing,
            value: formatting.letterSpacing,
            max: TextFormatting.maxLetterSpacing,
            divisions: 24,
            valueLabel: letterSpacingLabel,
            onChanged: (value) =>
                onChanged(formatting.copyWith(letterSpacing: value)),
          ),
          _FormattingSlider(
            title: l10n.videoEditorTextCurve,
            value: formatting.curvature,
            min: -1,
            max: 1,
            // Steps of 5, with straight text in the middle.
            divisions: 40,
            valueLabel: curvatureLabel,
            onChanged: (value) =>
                onChanged(formatting.copyWith(curvature: value)),
          ),
        ],
      ),
    );
  }
}

class _FormattingSlider extends StatelessWidget {
  const _FormattingSlider({
    required this.title,
    required this.value,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.min = 0,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: VineTheme.labelMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                valueLabel(value),
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        DivineSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: title,
          semanticValue: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FormattingToggle extends StatelessWidget {
  const _FormattingToggle({
    required this.icon,
    required this.semanticLabel,
    required this.isOn,
    required this.onChanged,
  });

  final DivineIconName icon;
  final String semanticLabel;
  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: icon,
      semanticLabel: semanticLabel,
      semanticToggled: isOn,
      size: .small,
      type: isOn ? .primary : .secondary,
      showShadow: false,
      onPressed: () => onChanged(!isOn),
    );
  }
}
