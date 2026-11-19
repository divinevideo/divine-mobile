// ABOUTME: Tests for drawing shaped split-screen cells: taps outside a shape
// ABOUTME: fall through, and a badge finds room inside the shape

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_cell_shape_widgets.dart';

void main() {
  group(SplitScreenCellClip, () {
    Future<List<String>> tapsAt(
      WidgetTester tester,
      SplitScreenCellShape shape,
      Offset position,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps.add('under'),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: 100,
                height: 100,
                child: SplitScreenCellClip(
                  shape: shape,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps.add('cell'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(position);
      return taps;
    }

    testWidgets('lets a tap outside a round cell reach the cell under it', (
      tester,
    ) async {
      expect(
        await tapsAt(tester, SplitScreenCellShape.oval, const Offset(4, 4)),
        ['under'],
      );
      expect(
        await tapsAt(tester, SplitScreenCellShape.oval, const Offset(50, 50)),
        ['cell'],
      );
    });

    testWidgets('keeps every tap in a rectangular cell', (tester) async {
      expect(
        await tapsAt(
          tester,
          SplitScreenCellShape.rectangle,
          const Offset(4, 4),
        ),
        ['cell'],
      );
    });
  });

  group('splitScreenBadgeOffset', () {
    const cell = Size(100, 100);
    const badge = Size(20, 20);

    test('sits in the corner of a rectangle', () {
      final placed = splitScreenBadgeOffset(
        shape: SplitScreenCellShape.rectangle,
        cell: cell,
        badge: badge,
        corner: Alignment.bottomLeft,
      );

      expect(placed.offset, const Offset(6, 74));
      expect(placed.moved, 0);
    });

    test('moves inside a circle, out of the corner it cuts away', () {
      final placed = splitScreenBadgeOffset(
        shape: SplitScreenCellShape.oval,
        cell: cell,
        badge: badge,
        corner: Alignment.topRight,
      );
      final circle = SplitScreenCellShape.oval.pathIn(Offset.zero & cell);
      final box = placed.offset & badge;

      expect(placed.moved, greaterThan(0));
      for (final corner in [
        box.topLeft,
        box.topRight,
        box.bottomLeft,
        box.bottomRight,
      ]) {
        expect(circle.contains(corner), isTrue, reason: '$corner');
      }
    });

    test('keeps clear of a cell on top of it', () {
      final window = Path()..addRect(const Rect.fromLTWH(0, 60, 40, 40));
      final placed = splitScreenBadgeOffset(
        shape: SplitScreenCellShape.rectangle,
        cell: cell,
        badge: badge,
        corner: Alignment.bottomLeft,
        covered: [window],
      );
      final box = placed.offset & badge;

      expect(window.contains(box.topLeft), isFalse);
      expect(window.contains(box.bottomRight), isFalse);
      expect(placed.moved, greaterThan(0));
    });
  });
}
