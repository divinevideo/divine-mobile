// ABOUTME: Tests for the shared video editor canvas geometry and fit widget.
// ABOUTME: Pins the canvas chain and the layer-compensation helper together.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas_fit.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

const ValueKey<String> _renderSurfaceKey = ValueKey('render-surface');

/// One canvas mapping to check, named for the failure message.
typedef _Case = ({
  String description,
  Size bodySize,
  double originalAspectRatio,
  double? targetAspectRatio,
});

/// Body sizes stay inside the 800x600 test surface so the chain is laid out
/// at the size it asks for.
const _cases = <_Case>[
  (
    description: 'portrait clip on a portrait body',
    bodySize: Size(300, 600),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: null,
  ),
  (
    description: 'square clip on a portrait body',
    bodySize: Size(300, 600),
    originalAspectRatio: 1,
    targetAspectRatio: 1,
  ),
  (
    description: 'square clip cropped to portrait on a portrait body',
    bodySize: Size(300, 600),
    originalAspectRatio: 1,
    targetAspectRatio: 9 / 16,
  ),
  (
    description: 'landscape clip on a landscape body',
    bodySize: Size(600, 300),
    originalAspectRatio: 16 / 9,
    targetAspectRatio: null,
  ),
  (
    description: 'square clip cropped to portrait on a landscape body',
    bodySize: Size(600, 300),
    originalAspectRatio: 1,
    targetAspectRatio: 9 / 16,
  ),
  (
    description: 'portrait clip cropped to square on a square body',
    bodySize: Size(400, 400),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: 1,
  ),
];

void main() {
  group(VideoEditorCanvasGeometry, () {
    group('renderSizeFor', () {
      test('takes its height from the shorter body dimension', () {
        expect(
          VideoEditorCanvasGeometry.renderSizeFor(const Size(300, 600), 1),
          equals(const Size(300, 300)),
        );
        expect(
          VideoEditorCanvasGeometry.renderSizeFor(const Size(600, 300), 1),
          equals(const Size(300, 300)),
        );
      });

      test('widens the surface by the clip aspect ratio', () {
        expect(
          VideoEditorCanvasGeometry.renderSizeFor(const Size(300, 600), 16 / 9),
          within(distance: 0.001, from: const Size(300 * 16 / 9, 300)),
        );
      });
    });

    group('targetSizeFor', () {
      test('contains the target ratio inside the body', () {
        expect(
          VideoEditorCanvasGeometry.targetSizeFor(const Size(400, 800), 9 / 16),
          equals(const Size(400, 400 / (9 / 16))),
        );
        expect(
          VideoEditorCanvasGeometry.targetSizeFor(const Size(800, 400), 9 / 16),
          equals(const Size(400 * 9 / 16, 400)),
        );
      });

      test('collapses when the body has no size yet', () {
        expect(
          VideoEditorCanvasGeometry.targetSizeFor(Size.zero, 9 / 16),
          equals(Size.zero),
        );
      });
    });

    group('fittedBoxScale', () {
      test('falls back to 1 before the body has been laid out', () {
        final geometry = VideoEditorCanvasGeometry(
          bodySize: Size.zero,
          originalAspectRatio: 9 / 16,
        );

        expect(geometry.fittedBoxScale, equals(1.0));
      });

      test('defaults the target ratio to the clip ratio', () {
        final uncropped = VideoEditorCanvasGeometry(
          bodySize: const Size(300, 600),
          originalAspectRatio: 9 / 16,
        );
        final explicit = VideoEditorCanvasGeometry(
          bodySize: const Size(300, 600),
          originalAspectRatio: 9 / 16,
          targetAspectRatio: 9 / 16,
        );

        expect(uncropped.targetSize, equals(explicit.targetSize));
        expect(uncropped.fittedBoxScale, equals(explicit.fittedBoxScale));
      });
    });

    test('canvasOrigin centres the cover-fitted render surface', () {
      final geometry = VideoEditorCanvasGeometry(
        bodySize: const Size(400, 800),
        originalAspectRatio: 1,
        targetAspectRatio: 9 / 16,
      );

      expect(
        geometry.canvasOrigin,
        within(
          distance: 0.001,
          from: const Offset(-155.5555555556, 44.4444444444),
        ),
      );
    });
  });

  group('canvas chain parity', () {
    for (final testCase in _cases) {
      testWidgets(
        'VideoEditorCanvasFit renders ${testCase.description} at the '
        'geometry the scale helper reports',
        (tester) async {
          final geometry = VideoEditorCanvasGeometry(
            bodySize: testCase.bodySize,
            originalAspectRatio: testCase.originalAspectRatio,
            targetAspectRatio: testCase.targetAspectRatio,
          );

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: testCase.bodySize,
                  child: VideoEditorCanvasFit(
                    geometry: geometry,
                    child: const SizedBox.expand(key: _renderSurfaceKey),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          // The canvas lays the editor out at the geometry's render size...
          final renderSurface = find.byKey(_renderSurfaceKey);
          expect(
            tester.getSize(renderSurface),
            within(distance: 0.001, from: geometry.renderSize),
          );

          // ...inside the visible target area it reports...
          expect(
            tester.getSize(find.byType(FittedBox)),
            within(distance: 0.001, from: geometry.targetSize),
          );

          // ...and the scale that cover-fit actually applies on screen is the
          // one layers compensate for. A geometry that only agreed with itself
          // would still pass the unit tests above; this is what #7534 broke.
          final appliedScale =
              tester.getRect(renderSurface).width / geometry.renderSize.width;
          expect(appliedScale, closeTo(geometry.fittedBoxScale, 0.001));
          expect(
            VideoEditorScope.calculateFittedBoxScale(
              testCase.bodySize,
              testCase.originalAspectRatio,
              targetAspectRatio: testCase.targetAspectRatio,
            ),
            closeTo(appliedScale, 0.001),
          );
          expect(
            tester.getRect(renderSurface).topLeft,
            within(distance: 0.001, from: geometry.canvasOrigin),
          );
        },
      );
    }

    test('VideoEditorScope reports the shared geometry', () {
      for (final testCase in _cases) {
        final geometry = VideoEditorCanvasGeometry(
          bodySize: testCase.bodySize,
          originalAspectRatio: testCase.originalAspectRatio,
          targetAspectRatio: testCase.targetAspectRatio,
        );

        expect(
          VideoEditorScope.calculateTargetSize(
            testCase.bodySize,
            testCase.targetAspectRatio ?? testCase.originalAspectRatio,
          ),
          equals(geometry.targetSize),
          reason: 'target size for ${testCase.description}',
        );
        expect(
          VideoEditorScope.calculateFittedBoxScale(
            testCase.bodySize,
            testCase.originalAspectRatio,
            targetAspectRatio: testCase.targetAspectRatio,
          ),
          equals(geometry.fittedBoxScale),
          reason: 'fitted box scale for ${testCase.description}',
        );
      }
    });
  });
}
