import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/timeline_loop_scroll_controller.dart';

void main() {
  group(TimelineLoopScrollController, () {
    late TimelineLoopScrollController controller;
    late int wrapCount;

    setUp(() {
      wrapCount = 0;
      controller = TimelineLoopScrollController(onUserWrap: () => wrapCount++);
    });

    tearDown(() => controller.dispose());

    // A 400 px viewport over 1000 px of content: 600 px of scroll range.
    Future<void> pumpTimeline(WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 100,
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: const SizedBox(width: 1000, height: 100),
              ),
            ),
          ),
        ),
      );
    }

    /// Drags in [steps] equal moves without lifting the finger, so the
    /// assertions see the offset mid-gesture.
    Future<TestGesture> dragBy(
      WidgetTester tester,
      double dx, {
      int steps = 10,
    }) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SingleChildScrollView)),
      );
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(dx / steps, 0));
        await tester.pump();
      }
      return gesture;
    }

    group('user drag', () {
      testWidgets('continues at the start when dragged past the end', (
        tester,
      ) async {
        await pumpTimeline(tester);
        controller.jumpTo(560);

        final gesture = await dragBy(tester, -200);

        expect(controller.offset, greaterThan(0));
        expect(controller.offset, lessThan(200));
        expect(wrapCount, equals(1));

        // The same gesture keeps scrolling from the start.
        final wrappedOffset = controller.offset;
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump();
        expect(controller.offset, closeTo(wrappedOffset + 30, 0.001));
        await gesture.up();
      });

      testWidgets('continues at the end when dragged past the start', (
        tester,
      ) async {
        await pumpTimeline(tester);
        controller.jumpTo(40);

        final gesture = await dragBy(tester, 200);

        expect(controller.offset, lessThan(600));
        expect(controller.offset, greaterThan(400));
        expect(wrapCount, equals(1));
        await gesture.up();
      });

      testWidgets('does not wrap while the drag stays inside the range', (
        tester,
      ) async {
        await pumpTimeline(tester);
        controller.jumpTo(300);

        final gesture = await dragBy(tester, -100);

        expect(controller.offset, greaterThan(300));
        expect(controller.offset, lessThanOrEqualTo(400));
        expect(wrapCount, equals(0));
        await gesture.up();
      });
    });

    group('loopExtent', () {
      testWidgets('keeps content past the loop point unscrollable', (
        tester,
      ) async {
        controller.loopExtent = 580;
        await pumpTimeline(tester);

        expect(controller.position.maxScrollExtent, equals(580));
      });

      testWidgets('wraps at the loop point instead of the content end', (
        tester,
      ) async {
        controller.loopExtent = 580;
        await pumpTimeline(tester);
        controller.jumpTo(570);

        final gesture = await dragBy(tester, -40);

        expect(controller.offset, greaterThan(0));
        expect(controller.offset, lessThan(40));
        expect(wrapCount, equals(1));
        await gesture.up();
      });
    });
  });
}
