// ABOUTME: Tests for HashtagSearchBloc - hashtag search via HashtagRepository.
// ABOUTME: Tests loading states, error handling, debouncing, and API delegation.

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

void main() {
  group(HashtagSearchBloc, () {
    late _MockHashtagRepository mockHashtagRepository;

    setUp(() {
      mockHashtagRepository = _MockHashtagRepository();

      // Default stub
      when(
        () => mockHashtagRepository.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockHashtagRepository.countHashtagsLocally(
          query: any(named: 'query'),
        ),
      ).thenReturn(0);
    });

    HashtagSearchBloc createBloc() =>
        HashtagSearchBloc(hashtagRepository: mockHashtagRepository);

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, HashtagSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      expect(bloc.state.resultCount, isNull);
      bloc.close();
    });

    group('HashtagSearchQueryChanged', () {
      // Debounce duration used in the BLoC + buffer
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, success] when search succeeds',
        setUp: () {
          when(
            () =>
                mockHashtagRepository.searchHashtags(query: 'music', limit: 50),
          ).thenAnswer((_) async => ['music', 'musician', 'musicvideo']);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('music')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'music',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', 'musician', 'musicvideo'],
            resultCount: 3,
            offset: 3,
          ),
        ],
        verify: (_) {
          verify(
            () =>
                mockHashtagRepository.searchHashtags(query: 'music', limit: 50),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, success] with empty results when no matches',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('zzzzz')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'zzzzz',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'zzzzz',
            resultCount: 0,
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () =>
                mockHashtagRepository.searchHashtags(query: 'error', limit: 50),
          ).thenThrow(const FunnelcakeException('search failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('error')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'error',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.failure,
            query: 'error',
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, failure] when repository throws timeout',
        setUp: () {
          when(
            () =>
                mockHashtagRepository.searchHashtags(query: 'slow', limit: 50),
          ).thenThrow(const FunnelcakeTimeoutException());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('slow')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'slow',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.failure,
            query: 'slow',
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits initial state when query is a single character',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('a')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does not re-search when query has not changed',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'flutter',
          results: ['flutter', 'flutterdev'],
        ),
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('flutter')),
        wait: const Duration(milliseconds: 400),
        expect: () => <HashtagSearchState>[],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        're-searches when same query is dispatched in failure state',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(
              query: 'flutter',
              limit: 50,
            ),
          ).thenAnswer((_) async => ['flutter', 'flutterdev']);
        },
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.failure,
          query: 'flutter',
        ),
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'flutter',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'flutter',
            results: ['flutter', 'flutterdev'],
            resultCount: 2,
            offset: 2,
          ),
        ],
        verify: (_) {
          verify(
            () => mockHashtagRepository.searchHashtags(
              query: 'flutter',
              limit: 50,
            ),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'normalizes query by trimming and lowercasing',
        setUp: () {
          when(
            () =>
                mockHashtagRepository.searchHashtags(query: 'cats', limit: 50),
          ).thenAnswer((_) async => ['cats']);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('  CATS  ')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'cats',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'cats',
            results: ['cats'],
            resultCount: 1,
            offset: 1,
          ),
        ],
        verify: (_) {
          verify(
            () =>
                mockHashtagRepository.searchHashtags(query: 'cats', limit: 50),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          when(
            () =>
                mockHashtagRepository.searchHashtags(query: 'final', limit: 50),
          ).thenAnswer((_) async => ['finalize']);
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const HashtagSearchQueryChanged('f'))
            ..add(const HashtagSearchQueryChanged('fi'))
            ..add(const HashtagSearchQueryChanged('fin'))
            ..add(const HashtagSearchQueryChanged('fina'))
            ..add(const HashtagSearchQueryChanged('final'));
        },
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'final',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'final',
            results: ['finalize'],
            resultCount: 1,
            offset: 1,
          ),
        ],
        verify: (_) {
          // Only the final query should be processed due to debounce
          verify(
            () =>
                mockHashtagRepository.searchHashtags(query: 'final', limit: 50),
          ).called(1);
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'f',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'fi',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'fin',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'fina',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
        },
      );
    });

    group('HashtagSearchBlocklistChanged', () {
      blocTest<HashtagSearchBloc, HashtagSearchState>(
        're-runs the current search, bypassing the same-query guard',
        setUp: () {
          when(
            () =>
                mockHashtagRepository.searchHashtags(query: 'music', limit: 50),
          ).thenAnswer((_) async => ['music']);
        },
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musicvideo'],
        ),
        act: (bloc) => bloc.add(const HashtagSearchBlocklistChanged()),
        expect: () => [
          isA<HashtagSearchState>().having(
            (s) => s.status,
            'status',
            HashtagSearchStatus.loading,
          ),
          isA<HashtagSearchState>().having(
            (s) => s.status,
            'status',
            HashtagSearchStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () =>
                mockHashtagRepository.searchHashtags(query: 'music', limit: 50),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does nothing when no search is active',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchBlocklistChanged()),
        expect: () => <HashtagSearchState>[],
      );
    });

    group('HashtagSearchLoadMore', () {
      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'appends results and updates offset',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(
              query: 'music',
              limit: 50,
              offset: 20,
            ),
          ).thenAnswer((_) async => ['extra1', 'extra2']);
        },
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musician'],
          offset: 20,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const HashtagSearchLoadMore()),
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', 'musician'],
            offset: 20,
            hasMore: true,
            isLoadingMore: true,
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', 'musician', 'extra1', 'extra2'],
            offset: 4,
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'sets hasMore to true when load more returns full page',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(
              query: 'music',
              limit: 50,
              offset: 20,
            ),
          ).thenAnswer((_) async => List.generate(50, (i) => 'tag$i'));
        },
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music'],
          offset: 20,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const HashtagSearchLoadMore()),
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music'],
            offset: 20,
            hasMore: true,
            isLoadingMore: true,
          ),
          HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', ...List.generate(50, (i) => 'tag$i')],
            offset: 51,
            hasMore: true,
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does nothing when hasMore is false',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music'],
          offset: 1,
        ),
        act: (bloc) => bloc.add(const HashtagSearchLoadMore()),
        expect: () => <HashtagSearchState>[],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music'],
          offset: 20,
          hasMore: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const HashtagSearchLoadMore()),
        expect: () => <HashtagSearchState>[],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does nothing when query is empty',
        build: createBloc,
        seed: () => const HashtagSearchState(hasMore: true),
        act: (bloc) => bloc.add(const HashtagSearchLoadMore()),
        expect: () => <HashtagSearchState>[],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'resets isLoadingMore on failure',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(
              query: 'music',
              limit: 50,
              offset: 20,
            ),
          ).thenThrow(Exception('network error'));
        },
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music'],
          offset: 20,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const HashtagSearchLoadMore()),
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music'],
            offset: 20,
            hasMore: true,
            isLoadingMore: true,
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music'],
            offset: 20,
            hasMore: true,
          ),
        ],
      );
    });

    group('HashtagSearchCleared', () {
      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'resets to initial state',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musician'],
        ),
        act: (bloc) => bloc.add(const HashtagSearchCleared()),
        expect: () => [const HashtagSearchState()],
      );
    });

    group('HashtagSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = HashtagSearchState();

        final updated = state.copyWith(
          status: HashtagSearchStatus.success,
          query: 'test',
          results: ['test', 'testing'],
        );

        expect(updated.status, HashtagSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.results, ['test', 'testing']);
      });

      test('copyWith preserves existing values when not specified', () {
        const state = HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music'],
        );

        final updated = state.copyWith(status: HashtagSearchStatus.loading);

        expect(updated.status, HashtagSearchStatus.loading);
        expect(updated.query, 'music');
        expect(updated.results, ['music']);
        expect(updated.resultCount, isNull);
      });

      test('props includes all fields', () {
        const state = HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musician'],
          offset: 2,
          hasMore: true,
        );

        expect(state.props, [
          HashtagSearchStatus.success,
          'music',
          ['music', 'musician'],
          -1,
          2,
          true,
          false,
        ]);
      });
    });

    group('feed performance tracking', () {
      late _MockHashtagRepository mockRepo;
      late _MockFeedPerformanceTracker mockTracker;
      late FeedLoadHandle feedLoad;

      // Debounce duration used in the BLoC + buffer
      const debounceDuration = Duration(milliseconds: 400);

      setUp(() {
        mockRepo = _MockHashtagRepository();
        mockTracker = _MockFeedPerformanceTracker();
        feedLoad = FeedPerformanceTracker(
          sink: const NoOpAnalyticsEventSink(),
        ).startFeedLoad('test');
        when(() => mockTracker.startFeedLoad(any())).thenReturn(feedLoad);

        when(
          () => mockRepo.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);
      });

      HashtagSearchBloc createBlocWithTracker() => HashtagSearchBloc(
        hashtagRepository: mockRepo,
        feedTracker: mockTracker,
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'calls startFeedLoad, markFirstVideosReceived, and '
        'markFeedDisplayed on success',
        setUp: () {
          when(
            () => mockRepo.searchHashtags(query: 'music', limit: 50),
          ).thenAnswer((_) async => ['music', 'musician', 'musicvideo']);
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('music')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('hashtag_search')).called(1);
          verify(
            () => mockTracker.markFirstVideosReceived(feedLoad, 3),
          ).called(1);
          verify(
            () => mockTracker.markFeedDisplayed(feedLoad, 3),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'calls trackFeedError on failure',
        setUp: () {
          when(
            () => mockRepo.searchHashtags(query: 'error', limit: 50),
          ).thenThrow(const FunnelcakeException('search failed'));
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('error')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('hashtag_search')).called(1);
          verify(
            () => mockTracker.trackFeedError(
              'hashtag_search',
              errorType: 'search_failed',
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
          verifyNever(
            () => mockTracker.markFirstVideosReceived(feedLoad, any()),
          );
          verifyNever(() => mockTracker.markFeedDisplayed(feedLoad, any()));
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does not call tracker for empty query',
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('')),
        wait: debounceDuration,
        verify: (_) {
          verifyNever(() => mockTracker.startFeedLoad(any()));
        },
      );
    });
  });
}
