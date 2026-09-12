import 'dart:async';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

// Mirrors Flutter's private _kBackGestureWidth in cupertino/route.dart.
const double _platformBackGestureWidth = 20;

/// Horizontal-swipe detector over the fullscreen feed that lets the user tune
/// recommendations: swipe right = "more like this", swipe left = "less like
/// this".
///
/// A committing swipe fires [onTuned]; the parent publishes the signal and
/// pages the feed forward. The child follows the finger and a directional
/// indicator brightens with drag progress; crossing [commitThreshold] fires a
/// haptic tick. Releasing before the threshold snaps back and does nothing.
/// Screen-reader users get the same two actions via custom semantic actions.
class FeedTuningSwipeOverlay extends StatefulWidget {
  /// Creates a swipe-to-tune overlay around [child].
  const FeedTuningSwipeOverlay({
    required this.onTuned,
    required this.child,
    this.commitThreshold = 96,
    super.key,
  });

  /// Called when a swipe commits past [commitThreshold].
  final ValueChanged<FeedTuningDirection> onTuned;

  /// The feed content the gesture wraps.
  final Widget child;

  /// Horizontal drag distance (logical pixels) needed to commit a tune.
  final double commitThreshold;

  @override
  State<FeedTuningSwipeOverlay> createState() => _FeedTuningSwipeOverlayState();
}

class _FeedTuningSwipeOverlayState extends State<FeedTuningSwipeOverlay> {
  double _dragExtent = 0;
  bool _passedThreshold = false;
  Timer? _pointerSignalResetTimer;
  int? _activeDragPointer;
  Offset _dragOffset = Offset.zero;
  _DragIntent _dragIntent = _DragIntent.undecided;

  double get _progress =>
      (_dragExtent.abs() / widget.commitThreshold).clamp(0.0, 1.0);

  FeedTuningDirection? get _direction {
    if (_dragExtent == 0) return null;
    return _dragExtent > 0
        ? FeedTuningDirection.more
        : FeedTuningDirection.less;
  }

