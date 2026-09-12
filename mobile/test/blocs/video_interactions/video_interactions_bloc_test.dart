// ABOUTME: Tests for VideoInteractionsBloc - per-video interactions management
// ABOUTME: Tests fetching counts, toggling likes, and state synchronization

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _CapturingObserver extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  group('VideoInteractionsBloc', () {
    late _MockLikesRepository mockLikesRepository;
    late _MockCommentsRepository mockCommentsRepository;
    late _MockRepostsRepository mockRepostsRepository;
    late StreamController<List<String>> likedIdsController;
    late StreamController<Set<String>> likedAddressableIdsController;
    late StreamController<Set<String>> repostedIdsController;

    const testEventId = 'test-event-id';
    const testAuthorPubkey = 'test-author-pubkey';
    const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';

    setUp(() {
      mockLikesRepository = _MockLikesRepository();
      mockCommentsRepository = _MockCommentsRepository();
      mockRepostsRepository = _MockRepostsRepository();
      likedIdsController = StreamController<List<String>>.broadcast();
      likedAddressableIdsController = StreamController<Set<String>>.broadcast();
      repostedIdsController = StreamController<Set<String>>.broadcast();

      // Default stub for watchLikedEventIds
      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => likedIdsController.stream);

      // Default stub for watchLikedAddressableIds
      when(
        () => mockLikesRepository.watchLikedAddressableIds(),
      ).thenAnswer((_) => likedAddressableIdsController.stream);

      // Default stub for watchRepostedAddressableIds
      when(
        () => mockRepostsRepository.watchRepostedAddressableIds(),
      ).thenAnswer((_) => repostedIdsController.stream);

      // Default stub for isReposted (returns false by default)
      when(
        () => mockRepostsRepository.isReposted(any()),
      ).thenAnswer((_) async => false);
    });

    tearDown(() {
      likedIdsController.close();
      likedAddressableIdsController.close();
      repostedIdsController.close();
    });

    VideoInteractionsBloc createBloc({
      String? addressableId,
      int? initialLikeCount,
      int? archivedLikeCount,
      int? initialCommentCount,
      int? initialRepostCount,
    }) => VideoInteractionsBloc(
      eventId: testEventId,
      authorPubkey: testAuthorPubkey,
      likesRepository: mockLikesRepository,
      commentsRepository: mockCommentsRepository,
      repostsRepository: mockRepostsRepository,
      addressableId: addressableId,
      initialLikeCount: initialLikeCount,
      archivedLikeCount: archivedLikeCount,
      initialCommentCount: initialCommentCount,
      initialRepostCount: initialRepostCount,
    );

    test('initial state is initial with default values', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoInteractionsStatus.initial);
      expect(bloc.state.isLiked, isFalse);
      expect(bloc.state.likeCount, isNull);
      expect(bloc.state.isReposted, isFalse);
      expect(bloc.state.repostCount, isNull);
      expect(bloc.state.commentCount, isNull);
      bloc.close();
    });

    test('initial state seeds engagement counts from initial counts', () {
      final bloc = createBloc(
        initialLikeCount: 42,
        initialCommentCount: 3,
        initialRepostCount: 7,
      );
      expect(bloc.state.likeCount, equals(42));
      expect(bloc.state.commentCount, equals(3));
      expect(bloc.state.repostCount, equals(7));
      bloc.close();
    });

    group('VideoInteractionsFetchRequested', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits [loading, success] with fetched data when all calls succeed',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 5);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 42,
            repostCount: 5,
            commentCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'leaves an unknown addressable like count unknown instead of zero',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => null);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 7);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 32);
        },
        build: () => createBloc(addressableId: testAddressableId),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            commentCount: 7,
            repostCount: 32,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'applies the like and repost counts when the comment count is unknown',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => null);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 5);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 42,
            repostCount: 5,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6022: the like floor is addressable + likes-ONLY. The clean
        // addressable relay resolve raises the like count above the seed, but
        // comment and repost counts are NOT floored — their higher relay
        // values must not overwrite the seeded display counts.
        'floors only the like count up to the addressable relay resolve; '
        'comments and reposts keep their seed',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 100);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 7);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 32);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          likeCount: 1,
          commentCount: 0,
          repostCount: 0,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 1,
            commentCount: 0,
            repostCount: 0,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 100,
            commentCount: 0,
            repostCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // The relay is still queried so unseeded blocs can use live counts,
        // but a seeded display count from the feed payload must not be
        // replaced by relay COUNT results, which can aggregate unrelated
        // historical reactions.
        'fetches relay like count but preserves seeded initialLikeCount',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => true);
          // Relay returns a higher count than the seeded REST value, simulating
          // the common case where new likes arrived after the REST snapshot.
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 120);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 5);
        },
        build: () => createBloc(initialLikeCount: 100),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 100,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 100,
            repostCount: 5,
            commentCount: 10,
          ),
        ],
        verify: (_) {
          verify(() => mockLikesRepository.getLikeCount(testEventId)).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6022: for addressable (Kind 34236) videos, getLikeCount resolves the
        // clean distinct-liker set. When that resolve exceeds the funnelcake
        // seed (e.g. the seed undercounts due to ingestion lag), the floor
        // raises the displayed count to the relay value. It only ever raises,
        // never lowers (see the relay-0 regression tests below).
        'raises the addressable like count to the relay resolve when it '
        'exceeds the seed (#6022)',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 75);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 3);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 2);
        },
        build: () =>
            createBloc(addressableId: testAddressableId, initialLikeCount: 50),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 50,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 75,
            repostCount: 2,
            commentCount: 3,
          ),
        ],
        verify: (_) {
          verify(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6022 case A: funnelcake returned reactions:0 so the seed is 0 (not
        // null). The old `seed ?? fetched` kept 0 and hid real relay likes; the
        // floor raises a zero addressable seed to the relay resolve.
        'raises a zero addressable seed to the relay resolve (#6022)',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 8);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 0);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 0);
        },
        build: () =>
            createBloc(addressableId: testAddressableId, initialLikeCount: 0),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 0,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 8,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6022 D3: the floor keeps the archival (classic Vine) baseline out of
        // the Nostr floor. Seed 102 = 100 archival + 2 Nostr; the relay resolves
        // 5 Nostr likes. A whole-seed max would keep 102 and MISS the extra
        // Nostr likes; the Nostr-portion floor yields 100 + max(2, 5) = 105.
        'keeps archival likes out of the Nostr floor and surfaces newly '
        'resolved Nostr likes (#6022)',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 5);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 0);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 0);
        },
        build: () => createBloc(
          addressableId: testAddressableId,
          initialLikeCount: 102,
          archivedLikeCount: 100,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 102,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 105,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6022: guards the seed-dominant branch — when the seed already
        // exceeds the archival + relay-resolved Nostr count, a non-zero relay
        // resolve below it leaves the seed intact (the raise direction is
        // covered by the tests above).
        'never lowers an addressable seed below the relay resolve (#6022)',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 40);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 0);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 0);
        },
        build: () =>
            createBloc(addressableId: testAddressableId, initialLikeCount: 100),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 100,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 100,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // Regression for #4432: after a metadata edit the new event_id has
        // no #e reactions yet, and the divine relay's #a COUNT for kind 7
        // can transiently return 0. _mergeUpdatedVideo carries
        // nostrLikeCount forward into the per-video bloc seed, so a
        // relay-fetched 0 here must not stomp it for addressable videos.
        // Mirrors the skip-zero guard in
        // VideoEventService._executeLikeCountBatchFetch.
        'does not overwrite a seeded non-zero likeCount with a relay 0 for '
        'addressable videos (regression for #4432)',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 0);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 0);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 0);
        },
        build: () =>
            createBloc(addressableId: testAddressableId, initialLikeCount: 5),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 5,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 5, // Preserved — relay 0 did not stomp the seed.
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // Even for non-addressable videos, seeded feed counts are the display
        // baseline. A relay 0 should not erase a count the feed payload
        // already rendered.
        'preserves a seeded likeCount over a relay 0 for non-addressable '
        'videos',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 0);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 0);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 0);
        },
        build: () => createBloc(initialLikeCount: 5),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 5,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 5,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits [loading, success] when video is not liked',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 5);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 0);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 0);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 5,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'fetches repost count by addressable ID per NIP-18 for addressable '
        'videos',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => true);
          // Mock with addressableId parameter for addressable videos
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 10);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 5);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 3);
        },
        build: () => createBloc(addressableId: testAddressableId),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            likeCount: 10,
            repostCount: 3,
            commentCount: 5,
          ),
        ],
        verify: (_) {
          // Uses addressable ID for addressable videos per NIP-18
          verify(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).called(1);
          verifyNever(
            () => mockRepostsRepository.getRepostCountByEventId(any()),
          );
          // Verifies getLikeCount is called with addressableId
          verify(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6020: after a video edit, the bloc is reconstructed with the new
        // (post-edit) event id but the same addressable coordinate. A like
        // recorded against the pre-edit event id must still fill the heart
        // — the bloc composes eventId + addressableId into a single
        // isLikedResolvingCoordinate call and trusts the repository to
        // resolve it, rather than checking isLiked(eventId) alone.
        'heart stays filled when the event id changed after an edit but '
        'the coordinate was already liked (#6020)',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockRepostsRepository.isReposted(testAddressableId),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(
              testEventId,
              addressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 10);
          when(
            () => mockCommentsRepository.getCommentsCount(
              testEventId,
              rootAddressableId: testAddressableId,
            ),
          ).thenAnswer((_) async => 5);
          when(
            () => mockRepostsRepository.getRepostCount(testAddressableId),
          ).thenAnswer((_) async => 3);
        },
        build: () => createBloc(addressableId: testAddressableId),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 10,
            repostCount: 3,
            commentCount: 5,
          ),
        ],
        verify: (_) {
          verify(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
              addressableId: testAddressableId,
            ),
          ).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'fetches repost count by event ID for non-addressable videos',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 10);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 5);
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 2);
        },
        build: createBloc, // No addressable ID
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 10,
            repostCount: 2,
            commentCount: 5,
          ),
        ],
        verify: (_) {
          // Uses event ID for non-addressable videos
          verify(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).called(1);
          verifyNever(() => mockRepostsRepository.getRepostCount(any()));
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits [loading, success] and reports addError when fetch fails',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.loading),
          const VideoInteractionsState(status: VideoInteractionsStatus.success),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not re-fetch when already loading',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.loading,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => <VideoInteractionsState>[],
        verify: (_) {
          verifyNever(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not re-fetch when already loaded successfully',
        setUp: () {
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 42);
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async => 10);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsFetchRequested()),
        expect: () => <VideoInteractionsState>[],
        verify: (_) {
          verifyNever(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: any(named: 'eventId'),
              addressableId: any(named: 'addressableId'),
            ),
          );
        },
      );

      late Completer<void> commentsCountStarted;
      late Completer<int> commentsCountCompleter;

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'preserves optimistic toggle when tap lands mid-fetch',
        setUp: () {
          commentsCountStarted = Completer<void>();
          commentsCountCompleter = Completer<int>();
          // Pre-fetch repository state: not liked, count from initial seed.
          when(
            () => mockLikesRepository.isLikedResolvingCoordinate(
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => false);
          // getLikeCount is now always queried (relay-fresh path). Return the
          // same value as the seed so the mid-fetch optimistic-toggle
          // arithmetic remains identical and the test stays focused on the
          // toggle-during-fetch race, not count reconciliation.
          when(
            () => mockLikesRepository.getLikeCount(testEventId),
          ).thenAnswer((_) async => 10);
          // Hold the fetch open until the test explicitly releases it so
          // the tap deterministically lands between the loading emit and
          // the success emit. Fixed delays were flaky on CI.
          when(
            () => mockCommentsRepository.getCommentsCount(testEventId),
          ).thenAnswer((_) async {
            if (!commentsCountStarted.isCompleted) {
              commentsCountStarted.complete();
            }
            return commentsCountCompleter.future;
          });
          when(
            () => mockRepostsRepository.getRepostCountByEventId(testEventId),
          ).thenAnswer((_) async => 0);
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(initialLikeCount: 10),
        act: (bloc) async {
          bloc.add(const VideoInteractionsFetchRequested());
          await commentsCountStarted.future;
          bloc.add(const VideoInteractionsLikeToggled());
          commentsCountCompleter.complete(0);
        },
        expect: () => [
          // Fetch enters loading. Seeded likeCount=10 carries through.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            likeCount: 10,
          ),
          // Tap lands while fetch awaits relay round-trips.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.loading,
            isLiked: true,
            likeCount: 11,
          ),
          // Fetch resolves: isLiked + likeCount drifted from the
          // pre-fetch baseline (false, 10) to the optimistic values
          // (true, 11), so the success emit MUST preserve them and only
          // apply the untouched commentCount + repostCount.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
            repostCount: 0,
            commentCount: 0,
          ),
        ],
      );
    });

    group('VideoInteractionsLikeToggled', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'likes video when not already liked',
        setUp: () {
          // Non-addressable video: no addressableId or targetKind
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => true);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'likes addressable video with a-tag params',
        setUp: () {
          // Addressable video: includes addressableId and targetKind 34236
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: testAddressableId,
              targetKind: 34236,
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
        verify: (_) {
          verify(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
              addressableId: testAddressableId,
              targetKind: 34236,
            ),
          ).called(1);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'unlikes video when already liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 9,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not allow like count to go below zero',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 0,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles AlreadyLikedException by updating state to liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(const AlreadyLikedException(testEventId));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles NotLikedException by updating state to not liked',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(const NotLikedException(testEventId));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.success),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits optimistic flip then rollback when toggle throws',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          // Optimistic flip lands first so the heart updates immediately.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
          ),
          // Rollback after the publish failure restores the pre-tap heart
          // state. The failure itself is surfaced via addError, asserted
          // below.
          const VideoInteractionsState(status: VideoInteractionsStatus.success),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'rolls back like + count to baseline when toggle throws',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 10,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'rolls back and advances the account restriction revision',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(const LikeAccountRestrictedException());
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 10,
            accountRestrictionRevision: 1,
          ),
        ],
      );

      // Regression for #3503: when the home feed mounts a feed item whose
      // BlocProvider snapshotted a stale LikesRepository (one wrapping a
      // Nostr instance with an empty cached public key), every sendLike
      // surfaces as `StateError('No public key available …')` from
      // `Nostr.ensurePublicKey`. The bloc must roll back the optimistic
      // flip and surface the StateError via `addError` — not crash and
      // not leave the heart filled. The fix in
      // the feed overlay wiring prevents the
      // stale snapshot in the first place; this test pins the bloc-side
      // behaviour so a future change to `ensurePublicKey`'s error type
      // doesn't silently drop the rollback.
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'rolls back when toggle throws StateError from ensurePublicKey',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenThrow(
            StateError(
              'No public key available — signer may not be configured',
            ),
          );
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 6,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 5,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'subscription stream tick during toggle does not double-emit',
        setUp: () {
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async {
            // Repository ticks the stream BEFORE returning, mirroring
            // LikesRepository.likeEvent's optimistic-first ordering. The
            // bloc's optimistic emit has already set state.isLiked=true,
            // so the subscription handler's early-return absorbs this.
            likedIdsController.add([testEventId]);
            await Future<void>.delayed(Duration.zero);
            return true;
          });
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 20));
          bloc.add(const VideoInteractionsLikeToggled());
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // Exactly one emit: optimistic flip with both fields. The
          // stream tick that follows is absorbed by the subscription
          // handler's early-return guard.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'optimistic emit lands before publish settles (fire-and-forget)',
        setUp: () {
          // Hold toggleLike open on a Completer so the publish never
          // settles within the test window. The bloc handler must still
          // emit the optimistic state and return — proving that the
          // network publish does not block the bloc's event queue.
          final completer = Completer<bool>();
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) => completer.future);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
        verify: (bloc) {
          // Settle event has not been dispatched (publish still pending),
          // but state already reflects the optimistic flip.
          expect(bloc.state.isLiked, isTrue);
          expect(bloc.state.likeCount, 11);
        },
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'older restriction cannot roll back a newer tap',
        setUp: () {
          final first = Completer<bool>();
          final second = Completer<bool>();
          var call = 0;
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) => call++ == 0 ? first.future : second.future);
          addTearDown(() {
            if (!first.isCompleted) first.completeError(Exception('unused'));
            if (!second.isCompleted) second.complete(false);
          });
          Future<void>.delayed(const Duration(milliseconds: 20), () {
            second.complete(false);
            first.completeError(const LikeAccountRestrictedException());
          });
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsLikeToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoInteractionsLikeToggled());
        },
        wait: const Duration(milliseconds: 80),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'out-of-band toggle reconciles count from pre-tap baseline',
        setUp: () {
          // User taps to like (optimistic: isLiked=true, count=11), but
          // the repository ends up with isLiked=false (e.g., another
          // device unliked mid-tap). Reconciliation in [_onLikeSettled]
          // applies _adjustCount to the pre-tap baseline (wasCount=10),
          // not the already-incremented current count (11). With
          // currentCount we would emit (false, 10) — incorrect because
          // another transition was missed. With wasCount we emit
          // (false, 9), reflecting the canonical decrement from the
          // baseline.
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async => false);
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsLikeToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
          // Anchored on wasCount=10, not the optimistic 11.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 9,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'closed bloc does not dispatch settle event after publish resolves',
        setUp: () {
          // Simulates scroll-away: user taps, immediately the feed item
          // disposes its bloc, and the publish settles afterward. The
          // unawaited future must check isClosed before dispatching a
          // _VideoInteractionsLikeSettled event — otherwise add() on a
          // closed bloc throws StateError.
          when(
            () => mockLikesRepository.toggleLike(
              eventId: testEventId,
              authorPubkey: testAuthorPubkey,
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return true;
          });
        },
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsLikeToggled());
          // Close before the publish has had a chance to resolve.
          await bloc.close();
        },
        wait: const Duration(milliseconds: 50),
        expect: () => [
          // Only the optimistic emit. The settle event would be a no-op
          // on a closed bloc, but we must guard against it being
          // dispatched at all (StateError on add to closed bloc).
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 11,
          ),
        ],
      );

      test('two blocs run in parallel — neither blocks the other', () async {
        // The architectural invariant rabble called out: a slow publish
        // on video A must not block tapping like on video B. Different
        // videos use different bloc instances; this test pins the
        // contract by keeping both publishes pending and asserting that
        // both blocs emit their optimistic state independently.
        final completerA = Completer<bool>();
        final completerB = Completer<bool>();
        final mockLikesA = _MockLikesRepository();
        final mockLikesB = _MockLikesRepository();
        final mockCommentsA = _MockCommentsRepository();
        final mockCommentsB = _MockCommentsRepository();
        final mockRepostsA = _MockRepostsRepository();
        final mockRepostsB = _MockRepostsRepository();
        final likedStreamA = StreamController<List<String>>.broadcast();
        final likedStreamB = StreamController<List<String>>.broadcast();
        final repostedStreamA = StreamController<Set<String>>.broadcast();
        final repostedStreamB = StreamController<Set<String>>.broadcast();
        addTearDown(() async {
          await likedStreamA.close();
          await likedStreamB.close();
          await repostedStreamA.close();
          await repostedStreamB.close();
        });

        // The closures below cannot be tear-offs because thenAnswer
        // requires a Function(Invocation), but the captured locals are
        // variable references that the analyzer cannot prove constant.
        // ignore_for_file: unnecessary_lambdas
        when(
          () => mockLikesA.watchLikedEventIds(),
        ).thenAnswer((_) => likedStreamA.stream);
        when(
          () => mockLikesB.watchLikedEventIds(),
        ).thenAnswer((_) => likedStreamB.stream);
        when(
          () => mockRepostsA.watchRepostedAddressableIds(),
        ).thenAnswer((_) => repostedStreamA.stream);
        when(
          () => mockRepostsB.watchRepostedAddressableIds(),
        ).thenAnswer((_) => repostedStreamB.stream);

        when(
          () => mockLikesA.toggleLike(
            eventId: 'event-a',
            authorPubkey: testAuthorPubkey,
          ),
        ).thenAnswer((_) => completerA.future);
        when(
          () => mockLikesB.toggleLike(
            eventId: 'event-b',
            authorPubkey: testAuthorPubkey,
          ),
        ).thenAnswer((_) => completerB.future);

        final blocA = VideoInteractionsBloc(
          eventId: 'event-a',
          authorPubkey: testAuthorPubkey,
          likesRepository: mockLikesA,
          commentsRepository: mockCommentsA,
          repostsRepository: mockRepostsA,
        );
        final blocB = VideoInteractionsBloc(
          eventId: 'event-b',
          authorPubkey: testAuthorPubkey,
          likesRepository: mockLikesB,
          commentsRepository: mockCommentsB,
          repostsRepository: mockRepostsB,
        );
        addTearDown(() async {
          await blocA.close();
          await blocB.close();
        });

        // Tap like on A (publish never resolves), then on B.
        blocA.add(const VideoInteractionsLikeToggled());
        blocB.add(const VideoInteractionsLikeToggled());

        // Allow both event loops to drain.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Both blocs already reflect the optimistic flip even though
        // neither publish has settled.
        expect(blocA.state.isLiked, isTrue, reason: 'bloc A should flip');
        expect(blocB.state.isLiked, isTrue, reason: 'bloc B should flip');
        expect(completerA.isCompleted, isFalse);
        expect(completerB.isCompleted, isFalse);

        // Both repositories were called — neither call queued behind the
        // other.
        verify(
          () => mockLikesA.toggleLike(
            eventId: 'event-a',
            authorPubkey: testAuthorPubkey,
          ),
        ).called(1);
        verify(
          () => mockLikesB.toggleLike(
            eventId: 'event-b',
            authorPubkey: testAuthorPubkey,
          ),
        ).called(1);
      });

      test('does not addError after close when _publishLike completes '
          'post-close (regression #4605)', () async {
        // _publishLike runs fire-and-forget via unawaited. The user can
        // scroll the feed and tear down this video's bloc before the
        // publish settles; the catch arm must not addError on a closed
        // bloc.
        final completer = Completer<bool>();
        when(
          () => mockLikesRepository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
        ).thenAnswer((_) => completer.future);

        final observer = _CapturingObserver();
        final priorObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = priorObserver);

        final bloc = createBloc(initialLikeCount: 10)
          ..add(const VideoInteractionsLikeToggled());
        // Let the handler dispatch the optimistic emit and reach the
        // unawaited(_publishLike).
        await Future<void>.delayed(Duration.zero);

        await bloc.close();

        completer.completeError(Exception('relay rejected'));
        await Future<void>.delayed(Duration.zero);

        expect(observer.errors, isEmpty);
      });
    });

    group('VideoInteractionsRepostToggled', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'reposts video when not already reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          // Single optimistic emit: icon + count flip together.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'unreposts video when already reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => false);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: true,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            repostCount: 4,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not allow repost count to go below zero',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) async => false);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: true,
          repostCount: 0,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            repostCount: 0,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'no-ops when no addressable ID is present',
        build: createBloc, // No addressable ID
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        // The handler logs a warning and returns early — no state emit, no
        // addError. Reposting a non-addressable video is a precondition
        // failure, not an exceptional error worth Crashlytics noise.
        expect: () => const <VideoInteractionsState>[],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles AlreadyRepostedException by leaving state reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenThrow(const AlreadyRepostedException(testAddressableId));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          // Optimistic flip stands; the rollback emit produces the same
          // state and is deduped by Equatable.
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'handles NotRepostedException by leaving state not-reposted',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenThrow(const NotRepostedException(testAddressableId));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isReposted: true,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(status: VideoInteractionsStatus.success),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'emits optimistic flip then rollback when toggle throws',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            repostCount: 5,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<Exception>(),
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'subscription stream tick during toggle does not double-emit',
        setUp: () {
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) async {
            // Repository ticks the stream BEFORE returning. The bloc's
            // optimistic emit already set state.isReposted=true, so the
            // subscription handler's early-return absorbs the tick.
            repostedIdsController.add({testAddressableId});
            await Future<void>.delayed(Duration.zero);
            return true;
          });
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 20));
          bloc.add(const VideoInteractionsRepostToggled());
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'optimistic emit lands before publish settles (fire-and-forget)',
        setUp: () {
          final completer = Completer<bool>();
          when(
            () => mockRepostsRepository.toggleRepost(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
              eventId: testEventId,
            ),
          ).thenAnswer((_) => completer.future);
        },
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          repostCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsRepostToggled()),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isReposted: true,
            repostCount: 6,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.isReposted, isTrue);
          expect(bloc.state.repostCount, 6);
        },
      );

      test('does not addError after close when _publishRepost completes '
          'post-close (regression #4605)', () async {
        final completer = Completer<bool>();
        when(
          () => mockRepostsRepository.toggleRepost(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
            eventId: testEventId,
          ),
        ).thenAnswer((_) => completer.future);

        final observer = _CapturingObserver();
        final priorObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = priorObserver);

        final bloc = createBloc(addressableId: testAddressableId)
          ..add(const VideoInteractionsRepostToggled());
        await Future<void>.delayed(Duration.zero);

        await bloc.close();

        completer.completeError(Exception('relay rejected'));
        await Future<void>.delayed(Duration.zero);

        expect(observer.errors, isEmpty);
      });
    });

    group('VideoInteractionsSubscriptionRequested', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates isLiked without adjusting likeCount when stream emits liked',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add([testEventId]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // likeCount stays at 10 — count is only adjusted by _onLikeToggled
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates isLiked without adjusting likeCount when stream emits '
        'unliked',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add(<String>[]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // likeCount stays at 10 — count is only adjusted by _onLikeToggled
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            likeCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not emit when like status unchanged',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add([testEventId]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <VideoInteractionsState>[],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        // #6020 regression: watchLikedEventIds ticks on EVERY like/unlike
        // anywhere in the app, not just this video. Before the fix, that
        // stream alone drove isLiked, so a coordinate-only hit (the
        // underlying reaction is recorded against a pre-edit event id) got
        // silently flipped back to unliked the next time anything else was
        // liked/unliked — because likedIds.contains(_eventId) was false and
        // didn't know about the coordinate. This pins that liked-via-
        // coordinate state survives an unrelated watchLikedEventIds tick.
        'liked-via-coordinate state survives an unrelated '
        'watchLikedEventIds tick elsewhere in the app (#6020)',
        build: () => createBloc(addressableId: testAddressableId),
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 10,
        ),
        act: (bloc) async {
          bloc.add(const VideoInteractionsSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // This video's own coordinate is liked (its reaction is recorded
          // under a different, pre-edit event id — never testEventId).
          likedAddressableIdsController.add({testAddressableId});
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // A completely unrelated video is liked elsewhere in the app,
          // ticking the shared watchLikedEventIds stream. testEventId is
          // (correctly) not in this list.
          likedIdsController.add(['some-other-unrelated-event-id']);
        },
        wait: const Duration(milliseconds: 150),
        expect: () => <VideoInteractionsState>[],
      );
    });

    group('VideoInteractionsCommentCountUpdated', () {
      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates comment count',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          commentCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(10)),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            commentCount: 10,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'updates comment count from null',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(3)),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            commentCount: 3,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'preserves other state fields when updating comment count',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          isLiked: true,
          likeCount: 42,
          repostCount: 7,
          commentCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(8)),
        expect: () => [
          const VideoInteractionsState(
            status: VideoInteractionsStatus.success,
            isLiked: true,
            likeCount: 42,
            repostCount: 7,
            commentCount: 8,
          ),
        ],
      );

      blocTest<VideoInteractionsBloc, VideoInteractionsState>(
        'does not call repository when updating comment count display',
        build: createBloc,
        seed: () => const VideoInteractionsState(
          status: VideoInteractionsStatus.success,
          commentCount: 5,
        ),
        act: (bloc) => bloc.add(const VideoInteractionsCommentCountUpdated(12)),
        verify: (_) {
          // Repository cache coherence is now owned by
          // CommentsRepository.loadComments(), not the BLoC.
          verifyNever(
            () => mockCommentsRepository.updateCachedCommentCount(any(), any()),
          );
        },
      );
    });

    group('close', () {
      test('cancels liked IDs subscription', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not affect anything
        // This mainly tests that no errors occur
        expect(() => likedIdsController.add([testEventId]), returnsNormally);
      });
    });
  });

  group('VideoInteractionsState', () {
    test('supports value equality', () {
      const state1 = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 10,
        commentCount: 5,
      );
      const state2 = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 10,
        commentCount: 5,
      );

      expect(state1, equals(state2));
    });

    test('hasLoadedCounts returns true when likeCount is not null', () {
      const stateWithCounts = VideoInteractionsState(likeCount: 10);
      const stateWithoutCounts = VideoInteractionsState();

      expect(stateWithCounts.hasLoadedCounts, isTrue);
      expect(stateWithoutCounts.hasLoadedCounts, isFalse);
    });

    test('copyWith creates copy with updated values', () {
      const state = VideoInteractionsState();

      final updated = state.copyWith(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 42,
        commentCount: 10,
      );

      expect(updated.status, VideoInteractionsStatus.success);
      expect(updated.isLiked, isTrue);
      expect(updated.likeCount, 42);
      expect(updated.commentCount, 10);
    });

    test('copyWith preserves values when not specified', () {
      const state = VideoInteractionsState(
        status: VideoInteractionsStatus.success,
        isLiked: true,
        likeCount: 42,
        commentCount: 10,
      );

      final updated = state.copyWith();

      expect(updated.status, VideoInteractionsStatus.success);
      expect(updated.isLiked, isTrue);
      expect(updated.likeCount, 42);
      expect(updated.commentCount, 10);
    });
  });
}
