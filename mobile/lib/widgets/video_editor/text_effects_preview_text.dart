// ABOUTME: Preview text that draws an outline, a shadow and a gradient fill
// ABOUTME: the way a text layer does, for the title and caption style tiles
// ABOUTME: (#9558, #10398).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

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
    this.highlightRange,
    this.highlightColor,
    this.gradient,
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

  /// The part of [text] filled with [highlightColor], such as the word a
  /// karaoke caption is on. Only the fill changes; the outline and shadow
  /// stay as they are.
  final TextRange? highlightRange;

  /// The fill color of [highlightRange].
  final Color? highlightColor;

  /// A color gradient that fills the glyphs, [highlightRange] included, in
  /// place of the color of [style]; the outline and shadow keep their own
  /// colors.
  final TextGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final scale =
        (style.fontSize ?? VideoEditorConstants.baseFontSize) /
        VideoEditorConstants.baseFontSize;
    final shadows = [for (final shadow in effects.shadows) shadow.scale(scale)];

    Text line(TextStyle style) {
      final range = highlightRange;
      final color = highlightColor;
      final lit =
          range != null &&
          color != null &&
          range.isValid &&
          !range.isCollapsed &&
          range.end <= text.length;
      if (!lit) {
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      }
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: range.textBefore(text)),
            TextSpan(
              text: range.textInside(text),
              style: style.copyWith(color: color),
            ),
            TextSpan(text: range.textAfter(text)),
          ],
        ),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final gradient = this.gradient;
    final hasGradient = gradient != null && gradient.isValid;

    Widget fill(TextStyle style) {
      if (!hasGradient) return line(style);
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: gradient.createShader,
        child: line(style),
      );
    }

    if (!effects.hasOutline) {
      if (!hasGradient) return line(style.copyWith(shadows: shadows));
      // The gradient would tint the shadow as well, so clear glyphs cast it
      // beneath the gradient ones.
      return Stack(
        children: [
          line(style.copyWith(shadows: shadows, color: VineTheme.transparent)),
          fill(style),
        ],
      );
    }

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
        fill(style),
      ],
    );
  }
}
