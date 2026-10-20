// ABOUTME: Tests for the split-screen layout geometry: where cells sit, what of
// ABOUTME: a clip a cell keeps, and how a pan or pinch reframes it

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';

const double _vertical = 9 / 16;

void main() {
  group(SplitScreenLayoutPreset, () {
    group('cellRects', () {
      test('splits the frame in half side by side with no gap', () {
        final cells = SplitScreenLayoutPreset.sideBySide.cellRects(
          aspectRatio: _vertical,
          gap: 0,
        );

        expect(cells, [
          const Rect.fromLTRB(0, 0, 0.5, 1),
          const Rect.fromLTRB(0.5, 0, 1, 1),
        ]);
      });

      test('gives every preset as many cells as it promises', () {
        for (final preset in SplitScreenLayoutPreset.values) {
          expect(
            preset.cellRects(aspectRatio: _vertical, gap: 0.04),
            hasLength(preset.cellCount),
            reason: preset.name,
          );
        }
      });

      test('keeps the gap equally thick between cells and at the edges', () {
        const gap = 0.05;
        final cells = SplitScreenLayoutPreset.grid.cellRects(
          aspectRatio: _vertical,
          gap: gap,
        );
        // The gap is a fraction of the shorter side, which is the width here:
        // horizontally that is the gap itself, vertically scaled by 9/16.
        const horizontal = gap;
        const vertical = gap * _vertical;

        expect(cells[0].left, closeTo(horizontal, 1e-9));
        expect(cells[1].left - cells[0].right, closeTo(horizontal, 1e-9));
        expect(1 - cells[1].right, closeTo(horizontal, 1e-9));
        expect(cells[0].top, closeTo(vertical, 1e-9));
        expect(cells[2].top - cells[0].bottom, closeTo(vertical, 1e-9));
        expect(1 - cells[2].bottom, closeTo(vertical, 1e-9));
      });

      test('caps a gap past the largest the slider offers', () {
        final capped = SplitScreenLayoutPreset.stacked.cellRects(
          aspectRatio: _vertical,
          gap: 1,
        );
        final widest = SplitScreenLayoutPreset.stacked.cellRects(
          aspectRatio: _vertical,
          gap: SplitScreenLayoutGeometry.maxGap,
        );

        expect(capped, widest);
      });

      test('gives the picture-in-picture window the shape of the frame', () {
        final cells = SplitScreenLayoutPreset.pictureInPictureTopRight
            .cellRects(aspectRatio: _vertical, gap: 0);
        final window = cells.last;

        expect(cells.first, const Rect.fromLTRB(0, 0, 1, 1));
        expect(
          splitScreenCellAspectRatio(window, _vertical),
          closeTo(_vertical, 1e-9),
        );
      });

      test('puts each picture-in-picture window in its own corner', () {
        Rect window(SplitScreenLayoutPreset preset) =>
            preset.cellRects(aspectRatio: _vertical, gap: 0).last;

        final topLeft = window(SplitScreenLayoutPreset.pictureInPictureTopLeft);
        final topRight = window(
          SplitScreenLayoutPreset.pictureInPictureTopRight,
        );
        final bottomLeft = window(
          SplitScreenLayoutPreset.pictureInPictureBottomLeft,
        );
        final bottomRight = window(
          SplitScreenLayoutPreset.pictureInPictureBottomRight,
        );

        expect(topLeft.center.dx, lessThan(0.5));
        expect(topLeft.center.dy, lessThan(0.5));
        expect(topRight.center.dx, greaterThan(0.5));
        expect(topRight.top, closeTo(topLeft.top, 1e-9));
        expect(bottomLeft.left, closeTo(topLeft.left, 1e-9));
        expect(bottomLeft.center.dy, greaterThan(0.5));
        // Each window keeps the same distance to the two edges it sits on.
        expect(1 - bottomRight.right, closeTo(topLeft.left, 1e-9));
        expect(1 - bottomRight.bottom, closeTo(topLeft.top, 1e-9));
      });
    });
  });

  group('splitScreenCellAspectRatio', () {
    test('is the shape a cell has in a frame of the given shape', () {
      // One row of three in a vertical frame: full width, a third of 16.
      expect(
        splitScreenCellAspectRatio(
          const Rect.fromLTRB(0, 0, 1, 1 / 3),
          _vertical,
        ),
        closeTo(27 / 16, 1e-9),
      );
    });
  });

  group('splitScreenCropRect', () {
    test('cuts the widest slice of a tall frame for a wide cell', () {
      final crop = splitScreenCropRect(
        sourceAspectRatio: _vertical,
        cellAspectRatio: 16 / 9,
      );

      expect(crop.width, closeTo(1, 1e-9));
      expect(crop.height, closeTo(607.5 / 1920, 1e-9));
      expect(crop.center.dx, closeTo(0.5, 1e-9));
      expect(crop.center.dy, closeTo(0.5, 1e-9));
    });

    test('moves the slice with the alignment and stops at the frame', () {
      final top = splitScreenCropRect(
        sourceAspectRatio: _vertical,
        cellAspectRatio: 16 / 9,
        alignment: Alignment.topCenter,
      );
      final beyond = splitScreenCropRect(
        sourceAspectRatio: _vertical,
        cellAspectRatio: 16 / 9,
        alignment: const Alignment(0, 3),
      );

      expect(top.top, closeTo(0, 1e-9));
      expect(beyond.bottom, closeTo(1, 1e-9));
    });

    test('shows a smaller part of the frame when zoomed in', () {
      final crop = splitScreenCropRect(
        sourceAspectRatio: _vertical,
        cellAspectRatio: _vertical,
        zoom: 2,
      );

      expect(crop.width, closeTo(0.5, 1e-9));
      expect(crop.height, closeTo(0.5, 1e-9));
      expect(crop.center.dx, closeTo(0.5, 1e-9));
    });
  });

  group('splitScreenReframed', () {
    const cell = Size(200, 100);

    test('moves the footage along the axis it overhangs', () {
      // A tall clip covering a wide cell overhangs vertically: 200 wide means
      // 355.5 tall, so 255.5 of it is outside the cell.
      final framing = splitScreenReframed(
        alignment: Alignment.center,
        zoom: 1,
        targetZoom: 1,
        focalPoint: const Offset(100, 50),
        delta: const Offset(40, 50),
        cellSize: cell,
        sourceAspectRatio: _vertical,
      );

      expect(framing.alignment.x, 0);
      expect(
        framing.alignment.y,
        closeTo(-2 * 50 / (200 / _vertical - 100), 1e-9),
      );
    });

    test('stops once an edge of the footage meets the cell', () {
      final framing = splitScreenReframed(
        alignment: Alignment.center,
        zoom: 1,
        targetZoom: 1,
        focalPoint: const Offset(100, 50),
        delta: const Offset(0, -1000),
        cellSize: cell,
        sourceAspectRatio: _vertical,
      );

      expect(framing.alignment.y, 1);
    });

    test('zooms into the point under the fingers', () {
      const square = Size(100, 100);
      final corner = splitScreenReframed(
        alignment: Alignment.center,
        zoom: 1,
        targetZoom: 2,
        focalPoint: Offset.zero,
        delta: Offset.zero,
        cellSize: square,
        sourceAspectRatio: 1,
      );
      final middle = splitScreenReframed(
        alignment: Alignment.center,
        zoom: 1,
        targetZoom: 2,
        focalPoint: const Offset(50, 50),
        delta: Offset.zero,
        cellSize: square,
        sourceAspectRatio: 1,
      );

      expect(corner.zoom, 2);
      expect(corner.alignment, Alignment.topLeft);
      expect(middle.alignment, Alignment.center);
    });

    test('keeps the zoom between the cover size and the limit', () {
      double zoomed(double targetZoom) => splitScreenReframed(
        alignment: Alignment.center,
        zoom: 1,
        targetZoom: targetZoom,
        focalPoint: Offset.zero,
        delta: Offset.zero,
        cellSize: cell,
        sourceAspectRatio: _vertical,
      ).zoom;

      expect(zoomed(0.2), 1);
      expect(zoomed(40), SplitScreenLayoutGeometry.maxZoom);
    });
  });
}
