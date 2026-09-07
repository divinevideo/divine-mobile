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
  });
}
