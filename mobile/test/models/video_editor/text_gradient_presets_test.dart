// ABOUTME: Tests for the text editor's gradient presets and directions: a
// ABOUTME: direction still reads back after a draft has stored the gradient.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/text_gradient_presets.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

void main() {
  group(TextGradientDirection, () {
    group('of', () {
      test('reads every direction back from a stored gradient', () {
        // A draft stores the angle rounded, so it comes back a hair off the
        // exact multiple of 45 degrees.
        for (final direction in TextGradientDirection.values) {
          final stored = TextGradient.fromMap(
            TextGradientPreset.sunset.withAngle(direction.angle).toMap(),
          );

          expect(TextGradientDirection.of(stored.angle), direction);
        }
      });
    });
  });
}
