// ABOUTME: Draws the second camera's thumbnail over a dual-camera take's own,
// ABOUTME: where the viewfinder showed its window, for gallery thumbnails

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/extensions/layer_animation_storage.dart'
    show ExportLayerMapping;
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';

/// JPEG quality of the composite. Above the recorder's own thumbnails (75):
/// the composite re-encodes one of them, and a second pass at 75 would stack
/// its artifacts.
const _jpegQuality = 90;

/// Draws [secondaryThumbnailPath] over [mainThumbnailPath] the way the
/// viewfinder showed the second camera: a window
/// [SecondaryCameraTake.pipWidthFraction] of the kept picture wide times
/// [pipScale], showing the whole second picture or, for a square
/// [pipAspectRatio], the square from its middle, turned by [pipRotation]
/// radians clockwise, centred on
/// [pipCenter] and kept whole inside the kept picture, its corners rounded by
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
  double pipScale = 1,
  double pipRotation = 0,
  model.AspectRatio pipAspectRatio = model.AspectRatio.vertical,
}) {
  final isSquare = pipAspectRatio == model.AspectRatio.square;
  final centerX = pipCenter.dx;
  final centerY = pipCenter.dy;
  return Isolate.run(
    () => _compose(
      mainThumbnailPath: mainThumbnailPath,
      secondaryThumbnailPath: secondaryThumbnailPath,
      centerX: centerX,
      centerY: centerY,
      scale: pipScale,
      rotation: pipRotation,
      isSquare: isSquare,
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
  required double scale,
  required double rotation,
  required bool isSquare,
  required double targetAspectRatio,
  required String outputPath,
}) {
  final frame = _decode(mainThumbnailPath);
  final decoded = _decode(secondaryThumbnailPath);
  if (frame == null || decoded == null) return null;
  // A square window shows the middle of the second picture, as the
  // viewfinder's window covers it.
  final side = math.min(decoded.width, decoded.height);
  final second = isSquare
      ? img.copyCrop(
          decoded,
          x: (decoded.width - side) ~/ 2,
          y: (decoded.height - side) ~/ 2,
          width: side,
          height: side,
        )
      : decoded;

  final kept = ExportLayerMapping.keptRect(
    Size(frame.width.toDouble(), frame.height.toDouble()),
    targetAspectRatio,
  );
  final unscaledWidth = kept.width * SecondaryCameraTake.pipWidthFraction;
  final unscaledSize = Size(
    unscaledWidth,
    unscaledWidth * second.height / second.width,
  );
  final fitted = SecondaryCameraTake.fittingPipScale(
    scale: scale,
    unscaledSize: unscaledSize,
    rotation: rotation,
    area: kept.size,
  );
  final width = math.max(1, (unscaledSize.width * fitted).round());
  final height = math.max(1, (unscaledSize.height * fitted).round());
  final window = img.copyResize(
    second,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  // The turned window is kept whole inside the kept picture, as the
  // viewfinder kept it.
  final bounds = SecondaryCameraTake.turnedPipBounds(
    Size(width.toDouble(), height.toDouble()),
    rotation,
  );
  final halfFreeWidth = math.max(0.0, (kept.width - bounds.width) / 2);
  final halfFreeHeight = math.max(0.0, (kept.height - bounds.height) / 2);
  final centre = Offset(
    kept.center.dx +
        ((centerX - 0.5) * kept.width).clamp(-halfFreeWidth, halfFreeWidth),
    kept.center.dy +
        ((centerY - 0.5) * kept.height).clamp(-halfFreeHeight, halfFreeHeight),
  );
  // A rectangle mask measures its corner radius as a fraction of half its
  // shorter side, so the window matches the viewfinder and the editor layer.
  final radius =
      math.min(width, height) / 2 * SecondaryCameraTake.pipCornerRadius;

  // Every frame pixel the turned window may cover is mapped back into the
  // upright window and takes the pixel it lands on.
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  final left = math.max(0, (centre.dx - bounds.width / 2).floor());
  final right = math.min(frame.width, (centre.dx + bounds.width / 2).ceil());
  final top = math.max(0, (centre.dy - bounds.height / 2).floor());
  final bottom = math.min(frame.height, (centre.dy + bounds.height / 2).ceil());
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final dx = x + 0.5 - centre.dx;
      final dy = y + 0.5 - centre.dy;
      final wx = dx * cos + dy * sin + width / 2;
      final wy = -dx * sin + dy * cos + height / 2;
      if (wx < 0 || wy < 0 || wx >= width || wy >= height) continue;
      if (_isOutsideRoundedCorner(wx, wy, width, height, radius)) continue;
      frame.setPixel(x, y, window.getPixel(wx.floor(), wy.floor()));
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

/// Whether the point [px], [py] of a [width] by [height] window lies in one
/// of its corners, outside the arc of [radius].
bool _isOutsideRoundedCorner(
  double px,
  double py,
  int width,
  int height,
  double radius,
) {
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
