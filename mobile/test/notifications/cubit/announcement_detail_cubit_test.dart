import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/cubit/announcement_detail_cubit.dart';

class _MockAnnouncementsRepository extends Mock
    implements AnnouncementsRepository {}

void main() {
  final item = AnnouncementNotification(
    announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
    title: 'A small update',
    body: 'The app has a new release.',
    timestamp: DateTime.utc(2026, 10, 23),
    expiresAt: DateTime.utc(2026, 11, 23),
  );

  group('AnnouncementDetailCubit snapshots', () {
    late _MockAnnouncementsRepository repository;
    late StreamController<List<AnnouncementNotification>> snapshots;
    late Completer<bool> refresh;
    late List<AnnouncementNotification>? catalog;

    setUp(() {
      catalog = null;
      refresh = Completer<bool>();
      repository = _MockAnnouncementsRepository();
      snapshots = StreamController<List<AnnouncementNotification>>();
      when(() => repository.hasCatalog).thenAnswer((_) => catalog != null);
      when(() => repository.items).thenAnswer((_) => catalog ?? const []);
      when(repository.watchSnapshot).thenAnswer((_) => snapshots.stream);
      when(repository.refresh).thenAnswer((_) => refresh.future);
      addTearDown(snapshots.close);
    });

    AnnouncementDetailCubit watchAnnouncement({String? id}) {
      final cubit = AnnouncementDetailCubit(
        announcementId: id ?? item.announcementId,
        repository: repository,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test(
      'cold hydration waits for a catalog and resolves the requested item',
      () async {
        final cubit = watchAnnouncement();
        expect(cubit.state.status, AnnouncementDetailStatus.loading);
        verify(repository.refresh).called(1);
        final hydrated = cubit.stream.first;
        catalog = [item];
        snapshots.add([item]);
        refresh.complete(true);

        expect((await hydrated).announcement, item);
      },
    );

    test('a failed cold refresh cannot confirm absence', () async {
      final cubit = watchAnnouncement();
      expect(cubit.state.status, AnnouncementDetailStatus.loading);
      final failed = cubit.stream.first;
      snapshots.add(const []);
      refresh.complete(false);

      expect((await failed).status, AnnouncementDetailStatus.failed);
    });

    test(
      'keeps the current item while refreshing and clears it on withdrawal',
      () async {
        catalog = [item];
        final cubit = watchAnnouncement();
        expect(cubit.state.announcement, item);

        refresh.complete(true);
        await pumpEventQueue();
        expect(cubit.state.status, AnnouncementDetailStatus.ready);
        expect(cubit.state.announcement, item);

        final withdrawn = cubit.stream.first;
        catalog = const [];
        snapshots.add(const []);
        expect((await withdrawn).status, AnnouncementDetailStatus.unavailable);
        expect(cubit.state.announcement, isNull);
      },
    );

    group('a cached catalog without the announcement', () {
      const otherId = '60b328b6-4390-47c1-9f45-43738f2bd790';

      test('waits for the endpoint instead of reporting withdrawal', () async {
        catalog = [item];
        final cubit = watchAnnouncement(id: otherId);
        expect(cubit.state.status, AnnouncementDetailStatus.loading);

        snapshots.add([item]);
        await pumpEventQueue();
        expect(cubit.state.status, AnnouncementDetailStatus.loading);
        expect(cubit.state.announcement, isNull);
        refresh.complete(true);
      });

      test('reports withdrawal once the endpoint answers without it', () async {
        catalog = [item];
        final cubit = watchAnnouncement(id: otherId);
        final answered = cubit.stream.first;
        refresh.complete(true);

        expect((await answered).status, AnnouncementDetailStatus.unavailable);
        expect(cubit.state.announcement, isNull);
      });

      test(
        'reports a failed lookup when the endpoint does not answer',
        () async {
          catalog = [item];
          final cubit = watchAnnouncement(id: otherId);
          final failed = cubit.stream.first;
          snapshots.add([item]);
          refresh.complete(false);

          expect((await failed).status, AnnouncementDetailStatus.failed);
          await pumpEventQueue();
          expect(cubit.state.status, AnnouncementDetailStatus.failed);
        },
      );
    });

    test(
      'an announcement that expires while shown is unavailable even when the '
      'refresh fails',
      () async {
        catalog = [item];
        final cubit = watchAnnouncement();
        expect(cubit.state.status, AnnouncementDetailStatus.ready);

        final expired = cubit.stream.first;
        catalog = const [];
        refresh.complete(false);

        expect((await expired).status, AnnouncementDetailStatus.unavailable);
      },
    );
  });
}
