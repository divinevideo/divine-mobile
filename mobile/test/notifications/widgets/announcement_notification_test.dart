import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_list_item.dart';

void main() {
  group('official announcement row', () {
    testWidgets('shows the official message and opens it on tap', (
      tester,
    ) async {
      var opened = false;
      final announcement = AnnouncementNotification(
        announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
        title: 'Your profile has a home',
        body: 'Open your profile to find your own Divine website.',
        timestamp: DateTime.utc(2026, 10, 23),
        expiresAt: DateTime.utc(2026, 11, 23),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NotificationListItem(
              notification: announcement,
              onTap: () => opened = true,
            ),
          ),
        ),
      );

      expect(find.text('From Divine'), findsOneWidget);
      expect(find.text('Your profile has a home'), findsOneWidget);
      expect(
        find.text('Open your profile to find your own Divine website.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Your profile has a home'));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('does not brand an arbitrary system row as official', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NotificationListItem(
              notification: ActorNotification(
                id: 'social-system',
                type: NotificationKind.system,
                actor: const ActorInfo(
                  pubkey: '1111111111111111111111111111111111111111111111111111111111111111',
                  displayName: 'Divine',
                ),
                timestamp: DateTime.utc(2026, 10, 23),
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('From Divine'), findsNothing);
    });

    for (final isRead in [false, true]) {
      testWidgets('exposes unread status accessibly when read=$isRead', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        addTearDown(semantics.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: NotificationListItem(
                notification: AnnouncementNotification(
                  announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
                  title: 'A small update',
                  body: 'Your website is ready.',
                  timestamp: DateTime.utc(2026, 10, 23),
                  expiresAt: DateTime.utc(2026, 11, 23),
                  isRead: isRead,
                ),
                onTap: () {},
              ),
            ),
          ),
        );
        expect(
          find.bySemanticsLabel(RegExp('Unread notification')),
          isRead ? findsNothing : findsOneWidget,
        );
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('fits large text in ${brightness.name} appearance', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? VineTheme.theme
                : VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: NotificationListItem(
                  notification: AnnouncementNotification(
                    announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
                    title: 'A useful update for everyone creating on Divine',
                    body: 'Open the full message to learn what has changed.',
                    timestamp: DateTime.utc(2026, 10, 23),
                    expiresAt: DateTime.utc(2026, 11, 23),
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('From Divine'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
