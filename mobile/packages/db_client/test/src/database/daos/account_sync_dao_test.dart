import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
  tearDown(() => db.close());
  group('writeNotificationReads', () {
    test(
      'acknowledged overlay shrinks with cache, pending intent never does',
      () async {
        final dao = db.accountSyncDao;
        await dao.writeNotificationReads(
          'a',
          {'old', 'queued', 'cached'},
          {'queued'},
          {
            'group': ['cached'],
          },
        );
        expect(
          (await dao.readNotificationReads('a')).map((r) => r.notificationId),
          unorderedEquals(['queued', 'cached']),
        );
        await dao.writeNotificationReads(
          'a',
          {'queued', 'cached'},
          {'queued'},
          {},
        );
        expect(
          (await dao.readNotificationReads('a')).map((r) => r.notificationId),
          ['queued'],
        );
        expect(await dao.readNotificationMembers('a'), isEmpty);
        await dao.writeNotificationReads('a', {'queued'}, {}, {});
        expect(await dao.readNotificationReads('a'), isEmpty);
      },
    );
  });

  group('clearAccount', () {
    test('structured state and erasure are owner/namespace scoped', () async {
      final dao = db.accountSyncDao;
      await dao.writeState('a', 'dm', {
        'entries': {'tuple': 'null'},
        'events': {'event': 'signed'},
      });
      await dao.writeState('b', 'dm', {
        'entries': {'tuple': 'keep'},
      });
      await dao.writeState('a', 'preferences', {
        'entries': {'key': 'keep'},
      });
      await dao.writeState('a', 'dm', {
        'entries': {'tuple': 'null'},
      });
      expect((await dao.readState('a', 'dm')).single.value, 'null');
      await dao.writeNotificationReads('a', {'queued'}, {'queued'}, {
        'group': ['queued'],
      });
      await dao.clearAccount('a');
      expect(await dao.readState('a', 'dm'), isEmpty);
      expect(await dao.readState('a', 'preferences'), isEmpty);
      expect(await dao.readNotificationReads('a'), isEmpty);
      expect(await dao.readNotificationMembers('a'), isEmpty);
      expect((await dao.readState('b', 'dm')).single.value, 'keep');
    });
  });
}
