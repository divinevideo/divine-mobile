// ABOUTME: Canvas geometry shared by the editor canvas and layer compensation.
// ABOUTME: Owns the render-size and cover-fit math both sides depend on.

import 'dart:math';

import 'package:flutter/widgets.dart';

/// How the editor canvas maps a clip onto the body it is drawn in.
///
/// The canvas lays the editor out at [renderSize] and cover-fits it into
/// [targetSize]. Layers (text, stickers, helper lines, drawing stroke widths)
/// are authored in render space, so they compensate for that transform with
/// [fittedBoxScale].
///
/// Canvas layout, layer compensation, and the cut-area overlay read this one
/// model. The canvas and layer compensation used to model it separately, which
/// is how #7534 changed only the reporting side and made layers compensate for
/// a scale the canvas never applied.
@immutable
class VideoEditorCanvasGeometry {
  /// Derives the canvas geometry for [bodySize].
  ///
  /// [targetAspectRatio] is the crop the viewer sees; it defaults to
  /// [originalAspectRatio] when the clip is uncropped.
  factory VideoEditorCanvasGeometry({
    required Size bodySize,
    required double originalAspectRatio,
    double? targetAspectRatio,
  }) {
    return VideoEditorCanvasGeometry._(
      bodySize: bodySize,
      renderSize: renderSizeFor(bodySize, originalAspectRatio),
      targetSize: targetSizeFor(
        bodySize,
        targetAspectRatio ?? originalAspectRatio,
      ),
    );
  }

  const VideoEditorCanvasGeometry._({
    required this.bodySize,
    required this.renderSize,
    required this.targetSize,
  });

  /// Space the canvas was laid out in.
  final Size bodySize;

  /// Unscaled surface the editor and its layers are laid out at.
  final Size renderSize;

  /// Visible area the [renderSize] surface is cover-fitted into.
  final Size targetSize;

  /// Unscaled canvas surface for [bodySize] at [aspectRatio].
  ///
  /// The height is the body's shorter dimension. For landscape clips in a
  /// portrait body, the resulting width deliberately extends beyond the body
  /// before the cover-fit into [targetSizeFor] scales it.
  static Size renderSizeFor(Size bodySize, double aspectRatio) {
    final height = bodySize.shortestSide;
    return Size(height * aspectRatio, height);
  }

  /// Visible target area of [targetAspectRatio] contained in [bodySize].
  static Size targetSizeFor(Size bodySize, double targetAspectRatio) {
    if (bodySize == Size.zero) return Size.zero;
    if (bodySize.aspectRatio > targetAspectRatio) {
      return Size(bodySize.height * targetAspectRatio, bodySize.height);
    }
    return Size(bodySize.width, bodySize.width / targetAspectRatio);
  }

  /// Scale the canvas applies when cover-fitting [renderSize] into
  /// [targetSize].
  ///
  /// Layers divide their size by this so they end up on screen at the size
  /// they were authored at.
  double get fittedBoxScale {
    if (bodySize == Size.zero) return 1;
    return max(
      targetSize.width / renderSize.width,
      targetSize.height / renderSize.height,
    );
  }
}

/// Applies [geometry] to the editor canvas.
///
/// [child] is laid out at [VideoEditorCanvasGeometry.renderSize] and
/// cover-fitted into [VideoEditorCanvasGeometry.targetSize], centered in the
/// body — the transform [VideoEditorCanvasGeometry.fittedBoxScale] describes.
class VideoEditorCanvasFit extends StatelessWidget {
  /// Creates a [VideoEditorCanvasFit].
  const VideoEditorCanvasFit({
    required this.geometry,
    required this.child,
    super.key,
  });

  /// Mapping applied to [child].
  final VideoEditorCanvasGeometry geometry;

  /// Canvas laid out at [VideoEditorCanvasGeometry.renderSize].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.fromSize(
        size: geometry.targetSize,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox.fromSize(size: geometry.renderSize, child: child),
        ),
      ),
    );
  }
}
