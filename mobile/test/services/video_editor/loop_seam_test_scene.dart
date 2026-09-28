// ABOUTME: Synthetic frames of one fixed scene seen through a known camera
// ABOUTME: move, shared by the loop-seam tests.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:openvine/services/video_editor/loop_seam_alignment.dart';

/// A smooth, feature-rich scene: soft blobs over a low-frequency wash.
///
/// Built from a fixed [seed] so every test sees the same image.
class TestScene {
  TestScene({int seed = 7, int blobs = 40}) {
    final random = math.Random(seed);
    for (var i = 0; i < blobs; i++) {
      _blobs.add((
        x: random.nextDouble() * 160 - 20,
        y: random.nextDouble() * 260 - 30,
        radius: 4 + random.nextDouble() * 12,
        weight: random.nextBool() ? 1.0 : -1.0,
      ));
    }
  }

  final _blobs = <({double x, double y, double radius, double weight})>[];

  double sample(double x, double y) {
    var v = 128 + 30 * math.sin(x / 17) * math.cos(y / 23);
    for (final b in _blobs) {
      final dx = x - b.x;
      final dy = y - b.y;
      v +=
          b.weight *
          70 *
          math.exp(-(dx * dx + dy * dy) / (b.radius * b.radius));
    }
    return v.clamp(0, 255).toDouble();
  }

  /// This scene as a frame the camera sees after moving so that displaying it
  /// at [scale] about the centre and shifting it by ([dx], [dy]) pixels lines
  /// it up with the unmoved view.
  GrayFrame frame({
    int width = 108,
    int height = 192,
    double scale = 1,
    double dx = 0,
    double dy = 0,
  }) {
    final cx = (width - 1) / 2;
    final cy = (height - 1) / 2;
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final v = sample(
          cx + scale * (x - cx) + dx,
          cy + scale * (y - cy) + dy,
        ).round();
        final o = (y * width + x) * 4;
        rgba
          ..[o] = v
          ..[o + 1] = v
          ..[o + 2] = v
          ..[o + 3] = 255;
      }
    }
    return GrayFrame.fromRgba(width, height, rgba);
  }
}
