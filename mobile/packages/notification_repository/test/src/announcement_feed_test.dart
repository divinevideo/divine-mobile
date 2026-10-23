// ABOUTME: Keeps official announcements separate from social cursors/writes.

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

class _Announcements extends Mock implements AnnouncementsRepository {}

void main() {
  late _Api api;
  late _Dao dao;
  late _Announcements announcements;
  late BehaviorSubject<List<AnnouncementNotification>> catalog;
  late NotificationRepository repository;
  final item = AnnouncementNotification(
    announcementId: '9cf3daa0-d982-47a9-a942-c907c223b8b5',
    title: 'Your profile has a home',
    body: 'Find your own website on your profile.',
    timestamp: DateTime.utc(2026, 10, 23),
    expiresAt: DateTime.utc(2026, 11, 23),
  );

  setUp(() {
    api = _Api();
    dao = _Dao();
    announcements = _Announcements();
    catalog = BehaviorSubject.seeded([item]);
    when(announcements.watchSnapshot).thenAnswer((_) => catalog.stream);
    when(() => announcements.items).thenAnswer((_) => catalog.value);
    when(() => announcements.markSeen(any())).thenAnswer((_) async {});
    when(announcements.refresh).thenAnswer((_) async {});
    when(announcements.close).thenAnswer((_) async {});
    repository = NotificationRepository(
      funnelcakeApiClient: api,
      profileRepository: _Profiles(),
      notificationsDao: dao,
      userPubkey:
          '45f311307ca34091492a80b694b624e780e65655de49396b6f788e09303e9f5a',
      announcementsRepository: announcements,
      hydrateOnStart: false,
    );
  });
  tearDown(() async {
    await repository.close();
    await catalog.close();
  });

  group('NotificationRepository announcement composition', () {
    test(
      'All and badge include official rows, social tabs stay separate',
      () async {
        final all = await repository.watchSnapshot().first;
        expect(all.items, [item]);
        expect(all.hasMore, isFalse);
        expect(all.nextCursor, isNull);
        expect(await repository.watchUnreadCount().first, 1);
        expect(
          (await repository.watchSnapshot(filter: NotificationKind.like).first)
              .items,
          isEmpty,
        );
        catalog.add([item.copyWith(isRead: true)]);
        expect(await repository.watchUnreadCount().first, 0);
        verifyZeroInteractions(api);
        verifyZeroInteractions(dao);
      },
    );

    test(
      'opening an announcement never signs or writes a social read marker',
      () async {
        await repository.markAsRead([item.id]);
        verify(() => announcements.markSeen([item.id])).called(1);
        verifyZeroInteractions(api);
        verifyZeroInteractions(dao);
      },
    );

    test(
      'closing the account drains its announcement repository once',
      () async {
        await repository.close();
        await repository.close();
        verify(announcements.close).called(1);
        await expectLater(repository.markAsRead([item.id]), throwsStateError);
      },
    );
  });
}
