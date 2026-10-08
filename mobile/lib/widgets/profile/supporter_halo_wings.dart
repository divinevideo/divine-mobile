// ABOUTME: Divine Supporter treatment around the profile avatar: a floating
// ABOUTME: halo and two wings, gently animated by one repeating controller.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:visibility_detector/visibility_detector.dart';

// TODO(#9914): Prototype switch. Replace with real supporter status before
// this ships; for now `--dart-define=SUPPORTER_HALO_PREVIEW=true` forces the
// treatment on the signed-in user's own profile.
const bool supporterHaloPreview = bool.fromEnvironment(
  'SUPPORTER_HALO_PREVIEW',
);

/// Wraps [child] (the avatar) with a halo above it and a wing on each side.
///
/// Geometry comes from the Figma profile frame, where the avatar is 144pt.
/// Every offset is stored as a fraction of that size so the treatment scales
/// with whatever [avatarSize] it is given.
class SupporterHaloWings extends StatefulWidget {
  const SupporterHaloWings({
    required this.avatarSize,
    required this.child,
    super.key,
  });

  final double avatarSize;
  final Widget child;

  @override
  State<SupporterHaloWings> createState() => _SupporterHaloWingsState();
}

/// Figma geometry, as fractions of the 144pt avatar.
abstract class _Geometry {
  static const double _figmaAvatar = 144;

  static const double wingWidth = 46 / _figmaAvatar;
  static const double wingHeight = 97 / _figmaAvatar;
  static const double wingTop = 14 / _figmaAvatar;

  /// How far each wing reaches past the avatar edge (it tucks 3pt behind it).
  static const double wingOutset = 43 / _figmaAvatar;

  static const double haloWidth = 75.76 / _figmaAvatar;
  static const double haloHeight = 28 / _figmaAvatar;
  static const double haloTop = -37 / _figmaAvatar;
}

/// Motion amplitudes. Kept small: the avatar should breathe, not flap.
abstract class _Motion {
  static const Duration period = Duration(milliseconds: 3000);
  static const double haloBobFraction = 3 / 144;
  static const double haloTiltRadians = 2.5 * math.pi / 180;

  /// The whole group floats like the halo, but smaller and trailing it, so
  /// the halo still reads as hovering over the head rather than fixed to it.
  static const double groupBobFraction = 2 / 144;
  static const double groupTiltRadians = 0.5 * math.pi / 180;
  static const double groupPhaseLag = 0.15;

  /// Wings swing between these angles, always tipping down from the Figma
  /// pose, so the inner edge below the pivot stays tucked behind the avatar.
  static const double wingLowRadians = 10 * math.pi / 180;
  static const double wingHighRadians = 1 * math.pi / 180;

  /// The right wing trails the left by this share of a cycle.
  static const double wingPhaseLag = 0.08;
}

class _SupporterHaloWingsState extends State<SupporterHaloWings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _Motion.period,
  );
  late final AppLifecycleListener _lifecycle;
  final Key _visibilityKey = UniqueKey();
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  /// Runs the loop only while it can be seen and motion is allowed.
  void _sync() {
    final appVisible =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden;
    if (context.reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
    } else if (_visible && appVisible) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    _visible = info.visibleFraction > 0;
    _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.avatarSize;
    final outset = size * _Geometry.wingOutset;
    final wingWidth = size * _Geometry.wingWidth;
    final wingHeight = size * _Geometry.wingHeight;
    final wingTop = size * _Geometry.wingTop;
    final haloWidth = size * _Geometry.haloWidth;
    final haloHeight = size * _Geometry.haloHeight;

    // The box claims the wings' width so nothing beside it can crowd them.
    // The halo is left to overflow upward into the empty middle of the nav
    // row, matching Figma where it sits above the avatar's own frame.
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: _AnimatedPart(
        animation: _controller,
        builder: (t) => _Group(t: t, avatarSize: size),
        // Its own boundary keeps the static avatar from repainting as the
        // group moves.
        child: RepaintBoundary(
          child: SizedBox(
            width: size + outset * 2,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: wingTop,
                  width: wingWidth,
                  height: wingHeight,
                  child: _AnimatedPart(
                    animation: _controller,
                    builder: (t) => _Wing(t: t, isLeft: true),
                    child: const _PartImage('assets/supporter/wing_left.png'),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: wingTop,
                  width: wingWidth,
                  height: wingHeight,
                  child: _AnimatedPart(
                    animation: _controller,
                    builder: (t) => _Wing(t: t, isLeft: false),
                    child: const _PartImage('assets/supporter/wing_right.png'),
                  ),
                ),
                Positioned(
                  left: outset,
                  top: 0,
                  width: size,
                  height: size,
                  child: widget.child,
                ),
                Positioned(
                  left: outset + (size - haloWidth) / 2,
                  top: size * _Geometry.haloTop,
                  width: haloWidth,
                  height: haloHeight,
                  child: _AnimatedPart(
                    animation: _controller,
                    builder: (t) => _Halo(t: t, avatarSize: size),
                    child: const _PartImage('assets/supporter/halo.png'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A transform computed from the loop position `t` in [0, 1).
abstract class _PartTransform {
  Matrix4 get matrix;
  Alignment get origin;
}

class _Wing implements _PartTransform {
  _Wing({required this.t, required this.isLeft});

  final double t;
  final bool isLeft;

  @override
  Matrix4 get matrix {
    final phase = isLeft ? t : t - _Motion.wingPhaseLag;
    const mid = (_Motion.wingLowRadians + _Motion.wingHighRadians) / 2;
    const amplitude = (_Motion.wingLowRadians - _Motion.wingHighRadians) / 2;
    final drop = mid + math.sin(phase * 2 * math.pi) * amplitude;
    // Tipping down swings the inner edge below the pivot into the avatar.
    return Matrix4.rotationZ(isLeft ? -drop : drop);
  }

  // Pivot on the upper inner edge, like a shoulder joint.
  @override
  Alignment get origin =>
      isLeft ? const Alignment(1, -0.2) : const Alignment(-1, -0.2);
}

class _Halo implements _PartTransform {
  _Halo({required this.t, required this.avatarSize});

  final double t;
  final double avatarSize;

  @override
  Matrix4 get matrix {
    final angle = t * 2 * math.pi;
    final bob = -math.sin(angle) * avatarSize * _Motion.haloBobFraction;
    final tilt = math.sin(angle + math.pi / 2) * _Motion.haloTiltRadians;
    return Matrix4.translationValues(0, bob, 0)..rotateZ(tilt);
  }

  @override
  Alignment get origin => Alignment.center;
}

class _Group implements _PartTransform {
  _Group({required this.t, required this.avatarSize});

  final double t;
  final double avatarSize;

  @override
  Matrix4 get matrix {
    final angle = (t - _Motion.groupPhaseLag) * 2 * math.pi;
    final bob = -math.sin(angle) * avatarSize * _Motion.groupBobFraction;
    final tilt = math.sin(angle + math.pi / 2) * _Motion.groupTiltRadians;
    return Matrix4.translationValues(0, bob, 0)..rotateZ(tilt);
  }

  @override
  Alignment get origin => Alignment.center;
}

/// Applies a per-frame transform to an image without rebuilding it.
class _AnimatedPart extends StatelessWidget {
  const _AnimatedPart({
    required this.animation,
    required this.builder,
    required this.child,
  });

  final Animation<double> animation;
  final _PartTransform Function(double t) builder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final part = builder(animation.value);
          return Transform(
            transform: part.matrix,
            alignment: part.origin,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

class _PartImage extends StatelessWidget {
  const _PartImage(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
