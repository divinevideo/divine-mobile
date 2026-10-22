// ABOUTME: The style of an overlay layer — opacity, enter/leave/loop animation,
// ABOUTME: shape mask and, for a text, its look — as one unit that Copy style
// ABOUTME: lifts off a layer and Paste style writes onto others (#10258).

import 'dart:ui' show Offset, Size;

import 'package:equatable/equatable.dart';
import 'package:openvine/extensions/layer_animation_apply.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/caption_layer_mapping.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerMask, TextLayer;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// Whether [layer] can give its style to Copy style and take one from Paste
/// style: a text, a sticker, a drawing or an audio visualizer.
///
/// A hidden area (blur, pixelate) is left out because it takes none of the
/// parts: it cannot be see-through, animated or masked. A detached clip is
/// left out too: it is a clip as much as a layer, and its style would mix the
/// two. A burned-in caption cue takes its look from the caption track.
bool canCopyLayerStyle(Layer? layer) =>
    layer != null &&
    !isCensorLayer(layer) &&
    !DetachedClipLayerData.isDetachedClipLayer(layer) &&
    !isCaptionCueLayer(layer);

/// Everything about how an overlay layer looks and moves that is not its
/// content or where it sits on the canvas and the timeline.
///
/// Every layer that takes a style takes all of it that fits: a text takes the
/// look of a copied text, a sticker takes a text's animations but not its
/// font, an audio visualizer takes everything but the mask. Pasting makes the
/// target match, so a style copied without an animation or a mask takes the
/// target's away.
class LayerStyle extends Equatable {
  /// Creates a style.
  const LayerStyle({
    this.opacity = 1,
    this.enter = const [],
    this.leave = const [],
    this.loop = const [],
    this.enterPoint,
    this.leavePoint,
    this.mask,
    this.maskBoxSize,
    this.text,
  });

  /// The style [layer] shows at [at] on the video.
  ///
  /// [boxSize] is the size of the box the layer is drawn in, which its mask
  /// is measured against; without it a pasted mask cannot keep its
  /// proportions on a differently shaped layer.
  factory LayerStyle.of(Layer layer, {required Duration at, Size? boxSize}) {
    final points = LayerSlidePoints.of(layer);
    return LayerStyle(
      opacity: layer.keyframePlacementAt(at)?.opacity ?? layer.opacity,
      enter: layer.divineEnterAnimations,
      leave: layer.divineLeaveAnimations,
      loop: layer.divineLoopAnimations,
      enterPoint: points.enter,
      leavePoint: points.leave,
      mask: layer.mask,
      maskBoxSize: layer.mask == null ? null : boxSize,
      text: layer is TextLayer ? TitleStyle.of(layer) : null,
    );
  }

  /// How see-through the layer is, from 0 (invisible) to 1.
  ///
  /// A layer with keyframes fades through its keyframes instead, so it keeps
  /// them when this is pasted onto it.
  final double opacity;

  /// Animations played when the layer appears.
  final List<pve.LayerAnimation> enter;

  /// Animations played when the layer disappears.
  final List<pve.LayerAnimation> leave;

  /// Animations repeated for as long as the layer is visible.
  final List<pve.LayerAnimation> loop;

  /// Where the enter slide starts, as a canvas fraction; `null` slides in
  /// from a canvas edge. See [LayerSlidePoints].
  final Offset? enterPoint;

  /// Where the leave slide ends, as a canvas fraction; `null` slides out to a
  /// canvas edge.
  final Offset? leavePoint;

  /// The shape mask, or `null` for none.
  final LayerMask? mask;

  /// The box [mask] was shaped on, when it could be measured.
  final Size? maskBoxSize;

  /// The look of the text the style was copied from, or `null` when it came
  /// from another kind of layer.
  final TitleStyle? text;

  /// [layer] restyled. Its content, position, rotation, pinch scale,
  /// keyframes and timeline start are untouched; its end time is re-resolved
  /// for the leave animation the way the animation sheet does it.
  ///
  /// [canvasSize] resolves a custom slide point for the in-editor preview,
  /// [totalDuration] is the true total video duration (see
  /// `resolveLayerEndTime`), and [boxSize] is the box [layer] is drawn in.
  Layer applyTo(
    Layer layer, {
    required Size canvasSize,
    required Duration totalDuration,
    Size? boxSize,
  }) {
    if (!canCopyLayerStyle(layer)) return layer;
    final look = text;
    // Both writes hand back a copy, which the rest of this sets in place.
    final styled = layer is TextLayer && look != null
        ? look.applyTo(
            layer,
            canvasSize: canvasSize,
            totalDuration: totalDuration,
          )
        : layer.withDivineAnimations(
            enter: _playableOn(layer, enter),
            leave: _playableOn(layer, leave),
            loop: _playableOn(layer, loop),
            points: LayerSlidePoints(enter: enterPoint, leave: leavePoint),
            canvasSize: canvasSize,
            totalDuration: totalDuration,
          );
    if (!styled.hasKeyframes) styled.opacity = opacity;
    if (canMaskLayer(styled)) {
      final mask = this.mask;
      styled.mask = mask == null
          ? null
          : transferEditorMask(mask, from: maskBoxSize, to: boxSize);
    }
    return styled;
  }

  @override
  List<Object?> get props => [
    opacity,
    enter,
    leave,
    loop,
    enterPoint,
    leavePoint,
    mask,
    maskBoxSize,
    text,
  ];
}

/// [animations] without the ones [layer] cannot play: typing a text out
/// letter by letter or word by word means nothing on a sticker or a drawing.
List<pve.LayerAnimation> _playableOn(
  Layer layer,
  List<pve.LayerAnimation> animations,
) {
  if (layer is TextLayer) return animations;
  return [
    for (final animation in animations)
      if (animation.type != pve.LayerAnimationType.typewriter &&
          animation.type != pve.LayerAnimationType.wordByWord)
        animation,
  ];
}
