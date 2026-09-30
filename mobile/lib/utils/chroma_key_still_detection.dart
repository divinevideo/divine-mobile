// ABOUTME: Measures the chroma-key screen in a camera still, cropped to the
// ABOUTME: part of the frame the finished video keeps.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKeyDetection, ChromaKeyDetectionException, ChromaKeyDetector;

/// Longest side, in pixels, a still is decoded at before it is measured.
///
/// The detector only reads a ring around the border, so a thumbnail carries
/// all of the signal. Decoding a 12 MP photo at full size would cost tens of
/// megabytes and a noticeable pause for nothing.
const int _sampleLongestSide = 320;

/// Measures the screen behind the subject in the photo at [path].
///
/// Only the centre of the photo shaped like [visibleAspectRatio] (width over
/// height) is measured: a camera still usually shows more than the video keeps
/// — a 4:3 sensor against a 9:16 frame — and the detector reads the frame
/// border, so a wall that fills the recording but not the photo's wider edges
/// would otherwise be reported as missing.
///
/// Throws [ChromaKeyDetectionException] when the border is not one saturated
/// colour, or when the photo cannot be decoded.
Future<ChromaKeyDetection> detectChromaKeyInStill(
  String path, {
  required double visibleAspectRatio,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await File(path).readAsBytes(),
  );
  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodecWithSize(
      buffer,
      // Only the width is pinned, so the decoder keeps the aspect ratio even
      // when it applies an EXIF rotation after sizing.
      getTargetSize: (width, height) {
        final scale = _sampleLongestSide / math.max(width, height);
        if (scale >= 1) return const ui.TargetImageSize();
        return ui.TargetImageSize(width: (width * scale).round());
      },
    );
  } on Exception catch (error) {
    throw ChromaKeyDetectionException('Could not decode the still: $error');
  }

  try {
    final image = (await codec.getNextFrame()).image;
    try {
      final data = await image.toByteData();
      if (data == null) {
        throw const ChromaKeyDetectionException('Could not read the still');
      }
      final crop = centerCropRect(
        width: image.width,
        height: image.height,
        aspectRatio: _orientedAspectRatio(
          width: image.width,
          height: image.height,
          aspectRatio: visibleAspectRatio,
        ),
      );
      return ChromaKeyDetector.fromFrames(
        [
          cropRgba(
            data.buffer.asUint8List(),
            sourceWidth: image.width,
            crop: crop,
          ),
        ],
        width: crop.width,
        height: crop.height,
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// [aspectRatio] turned to match the orientation of the decoded still.
///
/// A still that arrives landscape while the video is portrait was stored in
/// sensor orientation. The border ring reads the same either way round, so
/// cropping the rotated shape measures exactly the region the video keeps.
double _orientedAspectRatio({
  required int width,
  required int height,
  required double aspectRatio,
}) {
  final stillIsPortrait = height > width;
  final frameIsPortrait = aspectRatio < 1;
  if (width == height || aspectRatio == 1) return aspectRatio;
  return stillIsPortrait == frameIsPortrait ? aspectRatio : 1 / aspectRatio;
}

/// The largest centred rectangle shaped like [aspectRatio] (width over height)
/// that fits a [width] x [height] image.
@visibleForTesting
({int left, int top, int width, int height}) centerCropRect({
  required int width,
  required int height,
  required double aspectRatio,
}) {
  final cropWidth = math.min(width, (height * aspectRatio).round());
  final cropHeight = math.min(height, (width / aspectRatio).round());
  return (
    left: (width - cropWidth) ~/ 2,
    top: (height - cropHeight) ~/ 2,
    width: cropWidth,
    height: cropHeight,
  );
}

/// Copies the pixels inside [crop] out of an RGBA buffer [sourceWidth] pixels
/// wide.
@visibleForTesting
Uint8List cropRgba(
  Uint8List rgba, {
  required int sourceWidth,
  required ({int left, int top, int width, int height}) crop,
}) {
  const bytesPerPixel = 4;
  final rowBytes = crop.width * bytesPerPixel;
  final out = Uint8List(rowBytes * crop.height);
  for (var row = 0; row < crop.height; row++) {
    final from = ((crop.top + row) * sourceWidth + crop.left) * bytesPerPixel;
    out.setRange(row * rowBytes, (row + 1) * rowBytes, rgba, from);
  }
  return out;
}
