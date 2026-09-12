// ABOUTME: Pins UserProfileTile to the vanished-account substitution.
// ABOUTME: This is the row the badge screens, follower/following lists and
// ABOUTME: engagement lists all render, so the picker and the screens it feeds
// ABOUTME: have to agree about who an account is (#8421 adjacent).

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  const pubkey =
      'b75b9a3131f4263add94ba20beb352a1'
      '1032684f2dac07a7e1af827c6f3c1505';

  late AppLocalizations l10n;

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  UserProfile profileWith({String? nip05}) => UserProfile(
    pubkey: pubkey,
    displayName: 'Aeontropy',
    nip05: nip05,
    picture: 'https://example.invalid/aeontropy.png',
    rawData: const {},
    createdAt: DateTime(2026),
    eventId: 'e' * 64,
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    required bool isVanished,
    UserProfile? profile,
    FollowRelationship relationship = FollowRelationship.none,
  }) async {
    await tester.pumpWidget(
      testMaterialApp(
        additionalOverrides: [
          // Overridden directly rather than through
          // `vanishedProfilePubkeysProvider`: the derived provider reads
          // `.value`, which is null until the source stream's first microtask,
          // and that window outlives the pump.
          profileVanishedProvider(pubkey).overrideWith((ref) => isVanished),
          followRelationshipProvider(
            pubkey,
          ).overrideWith((ref) => Stream.value(relationship)),
          if (profile != null)
            userProfileReactiveProvider(
              pubkey,
            ).overrideWith((ref) => Stream.value(profile)),
        ],
        home: const Scaffold(
          body: UserProfileTile(pubkey: pubkey, showFollowButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group(UserProfileTile, () {
    group('renders', () {
      testWidgets('names a live account from its profile', (tester) async {
        await pumpTile(tester, isVanished: false, profile: profileWith());

        expect(find.text('Aeontropy'), findsOneWidget);
        expect(find.text(l10n.profileDeletedAccountName), findsNothing);
      });

      testWidgets('names a vanished account "Deleted account"', (tester) async {
        await pumpTile(tester, isVanished: true, profile: profileWith());

        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        expect(find.text('Aeontropy'), findsNothing);
      });

      testWidgets("loads a live account's photo", (tester) async {
        // The control for the case below: without it a green findsNothing
        // there could mean the finder is dead rather than the branch taken.
        await pumpTile(tester, isVanished: false, profile: profileWith());

        expect(find.byType(VineCachedImage), findsOneWidget);
      });

      testWidgets("drops a vanished account's photo", (tester) async {
        await pumpTile(tester, isVanished: true, profile: profileWith());

        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets("hides a vanished account's NIP-05", (tester) async {
        await pumpTile(
          tester,
          isVanished: true,
          profile: profileWith(nip05: '_@aeontropy.divine.video'),
        );

        expect(find.text('@aeontropy'), findsNothing);
      });

      testWidgets(
        "drops the whole second line, not just a vanished account's NIP-05",
        (tester) async {
          // `resolveUserIdentifierLine` falls through to relationship and
          // follower count when it has no handle, so nulling only the handle
          // swaps "@aeontropy" for social proof about the deleted account
          // rather than removing the line. The mutual relationship is what
          // makes that fall-through reachable here.
          await pumpTile(
            tester,
            isVanished: true,
            profile: profileWith(nip05: '_@aeontropy.divine.video'),
            relationship: FollowRelationship.mutual,
          );

          expect(find.text(l10n.socialProofMutual), findsNothing);
          expect(find.text('@aeontropy'), findsNothing);
        },
      );

      testWidgets('keeps the relationship line on a live account', (
        tester,
      ) async {
        // The control: without it the assertion above could pass because the
        // line never renders, rather than because the vanish branch drops it.
        await pumpTile(
          tester,
          isVanished: false,
          profile: profileWith(),
          relationship: FollowRelationship.mutual,
        );

        expect(find.text(l10n.socialProofMutual), findsOneWidget);
      });

      testWidgets("keeps a live account's NIP-05", (tester) async {
        await pumpTile(
          tester,
          isVanished: false,
          profile: profileWith(nip05: '_@aeontropy.divine.video'),
        );

        expect(find.text('@aeontropy'), findsOneWidget);
      });
    });
  });
}
