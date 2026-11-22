// ABOUTME: Animated TV static noise effect using a fragment shader.
// ABOUTME: Mimics old television "no signal" snow for permission screens.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:unified_logger/unified_logger.dart';

/// A function that creates a [CustomPainter] for the given [time] and
/// [opacity].
@visibleForTesting
typedef PainterFactory =
    CustomPainter Function({required double time, required double opacity});

/// A function that asynchronously loads a [PainterFactory].
@visibleForTesting
typedef ShaderLoader = Future<PainterFactory> Function();

/// Renders an animated TV static / snow noise effect using a fragment shader.
///
/// The effect resembles an old CRT television with no signal.
/// Uses a GLSL fragment shader and animates at ~12 fps internally
/// for an authentic retro feel.
class TvStaticNoise extends StatefulWidget {
  /// Creates a [TvStaticNoise] widget.
  const TvStaticNoise({
    super.key,
    this.opacity = defaultOpacity,
    @visibleForTesting this.shaderLoader,
  }) : assert(
         opacity >= 0.0 && opacity <= 1.0,
         'opacity must be between 0.0 and 1.0',
       );

  /// Overall opacity of the noise layer.
  final double opacity;

  /// Default opacity of the noise layer.
  static const defaultOpacity = 0.07;

  /// Optional shader loader override for testing.
  final ShaderLoader? shaderLoader;

  @override
  State<TvStaticNoise> createState() => _TvStaticNoiseState();
}

class _TvStaticNoiseState extends State<TvStaticNoise>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsed = 0;
  int _frame = -1;
  PainterFactory? _createPainter;
  ui.FragmentShader? _ownedShader;
  bool _loaded = false;

  /// Internal frame rate the shader quantizes to.
  static const _shaderFps = 12;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    unawaited(_loadShader());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _ticker.stop();
      _elapsed = 0;
      _frame = -1;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  Future<void> _loadShader() async {
    try {
      if (widget.shaderLoader != null) {
        _createPainter = await widget.shaderLoader!();
      } else {
        // coverage:ignore-start
        // FragmentProgram.fromAsset requires a GPU shader bundle unavailable in
        // headless widget tests; tests inject [widget.shaderLoader] instead.
        final program = await ui.FragmentProgram.fromAsset(_shaderAssetPath);
        final shader = program.fragmentShader();
        if (!mounted) {
          shader.dispose();
          return;
        }
        _ownedShader = shader;
        final paint = Paint();
        // Reuse a single FragmentShader across frames rather than allocating
        // and leaking a new GPU shader on every 12-fps tick.
        // ignore: avoid_types_on_closure_parameters
        _createPainter = ({required double time, required double opacity}) =>
            _TvStaticPainter(
              shader: shader,
              paint: paint,
              time: time,
              opacity: opacity,
            );
        // coverage:ignore-end
      }
      if (mounted) {
        setState(() => _loaded = true);
      }
    } on Exception catch (e, s) {
      Log.error(
        'Failed to load TV static shader',
        name: 'TvStaticNoise',
        category: LogCategory.ui,
        error: e,
        stackTrace: s,
      );
    }
  }

  void _onTick(Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    final frame = (seconds * _shaderFps).floor();
    if (frame == _frame) return;
    _frame = frame;
    setState(() => _elapsed = seconds);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ownedShader?.dispose();
    _ownedShader = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _createPainter == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _createPainter!(time: _elapsed, opacity: widget.opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// coverage:ignore-start

/// Asset path for the TV static fragment shader.
const _shaderAssetPath = 'packages/tv_static_effect/shaders/tv_static.frag';

class _TvStaticPainter extends CustomPainter {
  _TvStaticPainter({
    required ui.FragmentShader shader,
    required Paint paint,
    required this.time,
    required this.opacity,
  }) : _shader = shader,
       _paint = paint;

  final ui.FragmentShader _shader;
  final Paint _paint;
  final double time;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    _shader
      ..setFloat(0, size.width) // uSize.x
      ..setFloat(1, size.height) // uSize.y
      ..setFloat(2, time) // uTime
      ..setFloat(3, opacity); // uOpacity

    _paint.shader = _shader;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(_TvStaticPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.opacity != opacity;
}

// coverage:ignore-end
