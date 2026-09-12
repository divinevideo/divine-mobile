// ABOUTME: Full-screen TikTok/Instagram-style reaction animation over the reel.
// ABOUTME: A big emoji springs in at screen center (overshoot), holds, floats
// ABOUTME: up and fades, garnished by a few floating-particle copies.
//
// Rendered on a SINGLE GPU layer: the emoji is rasterized once to a
// `ui.Image`, then the hero + particles are drawn by one `CustomPainter` via
// `drawImageRect` (alpha modulated through `paint.color`, transforms through
// the canvas). This avoids the per-frame `Opacity` save-layers and per-frame
// widget rebuilds that made the previous `Stack`-of-`Text` version stutter on
// low-end devices (#5389).

import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Font size the hero emoji is rasterized at; particles draw the same image
/// scaled down.
const double _heroFontSize = 120;

/// One-shot reaction animation centered over the player. The hero emoji springs
/// in with an overshoot (`easeOutBack`), holds, then floats up ~70px while
/// fading; a light layer of floating copies sways upward alongside it.
///
/// Rebuild with a fresh `key` (e.g. `ValueKey(nonce)`) to replay on each tap.
class ReactionOverlay extends StatefulWidget {
  /// Creates a reaction overlay for [emoji]. [onComplete] fires when the
  /// animation ends so the host can remove the overlay.
  const ReactionOverlay({required this.emoji, this.onComplete, super.key});

  /// The emoji to animate.
  final String emoji;

  /// Called once the animation completes.
  final VoidCallback? onComplete;

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1100);
  static const int _particleCount = 5;

  /// Extra resolution headroom so the hero's `easeOutBack` overshoot
  /// (peak scale ~1.28) never upsamples the rasterized glyph past device
  /// pixels.
  static const double _supersample = 1.3;

  late final AnimationController _controller;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroGrow;
  late final Animation<double> _heroOpacity;
  late final Animation<double> _heroY;
  late final List<_Particle> _particles;

  /// The emoji rasterized once to a GPU image; null until prepared.
  ui.Image? _emojiImage;

  /// Logical size of the rasterized glyph at [_heroFontSize] (the draw size
  /// before any animated scale).
  Size _baseSize = Size.zero;
  bool _prepared = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete?.call();
      })
      ..forward();

    // Spring in with a single ~27.5% overshoot, settle to 1.0.
    _heroScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    // Gentle extra grow as it floats away.
    _heroGrow = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 1)),
    );
    _heroOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1), weight: 50),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_controller);
    _heroY = Tween<double>(begin: 0, end: -70).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1, curve: Curves.easeOut),
      ),
    );

    final random = Random();
    _particles = List.generate(
      _particleCount,
      (_) => _Particle.random(random),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rasterize the emoji once (needs the device pixel ratio from context).
    // Runs before the first build, so the first frame paints the image.
    if (_prepared) return;
    _prepared = true;
    _prepareEmojiImage();
  }

  void _prepareEmojiImage() {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.emoji,
        style: const TextStyle(fontSize: _heroFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final logicalSize = textPainter.size;
    final pixelScale = devicePixelRatio * _supersample;
    final pixelWidth = (logicalSize.width * pixelScale).ceil();
    final pixelHeight = (logicalSize.height * pixelScale).ceil();
    if (pixelWidth <= 0 || pixelHeight <= 0) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelScale);
    textPainter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    _emojiImage = picture.toImageSync(pixelWidth, pixelHeight);
    _baseSize = logicalSize;
    picture.dispose();
  }

  @override
  void dispose() {
    _emojiImage?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ReactionPainter(
            image: _emojiImage,
            baseSize: _baseSize,
            progress: _controller,
            heroScale: _heroScale,
            heroGrow: _heroGrow,
            heroOpacity: _heroOpacity,
            heroY: _heroY,
            particles: _particles,
          ),
        ),
      ),
    );
  }
}

/// Paints the hero + particle emoji from a single rasterized [image] on one
/// canvas. Repaints on every [progress] tick without rebuilding any widget;
/// opacity is applied via `paint.color` (no save-layer) and position/scale/
/// rotation via canvas transforms.
class _ReactionPainter extends CustomPainter {
  _ReactionPainter({
    required this.image,
    required this.baseSize,
    required this.progress,
    required this.heroScale,
    required this.heroGrow,
    required this.heroOpacity,
    required this.heroY,
    required this.particles,
  }) : super(repaint: progress);

  final ui.Image? image;
  final Size baseSize;
  final Animation<double> progress;
  final Animation<double> heroScale;
  final Animation<double> heroGrow;
  final Animation<double> heroOpacity;
  final Animation<double> heroY;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final glyph = image;
    if (glyph == null) return;

    final t = progress.value;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final source = Rect.fromLTWH(
      0,
      0,
      glyph.width.toDouble(),
      glyph.height.toDouble(),
    );

    // Secondary floating-particle layer (garnish). All particles share the
    // same opacity curve, varying only in position, scale and tilt.
    final particleOpacity = sin(t * pi).clamp(0.0, 1.0);
    for (final p in particles) {
      final dx =
          centerX +
          p.startX +
          p.amplitude * sin(p.frequency * t * 2 * pi + p.phase);
      final dy = centerY - p.riseHeight * t;
      final scale = (p.size * 0.85 / _heroFontSize) * p.scaleAt(t);
      final rotation = 0.035 * sin(p.frequency * t * 2 * pi);
      _paintEmoji(
        canvas,
        glyph,
        source,
        Offset(dx, dy),
        scale,
        rotation,
        particleOpacity,
      );
    }

    // Primary hero pop at screen center.
    _paintEmoji(
      canvas,
      glyph,
      source,
      Offset(centerX, centerY + heroY.value),
      heroScale.value * heroGrow.value,
      0,
      heroOpacity.value.clamp(0.0, 1.0),
    );
  }

  void _paintEmoji(
    Canvas canvas,
    ui.Image glyph,
    Rect source,
    Offset center,
    double scale,
    double rotation,
    double opacity,
  ) {
    if (opacity <= 0 || scale <= 0) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.drawImageRect(
      glyph,
      source,
      Rect.fromCenter(
        center: Offset.zero,
        width: baseSize.width,
        height: baseSize.height,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReactionPainter oldDelegate) =>
      image != oldDelegate.image || baseSize != oldDelegate.baseSize;
}

class _Particle {
  _Particle({
    required this.startX,
    required this.size,
    required this.scale,
    required this.riseHeight,
    required this.amplitude,
    required this.frequency,
    required this.phase,
  });

  factory _Particle.random(Random r) => _Particle(
    startX: (r.nextDouble() - 0.5) * 60, // ±30px
    size: 44,
    scale: 0.6 + r.nextDouble() * 0.4, // 0.6–1.0
    riseHeight: 180 + r.nextDouble() * 140, // 180–320
    amplitude: 12 + r.nextDouble() * 22, // 12–34
    frequency: 1.0 + r.nextDouble() * 1.5, // 1.0–2.5
    phase: r.nextDouble() * 2 * pi,
  );

  final double startX;
  final double size;
  final double scale;
  final double riseHeight;
  final double amplitude;
  final double frequency;
  final double phase;

  /// Pop in (easeOutBack, first 20%), hold, then shrink out (last 25%).
  double scaleAt(double t) {
    if (t < 0.20) return scale * Curves.easeOutBack.transform(t / 0.20);
    if (t > 0.75) return scale * (1 - (t - 0.75) / 0.25);
    return scale;
  }
}
