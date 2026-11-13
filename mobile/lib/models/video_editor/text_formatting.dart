// ABOUTME: Line height, letter spacing, bold, italic, underline,
// ABOUTME: strikethrough, capitals and curve of an editor title, and how they
// ABOUTME: map onto the pro_image_editor TextLayer that renders them.

import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextLayer;

/// How the letters of a title are set, apart from their font, colors and
/// effects.
///
/// Everything but [uppercase] and [curvature] lives on the layer's text
/// style. [uppercase] is `TextLayer.uppercase`, which draws capitals while
/// the typed text is kept, so switching it off brings the typed letters back;
/// [curvature] is `TextLayer.curvature`, which bends the lines into arcs.
class TextFormatting extends Equatable {
  /// Creates formatting; the defaults leave the font as it is.
  const TextFormatting({
    this.lineHeight,
    this.letterSpacing = 0,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.uppercase = false,
    this.curvature = 0,
  });

  /// Reads the formatting [layer] currently has.
  factory TextFormatting.of(TextLayer layer) {
    final style = layer.textStyle;
    final decoration = style?.decoration ?? TextDecoration.none;
    return TextFormatting(
      lineHeight: style?.height,
      letterSpacing: (style?.letterSpacing ?? 0).clamp(0.0, maxLetterSpacing),
      bold: (style?.fontWeight ?? FontWeight.normal).value >= _boldWeight,
      italic: style?.fontStyle == FontStyle.italic,
      underline: decoration.contains(TextDecoration.underline),
      strikethrough: decoration.contains(TextDecoration.lineThrough),
      uppercase: layer.uppercase,
      curvature: layer.curvature.clamp(-1.0, 1.0),
    );
  }

  /// Decodes formatting from its [toJson] map. A missing or malformed map
  /// reads as no formatting, so a style saved before it existed still loads.
  factory TextFormatting.fromJson(Object? json) {
    if (json is! Map) return none;
    final lineHeight = json['lineHeight'];
    final letterSpacing = json['letterSpacing'];
    final curvature = json['curvature'];
    return TextFormatting(
      lineHeight: lineHeight is num && lineHeight.isFinite
          ? lineHeight.toDouble().clamp(minLineHeight, maxLineHeight)
          : null,
      letterSpacing: letterSpacing is num && letterSpacing.isFinite
          ? letterSpacing.toDouble().clamp(0.0, maxLetterSpacing)
          : 0,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      strikethrough: json['strikethrough'] == true,
      uppercase: json['uppercase'] == true,
      curvature: curvature is num && curvature.isFinite
          ? curvature.toDouble().clamp(-1.0, 1.0)
          : 0,
    );
  }

  /// Formatting that leaves the font as it is.
  static const TextFormatting none = TextFormatting();

  /// The tightest line height the slider offers, as a multiple of the font
  /// size.
  static const double minLineHeight = 0.8;

  /// The loosest line height the slider offers, as a multiple of the font
  /// size.
  static const double maxLineHeight = 2.4;

  /// The widest letter spacing the slider offers, in logical pixels at the
  /// editor's base font size (`VideoEditorConstants.baseFontSize`): half a
  /// letter. The layer grows it with the text, like the outline.
  static const double maxLetterSpacing = VideoEditorConstants.baseFontSize / 2;

  /// The weight bold text is set in. Fonts that ship no bold face get one
  /// drawn from their regular face.
  static const FontWeight _boldFontWeight = FontWeight.w700;

  /// The weight from which a layer's text counts as bold.
  static const int _boldWeight = 600;

  /// The height of a line as a multiple of the font size, or `null` for the
  /// height the font itself sets.
  final double? lineHeight;

  /// Extra space after each letter, in logical pixels at the editor's base
  /// font size; `0` adds none.
  final double letterSpacing;

  /// Whether the letters are bold.
  final bool bold;

  /// Whether the letters are italic.
  final bool italic;

  /// Whether the text is underlined.
  final bool underline;

  /// Whether the text is struck through.
  final bool strikethrough;

  /// Whether the text is drawn in capital letters.
  final bool uppercase;

  /// How far the lines bend into arcs, `-1..1`: `0` keeps them straight,
  /// positive values bend them into an arch and negative ones into a bowl.
  final double curvature;

  /// The underline and strikethrough as one decoration.
  TextDecoration get decoration => TextDecoration.combine([
    if (underline) TextDecoration.underline,
    if (strikethrough) TextDecoration.lineThrough,
  ]);

  /// [style] set with this formatting; its font, color and shadows are
  /// untouched.
  ///
  /// Weight, slant and decoration are written even when they are off, so
  /// turning one off on a style that has it takes it away.
  TextStyle applyToStyle(TextStyle style) => style.copyWith(
    height: lineHeight,
    letterSpacing: letterSpacing,
    fontWeight: bold ? _boldFontWeight : FontWeight.normal,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    decoration: decoration,
  );

  /// [layer] set with this formatting; everything else about it is
  /// untouched.
  ///
  /// A layer without a text style gets the first catalogue font, the same
  /// fallback `TextEffects.applyTo` makes.
  TextLayer applyTo(TextLayer layer) => layer.copyWith(
    textStyle: applyToStyle(
      layer.textStyle ?? VideoEditorConstants.textFonts.first(),
    ),
    uppercase: uppercase,
    curvature: curvature,
  );

  /// Encodes this formatting for database storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'lineHeight': ?lineHeight,
    'letterSpacing': letterSpacing,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    'strikethrough': strikethrough,
    'uppercase': uppercase,
    'curvature': curvature,
  };

  /// Copy with the given fields replaced.
  TextFormatting copyWith({
    double? lineHeight,
    double? letterSpacing,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? uppercase,
    double? curvature,
  }) => TextFormatting(
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strikethrough: strikethrough ?? this.strikethrough,
    uppercase: uppercase ?? this.uppercase,
    curvature: curvature ?? this.curvature,
  );

  @override
  List<Object?> get props => [
    lineHeight,
    letterSpacing,
    bold,
    italic,
    underline,
    strikethrough,
    uppercase,
    curvature,
  ];
}
