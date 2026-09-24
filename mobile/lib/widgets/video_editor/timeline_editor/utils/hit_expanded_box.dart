// ABOUTME: Shared render widget that expands the hit-test area horizontally.
// ABOUTME: Used by the clip strip and the overlay strips to let trim handles
// ABOUTME: positioned outside layout bounds receive touches.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Expands the hit-test area horizontally so that trim handles positioned
/// outside the child's layout bounds (via [Clip.none]) can still receive
/// touches.
///
/// Bypasses the child's own [RenderBox.hitTest] `size.contains` check and
/// delegates directly to [RenderHitExpandedBox.hitTestChildren] for the
/// normal region, or uses [RenderHitExpandedBox._hitTestDeep] for the
/// expanded margins.
class HitExpandedBox extends SingleChildRenderObjectWidget {
  const HitExpandedBox({
    required super.child,
    super.key,
    this.expandLeft = 0,
    this.expandRight = 0,
  });

  final double expandLeft;
  final double expandRight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderHitExpandedBox(
      expandLeft: expandLeft,
      expandRight: expandRight,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHitExpandedBox renderObject,
  ) {
    renderObject
      ..expandLeft = expandLeft
      ..expandRight = expandRight;
  }
}

class RenderHitExpandedBox extends RenderProxyBox {
  RenderHitExpandedBox({
    required double expandLeft,
    required double expandRight,
  }) : _expandLeft = expandLeft,
       _expandRight = expandRight;

  double _expandLeft;
  double get expandLeft => _expandLeft;
  set expandLeft(double value) {
    if (_expandLeft == value) return;
    _expandLeft = value;
  }

  double _expandRight;
  double get expandRight => _expandRight;
  set expandRight(double value) {
    if (_expandRight == value) return;
    _expandRight = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inBounds =
        position.dx >= -_expandLeft &&
        position.dx < size.width + _expandRight &&
        position.dy >= 0 &&
        position.dy < size.height;
    if (inBounds) {
      if (size.contains(position)) {
        if (hitTestChildren(result, position: position) ||
            hitTestSelf(position)) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      } else {
        // Expanded margin — recursively bypass size.contains on
        // intermediate single-child render nodes so the touch reaches
        // the trim handles inside the Stack.
        final childHit = _hitTestDeep(result, position, child);
        if (childHit || hitTestSelf(position)) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      }
    }
    return false;
  }

  /// Recursively traverses the render tree, bypassing `size.contains`
  /// checks on intermediate render nodes so that touches in the expanded
  /// margin reach the trim handles through Stacks, Columns, and other
  /// multi-child layouts.
  ///
  /// Handles both [RenderProxyBox] (e.g. AnimatedOpacity, IgnorePointer)
  /// and non-proxy single-child nodes (e.g. scroll views) by checking
  /// [RenderObjectWithChildMixin]. Multi-child nodes (Stack, Column,
  /// Row) are iterated in reverse paint order with recursive
  /// [_hitTestDeep] calls so bounds checks are skipped at every level.
  ///
  /// The two [HitExpandedBox] widgets in the timeline are siblings rather
  /// than nested, so the [RenderHitExpandedBox] branch below carries no
  /// live call site today. It stays because it is what makes this a
  /// general traversal rather than one that silently stops at the first
  /// nested instance someone adds.
  ///
  /// Applies each child's paint offset via
  /// [BoxHitTestResult.addWithPaintOffset] for correct coordinate
  /// transforms.
  static bool _hitTestDeep(
    BoxHitTestResult result,
    Offset position,
    RenderBox? node,
  ) {
    if (node == null) return false;

    if (node is RenderHitExpandedBox) {
      return node.hitTest(result, position: position);
    }
    // Respect IgnorePointer — do not traverse into ignored subtrees.
    if (node is RenderIgnorePointer && node.ignoring) {
      return false;
    }
    // Single-child render objects: skip bounds check, apply the
    // child's full paint transform (includes scroll offsets), and
    // recurse.
    if (node is RenderObjectWithChildMixin<RenderBox>) {
      // Try the node's own hitTest first so nodes such as
      // RenderPointerListener with HitTestBehavior.opaque can register
      // hits on themselves.
      if (node.hitTest(result, position: position)) {
        return true;
      }

      final singleChildNode = node as RenderObjectWithChildMixin<RenderBox>;
      final child = singleChildNode.child;
      if (child == null) {
        // Leaf node (e.g. childless GestureDetector with
        // HitTestBehavior.opaque). Fall back to the node's own
        // hitTest so it can register itself when position is in
        // bounds.
        return node.hitTest(result, position: position);
      }
      // Use applyPaintTransform instead of parentData.offset so that
      // scroll viewports (SingleChildScrollView) include their scroll
      // offset in the coordinate transform.
      final transform = Matrix4.identity();
      node.applyPaintTransform(child, transform);
      return result.addWithPaintTransform(
        transform: transform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset? transformed) =>
            transformed != null && _hitTestDeep(result, transformed, child),
      );
    }
    // Multi-child (Stack, Column, Row, etc.): iterate children in
    // reverse paint order, bypassing size.contains on each child so
    // expanded-margin touches propagate through intermediate layouts.
    if (node
        is ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >) {
      final multi =
          node
              as ContainerRenderObjectMixin<
                RenderBox,
                ContainerBoxParentData<RenderBox>
              >;
      var child = multi.lastChild;
      while (child != null) {
        final pd = child.parentData! as ContainerBoxParentData<RenderBox>;
        final current = child;
        final hit = result.addWithPaintOffset(
          offset: pd.offset,
          position: position,
          hitTest: (BoxHitTestResult r, Offset t) =>
              _hitTestDeep(r, t, current),
        );
        if (hit) return true;
        child = pd.previousSibling;
      }
      return false;
    }
    // Fallback for unknown node types.
    return node.hitTestChildren(result, position: position);
  }
}
