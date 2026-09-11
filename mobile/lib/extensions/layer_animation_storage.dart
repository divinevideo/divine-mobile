// ABOUTME: Bridges a pro_image_editor Layer's typed enter/leave animations to
// ABOUTME: the pro_video_editor LayerAnimation the export pipeline consumes,
// ABOUTME: including the layer geometry a custom slide point is resolved in.

import 'dart:ui';

import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// The two packages model layer animations identically (same enum names and
/// `toMap` keys), so a map round-trip converts losslessly between them. This is
/// the single boundary where pro_image_editor's [LayerAnimation] (used for
/// editing + the in-editor preview) becomes pro_video_editor's (used at export).
///
/// The round-trip relies on that schema parity; a future bump of either package
/// that changes its `toMap` keys or enum names would break it silently, so it is
/// guarded by the round-trip unit test in `layer_animation_storage_test.dart` —
/// re-run that test when bumping either dependency.
///
/// `slideFrom` is the one field that does **not** round-trip, because the two
/// packages measure it in different spaces: pro_image_editor's is a canvas
/// pixel offset from the canvas centre, pro_video_editor's is the layer's
/// top-left corner in video pixels. It is dropped on the way out and rebuilt
/// from [LayerSlidePoints] by [LayerExportAnimations.divineAnimationsForExport],
/// so a canvas-space value can never be handed to the renderer as if it were a
/// video-space one.
extension LayerAnimationStorage on Layer {
  /// This layer's enter/leave animations as pro_video_editor models, for the
  /// export pipeline. Empty when the layer has no animations.
  ///
  /// Reads [Layer.effectiveAnimations] (not the raw [Layer.animations]) so a
  /// layer that only carries the legacy `enterDuration` / `exitDuration` fade
  /// fields still exports the fade pro_image_editor synthesizes for the preview
  /// — keeping export and preview correct-by-construction.
  List<pve.LayerAnimation> get divineAnimations => effectiveAnimations
      .map((a) => pve.LayerAnimation.fromMap(_withoutSlideFrom(a.toMap())))
      .toList();

  /// All [pve.AnimationPhase.animateIn] animations. A layer can combine several
  /// per phase (e.g. a fade and a slide), which the renderers compose. Empty
  /// when the layer has no enter animation.
  List<pve.LayerAnimation> get divineEnterAnimations => [
    for (final animation in divineAnimations)
      if (animation.phase == pve.AnimationPhase.animateIn) animation,
  ];

  /// All [pve.AnimationPhase.animateOut] animations. Empty when the layer has
  /// no leave animation.
  List<pve.LayerAnimation> get divineLeaveAnimations => [
    for (final animation in divineAnimations)
      if (animation.phase == pve.AnimationPhase.animateOut) animation,
  ];
}

/// Converts the picker's pro_video_editor animations into pro_image_editor
/// [LayerAnimation]s for assignment to [Layer.animations] — the inverse of
/// [LayerAnimationStorage.divineAnimations].
extension DivineLayerAnimationList on List<pve.LayerAnimation> {
  /// This list as pro_image_editor [LayerAnimation]s for [Layer.animations].
  ///
  /// [points] carries each phase's custom slide point, which is written onto
  /// the slide animations in canvas pixels — the space pro_image_editor's own
  /// `slideFrom` is measured in — so the in-editor preview travels the path the
  /// export will. [canvasSize] is the canvas those pixels are relative to.
  ///
  /// The stored fractions stay the source of truth for the export; the pixel
  /// copy written here only feeds the preview. pro_image_editor rescales it
  /// together with the layer's offset when the canvas changes size (since
  /// 14.1.1), so the two keep describing the same journey until the animation
  /// is edited again.
  List<LayerAnimation> toLayerAnimations({
    LayerSlidePoints points = const LayerSlidePoints(),
    Size canvasSize = Size.zero,
  }) => [
    for (final animation in this)
      LayerAnimation.fromMap({
        // Any incoming `slideFrom` is dropped and rebuilt from [points], for
        // the same reason the outbound direction drops it: it arrives in video
        // pixels from the frame's top-left and would be read here as canvas
        // pixels from the canvas centre. It cannot be overridden afterwards
        // either — `copyWith` resolves `slideFrom ?? this.slideFrom`, so a
        // phase with no point would silently keep the video-space value.
        ..._withoutSlideFrom(animation.toMap()),
        if (animation.type == pve.LayerAnimationType.slide)
          if (points.resolve(animation.phase, canvasSize) case final point?)
            'slideFrom': _offsetToMap(point),
      }),
  ];
}

