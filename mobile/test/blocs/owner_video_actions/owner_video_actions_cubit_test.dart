// ABOUTME: Unit tests for owner-only video action business logic.
// ABOUTME: Verifies delete success, typed failures, and exception handling.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

void main() {
  group(OwnerVideoActionsCubit, () {
    final video = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
    );
    final secondVideo = VideoEvent(
      id: '123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385264,
      content: 'Second test video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385264 * 1000),
      videoUrl: 'https://example.com/second.mp4',
    );

    late _MockContentDeletionService deletionService;
    late _MockVideoEventService videoEventService;
    late _MockEnforcementRepository enforcementRepository;

    OwnerVideoActionsCubit buildCubit() => OwnerVideoActionsCubit(
      contentDeletionService: () async => deletionService,
      videoEventService: () => videoEventService,
      enforcementRepository: () => enforcementRepository,
    );

    setUp(() {
      deletionService = _MockContentDeletionService();
      videoEventService = _MockVideoEventService();
      enforcementRepository = _MockEnforcementRepository();
      when(() => enforcementRepository.enforce(any())).thenAnswer(
        (_) async => const CreatorDeleteEnforcementResult.confirmed(),
      );
    });

    test('passes the published signed deletion event to cleanup', () async {
      final event = Event(
        video.pubkey,
        5,
        [
          ['e', video.id],
        ],
        'Delete this video',
        createdAt: 1757385263,
      );
      event.sig = '12' * 64;
      final cleanupCompleter = Completer<CreatorDeleteEnforcementResult>();
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer(
        (_) async => DeleteResult.createSuccess(
          event.id,
          acceptance: DeleteAcceptance.someRelays,
          deleteEvent: event,
        ),
      );
      when(
        () => enforcementRepository.enforce(
          event.id,
          deletionEvent: any(named: 'deletionEvent'),
        ),
      ).thenAnswer((_) => cleanupCompleter.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.deleteVideo(video);
      final completion = cubit.cleanupCompletionFor(video.id);
      expect(completion, isNotNull);
      final suppliedEvent = verify(
        () => enforcementRepository.enforce(
          event.id,
          deletionEvent: captureAny(named: 'deletionEvent'),
        ),
      ).captured.single;
      expect(suppliedEvent, event.toJson());
      cleanupCompleter.complete(
        const CreatorDeleteEnforcementResult.confirmed(),
      );
      expect(
        (await completion)!.cleanupStatus,
        OwnerVideoCleanupStatus.confirmed,
      );
    });

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'removes the video locally after delete success',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.everyRelay,
          ),
        );
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        isA<OwnerVideoActionsState>().having(
          (state) => state.forVideo(video.id).deleteStatus,
          'deleteStatus',
          OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.forVideo(video.id).deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.success,
            )
            .having(
              (state) => state.forVideo(video.id).deleteResult?.success,
              'deleteResult.success',
              isTrue,
            )
            .having(
              (state) => state.forVideo(video.id).deleteResult?.deleteEventId,
              'deleteResult.deleteEventId',
              'delete-event-id',
            ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.forVideo(video.id).deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.success,
            )
            .having(
              (state) => state.forVideo(video.id).cleanupStatus,
              'cleanupStatus',
              OwnerVideoCleanupStatus.confirmed,
            ),
      ],
      verify: (_) {
        verify(
          () => videoEventService.removeVideoEventCompletely(video),
        ).called(1);
      },
    );

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'surfaces typed delete failures without removing the video locally',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.failure(
            'Relay rejected delete event',
            DeleteFailureKind.relayRejected,
          ),
        );
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        isA<OwnerVideoActionsState>().having(
          (state) => state.forVideo(video.id).deleteStatus,
          'deleteStatus',
          OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.forVideo(video.id).deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.failure,
            )
            .having(
              (state) => state.forVideo(video.id).deleteResult?.success,
              'deleteResult.success',
              isFalse,
            )
            .having(
              (state) => state.forVideo(video.id).deleteResult?.failureKind,
              'deleteResult.failureKind',
              DeleteFailureKind.relayRejected,
            ),
      ],
      verify: (_) {
        verifyNever(() => videoEventService.removeVideoEventCompletely(video));
      },
    );

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'keeps relay success while cleanup confirmation is delayed',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.everyRelay,
          ),
        );
        when(() => enforcementRepository.enforce('delete-event-id')).thenAnswer(
          (_) async => const CreatorDeleteEnforcementResult.delayed(),
        );
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        isA<OwnerVideoActionsState>().having(
          (state) => state.forVideo(video.id).deleteStatus,
          'deleteStatus',
          OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>().having(
          (state) => state.forVideo(video.id).cleanupStatus,
          'cleanupStatus',
          OwnerVideoCleanupStatus.inProgress,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.forVideo(video.id).deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.success,
            )
            .having(
              (state) => state.forVideo(video.id).cleanupStatus,
              'cleanupStatus',
              OwnerVideoCleanupStatus.delayed,
            ),
      ],
    );

    test('returns after relay success without waiting for cleanup', () async {
      final cleanupCompleter = Completer<CreatorDeleteEnforcementResult>();
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer(
        (_) async => DeleteResult.createSuccess(
          'delete-event-id',
          acceptance: DeleteAcceptance.everyRelay,
        ),
      );
      when(
        () => enforcementRepository.enforce('delete-event-id'),
      ).thenAnswer((_) => cleanupCompleter.future);
      final cubit = buildCubit();

      final start = await cubit.deleteVideo(video);

      expect(start, OwnerVideoDeleteStart.started);
      expect(
        cubit.state.forVideo(video.id).cleanupStatus,
        OwnerVideoCleanupStatus.inProgress,
      );
      expect(cubit.cleanupCompletionFor(video.id), isNotNull);

      cleanupCompleter.complete(
        const CreatorDeleteEnforcementResult.confirmed(),
      );
      final terminal = await cubit.cleanupCompletionFor(video.id);
      expect(terminal!.cleanupStatus, OwnerVideoCleanupStatus.confirmed);
      await cubit.close();
    });

    test('completes cleanup as delayed when enforcement throws', () async {
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer(
        (_) async => DeleteResult.createSuccess(
          'delete-event-id',
          acceptance: DeleteAcceptance.everyRelay,
        ),
      );
      when(
        () => enforcementRepository.enforce('delete-event-id'),
      ).thenAnswer(
        (_) => Future.error(StateError('unexpected enforcement failure')),
      );
      final cubit = buildCubit();

      await cubit.deleteVideo(video);
      final terminal = await cubit
          .cleanupCompletionFor(video.id)!
          .timeout(const Duration(seconds: 1));

      expect(terminal.cleanupStatus, OwnerVideoCleanupStatus.delayed);
      expect(
        cubit.state.forVideo(video.id).cleanupStatus,
        OwnerVideoCleanupStatus.delayed,
      );
      await cubit.close();
    });

    test('ignores a second delete while the first is in flight', () async {
      final relayCompleter = Completer<DeleteResult>();
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer((_) => relayCompleter.future);
      final cubit = buildCubit();

      final first = cubit.deleteVideo(video);
      await Future<void>.delayed(Duration.zero);
      await cubit.deleteVideo(video);
      relayCompleter.complete(
        DeleteResult.failure('rejected', DeleteFailureKind.relayRejected),
      );
      await first;

      verify(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).called(1);
      await cubit.close();
    });

    test('allows different videos to delete concurrently', () async {
      final firstRelay = Completer<DeleteResult>();
      final secondRelay = Completer<DeleteResult>();
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer((_) => firstRelay.future);
      when(
        () => deletionService.quickDelete(
          video: secondVideo,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer((_) => secondRelay.future);
      final cubit = buildCubit();

      final first = cubit.deleteVideo(video);
      final second = cubit.deleteVideo(secondVideo);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.isDeleteInProgress(video.id), isTrue);
      expect(cubit.isDeleteInProgress(secondVideo.id), isTrue);
      verify(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).called(1);
      verify(
        () => deletionService.quickDelete(
          video: secondVideo,
          reason: DeleteReason.personalChoice,
        ),
      ).called(1);

      firstRelay.complete(
        DeleteResult.failure('rejected', DeleteFailureKind.relayRejected),
      );
      secondRelay.complete(
        DeleteResult.failure('rejected', DeleteFailureKind.relayRejected),
      );
      await Future.wait([first, second]);
      await cubit.close();
    });

    test('keeps resolved dependencies alive after the cubit closes', () async {
      final relayCompleter = Completer<DeleteResult>();
      var surfaceDisposed = false;
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer((_) => relayCompleter.future);
      final cubit = OwnerVideoActionsCubit(
        contentDeletionService: () {
          if (surfaceDisposed) throw StateError('surface disposed');
          return Future.value(deletionService);
        },
        videoEventService: () {
          if (surfaceDisposed) throw StateError('surface disposed');
          return videoEventService;
        },
        enforcementRepository: () {
          if (surfaceDisposed) throw StateError('surface disposed');
          return enforcementRepository;
        },
      );

      final deletion = cubit.deleteVideo(video);
      await Future<void>.delayed(Duration.zero);
      surfaceDisposed = true;
      await cubit.close();
      relayCompleter.complete(
        DeleteResult.createSuccess(
          'delete-event-id',
          acceptance: DeleteAcceptance.everyRelay,
        ),
      );
      await deletion;
      await cubit.cleanupCompletionFor(video.id);

      verify(
        () => videoEventService.removeVideoEventCompletely(video),
      ).called(1);
      verify(() => enforcementRepository.enforce('delete-event-id')).called(1);
    });

    blocTest<OwnerVideoActionsCubit, OwnerVideoActionsState>(
      'reports unknown failure when delete throws',
      build: buildCubit,
      setUp: () {
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenThrow(Exception('network failed'));
      },
      act: (cubit) => cubit.deleteVideo(video),
      expect: () => [
        isA<OwnerVideoActionsState>().having(
          (state) => state.forVideo(video.id).deleteStatus,
          'deleteStatus',
          OwnerVideoDeleteStatus.deleting,
        ),
        isA<OwnerVideoActionsState>()
            .having(
              (state) => state.forVideo(video.id).deleteStatus,
              'deleteStatus',
              OwnerVideoDeleteStatus.failure,
            )
            .having(
              (state) => state.forVideo(video.id).deleteResult?.success,
              'deleteResult.success',
              isFalse,
            )
            .having(
              (state) => state.forVideo(video.id).deleteResult?.failureKind,
              'deleteResult.failureKind',
              DeleteFailureKind.unknown,
            ),
      ],
      verify: (_) {
        verifyNever(() => videoEventService.removeVideoEventCompletely(video));
      },
    );
  });
}
