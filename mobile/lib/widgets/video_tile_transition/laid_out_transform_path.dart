// ABOUTME: Checks layout availability before tile transitions read transforms.
// ABOUTME: A sized child can be grafted below an ancestor awaiting layout.

import 'package:flutter/rendering.dart';

/// Whether every box from [object] through [ancestor] has a layout size.
///
/// Without [ancestor], checks through the root for a global conversion.
/// Paint transforms such as fractional translations read their own size,
/// even when the descendant being converted already has one.
bool hasLaidOutTransformPath(RenderObject object, {RenderObject? ancestor}) {
  for (RenderObject? node = object; node != null; node = node.parent) {
    if (!node.attached || (node is RenderBox && !node.hasSize)) return false;
    if (identical(node, ancestor)) return true;
  }
  return ancestor == null;
}
