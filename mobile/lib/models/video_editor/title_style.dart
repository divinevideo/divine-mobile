// ABOUTME: The look of a free-form text overlay — font, colors, background
// ABOUTME: mode, alignment, size and enter/leave animation — as one
// ABOUTME: serializable unit that can be lifted off a layer and applied to
// ABOUTME: another (#7742).

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_apply.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:openvine/utils/editor_text_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode, TextLayer;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// A title treatment: everything about a text overlay's look except the text
/// itself and where it sits on the canvas.
///
/// A text overlay has no style model of its own in a draft — its look lives
/// on the `pro_image_editor` [TextLayer] and its animation on
/// `Layer.animations`. This is the shape that look takes when the user saves
/// it: [TitleStyle.of] lifts it off a layer, [applyTo] writes it onto another,
/// and [toJson] / [fromJson] carry it through the database.
///
/// Position, rotation and pinch scale are deliberately not part of it: a
/// saved style is a look, and the next title lands wherever the user puts it.
/// The font-size slider ([fontScale]) is, because it is styling.
class TitleStyle extends Equatable {
  /// Creates a style.
  const TitleStyle({
    required this.fontIndex,
    required this.color,
    required this.background,
    required this.colorMode,
    this.customSecondaryColor = false,
    this.align = TextAlign.center,
    this.fontScale = 1,
    this.enter = const [],
    this.leave = const [],
    this.enterPoint,
    this.leavePoint,
  });

  /// The look [layer] currently has.
  ///
  /// A layer whose font is not one of the editor's catalogue fonts (an old
  /// draft, say) maps to the first catalogue font, the same fallback the text
  /// editor makes when it opens such a layer.
  factory TitleStyle.of(TextLayer layer) {
    final points = LayerSlidePoints.of(layer);
    return TitleStyle(
      fontIndex: max(0, editorTextFontIndexFor(layer.textStyle?.fontFamily)),
      color: layer.color,
      background: layer.background,
      colorMode: layer.colorMode,
      customSecondaryColor: layer.customSecondaryColor,
      align: layer.align,
      fontScale: layer.fontScale,
      enter: layer.divineEnterAnimations,
      leave: layer.divineLeaveAnimations,
      enterPoint: points.enter,
      leavePoint: points.leave,
    );
  }

  /// Decodes a style from its [toJson] map, or `null` when the map is absent
  /// or malformed, so one unreadable row never hides the others.
  static TitleStyle? fromJson(Object? json) {
    if (json is! Map) return null;
    final fontIndex = json['fontIndex'];
    final color = json['color'];
    final background = json['background'];
    if (fontIndex is! int || color is! int || background is! int) return null;

    final enter = _animationsFromJson(json['enter']);
    final leave = _animationsFromJson(json['leave']);
    if (enter == null || leave == null) return null;

    final fontScale = json['fontScale'];
    if (fontScale != null && fontScale is! num) return null;

    return TitleStyle(
      fontIndex: fontIndex,
      color: colorFromArgb32(color),
      background: colorFromArgb32(background),
      colorMode: LayerBackgroundMode.values.firstWhere(
        (mode) => mode.name == json['colorMode'],
        orElse: () => LayerBackgroundMode.backgroundAndColor,
      ),
      customSecondaryColor: json['customSecondaryColor'] == true,
      align: TextAlign.values.firstWhere(
        (align) => align.name == json['align'],
        orElse: () => TextAlign.center,
      ),
      fontScale: (fontScale as num?)?.toDouble() ?? 1,
      enter: enter,
      leave: leave,
      enterPoint: _offsetFromJson(json['enterPoint']),
      leavePoint: _offsetFromJson(json['leavePoint']),
    );
  }

  /// Index into [VideoEditorConstants.textFonts].
  final int fontIndex;

  /// Text color, as the layer stores it.
  final Color color;

  /// Background color, as the layer stores it.
  final Color background;

  /// How [color] and [background] combine on the layer.
  final LayerBackgroundMode colorMode;

  /// Whether the layer's secondary color was picked by hand rather than
  /// derived from the primary one; the text editor reads it back on edit.
  final bool customSecondaryColor;

  /// Text alignment within the layer.
  final TextAlign align;

  /// Multiplier on the editor's base font size — the font-size slider.
  final double fontScale;

  /// Animations played when the layer appears.
  final List<pve.LayerAnimation> enter;

  /// Animations played when the layer disappears.
  final List<pve.LayerAnimation> leave;

  /// Where the enter slide starts, as a canvas fraction; `null` slides in
  /// from a canvas edge. See [LayerSlidePoints].
  final Offset? enterPoint;

  /// Where the leave slide ends, as a canvas fraction; `null` slides out to a
  /// canvas edge.
  final Offset? leavePoint;

  /// The font, resolved and index-clamped so a stale row still renders.
  TextFont get font =>
      VideoEditorConstants.textFonts[fontIndex.clamp(
        0,
        VideoEditorConstants.textFonts.length - 1,
      )];

