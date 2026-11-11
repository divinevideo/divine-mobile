// ABOUTME: Switches a video between square and 9:16 in the editor: crops every
// ABOUTME: clip anew and moves the layers the new frame would cut off.

import 'dart:math' as math;
import 'dart:ui';

import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_layer_mapping.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:openvine/models/video_editor/interactive_card_placement.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer;

/// The shape a video switches to from [ratio]: square from 9:16, and 9:16
/// from square.
model.AspectRatio switchedAspectRatio(model.AspectRatio ratio) =>
    switch (ratio) {
      .square => .vertical,
      .vertical => .square,
    };

/// [clips] cropped to [ratio], the shape of the whole video.
///
/// The composition is cropped to its first clip's ratio, so every clip takes
/// the new one; a clip reordered to the front later then keeps the video's
/// shape. A clip's shape mask is measured in the cropped frame, so it moves
/// onto the new frame ([maskForAspectRatioSwitch]) rather than stretching
/// with it. Nothing is re-rendered: a clip whose picture is narrower than the
/// new frame is zoomed in to fill it, as any clip of another shape is.
List<DivineVideoClip> clipsWithAspectRatio(
  List<DivineVideoClip> clips,
  model.AspectRatio ratio,
) {
  if (clips.isEmpty) return clips;
  // Masks are measured in the frame of the whole video, the first clip's.
  final from = clips.first.targetAspectRatio.value;
  return [
    for (final clip in clips)
      clip.copyWith(
        targetAspectRatio: ratio,
        mask: maskForAspectRatioSwitch(
          clip.mask,
          videoAspectRatio: clip.videoAspectRatio,
          from: from,
          to: ratio.value,
        ),
      ),
  ];
}

/// Moves [layer] for a switch of the video from [from] to [to], both aspect
/// ratios of the frame the export keeps, on an editor body of [bodySize].
///
/// Switching only changes which part of the canvas the video shows, so a
/// layer stays on the part of the picture it was placed on. A layer the new
/// frame would cut off is moved back onto it, just far enough; what already
/// hung off the old frame may hang off the new one by as much, so a sticker
/// peeking in from an edge keeps peeking. A layer larger than the frame
/// covers as much of it as it can.
///
/// Three kinds of layer are treated differently:
/// * a burned-in caption keeps its place relative to the frame, so it stays
///   in the lower third;
/// * a hidden area (blur, pixelate) stays where it is, on what it hides;
/// * an interactive card is left alone, as it is kept in its safe area on
///   every change already (`keepInteractiveCardInPlace`).
///
/// [size] is the layer as it is drawn, scaled ([Layer.renderSize]); without it
/// only the layer's centre is kept on the frame. Keyframes move with the
/// layer: a layer with keyframes is kept on the frame wherever they take it.
void placeLayerForAspectRatioSwitch(
  Layer layer, {
  required Size? size,
  required Size bodySize,
  required double from,
  required double to,
}) {
  if (from == to || bodySize.isEmpty) return;
  if (isCensorLayer(layer) || isInteractiveCardLayer(layer)) return;
  final old = ExportLayerMapping.keptRect(bodySize, from);
  final next = ExportLayerMapping.keptRect(bodySize, to);

  if (isCaptionCueLayer(layer)) {
    // Both frames are centred on the body, which layer offsets are measured
    // from, so scaling an offset keeps it at the same share of the frame.
    final scale = Offset(next.width / old.width, next.height / old.height);
    void keepShare(Layer placement) =>
        placement.offset = placement.offset.scale(scale.dx, scale.dy);
    keepShare(layer);
    layer.transformKeyframes(keepShare);
    return;
  }

  final shift = aspectRatioSwitchShift(
    bounds: _layerBounds(layer, size ?? Size.zero, bodySize),
    from: old,
    to: next,
  );
  if (shift == Offset.zero) return;
  void move(Layer placement) => placement.offset += shift;
  move(layer);
  layer.transformKeyframes(move);
}

/// How far a layer covering [bounds] moves when the frame changes from
/// [from] to [to], all in the same coordinates; see
/// [placeLayerForAspectRatioSwitch].
Offset aspectRatioSwitchShift({
  required Rect bounds,
  required Rect from,
  required Rect to,
}) => Offset(
  _axisShift(
    bounds.left,
    bounds.right,
    from.left,
    from.right,
    to.left,
    to.right,
  ),
  _axisShift(
    bounds.top,
    bounds.bottom,
    from.top,
    from.bottom,
    to.top,
    to.bottom,
  ),
);

/// The shift along one side of the frame for a layer from [low] to [high].
double _axisShift(
  double low,
  double high,
  double oldMin,
  double oldMax,
  double newMin,
  double newMax,
) {
  // Room for rounding, so a layer resting on an edge stays where it is.
  const slack = 1e-6;
  final min = newMin - math.max(0, oldMin - low) - slack;
  final max = newMax + math.max(0, high - oldMax) + slack;
  if (high - low <= max - min) {
    if (low < min) return min - low;
    if (high > max) return max - high;
    return 0;
  }
  // Larger than the frame: it covers as much of it as it can.
  if (low > min) return min - low;
  if (high < max) return max - high;
  return 0;
}

/// The box [layer] covers on an editor body of [bodySize], drawn [size] big
/// at its own scale and turned, wherever its keyframes take it.
Rect _layerBounds(Layer layer, Size size, Size bodySize) {
  final center = bodySize.center(Offset.zero);
  Rect boundsAt(Offset offset, double growth, double rotation) {
    final width = size.width * growth;
    final height = size.height * growth;
    final cos = math.cos(rotation).abs();
    final sin = math.sin(rotation).abs();
    return Rect.fromCenter(
      center: center + offset,
      width: width * cos + height * sin,
      height: width * sin + height * cos,
    );
  }

  // With keyframes, the layer's own offset only lays it out; they place it.
  if (!layer.hasKeyframes || layer.scale <= 0) {
    return boundsAt(layer.offset, 1, layer.rotation);
  }
  return layer.keyframes
      .map(
        (keyframe) => boundsAt(
          keyframe.offset,
          keyframe.scale / layer.scale,
          keyframe.rotation,
        ),
      )
      .reduce((a, b) => a.expandToInclude(b));
}
