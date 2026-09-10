import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_cut_area_overlay.dart';

/// Builds a scale+translate editor matrix the way the editor's
/// `onEditorZoomMatrix4Change` reports pinch-zoom (no rotation/skew).
Matrix4 _editorZoom({double scale = 1, double tx = 0, double ty = 0}) {
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
}

void main() {
  group('scrimZoomTransform', () {
    // 9/16 portrait → render box is 225 x 400 inside a 400 x 800 body.
    const boxSize = Size(400, 800);
    const aspectRatio = 9 / 16;

    test('returns the identity transform for an un-zoomed editor matrix', () {
      final result = scrimZoomTransform(
        editorMatrix: Matrix4.identity(),
        boxSize: boxSize,
        targetSize: const Size(225, 400),
        originalAspectRatio: aspectRatio,
      );

      expect(result, equals(Matrix4.identity()));
    });

    test(
      'scales the scrim and counter-translates by the centring offset for a '
      'zoom-only matrix when render already fills the target (coverScale 1)',
      () {
        // render 225x400 == target → coverScale 1; centring offset
        // d = ((400-225)/2, (800-400)/2) = (87.5, 200).
        final result = scrimZoomTransform(
          editorMatrix: _editorZoom(scale: 2),
          boxSize: boxSize,
          targetSize: const Size(225, 400),
          originalAspectRatio: aspectRatio,
        );

        expect(result.getMaxScaleOnAxis(), moreOrLessEquals(2));
        // coverScale*t + (1-k)*d = 0 + (1-2)*d = -d.
        expect(result.entry(0, 3), moreOrLessEquals(-87.5));
        expect(result.entry(1, 3), moreOrLessEquals(-200));
      },
    );

    test(
      'applies the cover factor to the translation when the render box is '
      'cover-scaled into a larger target',
      () {
        // target 450x800 vs render 225x400 → coverScale 2;
        // d = ((400-450)/2, (800-800)/2) = (-25, 0).
        final result = scrimZoomTransform(
          editorMatrix: _editorZoom(scale: 1.5, tx: 10, ty: 20),
          boxSize: boxSize,
          targetSize: const Size(450, 800),
          originalAspectRatio: aspectRatio,
        );

        expect(result.getMaxScaleOnAxis(), moreOrLessEquals(1.5));
        // coverScale*t + (1-k)*d
        expect(result.entry(0, 3), moreOrLessEquals(2 * 10 + (1 - 1.5) * -25));
        expect(result.entry(1, 3), moreOrLessEquals(2 * 20 + (1 - 1.5) * 0));
      },
    );

    test('returns the identity transform (not the editor matrix) for a '
        'degenerate zero-area box', () {
      final editorMatrix = _editorZoom(scale: 3, tx: 50, ty: 60);

      final result = scrimZoomTransform(
        editorMatrix: editorMatrix,
        boxSize: Size.zero,
        targetSize: const Size(225, 400),
        originalAspectRatio: aspectRatio,
      );

      expect(result, equals(Matrix4.identity()));
      expect(result, isNot(equals(editorMatrix)));
    });

    test('returns the identity transform for a zero aspect ratio', () {
      final result = scrimZoomTransform(
        editorMatrix: _editorZoom(scale: 3, tx: 50, ty: 60),
        boxSize: boxSize,
        targetSize: const Size(225, 400),
        originalAspectRatio: 0,
      );

      expect(result, equals(Matrix4.identity()));
    });
  });
}
