// ABOUTME: Tests for VideoEngagementBloc — likers / reposters list loading.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group(VideoEngagementBloc, () {
    late _MockLikesRepository likesRepository;
    late _MockRepostsRepository repostsRepository;
    late _MockProfileRepository profileRepository;
    late _MockVideosRepository videosRepository;

    const testEventId = 'event-id-1';
    const testAddressableId = '34236:authorpubkey:dtag';
    const liker1 = 'liker-pubkey-1';
    const liker2 = 'liker-pubkey-2';
    const reposter1 = 'reposter-pubkey-1';

    setUp(() {
      likesRepository = _MockLikesRepository();
      repostsRepository = _MockRepostsRepository();
      profileRepository = _MockProfileRepository();
      videosRepository = _MockVideosRepository();

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
      videosRepository: videosRepository,
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

      // A page whose every row the block filter removed arrives empty but
      // still carrying a cursor. Collapsing that to "done" would end the
      // list with pages still to come.
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'a fully filtered page advances the cursor and keeps paging',
        setUp: () => stubPage([], nextCursor: 'cursor-3'),
        build: createBloc,
        seed: loaded,
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        expect: () => [
          loaded(loadMoreStatus: VideoEngagementLoadMoreStatus.inProgress),
          loaded(nextCursor: 'cursor-3'),
        ],
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([liker1]));
          expect(bloc.state.hasMore, isTrue);
        },
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
          ).thenAnswer((_) async => const RepostersPage(pubkeys: [reposter1]));
        },
        build: () => createBloc(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([reposter1]));
          expect(bloc.state.hasMore, isFalse);
        },
      );
    });

    test('initial state has type and initial status', () async {
      final bloc = createBloc();
      expect(bloc.state.type, VideoEngagementType.likers);
      expect(bloc.state.status, VideoEngagementStatus.initial);
      expect(bloc.state.pubkeys, isEmpty);
      await bloc.close();
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

      // #10846: an unfinished relay read that found nobody is not "nobody".
      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'emits [loading, failure] when an unfinished read found nobody',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer(
            (_) async => const LikersPage(pubkeys: [], isComplete: false),
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
            status: VideoEngagementStatus.failure,
          ),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'shows the people an unfinished read found, marked incomplete',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer(
            (_) async => const LikersPage(pubkeys: [liker1], isComplete: false),
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
            isComplete: false,
          ),
        ],
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
          ).thenAnswer((_) async => const RepostersPage(pubkeys: [reposter1]));
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
        'emits [loading, failure] when an unfinished read found nobody',
        setUp: () {
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer(
            (_) async => const RepostersPage(pubkeys: [], isComplete: false),
          );
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

    // #10929: a link that names the video by coordinate reaches the bloc as
    // its d tag. The API resolves a bare d tag to the newest video any
    // account posted under it, and 404s on a 64-hex one, so the bloc
    // resolves the coordinate to that author's event first.
    group('coordinate links', () {
      const authorPubkey =
          '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
      // A Divine upload's d tag is the file's sha256: 64-hex, like an id.
      const hexDTag =
          '5f3a2c1d0e9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e3d2c1b0a9f8e7d6c5b4a39';
      const hexCoordinate = '34236:$authorPubkey:$hexDTag';
      const resolvedEventId =
          'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';

      VideoEvent videoWithId(String id) => VideoEvent(
        id: id,
        pubkey: authorPubkey,
        createdAt: 1700000000,
        content: '',
        timestamp: DateTime.utc(2023, 11, 14),
      );

      VideoEngagementBloc blocFor({
        String eventId = hexDTag,
        String? addressableId = hexCoordinate,
        VideoEngagementType type = VideoEngagementType.likers,
      }) => VideoEngagementBloc(
        eventId: eventId,
        type: type,
        likesRepository: likesRepository,
        repostsRepository: repostsRepository,
        videosRepository: videosRepository,
        profileRepository: profileRepository,
        addressableId: addressableId,
      );

      void stubLookup(String coordinate, VideoRouteLookupResult result) {
        when(() => videosRepository.lookupVideoForRouteId(coordinate))
            .thenAnswer((_) async => result);
      }

      void stubLikers(String eventId, String coordinate, List<String> pks) {
        when(
          () => likesRepository.fetchEventLikers(
            eventId: eventId,
            addressableId: coordinate,
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async => LikersPage(pubkeys: pks));
      }

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'queries likers by the event a 64-hex d tag coordinate resolves to',
        setUp: () {
          stubLookup(
            hexCoordinate,
            VideoRouteFound(videoWithId(resolvedEventId)),
          );
          stubLikers(resolvedEventId, hexCoordinate, [liker1]);
          stubLikers(hexDTag, hexCoordinate, [liker2]);
        },
        build: blocFor,
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
            resolvedEventId: resolvedEventId,
          ),
        ],
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'resolves a non-hex d tag coordinate the same way',
        setUp: () {
          const dTag = 'ip1dd9tAlmw';
          const coordinate = '34236:$authorPubkey:$dTag';
          stubLookup(coordinate, VideoRouteFound(videoWithId(resolvedEventId)));
          stubLikers(resolvedEventId, coordinate, [liker1]);
          stubLikers(dTag, coordinate, [liker2]);
        },
        build: () => blocFor(
          eventId: 'ip1dd9tAlmw',
          addressableId: '34236:$authorPubkey:ip1dd9tAlmw',
        ),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, equals(VideoEngagementStatus.success));
          expect(bloc.state.pubkeys, equals([liker1]));
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'queries reposters by the resolved event',
        setUp: () {
          stubLookup(
            hexCoordinate,
            VideoRouteFound(videoWithId(resolvedEventId)),
          );
          when(
            () => repostsRepository.fetchEventReposters(
              eventId: resolvedEventId,
              addressableId: hexCoordinate,
            ),
          ).thenAnswer((_) async => const RepostersPage(pubkeys: [reposter1]));
        },
        build: () => blocFor(type: VideoEngagementType.reposters),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, equals(VideoEngagementStatus.success));
          expect(bloc.state.pubkeys, equals([reposter1]));
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'pages on with the resolved event without looking it up again',
        setUp: () {
          when(
            () => likesRepository.fetchEventLikers(
              eventId: resolvedEventId,
              addressableId: hexCoordinate,
              cursor: 'cursor-2',
            ),
          ).thenAnswer((_) async => const LikersPage(pubkeys: [liker2]));
        },
        build: blocFor,
        seed: () => const VideoEngagementState(
          type: VideoEngagementType.likers,
          status: VideoEngagementStatus.success,
          pubkeys: [liker1],
          nextCursor: 'cursor-2',
          resolvedEventId: resolvedEventId,
        ),
        act: (bloc) => bloc.add(const VideoEngagementLoadMoreRequested()),
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([liker1, liker2]));
          verifyNever(() => videosRepository.lookupVideoForRouteId(any()));
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'falls back to the d tag when no video answers for the coordinate',
        setUp: () {
          stubLookup(hexCoordinate, const VideoRouteMissing());
          stubLikers(hexDTag, hexCoordinate, [liker1]);
        },
        build: blocFor,
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

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'falls back to the d tag without failing when the lookup is '
        'unreachable',
        setUp: () {
          when(() => videosRepository.lookupVideoForRouteId(hexCoordinate))
              .thenThrow(const FunnelcakeException('offline'));
          stubLikers(hexDTag, hexCoordinate, [liker1]);
        },
        build: blocFor,
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, equals(VideoEngagementStatus.success));
          expect(bloc.state.pubkeys, equals([liker1]));
        },
        errors: () => isEmpty,
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'does not look anything up when the link named an exact event',
        setUp: () => stubLikers(resolvedEventId, hexCoordinate, [liker1]),
        // In-app pushes send the event id and its coordinate, whose d tag
        // differs from the id.
        build: () => blocFor(eventId: resolvedEventId),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([liker1]));
          verifyNever(() => videosRepository.lookupVideoForRouteId(any()));
        },
      );

      blocTest<VideoEngagementBloc, VideoEngagementState>(
        'does not resolve a coordinate that names no valid author',
        setUp: () =>
            stubLikers(hexDTag, '34236:not-a-pubkey:$hexDTag', [liker1]),
        // The route lookup would read it as a bare d tag: the unscoped
        // lookup this resolution exists to avoid.
        build: () => blocFor(addressableId: '34236:not-a-pubkey:$hexDTag'),
        act: (bloc) => bloc.add(const VideoEngagementLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.pubkeys, equals([liker1]));
          verifyNever(() => videosRepository.lookupVideoForRouteId(any()));
        },
      );
    });

    group('videoRouteId', () {
      const hexEventId =
          'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
      const coordinate =
          '34236:81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95'
          ':ip1dd9tAlmw';

      VideoEngagementBloc blocFor({
        required String eventId,
        String? addressableId,
      }) => VideoEngagementBloc(
        eventId: eventId,
        type: VideoEngagementType.likers,
        likesRepository: likesRepository,
        repostsRepository: repostsRepository,
        videosRepository: videosRepository,
        profileRepository: profileRepository,
        addressableId: addressableId,
      );

      test('is the hex event id whenever one is known', () {
        // In-app pushes send both; the exact event still wins, so the
        // back fallback for those callers is unchanged.
        final bloc = blocFor(eventId: hexEventId, addressableId: coordinate);
        addTearDown(bloc.close);

        expect(bloc.videoRouteId, equals(hexEventId));
      });

      test('is the coordinate when the event id is only a d tag', () {
        // An naddr1 or coordinate link: the route hands the bloc the d tag
        // as eventId. A bare d tag would send the detail route to an
        // unscoped lookup, so the author-carrying coordinate is preferred.
        final bloc = blocFor(eventId: 'ip1dd9tAlmw', addressableId: coordinate);
        addTearDown(bloc.close);

        expect(bloc.videoRouteId, equals(coordinate));
      });

      test('is the coordinate when a 64-hex event id is its d tag', () {
        // A Divine upload's d tag is the file's sha256, which passes every
        // event-id check (#10929).
        const hexDTag =
            '5f3a2c1d0e9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e3d2c1b0a9f8e7d6c5b4a39';
        const hexCoordinate =
            '34236:81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95'
            ':$hexDTag';
        final bloc = blocFor(eventId: hexDTag, addressableId: hexCoordinate);
        addTearDown(bloc.close);

        expect(bloc.videoRouteId, equals(hexCoordinate));
      });

      test('falls back to the d tag when no coordinate is known', () {
        final bloc = blocFor(eventId: 'ip1dd9tAlmw');
        addTearDown(bloc.close);

        expect(bloc.videoRouteId, equals('ip1dd9tAlmw'));
      });
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
