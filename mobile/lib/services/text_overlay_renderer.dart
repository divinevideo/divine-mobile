// ABOUTME: Service that renders text overlays to PNG images using Flutter Canvas API
// ABOUTME: Supports multiple overlays with normalized positioning, custom fonts, colors, and alignment

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/utils/unified_logger.dart';

class TextOverlayRenderer {
  /// Renders a list of text overlays to a PNG image
  ///
  /// [overlays] - List of TextOverlay objects to render
  /// [videoSize] - Size of the video canvas in pixels
  ///
  /// Returns PNG image data as Uint8List
  Future<Uint8List> renderOverlays(
    List<TextOverlay> overlays,
    Size videoSize,
  ) async {
    try {
      Log.info(
        'Rendering ${overlays.length} overlays to ${videoSize.width}x${videoSize.height} canvas',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
      );

      // Create a picture recorder to capture canvas drawing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, videoSize.width, videoSize.height),
      );

      // Render each overlay
      for (final overlay in overlays) {
        _renderSingleOverlay(canvas, overlay, videoSize);
      }

      // Convert canvas to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        videoSize.width.toInt(),
        videoSize.height.toInt(),
      );

      // Encode image to PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode image to PNG');
      }

      final pngBytes = byteData.buffer.asUint8List();

      Log.info(
        'Successfully rendered overlays to PNG (${pngBytes.length} bytes)',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
      );

      return pngBytes;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to render overlays: $e',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Renders a single text overlay on the canvas
  void _renderSingleOverlay(
    Canvas canvas,
    TextOverlay overlay,
    Size videoSize,
  ) {
    // Calculate absolute position from normalized position
    final absoluteX = overlay.normalizedPosition.dx * videoSize.width;
    final absoluteY = overlay.normalizedPosition.dy * videoSize.height;

    // Create text painter
    final textSpan = TextSpan(
      text: overlay.text,
      style: TextStyle(
        fontSize: overlay.fontSize,
        color: overlay.color,
        fontFamily: overlay.fontFamily,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: overlay.alignment,
      textDirection: TextDirection.ltr,
    );

    // Layout the text
    textPainter.layout();

    // Calculate offset based on alignment
    double offsetX = absoluteX;

    switch (overlay.alignment) {
      case TextAlign.left:
        // No adjustment needed
        break;
      case TextAlign.center:
        offsetX = absoluteX - (textPainter.width / 2);
        break;
      case TextAlign.right:
        offsetX = absoluteX - textPainter.width;
        break;
      default:
        offsetX = absoluteX - (textPainter.width / 2);
    }

    // Center vertically at the position
    final offsetY = absoluteY - (textPainter.height / 2);

    // Paint the text
    textPainter.paint(canvas, Offset(offsetX, offsetY));
  }
}
