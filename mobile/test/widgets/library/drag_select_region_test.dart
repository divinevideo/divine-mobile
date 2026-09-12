// ABOUTME: Tests for the long-press-and-drag range selection region
// ABOUTME: Covers slot reporting and the edge auto-scroll

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/library/drag_select_region.dart';

void main() {
  group(DragSelectRegion, () {
    const rowHeight = 100.0;
    const slotCount = 20;

    late ScrollController controller;
    late List<int> started;
    late List<int> extended;
    late int endedCount;

    setUp(() {
      controller = ScrollController();
      started = [];
      extended = [];
      endedCount = 0;
    });

    tearDown(() => controller.dispose());

    /// A grid of [slotCount] full-width rows inside a box of [height], with
    /// [footerHeight] taken off the bottom the way the create-video bar does.
    Widget buildWidget({double height = 600, double footerHeight = 0}) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: height - footerHeight,
                child: DragSelectRegion(
                  scrollController: controller,
                  onStarted: started.add,
                  onExtended: extended.add,
                  onEnded: () => endedCount++,
                  child: ListView.builder(
                    controller: controller,
                    itemCount: slotCount,
                    itemBuilder: (context, index) => DragSelectSlot(
                      index: index,
                      child: SizedBox(
                        height: rowHeight,
                        child: Text('slot $index'),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: footerHeight),
            ],
          ),
        ),
      );
    }

    testWidgets('reports the slot the long press lands on', (tester) async {
      await tester.pumpWidget(buildWidget());

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('slot 1')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));

      expect(started, equals([1]));

      await gesture.up();
      await tester.pump();
      expect(endedCount, equals(1));
    });

    testWidgets('reports each further slot the finger reaches', (tester) async {
      await tester.pumpWidget(buildWidget());

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('slot 0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(tester.getCenter(find.text('slot 2')));
      await tester.pump();

      expect(extended, equals([2]));

      await gesture.up();
      await tester.pump();
    });

    testWidgets('scrolls the grid on while the finger sits at the edge', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final region = tester.getRect(find.byType(DragSelectRegion));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('slot 0')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(Offset(region.center.dx, region.bottom - 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.offset, greaterThan(0));

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
      'a footer appearing under the finger does not scroll the grid',
      (tester) async {
        // The press that opens the selection is also what raises the
        // create-video bar, which takes its height off the bottom of the
        // grid. A finger the user put well clear of the edge must not end up
        // scrolling just because the edge moved up to meet it.
        const footerHeight = 80.0;
        await tester.pumpWidget(buildWidget());

        final region = tester.getRect(find.byType(DragSelectRegion));
        final gesture = await tester.startGesture(
          Offset(region.center.dx, region.bottom - 100),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));

        await tester.pumpWidget(buildWidget(footerHeight: footerHeight));

        // The same 2pt of travel the finger makes just holding still.
        await gesture.moveTo(Offset(region.center.dx, region.bottom - 102));
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(controller.offset, equals(0));

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets('the edge still scrolls once the finger leaves and returns', (
      tester,
    ) async {
      const footerHeight = 80.0;
      await tester.pumpWidget(buildWidget());

      final region = tester.getRect(find.byType(DragSelectRegion));
      final gesture = await tester.startGesture(
        Offset(region.center.dx, region.bottom - 100),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await tester.pumpWidget(buildWidget(footerHeight: footerHeight));

      // Out of the band the footer pushed onto the finger...
      await gesture.moveTo(Offset(region.center.dx, region.center.dy));
      await tester.pump();
      // ...and deliberately back down onto the new edge.
      await gesture.moveTo(
        Offset(region.center.dx, region.bottom - footerHeight - 4),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.offset, greaterThan(0));

      await gesture.up();
      await tester.pump();
    });
  });
}
