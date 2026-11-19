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

      test('gives three columns the same width with a gap', () {
        const gap = SplitScreenLayoutGeometry.maxGap;
        final cells = SplitScreenLayoutPreset.threeColumns.cellRects(
          aspectRatio: _vertical,
          gap: gap,
        );

        expect(cells[1].width, closeTo(cells[0].width, 1e-9));
        expect(cells[2].width, closeTo(cells[0].width, 1e-9));
        expect(cells[0].left, closeTo(gap, 1e-9));
        expect(cells[1].left - cells[0].right, closeTo(gap, 1e-9));
        expect(cells[2].left - cells[1].right, closeTo(gap, 1e-9));
        expect(1 - cells[2].right, closeTo(gap, 1e-9));
      });

      test('gives cells with the same share of the frame the same size', () {
        for (final preset in SplitScreenLayoutPreset.values) {
          final shares = preset.cellRects(aspectRatio: _vertical, gap: 0);
          final cells = preset.cellRects(
            aspectRatio: _vertical,
            gap: SplitScreenLayoutGeometry.maxGap,
          );
          for (var i = 0; i < cells.length; i++) {
            for (var j = i + 1; j < cells.length; j++) {
              final reason = '${preset.name}: cells $i and $j';
              if ((shares[i].width - shares[j].width).abs() < 1e-9) {
                expect(
                  cells[i].width,
                  closeTo(cells[j].width, 1e-9),
                  reason: reason,
                );
              }
              if ((shares[i].height - shares[j].height).abs() < 1e-9) {
                expect(
                  cells[i].height,
                  closeTo(cells[j].height, 1e-9),
                  reason: reason,
                );
              }
            }
          }
        }
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

    group('cells', () {
      /// The corners of [cell]'s polygon in frame units, where the frame is
      /// [_vertical] wide and 1 high.
      List<Offset> cornersInFrame(SplitScreenCellGeometry cell) => [
        for (final corner in cell.shape.corners!)
          Offset(
            (cell.rect.left + corner.dx * cell.rect.width) * _vertical,
            cell.rect.top + corner.dy * cell.rect.height,
          ),
      ];

      /// [rect], in fractions of the frame, in frame units.
      Rect inFrame(Rect rect) => Rect.fromLTRB(
        rect.left * _vertical,
        rect.top,
        rect.right * _vertical,
        rect.bottom,
      );

      test('leaves the cells of a grid as rectangles', () {
        final cells = SplitScreenLayoutPreset.fourStacked.cells(
          aspectRatio: _vertical,
          gap: 0.04,
        );

        expect(cells.map((cell) => cell.shape.isRectangle), everyElement(true));
      });

      /// The two corners of [corners] furthest along [direction]: a slanted
      /// cell's edge on that side.
      List<Offset> edge(List<Offset> corners, Offset direction) {
        double along(Offset point) =>
            point.dx * direction.dx + point.dy * direction.dy;
        return (List.of(
          corners,
        )..sort((a, b) => along(b).compareTo(along(a)))).take(2).toList();
      }

      test('splits slanted rows by a line that rises to the right', () {
        final [top, bottom] = SplitScreenLayoutPreset.slantedStacked.cells(
          aspectRatio: _vertical,
          gap: 0,
        );
        final divider = edge(cornersInFrame(top), const Offset(0, 1))
          ..sort((a, b) => a.dx.compareTo(b.dx));
        final [leftEnd, rightEnd] = divider;

        expect(leftEnd.dy, greaterThan(rightEnd.dy));
        // With no gap the top cell reaches a hair under the bottom one, which
        // is drawn over it, so no border shows along the slanted line.
        final [upperLeft, upperRight] = edge(
          cornersInFrame(bottom),
          const Offset(0, -1),
        )..sort((a, b) => a.dx.compareTo(b.dx));
        const overlap = SplitScreenLayoutGeometry.slantSeamOverlap;
        expect(leftEnd.dy - upperLeft.dy, closeTo(overlap, overlap / 10));
        expect(rightEnd.dy - upperRight.dy, closeTo(overlap, overlap / 10));
        expect(top.rect.top, 0);
        expect(bottom.rect.bottom, closeTo(1, 1e-9));
      });

      test('keeps the gap across a slanted split square to the line', () {
        const gap = 0.05;
        final [top, bottom] = SplitScreenLayoutPreset.slantedStacked.cells(
          aspectRatio: _vertical,
          gap: gap,
        );
        final [a, b] = edge(cornersInFrame(top), const Offset(0, 1));
        final across = edge(cornersInFrame(bottom), const Offset(0, -1));
        // Distance of the bottom cell's upper edge from the top cell's lower
        // one, measured square to them.
        final along = b - a;
        final normal = Offset(-along.dy, along.dx) / along.distance;
        double distance(Offset point) =>
            ((point - a).dx * normal.dx + (point - a).dy * normal.dy).abs();

        for (final point in across) {
          expect(distance(point), closeTo(gap * _vertical, 1e-9));
        }
      });

      test('splits slanted columns by a line that leans right', () {
        final [left, right] = SplitScreenLayoutPreset.slantedSideBySide.cells(
          aspectRatio: _vertical,
          gap: 0,
        );
        final divider = edge(cornersInFrame(left), const Offset(1, 0))
          ..sort((a, b) => a.dy.compareTo(b.dy));
        final [topEnd, bottomEnd] = divider;

        expect(topEnd.dx, greaterThan(bottomEnd.dx));
        // The left cell reaches a hair under the right one, drawn over it.
        final [innerTop, innerBottom] = edge(
          cornersInFrame(right),
          const Offset(-1, 0),
        )..sort((a, b) => a.dy.compareTo(b.dy));
        expect(topEnd.dx, greaterThan(innerTop.dx));
        expect(bottomEnd.dx, greaterThan(innerBottom.dx));
      });

      test('gives three slanted rows a middle cut on both sides', () {
        final [top, middle, bottom] = SplitScreenLayoutPreset
            .slantedThreeStacked
            .cells(aspectRatio: _vertical, gap: 0.02);

        expect(top.shape.corners, hasLength(4));
        expect(middle.shape.corners, hasLength(4));
        expect(bottom.shape.corners, hasLength(4));
        expect(top.rect.top, lessThan(middle.rect.top));
        expect(middle.rect.bottom, lessThan(bottom.rect.bottom));
      });

      test('makes a round window a circle in the frame', () {
        final [under, window] = SplitScreenLayoutPreset.circleTopLeft.cells(
          aspectRatio: _vertical,
          gap: 0,
        );
        final circle = inFrame(window.rect);

        expect(window.shape.isOval, isTrue);
        expect(circle.width, closeTo(circle.height, 1e-9));
        expect(window.rect.center.dx, lessThan(0.5));
        expect(window.rect.center.dy, lessThan(0.5));
        expect(under.shape, SplitScreenCellShape.rectangle);
      });

      test('cuts a ring the width of the gap around each round window', () {
        const gap = 0.03;
        final [under, ...windows] = SplitScreenLayoutPreset.twoCircles.cells(
          aspectRatio: _vertical,
          gap: gap,
        );
        final underRect = inFrame(under.rect);
        final holes = [
          for (final hole in under.shape.holes)
            Rect.fromLTRB(
              underRect.left + hole.left * underRect.width,
              underRect.top + hole.top * underRect.height,
              underRect.left + hole.right * underRect.width,
              underRect.top + hole.bottom * underRect.height,
            ),
        ];

        expect(windows, hasLength(2));
        expect(holes, hasLength(2));
        for (final (index, window) in windows.indexed) {
          final ring = inFrame(window.rect).inflate(gap * _vertical);
          expect(holes[index].left, closeTo(ring.left, 1e-9));
          expect(holes[index].top, closeTo(ring.top, 1e-9));
          expect(holes[index].right, closeTo(ring.right, 1e-9));
          expect(holes[index].bottom, closeTo(ring.bottom, 1e-9));
          // The ring stays inside the clip it is cut from.
          expect(underRect.contains(ring.topLeft), isTrue);
          expect(underRect.contains(ring.bottomRight), isTrue);
        }
      });

      test('keeps the rings of round windows apart at the widest gap', () {
        const gap = SplitScreenLayoutGeometry.maxGap;
        final [_, ...windows] = SplitScreenLayoutPreset.threeCircles.cells(
          aspectRatio: _vertical,
          gap: gap,
        );
        final rings = [
          for (final window in windows)
            inFrame(window.rect).inflate(gap * _vertical),
        ];

        expect(rings, hasLength(3));
        expect(rings[0].right, lessThan(rings[1].left));
        expect(rings[1].right, lessThan(rings[2].left));
        expect(rings[2].right, lessThan(_vertical));
      });
    });
  });

  group(SplitScreenCellShape, () {
    const cell = Rect.fromLTWH(10, 20, 100, 100);

    test('a rectangle covers its whole rect', () {
      final path = SplitScreenCellShape.rectangle.pathIn(cell);

      expect(path.contains(cell.topLeft + const Offset(1, 1)), isTrue);
      expect(SplitScreenCellShape.rectangle.isRectangle, isTrue);
    });

    test('an oval leaves the corners of its rect out', () {
      final path = SplitScreenCellShape.oval.pathIn(cell);

      expect(path.contains(cell.center), isTrue);
      expect(path.contains(cell.topLeft + const Offset(2, 2)), isFalse);
      expect(SplitScreenCellShape.oval.isRectangle, isFalse);
    });

    test('a rectangle with holes leaves them out', () {
      const shape = SplitScreenCellShape.withHoles([
        Rect.fromLTRB(0.5, 0.5, 1, 1),
      ]);
      final path = shape.pathIn(cell);

      expect(path.contains(cell.topLeft + const Offset(5, 5)), isTrue);
      expect(path.contains(cell.topLeft + const Offset(75, 75)), isFalse);
      expect(shape.isRectangle, isFalse);
    });

    test('a polygon follows its corners', () {
      const shape = SplitScreenCellShape.polygon([
        Offset.zero,
        Offset(1, 0),
        Offset(0, 1),
      ]);
      final path = shape.pathIn(cell);

      expect(path.contains(cell.topLeft + const Offset(10, 10)), isTrue);
      expect(path.contains(cell.bottomRight - const Offset(10, 10)), isFalse);
    });

    test('rounds a rectangle by the given radius', () {
      final path = SplitScreenCellShape.rectangle.pathIn(
        cell,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      );

      expect(path.contains(cell.topLeft + const Offset(1, 1)), isFalse);
      expect(path.contains(cell.center), isTrue);
    });

    test('compares by value', () {
      expect(
        const SplitScreenCellShape.polygon([Offset.zero, Offset(1, 1)]),
        const SplitScreenCellShape.polygon([Offset.zero, Offset(1, 1)]),
      );
      expect(
        const SplitScreenCellShape.withHoles([Rect.fromLTRB(0, 0, 1, 1)]),
        isNot(SplitScreenCellShape.rectangle),
      );
      expect(
        SplitScreenCellShape.withHoles(List.empty()).hashCode,
        SplitScreenCellShape.rectangle.hashCode,
      );
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
