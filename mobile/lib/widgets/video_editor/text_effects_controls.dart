// ABOUTME: Outline and shadow controls — a slider and a color row for each —
// ABOUTME: shared by the text editor and the custom caption style (#9558).

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

/// Edits the outline and the shadow of a text: each gets a slider for its
/// thickness or strength, where the far left is off, and a color row.
///
/// Place it without horizontal padding around it: the color rows scroll out
/// to the edge of the sheet, and [horizontalPadding] insets everything else.
class TextEffectsControls extends StatelessWidget {
  /// Creates the controls for [effects].
  const TextEffectsControls({
    required this.effects,
    required this.onChanged,
    this.horizontalPadding = 0,
    super.key,
  });

  /// The sheet margin the labels and sliders are inset by, and the color
  /// rows' tiles line up with.
  final double horizontalPadding;

  /// The outline and shadow shown.
  final TextEffects effects;

  /// Called with the edited effects.
  final ValueChanged<TextEffects> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 24,
      children: [
        _EffectSection(
          horizontalPadding: horizontalPadding,
          title: l10n.videoEditorTextOutline,
          amountLabel: l10n.videoEditorTextOutlineThickness,
          colorLabel: l10n.videoEditorTextOutlineColor,
          amount: effects.outlineThickness,
          color: effects.outlineColor,
          onAmountChanged: (value) =>
              onChanged(effects.copyWith(outlineThickness: value)),
          onColorSelected: (color) =>
              onChanged(effects.withOutlineColor(color)),
        ),
        _EffectSection(
          horizontalPadding: horizontalPadding,
          title: l10n.videoEditorTextShadow,
          amountLabel: l10n.videoEditorTextShadowStrength,
          colorLabel: l10n.videoEditorTextShadowColor,
          amount: effects.shadowStrength,
          color: effects.shadowColor,
          onAmountChanged: (value) =>
              onChanged(effects.copyWith(shadowStrength: value)),
          onColorSelected: (color) => onChanged(effects.withShadowColor(color)),
        ),
      ],
    );
  }
}

class _EffectSection extends StatelessWidget {
  const _EffectSection({
    required this.horizontalPadding,
    required this.title,
    required this.amountLabel,
    required this.colorLabel,
    required this.amount,
    required this.color,
    required this.onAmountChanged,
    required this.onColorSelected,
  });

  /// Slider steps; also keeps a value read back from a layer on a step.
  static const _divisions = 20;

  final double horizontalPadding;
  final String title;
  final String amountLabel;
  final String colorLabel;
  final double amount;
  final Color color;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<Color> onColorSelected;

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showFullColorPicker(context, initialColor: color);
    if (picked != null) onColorSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final inset = EdgeInsets.symmetric(horizontal: horizontalPadding);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Padding(
          padding: inset,
          child: Row(
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
                  '${(amount * 100).round()}',
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: inset,
          child: DivineSlider(
            value: amount,
            divisions: _divisions,
            semanticLabel: amountLabel,
            onChanged: onAmountChanged,
          ),
        ),
        const SizedBox(height: 12),
        VideoEditorColorRow(
          padding: inset,
          semanticLabel: colorLabel,
          selected: color,
          onSelected: onColorSelected,
          onCustom: () => _pickCustom(context),
        ),
      ],
    );
  }
}
