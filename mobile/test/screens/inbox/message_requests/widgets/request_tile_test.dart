// ABOUTME: Widget tests for RequestTile.
// ABOUTME: Verifies avatar, display name, "Sent a message request" subtitle,
// ABOUTME: unread dot, and tap callback.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../../helpers/retired_key_custody.dart';
import '../../../../helpers/test_provider_overrides.dart';

void main() {
  const currentPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  UserProfile createTestProfile({String? displayName, String? picture}) {
    return UserProfile(
      pubkey: otherPubkey,
      displayName: displayName,
      picture: picture,
      rawData: const {},
      createdAt: now,
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
  }

  DmConversation createTestConversation({bool isRead = true}) {
    return DmConversation(
      id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      participantPubkeys: const [currentPubkey, otherPubkey],
      isGroup: false,
      createdAt: nowUnix,
      lastMessageContent: 'Hello',
      lastMessageTimestamp: nowUnix,
      isRead: isRead,
    );
  }

  group(RequestTile, () {
    group('renders', () {
      testWidgets('renders $UserAvatar', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders display name from profile', (tester) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
      });

      testWidgets('always renders "Sent a message request" subtitle', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sent a message request'), findsOneWidget);
        // Should NOT show the actual message content
        expect(find.text('Hello'), findsNothing);
      });

      testWidgets('renders unread dot when conversation is unread', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation(isRead: false);

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find 8x8 red circle (unread dot)
        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        final testProfile = createTestProfile(displayName: 'Alice');
        final testConversation = createTestConversation();

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: testConversation,
                currentUserPubkey: currentPubkey,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(RequestTile));

        expect(tapped, isTrue);
      });
    });

    // #6416. Moderation recognition reached only the inbox list, so an
    // enforcement notice that arrived inbound-first — the normal shape for an
    // automated notice — rendered here as an unidentified stranger with
    // "Decline and remove" beside it. Neither key has a kind-0 the app can
    // read, so the profile is always null and the name was always generated.
    group('moderation identity', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      Future<void> pumpTileFor(
        WidgetTester tester,
        String counterparty, {
        VoidCallback? onDismiss,
      }) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                counterparty,
              ).overrideWith((ref) => Stream.value(null)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: DmConversation(
                  id:
                      'dddddddddddddddddddddddddddddddddddddddddddddddddd'
                      'dddddddddddddd',
                  participantPubkeys: [currentPubkey, counterparty],
                  isGroup: false,
                  createdAt: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
                onDismiss: onDismiss,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder lockFinder() => find.byWidgetPredicate(
        (widget) =>
            widget is DivineIcon && widget.icon == DivineIconName.lockSimple,
        description: 'closed-thread lock',
      );

      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      testWidgets('a retired moderation request is named and badged', (
        tester,
      ) async {
        final retired = kLegacyModerationPubkeys.first;

        await pumpTileFor(tester, retired);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
        expect(find.text(l10n.inboxRequestTileSubtitle), findsNothing);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(retired)),
          findsNothing,
        );
        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('a retired moderation request is marked closed', (
        tester,
      ) async {
        // Same shape as the inbox row: the request list also names a retired
        // key "Divine Moderation" beside the same wordmark, so the closed
        // sentence needs the same status affordance on both surfaces or a
        // thread reads as dead in one list and live in the other (#7847).
        await pumpTileFor(tester, kLegacyModerationPubkeys.first);

        expect(lockFinder(), findsOneWidget);
      });

      // #10151. A room send is refused whole when any member is, so a room
      // that includes a retired key is closed wherever that member sorts.
      testWidgets('a group with a retired moderation member is marked closed', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(null)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: DmConversation(
                  id: 'e' * 64,
                  participantPubkeys: [
                    currentPubkey,
                    otherPubkey,
                    kLegacyModerationPubkeys.first,
                  ],
                  isGroup: true,
                  createdAt: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(lockFinder(), findsOneWidget);
      });

      // #10151. A room's members are whoever its author listed, so a room is
      // never named for the moderation account in it, even in production,
      // where that account's own profile carries Divine's name.
      testWidgets('a room that includes the moderation account is named for '
          'another member', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(kModerationPubkeyHex).overrideWith(
                (ref) => Stream.value(
                  UserProfile(
                    pubkey: kModerationPubkeyHex,
                    displayName: l10n.inboxSupportRowTitle,
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId: 'f' * 64,
                  ),
                ),
              ),
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(null)),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: DmConversation(
                  id: 'e' * 64,
                  participantPubkeys: const [
                    currentPubkey,
                    kModerationPubkeyHex,
                    otherPubkey,
                  ],
                  isGroup: true,
                  createdAt: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            l10n.inboxGroupConversationTitle(
              UserProfile.defaultDisplayNameFor(otherPubkey),
              1,
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(l10n.inboxSupportRowTitle), findsNothing);
      });

      testWidgets('a live moderation request carries no lock', (tester) async {
        await pumpTileFor(tester, kModerationPubkeyHex);

        expect(lockFinder(), findsNothing);
      });

      testWidgets('an ordinary request carries no lock', (tester) async {
        await pumpTileFor(tester, otherPubkey);

        expect(lockFinder(), findsNothing);
      });

      testWidgets('the current moderation key is named and badged too', (
        tester,
      ) async {
        await pumpTileFor(tester, kModerationPubkeyHex);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(wordmarkFinder(), findsOneWidget);
      });

      // Like removal, dismissal is withheld from a moderation notice.
      testWidgets('a retired moderation request offers no Dismiss', (
        tester,
      ) async {
        await pumpTileFor(
          tester,
          kLegacyModerationPubkeys.first,
          onDismiss: () {},
        );

        expect(find.text(l10n.inboxRequestDismiss), findsNothing);
      });

      testWidgets('an ordinary request offers Dismiss', (tester) async {
        await pumpTileFor(tester, otherPubkey, onDismiss: () {});

        expect(find.text(l10n.inboxRequestDismiss), findsOneWidget);
      });

      testWidgets('an ordinary request is untouched', (tester) async {
        await pumpTileFor(tester, otherPubkey);

        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsOneWidget,
        );
        expect(wordmarkFinder(), findsNothing);
      });
    });

    // Official branding follows recorded custody (#9963). The closed-thread
    // line is a safety behavior and holds for every custody.
    group('a retired moderation key, by recorded custody (#9963)', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final retired = shippedRetiredKey;

      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      Future<void> pumpTileFor(
        WidgetTester tester,
        RetiredKeyCustody custody,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              retiredKeyCustody(custody),
              // The key's holder controls its kind-0, so the test gives it one
              // that tries to look official.
              userProfileReactiveProvider(retired).overrideWith(
                (ref) => Stream.value(
                  UserProfile(
                    pubkey: retired,
                    displayName: 'Looks Official',
                    picture: 'https://example.invalid/looks-official.png',
                    rawData: const {},
                    createdAt: now,
                    eventId: 'c' * 64,
                  ),
                ),
              ),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: DmConversation(
                  id: 'd' * 64,
                  participantPubkeys: [currentPubkey, retired],
                  isGroup: false,
                  createdAt: nowUnix,
                ),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final custody in keptCustodies) {
        testWidgets("${custody.name}: keeps Divine's name and wordmark", (
          tester,
        ) async {
          await pumpTileFor(tester, custody);

          expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
          expect(wordmarkFinder(), findsOneWidget);
          expect(find.text(l10n.dmFormerModerationAccountName), findsNothing);
        });
      }

      for (final custody in withdrawnCustodies) {
        testWidgets('${custody.name}: neutral label, no wordmark, no picture', (
          tester,
        ) async {
          await pumpTileFor(tester, custody);

          expect(find.text(l10n.dmFormerModerationAccountName), findsOneWidget);
          expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
          expect(find.text('Looks Official'), findsNothing);
          expect(wordmarkFinder(), findsNothing);
          expect(
            tester.widget<UserAvatar>(find.byType(UserAvatar)).imageUrl,
            isNull,
          );
        });
      }

      for (final custody in RetiredKeyCustody.values) {
        testWidgets('${custody.name}: the request still reads as closed', (
          tester,
        ) async {
          await pumpTileFor(tester, custody);

          expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
          expect(find.text(l10n.inboxRequestTileSubtitle), findsNothing);
        });
      }
    });

    // `DmRepository.classifyPotentialRequests` routes an unfollowed thread
    // here "1:1 or group alike", so a group reaches this list and the row has
    // to name the room rather than whichever member sorts first.
    group('group conversations', () {
      const third =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

      DmConversation groupConversation({String? subject}) => DmConversation(
        id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        participantPubkeys: const [currentPubkey, otherPubkey, third],
        isGroup: true,
        createdAt: nowUnix,
        subject: subject,
        lastMessageContent: 'Anyone free on Saturday?',
        lastMessageTimestamp: nowUnix,
      );

      Future<void> pumpTile(
        WidgetTester tester,
        DmConversation conversation, {
        List<Override> extraOverrides = const [],
      }) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith(
                (ref) => Stream.value(
                  createTestProfile(
                    displayName: 'Alice',
                  ),
                ),
              ),
              ...extraOverrides,
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: conversation,
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('renders the NIP-17 subject when the room has one', (
        tester,
      ) async {
        await pumpTile(tester, groupConversation(subject: 'Weekend trip'));

        expect(find.text('Weekend trip'), findsOneWidget);
        expect(find.text('Alice'), findsNothing);
      });

      testWidgets('names an untitled room for who is in it', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await pumpTile(tester, groupConversation());

        expect(
          find.text(l10n.inboxGroupConversationTitle('Alice', 1)),
          findsOneWidget,
        );
      });

      testWidgets('leaves a 1:1 row naming its peer', (tester) async {
        await pumpTile(tester, createTestConversation());

        expect(find.text('Alice'), findsOneWidget);
      });

      // #10150. A request normally cannot hold a hidden member, but the row
      // follows the viewer's lists as they change, like every other title.
      testWidgets('names an untitled room for a member the viewer has not '
          'blocked', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final blocklist = ContentBlocklistRepository();
        addTearDown(blocklist.dispose);
        await tester.runAsync(
          () => blocklist.blockUsers([otherPubkey], ourPubkey: currentPubkey),
        );
        expect(blocklist.isBlocked(otherPubkey), isTrue);

        await pumpTile(
          tester,
          groupConversation(),
          extraOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
            userProfileReactiveProvider(third).overrideWith(
              (ref) => Stream.value(
                UserProfile(
                  pubkey: third,
                  displayName: 'Bob',
                  rawData: const {},
                  createdAt: now,
                  eventId: 'c' * 64,
                ),
              ),
            ),
          ],
        );

        expect(
          find.text(l10n.inboxGroupConversationTitle('Bob', 1)),
          findsOneWidget,
        );
        expect(find.textContaining('Alice'), findsNothing);
      });
    });

    group('deleted accounts', () {
      Future<void> pumpTile(
        WidgetTester tester, {
        required bool vanished,
        String? picture,
        Locale? locale,
      }) async {
        await tester.pumpWidget(
          testMaterialApp(
            locale: locale,
            additionalOverrides: [
              userProfileReactiveProvider(otherPubkey).overrideWith(
                (ref) => Stream.value(
                  createTestProfile(displayName: 'Alice', picture: picture),
                ),
              ),
              profileVanishedProvider(
                otherPubkey,
              ).overrideWith((ref) => vanished),
            ],
            home: Scaffold(
              body: RequestTile(
                conversation: createTestConversation(),
                currentUserPubkey: currentPubkey,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('names a vanished requester for the state, not a handle', (
        tester,
      ) async {
        await pumpTile(
          tester,
          vanished: true,
          picture: 'https://example.com/alice.jpg',
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        // The vanish evicts the cached profile, so without the check this row
        // renders a generated "Adjective Animal N" the viewer has never seen.
        expect(
          find.text(UserProfile.defaultDisplayNameFor(otherPubkey)),
          findsNothing,
        );
        expect(find.text('Alice'), findsNothing);
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).imageUrl,
          isNull,
        );
      });

      testWidgets('reads the deleted-account copy from l10n', (tester) async {
        await pumpTile(tester, vanished: true, locale: const Locale('de'));

        final de = lookupAppLocalizations(const Locale('de'));
        expect(find.text(de.profileDeletedAccountName), findsOneWidget);
      });

      testWidgets('leaves a live requester untouched', (tester) async {
        await pumpTile(tester, vanished: false);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text(l10n.profileDeletedAccountName), findsNothing);
      });
    });
  });
}
