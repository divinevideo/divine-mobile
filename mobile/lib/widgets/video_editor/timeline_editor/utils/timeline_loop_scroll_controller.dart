import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Scroll controller for the editor timeline that wraps a user drag around
/// the loop point.
///
/// The composition plays as a loop, so dragging past its end continues at its
/// start and dragging past its start continues at its end — within the same
/// gesture, so the loop restart can be scrubbed back and forth. Only finger
/// drags wrap: flings and programmatic scrolls (playback sync, zoom anchoring,
/// reorder auto-scroll) still clamp at the ends.
class TimelineLoopScrollController extends ScrollController {
  TimelineLoopScrollController({this.onUserWrap});

  /// Called each time a user drag wraps around the loop point.
  final VoidCallback? onUserWrap;

  /// Scroll offset at which the composition ends — the loop point.
  ///
  /// Content laid out past it, such as the loop-restart button's trailing
  /// slot, stays unscrollable: every offset there maps to the composition's
  /// last instant, so the preview would freeze just before the wrap. `null`
  /// scrolls the full content extent. Takes effect on the next layout.
  double? loopExtent;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _LoopScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
      onUserWrap: onUserWrap,
      loopExtent: () => loopExtent,
    );
  }
}

class _LoopScrollPosition extends ScrollPositionWithSingleContext {
  _LoopScrollPosition({
    required super.physics,
    required super.context,
    required this.loopExtent,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    this.onUserWrap,
  });

  final VoidCallback? onUserWrap;
  final ValueGetter<double?> loopExtent;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final loopEnd = loopExtent();
    return super.applyContentDimensions(
      minScrollExtent,
      loopEnd == null
          ? maxScrollExtent
          : loopEnd.clamp(minScrollExtent, maxScrollExtent),
    );
  }

  @override
  void applyUserOffset(double delta) {
    final range = hasContentDimensions
        ? maxScrollExtent - minScrollExtent
        : 0.0;
    if (range <= 0) {
      super.applyUserOffset(delta);
      return;
    }

    // Moving the pixels through setPixels keeps the drag activity alive —
    // jumpTo would end it and the finger would have to be lifted first.
    updateUserScrollDirection(
      delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    final target = pixels - physics.applyPhysicsToUserOffset(this, delta);
    if (target >= minScrollExtent && target <= maxScrollExtent) {
      setPixels(target);
      return;
    }
    setPixels(minScrollExtent + (target - minScrollExtent) % range);
    onUserWrap?.call();
  }
}
