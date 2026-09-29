// ABOUTME: Preview text that draws an outline and shadow the way a text layer
// ABOUTME: does, for the title and caption style tiles (#9558).

import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/text_effects.dart';

/// [text] in [style] with [effects]: the outline under the glyphs and the
/// shadow beneath both, scaled to the rendered font size as a text layer
/// scales them.
///
/// The shadow follows the bare glyphs rather than the outlined ones, which
/// is close enough at tile size and avoids an offscreen layer per tile.
class TextEffectsPreviewText extends StatelessWidget {
  /// Creates the preview text.
  const TextEffectsPreviewText(
    this.text, {
    required this.style,
    required this.effects,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  /// The text to show.
  final String text;

  /// The text style; its font size decides how large the effects draw.
  final TextStyle style;

  /// The outline and shadow to draw.
  final TextEffects effects;

  /// See [Text.textAlign].
  final TextAlign? textAlign;

  /// See [Text.maxLines].
  final int? maxLines;

  /// See [Text.overflow].
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final scale =
        (style.fontSize ?? VideoEditorConstants.baseFontSize) /
        VideoEditorConstants.baseFontSize;
    final shadows = [for (final shadow in effects.shadows) shadow.scale(scale)];

    Text line(TextStyle style) => Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (!effects.hasOutline) return line(style.copyWith(shadows: shadows));

    return Stack(
      children: [
        line(
          style.copyWith(
            shadows: shadows,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              // Half of the stroke lies inside the glyph, under the fill.
              ..strokeWidth = effects.outlineWidth * scale * 2
              ..strokeJoin = StrokeJoin.round
              ..color = effects.outlineColor,
          ),
        ),
        line(style),
      ],
    );
  }
}
