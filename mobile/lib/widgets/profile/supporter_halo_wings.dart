// ABOUTME: Divine Supporter treatment around the profile avatar: a floating
// ABOUTME: halo and two wings, gently animated by one repeating controller.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Called with the animation of a route that lifts the avatar away, such as
/// the avatar lightbox, so the halo and wings can follow it out and back.
typedef TrackCoveringTransition = void Function(Animation<double> transition);

/// Wraps the avatar from [builder] with a halo above it and a wing on each
/// side.
///
/// Geometry comes from the Figma profile frame, where the avatar is 144pt.
/// Every offset is stored as a fraction of that size so the treatment scales
/// with whatever [avatarSize] it is given.
class SupporterHaloWings extends StatefulWidget {
  const SupporterHaloWings({
    required this.avatarSize,
    required this.builder,
    this.sparkles,
    this.fadeIn = false,
    super.key,
  });

  final double avatarSize;

  /// Whether the halo and wings fade in when this first appears, rather than
  /// being there from the start. Set where supporter status arrives after the
  /// avatar is already on screen; left off where the group flies in whole.
  final bool fadeIn;

  /// When set, twinkling sparkles surround the group, faded in by this value.
  /// Used where the supporter status is the subject, such as its lightbox.
  final Animation<double>? sparkles;

  /// Builds the avatar. Call the given callback with the route animation when
  /// the avatar opens something that flies it away.
  final Widget Function(BuildContext context, TrackCoveringTransition track)
  builder;

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
  static const Duration reveal = Duration(milliseconds: 300);
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

  /// Sparkles pulse between this scale and full size, each on its own beat.
  static const double sparkleMinScale = 0.55;
  static const double sparkleTiltRadians = 12 * math.pi / 180;
}

/// Accents around the avatar: offset from its top-left corner and size, as
/// fractions of the avatar size, a phase so they do not pulse together, and
/// the image. Hearts sit in opposite corners, sparkles in the other two.
const _sparkleAsset = 'assets/supporter/sparkle.png';
const _heartAsset = 'assets/supporter/heart.png';
const List<({double dx, double dy, double size, double phase, String asset})>
_sparkles = [
  (dx: -0.12, dy: -0.04, size: 0.16, phase: 0, asset: _heartAsset),
  (dx: -0.36, dy: 0.62, size: 20 / 192, phase: 0.35, asset: _sparkleAsset),
  (dx: 0.98, dy: 0.12, size: 0.16, phase: 0.55, asset: _sparkleAsset),
  (dx: 1.02, dy: 0.88, size: 20 / 192, phase: 0.8, asset: _heartAsset),
];

