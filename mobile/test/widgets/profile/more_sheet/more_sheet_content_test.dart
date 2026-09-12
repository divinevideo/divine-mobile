// ABOUTME: Widget tests for MoreSheetContent's menu-to-confirmation transition.
// ABOUTME: Pins that the content swap is driven by the animation, not a timer.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_menu.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(MoreSheetContent, () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      bool isBlocked = false,
    }) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: MoreSheetContent(
              userIdHex: 'a' * 64,
              displayName: 'Ada',
              isFollowing: true,
              isBlocked: isBlocked,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // The block row is the tap that starts the transition under test.
    Future<void> tapBlock(WidgetTester tester) async {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MoreSheetContent)),
      );
      await tester.tap(find.text(l10n.profileBlockDisplayName('Ada')));
    }

    group('renders', () {
      testWidgets('starts on the menu', (tester) async {
        await pumpSheet(tester);

        expect(find.byType(MoreSheetMenu), findsOneWidget);
      });
    });

    group('block transition', () {
      // The swap used to run on Future.delayed(200ms) — an unowned timer with
      // nothing but a `mounted` check between it and a disposed widget. It is
      // now driven off the AnimationController the sheet already owns, at the
      // end of the fade-out interval (0.333 of the 600ms transition, i.e. the
      // same 200ms), so it is cancelled with the controller.
      //
      // These assertions pin the visible behaviour; the leak is caught by
      // flutter_test itself, which fails any test that ends with a pending
      // timer. Restoring the old Future.delayed turns two of them red with
      // "A Timer is still pending even after the widget tree was disposed".
      testWidgets('keeps the menu on screen during the fade-out', (
        tester,
      ) async {
        await pumpSheet(tester);

        await tapBlock(tester);
        await tester.pump();

        // Well inside the fade-out phase: the menu must still be the content.
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MoreSheetMenu), findsOneWidget);
      });

      testWidgets('swaps to the confirmation when the fade-out completes', (
        tester,
      ) async {
        await pumpSheet(tester);

        expect(find.byType(MoreSheetMenu), findsOneWidget);

        await tapBlock(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.byType(MoreSheetMenu),
          findsNothing,
          reason: 'the menu is replaced once the fade-out interval ends',
        );
      });

      testWidgets('does not swap without advancing the animation', (
        tester,
      ) async {
        // The swap must be a function of animation progress, not of elapsed
        // wall-clock time since the tap.
        await pumpSheet(tester);

        await tapBlock(tester);
        await tester.pump();

        expect(
          find.byType(MoreSheetMenu),
          findsOneWidget,
          reason: 'no progress has been made, so nothing may have swapped',
        );
      });
    });

    group('lifecycle', () {
      testWidgets('unmounting mid-transition throws nothing', (tester) async {
        // The old timer fired 200ms after the tap whether or not the sheet was
        // still mounted; the listener is torn down with the controller.
        await pumpSheet(tester);

        await tapBlock(tester);
        await tester.pump();

        await tester.pumpWidget(
          testMaterialApp(home: const Scaffold(body: SizedBox())),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      });
    });
  });
}
