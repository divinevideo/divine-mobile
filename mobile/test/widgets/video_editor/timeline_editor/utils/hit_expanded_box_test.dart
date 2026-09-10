// ABOUTME: Widget tests for HitExpandedBox — verifies hit-test expansion
// ABOUTME: logic, height constraints, and update propagation.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/hit_expanded_box.dart';

/// Builds a [HitExpandedBox] at a fixed position with a child [Stack]
/// that has a tappable handle positioned outside the main content's
/// bounds — matching the real trim-handle use case.
Widget _buildExpandedHitScene({
  required double expandLeft,
  required double expandRight,
  required double handleWidth,
  required VoidCallback onLeftHandleTap,
  required VoidCallback onRightHandleTap,
  required VoidCallback onCenterTap,
}) {
  const contentWidth = 100.0;
  const contentHeight = 50.0;

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        Positioned(
          left: 100,
          top: 100,
          child: HitExpandedBox(
            expandLeft: expandLeft,
            expandRight: expandRight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main content area.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCenterTap,
                  child: const SizedBox(
                    width: contentWidth,
                    height: contentHeight,
                  ),
                ),
                // Left handle positioned outside bounds.
                Positioned(
                  left: -handleWidth,
                  top: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onLeftHandleTap,
                    child: SizedBox(width: handleWidth, height: contentHeight),
                  ),
                ),
                // Right handle positioned outside bounds.
                Positioned(
                  left: contentWidth,
                  top: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRightHandleTap,
                    child: SizedBox(width: handleWidth, height: contentHeight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  group(HitExpandedBox, () {
    group('renders', () {
      testWidgets('child widget', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: HitExpandedBox(child: SizedBox(width: 100, height: 50)),
            ),
          ),
        );

        expect(find.byType(HitExpandedBox), findsOneWidget);
      });

      testWidgets('with tight height constraint', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: HitExpandedBox(child: SizedBox(width: 100, height: 40)),
            ),
          ),
        );

        final box = tester.renderObject<RenderBox>(find.byType(HitExpandedBox));
        expect(box.size.height, equals(40));
      });
    });

    group('hit testing', () {
      testWidgets('registers taps inside normal bounds', (tester) async {
        var centerTapped = false;

        await tester.pumpWidget(
          _buildExpandedHitScene(
            expandLeft: 30,
            expandRight: 30,
            handleWidth: 20,
            onLeftHandleTap: () {},
            onRightHandleTap: () {},
            onCenterTap: () => centerTapped = true,
          ),
        );

        // Tap center of the main content area (100,100) + (50,25).
        await tester.tapAt(const Offset(150, 125));
        expect(centerTapped, isTrue);
      });

      testWidgets('registers taps on handle in expanded left margin', (
        tester,
      ) async {
        var leftTapped = false;

        await tester.pumpWidget(
          _buildExpandedHitScene(
            expandLeft: 30,
            expandRight: 30,
            handleWidth: 20,
            onLeftHandleTap: () => leftTapped = true,
            onRightHandleTap: () {},
            onCenterTap: () {},
          ),
        );

        // Left handle is outside main content bounds: x in [80, 100].
        await tester.tapAt(const Offset(90, 125));

        expect(leftTapped, isTrue);
      });

      testWidgets('registers taps on handle in expanded right margin', (
        tester,
      ) async {
        var rightTapped = false;

        await tester.pumpWidget(
          _buildExpandedHitScene(
            expandLeft: 30,
            expandRight: 30,
            handleWidth: 20,
            onLeftHandleTap: () {},
            onRightHandleTap: () => rightTapped = true,
            onCenterTap: () {},
          ),
        );

        // Right handle is outside main content bounds: x in [200, 220].
        await tester.tapAt(const Offset(210, 125));

        expect(rightTapped, isTrue);
      });

      testWidgets('ignores taps beyond the expanded area', (tester) async {
        var anyTapped = false;
        void onTap() => anyTapped = true;

        await tester.pumpWidget(
          _buildExpandedHitScene(
            expandLeft: 20,
            expandRight: 20,
            handleWidth: 15,
            onLeftHandleTap: onTap,
            onRightHandleTap: onTap,
            onCenterTap: onTap,
          ),
        );

        // Tap well outside the expanded area.
        await tester.tapAt(const Offset(10, 10));
        expect(anyTapped, isFalse);
      });

      testWidgets('ignores taps outside vertical bounds', (tester) async {
        var anyTapped = false;
        void onTap() => anyTapped = true;

        await tester.pumpWidget(
          _buildExpandedHitScene(
            expandLeft: 30,
            expandRight: 30,
            handleWidth: 20,
            onLeftHandleTap: onTap,
            onRightHandleTap: onTap,
            onCenterTap: onTap,
          ),
        );

        // Tap below the widget (y > 100 + 50 = 150).
        await tester.tapAt(const Offset(150, 170));
        expect(anyTapped, isFalse);
      });
    });

    group('updateRenderObject', () {
      testWidgets('updates expand values on rebuild', (tester) async {
        var expandLeft = 10.0;
        var expandRight = 10.0;
        late StateSetter rebuildState;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuildState = setState;
                return Center(
                  child: HitExpandedBox(
                    expandLeft: expandLeft,
                    expandRight: expandRight,
                    child: const SizedBox(width: 100, height: 50),
                  ),
                );
              },
            ),
          ),
        );

        var renderObject = tester.renderObject<RenderHitExpandedBox>(
          find.byType(HitExpandedBox),
        );
        expect(renderObject.expandLeft, equals(10));
        expect(renderObject.expandRight, equals(10));

        rebuildState(() {
          expandLeft = 30;
          expandRight = 40;
        });
        await tester.pump();

        renderObject = tester.renderObject<RenderHitExpandedBox>(
          find.byType(HitExpandedBox),
        );
        expect(renderObject.expandLeft, equals(30));
        expect(renderObject.expandRight, equals(40));
      });

      testWidgets('updates height constraint on rebuild', (tester) async {
        var height = 40.0;
        late StateSetter rebuildState;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuildState = setState;
                return Center(
                  child: HitExpandedBox(
                    child: SizedBox(width: 100, height: height),
                  ),
                );
              },
            ),
          ),
        );

        var box = tester.renderObject<RenderBox>(find.byType(HitExpandedBox));
        expect(box.size.height, equals(40));

        rebuildState(() => height = 60);
        await tester.pump();

        box = tester.renderObject<RenderBox>(find.byType(HitExpandedBox));
        expect(box.size.height, equals(60));
      });
    });
  });
}
