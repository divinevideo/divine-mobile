// ABOUTME: Draws the second camera's thumbnail over a dual-camera take's own,
// ABOUTME: where the viewfinder showed its window, for gallery thumbnails

import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;
import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';

/// JPEG quality of the composite, the same as the recorder's thumbnails.
const _jpegQuality = 90;

/// Draws [secondaryThumbnailPath] over [mainThumbnailPath] the way the
/// viewfinder showed the second camera: a window
/// [SecondaryCameraTake.pipWidthFraction] of the kept picture wide, centred
/// on [pipCenter] and kept whole inside it, its corners rounded by
/// [SecondaryCameraTake.pipCornerRadius]. Writes the result as a JPEG to
/// [outputPath].
///
/// The kept picture is the middle of the frame at [targetAspectRatio], the
/// part the post keeps and the library card shows; [pipCenter] is measured
/// against it.
///
/// Runs in a background isolate. Returns [outputPath], or null when either
/// thumbnail cannot be read.
Future<String?> composeDualCameraThumbnail({
  required String mainThumbnailPath,
  required String secondaryThumbnailPath,
  required Offset pipCenter,
  required double targetAspectRatio,
  required String outputPath,
}) {
  final centerX = pipCenter.dx;
  final centerY = pipCenter.dy;
  return Isolate.run(
    () => _compose(
      mainThumbnailPath: mainThumbnailPath,
      secondaryThumbnailPath: secondaryThumbnailPath,
      centerX: centerX,
      centerY: centerY,
      targetAspectRatio: targetAspectRatio,
      outputPath: outputPath,
    ),
  );
}

String? _compose({
  required String mainThumbnailPath,
  required String secondaryThumbnailPath,
  required double centerX,
  required double centerY,
  required double targetAspectRatio,
  required String outputPath,
}) {
  final frame = _decode(mainThumbnailPath);
  final second = _decode(secondaryThumbnailPath);
  if (frame == null || second == null) return null;

  final kept = ExportLayerMapping.keptRect(
    Size(frame.width.toDouble(), frame.height.toDouble()),
    targetAspectRatio,
  );
  final width = (kept.width * SecondaryCameraTake.pipWidthFraction).round();
  final height = (width * second.height / second.width).round().clamp(
    1,
    kept.height.round(),
  );
  final window = img.copyResize(
    second,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  final left = (kept.left + centerX * kept.width - width / 2)
      .clamp(kept.left, kept.right - width)
      .round();
  final top = (kept.top + centerY * kept.height - height / 2)
      .clamp(kept.top, kept.bottom - height)
      .round();
  // A rectangle mask measures its corner radius as a fraction of half its
  // width, so the window matches the viewfinder and the editor layer.
  final radius = width / 2 * SecondaryCameraTake.pipCornerRadius;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (_isOutsideRoundedCorner(x, y, width, height, radius)) continue;
      frame.setPixel(left + x, top + y, window.getPixel(x, y));
    }
  }
  File(outputPath).writeAsBytesSync(
    img.encodeJpg(frame, quality: _jpegQuality),
  );
  return outputPath;
}

img.Image? _decode(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return img.decodeImage(file.readAsBytesSync());
}

/// Whether the pixel at [x], [y] of a [width] by [height] window lies in one
/// of its corners, outside the arc of [radius]. Measured at pixel centres.
bool _isOutsideRoundedCorner(
  int x,
  int y,
  int width,
  int height,
  double radius,
) {
  final px = x + 0.5;
  final py = y + 0.5;
  final cornerX = px < radius
      ? radius
      : (px > width - radius ? width - radius : null);
  final cornerY = py < radius
      ? radius
      : (py > height - radius ? height - radius : null);
  if (cornerX == null || cornerY == null) return false;
  final dx = px - cornerX;
  final dy = py - cornerY;
  return dx * dx + dy * dy > radius * radius;
}
