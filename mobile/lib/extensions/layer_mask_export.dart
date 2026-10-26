// ABOUTME: Maps a shape mask whose keyframes change it over time into the
// ABOUTME: pro_video_editor export, which draws it on every frame.

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart' show immutable;
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show ExportedLayer, Layer, LayerMask, LayerMaskKeyframe;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// Where the box a mask is measured in lies in the image the export masks.
///
/// The same box by default, as for a timeline clip's cover and a detached
/// clip's frame. A captured text, sticker or drawing is turned and flipped
/// into its image instead (`Layer.captureAsPng`), which is the box around the
/// turned layer: [boxSize] is the layer's own box, [imageSize] that image,
/// and [rotation], [flipX] and [flipY] are the layer's.
@immutable
class ExportMaskPlacement {
  /// Creates an [ExportMaskPlacement] of a box of [boxSize] turned by
  /// [rotation] and flipped into an image of [imageSize].
  const ExportMaskPlacement({
    required this.boxSize,
    required this.imageSize,
    this.rotation = 0,
    this.flipX = false,
    this.flipY = false,
  });

  /// The image is the mask's own box.
  const ExportMaskPlacement.identity()
    : boxSize = null,
      imageSize = null,
      rotation = 0,
      flipX = false,
      flipY = false;

  /// The mask's own box, or `null` when it is the image.
  final Size? boxSize;

  /// The image the box is turned into, or `null` when it is the box.
  final Size? imageSize;

  /// How far the box is turned into the image, clockwise, in radians.
  final double rotation;

  /// Whether the box is mirrored horizontally into the image.
  final bool flipX;

  /// Whether the box is mirrored vertically into the image.
  final bool flipY;

  bool get _isIdentity {
    final box = boxSize;
    final image = imageSize;
    return box == null ||
        image == null ||
        box.isEmpty ||
        image.isEmpty ||
        (box == image && rotation == 0 && !flipX && !flipY);
  }

  /// Whether a shape comes out mirrored, which one flip does and two undo.
  bool get mirrors => flipX != flipY;

  /// [geometry], measured in the box, measured in the image.
  ///
  /// The image is the box turned by [rotation] and then flipped, around its
  /// centre, as the capture draws it: a point moves by the flips of the turn
  /// of where it lies, a shape's own turn follows, mirrored by one flip, and
  /// its size and softness keep their length in pixels.
  _MaskGeometry _place(_MaskGeometry geometry) {
    if (_isIdentity) return geometry;
    final box = boxSize!;
    final image = imageSize!;
    final dx = (geometry.center.dx - 0.5) * box.width;
    final dy = (geometry.center.dy - 0.5) * box.height;
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    final x = (dx * cos - dy * sin) * (flipX ? -1 : 1);
    final y = (dx * sin + dy * cos) * (flipY ? -1 : 1);
    final turn = geometry.rotation + rotation;
    return _MaskGeometry(
      center: Offset(x / image.width + 0.5, y / image.height + 0.5),
      size: Size(
        geometry.size.width * box.width / image.width,
        geometry.size.height * box.height / image.height,
      ),
      // A flip of the turned shape is a mirror of it before the turn, turned
      // the other way; a vertical flip a horizontal one half way round.
      rotation: switch ((flipX, flipY)) {
        (false, false) => turn,
        (true, false) => -turn,
        (false, true) => math.pi - turn,
        (true, true) => math.pi + turn,
      },
      feather: geometry.feather * box.shortestSide / image.shortestSide,
    );
  }
}

/// The parts of a mask its keyframes change.
@immutable
class _MaskGeometry {
  const _MaskGeometry({
    required this.center,
    required this.size,
    required this.rotation,
    required this.feather,
  });

  final Offset center;
  final Size size;
  final double rotation;
  final double feather;
}

