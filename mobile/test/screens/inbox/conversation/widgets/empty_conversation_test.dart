import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/empty_conversation.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(EmptyConversation, () {
    group('renders', () {
      testWidgets('renders $UserAvatar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders display name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(find.text('Bob'), findsOneWidget);
      });

      testWidgets('renders nip05 when provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                nip05: 'bob@example.com',
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(find.text('bob@example.com'), findsOneWidget);
      });

      testWidgets('does not render nip05 when null', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                onViewProfile: () {},
              ),
            ),
          ),
        );

        // Only two Text widgets: display name and "View profile"
        expect(find.byType(Text), findsNWidgets(2));
      });

      testWidgets('renders "View profile" button text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(find.text('View profile'), findsOneWidget);
      });

      testWidgets('does not render "View profile" when onViewProfile is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
              ),
            ),
          ),
        );

        expect(
          find.text(l10n.inboxConversationViewProfileButton),
          findsNothing,
        );
      });

      testWidgets('announces loading instead of the placeholder identity', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Generated Name',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                isIdentityResolving: true,
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Loading'), findsOneWidget);
        expect(find.bySemanticsLabel('Generated Name'), findsNothing);
        semantics.dispose();
      });
    });

    group('interactions', () {
      testWidgets('calls onViewProfile when View profile is tapped', (
        tester,
      ) async {
        var wasCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                onViewProfile: () => wasCalled = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('View profile'));
        await tester.pump();

        expect(wasCalled, isTrue);
      });
    });

    group('accessibility', () {
      testWidgets('exposes "View profile" as a button', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                pubkey: 'pk1',
                moderation: ModerationPresentation.ordinary,
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(
          tester.getSemantics(
            find.text(l10n.inboxConversationViewProfileButton),
          ),
          isSemantics(
            label: l10n.inboxConversationViewProfileButton,
            isButton: true,
          ),
        );
        handle.dispose();
      });
    });

    // Caught on device (#6416): opening the moderation thread before it has
    // any messages showed the generic orange placeholder, because this card
    // renders its own avatar rather than the one the tile and header use.
    group('moderation identity', () {
      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      Future<void> pumpFor(
        WidgetTester tester,
        String pubkey, {
        required ModerationPresentation moderation,
        String? imageUrl,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Divine Moderation',
                pubkey: pubkey,
                moderation: moderation,
                imageUrl: imageUrl,
                onViewProfile: () {},
              ),
            ),
          ),
        );
      }

      testWidgets('the current moderation key gets the wordmark', (
        tester,
      ) async {
        await pumpFor(
          tester,
          kModerationPubkeyHex,
          moderation: moderationPresentationOf(kModerationPubkeyHex),
        );

        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('the shipped retired key gets it too', (tester) async {
        final retired = kLegacyModerationPubkeys.first;
        await pumpFor(
          tester,
          retired,
          moderation: moderationPresentationOf(retired),
        );

        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('an ordinary account keeps the generated placeholder', (
        tester,
      ) async {
        await pumpFor(
          tester,
          'b' * 64,
          moderation: ModerationPresentation.ordinary,
        );

        expect(wordmarkFinder(), findsNothing);
      });

      // Official branding follows recorded custody (#9963), and a withdrawn key
      // also loses its own picture: its holder chooses what that shows.
      for (final custody in RetiredKeyCustody.values) {
        final key = 'c' * 64;
        final presentation = moderationPresentationOf(
          key,
          retiredKeys: [RetiredModerationKey(pubkeyHex: key, custody: custody)],
        );

        if (custody.canStillSign) {
          testWidgets('a ${custody.name} key gets no wordmark and no picture', (
            tester,
          ) async {
            await pumpFor(
              tester,
              key,
              moderation: presentation,
              imageUrl: 'https://example.invalid/looks-official.png',
            );

            expect(wordmarkFinder(), findsNothing);
            final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
            expect(avatar.imageUrl, isNull);
            expect(avatar.contentOverride, isNull);
          });
        } else {
          testWidgets('a ${custody.name} key keeps the wordmark', (
            tester,
          ) async {
            await pumpFor(tester, key, moderation: presentation);

            expect(wordmarkFinder(), findsOneWidget);
          });
        }
      }
    });

    // A group thread is titled for the room, and `pubkey` is then whichever
    // member sorted first — so the card must not put that member's face,
    // NIP-05 or profile link under the room's name.
    group('group conversations', () {
      const firstMember =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const firstMemberNip05 = 'first@example.com';

      Finder groupAvatarFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.users,
        description: 'group avatar',
      );

      Future<void> pumpCard(WidgetTester tester, EmptyConversation card) {
        return tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: card),
          ),
        );
      }

      testWidgets('shows the group avatar under the room name', (
        tester,
      ) async {
        await pumpCard(
          tester,
          const EmptyConversation(
            displayName: 'Weekend trip',
            pubkey: firstMember,
            moderation: ModerationPresentation.ordinary,
            isGroup: true,
          ),
        );

        expect(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: groupAvatarFinder(),
          ),
          findsOneWidget,
        );
        expect(find.text('Weekend trip'), findsOneWidget);
      });

      testWidgets('keeps the group avatar when the first member is the '
          'moderation account', (tester) async {
        await pumpCard(
          tester,
          const EmptyConversation(
            displayName: 'Weekend trip',
            pubkey: kModerationPubkeyHex,
            // What a one-to-one with this key gets the wordmark for.
            moderation: ModerationPresentation.official,
            isGroup: true,
          ),
        );

        expect(groupAvatarFinder(), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.logo,
          ),
          findsNothing,
        );
      });

      // The conversation view threads the first counterparty's details for
      // every thread, so leaving them off a room's card is the card's job.
      testWidgets('shows nothing of a single member, even when handed their '
          'details', (tester) async {
        await pumpCard(
          tester,
          EmptyConversation(
            displayName: 'Weekend trip',
            pubkey: firstMember,
            moderation: ModerationPresentation.ordinary,
            isGroup: true,
            imageUrl: 'https://example.com/first-member.jpg',
            nip05: firstMemberNip05,
            onViewProfile: () {},
          ),
        );

        expect(groupAvatarFinder(), findsOneWidget);
        expect(find.text(firstMemberNip05), findsNothing);
        expect(
          find.text(l10n.inboxConversationViewProfileButton),
          findsNothing,
        );
        // Their photo would load through this.
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('a one-to-one card shows the NIP-05 and profile link it is '
          'handed', (tester) async {
        await pumpCard(
          tester,
          EmptyConversation(
            displayName: 'Bob',
            pubkey: firstMember,
            moderation: ModerationPresentation.ordinary,
            nip05: firstMemberNip05,
            onViewProfile: () {},
          ),
        );

        expect(groupAvatarFinder(), findsNothing);
        expect(find.text(firstMemberNip05), findsOneWidget);
        expect(
          find.text(l10n.inboxConversationViewProfileButton),
          findsOneWidget,
        );
      });
    });
  });
}
