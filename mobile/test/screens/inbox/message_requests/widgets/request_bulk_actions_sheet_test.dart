// ABOUTME: Widget tests for RequestBulkActionsSheet.
// ABOUTME: Verifies both tiles render, that tapping one closes the sheet and
// ABOUTME: completes with the matching RequestBulkAction, and that dismissing
// ABOUTME: it completes with null.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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

    // A real GoRouter, not the MockGoRouter the rest of the inbox tests use.
    // The sheet once dismissed through go_router's `context.pop(result)`, which
    // a mock no-ops, so `VineBottomSheet.show` never completed its future and
    // every assertion about the result was unreachable while the old
    // `verify(pop(...))` still passed (#8409). The real router keeps these
    // assertions honest whichever navigator API the tiles use.
    Widget buildSubject({
      required ValueChanged<RequestBulkAction?> onResult,
      Locale? locale,
    }) {
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
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
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

    // `find.text(l10n.inboxRequestsMarkAllRead)` resolves to the English
    // literal, so on its own it passes whether the tile reads `context.l10n`
    // or hardcodes the string. Pumping a non-English locale is what tells the
    // two apart, which is the claim the assertions above are making.
    testWidgets('renders both tiles in the active locale', (tester) async {
      final filipino = lookupAppLocalizations(const Locale('fil'));
      await tester.pumpWidget(
        buildSubject(onResult: (_) {}, locale: const Locale('fil')),
      );

      await showSheet(tester);

      expect(find.text(filipino.inboxRequestsMarkAllRead), findsOneWidget);
      expect(find.text(filipino.inboxRequestsRemoveAll), findsOneWidget);
      expect(find.text(l10n.inboxRequestsMarkAllRead), findsNothing);
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

    // The opener can be torn down while the sheet is up — a route redirect
    // or a rebuild of the requests view. Resolving the navigator from its
    // context at tap time then throws, because a deactivated element has no
    // inherited widgets left to find the router through.
    testWidgets('returns the tapped action after its opener unmounts', (
      tester,
    ) async {
      RequestBulkAction? capturedResult;
      final openerVisible = ValueNotifier<bool>(true);
      addTearDown(openerVisible.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: openerVisible,
                builder: (_, visible, _) => visible
                    ? _SheetOpener(
                        onResult: (result) => capturedResult = result,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
        ),
      );

      await showSheet(tester);
      openerVisible.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(showSheetButtonKey), findsNothing);

      await tester.tap(find.text(l10n.inboxRequestsRemoveAll));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
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

/// Opens the sheet from its own [State.context], so unmounting it leaves the
/// sheet open above a defunct opener.
class _SheetOpener extends StatefulWidget {
  const _SheetOpener({required this.onResult});

  final ValueChanged<RequestBulkAction?> onResult;

  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: const Key('show-sheet-button'),
      onPressed: () async {
        widget.onResult(await RequestBulkActionsSheet.show(context));
      },
      child: const Text('Show sheet'),
    );
  }
}