/// [map] without the `slideFrom` entry, whose meaning differs between the two
/// packages (see [LayerAnimationStorage]).
Map<String, dynamic> _withoutSlideFrom(Map<String, dynamic> map) =>
    Map<String, dynamic>.from(map)..remove('slideFrom');

/// [offset] in the shape both packages serialize an `Offset` as.
Map<String, dynamic> _offsetToMap(Offset offset) => <String, dynamic>{
  'dx': offset.dx,
  'dy': offset.dy,
};

/// Top-left corner of an exported layer, in the video's pixel space.
///
/// [anchor] is a point in editor body coordinates measured from the body's
/// centre — a layer's own [Layer.offset], or the custom slide point a
/// [LayerSlidePoints] resolves to. [logicalSize] is the layer's unscaled size
/// and [scale] maps body coordinates onto video pixels.
///
/// `ImageLayer.offset` and `LayerAnimation.slideFrom` share this corner
/// convention, so both are derived here — a layer that slides in from a custom
/// point must land exactly on its resting offset, which only holds while the
/// two are computed the same way.
Offset exportedLayerTopLeft({
  required Offset anchor,
  required Size bodySize,
  required Size logicalSize,
  required double scale,
}) => Offset(
  (bodySize.width / 2 + anchor.dx - logicalSize.width / 2) * scale,
  (bodySize.height / 2 + anchor.dy - logicalSize.height / 2) * scale,
);

/// Resolves a layer's animations for the export pipeline, folding in any custom
/// slide point stored on [Layer.meta].
extension LayerExportAnimations on Layer {
  /// This layer's animations with every custom slide point resolved into
  /// `LayerAnimation.slideFrom`, in the video's pixel space.
  ///
  /// [bodySize] is the editor body the layer was laid out against,
  /// [logicalSize] the layer's unscaled size, and [scale] the body-to-video
  /// pixel factor — the same three values [exportedLayerTopLeft] maps the
  /// layer's resting offset with.
  ///
  /// A phase without a custom point keeps its `slideDirection` and travels from
  /// the canvas edge as before. `slideDirection` is left in place even when a
  /// point overrides it, so the animation stays valid for pro_image_editor
  /// (which requires a direction on every slide) and for a reader that predates
  /// `slideFrom`.
  List<pve.LayerAnimation> divineAnimationsForExport({
    required Size bodySize,
    required Size logicalSize,
    required double scale,
  }) {
    final animations = divineAnimations;
    final points = LayerSlidePoints.of(this);
    if (points.isEmpty) return animations;

    return [
      for (final animation in animations)
        if (points.resolve(animation.phase, bodySize) case final anchor?
            when animation.type == pve.LayerAnimationType.slide)
          _withSlideFrom(
            animation,
            exportedLayerTopLeft(
              anchor: anchor,
              bodySize: bodySize,
              logicalSize: logicalSize,
              scale: scale,
            ),
          )
        else
          animation,
    ];
  }
}

/// [animation] with [slideFrom] set. pro_video_editor's model has no
/// `copyWith`, so every field is carried over by hand.
pve.LayerAnimation _withSlideFrom(pve.LayerAnimation animation, Offset from) =>
    pve.LayerAnimation(
      type: animation.type,
      phase: animation.phase,
      duration: animation.duration,
      curve: animation.curve,
      slideDirection: animation.slideDirection,
      slideFrom: from,
      scaleFrom: animation.scaleFrom,
    );
