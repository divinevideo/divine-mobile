import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../../helpers/badge_fixtures.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group('BadgesScreen', () {
    late _MockBadgeRepository repository;
    late BadgeAwardViewData awardedBadge;
    late IssuedBadgeViewData issuedBadge;
    late CreatedBadgeViewData createdBadge;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(badgeAwardFixture(isAccepted: false));
    });

    setUp(() {
      repository = _MockBadgeRepository();
      awardedBadge = badgeAwardFixture(isAccepted: false);
      issuedBadge = _issuedViewData(recipientAccepted: true);
      createdBadge = _createdViewData();
    });

    /// The issued tab renders recipients through [UserProfileTile], which
    /// reaches for auth and profile providers — hence the standard test
    /// overrides rather than a bare scope.
    Widget buildSubject() {
      return testMaterialApp(
        additionalOverrides: [
          badgeRepositoryProvider.overrideWithValue(repository),
        ],
        home: const BadgesScreen(),
      );
    }

    testWidgets('opens on the awarded tab', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [awardedBadge],
          issued: [issuedBadge],
          created: [createdBadge],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(DiVineAppBar), findsOneWidget);
      expect(find.text(l10n.badgesTitle), findsOneWidget);
      expect(find.text('Diviner of the Day'), findsOneWidget);
      expect(find.text(l10n.badgesStatusNotAccepted), findsOneWidget);
      expect(find.text(l10n.badgesActionAccept), findsOneWidget);
      expect(find.text(l10n.badgesActionReject), findsOneWidget);
      // The other tabs' content is not built until they are selected.
      expect(find.text('Diviner of the Month'), findsNothing);
    });

    testWidgets('awarded card skips the description line when it is empty', (
      tester,
    ) async {
      // A definition published by another client can carry ["description", ""],
      // which parses back as '' rather than null.
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [badgeAwardFixture(isAccepted: false, description: '')],
          issued: [issuedBadge],
          created: [createdBadge],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Diviner of the Day'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data?.isEmpty ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('created tab lists the badges the user made', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [awardedBadge],
          issued: [issuedBadge],
          created: [createdBadge],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesTabCreated));
      await tester.pumpAndSettle();

      expect(find.text('Diviner of the Month'), findsOneWidget);
      expect(find.text(l10n.badgesCreatedAwardSummary(3)), findsOneWidget);
    });

    testWidgets('issued tab lists recipient acceptance', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [awardedBadge],
          issued: [issuedBadge],
          created: [createdBadge],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesTabIssued));
      await tester.pumpAndSettle();

      expect(find.text('Diviner of the Week'), findsOneWidget);
      // Collapsed by default: a badge can carry thousands of recipients, and
      // each row resolves a profile, so none of them build until asked for.
      expect(find.byType(UserProfileTile), findsNothing);
      expect(find.text(l10n.badgesCreatedAwardSummary(1)), findsOneWidget);

      await tester.tap(find.text('Diviner of the Week'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesRecipientAcceptedStatus), findsOneWidget);
      // Recipients render as people, not as raw keys.
      expect(find.byType(UserProfileTile), findsOneWidget);
      expect(find.text(badgeTestPubkey(3)), findsNothing);
    });

    testWidgets('created tab shows its own empty state', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [awardedBadge],
          issued: const [],
          created: const [],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesTabCreated));
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesCreatedEmptyTitle), findsOneWidget);
      expect(find.text(l10n.badgesCreatedEmptySubtitle), findsOneWidget);
    });

    testWidgets('offers an undo right after rejecting an award', (
      tester,
    ) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [awardedBadge],
          issued: const [],
          created: const [],
        ),
      );
      when(() => repository.hideAward(any())).thenAnswer((_) async {});
      when(() => repository.unhideAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesActionReject));
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesHiddenSnackbar), findsOneWidget);
      await tester.tap(find.text(l10n.badgesHiddenSnackbarUndo));
      await tester.pumpAndSettle();

      verify(
        () => repository.unhideAward(awardedBadge.definitionCoordinate),
      ).called(1);
    });

    testWidgets('an accepted award can be rejected, not only removed', (
      tester,
    ) async {
      final accepted = badgeAwardFixture(isAccepted: true);
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [accepted],
          issued: const [],
          created: const [],
        ),
      );
      when(() => repository.hideAward(any())).thenAnswer((_) async {});
      when(() => repository.removeAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesActionRemove), findsOneWidget);
      await tester.tap(find.text(l10n.badgesActionReject));
      await tester.pumpAndSettle();

      // Unpinned as well as dismissed: hiding alone would leave it on the
      // profile while it is gone from the dashboard.
      verify(() => repository.removeAward(accepted)).called(1);
      verify(
        () => repository.hideAward(accepted.definitionCoordinate),
      ).called(1);
    });

    testWidgets('a badge pinned without an award can only be removed', (
      tester,
    ) async {
      const coordinate = '30009:pinned-issuer:orphan';
      when(repository.loadDashboard).thenAnswer(
        (_) async => const BadgeDashboardData(
          awarded: [
            BadgeAwardViewData.pinnedWithoutAward(
              definitionCoordinate: coordinate,
              awardEventId: 'orphan-award',
              awardedAt: 1000,
            ),
          ],
          issued: [],
          created: [],
        ),
      );
      when(() => repository.removeAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Dismissing it would hide the only row that can take it off the
      // profile, so the action is not offered.
      expect(find.text(l10n.badgesActionReject), findsNothing);
      expect(find.text(l10n.badgesActionAccept), findsNothing);

      await tester.tap(find.text(l10n.badgesActionRemove));
      await tester.pumpAndSettle();

      verify(() => repository.removeAward(any())).called(1);
    });

    testWidgets('restores a dismissed award from the hidden section', (
      tester,
    ) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: const [],
          issued: const [],
          created: const [],
          hidden: [awardedBadge],
        ),
      );
      when(() => repository.unhideAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Collapsed by default: the badge itself is not on screen yet.
      expect(find.text(l10n.badgesActionRestore), findsNothing);

      await tester.tap(find.text(l10n.badgesHiddenSectionTitle(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.badgesActionRestore));
      await tester.pumpAndSettle();

      verify(
        () => repository.unhideAward(awardedBadge.definitionCoordinate),
      ).called(1);
    });

    testWidgets('accept button delegates to the repository', (tester) async {
      when(repository.loadDashboard).thenAnswer(
        (_) async => BadgeDashboardData(
          awarded: [awardedBadge],
          issued: const [],
          created: const [],
        ),
      );
      when(() => repository.acceptAward(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgesActionAccept));
      await tester.pumpAndSettle();

      verify(() => repository.acceptAward(awardedBadge)).called(1);
      verify(repository.loadDashboard).called(greaterThanOrEqualTo(2));
    });
  });
}

CreatedBadgeViewData _createdViewData() {
  final issuerPubkey = badgeTestPubkey(1);
  return CreatedBadgeViewData(
    definition: Nip58BadgeDefinition(
      event: badgeTestEvent(
        id: badgeTestEventId(5),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: '30009:$issuerPubkey:monthly-diviner',
      dTag: 'monthly-diviner',
      name: 'Diviner of the Month',
    ),
    awardCount: 2,
    recipientCount: 3,
  );
}

IssuedBadgeViewData _issuedViewData({required bool recipientAccepted}) {
  final issuerPubkey = badgeTestPubkey(1);
  final recipientPubkey = badgeTestPubkey(3);
  final definitionCoordinate = '30009:$issuerPubkey:weekly-diviner';
  return IssuedBadgeViewData(
    coordinate: definitionCoordinate,
    latestAwardedAt: 1000,
    definition: Nip58BadgeDefinition(
      event: badgeTestEvent(
        id: badgeTestEventId(4),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: definitionCoordinate,
      dTag: 'weekly-diviner',
      name: 'Diviner of the Week',
    ),
    recipients: [
      IssuedBadgeRecipientViewData(
        pubkey: recipientPubkey,
        isAccepted: recipientAccepted,
      ),
    ],
  );
}
