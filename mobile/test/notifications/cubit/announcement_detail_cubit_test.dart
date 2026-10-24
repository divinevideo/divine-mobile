import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/notification_item.dart';
import 'package:openvine/notifications/cubit/announcement_detail_cubit.dart';

void main() {
  final item = AnnouncementNotification(
    announcementId: 'd7388b9c-b35c-4269-8fc5-fac5d7a454ad',
    title: 'A small update',
    body: 'Your website is ready.',
    timestamp: DateTime.utc(2026, 10, 23),
    expiresAt: DateTime.utc(2026, 11, 23),
  );

  group('AnnouncementDetailCubit snapshots', () {
    test('cold hydration resolves only the requested announcement', () async {
      final snapshots = StreamController<List<AnnouncementNotification>>();
      final cubit = AnnouncementDetailCubit(
        announcementId: item.announcementId,
        initialItems: const [],
        snapshots: snapshots.stream,
      );
      addTearDown(cubit.close);
      addTearDown(snapshots.close);
      expect(cubit.state, isNull);
      final hydrated = cubit.stream.first;
      snapshots.add([item]);
      expect(await hydrated, item);
    });

    test('withdrawal clears a detail that is already open', () async {
      final snapshots = StreamController<List<AnnouncementNotification>>();
      final cubit = AnnouncementDetailCubit(
        announcementId: item.announcementId,
        initialItems: [item],
        snapshots: snapshots.stream,
      );
      addTearDown(cubit.close);
      addTearDown(snapshots.close);
      expect(cubit.state, item);
      final withdrawn = cubit.stream.first;
      snapshots.add(const []);
      expect(await withdrawn, isNull);
    });

    test('a different ID cannot supply the detail', () async {
      final snapshots = StreamController<List<AnnouncementNotification>>();
      final cubit = AnnouncementDetailCubit(
        announcementId: '60b328b6-4390-47c1-9f45-43738f2bd790',
        initialItems: [item],
        snapshots: snapshots.stream,
      );
      addTearDown(cubit.close);
      addTearDown(snapshots.close);
      expect(cubit.state, isNull);
    });
  });
}
