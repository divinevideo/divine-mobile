// ABOUTME: Tests for VideoSearchBloc - progressive search via
// ABOUTME: VideosRepository.searchVideos() stream.
// ABOUTME: Verifies debounce, clear, progressive emission, and error handling.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group(VideoSearchBloc, () {
    late _MockVideosRepository mockVideosRepository;
    late StreamController<List<VideoEvent>> trendingController;
    late Completer<void> trendingSubscribed;
    late Completer<({List<VideoEvent> videos, int totalCount, bool hasMore})>
    loadMoreCompleter;
    late Completer<void> loadMoreStarted;

    const debounceDuration = Duration(milliseconds: 400);

    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;

    setUpAll(() {
      registerFallbackValue(VideoSearchSort.trending);
    });

    VideoEvent createVideo({
      required String id,
      String pubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      String? title,
      String? content,
      List<String> hashtags = const [],
    }) {
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        content: content ?? '',
        title: title,
        createdAt: timestamp,
        timestamp: now,
        hashtags: hashtags,
      );
    }

    setUp(() {
      mockVideosRepository = _MockVideosRepository();

      // Default stub: empty stream
      when(
        () => mockVideosRepository.searchVideos(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          sort: any(named: 'sort'),
        ),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () =>
            mockVideosRepository.countVideosLocally(query: any(named: 'query')),
      ).thenAnswer((_) async => 0);
      when(
        () => mockVideosRepository.searchVideosViaApi(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sort: any(named: 'sort'),
        ),
      ).thenAnswer(
        (_) async => (videos: <VideoEvent>[], totalCount: 0, hasMore: false),
      );
      when(
        () => mockVideosRepository.deduplicateVideosPreservingOrder(any()),
      ).thenAnswer((inv) => inv.positionalArguments.first as List<VideoEvent>);
    });

    VideoSearchBloc createBloc() =>
        VideoSearchBloc(videosRepository: mockVideosRepository);

    test('initial state is correct', () async {
      final bloc = createBloc();
      expect(bloc.state.status, VideoSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.resultCount, isNull);
      expect(bloc.state.sort, VideoSearchSort.trending);
      await bloc.close();
    });

    group('VideoSearchQueryChanged', () {
      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const VideoSearchState()],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
              sort: any(named: 'sort'),
            ),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const VideoSearchState()],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
              sort: any(named: 'sort'),
            ),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits initial state when query is a single character',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('a')),
        wait: debounceDuration,
        expect: () => [const VideoSearchState()],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
              sort: any(named: 'sort'),
            ),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits [searching, searching(videos), success] '
        'when stream yields results',
        setUp: () {
          final video = createVideo(id: 'v1', title: 'Flutter Tutorial');

          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) => Stream.value([video]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter'),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', hasLength(1)),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits progressive searching states then success '
        'when stream yields multiple times',
        setUp: () {
          final localVideo = createVideo(id: 'local-1', title: 'Local');
          final combinedVideos = [
            localVideo,
            createVideo(id: 'relay-1', title: 'Relay'),
          ];

          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              [localVideo],
              combinedVideos,
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter'),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(2)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', hasLength(2)),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'stays searching when local cache is empty '
        'until API yields results and stream completes',
        setUp: () {
          final apiVideo = createVideo(id: 'api-1', title: 'API Result');

          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              <VideoEvent>[], // local cache empty
              [apiVideo], // API returns results
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter')
              .having((s) => s.videos, 'videos', isEmpty),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.resultCount, 'resultCount', 0),
          // local cache yields [] with an explicit zero count
          // API yields results — still searching
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          // stream done — now success
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', hasLength(1)),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits [searching, searching(empty), success(empty)] '
        'when stream yields empty list',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.resultCount, 'resultCount', 0)
              .having((s) => s.videos, 'videos', isEmpty),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.resultCount, 'resultCount', 0),
        ],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits [searching, failure] when stream throws',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) => Stream.error(Exception('search failed')));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          final video = createVideo(id: 'v1', title: 'Final Result');

          when(
            () => mockVideosRepository.searchVideos(
              query: 'final',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) => Stream.value([video]));
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const VideoSearchQueryChanged('f'))
            ..add(const VideoSearchQueryChanged('fi'))
            ..add(const VideoSearchQueryChanged('fin'))
            ..add(const VideoSearchQueryChanged('fina'))
            ..add(const VideoSearchQueryChanged('final'));
        },
        wait: debounceDuration,
        verify: (bloc) {
          expect(bloc.state.query, 'final');
          verify(
            () => mockVideosRepository.searchVideos(
              query: 'final',
              sort: any(named: 'sort'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'does not re-search when query has not changed',
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter Tutorial')],
        ),
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => <VideoSearchState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
              sort: any(named: 'sort'),
            ),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        're-searches when same query is dispatched in failure state',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        seed: () => const VideoSearchState(
          status: VideoSearchStatus.failure,
          query: 'flutter',
        ),
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'passes query to repository trimmed',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchQueryChanged('  flutter  ')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).called(1);
        },
      );
    });

    group('VideoSearchBlocklistChanged', () {
      blocTest<VideoSearchBloc, VideoSearchState>(
        're-runs the current search, bypassing the same-query guard',
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter Tutorial')],
        ),
        act: (bloc) => bloc.add(const VideoSearchBlocklistChanged()),
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.searching,
          ),
          isA<VideoSearchState>().having(
            (s) => s.status,
            'status',
            VideoSearchStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'does nothing when no search is active',
        build: createBloc,
        act: (bloc) => bloc.add(const VideoSearchBlocklistChanged()),
        expect: () => <VideoSearchState>[],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
              sort: any(named: 'sort'),
            ),
          );
        },
      );
    });

    group('VideoSearchCleared', () {
      blocTest<VideoSearchBloc, VideoSearchState>(
        'resets to initial state',
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter')],
        ),
        act: (bloc) => bloc.add(const VideoSearchCleared()),
        expect: () => [const VideoSearchState()],
      );
    });

    group(VideoSearchState, () {
      test('copyWith creates copy with updated values', () {
        const state = VideoSearchState();

        final updated = state.copyWith(
          status: VideoSearchStatus.success,
          query: 'test',
          videos: [],
        );

        expect(updated.status, VideoSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.videos, isEmpty);
      });

      test('copyWith preserves existing values when not specified', () {
        final state = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Flutter')],
        );

        final updated = state.copyWith(status: VideoSearchStatus.searching);

        expect(updated.status, VideoSearchStatus.searching);
        expect(updated.query, 'flutter');
        expect(updated.videos, hasLength(1));
        expect(updated.resultCount, isNull);
      });

      test('props includes all fields', () {
        final videos = [createVideo(id: 'v1', title: 'Test')];
        final state = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'test',
          videos: videos,
        );

        expect(state.props, [
          VideoSearchStatus.success,
          'test',
          videos,
          -1,
          0,
          -1,
          false,
          false,
          VideoSearchSort.trending,
        ]);
      });

      test('two states with same values are equal', () {
        const state1 = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
        );
        const state2 = VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
        );

        expect(state1, equals(state2));
      });

      test('two states with different values are not equal', () {
        const state1 = VideoSearchState(query: 'flutter');
        const state2 = VideoSearchState(query: 'dart');

        expect(state1, isNot(equals(state2)));
      });

      test('copyWith updates pagination fields', () {
        const state = VideoSearchState();

        final updated = state.copyWith(
          apiOffset: 50,
          totalApiCount: 120,
          hasMore: true,
          isLoadingMore: true,
        );

        expect(updated.apiOffset, 50);
        expect(updated.totalApiCount, 120);
        expect(updated.hasMore, isTrue);
        expect(updated.isLoadingMore, isTrue);
      });

      test('copyWith can clear totalApiCount to null', () {
        const state = VideoSearchState(totalApiCount: 100);

        final updated = state.copyWith(totalApiCount: null);

        expect(updated.totalApiCount, isNull);
      });

      test('copyWith updates sort', () {
        const state = VideoSearchState();

        final updated = state.copyWith(sort: VideoSearchSort.recent);

        expect(updated.sort, VideoSearchSort.recent);
      });
    });

    group('VideoSearchSortChanged', () {
      blocTest<VideoSearchBloc, VideoSearchState>(
        'updates sort without searching when query is empty',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const VideoSearchSortChanged(VideoSearchSort.recent)),
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.sort, 'sort', VideoSearchSort.recent)
              .having((s) => s.videos, 'videos', isEmpty),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.searchVideos(
              query: any(named: 'query'),
              sort: any(named: 'sort'),
            ),
          );
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'reloads current query with selected sort',
        setUp: () {
          final video = createVideo(id: 'recent-1', title: 'Recent Result');
          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: VideoSearchSort.recent,
            ),
          ).thenAnswer((_) => Stream.value([video]));
        },
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'old', title: 'Old Result')],
          hasMore: true,
        ),
        act: (bloc) =>
            bloc.add(const VideoSearchSortChanged(VideoSearchSort.recent)),
        wait: debounceDuration,
        expect: () => [
          isA<VideoSearchState>()
              .having((s) => s.sort, 'sort', VideoSearchSort.recent)
              .having((s) => s.videos, 'videos', isEmpty),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.query, 'query', 'flutter')
              .having((s) => s.sort, 'sort', VideoSearchSort.recent),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.searching)
              .having((s) => s.videos, 'videos', hasLength(1)),
          isA<VideoSearchState>()
              .having((s) => s.status, 'status', VideoSearchStatus.success)
              .having((s) => s.sort, 'sort', VideoSearchSort.recent),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: VideoSearchSort.recent,
            ),
          ).called(1);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'ignores stale stream results after sort changes',
        build: createBloc,
        setUp: () {
          trendingSubscribed = Completer<void>();
          trendingController = StreamController<List<VideoEvent>>(
            onListen: trendingSubscribed.complete,
          );
          // Not awaited: close() on a controller nobody listened to never
          // completes, which would hang teardown if the bloc never subscribes.
          addTearDown(() => unawaited(trendingController.close()));

          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) => trendingController.stream);
          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: VideoSearchSort.recent,
            ),
          ).thenAnswer(
            (_) => Stream.value([createVideo(id: 'recent-1', title: 'Recent')]),
          );
        },
        act: (bloc) async {
          bloc.add(const VideoSearchQueryChanged('flutter'));
          await trendingSubscribed.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('trending search was never subscribed'),
          );
          final recent = bloc.stream.firstWhere(
            (s) =>
                s.sort == VideoSearchSort.recent &&
                s.status == VideoSearchStatus.success,
          );
          bloc.add(const VideoSearchSortChanged(VideoSearchSort.recent));
          await recent.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('sort change never reached success'),
          );
          trendingController.add([
            createVideo(id: 'trending-1', title: 'Trending'),
          ]);
          await trendingController.close();
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.sort, VideoSearchSort.recent);
          expect(bloc.state.videos.map((video) => video.id), ['recent-1']);
        },
      );
    });

    group('VideoSearchLoadMore', () {
      blocTest<VideoSearchBloc, VideoSearchState>(
        'fetches next page and appends results',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideosViaApi(
              query: 'flutter',
              offset: 50,
              sort: VideoSearchSort.recent,
            ),
          ).thenAnswer(
            (_) async => (
              videos: [createVideo(id: 'v2', title: 'Page 2')],
              totalCount: 75,
              hasMore: false,
            ),
          );
        },
        build: createBloc,
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'v1', title: 'Page 1')],
          apiOffset: 50,
          hasMore: true,
          sort: VideoSearchSort.recent,
        ),
        act: (bloc) => bloc.add(const VideoSearchLoadMore()),
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<VideoSearchState>()
              .having((s) => s.videos, 'videos', hasLength(2))
              .having((s) => s.sort, 'sort', VideoSearchSort.recent)
              .having((s) => s.apiOffset, 'apiOffset', 100)
              .having((s) => s.totalApiCount, 'totalApiCount', 75)
              .having((s) => s.hasMore, 'hasMore', isFalse)
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.searchVideosViaApi(
              query: 'flutter',
              offset: 50,
              sort: VideoSearchSort.recent,
            ),
          ).called(1);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'drops stale load-more results after sort changes',
        build: createBloc,
        setUp: () {
          loadMoreStarted = Completer<void>();
          loadMoreCompleter =
              Completer<
                ({List<VideoEvent> videos, int totalCount, bool hasMore})
              >();

          when(
            () => mockVideosRepository.searchVideosViaApi(
              query: 'flutter',
              offset: 50,
              sort: any(named: 'sort'),
            ),
          ).thenAnswer((_) {
            loadMoreStarted.complete();
            return loadMoreCompleter.future;
          });
          when(
            () => mockVideosRepository.searchVideos(
              query: 'flutter',
              sort: VideoSearchSort.recent,
            ),
          ).thenAnswer(
            (_) => Stream.value([
              createVideo(id: 'recent-1', title: 'Recent Result'),
            ]),
          );
        },
        seed: () => VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          videos: [createVideo(id: 'old-page-1', title: 'Old Page 1')],
          apiOffset: 50,
          hasMore: true,
        ),
        act: (bloc) async {
          bloc.add(const VideoSearchLoadMore());
          await loadMoreStarted.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('load more never reached the repository'),
          );
          final recent = bloc.stream.firstWhere(
            (s) =>
                s.sort == VideoSearchSort.recent &&
                s.status == VideoSearchStatus.success,
          );
          bloc.add(const VideoSearchSortChanged(VideoSearchSort.recent));
          await recent.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('sort change never reached success'),
          );
          loadMoreCompleter.complete((
            videos: [createVideo(id: 'old-page-2', title: 'Old Page 2')],
            totalCount: 100,
            hasMore: true,
          ));
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.sort, VideoSearchSort.recent);
          expect(bloc.state.videos.map((video) => video.id), ['recent-1']);
          expect(bloc.state.apiOffset, 50);
          expect(bloc.state.hasMore, isTrue);
        },
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'does nothing when hasMore is false',
        build: createBloc,
        seed: () => const VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
        ),
        act: (bloc) => bloc.add(const VideoSearchLoadMore()),
        expect: () => <VideoSearchState>[],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => const VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          hasMore: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const VideoSearchLoadMore()),
        expect: () => <VideoSearchState>[],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'does nothing when query is empty',
        build: createBloc,
        seed: () => const VideoSearchState(
          status: VideoSearchStatus.success,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoSearchLoadMore()),
        expect: () => <VideoSearchState>[],
      );

      blocTest<VideoSearchBloc, VideoSearchState>(
        'emits isLoadingMore false on error and reports via addError',
        setUp: () {
          when(
            () => mockVideosRepository.searchVideosViaApi(
              query: 'flutter',
              offset: 50,
              sort: any(named: 'sort'),
            ),
          ).thenThrow(Exception('network error'));
        },
        build: createBloc,
        seed: () => const VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'flutter',
          apiOffset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const VideoSearchLoadMore()),
        expect: () => [
          isA<VideoSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<VideoSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isFalse,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });
  });
}
