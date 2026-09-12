import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas_fit.dart';
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

    VideoEditorCanvasGeometry geometry({
      Size body = boxSize,
      double original = aspectRatio,
      double? target,
    }) => VideoEditorCanvasGeometry(
      bodySize: body,
      originalAspectRatio: original,
      targetAspectRatio: target,
    );

    test('returns the identity transform for an un-zoomed editor matrix', () {
      final result = scrimZoomTransform(
        editorMatrix: Matrix4.identity(),
        geometry: geometry(),
      );

      expect(result, equals(Matrix4.identity()));
    });

    test(
      'scales the scrim and counter-translates by the centring offset for a '
      'zoom-only matrix when render already fills the target (coverScale 1)',
      () {
        // A square render and target have coverScale 1, centred vertically.
        final canvasGeometry = geometry(original: 1, target: 1);
        final result = scrimZoomTransform(
          editorMatrix: _editorZoom(scale: 2),
          geometry: canvasGeometry,
        );

        expect(result.getMaxScaleOnAxis(), moreOrLessEquals(2));
        // coverScale*t + (1-k)*d = 0 + (1-2)*d = -d.
        expect(result.entry(0, 3), moreOrLessEquals(0));
        expect(result.entry(1, 3), moreOrLessEquals(-200));
      },
    );

    test('applies the cover factor to the translation when the render box is '
        'cover-scaled into a larger target', () {
      final canvasGeometry = geometry(original: 1, target: 9 / 16);
      final result = scrimZoomTransform(
        editorMatrix: _editorZoom(scale: 1.5, tx: 10, ty: 20),
        geometry: canvasGeometry,
      );

      expect(result.getMaxScaleOnAxis(), moreOrLessEquals(1.5));
      // coverScale*t + (1-k)*d
      expect(
        result.entry(0, 3),
        moreOrLessEquals(
          canvasGeometry.fittedBoxScale * 10 +
              (1 - 1.5) * canvasGeometry.canvasOrigin.dx,
        ),
      );
      expect(
        result.entry(1, 3),
        moreOrLessEquals(
          canvasGeometry.fittedBoxScale * 20 +
              (1 - 1.5) * canvasGeometry.canvasOrigin.dy,
        ),
      );
    });

    test('returns the identity transform (not the editor matrix) for a '
        'degenerate zero-area box', () {
      final editorMatrix = _editorZoom(scale: 3, tx: 50, ty: 60);

      final result = scrimZoomTransform(
        editorMatrix: editorMatrix,
        geometry: geometry(body: Size.zero),
      );

      expect(result, equals(Matrix4.identity()));
      expect(result, isNot(equals(editorMatrix)));
    });

    test('returns the identity transform for a zero aspect ratio', () {
      final result = scrimZoomTransform(
        editorMatrix: _editorZoom(scale: 3, tx: 50, ty: 60),
        geometry: geometry(original: 0),
      );

      expect(result, equals(Matrix4.identity()));
    });
  });
}
