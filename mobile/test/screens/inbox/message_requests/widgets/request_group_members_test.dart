// ABOUTME: Widget tests for RequestGroupMembers, the member list on a group
// ABOUTME: message request (#10018).

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_group_members.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../../helpers/go_router.dart';
import '../../../../helpers/test_provider_overrides.dart';
import '../../../../helpers/test_pubkeys.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final alice = testPubkeyFromSeed(2);
  final bob = testPubkeyFromSeed(3);

  UserProfile profileOf(String pubkey, String name, {String? nip05}) =>
      UserProfile(
        pubkey: pubkey,
        displayName: name,
        picture: 'https://example.com/$name.jpg',
        nip05: nip05,
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: 'c' * 64,
      );

  group(RequestGroupMembers, () {
    late MockGoRouter goRouter;

    setUp(() {
      goRouter = MockGoRouter();
      when(() => goRouter.push<void>(any())).thenAnswer((_) async {});
    });

    Widget buildSubject(
      List<String> members, {
      List<Override> overrides = const [],
    }) {
      return testMaterialApp(
        additionalOverrides: overrides,
        home: MockGoRouterProvider(
          goRouter: goRouter,
          child: Scaffold(
            body: RequestGroupMembers(memberPubkeys: members),
          ),
        ),
      );
    }

    UserAvatar avatarIn(WidgetTester tester, String name) =>
        tester.widget<UserAvatar>(
          find.descendant(
            of: find.ancestor(
              of: find.text(name),
              matching: find.byType(Row),
            ),
            matching: find.byType(UserAvatar),
          ),
        );

    group('renders', () {
      testWidgets('the heading and one row per member', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            [alice, bob],
            overrides: [
              userProfileReactiveProvider(
                alice,
              ).overrideWith((ref) => Stream.value(profileOf(alice, 'Alice'))),
              userProfileReactiveProvider(
                bob,
              ).overrideWith((ref) => Stream.value(profileOf(bob, 'Bob'))),
            ],
          ),
        );
        await tester.pump();

        expect(
          find.text(l10n.messageRequestGroupMembersHeading),
          findsOneWidget,
        );
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(
          avatarIn(tester, 'Alice').imageUrl,
          'https://example.com/Alice.jpg',
        );
      });

      testWidgets('a verified NIP-05 as the identifier', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            [alice],
            overrides: [
              userProfileReactiveProvider(alice).overrideWith(
                (ref) => Stream.value(
                  profileOf(alice, 'Alice', nip05: 'alice@example.com'),
                ),
              ),
              nip05ClaimVerificationProvider(
                Nip05Claim(pubkey: alice, nip05: 'alice@example.com'),
              ).overrideWith((ref) async => Nip05VerificationStatus.verified),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('alice@example.com'), findsOneWidget);
        expect(find.text(NostrKeyUtils.encodePubKey(alice)), findsNothing);
      });

      testWidgets('the npub while the NIP-05 claim is unverified', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            [alice],
            overrides: [
              userProfileReactiveProvider(alice).overrideWith(
                (ref) => Stream.value(
                  profileOf(alice, 'Alice', nip05: 'alice@example.com'),
                ),
              ),
              nip05ClaimVerificationProvider(
                Nip05Claim(pubkey: alice, nip05: 'alice@example.com'),
              ).overrideWith((ref) async => Nip05VerificationStatus.failed),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(NostrKeyUtils.encodePubKey(alice)), findsOneWidget);
        expect(find.text('alice@example.com'), findsNothing);
      });

      testWidgets('a blocked member marked, without their photo', (
        tester,
      ) async {
        final blocklist = ContentBlocklistRepository();
        addTearDown(blocklist.dispose);
        await tester.runAsync(
          () => blocklist.blockUsers([alice], ourPubkey: testPubkeyFromSeed(1)),
        );
        expect(blocklist.isBlocked(alice), isTrue);

        await tester.pumpWidget(
          buildSubject(
            [alice, bob],
            overrides: [
              contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
              userProfileReactiveProvider(
                alice,
              ).overrideWith((ref) => Stream.value(profileOf(alice, 'Alice'))),
              userProfileReactiveProvider(
                bob,
              ).overrideWith((ref) => Stream.value(profileOf(bob, 'Bob'))),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Alice'), findsOneWidget);
        expect(find.text(l10n.profileBlockedLabel), findsOneWidget);
        expect(avatarIn(tester, 'Alice').imageUrl, isNull);
        expect(avatarIn(tester, 'Bob').imageUrl, 'https://example.com/Bob.jpg');
      });

      // #10151: a room's members are whoever its author listed, so the
      // moderation account is listed by its own name but never as Divine.
      testWidgets('the moderation account without the wordmark or a handle', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            [kModerationPubkeyHex, bob],
            overrides: [
              userProfileReactiveProvider(kModerationPubkeyHex).overrideWith(
                (ref) => Stream.value(
                  profileOf(
                    kModerationPubkeyHex,
                    l10n.inboxSupportRowTitle,
                    nip05: 'moderation@example.com',
                  ),
                ),
              ),
              // Even a claim that verifies is withheld for a moderation key.
              nip05ClaimVerificationProvider(
                const Nip05Claim(
                  pubkey: kModerationPubkeyHex,
                  nip05: 'moderation@example.com',
                ),
              ).overrideWith((ref) async => Nip05VerificationStatus.verified),
              userProfileReactiveProvider(
                bob,
              ).overrideWith((ref) => Stream.value(profileOf(bob, 'Bob'))),
            ],
          ),
        );
        await tester.pump();
        // A second frame lets the claim's verification settle.
        await tester.pump();

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.logo,
          ),
          findsNothing,
        );
        expect(find.text('moderation@example.com'), findsNothing);
        expect(
          find.text(NostrKeyUtils.encodePubKey(kModerationPubkeyHex)),
          findsOneWidget,
        );
        expect(avatarIn(tester, l10n.inboxSupportRowTitle).imageUrl, isNull);
      });

      testWidgets('a deleted account named for the state', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            [alice],
            overrides: [
              userProfileReactiveProvider(
                alice,
              ).overrideWith((ref) => Stream.value(profileOf(alice, 'Alice'))),
              profileVanishedProvider(alice).overrideWith((ref) => true),
            ],
          ),
        );
        await tester.pump();

        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        expect(find.text('Alice'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets("tapping a row opens that member's profile", (tester) async {
        await tester.pumpWidget(
          buildSubject(
            [alice, bob],
            overrides: [
              userProfileReactiveProvider(
                alice,
              ).overrideWith((ref) => Stream.value(profileOf(alice, 'Alice'))),
              userProfileReactiveProvider(
                bob,
              ).overrideWith((ref) => Stream.value(profileOf(bob, 'Bob'))),
            ],
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Alice'));
        await tester.pump();

        verify(
          () => goRouter.push<void>(
            any(that: contains(NostrKeyUtils.encodePubKey(alice))),
          ),
        ).called(1);
        verifyNever(
          () => goRouter.push<void>(
            any(that: contains(NostrKeyUtils.encodePubKey(bob))),
          ),
        );
      });
    });
  });
}
