// ABOUTME: Widget for displaying blurhash placeholders with smooth transitions
// ABOUTME: Provides progressive image loading experience for video thumbnails

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:openvine/services/blurhash_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Widget that displays a blurhash as a placeholder image
class BlurhashDisplay extends StatefulWidget {
  const BlurhashDisplay({
    required this.blurhash,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String blurhash;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<BlurhashDisplay> createState() => _BlurhashDisplayState();
}

class _BlurhashDisplayState extends State<BlurhashDisplay> {
  BlurhashData? _blurhashData;

  @override
  void initState() {
    super.initState();
    _decodeBlurhash();
  }

  @override
  void didUpdateWidget(BlurhashDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurhash != widget.blurhash) {
      _decodeBlurhash();
    }
  }

  void _decodeBlurhash() {
    try {
      final data = BlurhashService.decodeBlurhash(
        widget.blurhash,
        width: 32, // Small size for performance
        height: 32,
      );

      if (mounted && data != null) {
        setState(() {
          _blurhashData = data;
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
    if (_blurhashData?.pixels != null) {
      return FutureBuilder<ui.Image?>(
        future: _createImageFromPixels(
          _blurhashData!.pixels!,
          _blurhashData!.width,
          _blurhashData!.height,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return CustomPaint(
              painter: _BlurhashImagePainter(snapshot.data!),
              size: Size(
                widget.width ?? double.infinity,
                widget.height ?? double.infinity,
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

    // Fallback gradient while decoding
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade800, Colors.grey.shade600],
        ),
      ),
    );
  }

  Widget _buildGradientFallback() {
    final colors = _blurhashData?.colors ?? [];
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isNotEmpty
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
                ],
        ),
      ),
    );
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
  _BlurhashImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.low;

    // Scale the image to fit the widget size
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _BlurhashImagePainter || oldDelegate.image != image;
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
            blurhash: blurhash!,
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
