// ABOUTME: Tests for VideoFeedBloc - unified video feed with mode switching
// ABOUTME: Tests loading, pagination, mode switching, and following changes

// Mutable list literals keep each bloc-test fixture isolated and editable.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockHomeFeedCache extends Mock implements HomeFeedCache {}

class _MockFeedTuningRepository extends Mock implements FeedTuningRepository {}

/// No-op cache DAO so the bloc tests never touch the shared on-disk
/// [CacheSync] database. Under CI's parallel test isolates the
/// path_provider-mocked `/tmp/documents` DB is shared, so the cold-start serve
/// path cross-contaminates between tests and fails non-deterministically.
/// Wiring [CacheSync] to a no-op DAO in `setUp` keeps every bloc — whatever
/// factory built it — on the deterministic fresh-load path. Cache-serve
/// behaviour is covered separately by the 'cache-first home feed' group, which
/// injects its own [HomeFeedCache] mock.
class _FakeCacheDao implements CacheDao {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

class _FakeSharedPreferences extends Fake implements SharedPreferences {}

void main() {
  group('VideoFeedBloc', () {
    late _MockVideosRepository mockVideosRepository;
    late _MockFollowRepository mockFollowRepository;
    late _MockCuratedListRepository mockCuratedListRepository;
    late _MockProfileRepository mockProfileRepository;
    late StreamController<List<String>> followingController;
    late StreamController<List<CuratedList>> curatedListsController;
    late VideoFeedBloc savedModeBloc;

    setUp(() async {
      // Route the disk cache to a no-op DAO so no bloc — whatever factory
      // creates it — reads or writes the shared on-disk CacheSync DB.
      await CacheSync.init(dao: _FakeCacheDao());

      mockVideosRepository = _MockVideosRepository();
      mockFollowRepository = _MockFollowRepository();
      mockCuratedListRepository = _MockCuratedListRepository();
      mockProfileRepository = _MockProfileRepository();
      followingController = StreamController<List<String>>.broadcast();
      curatedListsController = StreamController<List<CuratedList>>.broadcast();

      // Default stubs
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      when(
        () => mockCuratedListRepository.subscribedListsStream,
      ).thenAnswer((_) => curatedListsController.stream);
      when(() => mockCuratedListRepository.getSubscribedLists()).thenReturn([]);

      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => {});
    });

    tearDown(() {
      followingController.close();
      curatedListsController.close();
    });

    VideoFeedBloc createBloc({
      FeedTuningRepository? feedTuningRepository,
      FeedPerformanceTracker? feedTracker,
    }) => VideoFeedBloc(
      videosRepository: mockVideosRepository,
      followRepository: mockFollowRepository,
      curatedListRepository: mockCuratedListRepository,
      feedTuningRepository: feedTuningRepository,
      feedTracker: feedTracker,
    );

    VideoEvent createTestVideo(
      String id, {
      int? createdAt,
      String pubkey =
          '0000000000000000000000000000000000000000000000000000000000000000',
      String? vineId,
    }) {
      final timestamp =
          createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        createdAt: timestamp,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
        title: 'Test Video $id',
        videoUrl: 'https://example.com/$id.mp4',
        thumbnailUrl: 'https://example.com/$id.jpg',
        vineId: vineId,
        addressableDTag: vineId,
      );
    }

    List<VideoEvent> createTestVideos(
      int count, {
      int? startTimestamp,
      String idPrefix = 'video',
    }) {
      final baseTimestamp =
          startTimestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return List.generate(
        count,
        (i) => createTestVideo(
          '$idPrefix-$i',
          createdAt: baseTimestamp - i, // Decreasing timestamps
        ),
      );
    }

    CuratedList createTestList({
      String id = 'list-a',
      String name = 'Best Vines',
      List<String> videoEventIds = const ['video-a', 'video-b'],
    }) {
      final now = DateTime(2026);
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: videoEventIds,
        createdAt: now,
        updatedAt: now,
      );
    }

