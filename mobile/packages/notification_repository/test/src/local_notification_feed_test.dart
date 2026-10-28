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
  group('$NotificationRepository with a local source', () {
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
    late _Api api;
    late _Dao dao;
    late _Local local;
    late BehaviorSubject<List<NotificationItem>> snapshots;
    late NotificationRepository repository;

    setUpAll(() {
      registerFallbackValue(<NotificationCacheRow>[]);
    });

    setUp(() {
      api = _Api();
      dao = _Dao();
      local = _Local();
      snapshots = BehaviorSubject<List<NotificationItem>>.seeded([row]);
      when(local.watchSnapshot).thenAnswer((_) => snapshots.stream);
      when(() => local.items).thenAnswer((_) => snapshots.value);
      when(() => local.markSeen(any())).thenAnswer((_) async {
        snapshots.add([row.copyWith(isRead: true)]);
      });
      when(local.refresh).thenAnswer((_) async {});
      repository = NotificationRepository(
        funnelcakeApiClient: api,
        profileRepository: _Profiles(),
        notificationsDao: dao,
        userPubkey: 'a' * 64,
        localNotifications: local,
        hydrateOnStart: false,
      );
      addTearDown(() async {
        await repository.close();
        await snapshots.close();
      });
    });

    group('watchSnapshot', () {
      test('joins the unfiltered and mention feeds and no other', () async {
        final merged = (await repository.watchSnapshot().first).items;
        expect(merged, [row]);
        expect((merged.single as ActorNotification).chatTarget, row.chatTarget);
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
      });

      test('a subscriber sees a local change without a social emit', () {
        final reads = repository.watchSnapshot().map(
          (page) => [for (final item in page.items) item.isRead],
        );
        final expectation = expectLater(
          reads,
          emitsInOrder([
            [false],
            [true],
          ]),
        );
        snapshots.add([row.copyWith(isRead: true)]);
        return expectation;
      });

      test('rows sharing a timestamp keep a stable id order', () async {
        final rows = [
          for (var i = 39; i >= 0; i--)
            row.copyWith(id: 'chat:general:${i.toString().padLeft(64, '0')}'),
        ];
        snapshots.add(rows);
        final merged = (await repository.watchSnapshot().first).items;
        expect(
          merged.map((item) => item.id),
          [for (final item in rows.reversed) item.id],
        );
      });
    });

    group('markAsRead', () {
      test('sends chat ids to the local source and never to the API', () async {
        await repository.markAsRead([row.id]);
        verify(() => local.markSeen([row.id])).called(1);
        expect(await repository.watchUnreadCount().first, 0);
        verifyZeroInteractions(api);
      });
    });

    group('markAllAsRead', () {
      test('marks the local rows shown at call time', () async {
        when(
          () => api.notificationsReadUri(pubkey: any(named: 'pubkey')),
        ).thenReturn(Uri.parse('https://api.test/notifications/read'));
        when(
          () => api.markNotificationsRead(
            pubkey: any(named: 'pubkey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 0),
        );
        when(
          () => dao.markAllAsRead(ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async => 0);
        await repository.markAllAsRead();
        verify(() => local.markSeen([row.id])).called(1);
      });
    });

    group('refreshFeed', () {
      setUp(() {
        when(
          () => api.notificationsUri(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            types: any(named: 'types'),
          ),
        ).thenReturn(Uri.parse('https://api.test/notifications'));
        when(
          () => api.getNotifications(
            pubkey: any(named: 'pubkey'),
            cursor: any(named: 'cursor'),
            cursorId: any(named: 'cursorId'),
            types: any(named: 'types'),
            requestUri: any(named: 'requestUri'),
            authHeaders: any(named: 'authHeaders'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => const NotificationResponse(
            notifications: [],
            unreadCount: 0,
            hasMore: false,
          ),
        );
        when(
          () => dao.replaceAll(any(), ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async {});
      });

      test('retries the local source on a full refresh', () async {
        await repository.refreshFeed(null);
        verify(local.refresh).called(1);
      });

      test(
        'a failing local refresh does not fail the social refresh',
        () async {
          when(
            local.refresh,
          ).thenAnswer((_) async => throw StateError('broken'));
          await expectLater(
            repository.refreshFeed(null),
            completion(isA<NotificationPage>()),
          );
          verify(local.refresh).called(1);
        },
      );

      test('a filtered refresh leaves the local source alone', () async {
        await repository.refreshFeed(NotificationKind.like);
        verifyNever(local.refresh);
      });
    });
  });
}
