// ABOUTME: The area text layers stay inside on the video editor canvas.
// ABOUTME: Shared by the live canvas and the draft re-render so both wrap alike.

import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

/// The part of the editor body the viewer sees, which text layers wrap their
/// lines to stay inside, in the logical pixels of the body.
///
/// The body is laid out at the clip's own aspect ratio and cover-fitted into
/// the [targetAspectRatio] crop, centered, so a crop of a different shape
/// hides the sides or the top and bottom of the body. A text layer that is
/// scaled up or moved towards an edge therefore wraps at the edges of the
/// video rather than running past them.
///
/// The live canvas and the draft re-render both pass this to
/// `TextEditorConfigs.layerBounds`; the bounds are not stored in the layers,
/// so the two only break lines alike while they share this function.
Rect editorTextLayerBounds(
  Size editorBodySize, {
  required double targetAspectRatio,
}) {
  return Rect.fromCenter(
    center: editorBodySize.center(Offset.zero),
    width: min(editorBodySize.width, editorBodySize.height * targetAspectRatio),
    height: min(
      editorBodySize.height,
      editorBodySize.width / targetAspectRatio,
    ),
  );
}
