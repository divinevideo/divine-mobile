// ABOUTME: Regression coverage for successful deletion reaching the Home feed.
// ABOUTME: Exercises removal notifications, cursor preservation, and late loads.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/feed_bloc_test_helper.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

class _MemoryHomeFeedCache extends HomeFeedCache {
  List<VideoEvent>? saved;
  List<VideoEvent>? window;
  bool cleared = false;

  @override
  Future<List<VideoEvent>?> readVideos({
    required String? pubkey,
    required String mode,
  }) async => window;

  @override
  Future<void> writeVideos({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
  }) async => saved = videos;

  @override
  Future<void> clearVideos({
    required String? pubkey,
    required String mode,
  }) async {
    saved = null;
    cleared = true;
  }
}

VideoEvent _video(String digit) => VideoEvent(
  id: digit * 64,
  pubkey: 'a' * 64,
  createdAt: 1700000000 - int.parse(digit),
  content: 'Synthetic clip',
  timestamp: DateTime.utc(2026),
  videoUrl: 'https://example.com/$digit.mp4',
);

// New limits each creator to two videos, so its fixtures need distinct authors.
VideoEvent _newVideo(String digit) =>
    _video(digit).copyWith(pubkey: digit * 64);

void main() {
  group('Home video removal', () {
    late _MockVideosRepository videos;
    late StreamController<String> removals;

    setUpAll(() => registerFallbackValue(_video('0')));

    setUp(() {
      videos = _MockVideosRepository();
      removals = StreamController<String>.broadcast();
      when(() => videos.removedVideoIds).thenAnswer((_) => removals.stream);
      when(() => videos.isVideoKnownDeleted(any())).thenReturn(false);
    });

    tearDown(() => removals.close());

    VideoFeedBloc createBloc({
      ProfileRepository? profiles,
      HomeFeedCache? cache,
      FeedPerformanceTracker? feedTracker,
      bool serveCachedHomeFeed = false,
    }) => VideoFeedBloc(
      videosRepository: videos,
      removedIdsStream: videos.removedVideoIds,
      followRepository: _MockFollowRepository(),
      curatedListRepository: _MockCuratedListRepository(),
      serveCachedHomeFeed: serveCachedHomeFeed,
      profileRepository: profiles,
      homeFeedCache: cache ?? _MemoryHomeFeedCache(),
      feedTracker: feedTracker,
    );

    group(VideoFeedVideoRemoved, () {
      feedBlocTest(
        'removes the currently playing video when deletion is announced',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2'), _video('3')],
          currentIndex: 1,
        ),
        act: (_) => removals.add('2' * 64),
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (state) => state.videos.map((v) => v.id).toList(),
                'surviving videos',
                ['1' * 64, '3' * 64],
              )
              .having((state) => state.currentIndex, 'current index', 1),
        ],
      );

      for (final (removed, currentIndex, nextIndex) in [
        ('1', 0, 0),
        ('1', 1, 0),
        ('1', 2, 1),
        ('3', 2, 1),
        ('3', 0, 0),
      ]) {
        feedBlocTest(
          'removing $removed preserves the survivor at cursor $currentIndex',
          build: createBloc,
          seed: () => VideoFeedBlocState(
            status: VideoFeedStatus.success,
            videos: [_video('1'), _video('2'), _video('3')],
            currentIndex: currentIndex,
            videoListSources: {
              removed * 64: const {'synthetic-list'},
              '2' * 64: const {'synthetic-list'},
            },
            listOnlyVideoIds: {removed * 64, '2' * 64},
          ),
          act: (_) => removals.add(removed * 64),
          wait: Duration.zero,
          expect: () => [
            isA<VideoFeedBlocState>()
                .having(
                  (state) => state.videos.map((v) => v.id).toList(),
                  'surviving videos',
                  [
                    for (final digit in ['1', '2', '3'])
                      if (digit != removed) digit * 64,
                  ],
                )
                .having(
                  (state) => state.currentIndex,
                  'current index',
                  nextIndex,
                )
                .having(
                  (state) => state.videoListSources,
                  'list attribution',
                  {
                    '2' * 64: const {'synthetic-list'},
                  },
                )
                .having(
                  (state) => state.listOnlyVideoIds,
                  'list-only videos',
                  {'2' * 64},
                ),
          ],
        );
      }

      feedBlocTest(
        'removing the last video reaches the existing empty state',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1')],
        ),
        act: (_) => removals.add('1' * 64),
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((state) => state.isEmpty, 'empty feed', isTrue)
              .having((state) => state.currentIndex, 'current index', 0),
        ],
      );

      // Block and mute sweeps share the bus and are reversible, so a removed id
      // can belong to a video that came back on a refresh.
      feedBlocTest(
        'removes a video again when its id is announced a second time',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2')],
          coordination: VideoFeedCoordination(removedVideoIds: {'2' * 64}),
        ),
        act: (_) => removals.add('2' * 64),
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (state) => state.videos,
            'surviving videos',
            [_video('1')],
          ),
        ],
      );

      feedBlocTest(
        'keeps a video that came back when a different video is removed',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2'), _video('3')],
          coordination: VideoFeedCoordination(removedVideoIds: {'2' * 64}),
        ),
        act: (_) => removals.add('3' * 64),
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (state) => state.videos,
            'surviving videos',
            [_video('1'), _video('2')],
          ),
        ],
      );

      // Deleting one version of an addressable video tombstones its coordinate,
      // but the bus only names the versions the service had cached.
      feedBlocTest(
        'removes another version of a deleted video the bus did not name',
        build: createBloc,
        setUp: () => when(() => videos.isVideoKnownDeleted(any())).thenAnswer(
          (call) =>
              (call.positionalArguments.single as VideoEvent).id == '1' * 64,
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2')],
        ),
        act: (_) => removals.add('9' * 64),
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (state) => state.videos,
            'surviving videos',
            [_video('2')],
          ),
        ],
      );

      group('resume window', () {
        late _MemoryHomeFeedCache resumeCache;

        // A swipe schedules a debounced write of the window ahead of the cursor.
        // The removal has to replace it, or closing Home flushes the video back.
        feedBlocTest(
          'a removal replaces a pending swipe write that still holds the video',
          setUp: () => resumeCache = _MemoryHomeFeedCache(),
          build: () => createBloc(cache: resumeCache),
          seed: () => VideoFeedBlocState(
            status: VideoFeedStatus.success,
            videos: [_video('1'), _video('2'), _video('3')],
          ),
          act: (bloc) async {
            bloc.add(const VideoFeedActiveIndexChanged(1));
            await bloc.stream.firstWhere((state) => state.currentIndex == 1);
            removals.add('3' * 64);
            await bloc.stream.firstWhere((state) => state.videos.length == 2);
          },
          verify: (_) async {
            await pumpEventQueue();
            expect(resumeCache.cleared, isTrue);
            expect(resumeCache.saved, isNull);
          },
        );
      });
    });

    test('close cancels the removal subscription', () async {
      final bloc = createBloc();
      expect(removals.hasListener, isTrue);
      await bloc.close();
      expect(removals.hasListener, isFalse);
    });

    group('late async results', () {
      late Completer<HomeFeedResult> page;
      late Completer<void> requested;

      setUp(() {
        page = Completer<HomeFeedResult>();
        requested = Completer<void>();
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) {
          requested.complete();
          return page.future;
        });
        when(() => videos.isVideoKnownDeleted(any())).thenAnswer(
          (call) =>
              (call.positionalArguments.single as VideoEvent).id == '2' * 64,
        );
      });

      feedBlocTest(
        'does not resurrect a removed item when pagination completes',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2'), _video('3')],
          currentIndex: 1,
          paginationCursor: 'next-page',
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedLoadMoreRequested());
          await requested.future;
          final removed = bloc.stream.firstWhere(
            (state) => !state.videos.contains(_video('2')),
          );
          removals.add('2' * 64);
          await removed;
          page.complete(
            HomeFeedResult(
              videos: [_video('2'), _video('4')],
              hasMore: false,
            ),
          );
        },
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (state) => state.isLoadingMore,
            'loading next page',
            isTrue,
          ),
          isA<VideoFeedBlocState>().having(
            (state) => state.videos,
            'removed while loading',
            [_video('1'), _video('3')],
          ),
          isA<VideoFeedBlocState>()
              .having((state) => state.videos, 'surviving page result', [
                _video('1'),
                _video('3'),
                _video('4'),
              ])
              .having((state) => state.isLoadingMore, 'page finished', isFalse),
        ],
      );

      feedBlocTest(
        'filters a deleted video when a refresh returns its stale first page',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2')],
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedRefreshRequested());
          await requested.future;
          final removed = bloc.stream.firstWhere(
            (state) => state.coordination.removedVideoIds.contains('2' * 64),
          );
          removals.add('2' * 64);
          await removed;
          page.complete(HomeFeedResult(videos: [_video('1'), _video('2')]));
        },
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (state) => state.status,
            'refresh started',
            VideoFeedStatus.loading,
          ),
          isA<VideoFeedBlocState>()
              .having((state) => state.videos, 'fresh surviving videos', [
                _video('1'),
              ])
              .having(
                (state) => state.status,
                'refresh finished',
                VideoFeedStatus.success,
              ),
        ],
      );

      // Block and mute sweeps share the removal bus but are reversible: once
      // the author is unblocked, a refresh must be able to show the video.
      feedBlocTest(
        'lets a refresh restore a video whose removal was not a deletion',
        build: createBloc,
        setUp: () =>
            when(() => videos.isVideoKnownDeleted(any())).thenReturn(false),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [_video('1'), _video('2')],
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedRefreshRequested());
          await requested.future;
          final removed = bloc.stream.firstWhere(
            (state) => state.coordination.removedVideoIds.contains('2' * 64),
          );
          removals.add('2' * 64);
          await removed;
          page.complete(HomeFeedResult(videos: [_video('1'), _video('2')]));
        },
        wait: Duration.zero,
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (state) => state.status,
            'refresh started',
            VideoFeedStatus.loading,
          ),
          isA<VideoFeedBlocState>().having(
            (state) => state.videos,
            'fresh videos',
            [_video('1'), _video('2')],
          ),
        ],
      );

      // New pages past a page that shows nothing new, so a page holding only
      // a removed video must not end the read early.
      feedBlocTest(
        'reads past a New page whose only video was removed',
        build: createBloc,
        setUp: () =>
            when(
              () => videos.getNewVideos(
                cursor: any(named: 'cursor'),
                skipCache: any(named: 'skipCache'),
                revalidate: any(named: 'revalidate'),
              ),
            ).thenAnswer(
              (call) async => call.namedArguments[#cursor] == 'first-page'
                  ? HomeFeedResult(
                      videos: [_newVideo('2')],
                      paginationCursor: 'second-page',
                      hasMore: true,
                    )
                  : HomeFeedResult(videos: [_newVideo('3')], hasMore: false),
            ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: const VideoFeedSource.newVideos(),
          videos: [_newVideo('1')],
          paginationCursor: 'first-page',
          coordination: VideoFeedCoordination(removedVideoIds: {'2' * 64}),
        ),
        act: (bloc) async {
          final finished = bloc.stream
              .skipWhile((state) => !state.isLoadingMore)
              .firstWhere((state) => !state.isLoadingMore);
          bloc.add(const VideoFeedLoadMoreRequested());
          await finished;
        },
        verify: (bloc) =>
            expect(bloc.state.videos, [_newVideo('1'), _newVideo('3')]),
      );
    });

    group('switching to a cached source', () {
      late _MemoryHomeFeedCache cache;
      List<VideoEvent>? firstServed;

      setUp(() {
        cache = _MemoryHomeFeedCache();
        firstServed = null;
        when(() => videos.applyContentPreferences(any())).thenAnswer(
          (call) => call.positionalArguments.single as List<VideoEvent>,
        );
        when(() => videos.isVideoKnownDeleted(any())).thenAnswer(
          (call) =>
              (call.positionalArguments.single as VideoEvent).id == '2' * 64,
        );
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResult(videos: [_video('1')], hasMore: false),
        );
      });

      // The window was read before the deletion arrived, so the repository's
      // own read filter could not drop it.
      VideoFeedBlocState removedAfterTheRead() => VideoFeedBlocState(
        status: VideoFeedStatus.success,
        source: const VideoFeedSource.classic(),
        coordination: VideoFeedCoordination(removedVideoIds: {'2' * 64}),
      );

      feedBlocTest(
        'serves a cached window without a video removed after it was read',
        // The fresh page differs from the window, so only the cache can put
        // video 1 first.
        setUp: () =>
            when(
              () => videos.getRecommendedVideos(
                userPubkey: any(named: 'userPubkey'),
                until: any(named: 'until'),
                skipCache: any(named: 'skipCache'),
                revalidate: any(named: 'revalidate'),
              ),
            ).thenAnswer(
              (_) async =>
                  HomeFeedResult(videos: [_video('4')], hasMore: false),
            ),
        build: () => createBloc(
          cache: cache..window = [_video('1'), _video('2')],
          serveCachedHomeFeed: true,
        ),
        seed: removedAfterTheRead,
        act: (bloc) async {
          final served = bloc.stream.firstWhere(
            (state) =>
                state.source == const VideoFeedSource.forYou() &&
                state.videos.isNotEmpty,
          );
          bloc.add(const VideoFeedModeChanged(FeedMode.forYou));
          firstServed = (await served).videos;
        },
        verify: (_) => expect(firstServed, [_video('1')]),
      );

      group('with a tracked load', () {
        late _MockFeedPerformanceTracker tracker;
        late FeedLoadHandle feedLoad;

        setUp(() {
          registerFallbackValue(FeedLoadReason.sourceSwitch);
          tracker = _MockFeedPerformanceTracker();
          feedLoad = FeedPerformanceTracker(
            sink: const NoOpAnalyticsEventSink(),
          ).startFeedLoad('forYou');
          when(
            () => tracker.startFeedLoad(any(), reason: any(named: 'reason')),
          ).thenReturn(feedLoad);
        });

        feedBlocTest(
          'a window left empty by removals is not counted as served',
          build: () => createBloc(
            cache: cache..window = [_video('2')],
            serveCachedHomeFeed: true,
            feedTracker: tracker,
          ),
          seed: removedAfterTheRead,
          act: (bloc) async {
            bloc.add(const VideoFeedModeChanged(FeedMode.forYou));
            await bloc.stream.firstWhere(
              (state) =>
                  state.status == VideoFeedStatus.success &&
                  state.source == const VideoFeedSource.forYou(),
            );
          },
          verify: (bloc) {
            expect(bloc.state.videos, [_video('1')]);
            verify(
              () => tracker.markFirstVisibleContent(
                feedLoad,
                1,
                servedFromCache: false,
              ),
            ).called(1);
          },
        );
      });
    });

    feedBlocTest(
      'late enrichment does not add a removed video back',
      build: createBloc,
      seed: () => VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [_video('1'), _video('2')],
      ),
      act: (bloc) async {
        final removed = bloc.stream.firstWhere(
          (state) => state.videos.length == 1,
        );
        removals.add('2' * 64);
        await removed;
        bloc.add(
          VideoFeedEnrichmentReady(
            source: const VideoFeedSource.forYou(),
            enrichedVideos: [
              _video('1').copyWith(title: 'Enriched'),
              _video('2'),
            ],
            sourceIds: {'1' * 64, '2' * 64},
          ),
        );
      },
      wait: Duration.zero,
      expect: () => [
        isA<VideoFeedBlocState>().having(
          (state) => state.videos,
          'removed before enrichment',
          [_video('1')],
        ),
        isA<VideoFeedBlocState>()
            .having(
              (state) => state.videos.map((v) => v.id).toList(),
              'still removed after enrichment',
              ['1' * 64],
            )
            .having(
              (state) => state.videos.single.title,
              'enriched title',
              'Enriched',
            ),
      ],
    );

    test(
      'a profile read finishing after deletion persists the surviving window',
      () async {
        final profiles = _MockProfileRepository();
        final profileRead = Completer<Map<String, UserProfile>>();
        final requested = Completer<void>();
        when(
          () => profiles.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
        ).thenAnswer((_) {
          requested.complete();
          return profileRead.future;
        });
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResult(
            videos: [_video('1'), _video('2'), _video('3')],
          ),
        );
        final cache = _MemoryHomeFeedCache();
        final bloc = createBloc(profiles: profiles, cache: cache);
        addTearDown(bloc.close);
        bloc.add(const VideoFeedRefreshRequested());
        await requested.future;
        expect(bloc.state.videos, hasLength(3));
        final removed = bloc.stream.firstWhere(
          (state) => state.videos.length == 2,
        );
        removals.add('3' * 64);
        await removed;
        profileRead.complete({});
        await pumpEventQueue();
        expect(cache.saved?.map((video) => video.id).toList(), ['2' * 64]);
      },
    );
  });
}
