import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:rxdart/rxdart.dart' hide NotificationKind;
import 'package:test/test.dart';

class _Api extends Mock implements FunnelcakeApiClient {}

class _Profiles extends Mock implements ProfileRepository {}

class _Dao extends Mock implements NotificationsDao {}

class _Local extends Mock implements LocalNotificationSource {}

void main() {
  group('watchSnapshot', () {
    test(
      'local mentions join feeds and reads stay local',
      () async {
        final api = _Api();
        final local = _Local();
        final row = ActorNotification(
          id: 'chat:general:${'b' * 64}',
          type: NotificationKind.mention,
          actor: ActorInfo(pubkey: 'b' * 64, displayName: 'Friend'),
          timestamp: DateTime.utc(2026),
          chatTarget: const ChatNotificationTarget(
            communityId: 'community-test',
            channelId: 'general',
          ),
        );
        final snapshots = BehaviorSubject<List<NotificationItem>>.seeded([row]);
        when(local.watchSnapshot).thenAnswer((_) => snapshots.stream);
        when(() => local.items).thenAnswer((_) => snapshots.value);
        when(() => local.markSeen(any())).thenAnswer((_) async {
          snapshots.add([row.copyWith(isRead: true)]);
        });
        final repository = NotificationRepository(
          funnelcakeApiClient: api,
          profileRepository: _Profiles(),
          notificationsDao: _Dao(),
          userPubkey: 'a' * 64,
          localNotifications: local,
          hydrateOnStart: false,
        );
        addTearDown(() async {
          await repository.close();
          await snapshots.close();
        });
        expect((await repository.watchSnapshot().first).items, [row]);
        expect(await repository.watchUnreadCount().first, 1);
        expect(
          (await repository
                  .watchSnapshot(filter: NotificationKind.mention)
                  .first)
              .items,
          [row],
        );
        expect(
          (await repository.watchSnapshot(filter: NotificationKind.like).first)
              .items,
          isEmpty,
        );
        await repository.markAsRead([row.id]);
        expect(await repository.watchUnreadCount().first, 0);
        expect(
          (snapshots.value.single as ActorNotification).chatTarget,
          row.chatTarget,
        );
        verify(() => local.markSeen([row.id])).called(1);
        verifyZeroInteractions(api);
      },
    );
  });
}
