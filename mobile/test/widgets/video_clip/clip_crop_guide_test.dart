// ABOUTME: Tests for where the crop guide falls over a preview that covers its
// ABOUTME: box with footage of another shape, and the shape it outlines

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
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

  group(ClipCropGuideOverlay, () {
    /// The overlay drawn over a white 100×100 box, as pixels.
    Future<ByteData> render(
      WidgetTester tester,
      SplitScreenCellShape shape,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(
              dimension: 100,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: ClipCropGuideOverlay(
                  aspectRatio: 1,
                  contentAspectRatio: 1,
                  shape: shape,
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(boundary.toImage);
      addTearDown(image!.dispose);
      return (await tester.runAsync(image.toByteData))!;
    }

    int red(ByteData pixels, int x, int y) =>
        pixels.getUint8((y * 100 + x) * 4);

    testWidgets('dims the corners a round cell cuts away', (tester) async {
      final round = await render(tester, SplitScreenCellShape.oval);
      final square = await render(tester, SplitScreenCellShape.rectangle);

      // A corner of the crop: dimmed only when the cell is round.
      expect(red(round, 4, 4), lessThan(200));
      expect(red(square, 4, 4), 255);
      // The middle is kept either way.
      expect(red(round, 50, 50), 255);
    });
  });
}
