// ABOUTME: Unit tests for PendingProductEventsDao durable analytics outbox.
// ABOUTME: Covers enqueue, retry filtering, status transitions, and cleanup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingProductEventsDao dao;
  late String tempDbPath;

  PendingProductEvent makeEvent({
    required String id,
    String eventName = 'screen_time',
    PendingProductEventStatus status = PendingProductEventStatus.pending,
    int attemptCount = 0,
    DateTime? createdAt,
    DateTime? nextAttemptAt,
    String? lastError,
    String? ownerPubkey,
  }) {
    return PendingProductEvent(
      id: id,
      eventName: eventName,
      payloadJson: '{"event_id":"$id","event_name":"$eventName"}',
      status: status,
      attemptCount: attemptCount,
      createdAt: createdAt ?? DateTime.utc(2026, 7),
      nextAttemptAt: nextAttemptAt,
      lastError: lastError,
      ownerPubkey: ownerPubkey,
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'pending_product_events_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingProductEventsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('PendingProductEventsDao', () {
    test('inserts a pending product event with idempotency id', () async {
      await dao.enqueue(makeEvent(id: 'event-a'));

      final fetched = await dao.getById('event-a');

      expect(fetched, isNotNull);
      expect(fetched!.id, 'event-a');
      expect(fetched.eventName, 'screen_time');
      expect(fetched.payloadJson, contains('"event_id":"event-a"'));
      expect(fetched.status, PendingProductEventStatus.pending);
      expect(fetched.attemptCount, 0);
      expect(fetched.nextAttemptAt, isNull);
      expect(fetched.lastError, isNull);
    });

    test('re-enqueueing the same event id preserves delivery state', () async {
      await dao.enqueue(makeEvent(id: 'event-a'));
      await dao.markPublishing('event-a');
      await dao.markFailed(
        'event-a',
        'timeout',
        nextAttemptAt: DateTime.utc(2026, 7, 1, 0, 0, 30),
      );

      await dao.enqueue(makeEvent(id: 'event-a'));

      final fetched = await dao.getById('event-a');
      expect(fetched!.status, PendingProductEventStatus.failed);
      expect(fetched.attemptCount, 1);
      expect(fetched.lastError, 'timeout');
      expect(
        fetched.nextAttemptAt!.isAtSameMomentAs(
          DateTime.utc(2026, 7, 1, 0, 0, 30),
        ),
        isTrue,
      );
    });

    test('returns retryable rows due now in created order', () async {
      await dao.enqueue(
        makeEvent(
          id: 'publishing',
          status: PendingProductEventStatus.publishing,
          createdAt: DateTime.utc(2026, 7),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'failed-old',
          status: PendingProductEventStatus.failed,
          nextAttemptAt: DateTime.utc(2026, 7, 1, 0, 0, 5),
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 1),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'pending-new',
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 2),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'not-yet',
          status: PendingProductEventStatus.failed,
          nextAttemptAt: DateTime.utc(2026, 7, 1, 0, 1),
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 3),
        ),
      );
      await dao.enqueue(
        makeEvent(
          id: 'many-attempts',
          status: PendingProductEventStatus.failed,
          attemptCount: 5,
          createdAt: DateTime.utc(2026, 7, 1, 0, 0, 4),
        ),
      );

      final retryable = await dao.getRetryable(
        now: DateTime.utc(2026, 7, 1, 0, 0, 10),
        limit: 10,
      );

      expect(retryable.map((event) => event.id), [
        'failed-old',
        'pending-new',
        'many-attempts',
      ]);
    });

    test(
      'temporary failures remain retryable regardless of attempt count',
      () async {
        await dao.enqueue(
          makeEvent(
            id: 'many-failures',
            status: PendingProductEventStatus.failed,
            attemptCount: 100,
            nextAttemptAt: DateTime.utc(2026, 7),
          ),
        );

        final retryable = await dao.getRetryable(
          now: DateTime.utc(2026, 7, 2),
          limit: 10,
        );

        expect(retryable.map((event) => event.id), ['many-failures']);
      },
    );

    group('owner scoping', () {
      const ownerA =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const ownerB =
          '2222222222222222222222222222222222222222222222222222222222222222';

      test('deleteForOwner removes only that owner rows', () async {
        await dao.enqueue(makeEvent(id: 'a1', ownerPubkey: ownerA));
        await dao.enqueue(makeEvent(id: 'a2', ownerPubkey: ownerA));
        await dao.enqueue(makeEvent(id: 'b1', ownerPubkey: ownerB));

        final deleted = await dao.deleteForOwner(ownerA);

        expect(deleted, 2);
        expect(await dao.getById('a1'), isNull);
        expect(await dao.getById('a2'), isNull);
        expect(
          await dao.getById('b1'),
          isNotNull,
          reason: 'another account queue must survive',
        );
      });

      test('deleteForOwner leaves legacy null-owner rows alone', () async {
        // Rows predating the owner column flush under whoever is active.
        // Deleting them here would discard events no account claims.
        await dao.enqueue(makeEvent(id: 'legacy'));
        await dao.enqueue(makeEvent(id: 'a1', ownerPubkey: ownerA));

        expect(await dao.deleteForOwner(ownerA), 1);
        expect(await dao.getById('legacy'), isNotNull);
      });

      test('enqueue round-trips ownerPubkey', () async {
        await dao.enqueue(makeEvent(id: 'a', ownerPubkey: ownerA));
        expect((await dao.getById('a'))!.ownerPubkey, equals(ownerA));
      });

      test('getRetryable returns only the requested owner rows', () async {
        await dao.enqueue(makeEvent(id: 'for-a', ownerPubkey: ownerA));
        await dao.enqueue(makeEvent(id: 'for-b', ownerPubkey: ownerB));
        await dao.enqueue(makeEvent(id: 'legacy'));

        final retryable = await dao.getRetryable(
          now: DateTime.utc(2026, 7, 2),
          limit: 10,
          ownerPubkey: ownerA,
        );

        expect(retryable.map((event) => event.id).toSet(), equals({'for-a'}));
      });

      test(
        'getRetryable without an owner returns only ownerless rows',
        () async {
          await dao.enqueue(makeEvent(id: 'for-a', ownerPubkey: ownerA));
          await dao.enqueue(makeEvent(id: 'for-b', ownerPubkey: ownerB));
          await dao.enqueue(makeEvent(id: 'legacy'));

          final retryable = await dao.getRetryable(
            now: DateTime.utc(2026, 7, 2),
            limit: 10,
          );

          expect(retryable.map((event) => event.id).toSet(), {'legacy'});
        },
      );
    });

    test('deleteAll removes signed and anonymous rows', () async {
      await dao.enqueue(makeEvent(id: 'signed', ownerPubkey: 'a' * 64));
      await dao.enqueue(makeEvent(id: 'anonymous'));

      expect(await dao.deleteAll(), 2);

      expect(await dao.getById('signed'), isNull);
      expect(await dao.getById('anonymous'), isNull);
    });

    test('prune removes expired rows then caps the oldest survivors', () async {
      await dao.enqueue(
        makeEvent(id: 'expired'),
      );
      await dao.enqueue(
        makeEvent(id: 'oldest-live', createdAt: DateTime.utc(2026, 7, 8)),
      );
      await dao.enqueue(
        makeEvent(id: 'newest-live', createdAt: DateTime.utc(2026, 7, 9)),
      );

      expect(
        await dao.prune(
          cutoff: DateTime.utc(2026, 7, 7),
          maxRecords: 1,
        ),
        2,
      );

      expect(await dao.getById('expired'), isNull);
      expect(await dao.getById('oldest-live'), isNull);
      expect(await dao.getById('newest-live'), isNotNull);
    });

    test('markDeadLetter stops exhausted events from retrying', () async {
      await dao.enqueue(makeEvent(id: 'event-a'));

      final updated = await dao.markDeadLetter('event-a', 'too many attempts');

      expect(updated, isTrue);
      final fetched = await dao.getById('event-a');
      expect(fetched!.status, PendingProductEventStatus.deadLetter);
      expect(fetched.lastError, 'too many attempts');
    });

    test('resetPublishingToPending recovers only in-flight rows', () async {
      await dao.enqueue(
        makeEvent(
          id: 'publishing-a',
          status: PendingProductEventStatus.publishing,
        ),
      );
      await dao.enqueue(makeEvent(id: 'pending-a'));
      await dao.enqueue(
        makeEvent(id: 'failed-a', status: PendingProductEventStatus.failed),
      );
      await dao.enqueue(
        makeEvent(id: 'dead-a', status: PendingProductEventStatus.deadLetter),
      );

      final updated = await dao.resetPublishingToPending();

      expect(updated, 1);
      expect(
        (await dao.getById('publishing-a'))!.status,
        PendingProductEventStatus.pending,
      );
      expect(
        (await dao.getById('pending-a'))!.status,
        PendingProductEventStatus.pending,
      );
      expect(
        (await dao.getById('failed-a'))!.status,
        PendingProductEventStatus.failed,
      );
      expect(
        (await dao.getById('dead-a'))!.status,
        PendingProductEventStatus.deadLetter,
      );
    });
  });
}
