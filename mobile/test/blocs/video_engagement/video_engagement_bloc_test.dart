// ABOUTME: Tests for VideoEngagementBloc — likers / reposters list loading.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(VideoEngagementBloc, () {
    late _MockLikesRepository likesRepository;
    late _MockRepostsRepository repostsRepository;
    late _MockProfileRepository profileRepository;

    const testEventId = 'event-id-1';
    const testAddressableId = '34236:authorpubkey:dtag';
    const liker1 = 'liker-pubkey-1';
    const liker2 = 'liker-pubkey-2';
    const reposter1 = 'reposter-pubkey-1';

    setUp(() {
      likesRepository = _MockLikesRepository();
      repostsRepository = _MockRepostsRepository();
      profileRepository = _MockProfileRepository();

      // Default stub — batch fetch returns empty map (cache miss is fine).
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => {});
    });

    VideoEngagementBloc createBloc({
      VideoEngagementType type = VideoEngagementType.likers,
      String? addressableId = testAddressableId,
    }) => VideoEngagementBloc(
      eventId: testEventId,
      type: type,
      likesRepository: likesRepository,
      repostsRepository: repostsRepository,
      profileRepository: profileRepository,
      addressableId: addressableId,
    );

    // #9358: Funnelcake caps a page at 500, so the Liked-by list showed 500
    // of 5,565 people and simply ended.
    group('VideoEngagementLoadMoreRequested', () {
      const liker3 = 'liker-pubkey-3';

      void stubPage(
        List<String> pubkeys, {
        String? nextCursor,
        String? forCursor,
      }) {
        when(
          () => likesRepository.fetchEventLikers(
            eventId: testEventId,
            addressableId: testAddressableId,
            cursor: forCursor ?? any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => LikersPage(pubkeys: pubkeys, nextCursor: nextCursor),
        );
      }

      VideoEngagementState loaded({
        List<String> pubkeys = const [liker1],
        String? nextCursor = 'cursor-2',
        VideoEngagementLoadMoreStatus loadMoreStatus =
            VideoEngagementLoadMoreStatus.idle,
      }) => VideoEngagementState(
        type: VideoEngagementType.likers,
        status: VideoEngagementStatus.success,
        pubkeys: pubkeys,
        loadMoreStatus: loadMoreStatus,
        nextCursor: nextCursor,
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'appends the next page and carries the new cursor',
        setUp: () => stubPage([liker2, liker3], nextCursor: 'cursor-3'),
        build: createBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        expect: () => [
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress),
          loaded(
            pubkeys: const [liker1, liker2, liker3],
            nextCursor: 'cursor-3',
          ),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'clears the cursor on the final page',
        setUp: () => stubPage([liker2]),
        build: createBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        expect: () => [
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress),
          loaded(pubkeys: const [liker1, liker2], nextCursor: null),
        ],
        verify: (bloc) => expect(bloc.state.hasMore, isFalse),
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'drops a pubkey already shown on an earlier page',
        setUp: () => stubPage([liker1, liker2]),
        build: createBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        expect: () => [
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress),
          loaded(pubkeys: const [liker1, liker2], nextCursor: null),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'warms profiles only for the pubkeys that just arrived',
        setUp: () => stubPage([liker1, liker2]),
        build: createBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        verify: (_) {
          verify(
            () => profileRepository.fetchBatchProfiles(pubkeys: [liker2]),
          ).called(1);
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'ignores the event when the list is already complete',
        build: createBloc,
        seed: () => loaded(nextCursor: null),
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        expect: () => const <VideoEngagementState>[],
        verify: (_) {
          verifyNever(
            () => likesRepository.fetchEventLikers(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
              cursor: any(named: 'cursor'),
            ),
          );
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'keeps the loaded list and its cursor when the page fails',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
              cursor: any(named: 'cursor'),
            ),
          ).thenThrow(Exception('relay down'));
        },
        build: createBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress),
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.failure),
        ],
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([liker1]));
          expect(bloc.state.nextCursor, equals('cursor-2'));
        },
      );

      // The view triggers the next page from its item builder, so a failure
      // that rebuilt the list would re-fire forever without this guard.
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'does not fetch again after a failure unless asked to retry',
        setUp: () => stubPage([liker2]),
        build: createBloc,
        seed: () =>
            loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.failure),
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        expect: () => const <VideoEngagementState>[],
        verify: (_) {
          verifyNever(
            () => likesRepository.fetchEventLikers(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
              cursor: any(named: 'cursor'),
            ),
          );
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'an explicit retry resumes from the same cursor',
        setUp: () => stubPage([liker2], forCursor: 'cursor-2'),
        build: createBloc,
        seed: () =>
            loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.failure),
        act: (bloc) =>
            bloc.add(const VideoEngagementLoadMoreRequested(retry: true)),
        expect: () => [
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress),
          loaded(pubkeys: const [liker1, liker2], nextCursor: null),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'reposters never report a further page',
        setUp: () {
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => const [reposter1]);
        },
        build: () => createBloc(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([reposter1]));
          expect(bloc.state.hasMore, isFalse);
        },
      );
    });

    test('initial state has type and initial status', () {
      final bloc = createBloc();
      expect(bloc.state.type, VideoEngagementType.likers);
      expect(bloc.state.status, VideoEngagementStatus.initial);
      expect(bloc.state.pubkeys, isEmpty);
      bloc.close();
    });

    group('VideoEngagementLoadRequested for likers', () {
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, success] with pubkeys from likes repo',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer(
            (_) async => const LikersPage(pubkeys: [liker1, liker2]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.success,
            pubkeys: [liker1, liker2],
          ),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, failure] and reports error when fetch throws',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenThrow(const FetchLikersFailedException('relay down'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.failure,
          ),
        ],
        errors: () => [isA<FetchLikersFailedException>()],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'forwards null addressableId when none was provided',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
            ),
          ).thenAnswer(
            (_) async => const LikersPage(pubkeys: [liker1]),
          );
        },
        build: () => createBloc(addressableId: null),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (_) {
          verify(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
            ),
          ).called(1);
          verifyNever(
            () => repostsRepository.fetchEventReposters(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );
    });

    group('VideoEngagementLoadRequested for reposters', () {
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, success] with pubkeys from reposts repo',
        setUp: () {
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => const [reposter1]);
        },
        build: () => createBloc(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.success,
            pubkeys: [reposter1],
          ),
        ],
        verify: (_) {
          verifyNever(
            () => likesRepository.fetchEventLikers(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, failure] and reports error when fetch throws',
        setUp: () {
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenThrow(const FetchRepostersFailedException('relay down'));
        },
        build: () => createBloc(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.reposters,
            status: VideoEngagementStatus.failure,
          ),
        ],
        errors: () => [isA<FetchRepostersFailedException>()],
      );
    });

    group('profile batch prefetch', () {
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'calls fetchBatchProfiles with likers pubkeys after successful fetch',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer(
            (_) async => const LikersPage(pubkeys: [liker1, liker2]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (_) {
          verify(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: [liker1, liker2],
            ),
          ).called(1);
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits success even when fetchBatchProfiles times out',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer(
            (_) async => const LikersPage(pubkeys: [liker1]),
          );
          // Simulate the TimeoutException that .timeout(2s) throws when the
          // profile fetch exceeds the deadline. The catchError in the bloc must
          // swallow it so success is still emitted.
          when(
            () => profileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) => Future.error(TimeoutException('profile prefetch timed out')),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        expect: () => [
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.loading,
          ),
          const VideoEngagementState(
            type: VideoEngagementType.likers,
            status: VideoEngagementStatus.success,
            pubkeys: [liker1],
          ),
        ],
      );
    });

    group('VideoEngagementState.copyWith', () {
      test('preserves type and updates only supplied fields', () {
        const original = VideoEngagementState(
          type: VideoEngagementType.likers,
          pubkeys: [liker1],
        );

        final copied = original.copyWith(
          status: VideoEngagementStatus.loading,
        );

        expect(copied.type, VideoEngagementType.likers);
        expect(copied.status, VideoEngagementStatus.loading);
        expect(copied.pubkeys, const [liker1]);
      });

      test('returns new pubkeys when supplied', () {
        const original = VideoEngagementState(
          type: VideoEngagementType.reposters,
        );

        final copied = original.copyWith(
          status: VideoEngagementStatus.success,
          pubkeys: const [reposter1],
        );

        expect(copied.pubkeys, const [reposter1]);
        expect(copied.type, VideoEngagementType.reposters);
      });
    });
  });
}
