// ABOUTME: Widget tests for showOwnerVideoDeleteConfirmationDialog.
// ABOUTME: Pins both answers and the no-op the buttons owe a torn-down route.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/owner_video_delete_confirmation_dialog.dart';

void main() {
  group('showOwnerVideoDeleteConfirmationDialog', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<Future<bool>> openDialog(WidgetTester tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      final confirmed = showOwnerVideoDeleteConfirmationDialog(hostContext);
      await tester.pumpAndSettle();
      expect(find.text(l10n.shareMenuDeleteConfirmation), findsOneWidget);
      return confirmed;
    }

    testWidgets('resolves true when the delete action is tapped', (
      tester,
    ) async {
      final confirmed = await openDialog(tester);

      await tester.tap(find.text(l10n.shareMenuDelete));
      await tester.pumpAndSettle();

      await expectLater(confirmed, completion(isTrue));
    });

    testWidgets('resolves false when the cancel action is tapped', (
      tester,
    ) async {
      final confirmed = await openDialog(tester);

      await tester.tap(find.text(l10n.shareMenuCancel));
      await tester.pumpAndSettle();

      await expectLater(confirmed, completion(isFalse));
    });

    testWidgets('both actions no-op once their route is torn down', (
      tester,
    ) async {
      // Opened and then deliberately abandoned: the callbacks are the subject
      // here, not the dialog's future. Tearing the whole tree down is a blunter
      // teardown than the route pop the app performs, and when the future
      // resolves under it is the route's business rather than the guard's.
      unawaited(await openDialog(tester));

      VoidCallback actionFor(String label) => tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed!;

      final cancel = actionFor(l10n.shareMenuCancel);
      final delete = actionFor(l10n.shareMenuDelete);

      // Stands in for anything that drops the dialog's route while the tap is
      // in flight — a rebuild above the modal, a redirect, a deep link.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(cancel, returnsNormally);
      expect(delete, returnsNormally);
    });
  });
}
