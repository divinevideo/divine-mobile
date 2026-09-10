// ABOUTME: Unit tests for VerticalOnlyClipper.
// ABOUTME: Verifies horizontal overflow clipping and reclip behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/vertical_only_clipper.dart';

void main() {
  group(VerticalOnlyClipper, () {
    test('getClip preserves full vertical range with horizontal overflow', () {
      const clipper = VerticalOnlyClipper();
      final rect = clipper.getClip(const Size(200, 50));

      expect(rect.top, equals(0));
      expect(rect.height, equals(50));
      expect(rect.left, lessThan(0));
      expect(rect.right, greaterThan(200));
    });

    test('shouldReclip returns false for same clipper type', () {
      const clipper = VerticalOnlyClipper();
      const old = VerticalOnlyClipper();

      expect(clipper.shouldReclip(old), isFalse);
    });
  });
}
