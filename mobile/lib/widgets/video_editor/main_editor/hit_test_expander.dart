// ABOUTME: Forwards hit-tests from the whole parent box into a smaller child
// ABOUTME: Lets letterbox taps reach the editor canvas underneath

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Forwards hit-tests from the entire parent box into [child], even
/// when the pointer falls outside [child]'s painted area.
///
/// Layout / paint are unchanged — [child] is laid out with the parent
/// constraints and painted at offset zero, exactly like a passthrough
/// wrapper. Only [hitTest] is customised: positions outside the
/// centered [visibleSize] rect are clamped to its nearest edge so the
/// downstream hit-test chain (which clips to `Center > SizedBox`) sees
/// a position it accepts and forwards the down event normally.
///
/// Subsequent move events flow through the gesture arena that the
/// initial down opens, so [GestureDetector.onScaleUpdate] still
/// receives real-pointer deltas.
class HitTestExpander extends SingleChildRenderObjectWidget {
  /// Creates a [HitTestExpander].
  const HitTestExpander({
    required this.visibleSize,
    required Widget super.child,
    super.key,
  });

  /// The size of the painted, hit-testable region inside the parent
  /// box, centered on both axes. Hits outside this rect are clamped
  /// onto its nearest edge before being forwarded.
  final Size visibleSize;

  @override
  // Flutter's public override returns this widget's private render object;
  // exposing that implementation type as public would widen the API.
  // ignore: library_private_types_in_public_api
  _RenderHitTestExpander createRenderObject(BuildContext context) {
    return _RenderHitTestExpander(visibleSize: visibleSize);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    // Flutter passes back the private render object created above.
    // ignore: library_private_types_in_public_api
    _RenderHitTestExpander renderObject,
  ) {
    renderObject.visibleSize = visibleSize;
  }
}

class _RenderHitTestExpander extends RenderProxyBox {
  _RenderHitTestExpander({required Size visibleSize})
    : _visibleSize = visibleSize;

  /// Symmetric 1 px inset applied when clamping a hit position onto
  /// the visible rect. Required because downstream transforms
  /// (FittedBox cover-fit) can map an exact `left`/`top` value to a
  /// slightly negative local coordinate after float multiplication,
  /// which then fails `Rect.contains` and drops the hit. The trailing
  /// inset is needed because `Rect.contains` excludes the right /
  /// bottom edge.
  static const double _hitTestEpsilon = 1.0;

  Size _visibleSize;
  Size get visibleSize => _visibleSize;
  set visibleSize(Size value) {
    if (value == _visibleSize) return;
    _visibleSize = value;
    // No markNeedsLayout/Paint: layout and paint don't depend on
    // [visibleSize] — only [hitTest] does, and that runs per-event.
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final left = (size.width - _visibleSize.width) / 2;
    final top = (size.height - _visibleSize.height) / 2;
    final clampedDx = position.dx.clamp(
      left + _hitTestEpsilon,
      left + _visibleSize.width - _hitTestEpsilon,
    );
    final clampedDy = position.dy.clamp(
      top + _hitTestEpsilon,
      top + _visibleSize.height - _hitTestEpsilon,
    );
    return c.hitTest(result, position: Offset(clampedDx, clampedDy));
  }
}
