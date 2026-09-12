// ABOUTME: Tests for NotificationListItem dispatcher — verifies the
// ABOUTME: correct row widget is rendered for each NotificationItem subtype.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';
import 'package:openvine/notifications/widgets/notification_list_item.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

const _alice = ActorInfo(
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: 'Alice',
);

VideoNotification _video({
  bool isRead = false,
}) {
  return VideoNotification(
    id: 'v1',
    type: NotificationKind.like,
    videoEventId:
        '1111111111111111111111111111111111111111111111111111111111111111',
    actors: const [_alice],
    totalCount: 1,
    timestamp: DateTime.utc(2026, 5, 4, 12),
    isRead: isRead,
  );
}

ActorNotification _actor({
  NotificationKind type = NotificationKind.follow,
  bool isRead = false,
}) {
  return ActorNotification(
    id: 'a1',
    type: type,
    actor: _alice,
    timestamp: DateTime.utc(2026, 5, 4, 12),
    isRead: isRead,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required NotificationItem notification,
  VoidCallback? onTap,
  VoidCallback? onProfileTap,
  VoidCallback? onFollowBack,
  VoidCallback? onThumbnailTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NotificationListItem(
          notification: notification,
          onTap: onTap ?? () {},
          onProfileTap: onProfileTap,
          onFollowBack: onFollowBack,
          onThumbnailTap: onThumbnailTap,
        ),
      ),
    ),
  );
}

void main() {
  group(NotificationListItem, () {
    group('dispatch', () {
      testWidgets('renders $VideoNotificationRow for $VideoNotification', (
        tester,
      ) async {
        await _pump(tester, notification: _video());

        expect(find.byType(VideoNotificationRow), findsOneWidget);
        expect(find.byType(ActorNotificationRow), findsNothing);
      });

      testWidgets('renders $ActorNotificationRow for $ActorNotification', (
        tester,
      ) async {
        await _pump(tester, notification: _actor());

        expect(find.byType(ActorNotificationRow), findsOneWidget);
        expect(find.byType(VideoNotificationRow), findsNothing);
      });
    });

    group('callback wiring', () {
      testWidgets('row tap on video forwards onTap', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _video(),
          onTap: () => tapped = true,
        );

        await tester.tap(find.byType(VideoNotificationRow));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('row tap on actor forwards onTap', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _actor(type: NotificationKind.mention),
          onTap: () => tapped = true,
        );

        await tester.tap(find.byType(ActorNotificationRow));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('Follow back tap on follow forwards onFollowBack', (
        tester,
      ) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _actor(),
          onFollowBack: () => tapped = true,
        );

        await tester.tap(find.text(_l10n.notificationFollowBack));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  });
}
