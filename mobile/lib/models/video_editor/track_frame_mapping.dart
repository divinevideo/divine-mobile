// ABOUTME: Maps between a clip's frame, measured in fractions as object
// ABOUTME: tracking reports it, and the canvas space layers are placed in.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;

/// Maps between a clip's upright frame, in fractions of its width and height
/// (`(0, 0)` top left, `(1, 1)` bottom right), and layer coordinates: canvas
/// pixels from the middle of the canvas, the space a layer's offset lives in.
///
/// The preview covers the visible part of the canvas with the part of every
/// clip the video keeps, both cut to the video's ratio and centred, and the
/// export composites layers the same way ([ExportLayerMapping]). This is the
/// same correspondence, so a point a layer is placed on is the point of the
/// frame it shows over.
@immutable
class TrackFrameMapping {
  /// Maps a frame of [videoAspectRatio] onto a canvas of [canvasSize] for a
  /// video cut to [targetAspectRatio].
  factory TrackFrameMapping({
    required Size canvasSize,
    required double videoAspectRatio,
    required double targetAspectRatio,
  }) {
    // Any frame of the right shape will do: the mapping is measured in
    // fractions of it.
    final frameSize = Size(videoAspectRatio * _frameHeight, _frameHeight);
    final mapping = ExportLayerMapping(
      bodySize: canvasSize,
      frameSize: frameSize,
      targetAspectRatio: targetAspectRatio,
    );
    final kept = ExportLayerMapping.keptRect(frameSize, targetAspectRatio);
    return TrackFrameMapping._(
      canvasSize: canvasSize,
      frameSize: frameSize,
      scale: mapping.scale,
      origin: mapping.origin,
      visibleFrame: Rect.fromLTRB(
        kept.left / frameSize.width,
        kept.top / frameSize.height,
        kept.right / frameSize.width,
        kept.bottom / frameSize.height,
      ),
    );
  }

  const TrackFrameMapping._({
    required this.canvasSize,
    required Size frameSize,
    required double scale,
    required Offset origin,
    required this.visibleFrame,
  }) : _frameSize = frameSize,
       _scale = scale,
       _origin = origin;

  static const double _frameHeight = 1000;

  /// The canvas layer coordinates are measured on.
  final Size canvasSize;

  /// The part of the frame the video keeps and the canvas shows, in
  /// fractions of the frame.
  final Rect visibleFrame;

  final Size _frameSize;

  /// Canvas pixels to frame pixels.
  final double _scale;

  /// Where the canvas's top left corner lands in the frame, in frame pixels.
  final Offset _origin;

  /// The point of the canvas, in layer coordinates, that shows the point
  /// [fraction] of the frame.
  Offset layerOffsetOf(Offset fraction) {
    final framePoint = Offset(
      fraction.dx * _frameSize.width,
      fraction.dy * _frameSize.height,
    );
    return (framePoint - _origin) / _scale - canvasSize.center(Offset.zero);
  }

  /// The point of the frame, in fractions of it, that shows at [layerOffset].
  Offset fractionOf(Offset layerOffset) {
    final framePoint =
        (layerOffset + canvasSize.center(Offset.zero)) * _scale + _origin;
    return Offset(
      framePoint.dx / _frameSize.width,
      framePoint.dy / _frameSize.height,
    );
  }

  /// How many canvas pixels a fraction of the frame's width spans.
  double get layerPixelsPerFrameWidth => _frameSize.width / _scale;

  /// How many canvas pixels a fraction of the frame's height spans.
  double get layerPixelsPerFrameHeight => _frameSize.height / _scale;

  /// [region] of the frame, in fractions of it, as a rect in layer
  /// coordinates.
  Rect layerRectOf(Rect region) => Rect.fromPoints(
    layerOffsetOf(region.topLeft),
    layerOffsetOf(region.bottomRight),
  );

  /// [rect] in layer coordinates as a region of the frame, in fractions of
  /// it.
  Rect regionOf(Rect rect) =>
      Rect.fromPoints(fractionOf(rect.topLeft), fractionOf(rect.bottomRight));
}