/// Maps a mask into the export.
extension LayerMaskExport on LayerMask {
  /// This mask as the pro_video_editor shape mask the export draws on every
  /// frame, laid into the image it masks by [placement].
  ///
  /// Its keyframes are placed at their time on the editor's timeline,
  /// [origin] (where the masked item starts there) plus their own, which the
  /// export reads off the masked layer's keyframe clock (see
  /// [divineKeyframeClock]).
  pve.LayerShapeMask divineShapeMaskForExport({
    required Duration origin,
    ExportMaskPlacement placement = const ExportMaskPlacement.identity(),
  }) {
    final own = placement._place(
      _MaskGeometry(
        center: center,
        size: size,
        rotation: rotation,
        feather: feather,
      ),
    );
    return pve.LayerShapeMask(
      // The packages share the shapes and their names.
      shape: pve.LayerShapeMaskShape.values.byName(shape.name),
      center: own.center,
      size: own.size,
      rotation: own.rotation,
      feather: own.feather,
      cornerRadius: cornerRadius,
      invert: invert,
      mirrored: placement.mirrors,
      keyframes: [
        for (final keyframe in keyframes)
          _exportedKeyframe(keyframe, origin: origin, placement: placement),
      ],
    );
  }
}

pve.LayerShapeMaskKeyframe _exportedKeyframe(
  LayerMaskKeyframe keyframe, {
  required Duration origin,
  required ExportMaskPlacement placement,
}) {
  final placed = placement._place(
    _MaskGeometry(
      center: keyframe.center,
      size: keyframe.size,
      rotation: keyframe.rotation,
      feather: keyframe.feather,
    ),
  );
  return pve.LayerShapeMaskKeyframe(
    time: origin + keyframe.time,
    center: placed.center,
    size: placed.size,
    rotation: placed.rotation,
    feather: placed.feather,
    // The packages share the thirteen curves and their names.
    curve: pve.AnimationCurve.values.byName(keyframe.curve.name),
  );
}

/// The clock keyframes on the editor's timeline are read on in the export:
/// each frame of the output at its time on the editor's timeline. Empty when
/// [timelineMap] runs as fast as the editor throughout.
///
/// A clip transition plays both clips at once, where the editor shows one
/// after the other, so the output runs at half the editor's pace through it.
/// A point at each edge of every transition lets the export place every frame
/// where the editor shows it at that moment, whichever curve the motion
/// follows and however short the stretch.
List<pve.KeyframeClockPoint> divineKeyframeClock(
  TransitionTimelineMap timelineMap,
) => [
  for (final boundary in timelineMap.clockBoundaries)
    pve.KeyframeClockPoint(
      output: timelineMap.editorToOutput(boundary),
      keyframe: boundary,
    ),
];

/// A layer's mask in the export.
extension LayerMaskExportOnLayer on Layer {
  /// Whether the layer's mask changes over time, and so is drawn by the
  /// export on every frame instead of baked into the layer's image.
  bool get hasKeyframedMask => mask?.hasKeyframes ?? false;
}

/// The mask of a captured layer in the export.
extension ExportedLayerMaskExport on ExportedLayer {
  /// The layer's mask as the export draws it on every frame of the captured
  /// image, or `null` when it has none that changes over time: a still mask
  /// is baked into the image (`Layer.captureAsPng`).
  ///
  /// The capture turns and flips the layer's box, [ExportedLayer.boxSize],
  /// into the image, [ExportedLayer.logicalSize], so the mask is placed there
  /// the same way; its keyframes count from the layer's start.
  pve.LayerShapeMask? divineShapeMaskForExport() {
    if (!layer.hasKeyframedMask) return null;
    return layer.mask!.divineShapeMaskForExport(
      origin: layer.keyframeOrigin,
      placement: ExportMaskPlacement(
        boxSize: boxSize,
        imageSize: logicalSize,
        rotation: layer.rotation,
        flipX: layer.flipX,
        flipY: layer.flipY,
      ),
    );
  }
}
