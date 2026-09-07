// ABOUTME: Widget tests for RequestBulkActionsSheet.
// ABOUTME: Verifies that both action tiles render and return the correct
// ABOUTME: RequestBulkAction when tapped.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_bulk_actions_sheet.dart';

void main() {
  group(RequestBulkActionsSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const showSheetButtonKey = Key('show-sheet-button');

    // The dark fallback is silent by design, so a dropped theme extension is
    // only observable through this counter — reset it around every pump.
    setUp(() => VineThemeColors.debugFallbackCount = 0);
    tearDown(() => VineThemeColors.debugFallbackCount = 0);

    Widget buildSubject({required ValueChanged<RequestBulkAction?> onResult}) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: showSheetButtonKey,
                    onPressed: () async {
                      final result = await RequestBulkActionsSheet.show(
                        context,
                      );
                      onResult(result);
                    },
                    child: const Text('Show sheet'),
                  );
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      return MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
      );
    }

    Future<void> showSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(showSheetButtonKey));
      await tester.pumpAndSettle();
    }

    testWidgets('renders both action tiles when shown', (tester) async {
      await tester.pumpWidget(buildSubject(onResult: (_) {}));

      await showSheet(tester);

      expect(find.text(l10n.inboxRequestsMarkAllRead), findsOneWidget);
      expect(find.text(l10n.inboxRequestsRemoveAll), findsOneWidget);
      expect(
        VineThemeColors.debugFallbackCount,
        0,
        reason:
            'A modal route is exactly where the VineThemeColors extension goes '
            'missing, and _ActionTile reads context.vineColors for its label '
            'and divider colours.',
      );
    });

    testWidgets('returns markAllRead when first tile tapped', (tester) async {
      RequestBulkAction? capturedResult;
      await tester.pumpWidget(
        buildSubject(onResult: (result) => capturedResult = result),
      );

      await showSheet(tester);
      await tester.tap(find.text(l10n.inboxRequestsMarkAllRead));
      await tester.pumpAndSettle();

      expect(capturedResult, RequestBulkAction.markAllRead);
      expect(find.text(l10n.inboxRequestsMarkAllRead), findsNothing);
    });

    testWidgets('returns removeAll when second tile tapped', (tester) async {
      RequestBulkAction? capturedResult;
      await tester.pumpWidget(
        buildSubject(onResult: (result) => capturedResult = result),
      );

      await showSheet(tester);
      await tester.tap(find.text(l10n.inboxRequestsRemoveAll));
      await tester.pumpAndSettle();

      expect(capturedResult, RequestBulkAction.removeAll);
      expect(find.text(l10n.inboxRequestsRemoveAll), findsNothing);
    });

    // `show` promises "the chosen [RequestBulkAction] or `null` if dismissed",
    // and the only caller leans on it: `message_requests_view.dart:60` returns
    // early on null rather than sweeping the list. `VineBottomSheet.show` runs
    // with the default `tapOutsideToDismiss: true`, so this is a live path —
    // and it was unreachable under the old MockGoRouter, whose no-op `pop`
    // meant the future never completed at all.
    testWidgets('returns null when dismissed without choosing', (tester) async {
      RequestBulkAction? capturedResult;
      var didComplete = false;
      await tester.pumpWidget(
        buildSubject(
          onResult: (result) {
            capturedResult = result;
            didComplete = true;
          },
        ),
      );

      await showSheet(tester);
      expect(find.text(l10n.inboxRequestsMarkAllRead), findsOneWidget);

      // Above the sheet, on the modal barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // `didComplete` is the pin: without it a future that never resolved
      // would leave `capturedResult` null and pass this test vacuously.
      expect(didComplete, isTrue);
      expect(capturedResult, isNull);
      expect(find.text(l10n.inboxRequestsMarkAllRead), findsNothing);
    });
  });
}
