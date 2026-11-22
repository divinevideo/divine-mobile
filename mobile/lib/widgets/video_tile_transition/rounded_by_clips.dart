// ABOUTME: Rounds a rect's corners where they sit in the corners of rounded
// ABOUTME: clips around it, such as a page's or a grid panel's.

import 'package:flutter/rendering.dart';

/// [rect] with each corner that sits in the corner of one of [clips] rounded
/// like that clip, the first of [clips] to reach a corner winning.
///
/// [rect] and the clips are compared in [ancestor]'s coordinates, or in
/// global ones without it. A clip with a custom clipper is skipped: its shape
/// is not its border radius.
RRect roundedByClips(
  Rect rect,
  Iterable<RenderClipRRect> clips, {
  RenderObject? ancestor,
}) {
  var topLeft = Radius.zero;
  var topRight = Radius.zero;
  var bottomLeft = Radius.zero;
  var bottomRight = Radius.zero;
  bool meets(Offset a, Offset b) => (a - b).distance < 0.5;
  for (final node in clips) {
    if (node.clipper != null || !node.hasSize) continue;
    final clip = MatrixUtils.transformRect(
      node.getTransformTo(ancestor),
      Offset.zero & node.size,
    );
    final radius = node.borderRadius.resolve(node.textDirection);
    if (topLeft == Radius.zero && meets(rect.topLeft, clip.topLeft)) {
      topLeft = radius.topLeft;
    }
    if (topRight == Radius.zero && meets(rect.topRight, clip.topRight)) {
      topRight = radius.topRight;
    }
    if (bottomLeft == Radius.zero && meets(rect.bottomLeft, clip.bottomLeft)) {
      bottomLeft = radius.bottomLeft;
    }
    if (bottomRight == Radius.zero &&
        meets(rect.bottomRight, clip.bottomRight)) {
      bottomRight = radius.bottomRight;
    }
  }
  return RRect.fromRectAndCorners(
    rect,
    topLeft: topLeft,
    topRight: topRight,
    bottomLeft: bottomLeft,
    bottomRight: bottomRight,
  );
}
