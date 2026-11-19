// ABOUTME: Counts semantics nodes in a subtree that expose a given action.
// ABOUTME: Catches an unlabelled twin node that duplicates a parent's action.

import 'package:flutter/semantics.dart';

/// How many nodes in [root]'s subtree, [root] included, expose [action].
///
/// A `GestureDetector` inside a `Semantics` that declares the same action
/// cannot merge into it, so Flutter publishes a second, unlabelled node with
/// the same rect. Asserting that a labelled node has an action does not see
/// that twin; this count does.
int countSemanticsNodesWithAction(SemanticsNode root, SemanticsAction action) {
  var count = root.getSemanticsData().hasAction(action) ? 1 : 0;
  root.visitChildren((child) {
    count += countSemanticsNodesWithAction(child, action);
    return true;
  });
  return count;
}
