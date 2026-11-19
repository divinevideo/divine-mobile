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
    late Completer<void> refresh;
    late List<AnnouncementNotification>? catalog;

    setUp(() {
      catalog = null;
      refresh = Completer<void>();
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
        refresh.complete();

        expect((await hydrated).announcement, item);
      },
    );

    test('a failed cold refresh cannot confirm absence', () async {
      final cubit = watchAnnouncement();
      expect(cubit.state.status, AnnouncementDetailStatus.loading);
      final failed = cubit.stream.first;
      snapshots.add(const []);
      refresh.complete();

      expect((await failed).status, AnnouncementDetailStatus.failed);
    });

    test(
      'keeps the current item while refreshing and clears it on withdrawal',
      () async {
        catalog = [item];
        final cubit = watchAnnouncement();
        expect(cubit.state.announcement, item);

        refresh.complete();
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

    test('a different ID cannot supply the detail', () async {
      catalog = [item];
      final cubit = watchAnnouncement(
        id: '60b328b6-4390-47c1-9f45-43738f2bd790',
      );
      expect(cubit.state.status, AnnouncementDetailStatus.unavailable);
      expect(cubit.state.announcement, isNull);
      refresh.complete();
    });
  });
}
