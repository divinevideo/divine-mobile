// ABOUTME: Tests for ScheduledPostsRepository against an in-memory Drift
// ABOUTME: database and a mocked ScheduleApiClient: submit, sync, cancel,
// ABOUTME: backoff and the client-publish schedule.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/schedule_api_client.dart';

class _MockScheduleApiClient extends Mock implements ScheduleApiClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  const owner =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const otherOwner =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';
  final now = DateTime.utc(2026, 9, 22, 12);
  final publishAt = DateTime.utc(2026, 9, 23, 9);

  late AppDatabase database;
  late _MockScheduleApiClient client;
  late ScheduledPostsRepository repository;
  late DateTime clockNow;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    client = _MockScheduleApiClient();
    clockNow = now;
    repository = ScheduledPostsRepository(
      dao: database.scheduledPostsDao,
      client: client,
      ownerPubkey: owner,
      now: () => clockNow,
    );
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  Event buildEvent({DateTime? at, String d = 'video-1'}) {
    return Event(
      owner,
      34236,
      [
        ['d', d],
        ['title', 'Plants'],
      ],
      'A plant video',
      createdAt: (at ?? publishAt).millisecondsSinceEpoch ~/ 1000,
    );
  }

  ScheduledPostServerEntry entry(
    String eventId,
    ScheduledPostServerState state, {
    String failureReason = '',
  }) {
    return ScheduledPostServerEntry(
      eventId: eventId,
      kind: 34236,
      publishAt: publishAt.millisecondsSinceEpoch ~/ 1000,
      state: state,
      failureReason: failureReason,
    );
  }

  group(ScheduledPostsRepository, () {
    group('enqueue', () {
      test('stores the signed event as a pendingSubmit row', () async {
        final event = buildEvent();

        final post = await repository.enqueue(
          event: event,
          draftId: 'draft-1',
          uploadId: 'upload-1',
          expireAfterSecs: 86400,
        );

        expect(post.status, ScheduledPostStatus.pendingSubmit);
        expect(post.publishAt, event.createdAt);
        final stored = await repository.getById(event.id);
        expect(stored, isNotNull);
        expect(stored!.draftId, 'draft-1');
        expect(stored.uploadId, 'upload-1');
        expect(stored.expireAfterSecs, 86400);
        expect(stored.createdAt.toUtc(), now);
        expect(
          ScheduledPostsRepository.decodeEvent(stored).toJson(),
          event.toJson(),
        );
        expect((await repository.getByDraftId('draft-1'))?.eventId, event.id);
      });

      test('notifies listeners of the write', () async {
        final changes = <void>[];
        final sub = repository.changes.listen(changes.add);
        addTearDown(sub.cancel);

        await repository.enqueue(event: buildEvent(), draftId: 'draft-1');
        await pumpEventQueue();

        expect(changes, hasLength(1));
      });
    });

    group('submit', () {
      test('a concurrent second call does not reach the relay', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        final gate = Completer<ScheduleSubmitResult>();
        when(() => client.schedule(any())).thenAnswer((_) => gate.future);

        final first = repository.submit(event.id);
        await pumpEventQueue();
        final second = await repository.submit(event.id);

        expect(second.outcome, ScheduledPostSubmitOutcome.retryLater);
        gate.complete(
          ScheduleSubmitAccepted(eventId: event.id, publishAt: event.createdAt),
        );
        expect((await first).outcome, ScheduledPostSubmitOutcome.submitted);
        verify(() => client.schedule(any())).called(1);
      });

      test('an accepted hand-off marks the row scheduled', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        when(() => client.schedule(any())).thenAnswer(
          (_) async => ScheduleSubmitAccepted(
            eventId: event.id,
            publishAt: event.createdAt,
          ),
        );

        final result = await repository.submit(event.id);

        expect(result.outcome, ScheduledPostSubmitOutcome.submitted);
        final stored = await repository.getById(event.id);
        expect(stored!.status, ScheduledPostStatus.scheduled);
        expect(stored.attempts, 1);
        expect(stored.lastAttemptAt?.toUtc(), now);
        final sent = verify(() => client.schedule(captureAny())).captured;
        expect((sent.single as Event).id, event.id);
      });

      test('a rejection marks the row failed with the relay wording', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        when(() => client.schedule(any())).thenAnswer(
          (_) async => const ScheduleSubmitRejected(
            statusCode: 429,
            kind: ScheduleRejectionKind.overCap,
            message: 'author already has 100 posts pending',
          ),
        );

        final result = await repository.submit(event.id);

        expect(result.outcome, ScheduledPostSubmitOutcome.rejected);
        expect(result.kind, ScheduleRejectionKind.overCap);
        final stored = await repository.getById(event.id);
        expect(stored!.status, ScheduledPostStatus.failed);
        expect(stored.failureReason, 'author already has 100 posts pending');
      });

      test('a transient failure keeps the row pending and counts', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        when(
          () => client.schedule(any()),
        ).thenAnswer(
          (_) async => const ScheduleSubmitTransientFailure('timeout'),
        );

        final result = await repository.submit(event.id);

        expect(result.outcome, ScheduledPostSubmitOutcome.retryLater);
        final stored = await repository.getById(event.id);
        expect(stored!.status, ScheduledPostStatus.pendingSubmit);
        expect(stored.attempts, 1);
        expect(stored.failureReason, 'timeout');
      });

      test('does not resubmit a row the relay already holds', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );

        final result = await repository.submit(event.id);

        expect(result.outcome, ScheduledPostSubmitOutcome.retryLater);
        verifyNever(() => client.schedule(any()));
      });
    });

    group('isSubmitDue', () {
      ScheduledPost pendingWith({
        required int attempts,
        DateTime? lastAttemptAt,
        String? failureReason,
      }) {
        return ScheduledPost(
          eventId: 'e',
          ownerPubkey: owner,
          draftId: 'd',
          kind: 34236,
          signedEventJson: '{}',
          publishAt: 0,
          createdAt: now,
          attempts: attempts,
          lastAttemptAt: lastAttemptAt,
          failureReason: failureReason,
        );
      }

      test('a never-attempted row is due immediately', () {
        expect(repository.isSubmitDue(pendingWith(attempts: 0), now), isTrue);
      });

      test('backs off exponentially from the last attempt', () {
        final post = pendingWith(attempts: 3, lastAttemptAt: now);
        // 30 s * 2^(3-1) = 2 min.
        expect(
          repository.isSubmitDue(post, now.add(const Duration(seconds: 119))),
          isFalse,
        );
        expect(
          repository.isSubmitDue(post, now.add(const Duration(minutes: 2))),
          isTrue,
        );
      });

      test('caps the backoff at maxDelay', () {
        final post = pendingWith(attempts: 40, lastAttemptAt: now);
        expect(
          repository.isSubmitDue(post, now.add(const Duration(hours: 1))),
          isTrue,
        );
      });

      Future<ScheduledPost> afterTransientFailure(
        ScheduleSubmitTransientFailure failure,
      ) async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        when(() => client.schedule(any())).thenAnswer((_) async => failure);
        await repository.submit(event.id);
        return (await repository.getById(event.id))!;
      }

      test('an unserved endpoint retries at the unavailable pace', () async {
        final post = await afterTransientFailure(
          const ScheduleSubmitTransientFailure('http_404', unavailable: true),
        );
        expect(
          repository.isSubmitDue(post, now.add(const Duration(minutes: 14))),
          isFalse,
        );
        expect(
          repository.isSubmitDue(post, now.add(const Duration(minutes: 15))),
          isTrue,
        );
      });

      test('a 404 the relay answered itself keeps the normal pace', () async {
        final post = await afterTransientFailure(
          const ScheduleSubmitTransientFailure('http_404'),
        );
        expect(
          repository.isSubmitDue(post, now.add(const Duration(seconds: 30))),
          isTrue,
        );
      });

      test('a scheduled row is never due for submission', () {
        final post = pendingWith(
          attempts: 0,
        ).copyWith(status: ScheduledPostStatus.scheduled);
        expect(repository.isSubmitDue(post, now), isFalse);
      });
    });

    group('client publish timing', () {
      test('a held post waits for the grace period after its time', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );
        final pending = await repository.pending();

        expect(
          repository.clientPublishTime(pending.single),
          publishAt.add(const Duration(minutes: 6)),
        );
        expect(repository.dueForClientPublish(pending, publishAt), isEmpty);
        expect(
          repository.dueForClientPublish(
            pending,
            publishAt.add(const Duration(minutes: 6)),
          ),
          hasLength(1),
        );
      });

      test('a never-handed-off post is due at its time', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        final pending = await repository.pending();

        expect(repository.clientPublishTime(pending.single), publishAt);
        expect(
          repository.shouldPublishDirectly(
            pending.single,
            publishAt.subtract(const Duration(minutes: 3)),
          ),
          isFalse,
        );
        expect(
          repository.shouldPublishDirectly(
            pending.single,
            publishAt.subtract(const Duration(minutes: 2)),
          ),
          isTrue,
        );
      });

      test('nextWakeIn is the earliest of retry and publish moments', () async {
        final soon = buildEvent(at: now.add(const Duration(hours: 5)), d: 'a');
        final later = buildEvent(at: now.add(const Duration(days: 2)), d: 'b');
        await repository.enqueue(event: soon, draftId: 'draft-a');
        await repository.enqueue(event: later, draftId: 'draft-b');
        await database.scheduledPostsDao.updateStatus(
          eventId: soon.id,
          status: ScheduledPostStatus.scheduled,
        );
        // `later` never attempted: a retry is due now.
        expect(
          repository.nextWakeIn(await repository.pending(), now),
          Duration.zero,
        );

        await database.scheduledPostsDao.updateStatus(
          eventId: later.id,
          attemptedAt: now,
          failureReason: 'timeout',
        );
        // Next: `later` retry in 30 s, before `soon` publishes in 5 h 6 min.
        expect(
          repository.nextWakeIn(await repository.pending(), now),
          const Duration(seconds: 30),
        );

        await database.scheduledPostsDao.updateStatus(
          eventId: later.id,
          status: ScheduledPostStatus.scheduled,
        );
        expect(
          repository.nextWakeIn(await repository.pending(), now),
          const Duration(hours: 5, minutes: 6),
        );
      });

      test('nextWakeIn is null with nothing pending', () async {
        expect(repository.nextWakeIn(const [], now), isNull);
      });
    });

    group('syncFromServer', () {
      test('maps every relay state onto the matching local rows', () async {
        final held = buildEvent(d: 'held');
        final done = buildEvent(d: 'done');
        final broken = buildEvent(d: 'broken');
        final withdrawn = buildEvent(d: 'withdrawn');
        for (final e in [held, done, broken, withdrawn]) {
          await repository.enqueue(event: e, draftId: 'draft-${e.id}');
        }
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            entry(held.id, ScheduledPostServerState.schedule),
            entry(done.id, ScheduledPostServerState.published),
            entry(
              broken.id,
              ScheduledPostServerState.failed,
              failureReason: 'blocked: banned',
            ),
            entry(withdrawn.id, ScheduledPostServerState.cancel),
            entry('f' * 64, ScheduledPostServerState.schedule),
            entry('e' * 64, ScheduledPostServerState.published),
          ]),
        );

        final result = await repository.syncFromServer();

        expect(result.succeeded, isTrue);
        expect(result.published.single.eventId, done.id);
        expect(result.failed.single.failureReason, 'blocked: banned');
        expect(result.cancelled.single.eventId, withdrawn.id);
        expect(result.serverOnly.single.eventId, 'f' * 64);
        expect(
          (await repository.getById(held.id))!.status,
          ScheduledPostStatus.scheduled,
        );
        expect(
          (await repository.getById(done.id))!.status,
          ScheduledPostStatus.published,
        );
        expect(
          (await repository.getById(broken.id))!.status,
          ScheduledPostStatus.failed,
        );
        expect(
          (await repository.getById(withdrawn.id))!.status,
          ScheduledPostStatus.cancelled,
        );
      });

      test('leaves rows absent from the relay list untouched', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );
        when(
          () => client.list(),
        ).thenAnswer((_) async => const ScheduleListLoaded([]));

        final result = await repository.syncFromServer();

        expect(result.succeeded, isTrue);
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.scheduled,
        );
      });

      test('reports a failed list without touching rows', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        when(
          () => client.list(),
        ).thenAnswer((_) async => const ScheduleListFailure('timeout'));

        final result = await repository.syncFromServer();

        expect(result.succeeded, isFalse);
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.pendingSubmit,
        );
      });

      test('does not report an unchanged failure twice', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            entry(
              event.id,
              ScheduledPostServerState.failed,
              failureReason: 'invalid: expired',
            ),
          ]),
        );

        expect((await repository.syncFromServer()).failed, hasLength(1));
        expect((await repository.syncFromServer()).failed, isEmpty);
      });
    });

    group('cancelOnServer', () {
      test('cancels a never-handed-off row without a round trip', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');

        final outcome = await repository.cancelOnServer(event.id);

        expect(outcome, ScheduledPostCancelOutcome.cancelled);
        verifyNever(() => client.cancel(any()));
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.cancelled,
        );
      });

      for (final answer in [
        const ScheduleCancelled(),
        const ScheduleCancelNotFound(),
      ]) {
        test('${answer.runtimeType} on a held row cancels it', () async {
          final event = buildEvent();
          await repository.enqueue(event: event, draftId: 'draft-1');
          await database.scheduledPostsDao.updateStatus(
            eventId: event.id,
            status: ScheduledPostStatus.scheduled,
          );
          when(() => client.cancel(event.id)).thenAnswer((_) async => answer);

          final outcome = await repository.cancelOnServer(event.id);

          expect(outcome, ScheduledPostCancelOutcome.cancelled);
          expect(
            (await repository.getById(event.id))!.status,
            ScheduledPostStatus.cancelled,
          );
        });
      }

      test('a conflict on a published post reports alreadyPublished', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );
        when(() => client.cancel(event.id)).thenAnswer(
          (_) async => const ScheduleCancelConflict('no longer pending'),
        );
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            entry(event.id, ScheduledPostServerState.published),
          ]),
        );

        final outcome = await repository.cancelOnServer(event.id);

        expect(outcome, ScheduledPostCancelOutcome.alreadyPublished);
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.published,
        );
      });

      test('a conflict on a cancelled post is a cancellation', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );
        when(() => client.cancel(event.id)).thenAnswer(
          (_) async => const ScheduleCancelConflict('no longer pending'),
        );
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            entry(event.id, ScheduledPostServerState.cancel),
          ]),
        );

        expect(
          await repository.cancelOnServer(event.id),
          ScheduledPostCancelOutcome.cancelled,
        );
      });

      test('a conflict the relay cannot confirm leaves the row', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );
        when(() => client.cancel(event.id)).thenAnswer(
          (_) async => const ScheduleCancelConflict('no longer pending'),
        );
        when(
          () => client.list(),
        ).thenAnswer((_) async => const ScheduleListFailure('timeout'));

        final outcome = await repository.cancelOnServer(event.id);

        expect(outcome, ScheduledPostCancelOutcome.failure);
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.scheduled,
          reason: 'the post may be live; only the relay can say',
        );
      });

      test(
        'a conflict the list still reports as held leaves the row',
        () async {
          final event = buildEvent();
          await repository.enqueue(event: event, draftId: 'draft-1');
          await database.scheduledPostsDao.updateStatus(
            eventId: event.id,
            status: ScheduledPostStatus.scheduled,
          );
          when(() => client.cancel(event.id)).thenAnswer(
            (_) async => const ScheduleCancelConflict('no longer pending'),
          );
          when(() => client.list()).thenAnswer(
            (_) async => ScheduleListLoaded([
              entry(event.id, ScheduledPostServerState.schedule),
            ]),
          );

          expect(
            await repository.cancelOnServer(event.id),
            ScheduledPostCancelOutcome.failure,
          );
          expect(
            (await repository.getById(event.id))!.status,
            ScheduledPostStatus.scheduled,
          );
        },
      );

      test('a transient failure leaves the row as it was', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');
        await database.scheduledPostsDao.updateStatus(
          eventId: event.id,
          status: ScheduledPostStatus.scheduled,
        );
        when(() => client.cancel(event.id)).thenAnswer(
          (_) async => const ScheduleCancelTransientFailure(
            'http_404',
            unavailable: true,
          ),
        );

        expect(
          await repository.cancelOnServer(event.id),
          ScheduledPostCancelOutcome.unavailable,
        );
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.scheduled,
        );
      });

      test('an unknown row is already cancelled', () async {
        expect(
          await repository.cancelOnServer('x' * 64),
          ScheduledPostCancelOutcome.cancelled,
        );
      });
    });

    group('cancelRemote', () {
      test('a conflict the relay cannot confirm is a failure', () async {
        const eventId =
            '8888888888888888888888888888888888888888888888888888888888888888';
        when(
          () => client.cancel(eventId),
        ).thenAnswer((_) async => const ScheduleCancelConflict('gone'));
        when(
          () => client.list(),
        ).thenAnswer((_) async => const ScheduleListFailure('timeout'));

        expect(
          await repository.cancelRemote(eventId),
          ScheduledPostCancelOutcome.failure,
        );
      });

      test('maps the relay answers without a local row', () async {
        const eventId =
            '7777777777777777777777777777777777777777777777777777777777777777';
        when(
          () => client.cancel(eventId),
        ).thenAnswer((_) async => const ScheduleCancelled());
        expect(
          await repository.cancelRemote(eventId),
          ScheduledPostCancelOutcome.cancelled,
        );

        when(
          () => client.cancel(eventId),
        ).thenAnswer((_) async => const ScheduleCancelConflict('gone'));
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            entry(eventId, ScheduledPostServerState.published),
          ]),
        );
        expect(
          await repository.cancelRemote(eventId),
          ScheduledPostCancelOutcome.alreadyPublished,
        );

        when(() => client.cancel(eventId)).thenAnswer(
          (_) async => const ScheduleCancelTransientFailure('timeout'),
        );
        expect(
          await repository.cancelRemote(eventId),
          ScheduledPostCancelOutcome.failure,
        );
      });
    });

    group('row bookkeeping', () {
      test('markPublished, markFailed, requeue and delete', () async {
        final event = buildEvent();
        await repository.enqueue(event: event, draftId: 'draft-1');

        await repository.markFailed(event.id, 'blocked');
        expect(
          (await repository.getById(event.id))!.failureReason,
          'blocked',
        );

        await repository.requeue(event.id);
        final requeued = (await repository.getById(event.id))!;
        expect(requeued.status, ScheduledPostStatus.pendingSubmit);
        expect(requeued.failureReason, isNull);

        await repository.markPublished(event.id);
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.published,
        );

        await repository.delete(event.id);
        expect(await repository.getById(event.id), isNull);
      });

      test('list, watch and pending are scoped to the owner', () async {
        final mine = buildEvent();
        await repository.enqueue(event: mine, draftId: 'draft-1');
        await database.scheduledPostsDao.enqueue(
          ScheduledPost(
            eventId: 'f' * 64,
            ownerPubkey: otherOwner,
            draftId: 'other',
            kind: 34236,
            signedEventJson: jsonEncode(buildEvent(d: 'o').toJson()),
            publishAt: 1,
            createdAt: now,
          ),
        );

        expect((await repository.list()).single.eventId, mine.id);
        expect((await repository.pending()).single.eventId, mine.id);
        expect((await repository.watch().first).single.eventId, mine.id);
      });
    });
  });
}
