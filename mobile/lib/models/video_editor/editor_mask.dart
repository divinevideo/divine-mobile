// ABOUTME: The shape masks the editor offers: which items take one, what a
// ABOUTME: new mask of each shape looks like, and how far it can be resized
// ABOUTME: and moved.

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerMask, LayerMaskShape;

/// The shapes the mask editor offers, in the order it shows them.
const List<LayerMaskShape> editorMaskShapes = [
  LayerMaskShape.ellipse,
  LayerMaskShape.rectangle,
  LayerMaskShape.heart,
  LayerMaskShape.star,
  LayerMaskShape.triangle,
  LayerMaskShape.diamond,
  LayerMaskShape.hexagon,
  LayerMaskShape.speechBubble,
  LayerMaskShape.linear,
];

/// How soft an edge the mask editor allows, in fractions of the shorter side
/// of the masked item: up to a fade over half of it.
const double editorMaskMaxFeather = 0.5;

/// The smallest a shape can be made, in fractions of the masked item's box,
/// so it never shrinks out of reach of the fingers resizing it.
const double editorMaskMinSize = 0.05;

/// The longest a side of a shape can be made, in fractions of the matching
/// side of the masked item's box. Turned a quarter, a side lies along the
/// other side of the box, which on a tall video is almost twice as long;
/// that the shape stays on the item ([fitEditorMask]) is what bounds it.
const double editorMaskMaxSize = 3;

/// The softness a new linear mask starts with: a visible gradient, which is
/// what a linear mask is mostly for.
const double editorMaskLinearFeather = 0.15;

/// The corner roundness a new rectangle starts with.
const double editorMaskRectangleCorners = 0.3;

/// Whether [layer] can be shown through a shape mask.
///
/// Every overlay can, except two that the export draws natively from their own
/// description rather than from what the canvas shows: a hidden area (blur,
/// pixelate), which covers what lies beneath it, and an audio visualizer.
bool canMaskLayer(Layer? layer) =>
    layer != null &&
    !isCensorLayer(layer) &&
    !AudioVisualizerLayerData.isAudioVisualizerLayer(layer);

/// Moves a timeline mask from the cropped export frame into the full box of
/// a detached clip. Keeping the same normalized coordinates would stretch a
/// circle when the source and project have different aspect ratios.
///
/// Its keyframes move with it, each the same way.
LayerMask? maskForDetachedClip(
  LayerMask? mask, {
  required Size boxSize,
  required double targetAspectRatio,
}) {
  if (mask == null || boxSize.isEmpty) return mask;
  final frame = ExportLayerMapping.keptRect(boxSize, targetAspectRatio);
  LayerMask moved(LayerMask still) => still.copyWith(
    center: Offset(
      (frame.left + still.center.dx * frame.width) / boxSize.width,
      (frame.top + still.center.dy * frame.height) / boxSize.height,
    ),
    size: Size(
      still.size.width * frame.width / boxSize.width,
      still.size.height * frame.height / boxSize.height,
    ),
    feather: still.feather * frame.shortestSide / boxSize.shortestSide,
  );
  return _withEachKeyframe(mask, moved);
}

/// [mask] with [change] made to its own values and, the same way, to the
/// geometry of each of its keyframes.
LayerMask _withEachKeyframe(
  LayerMask mask,
  LayerMask Function(LayerMask still) change,
) {
  final rest = change(mask.still);
  if (!mask.hasKeyframes) return rest;
  return rest.withKeyframes([
    for (final keyframe in mask.keyframes)
      keyframe.withGeometryOf(change(mask.at(keyframe.time))),
  ]);
}

/// [mask], shaped on an item whose box is [from], moved onto an item whose
/// box is [to].
///
/// Its size is measured in fractions of the box, so carried over as it is a
/// circle on a square sticker would turn into an oval on a wide text. The
/// shape keeps its proportions on screen instead and takes the same share of
/// the shorter side, and is then kept on the new item ([fitEditorMask]).
/// Without both boxes it carries over as it is. Its keyframes move with it,
/// each the same way.
LayerMask transferEditorMask(
  LayerMask mask, {
  required Size? from,
  required Size? to,
}) {
  if (from == null || to == null || from.isEmpty || to.isEmpty) return mask;
  final scale = to.shortestSide / from.shortestSide;
  LayerMask transferred(LayerMask still) => fitEditorMask(
    still.copyWith(
      size: clampEditorMaskSize(
        Size(
          still.size.width * from.width * scale / to.width,
          still.size.height * from.height * scale / to.height,
        ),
      ),
    ),
    to,
  );
  return _withEachKeyframe(mask, transferred);
}

