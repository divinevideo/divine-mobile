// ABOUTME: Tests for PlayerGestureSurface — the feed video's tap surface.
// ABOUTME: Pins that the LABEL and the TAP ACTION land on the same semantics
// ABOUTME: node, which is what shipped broken and what a device caught.

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/player_gesture_surface.dart';

import '../../helpers/accessibility_guidelines.dart';
import '../../helpers/test_provider_overrides.dart';

void main() {
  group(PlayerGestureSurface, () {
    Widget host({required bool interactiveReady, bool isOwnVideo = false}) =>
        testMaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 200,
                child: PlayerGestureSurface(
                  interactiveReady: interactiveReady,
                  isOwnVideo: isOwnVideo,
                  onTap: () {},
                  onDoubleTapDown: (_) {},
                  onLongPressStart: () {},
                ),
              ),
            ),
          ),
        );

    testWidgets('the labelled node is the one that owns the tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(host(interactiveReady: true));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoPlayerPlayVideo),
        );

        // The label used to sit on an ANCESTOR Semantics that owned no tap
        // action, so the node a screen reader activates was anonymous. On device
        // that surfaced as SemanticsNode#7(Rect 0,0,440,850, actions: [tap]) with
        // no label, failing labeledTapTargetGuideline.
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'the labelled node must be the tappable one',
        );
        expect(node.hint, equals(l10n.videoPlayerTapHint));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('omits the double-tap hint on the viewer own video', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          host(interactiveReady: true, isOwnVideo: true),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoPlayerPlayVideo),
        );

        expect(node.hint, isEmpty);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('meets the tap-target and labelling guidelines', (
      tester,
    ) async {
      await tester.pumpWidget(host(interactiveReady: true));
      await tester.pump();

      await expectMeetsAccessibilityGuidelines(
        tester,
        guidelines: divineSemanticsGuidelines,
      );
    });

    testWidgets('publishes no tap action before the player is ready', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(host(interactiveReady: false));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoPlayerPlayVideo),
        );

        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      } finally {
        handle.dispose();
      }
    });
  });
}
