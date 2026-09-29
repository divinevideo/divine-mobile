// ABOUTME: Caption render style (font + colors + outline and shadow +
// ABOUTME: animation) and the serializable custom-style descriptor users
// ABOUTME: configure themselves.

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// A curated caption animation, chosen as one unit (the primitives are those
/// pro_video_editor renders natively, so preview and export always match).
///
/// Slide is intentionally excluded for captions: the renderer slides a layer
/// fully off the video frame, which reads as distracting for subtitles.
enum CaptionAnimationStyle {
  /// Cue appears and disappears instantly.
  none,

  /// Soft fade in and out.
  fade,

  /// Scales up with a bounce.
  pop,

  /// Scales up with an elastic spring.
  spring;

  /// The enter/leave animations this style resolves to.
  ({List<pve.LayerAnimation> enter, List<pve.LayerAnimation> leave})
  resolve() => switch (this) {
    CaptionAnimationStyle.none => (enter: const [], leave: const []),
    CaptionAnimationStyle.fade => (
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    CaptionAnimationStyle.pop => (
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 450),
          curve: pve.AnimationCurve.bounceOut,
          scaleFrom: 0.6,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionAnimationStyle.spring => (
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 600),
          curve: pve.AnimationCurve.elasticOut,
          scaleFrom: 0.3,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
  };

  /// Parses a serialized [name], defaulting to [fade] for unknown input.
  static CaptionAnimationStyle fromName(String? name) =>
      CaptionAnimationStyle.values.firstWhere(
        (style) => style.name == name,
        orElse: () => CaptionAnimationStyle.fade,
      );
}

/// A caption look: font, colors, and animation as one fixed render unit.
///
/// Built-in presets and user-defined custom styles both resolve to this;
/// [buildLayer] turns a cue into its burned-in editor layer.
class CaptionStyle {
  /// Creates a style.
  const CaptionStyle({
    required this.font,
    required this.color,
    required this.background,
    required this.colorMode,
    required this.enter,
    required this.leave,
    this.fontScale = 1,
    this.effects = TextEffects.none,
  });

  /// The Google Font this style renders with.
  final TextFont font;

  /// Text color.
  final Color color;

  /// Pill/background color (used when [colorMode] draws a background).
  final Color background;

  /// How [color] and [background] combine on the text layer.
  final LayerBackgroundMode colorMode;

  /// Animations played when a cue appears.
  final List<pve.LayerAnimation> enter;

  /// Animations played when a cue disappears.
  final List<pve.LayerAnimation> leave;

  /// Multiplier on the editor's base font size.
  final double fontScale;

  /// The outline and shadow drawn around the caption text.
  final TextEffects effects;

  /// Vertical placement of caption cues: fraction of the canvas height below
  /// center, keeping captions in the lower third without touching the edge.
  static const double _bottomOffsetFactor = 0.32;

  /// Builds the burned-in editor layer for [cue].
  TextLayer buildLayer(
    CaptionCue cue, {
    required Size bodySize,
  }) {
    return TextLayer(
      text: cue.text,
      textStyle: effects.applyToStyle(font()),
      outlineWidth: effects.outlineWidth,
      outlineColor: effects.outlineColor,
      colorMode: colorMode,
      color: color,
      background: background,
      align: TextAlign.center,
      fontScale: fontScale,
      offset: Offset(0, bodySize.shortestSide * _bottomOffsetFactor),
      startTime: cue.start,
      endTime: cue.end,
      animations: [...enter, ...leave].toLayerAnimations(),
      meta: {
        VideoEditorConstants.captionCueMetaKey: true,
        VideoEditorConstants.captionCueIdMetaKey: cue.id,
      },
    );
  }
}

/// A user-configured caption style, serialized into the caption track.
///
/// Unlike a built-in preset (referenced by id), a custom style stores its own
/// font, colors, and animation choice so it survives draft round-trips.
class CaptionCustomStyle extends Equatable {
  /// Creates a custom style.
  const CaptionCustomStyle({
    required this.fontIndex,
    required this.color,
    required this.background,
    required this.colorMode,
    required this.animation,
    this.fontScale = 1,
    this.effects = TextEffects.none,
  });

  /// The default custom style: the first font, white on a dark pill, fading.
  factory CaptionCustomStyle.initial() => CaptionCustomStyle(
    fontIndex: 0,
    color: VideoEditorConstants.colors[0],
    background: VineTheme.scrim65,
    colorMode: LayerBackgroundMode.backgroundAndColor,
    animation: CaptionAnimationStyle.fade,
  );

  /// Decodes a custom style from its [toJson] map, or `null` when the map is
  /// absent or malformed (an old draft still opens with a preset).
  static CaptionCustomStyle? fromJson(Object? json) {
    if (json is! Map) return null;
    final fontIndex = json['fontIndex'];
    final color = json['color'];
    final background = json['background'];
    if (fontIndex is! int || color is! int || background is! int) return null;
    return CaptionCustomStyle(
      fontIndex: fontIndex,
      color: colorFromArgb32(color),
      background: colorFromArgb32(background),
      colorMode: LayerBackgroundMode.values.firstWhere(
        (mode) => mode.name == json['colorMode'],
        orElse: () => LayerBackgroundMode.backgroundAndColor,
      ),
      animation: CaptionAnimationStyle.fromName(json['animation'] as String?),
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1,
      effects: TextEffects.fromJson(json['effects']),
    );
  }

  /// Index into [VideoEditorConstants.textFonts].
  final int fontIndex;

  /// Text color.
  final Color color;

  /// Pill/background color.
  final Color background;

  /// How [color] and [background] combine.
  final LayerBackgroundMode colorMode;

  /// The chosen animation.
  final CaptionAnimationStyle animation;

  /// Multiplier on the editor's base font size.
  final double fontScale;

  /// The outline and shadow drawn around the caption text.
  final TextEffects effects;

  /// Whether the style draws a background pill.
  bool get hasBackground => colorMode != LayerBackgroundMode.onlyColor;

  /// The font, resolved and index-clamped so a stale draft still renders.
  TextFont get font =>
      VideoEditorConstants.textFonts[fontIndex.clamp(
        0,
        VideoEditorConstants.textFonts.length - 1,
      )];

  /// Resolves this descriptor into a renderable [CaptionStyle].
  CaptionStyle resolve() {
    final animations = animation.resolve();
    return CaptionStyle(
      font: font,
      color: color,
      background: background,
      colorMode: colorMode,
      fontScale: fontScale,
      effects: effects,
      enter: animations.enter,
      leave: animations.leave,
    );
  }

  /// Encodes this style for draft/history storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'fontIndex': fontIndex,
    'color': color.toARGB32(),
    'background': background.toARGB32(),
    'colorMode': colorMode.name,
    'animation': animation.name,
    'fontScale': fontScale,
    'effects': effects.toJson(),
  };

  /// Copy with the given fields replaced.
  CaptionCustomStyle copyWith({
    int? fontIndex,
    Color? color,
    Color? background,
    LayerBackgroundMode? colorMode,
    CaptionAnimationStyle? animation,
    double? fontScale,
    TextEffects? effects,
  }) => CaptionCustomStyle(
    fontIndex: fontIndex ?? this.fontIndex,
    color: color ?? this.color,
    background: background ?? this.background,
    colorMode: colorMode ?? this.colorMode,
    animation: animation ?? this.animation,
    fontScale: fontScale ?? this.fontScale,
    effects: effects ?? this.effects,
  );

  @override
  List<Object?> get props => [
    fontIndex,
    color,
    background,
    colorMode,
    animation,
    fontScale,
    effects,
  ];
}
