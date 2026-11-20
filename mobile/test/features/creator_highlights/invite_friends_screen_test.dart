import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/creator_highlights/invite_friends_screen.dart';
import 'package:openvine/l10n/l10n.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('inviteShareText', () {
    test('puts the link on its own line after the message', () {
      expect(
        inviteShareText('  Hi there  ', 'https://example.com'),
        'Hi there\nhttps://example.com',
      );
    });

    test('shares only the link when the message is blank', () {
      expect(
        inviteShareText(' \n ', 'https://example.com'),
        'https://example.com',
      );
    });
  });

  group(InviteFriendsScreen, () {
    late List<Map<Object?, Object?>> shareCalls;
    late String shareResult;

    setUp(() {
      shareCalls = [];
      shareResult = 'com.apple.UIKit.activity.Message';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            if (call.method == 'share') {
              shareCalls.add(call.arguments as Map<Object?, Object?>);
            }
            return shareResult;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, null);
    });

    /// Pumps a home page and pushes the invite page over it.
    Future<void> pumpPushed(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const InviteFriendsScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> share(WidgetTester tester) async {
      await tester.tap(find.byType(DivineButton));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('starts with the default message and shows the link', (
        tester,
      ) async {
        await pumpPushed(tester);
        expect(find.text(l10n.inviteFriendsTitle), findsOneWidget);
        expect(find.text(l10n.inviteFriendsDefaultMessage), findsOneWidget);
        expect(
          find.text(l10n.inviteFriendsLinkNote(AppConstants.downloadUrl)),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('shares the edited message and the link', (tester) async {
        await pumpPushed(tester);
        await tester.enterText(find.byType(TextField), 'Join me!');
        await share(tester);
        expect(shareCalls, hasLength(1));
        expect(
          shareCalls.single['text'],
          inviteShareText('Join me!', AppConstants.downloadUrl),
        );
      });

      testWidgets('a cleared message shares only the link', (tester) async {
        await pumpPushed(tester);
        await tester.enterText(find.byType(TextField), '');
        await share(tester);
        expect(shareCalls.single['text'], AppConstants.downloadUrl);
      });
    });

    group('navigation', () {
      testWidgets('a completed share returns', (tester) async {
        await pumpPushed(tester);
        await share(tester);
        expect(find.byType(InviteFriendsScreen), findsNothing);
      });

      testWidgets('a dismissed share stays', (tester) async {
        shareResult = '';
        await pumpPushed(tester);
        await share(tester);
        expect(shareCalls, hasLength(1));
        expect(find.byType(InviteFriendsScreen), findsOneWidget);
      });
    });
  });
}