class _SupporterHaloWingsState extends State<SupporterHaloWings>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _Motion.period,
  );

  /// Opacity of the halo and wings, below 1 only while fading in.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _Motion.reveal,
    value: widget.fadeIn ? 0 : 1,
  );
  late final AppLifecycleListener _lifecycle;
  final Key _visibilityKey = UniqueKey();
  bool _visible = true;

  /// The lightbox transition while it is open or closing, else null.
  Animation<double>? _cover;

  void _trackCover(Animation<double> transition) {
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      transition.removeStatusListener(onStatus);
      if (mounted && identical(_cover, transition)) {
        setState(() => _cover = null);
      }
    }

    transition.addStatusListener(onStatus);
    setState(() => _cover = transition);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reveal.isDismissed) {
      if (context.reduceMotion) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    }
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
      if (!_controller.isAnimating) {
        // Every instance starts from the wall clock, so the header and the
        // lightbox copy stay in step while the avatar flies between them.
        final periodMs = _Motion.period.inMilliseconds;
        _controller
          ..value =
              (DateTime.now().millisecondsSinceEpoch % periodMs) / periodMs
          ..repeat();
      }
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
    _reveal.dispose();
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
                // Accents sit behind the wings, avatar and halo.
                if (widget.sparkles case final visibility?)
                  for (final sparkle in _sparkles)
                    Positioned(
                      left: outset + (sparkle.dx - sparkle.size / 2) * size,
                      top: (sparkle.dy - sparkle.size / 2) * size,
                      width: sparkle.size * size,
                      height: sparkle.size * size,
                      child: FadeTransition(
                        opacity: visibility,
                        child: _AnimatedPart(
                          animation: _controller,
                          builder: (t) => _Sparkle(t: t, phase: sparkle.phase),
                          child: _PartImage(sparkle.asset),
                        ),
                      ),
                    ),
                Positioned(
                  left: 0,
                  top: wingTop,
                  width: wingWidth,
                  height: wingHeight,
                  child: _CoverFade(
                    reveal: _reveal,
                    cover: _cover,
                    // The avatar's centre, in this wing's own coordinates.
                    origin: Offset(outset + size / 2, size / 2 - wingTop),
                    child: _AnimatedPart(
                      animation: _controller,
                      builder: (t) => _Wing(t: t, isLeft: true),
                      child: const _PartImage('assets/supporter/wing_left.png'),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: wingTop,
                  width: wingWidth,
                  height: wingHeight,
                  child: _CoverFade(
                    reveal: _reveal,
                    cover: _cover,
                    origin: Offset(
                      wingWidth - outset - size / 2,
                      size / 2 - wingTop,
                    ),
                    child: _AnimatedPart(
                      animation: _controller,
                      builder: (t) => _Wing(t: t, isLeft: false),
                      child: const _PartImage(
                        'assets/supporter/wing_right.png',
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: outset,
                  top: 0,
                  width: size,
                  height: size,
                  child: widget.builder(context, _trackCover),
                ),
                Positioned(
                  left: outset + (size - haloWidth) / 2,
                  top: size * _Geometry.haloTop,
                  width: haloWidth,
                  height: haloHeight,
                  child: _CoverFade(
                    reveal: _reveal,
                    cover: _cover,
                    origin: Offset(
                      haloWidth / 2,
                      size / 2 - size * _Geometry.haloTop,
                    ),
                    child: _AnimatedPart(
                      animation: _controller,
                      builder: (t) => _Halo(t: t, avatarSize: size),
                      child: const _PartImage('assets/supporter/halo.png'),
                    ),
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

class _Sparkle implements _PartTransform {
  _Sparkle({required this.t, required this.phase});

  final double t;
  final double phase;

  @override
  Matrix4 get matrix {
    final wave = (math.sin((t + phase) * 2 * math.pi) + 1) / 2;
    final scale =
        _Motion.sparkleMinScale + (1 - _Motion.sparkleMinScale) * wave;
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..rotateZ((wave - 0.5) * _Motion.sparkleTiltRadians);
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

/// Fades a halo or wing in with [reveal], and hides it while the avatar is
/// lifted away by [cover].
///
/// It fades and draws in toward the avatar as the avatar takes off, and
/// returns only as the avatar lands, so neither is left floating around an
/// empty spot. Following the route animation keeps it in step when a close
/// is interrupted or swiped back.
class _CoverFade extends StatelessWidget {
  const _CoverFade({
    required this.reveal,
    required this.cover,
    required this.origin,
    required this.child,
  });

  /// Share of the opening transition the fade-out takes (~150 ms of 300).
  static const Interval _leave = Interval(0, 0.5, curve: Curves.easeOut);

  /// Share of the closing transition, from its end, that the return takes.
  static const Interval _land = Interval(0, 0.3, curve: Curves.easeIn);

  static const double _hiddenScale = 0.85;

  /// Fades the part in when supporter status arrives after the avatar.
  final Animation<double> reveal;
  final Animation<double>? cover;
  final Offset origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cover = this.cover;
    if (cover == null) return FadeTransition(opacity: reveal, child: child);
    final reduceMotion = context.reduceMotion;
    return FadeTransition(
      opacity: reveal,
      child: AnimatedBuilder(
        animation: cover,
        builder: (context, child) {
          final hidden = reduceMotion
              ? (cover.value > 0 ? 1.0 : 0.0)
              : (cover.status == AnimationStatus.reverse ? _land : _leave)
                    .transform(cover.value);
          final scale = 1 - (1 - _hiddenScale) * hidden;
          return Opacity(
            opacity: 1 - hidden,
            child: Transform(
              origin: origin,
              transform: Matrix4.diagonal3Values(scale, scale, 1),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
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
