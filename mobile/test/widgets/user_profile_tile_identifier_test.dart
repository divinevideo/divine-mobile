// ABOUTME: Widget tests for the user tile's secondary identifier line.
// ABOUTME: Pins NIP-05 precedence and the social-proof fallback over npubs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('$UserProfileTile identifier line', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const pubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    UserProfile profileWith({
      String? nip05,
      Map<String, dynamic> rawData = const {},
    }) {
      return UserProfile(
        pubkey: pubkey,
        name: 'Jack',
        nip05: nip05,
        rawData: rawData,
        createdAt: DateTime(2024),
        eventId: 'event1',
      );
    }

    Widget buildSubject({
      UserProfile? profile,
      Nip05VerificationStatus verificationStatus = Nip05VerificationStatus.none,
      FollowRelationship relationship = FollowRelationship.none,
    }) {
      return testProviderScope(
        additionalOverrides: [
          userProfileReactiveProvider.overrideWith(
            (ref, key) => Stream.value(profile),
          ),
          nip05VerificationProvider.overrideWith(
            (ref, key) async => verificationStatus,
          ),
          followRelationshipProvider.overrideWith(
            (ref, key) => Stream.value(relationship),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UserProfileTile(pubkey: pubkey),
          ),
        ),
      );
    }

    testWidgets('shows the handle rather than a key', (tester) async {
      await tester.pumpWidget(
        buildSubject(profile: profileWith(nip05: '_@jack.divine.video')),
      );
      await tester.pumpAndSettle();

      expect(find.text('@jack'), findsOneWidget);
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('keeps the handle when the well-known fetch errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profile: profileWith(nip05: '_@jack.divine.video'),
          verificationStatus: Nip05VerificationStatus.error,
        ),
      );
      await tester.pumpAndSettle();

      // A network failure is not an impersonation signal.
      expect(find.text('@jack'), findsOneWidget);
    });

    testWidgets('replaces a mismatched handle with social proof', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profile: profileWith(
            nip05: '_@jack.divine.video',
            rawData: const {'follower_count': 430},
          ),
          verificationStatus: Nip05VerificationStatus.failed,
          relationship: FollowRelationship.followsYou,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@jack'), findsNothing);
      expect(
        find.text(
          '${l10n.socialProofFollowsYou} · '
          '${l10n.socialProofFollowerCount(430, '430')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to social proof when there is no handle', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profile: profileWith(rawData: const {'follower_count': 2100}),
          relationship: FollowRelationship.mutual,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${l10n.socialProofMutual} · '
          '${l10n.socialProofFollowerCount(2100, '2.1K')}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('npub'), findsNothing);
    });

    testWidgets('does not render a self-reported Vine follower count', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          profile: profileWith(rawData: const {'vine_followers': 430}),
          relationship: FollowRelationship.mutual,
        ),
      );
      await tester.pumpAndSettle();

      // vine_followers is the account's own kind-0 claim; only an
      // authoritative follower_count earns a spot on the line.
      expect(find.text(l10n.socialProofMutual), findsOneWidget);
      expect(find.textContaining('430'), findsNothing);
    });

    testWidgets('renders no identifier line when nothing is known', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: profileWith()));
      await tester.pumpAndSettle();

      expect(find.text('Jack'), findsOneWidget);
      expect(find.textContaining('npub'), findsNothing);
    });
  });
}