  void _applyHorizontalDelta(double delta) {
    setState(() => _dragExtent += delta);
    final passed = _dragExtent.abs() >= widget.commitThreshold;
    if (passed && !_passedThreshold) {
      HapticFeedback.selectionClick();
    }
    _passedThreshold = passed;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activeDragPointer != null) return;
    if (_isPlatformBackGestureStart(event.position)) return;
    _activeDragPointer = event.pointer;
    _dragOffset = Offset.zero;
    _dragIntent = _DragIntent.undecided;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activeDragPointer) return;
    _onDragDelta(event.delta);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activeDragPointer) return;
    _onDragEnd();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activeDragPointer) return;
    _reset();
  }

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (_activeDragPointer != null) return;
    if (_isPlatformBackGestureStart(event.position)) return;
    _activeDragPointer = event.pointer;
    _dragOffset = Offset.zero;
    _dragIntent = _DragIntent.undecided;
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.pointer != _activeDragPointer) return;
    _onDragDelta(event.panDelta);
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    if (event.pointer != _activeDragPointer) return;
    _onDragEnd();
  }

  void _onDragDelta(Offset delta) {
    _dragOffset += delta;
    final absDx = _dragOffset.dx.abs();
    final absDy = _dragOffset.dy.abs();

    if (_dragIntent == _DragIntent.vertical) return;

    if (_dragIntent == _DragIntent.undecided) {
      if (absDx < kTouchSlop && absDy < kTouchSlop) return;
      if (absDy > absDx) {
        _dragIntent = _DragIntent.vertical;
        return;
      }
      _dragIntent = _DragIntent.horizontal;
      _applyHorizontalDelta(_dragOffset.dx);
      return;
    }

    if (!_passedThreshold && absDy > absDx * 1.2) {
      _dragIntent = _DragIntent.vertical;
      _resetVisualState();
      return;
    }

    _applyHorizontalDelta(delta.dx);
  }

  void _onDragEnd() {
    final direction = _direction;
    final committed =
        _dragIntent == _DragIntent.horizontal &&
        _passedThreshold &&
        direction != null;
    _reset();
    if (committed) widget.onTuned(direction);
  }

  bool _isPlatformBackGestureStart(Offset globalPosition) {
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
      return false;
    }

    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic> || !route.popGestureEnabled) return false;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return false;

    final localPosition = renderObject.globalToLocal(globalPosition);
    final textDirection = Directionality.of(context);
    final padding = MediaQuery.paddingOf(context);
    final backGestureWidth = switch (textDirection) {
      TextDirection.ltr => math.max(padding.left, _platformBackGestureWidth),
      TextDirection.rtl => math.max(padding.right, _platformBackGestureWidth),
    };

    return switch (textDirection) {
      TextDirection.ltr =>
        localPosition.dx >= 0 && localPosition.dx <= backGestureWidth,
      TextDirection.rtl =>
        localPosition.dx >= renderObject.size.width - backGestureWidth &&
            localPosition.dx <= renderObject.size.width,
    };
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final scrollDelta = event.scrollDelta;
    if (scrollDelta.dx.abs() <= scrollDelta.dy.abs()) return;

    _pointerSignalResetTimer?.cancel();
    // Pointer scroll deltas are scroll offsets, not finger movement. Negating
    // preserves the same left/right meaning as touch and mouse drags.
    _applyHorizontalDelta(-scrollDelta.dx);

    final direction = _direction;
    if (_passedThreshold && direction != null) {
      _reset();
      widget.onTuned(direction);
      return;
    }

    _pointerSignalResetTimer = Timer(const Duration(milliseconds: 140), _reset);
  }

  void _reset() {
    _pointerSignalResetTimer?.cancel();
    _pointerSignalResetTimer = null;
    _activeDragPointer = null;
    _dragOffset = Offset.zero;
    _dragIntent = _DragIntent.undecided;
    _resetVisualState();
  }

  void _resetVisualState() {
    setState(() {
      _dragExtent = 0;
      _passedThreshold = false;
    });
  }

  @override
  void dispose() {
    _pointerSignalResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final direction = _direction;
    return Semantics(
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: l10n.feedTuningMoreLabel): () =>
            widget.onTuned(FeedTuningDirection.more),
        CustomSemanticsAction(label: l10n.feedTuningLessLabel): () =>
            widget.onTuned(FeedTuningDirection.less),
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        onPointerPanZoomStart: _onPointerPanZoomStart,
        onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
        onPointerPanZoomEnd: _onPointerPanZoomEnd,
        onPointerSignal: _onPointerSignal,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Transform.translate(
              offset: Offset(_dragExtent * 0.4, 0),
              child: widget.child,
            ),
            if (direction != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _TuningIndicator(
                    direction: direction,
                    progress: _progress,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _DragIntent { undecided, horizontal, vertical }

/// Gates [FeedTuningSwipeOverlay] behind a feature flag.
///
/// When [enabled] is false the [child] is returned untouched — no gesture, no
/// indicator, no overlay — so the feed behaves exactly as before. The screen
/// drives [enabled] from `isFeatureEnabledProvider(FeatureFlag.feedTuning)`,
/// which is off by default until the relay and recommendation backend ship.
class FeedTuningSwipeGate extends StatelessWidget {
  /// Creates a feature-gated swipe-to-tune wrapper around [child].
  const FeedTuningSwipeGate({
    required this.enabled,
    required this.onTuned,
    required this.child,
    super.key,
  });

  /// Whether the swipe-to-tune gesture is active.
  final bool enabled;

  /// Called when a swipe commits past the threshold.
  final ValueChanged<FeedTuningDirection> onTuned;

  /// The feed content the gesture wraps when [enabled].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return FeedTuningSwipeOverlay(onTuned: onTuned, child: child);
  }
}

class _TuningIndicator extends StatelessWidget {
  const _TuningIndicator({required this.direction, required this.progress});

  final FeedTuningDirection direction;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMore = direction == FeedTuningDirection.more;
    final color = isMore
        ? VineTheme.vineGreen
        : context.vineColors.onSurfaceMuted;
    final label = isMore ? l10n.feedTuningMoreLabel : l10n.feedTuningLessLabel;
    final icon = isMore ? DivineIconName.arrowUp : DivineIconName.arrowDown;

    return Align(
      alignment: isMore ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: 0.8 + 0.2 * progress,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainerHigh.withValues(
                  alpha: 0.9,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DivineIcon(icon: icon, color: color, size: 28),
                    const SizedBox(height: 4),
                    Text(label, style: VineTheme.labelLargeFont(color: color)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