    /// Page size constant must match the one in video_feed_bloc.dart
    const pageSize = 5;

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, VideoFeedStatus.loading);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.mode, FeedMode.forYou);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('feed tuning', () {
      late _MockFeedTuningRepository tuningRepository;
      late VideoEvent tunedVideo;

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'publishes a tuning signal for the target video',
        setUp: () {
          tuningRepository = _MockFeedTuningRepository();
          tunedVideo = createTestVideo('tuned-video');
          when(
            () => tuningRepository.tune(
              video: tunedVideo,
              direction: FeedTuningDirection.more,
            ),
          ).thenAnswer((_) async => 'published-tuning-event-id');
        },
        build: () => createBloc(feedTuningRepository: tuningRepository),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [tunedVideo],
        ),
        act: (bloc) => bloc.add(
          const VideoFeedTuningSwipeCommitted(
            videoId: 'tuned-video',
            direction: FeedTuningDirection.more,
          ),
        ),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((state) => state.tuningActionSequence, 'sequence', 1)
              .having(
                (state) => state.lastTuningAction,
                'lastTuningAction',
                isA<VideoFeedTuningAction>()
                    .having(
                      (action) => action.videoId,
                      'videoId',
                      'tuned-video',
                    )
                    .having(
                      (action) => action.direction,
                      'direction',
                      FeedTuningDirection.more,
                    )
                    .having((action) => action.sequence, 'sequence', 1)
                    .having(
                      (action) => action.publishedEventId,
                      'publishedEventId',
                      'published-tuning-event-id',
                    ),
              ),
        ],
        verify: (_) {
          verify(
            () => tuningRepository.tune(
              video: tunedVideo,
              direction: FeedTuningDirection.more,
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'undo retracts a published tuning signal',
        setUp: () {
          tuningRepository = _MockFeedTuningRepository();
          when(
            () => tuningRepository.undo('published-tuning-event-id'),
          ).thenAnswer((_) async {});
        },
        build: () => createBloc(feedTuningRepository: tuningRepository),
        act: (bloc) => bloc.add(
          const VideoFeedTuningUndoRequested('published-tuning-event-id'),
        ),
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          verify(
            () => tuningRepository.undo('published-tuning-event-id'),
          ).called(1);
        },
      );
    });

    group('VideoFeedBlocState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = VideoFeedBlocState();
        const successState = VideoFeedBlocState(
          status: VideoFeedStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading', () {
        const initialState = VideoFeedBlocState();

        expect(initialState.isLoading, isTrue);
      });

      test('isEmpty returns true when success with no videos', () {
        const emptyState = VideoFeedBlocState(status: VideoFeedStatus.success);
        final loadedState = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [createTestVideo('v1')],
        );

        expect(emptyState.isEmpty, isTrue);
        expect(loadedState.isEmpty, isFalse);
      });

      test('copyWith maps legacy latest mode to New Videos source', () {
        const state = VideoFeedBlocState();

        final updated = state.copyWith(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
        );

        expect(updated.status, VideoFeedStatus.success);
        expect(updated.mode, FeedMode.latest);
        expect(updated.source, const VideoFeedSource.newVideos());
      });

      test('copyWith preserves values when not specified', () {
        const state = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
        );

        final updated = state.copyWith();

        expect(updated.status, VideoFeedStatus.success);
        expect(updated.mode, FeedMode.following);
      });

      test('copyWith clearError removes error', () {
        const state = VideoFeedBlocState(error: VideoFeedError.loadFailed);

        final updated = state.copyWith(clearError: true);

        expect(updated.error, isNull);
      });
    });

    group('VideoFeedStarted', () {
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'emits [loading, success] when home feed loads successfully',
        setUp: () {
          final videos = createTestVideos(pageSize);
          final authors = ['author1', 'author2'];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: authors,
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.mode, 'mode', FeedMode.following)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'applies background Nostr enrichment to following feed videos',
        setUp: () {
          final authors = ['author1'];
          final compactVideo = createTestVideo('video-1').copyWith(
            rawTags: const {
              'd': 'video-1',
              'url': 'https://example.com/video-1.mp4',
              'title': 'REST row',
              'thumb': 'https://example.com/video-1.jpg',
            },
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: authors,
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: [compactVideo]));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          enrichVideos: (videos) async => [
            videos.single.copyWith(
              rawTags: {
                ...videos.single.rawTags,
                'verification': 'verified_mobile',
                'proofmode': '{}',
              },
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.videos.single.hasProofMode,
                'proof before',
                isFalse,
              ),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.videos.single.hasProofMode,
                'proof after',
                isTrue,
              )
              .having(
                (s) => s.videos.single.rawTags['verification'],
                'verification tag',
                'verified_mobile',
              ),
        ],
      );

      test(
        'ignores stale background enrichment after switching sources',
        () async {
          final authors = ['author1'];
          final compactVideo = createTestVideo('video-1').copyWith(
            rawTags: const {
              'd': 'video-1',
              'url': 'https://example.com/video-1.mp4',
              'title': 'REST row',
              'thumb': 'https://example.com/video-1.jpg',
            },
          );
          final newVideos = createTestVideos(2, idPrefix: 'new');
          final enrichment = Completer<List<VideoEvent>>();
          var enrichCallCount = 0;

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: authors,
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: [compactVideo]));
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: newVideos));

          final bloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            enrichVideos: (videos) {
              enrichCallCount += 1;
              if (enrichCallCount == 1) return enrichment.future;
              return Future.value(videos);
            },
          );
          addTearDown(bloc.close);

          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await pumpEventQueue();
          expect(bloc.state.videos.map((video) => video.id), ['video-1']);

          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.newVideos()));
          await pumpEventQueue();
          expect(bloc.state.source, const VideoFeedSource.newVideos());
          expect(bloc.state.videos.map((video) => video.id), [
            'new-0',
            'new-1',
          ]);

          enrichment.complete([
            compactVideo.copyWith(
              rawTags: {
                ...compactVideo.rawTags,
                'verification': 'verified_mobile',
                'proofmode': '{}',
              },
            ),
          ]);
          await pumpEventQueue();
          await pumpEventQueue();

          expect(bloc.state.source, const VideoFeedSource.newVideos());
          expect(bloc.state.videos.map((video) => video.id), [
            'new-0',
            'new-1',
          ]);
          expect(
            bloc.state.videos.any(
              (video) => video.rawTags.containsKey('proofmode'),
            ),
            isFalse,
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'reports unexpected background enrichment failures as Reportable',
        setUp: () {
          final authors = ['author1'];
          final compactVideo = createTestVideo('video-1').copyWith(
            rawTags: const {
              'd': 'video-1',
              'url': 'https://example.com/video-1.mp4',
              'title': 'REST row',
              'thumb': 'https://example.com/video-1.jpg',
            },
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: authors,
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: [compactVideo]));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          enrichVideos: (_) async => throw StateError('enrichment broke'),
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 1),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having(
                (error) => error.context,
                'context',
                '_scheduleNostrEnrichment',
              )
              .having(
                (error) => error.unwrap(),
                'inner error',
                isA<StateError>(),
              ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'maps legacy latest start mode to New Videos',
        setUp: () {
          final videos = createTestVideos(5);

          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.latest),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.latest)
              .having((s) => s.videos.length, 'videos count', 5),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'loads recommendations when forYou mode is specified',
        setUp: () {
          final videos = createTestVideos(5);
          final authors = ['author1', 'author2'];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(authors);
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedBlocState(),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.forYou),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).called(1);
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'marks forYou exhausted when recommendations omit next cursor',
        setUp: () {
          final videos = createTestVideos(5);

          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(videos: videos, hasMore: true),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedBlocState(),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.forYou)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'restores saved following mode from SharedPreferences before loading',
        setUp: () async {
          final videos = createTestVideos(5);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': FeedMode.following.name,
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          when(
            () => mockFollowRepository.followingStream,
          ).thenAnswer((_) => followingController.stream);

          when(
            () => mockCuratedListRepository.subscribedListsStream,
          ).thenAnswer((_) => curatedListsController.stream);

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.following),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not inherit legacy following mode for a new account with no follows',
        setUp: () async {
          final videos = createTestVideos(3);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': FeedMode.following.name,
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
            userPubkey: 'b' * 64,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.source.type,
            'source',
            VideoFeedSourceType.forYou,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.forYou,
              ),
        ],
        verify: (_) async {
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );

          final sharedPreferences = await SharedPreferences.getInstance();
          expect(sharedPreferences.getString('selected_feed_mode'), isNull);
          expect(
            sharedPreferences.getString('selected_feed_mode_${'b' * 64}'),
            FeedMode.forYou.name,
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'migrates legacy following mode for current account with follows',
        setUp: () async {
          final videos = createTestVideos(5);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': FeedMode.following.name,
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
            userPubkey: 'a' * 64,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.following),
        ],
        verify: (_) async {
          final sharedPreferences = await SharedPreferences.getInstance();
          expect(sharedPreferences.getString('selected_feed_mode'), isNull);
          expect(
            sharedPreferences.getString('selected_feed_mode_${'a' * 64}'),
            FeedMode.following.name,
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not inherit legacy list mode for an authenticated account',
        setUp: () async {
          final videos = createTestVideos(3);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': 'list:list-a',
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(
            () => mockCuratedListRepository.getListById('list-a'),
          ).thenReturn(createTestList());
          when(
            () => mockCuratedListRepository.getOrderedVideoIds('list-a'),
          ).thenReturn(['video-a', 'video-b']);
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
            userPubkey: 'c' * 64,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.source.type,
            'source',
            VideoFeedSourceType.forYou,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.forYou,
              ),
        ],
        verify: (_) async {
          verifyNever(() => mockVideosRepository.getVideosForList(any()));

          final sharedPreferences = await SharedPreferences.getInstance();
          expect(sharedPreferences.getString('selected_feed_mode'), isNull);
          expect(
            sharedPreferences.getString('selected_feed_mode_${'c' * 64}'),
            FeedMode.forYou.name,
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'restores persisted latest to New Videos',
        setUp: () async {
          final videos = createTestVideos(2);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': 'latest',
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.newVideos,
              )
              .having((s) => s.mode, 'mode', FeedMode.latest),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.newVideos,
              )
              .having((s) => s.mode, 'mode', FeedMode.latest),
        ],
        verify: (_) async {
          verify(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).called(1);

          final sharedPreferences = await SharedPreferences.getInstance();
          expect(
            sharedPreferences.getString('selected_feed_mode'),
            const VideoFeedSource.newVideos().persistenceValue,
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'restores persisted classic to Classics',
        setUp: () async {
          final videos = createTestVideos(2);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': 'classic',
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.classic,
              )
              .having((s) => s.mode, 'mode', FeedMode.classic),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.classic,
              )
              .having((s) => s.mode, 'mode', FeedMode.classic),
        ],
        verify: (_) async {
          verify(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);

          final sharedPreferences = await SharedPreferences.getInstance();
          expect(
            sharedPreferences.getString('selected_feed_mode'),
            const VideoFeedSource.classic().persistenceValue,
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'restores saved subscribed list source when list exists',
        setUp: () async {
          final list = createTestList();
          final videos = createTestVideos(2);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': 'list:list-a',
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(
            () => mockCuratedListRepository.getListById('list-a'),
          ).thenReturn(list);
          when(
            () => mockCuratedListRepository.getOrderedVideoIds('list-a'),
          ).thenReturn(['video-a', 'video-b']);
          when(
            () => mockVideosRepository.getVideosForList(['video-a', 'video-b']),
          ).thenAnswer((_) async => videos);

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.subscribedList,
              )
              .having((s) => s.source.listId, 'listId', 'list-a')
              .having((s) => s.feedContextTitle, 'title', 'Best Vines'),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.hasMore, 'hasMore', false)
              .having((s) => s.isSubscribedListSelected, 'is list', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'falls back to For You when saved subscribed list no longer exists',
        setUp: () async {
          final videos = createTestVideos(2);
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': 'list:missing',
          });
          final sharedPreferences = await SharedPreferences.getInstance();

          when(
            () => mockCuratedListRepository.getListById('missing'),
          ).thenReturn(null);
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          savedModeBloc = VideoFeedBloc(
            videosRepository: mockVideosRepository,
            followRepository: mockFollowRepository,
            curatedListRepository: mockCuratedListRepository,
            sharedPreferences: sharedPreferences,
          );
        },
        build: () => savedModeBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.source.type,
            'source',
            VideoFeedSourceType.forYou,
          ),
          isA<VideoFeedBlocState>().having(
            (s) => s.status,
            'status',
            VideoFeedStatus.success,
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'emits noFollowedUsers when following list is empty on startup',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          // _loadVideos emits success with empty videos
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.following,
            hasMore: false,
          ),
          // _onStarted detects empty follows → noFollowedUsers CTA
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            mode: FeedMode.following,
            hasMore: false,
            error: VideoFeedError.noFollowedUsers,
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not emit noFollowedUsers for forYou when following list is empty',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedBlocState(),
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            hasMore: false,
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          const VideoFeedBlocState(
            status: VideoFeedStatus.failure,
            mode: FeedMode.following,
            error: VideoFeedError.loadFailed,
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'keeps hasMore true when fewer than page size returned',
        setUp: () {
          final videos = createTestVideos(3); // Less than 5 (page size)

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 3)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'sets hasMore to false when empty list returned',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not await initialized before calling repository',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          userPubkey: 'user-pubkey',
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          // Repository is called with empty authors (follow list
          // not yet initialized) — the fast path relies on
          // userPubkey to hit Funnelcake directly.
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: [],
              videoRefs: any(named: 'videoRefs'),
              userPubkey: 'user-pubkey',
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'refreshes following feed when follow repo initializes after initial load',
        // Regression test for: Following and For You show identical content
        // when the Funnelcake /feed endpoint returns stale/popular-fallback
        // content because FollowRepository.initialize() has not finished yet.
        //
        // Before the fix: the first followingStream replay was always ignored,
        // so no corrective refresh ever fired.
        //
        // After the fix: the first replay is processed when it differs from
        // the follow list used for the initial fetch, so the post-initialize()
        // emission triggers _onFollowingListChanged and does a skipCache
        // refresh with the real follow list.
        setUp: () {
          final popularVideos = createTestVideos(5, idPrefix: 'popular');
          final followingVideos = createTestVideos(5, idPrefix: 'following');

          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

          // Both calls (initial load + corrective refresh) share the same
          // signature; distinguish by call order via a counter.
          var callCount = 0;
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1
                ? HomeFeedResult(videos: popularVideos)
                : HomeFeedResult(videos: followingVideos);
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for the initial load to complete.
          await Future<void>.delayed(Duration.zero);
          // Simulate FollowRepository.initialize() completing and emitting
          // the real follow list. Because this first replay differs from the
          // list used for the initial fetch, it is NOT ignored.
          followingController.add(['author1', 'author2']);
          // Wait for _onFollowingListChanged to finish the corrective refresh.
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          // 1. Loading state
          const VideoFeedBlocState(mode: FeedMode.following),
          // 2. Initial load succeeds with popular/fallback content
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 5)
              .having(
                (s) => s.videos.first.id,
                'first video id',
                startsWith('popular'),
              ),
          // 3. Silent refresh replaces with real following content
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 5)
              .having(
                (s) => s.videos.first.id,
                'first video id',
                startsWith('following'),
              ),
        ],
        verify: (_) {
          // getHomeFeedVideos must be called twice: once for the initial load
          // (empty authors) and once for the corrective refresh (real authors).
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(2);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not refresh twice when cached follows replay before initialize finishes',
        setUp: () {
          final replayingFollowing = BehaviorSubject<List<String>>.seeded([
            'author1',
            'author2',
          ]);
          addTearDown(replayingFollowing.close);

          final followingVideos = createTestVideos(5, idPrefix: 'following');

          when(
            () => mockFollowRepository.followingStream,
          ).thenAnswer((_) => replayingFollowing.stream);
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author1', 'author2']);

          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: followingVideos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 5)
              .having(
                (s) => s.videos.first.id,
                'first video id',
                startsWith('following'),
              ),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: ['author1', 'author2'],
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      test(
        'abandons the telemetry session when a source load becomes stale',
        () async {
          final followingVideos = createTestVideos(2, idPrefix: 'following');
          final newVideos = createTestVideos(2, idPrefix: 'new');
          final followingResult = Completer<HomeFeedResult>();
          final newVideosResult = Completer<HomeFeedResult>();

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['pubkey']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) => followingResult.future);
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) => newVideosResult.future);

          final feedTracker = FeedPerformanceTracker(
            sink: const NoOpAnalyticsEventSink(),
          );
          final bloc = createBloc(feedTracker: feedTracker);
          addTearDown(bloc.close);

          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await pumpEventQueue();

          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.newVideos()));
          await pumpEventQueue();

          newVideosResult.complete(HomeFeedResult(videos: newVideos));
          await pumpEventQueue();

          followingResult.complete(HomeFeedResult(videos: followingVideos));
          await pumpEventQueue();

          expect(bloc.state.source, const VideoFeedSource.newVideos());
          expect(followingController.hasListener, isTrue);
          expect(curatedListsController.hasListener, isTrue);
          expect(feedTracker.activeSessionCount, 0);
        },
      );
    });

    group('VideoFeedModeChanged', () {
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'following fetches followed creators without subscribed list refs',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['pubkey']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: ['pubkey'],
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedSourceChanged(VideoFeedSource.following())),
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: ['pubkey'],
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'selected subscribed list fetches only that list in list order',
        setUp: () {
          final videos = createTestVideos(2);
          when(
            () => mockCuratedListRepository.getOrderedVideoIds('list-a'),
          ).thenReturn(['video-a', 'video-b']);
          when(
            () => mockVideosRepository.getVideosForList(['video-a', 'video-b']),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const VideoFeedSourceChanged(
            VideoFeedSource.subscribedList(
              listId: 'list-a',
              listName: 'Best Vines',
            ),
          ),
        ),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.subscribedList,
              )
              .having((s) => s.hasMore, 'loading hasMore', true),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.hasMore, 'hasMore', false)
              .having((s) => s.videos.length, 'videos count', 2),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getVideosForList(['video-a', 'video-b']),
          ).called(1);
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'classic source fetches popular classic videos via cursor',
        setUp: () {
          final videos = createTestVideos(2);
          when(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: videos,
              paginationCursor: 'next-page',
              hasMore: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoFeedSourceChanged(VideoFeedSource.classic())),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source.type,
                'source',
                VideoFeedSourceType.classic,
              )
              .having((s) => s.hasMore, 'loading hasMore', true),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.classic)
              .having((s) => s.videos.length, 'videos count', 2)
              .having((s) => s.hasMore, 'hasMore', true)
              .having((s) => s.paginationCursor, 'cursor', 'next-page'),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);
          verifyNever(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'classic load-more paginates with the stored cursor (no until)',
        setUp: () {
          when(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          ).thenAnswer((invocation) async {
            final cursor =
                invocation.namedArguments[const Symbol('cursor')] as String?;
            if (cursor == 'cursor-2') {
              // Page 2 is stamped *newer* than page 1 so a (wrong) timestamp
              // re-sort would surface it first — pinning the server-ranked
              // append order the cursor path must preserve.
              return HomeFeedResult(
                videos: createTestVideos(
                  2,
                  idPrefix: 'page2',
                  startTimestamp: 2000,
                ),
                hasMore: false,
              );
            }
            return HomeFeedResult(
              videos: createTestVideos(
                2,
                idPrefix: 'page1',
                startTimestamp: 1000,
              ),
              paginationCursor: 'cursor-2',
              hasMore: true,
            );
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.classic()));
          await pumpEventQueue();
          bloc.add(const VideoFeedLoadMoreRequested());
          await pumpEventQueue();
        },
        verify: (bloc) {
          verify(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: 'cursor-2',
              skipCache: any(named: 'skipCache'),
            ),
          ).called(1);
          expect(bloc.state.videos.length, 4);
          expect(bloc.state.hasMore, isFalse);
          // Server-ranked order is appended as-is, never re-sorted: page 1
          // (older) stays ahead of the newer page 2.
          expect(
            bloc.state.videos.map((v) => v.id).toList(),
            ['page1-0', 'page1-1', 'page2-0', 'page2-1'],
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'legacy latest mode change maps to New Videos',
        setUp: () {
          final videos = createTestVideos(5);

          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedModeChanged(FeedMode.latest)),
        expect: () => [
          const VideoFeedBlocState(source: VideoFeedSource.newVideos()),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.mode, 'mode', FeedMode.latest)
              .having((s) => s.videos.length, 'videos count', 5),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when legacy latest maps to already selected New Videos',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: const VideoFeedSource.newVideos(),
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedModeChanged(FeedMode.latest)),
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          );
        },
      );

      test(
        'ignores stale source response after a newer source is selected',
        () async {
          final followingVideos = createTestVideos(2, idPrefix: 'following');
          final newVideos = createTestVideos(2, idPrefix: 'new');
          final followingResult = Completer<HomeFeedResult>();
          final newVideosResult = Completer<HomeFeedResult>();

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['pubkey']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) => followingResult.future);
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) => newVideosResult.future);

          final bloc = createBloc();
          addTearDown(bloc.close);

          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.following()));
          await pumpEventQueue();

          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.newVideos()));
          await pumpEventQueue();

          newVideosResult.complete(HomeFeedResult(videos: newVideos));
          await pumpEventQueue();
          expect(bloc.state.source, const VideoFeedSource.newVideos());
          expect(bloc.state.videos.map((video) => video.id), [
            'new-0',
            'new-1',
          ]);

          followingResult.complete(HomeFeedResult(videos: followingVideos));
          await pumpEventQueue();

          expect(bloc.state.source, const VideoFeedSource.newVideos());
          expect(bloc.state.videos.map((video) => video.id), [
            'new-0',
            'new-1',
          ]);
        },
      );
    });

    group('VideoFeedLoadMoreRequested', () {
      late Completer<HomeFeedResult> loadMoreResult;
      late Completer<HomeFeedResult> sourceChangeResult;
      late List<VideoEvent> moreVideos;
      late List<VideoEvent> newVideos;

      setUp(() {
        loadMoreResult = Completer<HomeFeedResult>();
        sourceChangeResult = Completer<HomeFeedResult>();
        moreVideos = createTestVideos(2, idPrefix: 'more');
        newVideos = createTestVideos(2, idPrefix: 'new');

        addTearDown(() {
          if (!loadMoreResult.isCompleted) {
            loadMoreResult.complete(HomeFeedResult(videos: moreVideos));
          }
          if (!sourceChangeResult.isCompleted) {
            sourceChangeResult.complete(HomeFeedResult(videos: newVideos));
          }
        });
      });

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'clears stale pagination loading flag when source changes',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) => loadMoreResult.future);
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) => sourceChangeResult.future);
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: const VideoFeedSource.following(),
          videos: createTestVideos(3),
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedLoadMoreRequested());
          await pumpEventQueue();

          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.newVideos()));
          await pumpEventQueue();

          sourceChangeResult.complete(HomeFeedResult(videos: newVideos));
          await pumpEventQueue();

          loadMoreResult.complete(HomeFeedResult(videos: moreVideos));
          await pumpEventQueue();
        },
        expect: () => [
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source,
                'source',
                const VideoFeedSource.following(),
              )
              .having((s) => s.isLoadingMore, 'isLoadingMore', isTrue),
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source,
                'source',
                const VideoFeedSource.newVideos(),
              )
              .having((s) => s.status, 'status', VideoFeedStatus.loading)
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
          isA<VideoFeedBlocState>()
              .having(
                (s) => s.source,
                'source',
                const VideoFeedSource.newVideos(),
              )
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videos.map((video) => video.id), 'video ids', [
                'new-0',
                'new-1',
              ]),
        ],
      );

      // getNewVideos reports hasMore itself, so the newVideos source paginates
      // on that flag instead of the "did anything new arrive" fallback. A page
      // that adds videos but says the source is dry must stop pagination.
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'stops newVideos pagination on the repository hasMore flag',
        setUp: () {
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              cursor: 'p:next-page',
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(videos: moreVideos, hasMore: false),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: const VideoFeedSource.newVideos(),
          videos: createTestVideos(3),
          paginationCursor: 'p:next-page',
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        skip: 1,
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videos, 'videos', hasLength(5))
              .having((s) => s.hasMore, 'hasMore', isFalse),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'uses recommendations pagination path for forYou mode',
        setUp: () {
          final moreVideos = createTestVideos(
            2,
            startTimestamp: 1000,
            idPrefix: 'recommended',
          );

          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: moreVideos,
              paginationCursor: 'rec-page-3',
              hasMore: true,
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          paginationCursor: 'rec-page-2',
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize + 2)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              cursor: 'rec-page-2',
              revalidate: any(named: 'revalidate'),
            ),
          ).called(1);
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'preserves forYou recommendation order when next page has newer '
        'createdAt timestamps',
        setUp: () {
          final newerVideos = [
            createTestVideo('newer-c', createdAt: 5000),
            createTestVideo('newer-d', createdAt: 4999),
          ];

          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: newerVideos,
              paginationCursor: 'rec-page-3',
              hasMore: true,
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [
            createTestVideo('old-a', createdAt: 1000),
            createTestVideo('old-b', createdAt: 999),
          ],
          paginationCursor: 'rec-page-2',
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video ids',
                equals(['old-a', 'old-b', 'newer-c', 'newer-d']),
              ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'filters duplicate IDs from the next forYou page while preserving '
        'order',
        setUp: () {
          final nextPage = [
            createTestVideo('old-b', createdAt: 5000),
            createTestVideo('newer-c', createdAt: 4999),
          ];

          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: nextPage,
              paginationCursor: 'rec-page-3',
              hasMore: true,
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: [
            createTestVideo('old-a', createdAt: 1000),
            createTestVideo('old-b', createdAt: 999),
          ],
          paginationCursor: 'rec-page-2',
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video ids',
                equals(['old-a', 'old-b', 'newer-c']),
              ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'sorts merged following feed chronologically on load more',
        setUp: () {
          final newerVideos = [
            createTestVideo('newer-c', createdAt: 5000),
            createTestVideo('newer-d', createdAt: 4999),
          ];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: newerVideos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: [
            createTestVideo('old-a', createdAt: 1000),
            createTestVideo('old-b', createdAt: 999),
          ],
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video ids',
                equals(['newer-c', 'newer-d', 'old-a', 'old-b']),
              ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'uses inclusive oldest timestamp when loading more following videos',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: [createTestVideo('same-second-c', createdAt: 1999)],
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: [
            createTestVideo('old-a', createdAt: 2000),
            createTestVideo('old-b', createdAt: 1999),
          ],
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            false,
          ),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: 1999,
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'stops following pagination when load more returns only duplicates',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: [createTestVideo('old-b', createdAt: 1999)],
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: [
            createTestVideo('old-a', createdAt: 2000),
            createTestVideo('old-b', createdAt: 1999),
          ],
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.hasMore, 'hasMore', false)
              .having((s) => s.videos.length, 'videos count', 2),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'deduplicates republished following videos by addressable identity',
        setUp: () {
          const author =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([author]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: [
                createTestVideo(
                  'republished-event-id',
                  pubkey: author,
                  vineId: 'shared-d-tag',
                  createdAt: 1999,
                ),
                createTestVideo('new-video', createdAt: 1998),
              ],
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: [
            createTestVideo(
              'original-event-id',
              pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              vineId: 'shared-d-tag',
              createdAt: 2000,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having(
                (s) => s.videos.map((v) => v.id),
                'video ids',
                equals(['original-event-id', 'new-video']),
              ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'keeps same d-tag videos from different authors',
        setUp: () {
          const authorB =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([authorB]);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: [
                createTestVideo(
                  'author-b-event',
                  pubkey: authorB,
                  vineId: 'shared-d-tag',
                  createdAt: 1999,
                ),
              ],
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: [
            createTestVideo(
              'author-a-event',
              pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              vineId: 'shared-d-tag',
              createdAt: 2000,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', 2),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'stops forYou pagination when the current page has no cursor',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having((s) => s.hasMore, 'hasMore', false),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'appends new videos to existing list',
        setUp: () {
          // Use different ID prefix to ensure unique videos
          final moreVideos = createTestVideos(
            pageSize,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: moreVideos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize * 2)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when not in success state',
        build: createBloc,
        seed: () => const VideoFeedBlocState(),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(5),
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when hasMore is false',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(5),
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when videos list is empty',
        build: createBloc,
        seed: () => const VideoFeedBlocState(status: VideoFeedStatus.success),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'keeps hasMore true when fewer than page size returned from load more',
        setUp: () {
          // Return fewer videos than page size with unique IDs.
          // Server-side filtering can reduce the count below _pageSize
          // even when more content exists.
          final moreVideos = createTestVideos(
            2,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: moreVideos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize + 2)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'sets hasMore to false when empty list returned from load more',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'drops concurrent requests via droppable transformer',
        setUp: () {
          final moreVideos = createTestVideos(
            pageSize,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            // Simulate network delay
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return HomeFeedResult(videos: moreVideos);
          });
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
        ),
        act: (bloc) {
          // Fire multiple events simultaneously — droppable should
          // process only the first and drop the rest while it's running.
          bloc
            ..add(const VideoFeedLoadMoreRequested())
            ..add(const VideoFeedLoadMoreRequested())
            ..add(const VideoFeedLoadMoreRequested());
        },
        wait: const Duration(milliseconds: 200),
        verify: (_) {
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'deduplicates overlapping videos from Funnelcake and Nostr',
        setUp: () {
          // Return videos that partially overlap with existing ones.
          // This happens when Funnelcake runs out and Nostr returns
          // some of the same videos.
          createTestVideos(3, startTimestamp: 2000, idPrefix: 'existing');
          final overlappingVideos = [
            // 2 duplicates (same IDs as existing)
            ...createTestVideos(2, startTimestamp: 2000, idPrefix: 'existing'),
            // 3 truly new
            ...createTestVideos(3, startTimestamp: 1000, idPrefix: 'new'),
          ];

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: overlappingVideos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(
            3,
            startTimestamp: 2000,
            idPrefix: 'existing',
          ),
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              // 3 existing + 3 new = 6 (2 duplicates removed)
              .having((s) => s.videos.length, 'videos count', 6)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'resets isLoadingMore on error',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', 5),
        ],
      );
    });

    group('VideoFeedRefreshRequested', () {
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'clears videos and reloads from beginning',
        setUp: () {
          final freshVideos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: freshVideos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(10), // Previous videos
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const VideoFeedRefreshRequested()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
        verify: (_) {
          // Verify called without 'until' parameter (fresh fetch)
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'clears error on refresh',
        setUp: () {
          final videos = createTestVideos(5);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => const VideoFeedBlocState(
          status: VideoFeedStatus.failure,
          mode: FeedMode.following,
          error: VideoFeedError.loadFailed,
        ),
        act: (bloc) => bloc.add(const VideoFeedRefreshRequested()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.error, 'error', isNull),
        ],
      );
    });

    group('VideoFeedAutoRefreshRequested', () {
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'refreshes when on home mode and data is stale',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          autoRefreshMinInterval: Duration.zero,
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'revalidates New when data is stale',
        setUp: () {
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(videos: createTestVideos(pageSize)),
          );
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          autoRefreshMinInterval: Duration.zero,
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.latest),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              revalidate: true,
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when mode is classic',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.classic,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getClassicVideos(
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
              skipCache: any(named: 'skipCache'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'refreshes forYou when data is stale',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          autoRefreshMinInterval: Duration.zero,
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => [
          const VideoFeedBlocState(),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: true,
              revalidate: any(named: 'revalidate'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing for forYou when data is fresh '
        '(last refresh within auto-refresh interval)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          // Large interval so data is always considered fresh
          autoRefreshMinInterval: const Duration(hours: 1),
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize),
        ),
        act: (bloc) async {
          // First, trigger a load so _lastRefreshedAt gets set
          bloc.add(const VideoFeedStarted());
          await Future<void>.delayed(Duration.zero);

          // Now the auto-refresh should be skipped (data is fresh)
          bloc.add(const VideoFeedAutoRefreshRequested());
        },
        skip: 2, // Skip the loading + success from VideoFeedStarted
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when data is fresh '
        '(last refresh within auto-refresh interval)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          // Large interval so data is always considered fresh
          autoRefreshMinInterval: const Duration(hours: 1),
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(pageSize),
        ),
        act: (bloc) async {
          // First, trigger a load so _lastRefreshedAt gets set
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);

          // Now the auto-refresh should be skipped (data is fresh)
          bloc.add(const VideoFeedAutoRefreshRequested());
        },
        skip: 2, // Skip the loading + success from VideoFeedStarted
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'refreshes when auto-refresh interval has elapsed',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          autoRefreshMinInterval: Duration.zero,
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          videos: createTestVideos(pageSize),
        ),
        act: (bloc) async {
          // First load sets _lastRefreshedAt
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);

          // With Duration.zero interval, this should refresh
          bloc.add(const VideoFeedAutoRefreshRequested());
        },
        skip: 2, // Skip the loading + success from VideoFeedStarted
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'refreshes when _lastRefreshedAt is null '
        '(feed never loaded successfully)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => const VideoFeedBlocState(
          status: VideoFeedStatus.failure,
          mode: FeedMode.following,
          error: VideoFeedError.loadFailed,
        ),
        act: (bloc) => bloc.add(const VideoFeedAutoRefreshRequested()),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
      );
    });

    group('VideoFeedFollowingListChanged', () {
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'silently refreshes home feed on follow list change',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['new-author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(3),
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['new-author'])),
        expect: () => [
          // No loading state — silent refresh replaces in-place
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.mode, 'mode', FeedMode.following),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when mode is not home',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['new-author'])),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when feed is still loading',
        build: createBloc,
        seed: () => const VideoFeedBlocState(mode: FeedMode.following),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['new-author'])),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'transitions from noFollowedUsers to loaded feed',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['first-follow']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        seed: () => const VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          hasMore: false,
          error: VideoFeedError.noFollowedUsers,
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedFollowingListChanged(['first-follow'])),
        expect: () => [
          // No loading state — silent refresh replaces in-place
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.error, 'error', isNull),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'skips initial follow list replay to avoid redundant API call',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for initial load to complete (Funnelcake loaded content)
          await Future<void>.delayed(Duration.zero);
          // First stream emission is skipped (BehaviorSubject replay)
          followingController.add(['author']);
        },
        skip: 2, // Skip loading + success from VideoFeedStarted
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          // Called only once — the replay is skipped, no redundant call
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'silently refreshes on second follow list emission after feed '
        'is empty (Funnelcake failed)',
        setUp: () {
          final videos = createTestVideos(pageSize);
          var callCount = 0;

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return const HomeFeedResult(videos: []);
            }
            return HomeFeedResult(videos: videos);
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for initial load to complete (Funnelcake returned empty)
          await Future<void>.delayed(Duration.zero);
          // First emission is skipped (BehaviorSubject replay)
          followingController.add(['author']);
          await Future<void>.delayed(Duration.zero);
          // Second emission triggers recovery
          followingController.add(['author', 'new-follow']);
        },
        skip: 2, // Skip loading + success(empty) from VideoFeedStarted
        expect: () => [
          // No loading state — silent refresh replaces in-place
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize),
        ],
        verify: (_) {
          // Called twice: initial (empty), then recovery on 2nd emission
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(2);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'silently refreshes on runtime follow list changes '
        '(skips initial replay)',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);
          // First emission is skipped (BehaviorSubject replay)
          followingController.add(['author']);
          await Future<void>.delayed(Duration.zero);
          // Runtime follow — triggers silent refresh
          followingController.add(['author', 'new-author']);
        },
        skip: 2, // Skip loading + success from VideoFeedStarted
        // No state changes — same videos returned, Equatable deduplicates
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          // Called 2 times: initial + runtime (replay is skipped)
          verify(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(2);
        },
      );
    });

    group('VideoFeedCuratedListsChanged', () {
      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'updates subscribed lists without refreshing plain Following',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(3),
        ),
        act: (bloc) =>
            bloc.add(VideoFeedCuratedListsChanged([createTestList()])),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((s) => s.subscribedLists, 'lists', hasLength(1))
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 3),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'refreshes selected subscribed list when curated lists change',
        setUp: () {
          final videos = createTestVideos(2);
          when(
            () => mockCuratedListRepository.getOrderedVideoIds('list-a'),
          ).thenReturn(['video-a', 'video-b']);
          when(
            () => mockVideosRepository.getVideosForList(['video-a', 'video-b']),
          ).thenAnswer((_) async => videos);
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: const VideoFeedSource.subscribedList(
            listId: 'list-a',
            listName: 'Best Vines',
          ),
          videos: createTestVideos(3),
        ),
        act: (bloc) =>
            bloc.add(VideoFeedCuratedListsChanged([createTestList()])),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.loading)
              .having((s) => s.subscribedLists, 'lists', hasLength(1)),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', 2)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'falls back to forYou when selected subscribed list is unsubscribed',
        setUp: () async {
          SharedPreferences.setMockInitialValues({
            'video_feed_mode': 'list:list-a',
          });
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(videos: createTestVideos(2)),
          );
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
        ),
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: const VideoFeedSource.subscribedList(
            listId: 'list-a',
            listName: 'Best Vines',
          ),
          subscribedLists: [createTestList()],
          videos: createTestVideos(3),
        ),
        // List-a is no longer in the subscribed set — emulates unsubscribe.
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.loading)
              .having(
                (s) => s.source.type,
                'source type',
                VideoFeedSourceType.forYou,
              )
              .having((s) => s.subscribedLists, 'lists', isEmpty),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having(
                (s) => s.source.type,
                'source type',
                VideoFeedSourceType.forYou,
              )
              .having((s) => s.videos.length, 'videos count', 2),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not refresh plain Following when curated lists change',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when mode is not home',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.latest,
          videos: createTestVideos(5),
        ),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does nothing when feed is still loading',
        build: createBloc,
        seed: () => const VideoFeedBlocState(mode: FeedMode.following),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => <VideoFeedBlocState>[],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'subscribes to subscribedListsStream on startup',
        setUp: () {
          final videos = createTestVideos(pageSize);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(['author']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          // Wait for initial load to complete
          await Future<void>.delayed(Duration.zero);
          // First stream emission is skipped (BehaviorSubject replay)
          curatedListsController.add(const []);
          await Future<void>.delayed(Duration.zero);
          // Second emission updates state.subscribedLists.
          curatedListsController.add([createTestList()]);
        },
        skip: 2, // Skip loading + success from VideoFeedStarted
        expect: () => [
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'videos count', pageSize)
              .having((s) => s.subscribedLists, 'lists', hasLength(1)),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not fetch home attribution when plain Following curated lists change',
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(3),
        ),
        act: (bloc) => bloc.add(const VideoFeedCuratedListsChanged()),
        expect: () => <VideoFeedBlocState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'merges attribution metadata on load more',
        setUp: () {
          final moreVideos = createTestVideos(
            pageSize,
            startTimestamp: 1000,
            idPrefix: 'more',
          );

          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: moreVideos,
              videoListSources: {
                'more-0': {'list-2'},
              },
              listOnlyVideoIds: {'more-0'},
            ),
          );
        },
        build: createBloc,
        seed: () => VideoFeedBlocState(
          status: VideoFeedStatus.success,
          mode: FeedMode.following,
          videos: createTestVideos(pageSize, startTimestamp: 2000),
          videoListSources: const {
            'existing-0': {'list-1'},
          },
          listOnlyVideoIds: const {'existing-0'},
        ),
        act: (bloc) => bloc.add(const VideoFeedLoadMoreRequested()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videoListSources, 'videoListSources', {
                'existing-0': {'list-1'},
                'more-0': {'list-2'},
              })
              .having((s) => s.listOnlyVideoIds, 'listOnlyVideoIds', {
                'existing-0',
                'more-0',
              }),
        ],
      );
    });

    group('close', () {
      test('does not throw when stream emits after close', () async {
        final videos = createTestVideos(pageSize);

        when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
        when(
          () => mockVideosRepository.getHomeFeedVideos(
            authors: any(named: 'authors'),
            videoRefs: any(named: 'videoRefs'),
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => HomeFeedResult(videos: videos));

        final bloc = createBloc();
        bloc.add(const VideoFeedStarted(mode: FeedMode.following));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(followingController.hasListener, isTrue);
        expect(curatedListsController.hasListener, isTrue);

        await bloc.close();
        expect(followingController.hasListener, isFalse);
        expect(curatedListsController.hasListener, isFalse);

        // After closing, stream events should not cause errors
        expect(() => followingController.add(['a']), returnsNormally);
        expect(
          () => curatedListsController.add([createTestList()]),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);
      });
    });

    group('feed performance tracking', () {
      late _MockFeedPerformanceTracker mockTracker;
      late FeedLoadHandle feedLoad;

      setUp(() {
        mockTracker = _MockFeedPerformanceTracker();
        feedLoad = FeedPerformanceTracker(
          sink: const NoOpAnalyticsEventSink(),
        ).startFeedLoad('test');
        when(() => mockTracker.startFeedLoad(any())).thenReturn(feedLoad);
      });

      VideoFeedBloc createBlocWithTracker() => VideoFeedBloc(
        videosRepository: mockVideosRepository,
        followRepository: mockFollowRepository,
        curatedListRepository: mockCuratedListRepository,
        feedTracker: mockTracker,
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'calls startFeedLoad on VideoFeedStarted',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBlocWithTracker,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('following')).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'records first-visible and fresh-result milestones on success',
        setUp: () {
          final videos = createTestVideos(3);
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResult(
              videos: videos,
              followingPageCount: 2,
            ),
          );
        },
        build: createBlocWithTracker,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () => mockTracker.markFirstVideosReceived(feedLoad, 3),
          ).called(1);
          verify(
            () => mockTracker.markFirstVisibleContent(
              feedLoad,
              3,
              servedFromCache: false,
            ),
          ).called(1);
          verify(
            () => mockTracker.markFreshResultCompleted(
              feedLoad,
              3,
              followingPageCount: 2,
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'calls trackFeedError on failure',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn(['a']);
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBlocWithTracker,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () => mockTracker.trackFeedError(
              'following',
              errorType: 'load_failed',
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
          verifyNever(
            () => mockTracker.markFirstVideosReceived(feedLoad, any()),
          );
          verifyNever(
            () => mockTracker.markFreshResultCompleted(feedLoad, any()),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'uses New Videos feed type for legacy latest mode',
        setUp: () {
          final videos = createTestVideos(3);
          when(
            () => mockVideosRepository.getNewVideos(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const VideoFeedStarted(mode: FeedMode.latest)),
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('latest')).called(1);
          verify(
            () => mockTracker.markFirstVideosReceived(feedLoad, 3),
          ).called(1);
          verify(
            () => mockTracker.markFreshResultCompleted(feedLoad, 3),
          ).called(1);
        },
      );
    });

    group('cache-first home feed', () {
      late _MockHomeFeedCache mockCache;
      late SharedPreferences sharedPreferences;
      late StreamController<List<String>> cacheFollowingController;
      late StreamController<List<CuratedList>> cacheCuratedListsController;

      setUpAll(() {
        registerFallbackValue(_FakeSharedPreferences());
        registerFallbackValue(<VideoEvent>[]);
      });

      setUp(() async {
        mockCache = _MockHomeFeedCache();
        SharedPreferences.setMockInitialValues({});
        sharedPreferences = await SharedPreferences.getInstance();
        cacheFollowingController = StreamController<List<String>>.broadcast();
        cacheCuratedListsController =
            StreamController<List<CuratedList>>.broadcast();

        when(
          () => mockFollowRepository.followingStream,
        ).thenAnswer((_) => cacheFollowingController.stream);
        when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
        when(
          () => mockCuratedListRepository.subscribedListsStream,
        ).thenAnswer((_) => cacheCuratedListsController.stream);

        // Default passthrough so existing cache tests keep working. Individual
        // tests can override this stub to exercise the filter behavior.
        when(
          () => mockVideosRepository.applyContentPreferences(any()),
        ).thenAnswer(
          (invocation) =>
              invocation.positionalArguments.first as List<VideoEvent>,
        );

        // Default cache stubs: empty cache, no-op writes. Tests override the
        // reads to exercise the serve / splice / restore paths.
        when(
          () => mockCache.readVideos(
            pubkey: any(named: 'pubkey'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockCache.writeVideos(
            pubkey: any(named: 'pubkey'),
            mode: any(named: 'mode'),
            videos: any(named: 'videos'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockCache.clearVideos(
            pubkey: any(named: 'pubkey'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async {});
      });

      tearDown(() {
        cacheFollowingController.close();
        cacheCuratedListsController.close();
      });

      VideoFeedBloc createBlocWithCache() => VideoFeedBloc(
        videosRepository: mockVideosRepository,
        followRepository: mockFollowRepository,
        curatedListRepository: mockCuratedListRepository,
        sharedPreferences: sharedPreferences,
        homeFeedCache: mockCache,
      );

      void stubFollowingFetch(List<VideoEvent> videos) {
        when(
          () => mockVideosRepository.getHomeFeedVideos(
            authors: any(named: 'authors'),
            videoRefs: any(named: 'videoRefs'),
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => HomeFeedResult(videos: videos));
      }

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'serves cached videos then splices fresh after the active video',
        setUp: () {
          when(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          ).thenAnswer((_) async => createTestVideos(5, idPrefix: 'cached'));
          stubFollowingFetch(createTestVideos(3, idPrefix: 'fresh'));
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          // Cached window served instantly at index 0.
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'cached count', 5)
              .having((s) => s.currentIndex, 'served index', 0)
              .having((s) => s.videos.first.id, 'first cached id', 'cached-0'),
          // Splice: keep [0 .. currentIndex + 1] (cached-0, cached-1) then
          // fresh, so fresh appears right after the active video:
          // [cached-0, cached-1, fresh-0, fresh-1, fresh-2].
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'spliced count', 5)
              .having((s) => s.videos[0].id, 'kept head id', 'cached-0')
              .having((s) => s.videos[1].id, 'kept lookahead id', 'cached-1')
              .having((s) => s.videos[2].id, 'first fresh id', 'fresh-0'),
        ],
        verify: (_) {
          verify(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'serves cached For You then refreshes (supersedes #3861 exclusion)',
        setUp: () {
          when(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          ).thenAnswer((_) async => createTestVideos(2, idPrefix: 'cached'));
          when(
            () => mockVideosRepository.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer(
            (_) async =>
                HomeFeedResult(videos: createTestVideos(3, idPrefix: 'rec')),
          );
        },
        build: createBlocWithCache,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          const VideoFeedBlocState(),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'cached count', 2)
              .having((s) => s.videos.first.id, 'first cached id', 'cached-0'),
          isA<VideoFeedBlocState>()
              .having((s) => s.videos.length, 'spliced count', 5)
              .having((s) => s.videos[2].id, 'first fresh id', 'rec-0'),
        ],
        verify: (_) {
          verify(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'replaces wholesale when no cache exists',
        setUp: () => stubFollowingFetch(createTestVideos(3)),
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'count', 3),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'keeps cached data visible when the network fails',
        setUp: () {
          when(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          ).thenAnswer((_) async => createTestVideos(2, idPrefix: 'cached'));
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('network error'));
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'cached count', 2),
          // No failure state — cached data stays visible.
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not serve cache for a subscribed list source',
        setUp: () async {
          SharedPreferences.setMockInitialValues({
            'selected_feed_mode': 'list:list-a',
          });
          sharedPreferences = await SharedPreferences.getInstance();
          when(
            () => mockCuratedListRepository.getListById('list-a'),
          ).thenReturn(createTestList());
          when(
            () => mockCuratedListRepository.getOrderedVideoIds('list-a'),
          ).thenReturn(['video-a', 'video-b']);
          when(
            () => mockVideosRepository.getVideosForList(['video-a', 'video-b']),
          ).thenAnswer((_) async => createTestVideos(3));
        },
        build: createBlocWithCache,
        act: (bloc) => bloc.add(const VideoFeedStarted()),
        expect: () => [
          isA<VideoFeedBlocState>().having(
            (s) => s.source.type,
            'source',
            VideoFeedSourceType.subscribedList,
          ),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'count', 3),
        ],
        verify: (_) {
          verifyNever(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          );
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'filters cached videos through applyContentPreferences',
        setUp: () {
          final hidden = VideoEvent(
            id: '1' * 64,
            pubkey: '0' * 64,
            createdAt: 1704067200,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
            title: 'Hidden',
            videoUrl: 'https://example.com/hidden.mp4',
            moderationLabels: const ['nudity'],
          );
          final visible = VideoEvent(
            id: '2' * 64,
            pubkey: '0' * 64,
            createdAt: 1704067200,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
            title: 'Visible',
            videoUrl: 'https://example.com/visible.mp4',
          );

          when(
            () => mockCache.readVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
            ),
          ).thenAnswer((_) async => [hidden, visible]);
          when(
            () => mockVideosRepository.applyContentPreferences(any()),
          ).thenReturn([visible]);
          stubFollowingFetch([hidden, visible]);
        },
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.videos.length, 'filtered cached count', 1)
              .having((s) => s.videos.first.id, 'visible id', '2' * 64),
          isA<VideoFeedBlocState>().having(
            (s) => s.videos.length,
            'spliced count',
            2,
          ),
        ],
        verify: (_) {
          final captured = verify(
            () => mockVideosRepository.applyContentPreferences(captureAny()),
          ).captured;
          final list = captured.first as List<VideoEvent>;
          expect(list.map((v) => v.id), contains('1' * 64));
          expect(list.map((v) => v.id), contains('2' * 64));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'advances the resume window past the active position on a fetch',
        setUp: () => stubFollowingFetch(createTestVideos(3, idPrefix: 'fresh')),
        build: createBlocWithCache,
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          // Active index 0 + offset 1 = 1 → forward window starts past the
          // just-shown video, dropping only it.
          final captured = verify(
            () => mockCache.writeVideos(
              pubkey: any(named: 'pubkey'),
              mode: 'following',
              videos: captureAny(named: 'videos'),
            ),
          ).captured;
          final window = captured.last as List<VideoEvent>;
          expect(window.map((v) => v.id), equals(['fresh-1', 'fresh-2']));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'on swipe, persists the forward window starting past the active video',
        setUp: () => stubFollowingFetch(createTestVideos(5, idPrefix: 'fresh')),
        build: createBlocWithCache,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoFeedActiveIndexChanged(2));
        },
        // The swipe persist is trailing-debounced, so wait past the debounce
        // window for the disk write to fire.
        wait: const Duration(milliseconds: 700),
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos.length, 'count', 5),
          isA<VideoFeedBlocState>().having(
            (s) => s.currentIndex,
            'active index',
            2,
          ),
        ],
        verify: (_) {
          // Last write is the swipe: active index 2 + offset 1 = 3 →
          // [fresh-3, fresh-4]. (An earlier load-time write from index 0 also
          // occurs.)
          final captured = verify(
            () => mockCache.writeVideos(
              pubkey: any(named: 'pubkey'),
              mode: 'following',
              videos: captureAny(named: 'videos'),
            ),
          ).captured;
          final window = captured.last as List<VideoEvent>;
          expect(window.map((v) => v.id), equals(['fresh-3', 'fresh-4']));
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'clears the resume cache when swiped to the end of the window',
        setUp: () => stubFollowingFetch(createTestVideos(3, idPrefix: 'fresh')),
        build: createBlocWithCache,
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(Duration.zero);
          // Index 2 + offset 1 = 3 == length → nothing left to resume to.
          bloc.add(const VideoFeedActiveIndexChanged(2));
        },
        wait: const Duration(milliseconds: 700),
        verify: (_) {
          // An empty forward window must invalidate the key, not no-op — else
          // the next cold start re-serves already-seen videos.
          verify(
            () => mockCache.clearVideos(
              pubkey: any(named: 'pubkey'),
              mode: 'following',
            ),
          ).called(1);
          // No write should ever carry an empty list (those route to clear).
          final writes = verify(
            () => mockCache.writeVideos(
              pubkey: any(named: 'pubkey'),
              mode: any(named: 'mode'),
              videos: captureAny(named: 'videos'),
            ),
          ).captured;
          expect(
            writes.every((w) => (w as List<VideoEvent>).isNotEmpty),
            isTrue,
          );
        },
      );
    });

    group('creator profile prefetching', () {
      final pubkeyA = 'a' * 64;
      final pubkeyB = 'b' * 64;
      final pubkeyC = 'c' * 64;

      VideoEvent videoWithPubkey(String id, String pubkey, {int? createdAt}) {
        final timestamp =
            createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return VideoEvent(
          id: id,
          pubkey: pubkey,
          createdAt: timestamp,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
          title: 'Test Video $id',
          videoUrl: 'https://example.com/$id.mp4',
          thumbnailUrl: 'https://example.com/$id.jpg',
        );
      }

      UserProfile profileForPubkey(String pubkey) => UserProfile(
        pubkey: pubkey,
        eventId: 'event-$pubkey',
        rawData: const {},
        createdAt: DateTime(2024),
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'fetches creator profiles when videos load',
        setUp: () {
          final baseTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final videos = [
            videoWithPubkey('v1', pubkeyA, createdAt: baseTime),
            videoWithPubkey('v2', pubkeyB, createdAt: baseTime - 1),
          ];

          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => HomeFeedResult(videos: videos));

          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer(
            (_) async => {
              pubkeyA: profileForPubkey(pubkeyA),
              pubkeyB: profileForPubkey(pubkeyB),
            },
          );
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          profileRepository: mockProfileRepository,
        ),
        act: (bloc) =>
            bloc.add(const VideoFeedStarted(mode: FeedMode.following)),
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(1);
        },
        expect: () => [
          const VideoFeedBlocState(mode: FeedMode.following),
          // Videos loaded (no profiles yet)
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', hasLength(2))
              .having((s) => s.creatorProfiles, 'profiles', isEmpty),
          // Profiles fetched
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.creatorProfiles, 'profiles', hasLength(2)),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'fetches only new profiles on pagination',
        setUp: () {
          final baseTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final initialVideos = [
            videoWithPubkey('v1', pubkeyA, createdAt: baseTime),
          ];
          final moreVideos = [
            videoWithPubkey('v2', pubkeyB, createdAt: baseTime - 2),
            videoWithPubkey('v3', pubkeyC, createdAt: baseTime - 3),
          ];

          var callCount = 0;
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return HomeFeedResult(videos: initialVideos);
            }
            return HomeFeedResult(videos: moreVideos);
          });

          when(
            () => mockProfileRepository.fetchBatchProfiles(pubkeys: [pubkeyA]),
          ).thenAnswer((_) async => {pubkeyA: profileForPubkey(pubkeyA)});

          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys', that: isNot(equals([pubkeyA]))),
            ),
          ).thenAnswer(
            (_) async => {
              pubkeyB: profileForPubkey(pubkeyB),
              pubkeyC: profileForPubkey(pubkeyC),
            },
          );
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          profileRepository: mockProfileRepository,
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const VideoFeedLoadMoreRequested());
        },
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(2);
        },
        expect: () => [
          // Loading
          const VideoFeedBlocState(mode: FeedMode.following),
          // Initial videos loaded
          isA<VideoFeedBlocState>()
              .having((s) => s.status, 'status', VideoFeedStatus.success)
              .having((s) => s.videos, 'videos', hasLength(1)),
          // Profiles for initial videos
          isA<VideoFeedBlocState>().having(
            (s) => s.creatorProfiles,
            'profiles after initial',
            hasLength(1),
          ),
          // Pagination loading
          isA<VideoFeedBlocState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          // Pagination complete
          isA<VideoFeedBlocState>()
              .having((s) => s.videos, 'videos', hasLength(3))
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
          // Profiles for new creators
          isA<VideoFeedBlocState>().having(
            (s) => s.creatorProfiles,
            'profiles after pagination',
            hasLength(3),
          ),
        ],
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'does not re-fetch existing profiles on pagination',
        setUp: () {
          final baseTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final initialVideos = [
            videoWithPubkey('v1', pubkeyA, createdAt: baseTime),
          ];
          // Pagination returns a video from the same creator
          final moreVideos = [
            videoWithPubkey('v2', pubkeyA, createdAt: baseTime - 2),
          ];

          var callCount = 0;
          when(
            () => mockVideosRepository.getHomeFeedVideos(
              authors: any(named: 'authors'),
              videoRefs: any(named: 'videoRefs'),
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) {
              return HomeFeedResult(videos: initialVideos);
            }
            return HomeFeedResult(videos: moreVideos);
          });

          when(
            () => mockProfileRepository.fetchBatchProfiles(pubkeys: [pubkeyA]),
          ).thenAnswer((_) async => {pubkeyA: profileForPubkey(pubkeyA)});
        },
        build: () => VideoFeedBloc(
          videosRepository: mockVideosRepository,
          followRepository: mockFollowRepository,
          curatedListRepository: mockCuratedListRepository,
          profileRepository: mockProfileRepository,
        ),
        act: (bloc) async {
          bloc.add(const VideoFeedStarted(mode: FeedMode.following));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bloc.add(const VideoFeedLoadMoreRequested());
        },
        verify: (_) {
          // fetchBatchProfiles should only be called once (initial load).
          // Pagination has no new pubkeys, so no second call.
          verify(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).called(1);
        },
      );
    });
  });
}
