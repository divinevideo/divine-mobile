// ABOUTME: Widget tests for account details shown in search-result user tiles.
// ABOUTME: Ensures handles, counts, and bios help distinguish shared names.

import 'package:count_formatter/count_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(SearchUserTile, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    UserProfile profileWith({
      String nip05 = '_@lauren.divine.video',
      String? about,
      Map<String, dynamic> rawData = const {},
    }) {
      return UserProfile(
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'Lauren Test',
        nip05: nip05,
        about: about,
        rawData: rawData,
        createdAt: DateTime(2024),
        eventId: 'event1',
      );
    }

    Widget buildSubject(
      UserProfile profile, {
      Nip05VerificationStatus verificationStatus = Nip05VerificationStatus.none,
      FollowRelationship relationship = FollowRelationship.none,
    }) {
      return testProviderScope(
        additionalOverrides: [
          nip05VerificationProvider.overrideWith(
            (ref, pubkey) async => verificationStatus,
          ),
          followRelationshipProvider.overrideWith(
            (ref, pubkey) => Stream.value(relationship),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SearchUserTile(profile: profile)),
        ),
      );
    }

    testWidgets('shows the handle and video count together', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          profileWith(rawData: const {'video_count': 18}),
          verificationStatus: Nip05VerificationStatus.verified,
          relationship: FollowRelationship.youFollow,
        ),
      );
      await tester.pump();

      expect(
        find.text(
          '${l10n.socialProofYouFollow} · @lauren · '
          '${l10n.searchUserVideoCount(18, '18')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides a failed NIP-05 claim even when videos are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profileWith(
            nip05: 'claimed@example.com',
            rawData: const {'video_count': 18},
          ),
          verificationStatus: Nip05VerificationStatus.failed,
        ),
      );
      await tester.pump();

      expect(find.textContaining('claimed@example.com'), findsNothing);
      expect(
        find.textContaining(l10n.searchUserVideoCount(18, '18')),
        findsOneWidget,
      );
    });

    testWidgets('singularizes one video', (tester) async {
      await tester.pumpWidget(
        buildSubject(profileWith(rawData: const {'video_count': 1})),
      );

      expect(
        find.textContaining(l10n.searchUserVideoCount(1, '1')),
        findsOneWidget,
      );
    });

    testWidgets('compacts large video counts', (tester) async {
      await tester.pumpWidget(
        buildSubject(profileWith(rawData: const {'video_count': 12483})),
      );

      final formattedCount = CountFormatter.formatCompact(12483, locale: 'en');
      expect(
        find.textContaining(l10n.searchUserVideoCount(12483, formattedCount)),
        findsOneWidget,
      );
      expect(find.textContaining('12483'), findsNothing);
    });

    testWidgets('shows a verified Divine handle when the count is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profileWith(),
          verificationStatus: Nip05VerificationStatus.verified,
        ),
      );
      await tester.pump();

      expect(find.text('@lauren'), findsOneWidget);
      expect(find.textContaining('@lauren.divine.video'), findsNothing);
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('shows a verified external NIP-05 with its domain', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profileWith(nip05: 'liz@nos.social'),
          verificationStatus: Nip05VerificationStatus.verified,
        ),
      );
      await tester.pump();

      expect(find.text('liz@nos.social'), findsOneWidget);
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('keeps the claimed handle while verification is unresolved', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profileWith()));
      await tester.pump();

      // A pending or failed well-known fetch is a network condition, not an
      // identity claim, so it must not demote the handle to a bare key.
      expect(find.text('@lauren'), findsOneWidget);
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('shows social proof when there is no handle or video count', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profileWith(nip05: '', rawData: const {'follower_count': 2100}),
          relationship: FollowRelationship.mutual,
        ),
      );
      await tester.pump();

      expect(
        find.text(
          '${l10n.socialProofMutual} · '
          '${l10n.socialProofFollowerCount(2100, '2.1K')}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('renders no secondary line when nothing is known', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profileWith(nip05: '')));
      await tester.pump();

      // An npub here would be noise, not disambiguation.
      expect(find.text('Lauren Test'), findsOneWidget);
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('shows a compact bio below account details', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          profileWith(
            about: 'Maker of tiny videos\nfrom the garden',
            rawData: const {'video_count': 4},
          ),
        ),
      );

      expect(find.text('Maker of tiny videos from the garden'), findsOneWidget);
    });
  });
}
