// ABOUTME: The outline and drop shadow of an editor text — a title or a
// ABOUTME: caption — as two slider values with their colors, and how they map
// ABOUTME: onto the pro_image_editor TextLayer that renders them (#9558).

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextLayer;

/// An outline and a drop shadow that keep text readable over busy video.
///
/// The user sets each one with a slider ([outlineThickness],
/// [shadowStrength], both `0..1`, where `0` is off) and a color. On a
/// `TextLayer` they become `TextLayer.outlineWidth` and the shadows of its
/// `textStyle`, measured at the editor's base font size, so they grow with
/// the text and look the same in the editor, the export and burned-in
/// captions.
class TextEffects extends Equatable {
  /// Creates effects; the defaults draw neither.
  const TextEffects({
    this.outlineThickness = 0,
    this.outlineColor = defaultColor,
    this.shadowStrength = 0,
    this.shadowColor = defaultColor,
  });

  /// Reads the effects [layer] currently draws.
  ///
  /// The layer only stores pixel values, so the slider positions are mapped
  /// back from them; a shadow this app did not write lands on the nearest
  /// slider position.
  factory TextEffects.of(TextLayer layer) {
    final shadow = layer.textStyle?.shadows?.firstOrNull;
    return TextEffects(
      outlineThickness: layer.hasOutline
          ? (layer.outlineWidth / maxOutlineWidth).clamp(0.0, 1.0)
          : 0,
      outlineColor: layer.outlineColor,
      shadowStrength: shadow == null
          ? 0
          : max(
              shadow.blurRadius / _maxShadowBlur,
              shadow.offset.dy.abs() / _maxShadowOffset,
            ).clamp(0.0, 1.0),
      shadowColor: shadow?.color ?? defaultColor,
    );
  }

  /// Decodes effects from their [toJson] map. A missing or malformed map
  /// reads as no effects, so a style saved before #9558 still loads.
  factory TextEffects.fromJson(Object? json) {
    if (json is! Map) return none;
    final outlineThickness = json['outlineThickness'];
    final outlineColor = json['outlineColor'];
    final shadowStrength = json['shadowStrength'];
    final shadowColor = json['shadowColor'];
    return TextEffects(
      outlineThickness: outlineThickness is num
          ? outlineThickness.toDouble().clamp(0.0, 1.0)
          : 0,
      outlineColor: outlineColor is int
          ? colorFromArgb32(outlineColor)
          : defaultColor,
      shadowStrength: shadowStrength is num
          ? shadowStrength.toDouble().clamp(0.0, 1.0)
          : 0,
      shadowColor: shadowColor is int
          ? colorFromArgb32(shadowColor)
          : defaultColor,
    );
  }

  /// Effects that draw neither an outline nor a shadow.
  static const TextEffects none = TextEffects();

  /// The color both effects start with: black reads against the light text
  /// most titles and captions use. Fixed rather than adaptive, since the
  /// effects are drawn over the video, not an app surface.
  static const Color defaultColor = VineTheme.backgroundColor;

  /// The slider position an effect jumps to when the user picks its color
  /// while it is off.
  static const double defaultAmount = 0.5;

  /// Outline thickness at full slider travel, in logical pixels at the
  /// editor's base font size (`VideoEditorConstants.baseFontSize`).
  static const double maxOutlineWidth = 4;

  /// Shadow blur radius at full slider travel, at the base font size.
  static const double _maxShadowBlur = 10;

  /// Downward shadow offset at full slider travel, at the base font size.
  static const double _maxShadowOffset = 4;

  /// Outline slider position, `0..1`; `0` draws no outline.
  final double outlineThickness;

  /// Outline color.
  final Color outlineColor;

  /// Shadow slider position, `0..1`; `0` draws no shadow.
  final double shadowStrength;

  /// Shadow color.
  final Color shadowColor;

  /// Whether an outline is drawn.
  bool get hasOutline => outlineThickness > 0;

  /// Whether a shadow is drawn.
  bool get hasShadow => shadowStrength > 0;

  /// The outline thickness `TextLayer.outlineWidth` takes, at the base font
  /// size.
  double get outlineWidth => outlineThickness * maxOutlineWidth;

  /// The shadows the text style takes, at the base font size.
  List<Shadow> get shadows => [
    if (hasShadow)
      Shadow(
        color: shadowColor,
        offset: Offset(0, shadowStrength * _maxShadowOffset),
        blurRadius: shadowStrength * _maxShadowBlur,
      ),
  ];

  /// [style] with these effects' shadows in place of its own.
  TextStyle applyToStyle(TextStyle style) => style.copyWith(shadows: shadows);

  /// [layer] drawing these effects; everything else about it is untouched.
  ///
  /// The shadows live on the layer's text style, so a layer without one gets
  /// the first catalogue font, the same fallback `TitleStyle.of` makes.
  TextLayer applyTo(TextLayer layer) => layer.copyWith(
    outlineWidth: outlineWidth,
    outlineColor: outlineColor,
    textStyle: applyToStyle(
      layer.textStyle ?? VideoEditorConstants.textFonts.first(),
    ),
  );

  /// These effects with the outline in [color], switched on at
  /// [defaultAmount] when it was off, since picking a color for an outline
  /// nobody can see would look broken.
  TextEffects withOutlineColor(Color color) => copyWith(
    outlineColor: color,
    outlineThickness: hasOutline ? null : defaultAmount,
  );

  /// These effects with the shadow in [color], switched on at
  /// [defaultAmount] when it was off.
  TextEffects withShadowColor(Color color) => copyWith(
    shadowColor: color,
    shadowStrength: hasShadow ? null : defaultAmount,
  );

  /// Encodes these effects for draft and database storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'outlineThickness': outlineThickness,
    'outlineColor': outlineColor.toARGB32(),
    'shadowStrength': shadowStrength,
    'shadowColor': shadowColor.toARGB32(),
  };

  /// Copy with the given fields replaced.
  TextEffects copyWith({
    double? outlineThickness,
    Color? outlineColor,
    double? shadowStrength,
    Color? shadowColor,
  }) => TextEffects(
    outlineThickness: outlineThickness ?? this.outlineThickness,
    outlineColor: outlineColor ?? this.outlineColor,
    shadowStrength: shadowStrength ?? this.shadowStrength,
    shadowColor: shadowColor ?? this.shadowColor,
  );

  @override
  List<Object?> get props => [
    outlineThickness,
    outlineColor,
    shadowStrength,
    shadowColor,
  ];
}
