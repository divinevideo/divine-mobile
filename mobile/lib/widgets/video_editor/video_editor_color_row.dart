// ABOUTME: A horizontally scrolling row of color tiles — the custom color
// ABOUTME: picker, then the editor palette — for caption and text styling.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/color_swatch_button.dart';

/// One scrolling row of color tiles: the custom color picker first, then
/// every color of [VideoEditorConstants.colors].
///
/// The row is meant to span the full width of its sheet so its tiles scroll
/// out at the screen edge instead of being cut off at the sheet's padding;
/// [padding] insets the first and last tile to line up with the content
/// around it.
class VideoEditorColorRow extends StatelessWidget {
  /// Creates a color row.
  const VideoEditorColorRow({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    super.key,
  });

  /// Height of the row, which is the height of one tile.
  static const double height = 44;

  /// The color in use. A color outside the palette shows on the picker tile.
  final Color selected;

  /// Called with the palette color the user tapped.
  final ValueChanged<Color> onSelected;

  /// Called when the user taps the custom color picker tile.
  final VoidCallback onCustom;

  /// Space before the first and after the last tile.
  final EdgeInsetsGeometry padding;

  /// What the row is for, announced before its tiles (e.g. "Outline color").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final onPalette = VideoEditorConstants.colors.any(
      (color) => color.toARGB32() == selected.toARGB32(),
    );
    final row = SizedBox(
      height: height,
      child: ListView(
        scrollDirection: .horizontal,
        padding: padding,
        children: [
          // A custom (non-palette) color marks the picker tile as selected.
          VideoEditorColorTile(
            isCustom: true,
            color: selected,
            selected: !onPalette,
            onTap: onCustom,
          ),
          for (final color in VideoEditorConstants.colors) ...[
            const SizedBox(width: 12),
            VideoEditorColorTile(
              color: color,
              selected: color.toARGB32() == selected.toARGB32(),
              onTap: () => onSelected(color),
            ),
          ],
        ],
      ),
    );
    if (semanticLabel == null) return row;
    return Semantics(container: true, label: semanticLabel, child: row);
  }
}

/// A color tile: a rounded surface tile framing the color circle, outlined
/// in the accent color when selected — the same treatment as the text
/// editor's color control.
///
/// The custom tile shows only a paint brush, never the picked color, so the
/// brush stays visible whatever color was picked; [color] then only feeds
/// its screen-reader label.
class VideoEditorColorTile extends StatelessWidget {
  /// Creates a color tile.
  const VideoEditorColorTile({
    required this.color,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
    super.key,
  });

  /// The color shown; for the custom tile, the custom color in use.
  final Color color;

  /// Whether this is the color in use.
  final bool selected;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// Whether this is the tile that opens the custom color picker.
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final rgbLabel = ColorSwatchButton.rgbSemanticLabel(context, color);
    final semanticLabel = isCustom
        ? context.l10n.videoEditorColorPickerSwatchSemanticLabel(
            context.l10n.videoEditorColorPickerSemanticLabel,
            rgbLabel,
          )
        : rgbLabel;
    return Semantics(
      label: semanticLabel,
      button: true,
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
              color: selected
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: isCustom
                ? SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: DivineIcon(
                        icon: DivineIconName.paintBrush,
                        color: context.vineColors.accentPositive,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
