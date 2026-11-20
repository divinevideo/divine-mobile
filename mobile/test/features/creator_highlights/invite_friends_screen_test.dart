import 'dart:async';

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
    // Holds the sheet open until completed, like a person choosing an app.
    Completer<String>? openSheet;
    Object? shareError;

    setUp(() {
      shareCalls = [];
      shareResult = 'com.apple.UIKit.activity.Message';
      openSheet = null;
      shareError = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
            if (call.method != 'share') return null;
            shareCalls.add(call.arguments as Map<Object?, Object?>);
            if (shareError case final error?) throw error;
            return openSheet?.future ?? shareResult;
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

      testWidgets('a second tap while the sheet is open does not share again', (
        tester,
      ) async {
        openSheet = Completer();
        await pumpPushed(tester);
        await tester.tap(find.byType(DivineButton));
        await tester.pump();
        await tester.tap(find.byType(DivineButton), warnIfMissed: false);
        await tester.pump();
        expect(shareCalls, hasLength(1));
        openSheet!.complete('');
        await tester.pumpAndSettle();
        expect(find.byType(InviteFriendsScreen), findsOneWidget);
      });

      testWidgets('anchors the share sheet for iPad', (tester) async {
        await pumpPushed(tester);
        await share(tester);
        final call = shareCalls.single;
        for (final key in [
          'originX',
          'originY',
          'originWidth',
          'originHeight',
        ]) {
          expect(call[key], isNotNull, reason: key);
        }
        expect(call['originWidth'], greaterThan(0));
      });

      testWidgets('a share failure keeps the page open', (tester) async {
        shareError = PlatformException(code: 'Share failed');
        await pumpPushed(tester);
        await share(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(InviteFriendsScreen), findsOneWidget);
        expect(
          tester.widget<DivineButton>(find.byType(DivineButton)).onPressed,
          isNotNull,
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

      testWidgets('an unknown share outcome returns', (tester) async {
        shareResult = 'dev.fluttercommunity.plus/share/unavailable';
        await pumpPushed(tester);
        await share(tester);
        expect(find.byType(InviteFriendsScreen), findsNothing);
      });

      testWidgets('a page pushed over it while sharing is not popped', (
        tester,
      ) async {
        openSheet = Completer();
        await pumpPushed(tester);
        await tester.tap(find.byType(DivineButton));
        await tester.pump();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('over')),
              ),
            );
        await tester.pumpAndSettle();
        openSheet!.complete('com.apple.UIKit.activity.Message');
        await tester.pumpAndSettle();
        expect(find.text('over'), findsOneWidget);
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
