// ABOUTME: Swipe from the leading edge that drags a route's transition back
// ABOUTME: by hand, as iOS's back swipe does, and pops it or settles it back.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// How wide the strip along the leading edge that starts the swipe is, when
/// the screen's padding there is narrower.
const double _edgeWidth = 20;

/// How fast, in screen widths per second, a release flings the route out or
/// back regardless of how far it was dragged.
const double _minFlingVelocity = 1;

/// Starts a [VideoTileBackGesture] when a horizontal drag begins on the
/// leading edge of [child], while [enabledCallback] allows it.
///
/// Mirrors the back swipe a Cupertino page route has, which a route with its
/// own transition does not get.
class VideoTileBackGestureDetector extends StatefulWidget {
  /// Watches the leading edge of [child].
  const VideoTileBackGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
    super.key,
  });

  /// Whether a drag starting now may pop the route.
  final ValueGetter<bool> enabledCallback;

  /// Starts dragging the route.
  final ValueGetter<VideoTileBackGesture> onStartPopGesture;

  /// The route's transition and page.
  final Widget child;

  @override
  State<VideoTileBackGestureDetector> createState() =>
      _VideoTileBackGestureDetectorState();
}

class _VideoTileBackGestureDetectorState
    extends State<VideoTileBackGestureDetector> {
  late final HorizontalDragGestureRecognizer _recognizer =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = _onCancel;

  VideoTileBackGesture? _gesture;

  @override
  void dispose() {
    _recognizer.dispose();
    _gesture?.abandon();
    _gesture = null;
    super.dispose();
  }

  void _onStart(DragStartDetails details) {
    _gesture = widget.onStartPopGesture();
  }

  void _onUpdate(DragUpdateDetails details) {
    _gesture?.dragUpdate(_logical(details.primaryDelta! / context.size!.width));
  }

  void _onEnd(DragEndDetails details) {
    _gesture?.dragEnd(
      _logical(details.velocity.pixelsPerSecond.dx / context.size!.width),
    );
    _gesture = null;
  }

  void _onCancel() {
    // Also called for a pointer that never started a drag.
    _gesture?.dragEnd(0);
    _gesture = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) _recognizer.addPointer(event);
  }

  double _logical(double value) => switch (Directionality.of(context)) {
    TextDirection.rtl => -value,
    TextDirection.ltr => value,
  };

  @override
  Widget build(BuildContext context) {
    // A notch on the leading side widens the strip to clear it.
    final padding = MediaQuery.paddingOf(context);
    final notch = switch (Directionality.of(context)) {
      TextDirection.rtl => padding.right,
      TextDirection.ltr => padding.left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: math.max(notch, _edgeWidth),
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _onPointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Drags a route's transition back by hand, from 1 (open) towards 0 (closed),
/// and when released pops the route or settles it back open.
///
/// [inProgress] is `true` from the start of the drag until the route has
/// settled, so the transition can follow the finger linearly throughout,
/// rather than switching to its own curves when the finger lifts.
class VideoTileBackGesture {
  /// Starts dragging [controller], the route's, back.
  VideoTileBackGesture({
    required this.navigator,
    required this.controller,
    required this.inProgress,
    required this.isCurrent,
    required this.isActive,
    required this.openDuration,
    required this.closeDuration,
  }) {
    navigator.didStartUserGesture();
    inProgress.value = true;
  }

  /// The navigator the route is in.
  final NavigatorState navigator;

  /// The route's transition controller.
  final AnimationController controller;

  /// Whether the route is being dragged or settling from a drag.
  final ValueNotifier<bool> inProgress;

  /// Whether the route is still the top one.
  final ValueGetter<bool> isCurrent;

  /// Whether the route is still in the navigator.
  final ValueGetter<bool> isActive;

  /// How long settling back open from fully closed takes.
  final Duration openDuration;

  /// How long closing from fully open takes.
  final Duration closeDuration;

  /// The finger has moved [delta] screen widths towards closing.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// The finger has lifted moving at [velocity] screen widths per second
  /// towards closing.
  void dragEnd(double velocity) {
    final current = isCurrent();
    final bool open;
    if (!current) {
      // Popped or covered while dragging: follow what happened to the route.
      open = isActive();
    } else if (velocity.abs() >= _minFlingVelocity) {
      open = velocity <= 0;
    } else {
      open = controller.value > 0.5;
    }
    if (open) {
      controller.animateTo(
        1,
        duration: openDuration * (1 - controller.value),
        curve: Curves.easeOutCubic,
      );
    } else {
      if (current) navigator.pop();
      // The pop may have finished at once if the route was fully dragged out.
      if (controller.isAnimating) {
        controller.animateBack(
          0,
          duration: closeDuration * controller.value,
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (controller.isAnimating) {
      void settled(AnimationStatus status) {
        if (status.isAnimating) return;
        controller.removeStatusListener(settled);
        _stop();
      }

      controller.addStatusListener(settled);
    } else {
      _stop();
    }
  }

  /// The route went away mid-drag, taking its transition with it.
  void abandon() {
    // Disposal is no time to change the navigator's state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) navigator.didStopUserGesture();
    });
  }

  void _stop() {
    inProgress.value = false;
    if (navigator.mounted) navigator.didStopUserGesture();
  }
}
