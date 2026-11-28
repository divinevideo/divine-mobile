import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Hands each pointer signal over its child to [onPointerSignal] before the
/// child sees it.
///
/// A [Listener] hears a pointer signal only after everything below it, so a
/// scrollable inside it bids for the scroll with the pointer signal resolver
/// first and takes it. A page view also stops its pages from hearing any
/// pointer event while it animates, so a listener inside a page misses the
/// wheel at exactly that moment. This listener enters the hit test ahead of its
/// child instead, so [onPointerSignal] always bids first.
///
/// It is hit wherever it covers, like the opaque scrollable it is meant to
/// wrap.
class PriorityPointerSignalListener extends SingleChildRenderObjectWidget {
  /// Creates a listener that hears pointer signals before [child].
  const PriorityPointerSignalListener({
    required this.onPointerSignal,
    super.child,
    super.key,
  });

  /// Called with every pointer signal over this widget.
  final PointerSignalEventListener onPointerSignal;

  @override
  RenderPriorityPointerSignalListener createRenderObject(
    BuildContext context,
  ) => RenderPriorityPointerSignalListener(onPointerSignal);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPriorityPointerSignalListener renderObject,
  ) {
    renderObject.onPointerSignal = onPointerSignal;
  }
}

/// The render object of [PriorityPointerSignalListener].
class RenderPriorityPointerSignalListener extends RenderProxyBox {
  /// Creates a render object that hears pointer signals before its child.
  RenderPriorityPointerSignalListener(this.onPointerSignal);

  /// Called with every pointer signal over this render object.
  PointerSignalEventListener onPointerSignal;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // Added before the child, so the pointer signal reaches this entry first.
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerSignalEvent) onPointerSignal(event);
  }
}
