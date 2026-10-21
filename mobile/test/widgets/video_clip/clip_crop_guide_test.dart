// ABOUTME: Tests for where the crop guide falls over a preview that covers its
// ABOUTME: box with footage of another shape

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_clip/clip_crop_guide.dart';

void main() {
  group('clipCropGuideRect', () {
    test('marks the middle band of a vertical preview for a wide cell', () {
      final rect = clipCropGuideRect(
        size: const Size(90, 160),
        aspectRatio: 16 / 9,
        contentAspectRatio: 9 / 16,
      );

      expect(rect.width, 90);
      expect(rect.height, closeTo(90 * 9 / 16, 1e-9));
      expect(rect.center, const Offset(45, 80));
    });

    test('clips a crop that reaches past a square preview of tall footage', () {
      // The footage covers the square box and overhangs it top and bottom; a
      // tall cell's crop is taller than the box shows.
      final rect = clipCropGuideRect(
        size: const Size(100, 100),
        aspectRatio: 9 / 16,
        contentAspectRatio: 9 / 16,
      );

      expect(rect, const Rect.fromLTWH(0, 0, 100, 100));
    });
  });
}
