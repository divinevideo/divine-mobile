// ABOUTME: Tests for ScheduledPostsBloc: the list follows the outbox and the
// ABOUTME: relay's remote entries, and each action maps its outcome.

import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/scheduled_posts/scheduled_posts_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:openvine/services/scheduled_post_coordinator.dart';

class _MockScheduledPostsRepository extends Mock
    implements ScheduledPostsRepository {}

class _MockScheduledPostCoordinator extends Mock
    implements ScheduledPostCoordinator {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockDraft extends Mock implements DivineVideoDraft {}

void main() {
  const owner =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  final publishAt = DateTime.utc(2026, 9, 23, 9);

  late _MockScheduledPostsRepository repository;
  late _MockScheduledPostCoordinator coordinator;
  late _MockDraftStorageService draftService;
  late StreamController<List<ScheduledPost>> outbox;
  late StreamController<void> remoteChanges;

  Event buildEvent({String d = 'video-1'}) => Event(
    owner,
    34236,
    [
      ['d', d],
      ['title', 'Plants'],
      ['image', 'https://cdn.example.com/thumb.jpg'],
    ],
    'A plant video',
    createdAt: publishAt.millisecondsSinceEpoch ~/ 1000,
  );

  ScheduledPost post(
    Event event, {
    ScheduledPostStatus status = ScheduledPostStatus.scheduled,
    String draftId = 'draft-1',
  }) => ScheduledPost(
    eventId: event.id,
    ownerPubkey: owner,
    draftId: draftId,
    kind: 34236,
    signedEventJson: jsonEncode(event.toJson()),
    publishAt: event.createdAt,
    status: status,
    createdAt: DateTime.utc(2026, 9, 22),
  );

  ScheduledPostServerEntry remote(String eventId) => ScheduledPostServerEntry(
    eventId: eventId,
    kind: 34236,
    publishAt: 1800000000,
    state: ScheduledPostServerState.schedule,
    failureReason: '',
  );

  setUp(() {
    repository = _MockScheduledPostsRepository();
    coordinator = _MockScheduledPostCoordinator();
    draftService = _MockDraftStorageService();
    outbox = StreamController<List<ScheduledPost>>.broadcast();
    remoteChanges = StreamController<void>.broadcast();
    when(() => repository.watch()).thenAnswer((_) => outbox.stream);
    when(
      () => coordinator.serverOnlyChanges,
    ).thenAnswer((_) => remoteChanges.stream);
    when(() => coordinator.serverOnlyPosts).thenReturn(const []);
    when(
      () => coordinator.sweep(force: any(named: 'force')),
    ).thenAnswer((_) async {});
    when(() => draftService.getDraftById(any())).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await outbox.close();
    await remoteChanges.close();
  });

  ScheduledPostsBloc build() => ScheduledPostsBloc(
    repository: repository,
    coordinator: coordinator,
    draftService: draftService,
  );

  group(ScheduledPostsBloc, () {
    group('ScheduledPostsStarted', () {
      blocTest<ScheduledPostsBloc, ScheduledPostsState>(
        'loads the outbox rows with their drafts and drops terminal rows',
        setUp: () {
          final draft = _MockDraft();
          when(() => draft.id).thenReturn('draft-1');
          when(() => draft.title).thenReturn('From the draft');
          when(() => draft.lastModified).thenReturn(DateTime.utc(2026));
          when(
            () => draftService.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);
        },
        build: build,
        act: (bloc) async {
          bloc.add(const ScheduledPostsStarted());
          await pumpEventQueue();
          outbox.add([
            post(buildEvent()),
            post(
              buildEvent(d: 'gone'),
              status: ScheduledPostStatus.published,
              draftId: 'draft-2',
            ),
            post(
              buildEvent(d: 'orphan'),
              status: ScheduledPostStatus.failed,
              draftId: 'draft-3',
            ),
          ]);
        },
        expect: () => [
          const ScheduledPostsState(status: ScheduledPostsStatus.loading),
          isA<ScheduledPostsState>()
              .having((s) => s.status, 'status', ScheduledPostsStatus.loaded)
              .having((s) => s.items.length, 'items', 2)
              .having((s) => s.items[0].title, 'draft title', 'From the draft')
              .having((s) => s.items[1].title, 'tag title', 'Plants')
              .having(
                (s) => s.items[1].thumbnailUrl,
                'thumbnail',
                'https://cdn.example.com/thumb.jpg',
              )
              .having((s) => s.items[1].draft, 'missing draft', isNull)
              .having((s) => s.items[0].publishAt, 'publishAt', publishAt),
        ],
        verify: (_) {
          verify(() => coordinator.sweep(force: true)).called(1);
        },
      );

      blocTest<ScheduledPostsBloc, ScheduledPostsState>(
        'follows the relay entries scheduled from another device',
        build: build,
        act: (bloc) async {
          bloc.add(const ScheduledPostsStarted());
          await pumpEventQueue();
          when(
            () => coordinator.serverOnlyPosts,
          ).thenReturn([remote('f' * 64)]);
          remoteChanges.add(null);
        },
        expect: () => [
          const ScheduledPostsState(status: ScheduledPostsStatus.loading),
          isA<ScheduledPostsState>()
              .having((s) => s.remotePosts.single.eventId, 'remote', 'f' * 64)
              .having((s) => s.isEmpty, 'isEmpty', isFalse),
        ],
      );
    });

    group('ScheduledPostsRefreshRequested', () {
      blocTest<ScheduledPostsBloc, ScheduledPostsState>(
        'forces a sweep and refreshes the remote entries',
        build: build,
        act: (bloc) => bloc.add(const ScheduledPostsRefreshRequested()),
        expect: () => [const ScheduledPostsState()],
        verify: (_) {
          verify(() => coordinator.sweep(force: true)).called(1);
        },
      );
    });

    group('actions', () {
      final event = buildEvent();

      for (final (name, action, outcome, expected) in [
        (
          'cancel',
          ScheduledPostsCancelRequested(event.id),
          ScheduledPostActionOutcome.done,
          ScheduledPostsActionOutcome.cancelled,
        ),
        (
          'reschedule',
          ScheduledPostsRescheduleRequested(event.id, DateTime.utc(2026, 10)),
          ScheduledPostActionOutcome.done,
          ScheduledPostsActionOutcome.rescheduled,
        ),
        (
          'publish now',
          ScheduledPostsPublishNowRequested(event.id),
          ScheduledPostActionOutcome.done,
          ScheduledPostsActionOutcome.publishedNow,
        ),
        (
          'retry',
          ScheduledPostsRetryRequested(event.id),
          ScheduledPostActionOutcome.done,
          ScheduledPostsActionOutcome.retryQueued,
        ),
        (
          'remote cancel',
          ScheduledPostsCancelRemoteRequested(event.id),
          ScheduledPostActionOutcome.done,
          ScheduledPostsActionOutcome.cancelled,
        ),
        (
          'cancel of a post already live',
          ScheduledPostsCancelRequested(event.id),
          ScheduledPostActionOutcome.alreadyPublished,
          ScheduledPostsActionOutcome.alreadyPublished,
        ),
        (
          'publish now while the relay is unreachable',
          ScheduledPostsPublishNowRequested(event.id),
          ScheduledPostActionOutcome.unavailable,
          ScheduledPostsActionOutcome.unavailable,
        ),
        (
          'reschedule that could not sign',
          ScheduledPostsRescheduleRequested(event.id, DateTime.utc(2026, 10)),
          ScheduledPostActionOutcome.failed,
          ScheduledPostsActionOutcome.failed,
        ),
      ]) {
        blocTest<ScheduledPostsBloc, ScheduledPostsState>(
          '$name marks the row busy, then reports ${expected.name}',
          setUp: () {
            when(() => coordinator.cancel(any()))
                .thenAnswer((_) async => outcome);
            when(
              () => coordinator.reschedule(any(), any()),
            ).thenAnswer((_) async => outcome);
            when(
              () => coordinator.publishNow(any()),
            ).thenAnswer((_) async => outcome);
            when(() => coordinator.retry(any()))
                .thenAnswer((_) async => outcome);
            when(
              () => coordinator.cancelRemote(any()),
            ).thenAnswer((_) async => outcome);
          },
          build: build,
          act: (bloc) => bloc.add(action),
          expect: () => [
            ScheduledPostsState(busyEventId: event.id),
            ScheduledPostsState(lastAction: expected, actionCount: 1),
          ],
        );
      }

      blocTest<ScheduledPostsBloc, ScheduledPostsState>(
        'reschedule hands the new time to the coordinator',
        setUp: () {
          when(
            () => coordinator.reschedule(any(), any()),
          ).thenAnswer((_) async => ScheduledPostActionOutcome.done);
        },
        build: build,
        act: (bloc) => bloc.add(
          ScheduledPostsRescheduleRequested(event.id, DateTime.utc(2026, 10)),
        ),
        verify: (_) {
          verify(
            () => coordinator.reschedule(event.id, DateTime.utc(2026, 10)),
          ).called(1);
        },
      );

      blocTest<ScheduledPostsBloc, ScheduledPostsState>(
        'the action counter keeps rising across identical outcomes',
        setUp: () {
          when(
            () => coordinator.retry(any()),
          ).thenAnswer((_) async => ScheduledPostActionOutcome.done);
        },
        build: build,
        act: (bloc) => bloc
          ..add(ScheduledPostsRetryRequested(event.id))
          ..add(ScheduledPostsRetryRequested(event.id)),
        expect: () => [
          ScheduledPostsState(busyEventId: event.id),
          const ScheduledPostsState(
            lastAction: ScheduledPostsActionOutcome.retryQueued,
            actionCount: 1,
          ),
          ScheduledPostsState(
            busyEventId: event.id,
            lastAction: ScheduledPostsActionOutcome.retryQueued,
            actionCount: 1,
          ),
          const ScheduledPostsState(
            lastAction: ScheduledPostsActionOutcome.retryQueued,
            actionCount: 2,
          ),
        ],
      );
    });
  });
}
