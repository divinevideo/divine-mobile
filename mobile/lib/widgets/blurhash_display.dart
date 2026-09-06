// ABOUTME: Widget for displaying blurhash placeholders with smooth transitions
// ABOUTME: Provides progressive image loading experience for video thumbnails

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blurhash_service/blurhash_service.dart';
import 'package:flutter/material.dart';
import 'package:unified_logger/unified_logger.dart';

/// Widget that displays a blurhash as a placeholder image
class BlurhashDisplay extends StatefulWidget {
  const BlurhashDisplay({
    required this.blurhash,
    super.key,
    this.contentType,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.opacity = 1.0,
  });

  final String? blurhash;
  final VineContentType? contentType;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Alpha applied at paint level (no [Opacity] saveLayer). Used by the
  /// fullscreen feed backdrop, which dims the blurhash to 50%.
  final double opacity;

  @override
  State<BlurhashDisplay> createState() => _BlurhashDisplayState();
}

class _BlurhashDisplayState extends State<BlurhashDisplay> {
  BlurhashData? _blurhashData;
  Future<ui.Image?>? _imageFuture;

  /// The decoded image this state owns. [FutureBuilder] only borrows it; it is
  /// disposed here once a newer decode lands, and in [dispose].
  ui.Image? _image;

  /// Bumped per decode and in [dispose], so a decode that lands late disposes
  /// its own result instead of replacing a newer one.
  int _decodeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _decodeBlurhash();
  }

  @override
  void didUpdateWidget(BlurhashDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurhash != widget.blurhash ||
        oldWidget.contentType != widget.contentType) {
      _decodeBlurhash();
    }
  }

  @override
  void dispose() {
    _decodeGeneration++;
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  void _decodeBlurhash() {
    final hash =
        widget.blurhash ??
        (widget.contentType != null
            ? BlurhashService.getBlurhashForContentType(widget.contentType!)
            : BlurhashService.getDefaultVineBlurhash());

    try {
      final data = BlurhashService.decodeBlurhash(hash);

      if (mounted && data != null) {
        // Cache the decode future so its identity stays stable across parent
        // rebuilds — otherwise FutureBuilder restarts the decode and re-shows
        // the gradient fallback every time the surrounding tree rebuilds. #4196
        final pixels = data.pixels;
        final generation = ++_decodeGeneration;
        final imageFuture = pixels != null
            ? _decodeImage(pixels, data.width, data.height, generation)
            : null;
        setState(() {
          _blurhashData = data;
          _imageFuture = imageFuture;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to decode blurhash: $e',
        name: 'BlurhashDisplay',
        category: LogCategory.ui,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use actual decoded image if available
    final imageFuture = _imageFuture;
    if (imageFuture != null) {
      return FutureBuilder<ui.Image?>(
        future: imageFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: _BlurhashImagePainter(
                  snapshot.data!,
                  fit: widget.fit,
                  opacity: widget.opacity,
                ),
                size: Size(
                  widget.width ?? double.infinity,
                  widget.height ?? double.infinity,
                ),
              ),
            );
          }
          // Fall back to gradient while image is being created
          return _buildGradientFallback();
        },
      );
    }

    // Use gradient from blurhash data if available
    if (_blurhashData != null) {
      return _buildGradientFallback();
    }

    // Fallback while decoding - transparent since parent is black
    return SizedBox(width: widget.width, height: widget.height);
  }

  Widget _buildGradientFallback() {
    final colors = _blurhashData?.colors ?? [];
    final gradientColors = colors.isNotEmpty
        ? (colors.length >= 2
              ? [Color(colors[0].toARGB32()), Color(colors[1].toARGB32())]
              : [
                  Color(colors[0].toARGB32()),
                  Color(colors[0].toARGB32()).withValues(alpha: 0.7),
                ])
        : [
            Color(_blurhashData!.primaryColor.toARGB32()),
            Color(
              _blurhashData!.primaryColor.toARGB32(),
            ).withValues(alpha: 0.7),
          ];
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Match the paint-level alpha of the decoded-image path so the
            // fallback doesn't flash at full strength before decode lands.
            for (final color in gradientColors)
              color.withValues(alpha: color.a * widget.opacity),
          ],
        ),
      ),
    );
  }

  /// Decodes [pixels] and takes ownership of the result.
  ///
  /// A result that lands after a newer decode started, or after [dispose], has
  /// nothing left to paint it, so it is disposed on the spot.
  Future<ui.Image?> _decodeImage(
    Uint8List pixels,
    int width,
    int height,
    int generation,
  ) async {
    final image = await _createImageFromPixels(pixels, width, height);
    if (image == null) return null;
    if (generation != _decodeGeneration) {
      image.dispose();
      return null;
    }
    _image?.dispose();
    _image = image;
    return image;
  }

  Future<ui.Image?> _createImageFromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) async {
    try {
      // Validate input data first
      if (pixels.isEmpty || width <= 0 || height <= 0) {
        Log.warning(
          'Invalid image data: pixels=${pixels.length}, w=$width, h=$height',
          name: 'BlurhashDisplay',
          category: LogCategory.ui,
        );
        return null;
      }

      final completer = Completer<ui.Image?>();
      ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, (
        ui.Image image,
      ) {
        if (!completer.isCompleted) {
          completer.complete(image);
        }
      });
      return await completer.future;
    } catch (e) {
      Log.error(
        'Failed to create image from pixels: $e',
        name: 'BlurhashDisplay',
        category: LogCategory.ui,
      );
      return null;
    }
  }
}

/// Custom painter for rendering decoded blurhash image
class _BlurhashImagePainter extends CustomPainter {
  _BlurhashImagePainter(this.image, {required this.fit, this.opacity = 1.0});

  final ui.Image image;
  final BoxFit fit;
  final double opacity;

  // Paint color alpha modulates the drawn image, so opacity costs nothing
  // extra at raster time (no saveLayer, unlike an Opacity widget).
  late final _paint = Paint()
    ..filterQuality = FilterQuality.low
    ..color = Color.fromRGBO(0, 0, 0, opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fittedSizes = applyBoxFit(fit, imageSize, size);
    final src = Alignment.center.inscribe(
      fittedSizes.source,
      Offset.zero & imageSize,
    );
    final dst = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );

    canvas.drawImageRect(image, src, dst, _paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _BlurhashImagePainter ||
        oldDelegate.image != image ||
        oldDelegate.fit != fit ||
        oldDelegate.opacity != opacity;
  }
}

/// Widget that displays a blurhash and smoothly transitions to the actual image
class BlurhashImage extends StatelessWidget {
  const BlurhashImage({
    required this.imageUrl,
    super.key,
    this.blurhash,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.errorBuilder,
  });

  final String imageUrl;
  final String? blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Duration fadeInDuration;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    // If no blurhash, just show the image with fade in
    if (blurhash == null || blurhash!.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: fadeInDuration,
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      );
    }

    // Show blurhash while loading, then fade in the image
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurhash placeholder
          BlurhashDisplay(
            blurhash: blurhash,
            width: width,
            height: height,
            fit: fit,
          ),
          // Actual image with fade in
          Positioned.fill(
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: fit,
              errorBuilder: errorBuilder,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame == null) {
                  return const SizedBox.shrink();
                }
                return AnimatedOpacity(
                  opacity: 1,
                  duration: fadeInDuration,
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