/// A mask of [shape] for an item whose box is [boxSize].
///
/// Switching from [previous] keeps where it is, how far it is turned, how
/// soft its edge is and whether it is inverted, and its size between the
/// shapes that have one, made smaller if the new shape, turned like that,
/// would reach off the item. A shape other than a rectangle that was never
/// stretched out of its own proportions takes those of the new shape
/// instead, as long on its longer side, so a circle switched to a hexagon
/// becomes a regular one.
///
/// A new shape has its own proportions on screen, two thirds of the item's
/// shorter side along its longer side: a circle, a heart, a star, a diamond
/// and a bubble as wide as high, a triangle equilateral and a hexagon
/// regular. A new rectangle covers most of the item, with rounded corners.
LayerMask editorMaskForShape(
  LayerMaskShape shape, {
  required Size boxSize,
  LayerMask? previous,
}) {
  final keepsSize =
      previous != null &&
      previous.shape != LayerMaskShape.linear &&
      shape != LayerMaskShape.linear;
  final mask = LayerMask(
    shape: shape,
    center: previous?.center ?? const Offset(0.5, 0.5),
    size: keepsSize
        ? _switchedSize(previous, shape, boxSize)
        : _defaultSize(shape, boxSize),
    rotation: previous?.rotation ?? 0,
    feather:
        previous?.feather ??
        (shape == LayerMaskShape.linear ? editorMaskLinearFeather : 0),
    cornerRadius: previous?.shape == LayerMaskShape.rectangle
        ? previous!.cornerRadius
        : editorMaskRectangleCorners,
    invert: previous?.invert ?? false,
  );
  return fitEditorMask(mask, boxSize);
}

Size _defaultSize(LayerMaskShape shape, Size boxSize) {
  if (shape == LayerMaskShape.rectangle) return const Size(0.8, 0.8);
  if (boxSize.isEmpty) return const Size(0.6, 0.6);
  return _proportionalSize(shape, boxSize.shortestSide * 2 / 3, boxSize);
}

/// The size [previous] passes on to a mask of [shape] switched to from it.
Size _switchedSize(LayerMask previous, LayerMaskShape shape, Size boxSize) {
  if (boxSize.isEmpty) return previous.size;
  final width = previous.size.width * boxSize.width;
  final height = previous.size.height * boxSize.height;
  final proportions = _aspectRatio(previous.shape);
  // A rectangle has no proportions of its own: a new one fills most of the
  // item, whatever the item's shape.
  if (previous.shape == LayerMaskShape.rectangle ||
      height <= 0 ||
      ((width / height) - proportions).abs() > proportions * 1e-6) {
    return previous.size;
  }
  return _proportionalSize(shape, math.max(width, height), boxSize);
}

/// A size of [shape] in its own proportions on a box of [boxSize], [longer]
/// pixels along its longer side.
Size _proportionalSize(LayerMaskShape shape, double longer, Size boxSize) {
  final aspectRatio = _aspectRatio(shape);
  final width = aspectRatio >= 1 ? longer : longer * aspectRatio;
  return Size(
    width / boxSize.width,
    width / aspectRatio / boxSize.height,
  );
}

/// How much wider than high [shape] is in its own proportions: an
/// equilateral triangle, a regular hexagon, and the rest as wide as high.
double _aspectRatio(LayerMaskShape shape) => switch (shape) {
  LayerMaskShape.triangle => 2 / math.sqrt(3),
  LayerMaskShape.hexagon => math.sqrt(3) / 2,
  _ => 1,
};

/// [size] kept within [editorMaskMinSize] and [editorMaskMaxSize] on both
/// sides.
Size clampEditorMaskSize(Size size) => Size(
  size.width.clamp(editorMaskMinSize, editorMaskMaxSize),
  size.height.clamp(editorMaskMinSize, editorMaskMaxSize),
);

