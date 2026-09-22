// ABOUTME: Unit tests for ScheduledPostsDao: enqueue idempotence, owner
// ABOUTME: isolation, status/attempt bookkeeping and the pending filter.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ScheduledPostsDao dao;

  const ownerA =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const ownerB =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';
  const eventA =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const eventB =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const eventC =
      '3333333333333333333333333333333333333333333333333333333333333333';

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    dao = database.scheduledPostsDao;
  });

  tearDown(() => database.close());

  ScheduledPost post(
    String eventId, {
    String owner = ownerA,
    String draftId = 'draft-1',
    int publishAt = 1800000000,
    ScheduledPostStatus status = ScheduledPostStatus.pendingSubmit,
    int? expireAfterSecs,
  }) {
    return ScheduledPost(
      eventId: eventId,
      ownerPubkey: owner,
      draftId: draftId,
      uploadId: 'upload-$eventId',
      kind: 34236,
      signedEventJson: '{"id":"$eventId"}',
      publishAt: publishAt,
      expireAfterSecs: expireAfterSecs,
      status: status,
      createdAt: DateTime.utc(2026, 9, 22),
    );
  }

  group(ScheduledPostsDao, () {
    group('enqueue', () {
      test('stores every column and reads it back', () async {
        await dao.enqueue(post(eventA, expireAfterSecs: 86400));

        final stored = await dao.getById(eventA);
        expect(stored, isNotNull);
        expect(stored!.ownerPubkey, ownerA);
        expect(stored.draftId, 'draft-1');
        expect(stored.uploadId, 'upload-$eventA');
        expect(stored.kind, 34236);
        expect(stored.signedEventJson, '{"id":"$eventA"}');
        expect(stored.publishAt, 1800000000);
        expect(stored.publishAtUtc, DateTime.utc(2027, 1, 15, 8));
        expect(stored.expireAfterSecs, 86400);
        expect(stored.status, ScheduledPostStatus.pendingSubmit);
        expect(stored.attempts, 0);
        expect(stored.lastAttemptAt, isNull);
        expect(stored.failureReason, isNull);
        expect(stored.createdAt.toUtc(), DateTime.utc(2026, 9, 22));
      });

      test('ignores a repeat of the same event id', () async {
        await dao.enqueue(post(eventA));
        await dao.updateStatus(
          eventId: eventA,
          status: ScheduledPostStatus.scheduled,
        );

        await dao.enqueue(post(eventA));

        final stored = await dao.getById(eventA);
        expect(stored!.status, ScheduledPostStatus.scheduled);
        expect(await dao.listForOwner(ownerA), hasLength(1));
      });
    });

    group('getByDraftId', () {
      test('finds the row holding a draft', () async {
        await dao.enqueue(post(eventA, draftId: 'draft-x'));

        final found = await dao.getByDraftId('draft-x');
        expect(found?.eventId, eventA);
        expect(await dao.getByDraftId('draft-missing'), isNull);
      });
    });

    group('listForOwner', () {
      test('returns only the owner rows, soonest publish time first', () async {
        await dao.enqueue(post(eventA, publishAt: 1800000300));
        await dao.enqueue(post(eventB, publishAt: 1800000100));
        await dao.enqueue(post(eventC, owner: ownerB, publishAt: 1));

        final rows = await dao.listForOwner(ownerA);
        expect(rows.map((r) => r.eventId), [eventB, eventA]);
        expect((await dao.listForOwner(ownerB)).single.eventId, eventC);
      });
    });

    group('watchForOwner', () {
      test('emits again after a write', () async {
        await dao.enqueue(post(eventA));
        final stream = dao.watchForOwner(ownerA);

        final first = await stream.first;
        expect(first.single.status, ScheduledPostStatus.pendingSubmit);

        final next = stream
            .where((rows) => rows.single.status == ScheduledPostStatus.failed)
            .first;
        await dao.updateStatus(
          eventId: eventA,
          status: ScheduledPostStatus.failed,
          failureReason: 'blocked: banned',
        );
        expect((await next).single.failureReason, 'blocked: banned');
      });
    });

    group('pendingForOwner', () {
      test('keeps pendingSubmit and scheduled rows only', () async {
        await dao.enqueue(post(eventA));
        await dao.enqueue(post(eventB, status: ScheduledPostStatus.scheduled));
        await dao.enqueue(post(eventC, status: ScheduledPostStatus.failed));

        final pending = await dao.pendingForOwner(ownerA);
        expect(pending.map((r) => r.eventId), [eventA, eventB]);
        expect(pending.every((r) => r.isPending), isTrue);
      });
    });

    group('updateStatus', () {
      test('records an attempt: status, count and timestamp', () async {
        await dao.enqueue(post(eventA));
        final attemptedAt = DateTime.utc(2026, 9, 22, 12);

        final changed = await dao.updateStatus(
          eventId: eventA,
          status: ScheduledPostStatus.scheduled,
          attemptedAt: attemptedAt,
        );

        expect(changed, isTrue);
        final stored = await dao.getById(eventA);
        expect(stored!.status, ScheduledPostStatus.scheduled);
        expect(stored.attempts, 1);
        expect(stored.lastAttemptAt?.toUtc(), attemptedAt);
      });

      test('a failure keeps counting attempts and stores the reason', () async {
        await dao.enqueue(post(eventA));
        await dao.updateStatus(
          eventId: eventA,
          attemptedAt: DateTime.utc(2026, 9, 22, 12),
          failureReason: 'timeout',
        );
        await dao.updateStatus(
          eventId: eventA,
          attemptedAt: DateTime.utc(2026, 9, 22, 13),
          failureReason: 'network',
        );

        final stored = await dao.getById(eventA);
        expect(stored!.status, ScheduledPostStatus.pendingSubmit);
        expect(stored.attempts, 2);
        expect(stored.failureReason, 'network');
        expect(stored.lastAttemptAt?.toUtc(), DateTime.utc(2026, 9, 22, 13));
      });

      test('clearFailureReason nulls the stored reason', () async {
        await dao.enqueue(post(eventA));
        await dao.updateStatus(eventId: eventA, failureReason: 'timeout');

        await dao.updateStatus(
          eventId: eventA,
          status: ScheduledPostStatus.scheduled,
          clearFailureReason: true,
        );

        final stored = await dao.getById(eventA);
        expect(stored!.failureReason, isNull);
        expect(stored.status, ScheduledPostStatus.scheduled);
      });

      test('returns false for an unknown row', () async {
        final changed = await dao.updateStatus(
          eventId: eventA,
          status: ScheduledPostStatus.cancelled,
        );
        expect(changed, isFalse);
      });
    });

    group('deleteById', () {
      test('removes exactly that row', () async {
        await dao.enqueue(post(eventA));
        await dao.enqueue(post(eventB));

        expect(await dao.deleteById(eventA), 1);
        expect(await dao.getById(eventA), isNull);
        expect(await dao.getById(eventB), isNotNull);
      });
    });

    group('deleteAllForUser', () {
      test('removes the owner rows and leaves other accounts alone', () async {
        await dao.enqueue(post(eventA));
        await dao.enqueue(post(eventB));
        await dao.enqueue(post(eventC, owner: ownerB));

        expect(await dao.deleteAllForUser(ownerA), 2);
        expect(await dao.listForOwner(ownerA), isEmpty);
        expect(await dao.listForOwner(ownerB), hasLength(1));
      });
    });

    group('status parsing', () {
      test('throws on an unknown stored status', () async {
        await database.customStatement(
          'INSERT INTO scheduled_posts (event_id, owner_pubkey, draft_id, '
          'kind, signed_event_json, publish_at, status, created_at) '
          "VALUES ('$eventA', '$ownerA', 'd', 34236, '{}', 1, "
          "'teleported', 0)",
        );

        expect(
          () => dao.getById(eventA),
          throwsA(
            isA<UnknownScheduledPostStatusException>().having(
              (e) => e.toString(),
              'message',
              contains('"teleported"'),
            ),
          ),
        );
      });
    });

    group(ScheduledPost, () {
      test('copyWith replaces only the bookkeeping fields', () {
        final original = post(eventA, expireAfterSecs: 60);

        final copy = original.copyWith(
          status: ScheduledPostStatus.failed,
          failureReason: 'blocked',
          attempts: 3,
          lastAttemptAt: DateTime.utc(2026),
        );

        expect(copy.eventId, eventA);
        expect(copy.expireAfterSecs, 60);
        expect(copy.status, ScheduledPostStatus.failed);
        expect(copy.failureReason, 'blocked');
        expect(copy.attempts, 3);
        expect(copy.lastAttemptAt, DateTime.utc(2026));
        expect(
          copy.copyWith(clearFailureReason: true).failureReason,
          isNull,
        );
      });

      test('equality tracks the id and bookkeeping fields', () {
        expect(post(eventA), equals(post(eventA)));
        expect(post(eventA), isNot(equals(post(eventB))));
        expect(
          post(eventA),
          isNot(equals(post(eventA, status: ScheduledPostStatus.scheduled))),
        );
        expect(post(eventA).hashCode, post(eventA).hashCode);
      });
    });
  });
}
