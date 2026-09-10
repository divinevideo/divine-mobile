// ABOUTME: BadgeRecipientRow — the acceptance pill, its unknown state, and
// ABOUTME: the issuer-only revoke action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/screens/badges/widgets/badge_status_pill.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(BadgeRecipientRow, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpRow(
      WidgetTester tester, {
      required bool? isAccepted,
      bool showRevokeAction = false,
      bool isRevoking = false,
      VoidCallback? onRevoke,
    }) {
      return tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BadgeRecipientRow(
                pubkey:
                    'a1b2c3d4e5f6789012345678901234567890abcdef'
                    '123456789012345678901234',
                isAccepted: isAccepted,
                showRevokeAction: showRevokeAction,
                isRevoking: isRevoking,
                onRevoke: onRevoke,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the accepted pill when the award is pinned', (
      tester,
    ) async {
      await pumpRow(tester, isAccepted: true);

      expect(find.byType(BadgeStatusPill), findsOneWidget);
      expect(find.text(l10n.badgesRecipientAcceptedStatus), findsOneWidget);
    });

    testWidgets('shows the waiting pill when the award is not pinned', (
      tester,
    ) async {
      await pumpRow(tester, isAccepted: false);

      expect(find.text(l10n.badgesRecipientWaitingStatus), findsOneWidget);
    });

    testWidgets('offers no revoke action by default', (tester) async {
      await pumpRow(tester, isAccepted: true);

      expect(
        find.bySemanticsLabel(l10n.badgeDetailRevokeAction),
        findsNothing,
      );
    });

    testWidgets('calls back when the issuer revokes the award', (tester) async {
      var revoked = 0;
      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        onRevoke: () => revoked++,
      );

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailRevokeAction));
      await tester.pump();

      expect(revoked, 1);
    });

    testWidgets('keeps the acceptance pill out of the revoke button', (
      tester,
    ) async {
      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        onRevoke: () {},
      );

      expect(
        tester.getSemantics(find.byType(DivineIconButton)).label,
        l10n.badgeDetailRevokeAction,
      );
    });

    testWidgets('shows progress on the row whose award is going', (
      tester,
    ) async {
      // A greyed-out button is indistinguishable from every other greyed-out
      // button on the screen, so the row doing the work says so itself.
      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        isRevoking: true,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DivineIconButton), findsNothing);
    });

    testWidgets('leaves the row geometry untouched while revoking', (
      tester,
    ) async {
      // The spinner takes the button's box, so the list does not jump when
      // the swap happens.
      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        onRevoke: () {},
      );
      // The tile shares the row with the trailing control, so its rect is
      // what a wider or narrower spinner would move; the row's own size is
      // parent-constrained and could never fail (#8617).
      final idleTile = tester.getRect(find.byType(UserProfileTile));

      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        isRevoking: true,
      );

      // Unchanged geometry only means something once the spinner has
      // actually replaced the button.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getRect(find.byType(UserProfileTile)), idleTile);
    });

    testWidgets('greys the revoke action out instead of removing it', (
      tester,
    ) async {
      // A row that loses its trailing button mid-flight reflows the whole
      // list; disabling keeps the layout still.
      await pumpRow(tester, isAccepted: true, showRevokeAction: true);

      expect(
        tester
            .widget<DivineIconButton>(find.byType(DivineIconButton))
            .onPressed,
        isNull,
      );
    });

    testWidgets('claims no status when acceptance was not resolved', (
      tester,
    ) async {
      // Past the recipient-check limit the answer is unknown, and "Waiting
      // for recipient" would be a claim the repository never made.
      await pumpRow(tester, isAccepted: null);

      expect(find.byType(BadgeStatusPill), findsNothing);
    });
  });
}
