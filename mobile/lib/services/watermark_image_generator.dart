// ABOUTME: Generates transparent PNG watermark overlays for video exports
// ABOUTME: Draws the Divine wordmark + creator identity text at bottom-right

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Generates a transparent PNG watermark overlay for video exports.
///
/// The watermark includes the Divine wordmark and creator identity text
/// positioned in the bottom-right corner at 60% opacity.
class WatermarkImageGenerator {
  WatermarkImageGenerator._();

  /// White raster derivative of `assets/icon/logo.svg`, the brand source.
  static const _wordmarkAssetPath = 'assets/icon/divine_wordmark.png';
  static const _watermarkOpacity = 0.6;
  static const _margin = 16.0;

  /// Generates a transparent PNG watermark image at the given resolution.
  ///
  /// The watermark includes:
  /// - Divine wordmark (from assets) in bottom-right corner
  /// - Creator identity text below the wordmark
  /// All at ~60% opacity, sized to ~15% of video width.
  ///
  /// Returns PNG bytes ([Uint8List]) suitable for use as an image overlay.
  ///
  /// Throws [WatermarkGenerationException] if the wordmark asset cannot be
  /// loaded or image encoding fails.
  static Future<Uint8List> generateWatermark({
    required int videoWidth,
    required int videoHeight,
    required String watermarkText,
  }) async {
    final wordmarkImage = await _loadWordmarkImage();
    ui.Paragraph? textParagraph;
    ui.Picture? picture;
    ui.Image? image;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final wordmarkWidth = videoWidth * 0.15;
      final fontSize = wordmarkWidth * 0.14;

      // Build the single-line watermark text using the resolved identity.
      // Available width = from left margin to right margin
      final maxTextWidth = videoWidth - 2 * _margin;
      textParagraph = _buildParagraph(watermarkText, fontSize, maxTextWidth);
      textParagraph.layout(ui.ParagraphConstraints(width: maxTextWidth));

      // Calculate wordmark draw size preserving aspect ratio
      final wordmarkAspectRatio = wordmarkImage.width / wordmarkImage.height;
      final wordmarkDrawWidth = wordmarkWidth;
      final wordmarkDrawHeight = wordmarkDrawWidth / wordmarkAspectRatio;

      // Calculate total block height: wordmark + gap + text
      final gap = fontSize * 0.3;
      final totalHeight = wordmarkDrawHeight + gap + textParagraph.height;

      // Position the block in the bottom-right corner
      final blockRight = videoWidth - _margin;
      final blockBottom = videoHeight - _margin;
      final blockTop = blockBottom - totalHeight;

      // Draw wordmark - right-aligned
      final wordmarkPaint = ui.Paint()
        ..color = const ui.Color.fromRGBO(255, 255, 255, _watermarkOpacity);

      final wordmarkLeft = blockRight - wordmarkDrawWidth;
      final wordmarkTop = blockTop;

      canvas.drawImageRect(
        wordmarkImage,
        ui.Rect.fromLTWH(
          0,
          0,
          wordmarkImage.width.toDouble(),
          wordmarkImage.height.toDouble(),
        ),
        ui.Rect.fromLTWH(
          wordmarkLeft,
          wordmarkTop,
          wordmarkDrawWidth,
          wordmarkDrawHeight,
        ),
        wordmarkPaint,
      );

      // Draw creator identity - right-aligned below wordmark
      // Position paragraph box so its right edge aligns with blockRight.
      // Text is right-aligned within the box, so it stays flush right.
      final textTop = wordmarkTop + wordmarkDrawHeight + gap;
      final textLeft = blockRight - maxTextWidth;
      canvas.drawParagraph(textParagraph, ui.Offset(textLeft, textTop));

      // Convert to image
      picture = recorder.endRecording();
      image = await picture.toImage(videoWidth, videoHeight);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw const WatermarkGenerationException(
          'Failed to encode watermark image to PNG',
        );
      }

      return byteData.buffer.asUint8List();
    } finally {
      // Every native drawing resource this call created; only the PNG bytes
      // may outlive it.
      image?.dispose();
      picture?.dispose();
      textParagraph?.dispose();
      wordmarkImage.dispose();
    }
  }

  /// Loads the Divine wordmark from app assets.
  static Future<ui.Image> _loadWordmarkImage() async {
    try {
      final data = await rootBundle.load(_wordmarkAssetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } catch (e) {
      throw WatermarkGenerationException('Failed to load wordmark asset: $e');
    }
  }

  /// Builds a right-aligned paragraph with the watermark text style.
  static ui.Paragraph _buildParagraph(
    String text,
    double fontSize,
    double maxWidth,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: ui.TextAlign.right, maxLines: 1),
          )
          ..pushStyle(
            ui.TextStyle(
              color: const ui.Color.fromRGBO(255, 255, 255, _watermarkOpacity),
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w600,
            ),
          )
          ..addText(text)
          ..pop();

    return builder.build();
  }
}

/// Exception thrown when watermark generation fails.
class WatermarkGenerationException implements Exception {
  /// Creates a [WatermarkGenerationException] with the given [message].
  const WatermarkGenerationException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'WatermarkGenerationException: $message';
}