  /// Whether the style draws anything behind the text.
  bool get hasBackground => colorMode != LayerBackgroundMode.onlyColor;

  /// The custom slide points, in the shape the layer stores them.
  LayerSlidePoints get slidePoints =>
      LayerSlidePoints(enter: enterPoint, leave: leavePoint);

  /// [layer] restyled with this look. Its text, position, rotation, pinch
  /// scale and timeline start are untouched; its end time is re-resolved
  /// for the leave animation the way the animation sheet does it (see
  /// `LayerAnimationApply.withDivineAnimations`).
  ///
  /// [canvasSize] is the canvas a custom slide point is resolved against for
  /// the in-editor preview; [totalDuration] is the true total video duration.
  TextLayer applyTo(
    TextLayer layer, {
    required Size canvasSize,
    required Duration totalDuration,
  }) {
    final restyled = layer.copyWith(
      textStyle: font(),
      color: color,
      background: background,
      colorMode: colorMode,
      customSecondaryColor: customSecondaryColor,
      align: align,
      fontScale: fontScale,
    );
    // `TextLayer.copyWith` returns a `TextLayer`, so the animation write —
    // typed on the base `Layer` — hands back the same subtype.
    return restyled.withDivineAnimations(
      enter: enter,
      leave: leave,
      points: slidePoints,
      canvasSize: canvasSize,
      totalDuration: totalDuration,
    ) as TextLayer;
  }

  /// Encodes this style for database storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'fontIndex': fontIndex,
    'color': color.toARGB32(),
    'background': background.toARGB32(),
    'colorMode': colorMode.name,
    'customSecondaryColor': customSecondaryColor,
    'align': align.name,
    'fontScale': fontScale,
    'enter': [for (final animation in enter) animation.toMap()],
    'leave': [for (final animation in leave) animation.toMap()],
    if (enterPoint case final point?) 'enterPoint': _offsetToJson(point),
    if (leavePoint case final point?) 'leavePoint': _offsetToJson(point),
  };

  @override
  List<Object?> get props => [
    fontIndex,
    color,
    background,
    colorMode,
    customSecondaryColor,
    align,
    fontScale,
    enter,
    leave,
    enterPoint,
    leavePoint,
  ];
}

/// Decodes a list of [pve.LayerAnimation] maps; `null` when [json] is not a
/// list or any entry does not parse — a half-read animation would play
/// something the user never saved.
///
/// Read by hand rather than through `LayerAnimation.fromMap`, which throws
/// on an enum name this build does not know or a field of the wrong shape;
/// a stored row is data, so an unreadable one is reported, not thrown.
List<pve.LayerAnimation>? _animationsFromJson(Object? json) {
  if (json == null) return const [];
  if (json is! List) return null;
  final animations = <pve.LayerAnimation>[];
  for (final entry in json) {
    final animation = _animationFromJson(entry);
    if (animation == null) return null;
    animations.add(animation);
  }
  return animations;
}

/// One entry of [_animationsFromJson], in the shape `LayerAnimation.toMap`
/// writes; `null` when it does not parse.
pve.LayerAnimation? _animationFromJson(Object? json) {
  if (json is! Map) return null;
  final type = pve.LayerAnimationType.values.asNameMap()[json['type']];
  final phase = pve.AnimationPhase.values.asNameMap()[json['phase']];
  final durationUs = json['durationUs'];
  if (type == null || phase == null || durationUs is! int) return null;

  final curveName = json['curve'];
  final curve = curveName == null
      ? pve.AnimationCurve.linear
      : pve.AnimationCurve.values.asNameMap()[curveName];
  if (curve == null) return null;

  final directionName = json['slideDirection'];
  final slideDirection = directionName == null
      ? null
      : pve.SlideDirection.values.asNameMap()[directionName];
  if (directionName != null && slideDirection == null) return null;
  // A slide needs a direction: the custom point is stored on the style, not
  // on the animation, so one without a direction has nowhere to travel from.
  if (type == pve.LayerAnimationType.slide && slideDirection == null) {
    return null;
  }

  final scaleFrom = json['scaleFrom'];
  if (scaleFrom != null && scaleFrom is! num) return null;

  return pve.LayerAnimation(
    type: type,
    phase: phase,
    duration: Duration(microseconds: durationUs),
    curve: curve,
    slideDirection: slideDirection,
    scaleFrom: (scaleFrom as num?)?.toDouble(),
  );
}

Map<String, Object?> _offsetToJson(Offset offset) => <String, Object?>{
  'dx': offset.dx,
  'dy': offset.dy,
};

Offset? _offsetFromJson(Object? json) {
  if (json is! Map) return null;
  final dx = json['dx'];
  final dy = json['dy'];
  if (dx is! num || dy is! num) return null;
  return Offset(dx.toDouble(), dy.toDouble());
}
