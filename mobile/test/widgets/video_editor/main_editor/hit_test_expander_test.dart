import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/main_editor/hit_test_expander.dart';

void main() {
  group(HitTestExpander, () {
    /// Pumps a [HitTestExpander] of [outerSize] containing a centered
    /// [visibleSize] [Listener] and returns a getter for the number of
    /// pointer-down events the listener has received.
    Future<int Function()> pumpExpander(
      WidgetTester tester, {
      required Size outerSize,
      required Size visibleSize,
    }) async {
      var hits = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: outerSize,
              child: HitTestExpander(
                visibleSize: visibleSize,
                child: Center(
                  child: SizedBox.fromSize(
                    size: visibleSize,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => hits++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return () => hits;
    }

    testWidgets('routes taps inside visible rect to the child', (tester) async {
      final hitCount = await pumpExpander(
        tester,
        outerSize: const Size(200, 200),
        visibleSize: const Size(100, 100),
      );

      await tester.tapAt(tester.getCenter(find.byType(Listener)));

      expect(hitCount(), 1);
    });

    testWidgets('clamps taps in the top-left scrim into the child', (
      tester,
    ) async {
      final hitCount = await pumpExpander(
        tester,
        outerSize: const Size(200, 200),
        visibleSize: const Size(100, 100),
      );

      // Tap deep into the top-left scrim — well outside the centered
      // 100x100 visible rect (which lives at (50,50)..(150,150)).
      // Without HitTestExpander, the standard `Center` hit-test would
      // drop this position and the listener would never see it.
      final expanderRect = tester.getRect(find.byType(HitTestExpander));
      await tester.tapAt(expanderRect.topLeft + const Offset(10, 10));

      expect(hitCount(), 1);
    });

    testWidgets('clamps taps in the bottom-right scrim into the child', (
      tester,
    ) async {
      final hitCount = await pumpExpander(
        tester,
        outerSize: const Size(200, 200),
        visibleSize: const Size(100, 100),
      );

      final expanderRect = tester.getRect(find.byType(HitTestExpander));
      await tester.tapAt(expanderRect.bottomRight - const Offset(10, 10));

      expect(hitCount(), 1);
    });

    testWidgets('routes taps in every scrim quadrant to the child', (
      tester,
    ) async {
      final hitCount = await pumpExpander(
        tester,
        outerSize: const Size(200, 200),
        visibleSize: const Size(100, 100),
      );

      final expanderRect = tester.getRect(find.byType(HitTestExpander));
      // Each of these falls in a different scrim quadrant; without the
      // expander the listener would receive zero of them.
      await tester.tapAt(expanderRect.topLeft + const Offset(5, 100));
      await tester.tapAt(expanderRect.topRight + const Offset(-5, 100));
      await tester.tapAt(expanderRect.bottomLeft + const Offset(100, -5));
      await tester.tapAt(expanderRect.topLeft + const Offset(100, 5));

      expect(hitCount(), 4);
    });

    testWidgets('updates clamp region when visibleSize changes', (
      tester,
    ) async {
      var hits = 0;

      Widget buildWith(Size visibleSize) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: const Size(200, 200),
              child: HitTestExpander(
                visibleSize: visibleSize,
                child: Center(
                  child: SizedBox.fromSize(
                    size: visibleSize,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => hits++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWith(const Size(100, 100)));
      final expanderRect = tester.getRect(find.byType(HitTestExpander));
      await tester.tapAt(expanderRect.topLeft + const Offset(10, 10));
      expect(hits, 1);

      // Shrink the visible rect — the clamp region must follow so that
      // the same scrim tap still resolves into the smaller listener.
      await tester.pumpWidget(buildWith(const Size(50, 50)));
      await tester.tapAt(expanderRect.topLeft + const Offset(10, 10));
      expect(hits, 2);
    });
  });
}
