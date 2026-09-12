// ABOUTME: Tests for ScrollFadeOverlay — the scroll-driven opacity wrapper
// ABOUTME: that must not rebuild its overlay child on page-position ticks.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';

// Scoped to the widget under test — MaterialApp/Navigator introduce their own
// Opacity/IgnorePointer widgets that would otherwise match.
Finder _in<T extends Widget>() => find.descendant(
  of: find.byType(ScrollFadeOverlay),
  matching: find.byType(T),
);

void main() {
  group(ScrollFadeOverlay, () {
    testWidgets('does not rebuild the child when the page position changes', (
      tester,
    ) async {
      final pagePosition = ValueNotifier<double>(0);
      addTearDown(pagePosition.dispose);
      var childBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScrollFadeOverlay(
            pagePosition: pagePosition,
            index: 0,
            child: Builder(
              builder: (context) {
                childBuilds++;
                return const SizedBox(width: 10, height: 10);
              },
            ),
          ),
        ),
      );

      expect(childBuilds, 1);
      final opacityBefore = tester.widget<Opacity>(_in<Opacity>()).opacity;

      // A page-position tick (scroll away) must fade the overlay without
      // rebuilding the (expensive) overlay content.
      pagePosition.value = 0.5;
      await tester.pump();

      expect(
        childBuilds,
        1,
        reason: 'overlay child must be reused across page-position ticks',
      );
      final opacityAfter = tester.widget<Opacity>(_in<Opacity>()).opacity;
      expect(opacityAfter, lessThan(opacityBefore));
    });

    testWidgets('ignores pointer input once fully faded out', (tester) async {
      final pagePosition = ValueNotifier<double>(0);
      addTearDown(pagePosition.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ScrollFadeOverlay(
            pagePosition: pagePosition,
            index: 0,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      IgnorePointer ignorePointer() =>
          tester.widget<IgnorePointer>(_in<IgnorePointer>());

      expect(ignorePointer().ignoring, isFalse);

      // Scroll a full page away — opacity collapses and the overlay stops
      // absorbing taps meant for the video beneath it.
      pagePosition.value = 1;
      await tester.pump();

      expect(scrollDrivenOpacity(1), lessThan(0.01));
      expect(ignorePointer().ignoring, isTrue);
    });
  });
}