/// [mask] scaled by [factor] around its centre, keeping its proportions as
/// long as neither side runs into a limit.
LayerMask scaleEditorMask(LayerMask mask, double factor) {
  final largest = math.max(mask.size.width, mask.size.height);
  final smallest = math.min(mask.size.width, mask.size.height);
  final clamped = factor.clamp(
    editorMaskMinSize / smallest,
    editorMaskMaxSize / largest,
  );
  return mask.copyWith(size: clampEditorMaskSize(mask.size * clamped));
}

/// [mask] kept on an item whose box is [boxSize].
///
/// A shape whose turned outline reaches further than the item is shrunk
/// around its centre until it fits, and one hanging over an edge is moved
/// back onto the item just far enough. Moving, turning and pinching a shape
/// all run through this, so it never leaves the item it masks; pinching one
/// bigger against an edge pushes it away from that edge. A linear mask is a
/// line across the whole item, so only its centre is kept on it.
LayerMask fitEditorMask(LayerMask mask, Size boxSize) {
  if (boxSize.isEmpty) return mask;
  var fitted = mask;
  var reach = Size.zero;
  if (mask.shape != LayerMaskShape.linear) {
    reach = _halfReach(mask, boxSize);
    final largest = math.max(reach.width, reach.height);
    if (largest > 0.5) {
      fitted = mask.copyWith(
        size: clampEditorMaskSize(mask.size * (0.5 / largest)),
      );
      reach = _halfReach(fitted, boxSize);
    }
  }
  return fitted.copyWith(
    center: Offset(
      mask.center.dx.clamp(reach.width, math.max(reach.width, 1 - reach.width)),
      mask.center.dy.clamp(
        reach.height,
        math.max(reach.height, 1 - reach.height),
      ),
    ),
  );
}

/// [mask] resized towards [size] on an item whose box is [boxSize], around
/// its centre and only as far as its turned outline stays on the item.
///
/// A side handle dragged past the item's edge therefore stops where the shape
/// touches it.
LayerMask resizeEditorMask(LayerMask mask, Size size, {required Size boxSize}) {
  final target = mask.copyWith(size: clampEditorMaskSize(size));
  if (mask.shape == LayerMaskShape.linear ||
      boxSize.isEmpty ||
      _liesOnBox(target, boxSize)) {
    return target;
  }
  // The shape fits at the start of the way to [size] and stops fitting
  // somewhere along it; the furthest point that still fits is searched for.
  final start = fitEditorMask(mask, boxSize);
  var fits = 0.0;
  var overflows = 1.0;
  for (var step = 0; step < 24; step++) {
    final middle = (fits + overflows) / 2;
    final resized = start.copyWith(
      size: Size.lerp(start.size, target.size, middle),
    );
    if (_liesOnBox(resized, boxSize)) {
      fits = middle;
    } else {
      overflows = middle;
    }
  }
  return start.copyWith(size: Size.lerp(start.size, target.size, fits));
}

/// Whether the turned outline of [mask] lies on a box of [boxSize].
bool _liesOnBox(LayerMask mask, Size boxSize) {
  // Room for rounding, so a shape resting on an edge counts as on the box.
  const slack = 1e-9;
  final reach = _halfReach(mask, boxSize);
  return mask.center.dx - reach.width >= -slack &&
      mask.center.dx + reach.width <= 1 + slack &&
      mask.center.dy - reach.height >= -slack &&
      mask.center.dy + reach.height <= 1 + slack;
}

/// How far the turned shape of [mask] reaches from its centre along each
/// side of the box, in fractions of [boxSize].
Size _halfReach(LayerMask mask, Size boxSize) {
  final width = mask.size.width * boxSize.width / 2;
  final height = mask.size.height * boxSize.height / 2;
  final cos = math.cos(mask.rotation).abs();
  final sin = math.sin(mask.rotation).abs();
  final (x, y) = mask.shape == LayerMaskShape.ellipse
      ? (
          math.sqrt(math.pow(width * cos, 2) + math.pow(height * sin, 2)),
          math.sqrt(math.pow(width * sin, 2) + math.pow(height * cos, 2)),
        )
      // The bounds of the box the shape fills, which no other shape reaches
      // past: each fills its box, and only an ellipse is measured exactly.
      : (width * cos + height * sin, width * sin + height * cos);
  return Size(x / boxSize.width, y / boxSize.height);
}
