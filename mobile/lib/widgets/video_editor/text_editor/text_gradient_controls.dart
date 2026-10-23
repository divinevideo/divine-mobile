// ABOUTME: Controls for a color gradient across the letters of a text — the
// ABOUTME: ready-made gradients, its colors and its direction (#10398).

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_gradient_presets.dart';
import 'package:openvine/widgets/color_swatch_button.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

/// Edits [gradient]: a row of ready-made gradients, a row of its colors that
/// opens the color picker on tap and grows or shrinks at its end, and a row
/// of the directions it can run in.
///
/// Place it without horizontal padding around it: the rows scroll out to the
/// edge of the sheet, and [horizontalPadding] insets everything else.
class TextGradientControls extends StatelessWidget {
  /// Creates the controls for [gradient].
  const TextGradientControls({
    required this.gradient,
    required this.onChanged,
    this.horizontalPadding = 0,
    super.key,
  });

  /// The gradient shown.
  final TextGradient gradient;

  /// Called with the edited gradient.
  final ValueChanged<TextGradient> onChanged;

  /// The sheet margin the titles are inset by, and the rows' tiles line up
  /// with.
  final double horizontalPadding;

  Future<void> _changeColor(BuildContext context, int index) async {
    final picked = await showFullColorPicker(
      context,
      initialColor: gradient.colors[index],
    );
    if (picked == null || !context.mounted) return;
    onChanged(
      gradient.copyWith(colors: [...gradient.colors]..[index] = picked),
    );
  }

  Future<void> _addColor(BuildContext context) async {
    final picked = await showFullColorPicker(
      context,
      initialColor: gradient.colors.last,
    );
    if (picked == null || !context.mounted) return;
    // Stops fit the colors they were made for, so the colors space evenly.
    onChanged(
      TextGradient(colors: [...gradient.colors, picked], angle: gradient.angle),
    );
  }

  void _removeColor() {
    onChanged(
      TextGradient(
        colors: gradient.colors.sublist(0, gradient.colors.length - 1),
        angle: gradient.angle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inset = EdgeInsets.symmetric(horizontal: horizontalPadding);
    final colorCount = gradient.colors.length;
    final direction = TextGradientDirection.of(gradient.angle);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 24,
      children: [
        _Section(
          title: l10n.videoEditorTextGradientPresets,
          padding: inset,
          children: [
            for (final preset in TextGradientPreset.values)
              _GradientTile(
                gradient: preset.withAngle(gradient.angle),
                semanticLabel: preset.localizedName(l10n),
                selected: preset.matches(gradient),
                onTap: () => onChanged(preset.withAngle(gradient.angle)),
              ),
          ],
        ),
        _Section(
          title: l10n.videoEditorTextGradientColors,
          padding: inset,
          children: [
            for (var i = 0; i < colorCount; i++)
              _ColorTile(
                color: gradient.colors[i],
                onTap: () => _changeColor(context, i),
              ),
            _IconTile(
              icon: .minus,
              semanticLabel: l10n.videoEditorTextGradientRemoveColor,
              onTap: colorCount > VideoEditorConstants.minTextGradientColors
                  ? _removeColor
                  : null,
            ),
            _IconTile(
              icon: .plus,
              semanticLabel: l10n.videoEditorTextGradientAddColor,
              onTap: colorCount < VideoEditorConstants.maxTextGradientColors
                  ? () => _addColor(context)
                  : null,
            ),
          ],
        ),
        _Section(
          title: l10n.videoEditorTransitionDirection,
          padding: inset,
          children: [
            for (final option in TextGradientDirection.values)
              _IconTile(
                icon: option.icon,
                semanticLabel: option.localizedName(l10n),
                selected: option == direction,
                onTap: () => onChanged(gradient.copyWith(angle: option.angle)),
              ),
          ],
        ),
      ],
    );
  }
}

/// A [title] over a row of tiles that scrolls out to the edge of the sheet.
///
/// A screen reader hears the title as the label of the row, before its
/// tiles.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.padding,
    required this.children,
  });

  final String title;
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      spacing: 12,
      children: [
        Padding(
          padding: padding,
          child: ExcludeSemantics(
            child: Text(
              title,
              style: VineTheme.labelMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
        ),
        Semantics(
          container: true,
          label: title,
          child: SizedBox(
            height: VideoEditorColorRow.height,
            child: ListView.separated(
              scrollDirection: .horizontal,
              padding: padding,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ),
      ],
    );
  }
}

/// A tile in the shape of a [VideoEditorColorTile] holding [child], outlined
/// in the accent color when [selected].
class _Tile extends StatelessWidget {
  const _Tile({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.selected,
  });

  final String semanticLabel;

  /// Called when the tile is tapped; `null` disables it.
  final VoidCallback? onTap;

  /// Whether the tile shows the option in use; `null` for a tile that is an
  /// action rather than an option.
  final bool? selected;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onTap != null,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ?? false
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox.square(dimension: 24, child: child),
          ),
        ),
      ),
    );
  }
}

/// A ready-made gradient, shown on a circle.
class _GradientTile extends StatelessWidget {
  const _GradientTile({
    required this.gradient,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final TextGradient gradient;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      semanticLabel: semanticLabel,
      selected: selected,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient.swatch,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A color of the gradient, which opens the color picker to change it.
class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Tile(
      // Read like the palette's own picker tile: what it opens, then its
      // color.
      semanticLabel: l10n.videoEditorColorPickerSwatchSemanticLabel(
        l10n.videoEditorColorPickerSemanticLabel,
        ColorSwatchButton.rgbSemanticLabel(context, color),
      ),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// An action or a direction, shown as an icon.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.selected,
  });

  final DivineIconName icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      semanticLabel: semanticLabel,
      selected: selected,
      onTap: onTap,
      child: Center(
        child: DivineIcon(
          icon: icon,
          size: 20,
          color: onTap == null
              ? context.vineColors.disabled
              : context.vineColors.accentPositive,
        ),
      ),
    );
  }
}
