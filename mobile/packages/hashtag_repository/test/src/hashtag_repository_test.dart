// ABOUTME: Tests for HashtagRepository.
// ABOUTME: Tests remote search with local fallback and exception handling.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group(HashtagRepository, () {
    late _MockFunnelcakeApiClient mockClient;
    late HashtagRepository repository;

    setUp(() {
      mockClient = _MockFunnelcakeApiClient();
      repository = HashtagRepository(funnelcakeApiClient: mockClient);
    });

    group('searchHashtags', () {
      test('drops remote results over the hashtag length limit', () async {
        final pastedList = 'vine' * 20;
        when(
          () => mockClient.searchHashtags(query: 'vine'),
        ).thenAnswer((_) async => [pastedList, 'vine', 'vinefyp']);

        final results = await repository.searchHashtags(query: 'vine');

        expect(results, equals(['vine', 'vinefyp']));
      });

      test('returns filtered remote results when they contain query', () async {
        when(
          () => mockClient.searchHashtags(query: 'bitcoin'),
        ).thenAnswer((_) async => ['bitcoin', 'bitcoinmining', 'unrelated']);

        final results = await repository.searchHashtags(query: 'bitcoin');

        expect(results, equals(['bitcoin', 'bitcoinmining']));
        verify(() => mockClient.searchHashtags(query: 'bitcoin')).called(1);
      });

      test('passes custom limit to client', () async {
        when(
          () => mockClient.searchHashtags(query: 'nostr', limit: 50),
        ).thenAnswer((_) async => ['nostr']);

        final results = await repository.searchHashtags(
          query: 'nostr',
          limit: 50,
        );

        expect(results, equals(['nostr']));
        verify(
          () => mockClient.searchHashtags(query: 'nostr', limit: 50),
        ).called(1);
      });

      test('skips filtering when query is null', () async {
        when(
          () => mockClient.searchHashtags(),
        ).thenAnswer((_) async => ['trending1', 'trending2']);

        final results = await repository.searchHashtags();

        expect(results, equals(['trending1', 'trending2']));
        verify(() => mockClient.searchHashtags()).called(1);
      });

      test('skips filtering when query is empty', () async {
        when(
          () => mockClient.searchHashtags(query: ''),
        ).thenAnswer((_) async => ['trending1', 'trending2']);

        final results = await repository.searchHashtags(query: '');

        expect(results, equals(['trending1', 'trending2']));
      });

      test('falls back to local when remote returns empty list', () async {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['localresult'],
        );
        when(
          () => mockClient.searchHashtags(query: 'zzzzz'),
        ).thenAnswer((_) async => []);

        final results = await repoWithLocal.searchHashtags(query: 'zzzzz');

        expect(results, equals(['localresult']));
      });

      test(
        'falls back to local when remote results do not match query',
        () async {
          final repoWithLocal = HashtagRepository(
            funnelcakeApiClient: mockClient,
            localSearch: (query, limit) => ['music', 'musician'],
          );
          when(
            () => mockClient.searchHashtags(query: 'music'),
          ).thenAnswer((_) async => ['unrelated', 'othertag']);

          final results = await repoWithLocal.searchHashtags(query: 'music');

          expect(results, equals(['music', 'musician']));
        },
      );

      test('falls back to local when remote throws '
          'FunnelcakeApiException', () async {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['localfallback'],
        );
        when(
          () => mockClient.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/hashtags',
          ),
        );

        final results = await repoWithLocal.searchHashtags(query: 'test');

        expect(results, equals(['localfallback']));
      });

      test('falls back to local when remote throws '
          'FunnelcakeTimeoutException', () async {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['localfallback'],
        );
        when(
          () => mockClient.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(const FunnelcakeTimeoutException());

        final results = await repoWithLocal.searchHashtags(query: 'test');

        expect(results, equals(['localfallback']));
      });

      test('falls back to local when remote throws '
          'FunnelcakeNotConfiguredException', () async {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['localfallback'],
        );
        when(
          () => mockClient.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        final results = await repoWithLocal.searchHashtags(query: 'test');

        expect(results, equals(['localfallback']));
      });

      test(
        'returns empty list when remote fails and no local callback',
        () async {
          when(
            () => mockClient.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const FunnelcakeException('search failed'));

          final results = await repository.searchHashtags(query: 'test');

          expect(results, isEmpty);
        },
      );

      test('returns empty list when remote returns empty and no local '
          'callback', () async {
        when(
          () => mockClient.searchHashtags(query: 'zzzzz'),
        ).thenAnswer((_) async => []);

        final results = await repository.searchHashtags(query: 'zzzzz');

        expect(results, isEmpty);
      });

      test('passes offset to client', () async {
        when(
          () => mockClient.searchHashtags(
            query: 'nostr',
            offset: 20,
          ),
        ).thenAnswer((_) async => ['nostr2']);

        final results = await repository.searchHashtags(
          query: 'nostr',
          offset: 20,
        );

        expect(results, equals(['nostr2']));
        verify(
          () => mockClient.searchHashtags(
            query: 'nostr',
            offset: 20,
          ),
        ).called(1);
      });
    });

    group('searchHashtagsLocally', () {
      test('drops local results over the hashtag length limit', () {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['local', 'local' * 20],
        );

        final results = repoWithLocal.searchHashtagsLocally(query: 'local');

        expect(results, equals(['local']));
      });

      test('returns results from local callback', () {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['local1', 'local2'],
        );

        final results = repoWithLocal.searchHashtagsLocally(
          query: 'local',
        );

        expect(results, equals(['local1', 'local2']));
      });

      test('returns empty list when no local callback', () {
        final results = repository.searchHashtagsLocally(query: 'test');

        expect(results, isEmpty);
      });

      test('returns empty list for empty query', () {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['result'],
        );

        final results = repoWithLocal.searchHashtagsLocally(query: '');

        expect(results, isEmpty);
      });

      test('returns empty list for whitespace-only query', () {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['result'],
        );

        final results = repoWithLocal.searchHashtagsLocally(
          query: '   ',
        );

        expect(results, isEmpty);
      });

      test('passes trimmed query and limit to callback', () {
        String? capturedQuery;
        int? capturedLimit;
        HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) {
            capturedQuery = query;
            capturedLimit = limit;
            return [];
          },
        ).searchHashtagsLocally(query: '  music  ', limit: 50);

        expect(capturedQuery, equals('music'));
        expect(capturedLimit, equals(50));
      });
    });

    group('countHashtagsLocally', () {
      test('returns count of local results', () {
        final repoWithLocal = HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) => ['a', 'b', 'c'],
        );

        final count = repoWithLocal.countHashtagsLocally(query: 'test');

        expect(count, equals(3));
      });

      test('returns zero when no local callback', () {
        final count = repository.countHashtagsLocally(query: 'test');

        expect(count, equals(0));
      });

      test('passes maxLocalHashtagCount as limit', () {
        int? capturedLimit;
        HashtagRepository(
          funnelcakeApiClient: mockClient,
          localSearch: (query, limit) {
            capturedLimit = limit;
            return [];
          },
        ).countHashtagsLocally(query: 'test');

        expect(capturedLimit, equals(maxLocalHashtagCount));
      });
    });

    group('fetchTrendingHashtags', () {
      test(
        'delegates to FunnelcakeApiClient with correct parameters',
        () async {
          final trendingHashtags = [
            TrendingHashtag(
              tag: 'bitcoin',
              videoCount: 42,
              uniqueCreators: 10,
              totalLoops: 1000,
            ),
            TrendingHashtag(
              tag: 'nostr',
              videoCount: 30,
              uniqueCreators: 8,
              totalLoops: 500,
            ),
          ];

          when(
            () => mockClient.fetchTrendingHashtags(),
          ).thenAnswer((_) async => trendingHashtags);

          final results = await repository.fetchTrendingHashtags();

          expect(results, equals(trendingHashtags));
          verify(() => mockClient.fetchTrendingHashtags()).called(1);
        },
      );

      test('passes custom limit to client', () async {
        when(() => mockClient.fetchTrendingHashtags(limit: 50)).thenAnswer(
          (_) async => [
            TrendingHashtag(
              tag: 'bitcoin',
              videoCount: 42,
              uniqueCreators: 10,
              totalLoops: 1000,
            ),
          ],
        );

        final results = await repository.fetchTrendingHashtags(limit: 50);

        expect(results, hasLength(1));
        verify(() => mockClient.fetchTrendingHashtags(limit: 50)).called(1);
      });

      test('returns empty list when client returns empty', () async {
        when(
          () => mockClient.fetchTrendingHashtags(),
        ).thenAnswer((_) async => []);

        final results = await repository.fetchTrendingHashtags();

        expect(results, isEmpty);
      });

      test('propagates FunnelcakeNotConfiguredException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        expect(
          () => repository.fetchTrendingHashtags(),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );
      });

      test('propagates FunnelcakeApiException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/hashtags/trending',
          ),
        );

        expect(
          () => repository.fetchTrendingHashtags(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('propagates FunnelcakeTimeoutException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(const FunnelcakeTimeoutException());

        expect(
          () => repository.fetchTrendingHashtags(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getTrendingHashtags', () {
      late HashtagRepository cachingRepository;

      setUp(() {
        cachingRepository = HashtagRepository(funnelcakeApiClient: mockClient);
      });

      test('fetches from client on cache miss', () async {
        final trendingHashtags = [
          TrendingHashtag(
            tag: 'bitcoin',
            videoCount: 42,
            uniqueCreators: 10,
            totalLoops: 1000,
          ),
        ];
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenAnswer((_) async => trendingHashtags);

        final results = await cachingRepository.getTrendingHashtags();

        expect(results, equals(trendingHashtags));
        verify(() => mockClient.fetchTrendingHashtags()).called(1);
      });

      test(
        'returns cached result on second call without force refresh',
        () async {
          final trendingHashtags = [
            TrendingHashtag(
              tag: 'nostr',
              videoCount: 30,
              uniqueCreators: 8,
              totalLoops: 500,
            ),
          ];
          when(
            () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
          ).thenAnswer((_) async => trendingHashtags);

          await cachingRepository.getTrendingHashtags();
          final secondResult = await cachingRepository.getTrendingHashtags();

          expect(secondResult, equals(trendingHashtags));
          // Client called only once; second call served from cache.
          verify(() => mockClient.fetchTrendingHashtags()).called(1);
        },
      );

      test('bypasses cache when forceRefresh is true', () async {
        final firstBatch = [
          TrendingHashtag(
            tag: 'vine',
            videoCount: 10,
            uniqueCreators: 3,
            totalLoops: 100,
          ),
        ];
        final secondBatch = [
          TrendingHashtag(
            tag: 'openvine',
            videoCount: 20,
            uniqueCreators: 5,
            totalLoops: 200,
          ),
        ];
        var callCount = 0;
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? firstBatch : secondBatch;
        });

        await cachingRepository.getTrendingHashtags();
        final refreshed = await cachingRepository.getTrendingHashtags(
          forceRefresh: true,
        );

        expect(refreshed, equals(secondBatch));
        verify(() => mockClient.fetchTrendingHashtags()).called(2);
      });

      test('cache expires after cacheDuration', () async {
        final expiredRepository = HashtagRepository(
          funnelcakeApiClient: mockClient,
          cacheDuration: Duration.zero,
        );
        final hashtags = [
          TrendingHashtag(
            tag: 'bitcoin',
            videoCount: 42,
            uniqueCreators: 10,
            totalLoops: 1000,
          ),
        ];
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenAnswer((_) async => hashtags);

        await expiredRepository.getTrendingHashtags();
        await expiredRepository.getTrendingHashtags();

        // With Duration.zero the cache is always stale, so client is called
        // twice.
        verify(() => mockClient.fetchTrendingHashtags()).called(2);
      });

      test('passes custom limit to client', () async {
        when(
          () => mockClient.fetchTrendingHashtags(limit: 50),
        ).thenAnswer((_) async => []);

        await cachingRepository.getTrendingHashtags(limit: 50);

        verify(() => mockClient.fetchTrendingHashtags(limit: 50)).called(1);
      });

      test('returns default hashtags when API is not configured', () async {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        final results = await cachingRepository.getTrendingHashtags();

        expect(results, isNotEmpty);
        expect(results.first, isA<TrendingHashtag>());
        // Does not throw — callers always get a usable list.
      });

      test('default hashtags respect the limit parameter', () async {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        final results = await cachingRepository.getTrendingHashtags(limit: 5);

        expect(results, hasLength(5));
      });

      test('propagates FunnelcakeApiException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 503,
            url: 'https://example.com/api/hashtags',
          ),
        );

        expect(
          () => cachingRepository.getTrendingHashtags(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(503),
            ),
          ),
        );
      });

      test('propagates FunnelcakeTimeoutException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(const FunnelcakeTimeoutException());

        expect(
          () => cachingRepository.getTrendingHashtags(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });
  });
}
