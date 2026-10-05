// ABOUTME: Tests the area text layers stay inside on the video editor canvas
// ABOUTME: Pins it to the visible part of the canvas geometry's cover-fit

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/editor_text_layer_bounds.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas_fit.dart';

void main() {
  group('editorTextLayerBounds', () {
    const bodySize = Size(390, 700);

    for (final (name, original, target) in [
      ('an uncropped vertical clip', 9 / 16, 9 / 16),
      ('a vertical clip cropped to square', 9 / 16, 1.0),
      ('a square clip cropped to vertical', 1.0, 9 / 16),
      ('a landscape clip cropped to vertical', 16 / 9, 9 / 16),
      ('a 3:4 clip cropped to vertical', 3 / 4, 9 / 16),
    ]) {
      test('is the visible part of the canvas for $name', () {
        final geometry = VideoEditorCanvasGeometry(
          bodySize: bodySize,
          originalAspectRatio: original,
          targetAspectRatio: target,
        );
        // The canvas lays the layers out at renderSize and shows the centered
        // part of it that covers targetSize.
        final renderSize = geometry.renderSize;
        final visible = Rect.fromCenter(
          center: renderSize.center(Offset.zero),
          width: geometry.targetSize.width / geometry.fittedBoxScale,
          height: geometry.targetSize.height / geometry.fittedBoxScale,
        );

        final bounds = editorTextLayerBounds(
          renderSize,
          targetAspectRatio: target,
        );

        expect(bounds.left, moreOrLessEquals(visible.left));
        expect(bounds.top, moreOrLessEquals(visible.top));
        expect(bounds.right, moreOrLessEquals(visible.right));
        expect(bounds.bottom, moreOrLessEquals(visible.bottom));
      });
    }
  });
}
