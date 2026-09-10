// ABOUTME: Verifies UnfocusOnSheetDismiss drops the keyboard when the sheet
// ABOUTME: starts closing, so iOS does not strand an orphaned keyboard (#5604).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/widgets/unfocus_on_sheet_dismiss.dart';

void main() {
  group(UnfocusOnSheetDismiss, () {
    Future<FocusNode> pumpHostAndOpenSheet(WidgetTester tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => UnfocusOnSheetDismiss(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: Text('drag handle'),
                          ),
                          TextField(focusNode: focusNode, autofocus: true),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The comment field is focused and the keyboard connection is open.
      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      return focusNode;
    }

    /// Reproduces the iOS background/resume split-brain (#5959): the platform
    /// closes the text-input connection, the framework detaches and unfocuses
    /// WITHOUT sending TextInput.hide, and iOS re-presents the keyboard for
    /// the stale first responder — so the keyboard stays visible while the
    /// framework believes nothing is focused.
    Future<void> severConnectionPlatformSide(
      WidgetTester tester,
      FocusNode focusNode,
    ) async {
      tester.testTextInput.closeConnection();
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason:
            'platform-initiated teardown must leave the keyboard '
            'stranded — that is the bug precondition',
      );
    }

    testWidgets(
      'unfocuses the active field when the enclosing sheet starts dismissing',
      (tester) async {
        final focusNode = await pumpHostAndOpenSheet(tester);

        // Dismiss the sheet. The route's transition reverses immediately —
        // the signal UnfocusOnSheetDismiss reacts to — while the field is
        // still mounted and focused.
        Navigator.of(tester.element(find.byType(UnfocusOnSheetDismiss))).pop();
        await tester.pump();

        // Unfocus fired at dismiss-initiation (before teardown), so the
        // text-input connection is closed rather than left orphaned (#5604).
        expect(focusNode.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'hides the stranded keyboard on dismiss after the platform closed the '
      'connection during background/resume',
      (tester) async {
        final focusNode = await pumpHostAndOpenSheet(tester);
        await severConnectionPlatformSide(tester, focusNode);

        // Dismiss the sheet normally. unfocus() alone is a no-op here (the
        // framework already lost focus and connection), so only an explicit
        // TextInput.hide can drop the stranded keyboard (#5959).
        Navigator.of(tester.element(find.byType(UnfocusOnSheetDismiss))).pop();
        await tester.pump();

        expect(tester.testTextInput.isVisible, isFalse);

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'clears the engine-side client on dismiss after the platform closed '
      'the connection during background/resume',
      (tester) async {
        final focusNode = await pumpHostAndOpenSheet(tester);
        await severConnectionPlatformSide(tester, focusNode);

        // In the split-brain state the framework never sends its own
        // TextInput.clearClient, and TextInput.hide alone leaves the engine
        // with a stale client id whose in-hierarchy view iOS 26 can
        // re-present on its own (#6007). The guard must clear the client
        // explicitly, and must do so before the hide so the engine removes
        // the input view during the hide's resign (the engine's own reset
        // order).
        tester.testTextInput.log.clear();
        Navigator.of(tester.element(find.byType(UnfocusOnSheetDismiss))).pop();
        await tester.pumpAndSettle();

        final teardownCalls = tester.testTextInput.log
            .map((call) => call.method)
            .where(
              (method) =>
                  method == 'TextInput.clearClient' ||
                  method == 'TextInput.hide',
            )
            .toList();
        expect(
          teardownCalls,
          equals(['TextInput.clearClient', 'TextInput.hide']),
        );
      },
    );

    testWidgets(
      'hides the stranded keyboard when a chrome drag rides the route '
      'controller to its 0.0 clamp without ever reversing',
      (tester) async {
        final focusNode = await pumpHostAndOpenSheet(tester);
        await severConnectionPlatformSide(tester, focusNode);

        // Drag the sheet chrome down past the sheet's full height in one
        // continuous gesture. This drives the modal route's controller value
        // straight to 0.0: the status goes completed→forward→dismissed and
        // AnimationStatus.reverse never fires (both fling branches in
        // material/bottom_sheet.dart are guarded by `value > 0.0`).
        await tester.drag(find.text('drag handle'), const Offset(0, 700));
        await tester.pumpAndSettle();

        expect(find.byType(UnfocusOnSheetDismiss), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );

    testWidgets(
      'hides the stranded keyboard when the sheet subtree is disposed '
      'without any route status change',
      (tester) async {
        final focusNode = await pumpHostAndOpenSheet(tester);
        await severConnectionPlatformSide(tester, focusNode);

        // Remove the sheet's route without popping it (what a navigator
        // page-stack rebuild does to pageless routes) — no animation status
        // change ever fires, only dispose runs.
        final element = tester.element(find.byType(UnfocusOnSheetDismiss));
        Navigator.of(element).removeRoute(ModalRoute.of(element)!);
        await tester.pump();

        expect(find.byType(UnfocusOnSheetDismiss), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );

    testWidgets(
      'sends TextInput.hide exactly once on a pop that emits both reverse '
      'and dismissed',
      (tester) async {
        final focusNode = await pumpHostAndOpenSheet(tester);
        // Sever the connection first so unfocus() contributes no framework
        // hide of its own — every logged hide is then our explicit one,
        // isolating the dedup guard.
        await severConnectionPlatformSide(tester, focusNode);

        tester.testTextInput.log.clear();
        Navigator.of(tester.element(find.byType(UnfocusOnSheetDismiss))).pop();
        await tester.pumpAndSettle();

        // A pop drives the route controller reverse → dismissed, so both
        // status branches fire; the dedup guard must collapse them to a
        // single explicit hide.
        expect(
          tester.testTextInput.log
              .where((call) => call.method == 'TextInput.hide')
              .length,
          1,
        );
      },
    );

    testWidgets(
      'does not touch the keyboard on disposal when there is no enclosing '
      'modal route',
      (tester) async {
        // A generic host with no modal route never stranded a keyboard, so
        // tearing it down must not reach for global focus or the IME. Pump
        // without any Navigator/route so ModalRoute.of resolves to null.
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: UnfocusOnSheetDismiss(child: SizedBox()),
          ),
        );

        tester.testTextInput.log.clear();
        await tester.pumpWidget(const SizedBox());

        expect(tester.testTextInput.log, isEmpty);
      },
    );

    testWidgets('renders its child unchanged', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UnfocusOnSheetDismiss(child: Text('hello')),
        ),
      );

      expect(find.text('hello'), findsOneWidget);
    });
  });
}
