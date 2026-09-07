// ABOUTME: Value types for the video editor's clip normalization pass
// ABOUTME: Crop geometry, per-clip analysis, and the pass's rendered result

import 'package:flutter/widgets.dart' show Size;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Result of normalizing clips to a target aspect ratio.
class NormalizationResult {
  const NormalizationResult({
    required this.segments,
    required this.tempFilePaths,
    this.globalTransform,
  });

  /// The video segments ready for concatenation.
  final List<VideoSegment> segments;

  /// Paths to temporary files that should be cleaned up after rendering.
  final List<String> tempFilePaths;

  /// Global crop transform to apply during concatenation (if all clips match).
  final CropParameters? globalTransform;
}

/// Analysis result for a single clip.
class ClipAnalysisEntry {
  const ClipAnalysisEntry({
    required this.clip,
    required this.resolution,
    required this.cropParams,
  });

  final DivineVideoClip clip;
  final Size resolution;
  final CropParameters cropParams;
}

/// Analysis of all clips for optimal rendering strategy.
class ClipAnalysis {
  const ClipAnalysis({required this.entries});

  final List<ClipAnalysisEntry> entries;

  /// True if all clips have identical crop parameters.
  bool get allSameCropParams {
    if (entries.isEmpty) return true;
    final first = entries.first.cropParams;
    return entries.every(
      (e) =>
          e.cropParams.x == first.x &&
          e.cropParams.y == first.y &&
          e.cropParams.width == first.width &&
          e.cropParams.height == first.height,
    );
  }
}

/// Crop parameters for aspect ratio transformation.
class CropParameters {
  const CropParameters({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Creates crop parameters for the given aspect ratio.
  factory CropParameters.forAspectRatio({
    required Size resolution,
    required model.AspectRatio aspectRatio,
  }) {
    return switch (aspectRatio) {
      model.AspectRatio.square => CropParameters.squareCrop(resolution),
      model.AspectRatio.vertical => CropParameters.verticalCrop(resolution),
    };
  }

  /// Creates crop parameters from a resolution for a centered square crop.
  factory CropParameters.squareCrop(Size resolution) {
    final minDimension = resolution.width < resolution.height
        ? resolution.width
        : resolution.height;

    return CropParameters(
      x: ((resolution.width - minDimension) / 2).round(),
      y: ((resolution.height - minDimension) / 2).round(),
      width: minDimension.round(),
      height: minDimension.round(),
    );
  }

  /// Creates crop parameters from a resolution for a centered 9:16 vertical crop.
  factory CropParameters.verticalCrop(Size resolution) {
    final inputAspectRatio = resolution.width / resolution.height;
    const targetRatio = 9.0 / 16.0;

    final double cropX;
    final double cropY;
    final double cropWidth;
    final double cropHeight;

    if (inputAspectRatio > targetRatio) {
      // Input is wider than 9:16 - crop width, keep height
      cropHeight = resolution.height;
      cropWidth = cropHeight * targetRatio;
      cropX = (resolution.width - cropWidth) / 2;
      cropY = 0;
    } else {
      // Input is taller than 9:16 - keep width, crop height
      cropWidth = resolution.width;
      cropHeight = cropWidth / targetRatio;
      cropX = 0;
      cropY = (resolution.height - cropHeight) / 2;
    }

    return CropParameters(
      x: cropX.round(),
      y: cropY.round(),
      width: cropWidth.round(),
      height: cropHeight.round(),
    );
  }

  /// Horizontal offset for cropping.
  final int x;

  /// Vertical offset for cropping.
  final int y;

  /// Width of the cropped area.
  final int width;

  /// Height of the cropped area.
  final int height;

  /// Whether cropping is needed based on the original resolution.
  bool needsCropping(Size resolution) {
    return x != 0 ||
        y != 0 ||
        width != resolution.width.round() ||
        height != resolution.height.round();
  }

  /// Converts to [ExportTransform] for video rendering.
  ExportTransform toExportTransform() {
    return ExportTransform(x: x, y: y, width: width, height: height);
  }

  @override
  String toString() => '($x, $y, ${width}x$height)';
}
