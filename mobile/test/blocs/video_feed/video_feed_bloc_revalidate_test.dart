// ABOUTME: Tests that a cold start revalidates instead of trusting the cache
// ABOUTME: Pins the #7719 fix: serve cached content, then fetch fresh

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockFeedTuningRepository extends Mock implements FeedTuningRepository {}

class _MockHomeFeedCache extends Mock implements HomeFeedCache {}

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: '0000000000000000000000000000000000000000000000000000000000000000',
  createdAt: 1755300000,
  content: 'c',
  timestamp: DateTime.utc(2026, 8, 16),
  videoUrl: 'https://example.com/$id.mp4',
);

void main() {
  group(VideoFeedBloc, () {
    group('VideoFeedStarted', () {
      late _MockVideosRepository videosRepository;
      late _MockFollowRepository followRepository;
      late _MockCuratedListRepository curatedListRepository;
      late _MockFeedTuningRepository feedTuningRepository;
      late _MockHomeFeedCache homeFeedCache;
      late Completer<HomeFeedResult> freshResult;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        videosRepository = _MockVideosRepository();
        followRepository = _MockFollowRepository();
        curatedListRepository = _MockCuratedListRepository();
        feedTuningRepository = _MockFeedTuningRepository();
        homeFeedCache = _MockHomeFeedCache();
        freshResult = Completer<HomeFeedResult>();

        when(() => followRepository.followingPubkeys).thenReturn([]);
        when(
          () => followRepository.followingStream,
        ).thenAnswer((_) => BehaviorSubject<List<String>>.seeded([]));
        when(() => curatedListRepository.getSubscribedLists()).thenReturn([]);
        when(
          () => curatedListRepository.subscribedListsStream,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => videosRepository.getNewVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => HomeFeedResult(videos: [_video('fresh')]));
        when(() => videosRepository.applyContentPreferences(any())).thenAnswer(
          (invocation) =>
              invocation.positionalArguments.single as List<VideoEvent>,
        );
        when(
          () => homeFeedCache.readVideos(
            pubkey: any(named: 'pubkey'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => homeFeedCache.writeVideos(
            pubkey: any(named: 'pubkey'),
            mode: any(named: 'mode'),
            videos: any(named: 'videos'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => homeFeedCache.clearVideos(
            pubkey: any(named: 'pubkey'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => videosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) async => HomeFeedResult(videos: [_video('c')]));
        when(
          () => videosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => HomeFeedResult(videos: [_video('rec')]));
      });

      VideoFeedBloc buildBloc() => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
        curatedListRepository: curatedListRepository,
        feedTuningRepository: feedTuningRepository,
        homeFeedCache: homeFeedCache,
      );

      test(
        'late cached-window pagination cannot replace a fresh cursor',
        () async {
          final cached = _video(''.padLeft(64, 'a')).copyWith(createdAt: 1000);
          final fresh = _video(''.padLeft(64, 'b')).copyWith(createdAt: 9000);
          final stale = _video(''.padLeft(64, 'c')).copyWith(createdAt: 999);
          final next = _video(''.padLeft(64, 'd')).copyWith(createdAt: 8999);
          final oldPage = Completer<HomeFeedResult>();
          final oldPageStarted = Completer<void>();
          when(() => homeFeedCache.readVideos(pubkey: null, mode: 'latest'))
              .thenAnswer((_) async => [cached]);
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((call) {
            if (call.namedArguments[#revalidate] == true) {
              return freshResult.future;
            }
            if (call.namedArguments[#cursor] == 'p:fresh') {
              expect(call.namedArguments[#until], isNull);
              return Future.value(
                HomeFeedResult(videos: [next], hasMore: false),
              );
            }
            expect(call.namedArguments[#until], 1000);
            oldPageStarted.complete();
            return oldPage.future;
          });
          final bloc = buildBloc();
          addTearDown(bloc.close);
          final cachedReady = bloc.stream.firstWhere(
            (s) => s.videos.isNotEmpty,
          );
          bloc.add(const VideoFeedStarted(mode: FeedMode.latest));
          await cachedReady;
          bloc.add(const VideoFeedLoadMoreRequested());
          await oldPageStarted.future;

          final freshReady = bloc.stream.firstWhere(
            (s) => s.paginationCursor == 'p:fresh',
          );
          freshResult.complete(
            HomeFeedResult(
              videos: [fresh],
              hasMore: true,
              paginationCursor: 'p:fresh',
            ),
          );
          await freshReady;
          oldPage.complete(
            HomeFeedResult(
              videos: [stale],
              hasMore: true,
              paginationCursor: 'p:old',
            ),
          );
          await pumpEventQueue();

          expect(bloc.state.paginationCursor, 'p:fresh');
          expect(bloc.state.videos.map((v) => v.id), [cached.id, fresh.id]);
          expect(bloc.state.isLoadingMore, isFalse);

          final nextReady = bloc.stream.firstWhere((s) => !s.hasMore);
          bloc.add(const VideoFeedLoadMoreRequested());
          await nextReady;
          expect(bloc.state.videos.map((v) => v.id), [
            cached.id,
            fresh.id,
            next.id,
          ]);
        },
      );

      // The regression this pins (#7719): `_onStarted` used to call
      // `_loadVideos` with the default `skipCache: false`, so the fetch that
      // exists to refresh the feed was itself answered from the repository's
      // in-memory cache — which carries no TTL for the home, latest, and
      // recommended first-page entries. Reopening the app served hours-old
      // videos until the user pulled to refresh.
      //
      // The fetch revalidates (cache-read bypass) rather than full
      // `skipCache`, because `skipCache` on New also triggers the
      // pull-to-refresh relay merge, which does not belong on session start.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'revalidates past the cache on start so a reopen is not stale',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.latest));
          await bloc.stream.firstWhere(
            (state) =>
                state.source.mode == FeedMode.latest &&
                state.status == VideoFeedStatus.success,
          );
        },
        verify: (_) {
          final captured = verify(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: captureAny(named: 'skipCache'),
              revalidate: true,
            ),
          ).captured;
          expect(captured, [isFalse]);
          // Any additional call would mean the cache-answerable variant also
          // ran; exactly one fetch, and it revalidated past the cache.
          verifyNoMoreInteractions(videosRepository);
        },
      );

      // Switching *to* a mode mid-session reaches the feed through
      // `_selectSource`, a second route to the same stale page: the cache it
      // reads has no TTL either. Fixing only the cold start left #7719's
      // symptom alive here.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'revalidates past the cache when the user switches modes',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.classic));
          await bloc.stream.firstWhere(
            (state) =>
                state.source.mode == FeedMode.classic &&
                state.status == VideoFeedStatus.success,
          );
          bloc.add(const VideoFeedModeChanged(FeedMode.latest));
          await bloc.stream.firstWhere(
            (state) =>
                state.source.mode == FeedMode.latest &&
                state.status == VideoFeedStatus.success,
          );
        },
        verify: (_) {
          final captured = verify(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: captureAny(named: 'skipCache'),
              revalidate: true,
            ),
          ).captured;
          expect(captured, [isFalse]);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'switches directly to cached content before revalidation completes',
        setUp: () {
          when(
            () => homeFeedCache.readVideos(pubkey: null, mode: 'latest'),
          ).thenAnswer((_) async => [_video('cached')]);
          when(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) => freshResult.future);
          addTearDown(() {
            if (!freshResult.isCompleted) {
              freshResult.complete(const HomeFeedResult(videos: []));
            }
          });
        },
        build: buildBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.classic,
          videos: [_video('previous-source')],
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedModeChanged(FeedMode.latest));
          await bloc.stream.firstWhere(
            (state) => state.videos.singleOrNull?.id == 'cached',
          );
          freshResult.complete(HomeFeedResult(videos: [_video('fresh')]));
        },
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((state) => state.mode, 'mode', FeedMode.latest)
              .having(
                (state) => state.status,
                'status',
                VideoFeedStatus.success,
              )
              .having(
                (state) => state.videos.map((video) => video.id),
                'cached videos',
                ['cached'],
              ),
          isA<VideoFeedBlocState>()
              .having((state) => state.mode, 'mode', FeedMode.latest)
              .having(
                (state) => state.status,
                'status',
                VideoFeedStatus.success,
              )
              .having(
                (state) => state.videos.map((video) => video.id),
                'fresh videos spliced after cache',
                ['cached', 'fresh'],
              ),
        ],
        verify: (_) {
          verify(
            () => videosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              revalidate: true,
            ),
          ).called(1);
        },
      );

      // For You start revalidates without `skipCache`: `skipCache` would
      // draw a new recommendation session seed and reshuffle the session,
      // which is reserved for explicit pull-to-refresh.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'revalidates For You on start without reseeding the session',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted());
          await bloc.stream.firstWhere(
            (state) =>
                state.source.mode == FeedMode.forYou &&
                state.status == VideoFeedStatus.success,
          );
        },
        verify: (_) {
          final captured = verify(
            () => videosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              until: any(named: 'until'),
              skipCache: captureAny(named: 'skipCache'),
              revalidate: true,
            ),
          ).captured;
          expect(captured, [isFalse]);
        },
      );

      // Classics keeps its deliberate 15-minute first-page cache on start:
      // re-entry within the TTL resumes the same stable opening instead of
      // re-shuffling, so the bloc must not bypass or revalidate it.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'keeps the Classics first-page cache on start',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.classic));
          await bloc.stream.firstWhere(
            (state) =>
                state.source.mode == FeedMode.classic &&
                state.status == VideoFeedStatus.success,
          );
        },
        verify: (_) {
          final captured = verify(
            () => videosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: captureAny(named: 'skipCache'),
            ),
          ).captured;
          expect(captured, [isFalse]);
          verifyNever(
            () => videosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: true,
            ),
          );
        },
      );
    });
  });
}
