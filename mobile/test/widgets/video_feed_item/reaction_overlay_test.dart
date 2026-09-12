// ABOUTME: Widget test for the full-screen reaction overlay animation.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_feed_item/reaction_overlay.dart';

void main() {
  group('renders', () {
    testWidgets('paints on a single CustomPaint then fires onComplete', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReactionOverlay(
              emoji: '❤️',
              onComplete: () => completed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // The 6 emoji are now drawn by one CustomPainter, not a Stack of Text.
      expect(
        find.descendant(
          of: find.byType(ReactionOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
      expect(completed, isFalse);

      // Mid-animation: opacity/scale are non-zero here, so the painter actually
      // draws the glyph (at t≈0 and t≈1 they are 0). Still animating.
      await tester.pump(const Duration(milliseconds: 450));
      expect(completed, isFalse);

      // Past the 1100ms animation → completes and notifies.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('does not absorb pointer events (IgnorePointer)', (
      tester,
    ) async {
      var tappedBehind = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tappedBehind = true,
                  child: const SizedBox.expand(),
                ),
                const ReactionOverlay(emoji: '🔥'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      expect(tappedBehind, isTrue);
      // Let the animation finish so no timer leaks into teardown.
      await tester.pump(const Duration(milliseconds: 1200));
    });
  });
}
