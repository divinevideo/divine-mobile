// ABOUTME: Animated heart overlay shown on double-tap-to-like gesture.
// ABOUTME: Uses AnimationController with Interval-based scale and opacity
// ABOUTME: animations. Triggered via a ValueNotifier<HeartTrigger?>.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Data carried by a double-tap heart trigger.
///
/// Pairs the tap [offset] with a unique [id] so that consecutive taps at
/// the same position still notify listeners.
typedef HeartTrigger = ({Offset offset, int id});

/// Animation durations for the double-tap heart.
abstract class _HeartAnimation {
  static const totalDuration = Duration(milliseconds: 1000);

  /// Scale animates from 0 to 1 in the first 25% of the timeline.
  static const scaleEnd = 0.25;

  /// Opacity begins fading at 60% and reaches 0 at 100%.
  static const fadeStart = 0.6;
}

/// Size of the heart icon in logical pixels.
const _heartSize = 120.0;

/// Animated heart overlay that appears on double-tap-to-like.
///
/// Listens to [trigger] and starts a scale-up + fade-out animation each time
/// the trigger notifies. The heart is positioned at the tap location.
/// Wraps itself in [IgnorePointer] so it never consumes tap events.
///
/// Must be placed inside a [Positioned.fill] (or equivalent) so that the
/// internal [Stack] + [Positioned] can lay out correctly.
class DoubleTapHeartOverlay extends StatefulWidget {
  const DoubleTapHeartOverlay({required this.trigger, super.key});

  /// A [ValueNotifier] that triggers the animation when it notifies.
  ///
  /// Set to a [HeartTrigger] with the tap offset and a unique id on each
  /// double-tap.
  final ValueNotifier<HeartTrigger?> trigger;

  @override
  State<DoubleTapHeartOverlay> createState() => _DoubleTapHeartOverlayState();
}

class _DoubleTapHeartOverlayState extends State<DoubleTapHeartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  bool _visible = false;
  Offset? _position;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync: this,
          duration: _HeartAnimation.totalDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _visible = false);
          }
        });

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0,
          _HeartAnimation.scaleEnd,
          curve: Curves.elasticOut,
        ),
      ),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: _HeartAnimation.fadeStart * 100,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: (1 - _HeartAnimation.fadeStart) * 100,
      ),
    ]).animate(_controller);

    widget.trigger.addListener(_onTrigger);
  }

  @override
  void didUpdateWidget(covariant DoubleTapHeartOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_onTrigger);
      widget.trigger.addListener(_onTrigger);
    }
  }

  void _onTrigger() {
    final value = widget.trigger.value;
    if (value == null) return;
    _position = value.offset;
    setState(() => _visible = true);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_onTrigger);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (!_visible || _position == null) return const SizedBox.shrink();
          return Stack(
            children: [
              Positioned(
                left: _position!.dx - _heartSize / 2,
                top: _position!.dy - _heartSize / 2,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: const DivineIcon(
          icon: DivineIconName.heartDuo,
          size: _heartSize,
          color: VineTheme.likeRed,
        ),
      ),
    );
  }
}
