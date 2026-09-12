import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/empty_conversation.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
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
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(find.text('View profile'), findsOneWidget);
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

    // Caught on device (#6416): opening the moderation thread before it has
    // any messages showed the generic orange placeholder, because this card
    // renders its own avatar rather than the one the tile and header use.
    group('moderation identity', () {
      Finder wordmarkFinder() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      Future<void> pumpFor(WidgetTester tester, String pubkey) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Divine Moderation',
                pubkey: pubkey,
                onViewProfile: () {},
              ),
            ),
          ),
        );
      }

      testWidgets('the current moderation key gets the wordmark', (
        tester,
      ) async {
        await pumpFor(tester, kModerationPubkeyHex);

        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('a retired moderation key gets it too', (tester) async {
        await pumpFor(tester, kLegacyModerationPubkeys.first);

        expect(wordmarkFinder(), findsOneWidget);
      });

      testWidgets('an ordinary account keeps the generated placeholder', (
        tester,
      ) async {
        await pumpFor(tester, 'b' * 64);

        expect(wordmarkFinder(), findsNothing);
      });
    });
  });
}
