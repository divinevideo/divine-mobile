// ABOUTME: Tests for ScheduledPostCoordinator: the sweep order (settled rows,
// ABOUTME: hand-off, sync, client fallback, finalize), owner scoping, and the
// ABOUTME: user actions cancel / reschedule / publish now / retry.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:openvine/services/scheduled_post_coordinator.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockScheduleApiClient extends Mock implements ScheduleApiClient {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  const owner =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const collaborator =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';
  final start = DateTime.utc(2026, 9, 22, 12);
  final publishAt = DateTime.utc(2026, 9, 23, 9);

  late AppDatabase database;
  late _MockScheduleApiClient client;
  late _MockDraftStorageService draftService;
  late _MockCollaboratorInviteService inviteService;
  late ScheduledPostsRepository repository;
  late ScheduledPostCoordinator coordinator;
  late StreamController<bool> foreground;
  late StreamController<void> reconnect;
  late DateTime now;
  late String currentPubkey;
  late List<Event> broadcasts;
  late EventPublishOutcome broadcastOutcome;
  late Object? broadcastError;
  late List<(Event, String?)> recorded;
  late bool signerFails;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(PublishStatus.draft);
  });

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    client = _MockScheduleApiClient();
    draftService = _MockDraftStorageService();
    inviteService = _MockCollaboratorInviteService();
    foreground = StreamController<bool>.broadcast();
    reconnect = StreamController<void>.broadcast();
    now = start;
    currentPubkey = owner;
    broadcasts = [];
    broadcastOutcome = EventPublishOutcome.published;
    broadcastError = null;
    recorded = [];
    signerFails = false;

    repository = ScheduledPostsRepository(
      dao: database.scheduledPostsDao,
      client: client,
      ownerPubkey: owner,
      now: () => now,
    );
    coordinator = ScheduledPostCoordinator(
      repository: repository,
      broadcast: (event, {isRetry = false}) async {
        expect(isRetry, isTrue, reason: 'held events are retries');
        final error = broadcastError;
        if (error != null) throw error;
        broadcasts.add(event);
        return broadcastOutcome;
      },
      recordPublish: (event, {uploadId}) async =>
          recorded.add((event, uploadId)),
      sign:
          ({
            required int kind,
            required String content,
            List<List<String>>? tags,
            int? createdAt,
          }) async {
            if (signerFails) return null;
            return Event(
              owner,
              kind,
              tags ?? [],
              content,
              createdAt: createdAt,
            );
          },
      draftService: draftService,
      collaboratorInviteService: inviteService,
      appForegroundStream: foreground.stream,
      retryTriggerStream: reconnect.stream,
      outboxChangedStream: repository.changes,
      currentPubkey: () => currentPubkey,
      now: () => now,
    );

    when(() => draftService.deleteDraft(any())).thenAnswer((_) async {});
    when(
      () => draftService.updatePublishStatus(
        draftId: any(named: 'draftId'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => inviteService.sendInvites(
        collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
        creatorPubkey: any(named: 'creatorPubkey'),
        videoAddress: any(named: 'videoAddress'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        relayHint: any(named: 'relayHint'),
      ),
    ).thenAnswer(
      (_) async => const CollaboratorInviteBatchResult(results: {}),
    );
    when(
      () => client.list(),
    ).thenAnswer((_) async => const ScheduleListLoaded([]));
  });

  tearDown(() async {
    await coordinator.dispose();
    repository.dispose();
    await foreground.close();
    await reconnect.close();
    await database.close();
  });

  Event buildEvent({DateTime? at, String d = 'video-1', bool collab = false}) {
    return Event(
      owner,
      34236,
      [
        ['d', d],
        ['title', 'Plants'],
        ['image', 'https://cdn.example.com/thumb.jpg'],
        if (collab)
          ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
      ],
      'A plant video',
      createdAt: (at ?? publishAt).millisecondsSinceEpoch ~/ 1000,
    );
  }

  Future<ScheduledPost> enqueue(
    Event event, {
    ScheduledPostStatus? status,
    String draftId = 'draft-1',
  }) async {
    final post = await repository.enqueue(
      event: event,
      draftId: draftId,
      uploadId: 'upload-1',
      expireAfterSecs: 86400,
    );
    if (status != null) {
      await database.scheduledPostsDao.updateStatus(
        eventId: event.id,
        status: status,
      );
    }
    return post;
  }

  void stubAccepted() {
    when(() => client.schedule(any())).thenAnswer((invocation) async {
      final event = invocation.positionalArguments.first as Event;
      return ScheduleSubmitAccepted(
        eventId: event.id,
        publishAt: event.createdAt,
      );
    });
  }

  ScheduledPostServerEntry serverEntry(
    Event event,
    ScheduledPostServerState state,
  ) => ScheduledPostServerEntry(
    eventId: event.id,
    kind: 34236,
    publishAt: event.createdAt,
    state: state,
    failureReason: '',
  );

  group(ScheduledPostCoordinator, () {
    group('sweep', () {
      test('hands a pending post to the relay', () async {
        stubAccepted();
        final event = buildEvent();
        await enqueue(event);

        await coordinator.sweep();

        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.scheduled,
        );
        expect(broadcasts, isEmpty);
      });

      test('publishes a pending post directly when its time is near', () async {
        final event = buildEvent();
        await enqueue(event);
        now = publishAt.subtract(const Duration(minutes: 1));

        await coordinator.sweep();

        verifyNever(() => client.schedule(any()));
        expect(broadcasts.single.id, event.id);
        expect(recorded.single.$1.id, event.id);
        expect(recorded.single.$2, 'upload-1');
        verify(() => draftService.deleteDraft('draft-1')).called(1);
        expect(await repository.getById(event.id), isNull);
      });

      test('finalizes a held post the relay reports as published', () async {
        final event = buildEvent(collab: true);
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            serverEntry(event, ScheduledPostServerState.published),
          ]),
        );

        await coordinator.sweep(force: true);

        expect(broadcasts, isEmpty);
        expect(recorded.single.$1.id, event.id);
        verify(
          () => inviteService.sendInvites(
            collaboratorPubkeys: {collaborator},
            creatorPubkey: owner,
            videoAddress: '34236:$owner:video-1',
            title: 'Plants',
            thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
            relayHint: 'wss://relay.divine.video',
          ),
        ).called(1);
        verify(() => draftService.deleteDraft('draft-1')).called(1);
        expect(await repository.getById(event.id), isNull);
      });

      test('logs a collaborator invite that did not go out', () async {
        final event = buildEvent(collab: true);
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            serverEntry(event, ScheduledPostServerState.published),
          ]),
        );
        when(
          () => inviteService.sendInvites(
            collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
            creatorPubkey: any(named: 'creatorPubkey'),
            videoAddress: any(named: 'videoAddress'),
            title: any(named: 'title'),
            thumbnailUrl: any(named: 'thumbnailUrl'),
            relayHint: any(named: 'relayHint'),
          ),
        ).thenAnswer(
          (_) async => const CollaboratorInviteBatchResult(
            results: {
              collaborator: CollaboratorInviteResult(
                success: false,
                error: 'dm relay refused',
              ),
            },
          ),
        );

        await coordinator.sweep(force: true);

        final logged = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .where((message) => message.contains(event.id))
            .join('\n');
        expect(logged, contains('dm relay refused'));
        expect(logged, contains(collaborator));
      });

      test('returns a post cancelled elsewhere to the drafts', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            serverEntry(event, ScheduledPostServerState.cancel),
          ]),
        );

        await coordinator.sweep(force: true);

        verify(
          () => draftService.updatePublishStatus(
            draftId: 'draft-1',
            status: PublishStatus.draft,
          ),
        ).called(1);
        expect(await repository.getById(event.id), isNull);
        expect(recorded, isEmpty);
      });

      test('publishes a held post itself once the relay is late', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            serverEntry(event, ScheduledPostServerState.schedule),
          ]),
        );

        now = publishAt.add(const Duration(minutes: 5));
        await coordinator.sweep();
        expect(broadcasts, isEmpty, reason: 'inside the grace period');

        now = publishAt.add(const Duration(minutes: 6));
        await coordinator.sweep();

        expect(broadcasts.single.id, event.id);
        expect(recorded, hasLength(1));
        expect(await repository.getById(event.id), isNull);
      });

      test(
        'keeps a held post when the broadcast does not go through',
        () async {
          final event = buildEvent();
          await enqueue(event, status: ScheduledPostStatus.scheduled);
          broadcastOutcome = EventPublishOutcome.transientFailure;
          now = publishAt.add(const Duration(minutes: 10));

          await coordinator.sweep();

          expect(broadcasts, hasLength(1));
          expect(recorded, isEmpty);
          expect(
            (await repository.getById(event.id))!.status,
            ScheduledPostStatus.scheduled,
          );
        },
      );

      test('marks a post failed when the account is restricted', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        broadcastError = const AccountRestrictedPublishException(
          reason: 'blocked: account suspended',
          source: AccountRestrictionSource.webSocket,
        );
        now = publishAt.add(const Duration(minutes: 10));

        await coordinator.sweep();

        final stored = await repository.getById(event.id);
        expect(stored!.status, ScheduledPostStatus.failed);
        expect(stored.failureReason, 'blocked: account suspended');
      });

      test('does nothing for an outbox of another account', () async {
        stubAccepted();
        await enqueue(buildEvent());
        currentPubkey = collaborator;

        await coordinator.sweep();

        verifyNever(() => client.schedule(any()));
      });

      test('respects the submission backoff', () async {
        when(() => client.schedule(any())).thenAnswer(
          (_) async => const ScheduleSubmitTransientFailure('timeout'),
        );
        final event = buildEvent();
        await enqueue(event);

        await coordinator.sweep();
        await coordinator.sweep();
        verify(() => client.schedule(any())).called(1);

        now = now.add(const Duration(seconds: 30));
        await coordinator.sweep();
        verify(() => client.schedule(any())).called(1);
      });
    });

    group('posts scheduled from another device', () {
      test(
        'a forced sweep lists them and cancelRemote withdraws one',
        () async {
          final elsewhere = buildEvent(d: 'elsewhere');
          when(() => client.list()).thenAnswer(
            (_) async => ScheduleListLoaded([
              serverEntry(elsewhere, ScheduledPostServerState.schedule),
            ]),
          );
          final changes = <void>[];
          final sub = coordinator.serverOnlyChanges.listen(changes.add);
          addTearDown(sub.cancel);

          await coordinator.sweep(force: true);
          await pumpEventQueue();

          expect(coordinator.serverOnlyPosts.single.eventId, elsewhere.id);
          expect(changes, hasLength(1));

          when(
            () => client.cancel(elsewhere.id),
          ).thenAnswer((_) async => const ScheduleCancelled());
          final outcome = await coordinator.cancelRemote(elsewhere.id);
          await pumpEventQueue();

          expect(outcome, ScheduledPostActionOutcome.done);
          expect(coordinator.serverOnlyPosts, isEmpty);
          expect(changes, hasLength(2));
        },
      );

      test('an unforced sweep with an empty outbox does not sync', () async {
        await coordinator.sweep();

        verifyNever(() => client.list());
      });
    });

    group('lifecycle', () {
      test(
        'syncs once when the provider replays that the app is open',
        () async {
          when(
            () => client.list(),
          ).thenAnswer((_) async => const ScheduleListLoaded([]));

          await coordinator.initialize();
          // appForegroundProvider is listened to with fireImmediately, so the
          // current state arrives right after initialize's own sweep starts.
          foreground.add(true);
          await pumpEventQueue();

          verify(() => client.list()).called(1);
        },
      );

      test('sweeps on initialize, foreground and reconnect', () async {
        stubAccepted();
        await enqueue(buildEvent());

        await coordinator.initialize();
        await pumpEventQueue();
        verify(() => client.schedule(any())).called(1);

        await enqueue(buildEvent(d: 'video-2'));
        await pumpEventQueue();
        verify(() => client.schedule(any())).called(1);

        foreground.add(false);
        await pumpEventQueue();
        expect(coordinator.hasTimer, isFalse);
        await enqueue(buildEvent(d: 'video-3'));
        await pumpEventQueue();
        verifyNever(() => client.schedule(any()));

        foreground.add(true);
        await pumpEventQueue();
        verify(() => client.schedule(any())).called(1);

        await enqueue(buildEvent(d: 'video-4'));
        await database.scheduledPostsDao.updateStatus(
          eventId: buildEvent(d: 'video-4').id,
          attemptedAt: now,
          failureReason: 'timeout',
        );
        reconnect.add(null);
        await pumpEventQueue();
        verifyNever(() => client.schedule(any()));
        now = now.add(const Duration(minutes: 1));
        reconnect.add(null);
        await pumpEventQueue();
        verify(() => client.schedule(any())).called(1);
      });

      test(
        'arms one timer to the next due moment and drops it on dispose',
        () async {
          await enqueue(buildEvent(), status: ScheduledPostStatus.scheduled);

          await coordinator.initialize();
          await pumpEventQueue();
          expect(coordinator.hasTimer, isTrue);

          await coordinator.dispose();
          expect(coordinator.hasTimer, isFalse);
          expect(coordinator.isInitialized, isFalse);
        },
      );

      test('arms no timer with an empty outbox', () async {
        await coordinator.initialize();
        await pumpEventQueue();
        expect(coordinator.hasTimer, isFalse);
      });
    });

    group('cancel', () {
      test('withdraws the post and returns its draft', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(event.id),
        ).thenAnswer((_) async => const ScheduleCancelled());

        final outcome = await coordinator.cancel(event.id);

        expect(outcome, ScheduledPostActionOutcome.done);
        verify(
          () => draftService.updatePublishStatus(
            draftId: 'draft-1',
            status: PublishStatus.draft,
          ),
        ).called(1);
        expect(await repository.getById(event.id), isNull);
      });

      test('finalizes a post the relay already published', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(event.id),
        ).thenAnswer((_) async => const ScheduleCancelConflict('published'));
        when(() => client.list()).thenAnswer(
          (_) async => ScheduleListLoaded([
            serverEntry(event, ScheduledPostServerState.published),
          ]),
        );

        final outcome = await coordinator.cancel(event.id);

        expect(outcome, ScheduledPostActionOutcome.alreadyPublished);
        expect(recorded.single.$1.id, event.id);
        expect(await repository.getById(event.id), isNull);
      });

      test('leaves the post when the relay is unreachable', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(() => client.cancel(event.id)).thenAnswer(
          (_) async => const ScheduleCancelTransientFailure(
            'http_404',
            unavailable: true,
          ),
        );

        expect(
          await coordinator.cancel(event.id),
          ScheduledPostActionOutcome.unavailable,
        );
        expect(await repository.getById(event.id), isNotNull);
      });

      test('refuses for another account', () async {
        final event = buildEvent();
        await enqueue(event);
        currentPubkey = collaborator;

        expect(
          await coordinator.cancel(event.id),
          ScheduledPostActionOutcome.failed,
        );
        expect(await repository.getById(event.id), isNotNull);
      });
    });

    group('reschedule', () {
      test('replaces the held event with a newly signed one', () async {
        stubAccepted();
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(event.id),
        ).thenAnswer((_) async => const ScheduleCancelled());
        final newTime = publishAt.add(const Duration(days: 1));

        final outcome = await coordinator.reschedule(event.id, newTime);

        expect(outcome, ScheduledPostActionOutcome.done);
        expect(await repository.getById(event.id), isNull);
        final replacement = (await repository.list()).single;
        expect(replacement.eventId, isNot(event.id));
        expect(replacement.publishAtUtc, newTime);
        expect(replacement.draftId, 'draft-1');
        expect(replacement.uploadId, 'upload-1');
        expect(replacement.expireAfterSecs, 86400);
        expect(replacement.status, ScheduledPostStatus.scheduled);
        final signed = ScheduledPostsRepository.decodeEvent(replacement);
        expect(signed.tags, [
          ['d', 'video-1'],
          ['title', 'Plants'],
          ['image', 'https://cdn.example.com/thumb.jpg'],
          ['published_at', '${signed.createdAt}'],
          ['expiration', '${signed.createdAt + 86400}'],
        ]);
        verify(() => client.cancel(event.id)).called(1);
      });

      test('reports a new time the relay refuses as failed', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(event.id),
        ).thenAnswer((_) async => const ScheduleCancelled());
        when(() => client.schedule(any())).thenAnswer(
          (_) async => const ScheduleSubmitRejected(
            statusCode: 429,
            kind: ScheduleRejectionKind.overCap,
            message: 'author already has 100 posts pending',
          ),
        );

        final outcome = await coordinator.reschedule(
          event.id,
          publishAt.add(const Duration(days: 1)),
        );

        expect(outcome, ScheduledPostActionOutcome.failed);
        expect(
          (await repository.list()).single.status,
          ScheduledPostStatus.failed,
        );
      });

      test('holds a new time the relay cannot take yet as done', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(event.id),
        ).thenAnswer((_) async => const ScheduleCancelled());
        when(() => client.schedule(any())).thenAnswer(
          (_) async => const ScheduleSubmitTransientFailure(
            'http_404',
            unavailable: true,
          ),
        );

        final outcome = await coordinator.reschedule(
          event.id,
          publishAt.add(const Duration(days: 1)),
        );

        expect(outcome, ScheduledPostActionOutcome.done);
        expect(
          (await repository.list()).single.status,
          ScheduledPostStatus.pendingSubmit,
        );
      });

      test('keeps the held event when signing fails', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        signerFails = true;

        final outcome = await coordinator.reschedule(
          event.id,
          publishAt.add(const Duration(days: 1)),
        );

        expect(outcome, ScheduledPostActionOutcome.failed);
        verifyNever(() => client.cancel(any()));
        expect(await repository.getById(event.id), isNotNull);
      });

      test('keeps the held event when the relay cannot withdraw it', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(() => client.cancel(event.id)).thenAnswer(
          (_) async => const ScheduleCancelTransientFailure('timeout'),
        );

        final outcome = await coordinator.reschedule(
          event.id,
          publishAt.add(const Duration(days: 1)),
        );

        expect(outcome, ScheduledPostActionOutcome.failed);
        expect((await repository.list()).single.eventId, event.id);
      });

      test('keeps the post when moved to the time it already has', () async {
        stubAccepted();
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(any()),
        ).thenAnswer((_) async => const ScheduleCancelled());
        final newTime = publishAt.add(const Duration(days: 1));
        // The first move adds `published_at` and the expiration, so
        // re-signing the result for the same time yields the same event id.
        await coordinator.reschedule(event.id, newTime);
        final held = (await repository.list()).single;
        expect(held.status, ScheduledPostStatus.scheduled);

        final outcome = await coordinator.reschedule(held.eventId, newTime);

        expect(outcome, ScheduledPostActionOutcome.done);
        final kept = await repository.getById(held.eventId);
        expect(kept?.status, ScheduledPostStatus.scheduled);
        verifyNever(() => client.cancel(held.eventId));
        verifyNever(
          () => draftService.updatePublishStatus(
            draftId: any(named: 'draftId'),
            status: any(named: 'status'),
          ),
        );
      });

      test('keeps a freshly scheduled post moved to its own time', () async {
        stubAccepted();
        final at = publishAt.millisecondsSinceEpoch ~/ 1000;
        // The publisher writes published_at and the expiration mid-list,
        // ahead of the credit tags.
        final event = Event(
          owner,
          34236,
          [
            ['d', 'video-1'],
            ['title', 'Plants'],
            ['published_at', '$at'],
            ['alt', 'Plants'],
            ['expiration', '${at + 86400}'],
            ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
          ],
          'A plant video',
          createdAt: at,
        );
        await enqueue(event, status: ScheduledPostStatus.scheduled);

        final outcome = await coordinator.reschedule(event.id, publishAt);

        expect(outcome, ScheduledPostActionOutcome.done);
        expect((await repository.list()).single.eventId, event.id);
        verifyNever(() => client.cancel(any()));
        verifyNever(() => client.schedule(any()));
      });

      test(
        'hands a failed post back to the relay when moved to its own time',
        () async {
          stubAccepted();
          final event = buildEvent();
          await enqueue(event, status: ScheduledPostStatus.scheduled);
          when(
            () => client.cancel(any()),
          ).thenAnswer((_) async => const ScheduleCancelled());
          final newTime = publishAt.add(const Duration(days: 1));
          await coordinator.reschedule(event.id, newTime);
          final held = (await repository.list()).single;
          await repository.markFailed(held.eventId, 'rate-limited');

          final outcome = await coordinator.reschedule(held.eventId, newTime);

          expect(outcome, ScheduledPostActionOutcome.done);
          final resubmitted = await repository.getById(held.eventId);
          expect(resubmitted?.status, ScheduledPostStatus.scheduled);
          expect(resubmitted?.failureReason, isNull);
          verifyNever(() => client.cancel(held.eventId));
        },
      );
    });

    group('publishNow', () {
      test('signs for now, withdraws the held event and publishes', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        when(
          () => client.cancel(event.id),
        ).thenAnswer((_) async => const ScheduleCancelled());

        final outcome = await coordinator.publishNow(event.id);

        expect(outcome, ScheduledPostActionOutcome.done);
        expect(broadcasts.single.createdAt, now.millisecondsSinceEpoch ~/ 1000);
        expect(broadcasts.single.id, isNot(event.id));
        expect(recorded.single.$1.id, broadcasts.single.id);
        verify(() => draftService.deleteDraft('draft-1')).called(1);
        expect(await repository.list(), isEmpty);
      });

      test(
        'keeps the replacement for the sweep when the broadcast fails',
        () async {
          final event = buildEvent();
          await enqueue(event, status: ScheduledPostStatus.scheduled);
          when(
            () => client.cancel(event.id),
          ).thenAnswer((_) async => const ScheduleCancelled());
          broadcastOutcome = EventPublishOutcome.transientFailure;

          final outcome = await coordinator.publishNow(event.id);

          expect(outcome, ScheduledPostActionOutcome.unavailable);
          final replacement = (await repository.list()).single;
          expect(replacement.status, ScheduledPostStatus.pendingSubmit);
          expect(replacement.publishAt, now.millisecondsSinceEpoch ~/ 1000);
        },
      );

      group('when the held event is already dated now', () {
        late Event event;

        setUp(() async {
          // A body restamped for exactly `now`, so re-signing it for now
          // reproduces the held event and its id.
          final nowSecs = now.millisecondsSinceEpoch ~/ 1000;
          event = Event(
            owner,
            34236,
            [
              ['d', 'video-1'],
              ['title', 'Plants'],
              ['published_at', '$nowSecs'],
              ['expiration', '${nowSecs + 86400}'],
            ],
            'A plant video',
            createdAt: nowSecs,
          );
          await enqueue(event, status: ScheduledPostStatus.scheduled);
          when(
            () => client.cancel(any()),
          ).thenAnswer((_) async => const ScheduleCancelled());
        });

        test('broadcasts the held event itself', () async {
          final outcome = await coordinator.publishNow(event.id);

          expect(outcome, ScheduledPostActionOutcome.done);
          expect(broadcasts.single.id, event.id);
          verify(() => draftService.deleteDraft('draft-1')).called(1);
          verifyNever(() => client.cancel(any()));
        });

        test('keeps the only copy when the broadcast fails', () async {
          broadcastOutcome = EventPublishOutcome.transientFailure;

          final outcome = await coordinator.publishNow(event.id);

          expect(outcome, ScheduledPostActionOutcome.unavailable);
          final kept = await repository.getById(event.id);
          expect(kept?.status, ScheduledPostStatus.scheduled);
          verifyNever(() => client.cancel(any()));
        });
      });
    });

    group('retry', () {
      test('re-submits a failed post whose time is still ahead', () async {
        stubAccepted();
        final event = buildEvent();
        await enqueue(event);
        await repository.markFailed(event.id, 'rate-limited');

        final outcome = await coordinator.retry(event.id);

        expect(outcome, ScheduledPostActionOutcome.done);
        final stored = await repository.getById(event.id);
        expect(stored!.status, ScheduledPostStatus.scheduled);
        expect(stored.failureReason, isNull);
      });

      test('reports a hand-off the relay refuses again as failed', () async {
        final event = buildEvent();
        await enqueue(event);
        await repository.markFailed(event.id, 'too many pending posts');
        when(() => client.schedule(any())).thenAnswer(
          (_) async => const ScheduleSubmitRejected(
            statusCode: 429,
            kind: ScheduleRejectionKind.overCap,
            message: 'author already has 100 posts pending',
          ),
        );

        final outcome = await coordinator.retry(event.id);

        expect(outcome, ScheduledPostActionOutcome.failed);
        expect(
          (await repository.getById(event.id))!.status,
          ScheduledPostStatus.failed,
        );
      });

      test('publishes a failed post whose time has passed', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        await repository.markFailed(event.id, 'gave up');
        now = publishAt.add(const Duration(days: 2));

        final outcome = await coordinator.retry(event.id);

        expect(outcome, ScheduledPostActionOutcome.done);
        expect(broadcasts.single.createdAt, now.millisecondsSinceEpoch ~/ 1000);
        expect(await repository.list(), isEmpty);
      });

      test('ignores a post that is not failed', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);

        expect(
          await coordinator.retry(event.id),
          ScheduledPostActionOutcome.done,
        );
        verifyNever(() => client.schedule(any()));
        expect(broadcasts, isEmpty);
      });
    });

    group('settled rows', () {
      test('finishes a withdrawal a backgrounded sweep left behind', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        final listed = Completer<ScheduleListResult>();
        when(() => client.list()).thenAnswer((_) => listed.future);
        await coordinator.initialize();
        await pumpEventQueue();

        // The app leaves while the relay's list is still on its way.
        foreground.add(false);
        await pumpEventQueue();
        listed.complete(
          ScheduleListLoaded([
            serverEntry(event, ScheduledPostServerState.cancel),
          ]),
        );
        await pumpEventQueue();
        expect(
          (await repository.getById(event.id))?.status,
          ScheduledPostStatus.cancelled,
        );
        verifyNever(
          () => draftService.updatePublishStatus(
            draftId: any(named: 'draftId'),
            status: any(named: 'status'),
          ),
        );

        when(
          () => client.list(),
        ).thenAnswer((_) async => const ScheduleListLoaded([]));
        foreground.add(true);
        await pumpEventQueue();

        verify(
          () => draftService.updatePublishStatus(
            draftId: 'draft-1',
            status: PublishStatus.draft,
          ),
        ).called(1);
        expect(await repository.getById(event.id), isNull);
      });

      test('keeps a draft held while another live row still owns it', () async {
        final withdrawn = buildEvent();
        final live = buildEvent(d: 'video-2');
        await enqueue(withdrawn, status: ScheduledPostStatus.cancelled);
        await enqueue(live, status: ScheduledPostStatus.scheduled);

        await coordinator.sweep(force: true);

        expect(await repository.getById(withdrawn.id), isNull);
        expect(await repository.getById(live.id), isNotNull);
        verifyNever(
          () => draftService.updatePublishStatus(
            draftId: any(named: 'draftId'),
            status: any(named: 'status'),
          ),
        );
      });
    });

    group('an action racing a sweep', () {
      test(
        'post now publishes and finishes once while the coordinator runs',
        () async {
          final event = buildEvent(collab: true);
          await enqueue(event, status: ScheduledPostStatus.scheduled);
          when(
            () => client.cancel(event.id),
          ).thenAnswer((_) async => const ScheduleCancelled());
          await coordinator.initialize();
          await pumpEventQueue();
          // Keeps the live row in the outbox while the sweeps its writes wake
          // look at it.
          final draftDeleted = Completer<void>();
          when(
            () => draftService.deleteDraft(any()),
          ).thenAnswer((_) => draftDeleted.future);

          final publishing = coordinator.publishNow(event.id);
          await pumpEventQueue();
          draftDeleted.complete();

          expect(await publishing, ScheduledPostActionOutcome.done);
          await pumpEventQueue();
          expect(broadcasts, hasLength(1));
          expect(recorded, hasLength(1));
          verify(
            () => inviteService.sendInvites(
              collaboratorPubkeys: any(named: 'collaboratorPubkeys'),
              creatorPubkey: any(named: 'creatorPubkey'),
              videoAddress: any(named: 'videoAddress'),
              title: any(named: 'title'),
              thumbnailUrl: any(named: 'thumbnailUrl'),
              relayHint: any(named: 'relayHint'),
            ),
          ).called(1);
          verifyNever(
            () => draftService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
            ),
          );
        },
      );

      test('a cancel keeps a late post from going live while the relay '
          'answers', () async {
        final event = buildEvent();
        await enqueue(event, status: ScheduledPostStatus.scheduled);
        final answer = Completer<ScheduleCancelResult>();
        when(() => client.cancel(event.id)).thenAnswer((_) => answer.future);
        now = publishAt.add(const Duration(minutes: 6));

        final cancelling = coordinator.cancel(event.id);
        await pumpEventQueue();
        await coordinator.sweep();
        answer.complete(const ScheduleCancelled());

        expect(await cancelling, ScheduledPostActionOutcome.done);
        expect(broadcasts, isEmpty);
        verify(
          () => draftService.updatePublishStatus(
            draftId: 'draft-1',
            status: PublishStatus.draft,
          ),
        ).called(1);
        expect(await repository.getById(event.id), isNull);
      });
    });

    group('a broadcast no relay confirmed', () {
      setUp(() => broadcastOutcome = EventPublishOutcome.transientFailure);

      test('waits out a backoff before the next attempt', () async {
        await enqueue(buildEvent(), status: ScheduledPostStatus.scheduled);
        now = publishAt.add(const Duration(minutes: 10));

        await coordinator.sweep();
        await coordinator.sweep();
        expect(broadcasts, hasLength(1));

        now = now.add(const Duration(seconds: 30));
        await coordinator.sweep();
        expect(broadcasts, hasLength(2));
      });

      test(
        'holds a post in the direct window without handing it off',
        () async {
          await enqueue(buildEvent());
          now = publishAt.subtract(const Duration(seconds: 90));

          await coordinator.sweep();
          await coordinator.sweep();

          expect(broadcasts, hasLength(1));
          verifyNever(() => client.schedule(any()));
        },
      );

      test('retries at once after a reconnect', () async {
        await enqueue(buildEvent(), status: ScheduledPostStatus.scheduled);
        now = publishAt.add(const Duration(minutes: 10));
        await coordinator.initialize();
        await pumpEventQueue();
        expect(broadcasts, hasLength(1));

        reconnect.add(null);
        await pumpEventQueue();

        expect(broadcasts, hasLength(2));
      });

      test('retries at once when the app comes back', () async {
        await enqueue(buildEvent(), status: ScheduledPostStatus.scheduled);
        now = publishAt.add(const Duration(minutes: 10));
        await coordinator.initialize();
        await pumpEventQueue();
        expect(broadcasts, hasLength(1));

        foreground
          ..add(false)
          ..add(true);
        await pumpEventQueue();

        expect(broadcasts, hasLength(2));
      });
    });
  });
}
