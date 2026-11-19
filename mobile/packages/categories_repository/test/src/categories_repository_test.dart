// ABOUTME: Tests for CategoriesRepository
// ABOUTME: Verifies caching, filtering, and featured-first ordering

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:categories_repository/categories_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show RecommendationsResponse, VideoCategory, VideoStats;
import 'package:test/test.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  const blockedPubkey = 'blocked_pubkey';
  const allowedPubkey = 'allowed_pubkey';

  group(CategoriesRepository, () {
    late _MockFunnelcakeApiClient apiClient;
    late CategoriesRepository repository;

    setUp(() {
      apiClient = _MockFunnelcakeApiClient();
      repository = CategoriesRepository(
        funnelcakeApiClient: apiClient,
        blockFilter: (pubkey) => pubkey == blockedPubkey,
      );
    });

    const sampleCategories = <VideoCategory>[
      VideoCategory(name: 'comedy', videoCount: 500),
      VideoCategory(name: 'animals', videoCount: 300),
      VideoCategory(name: 'music', videoCount: 200),
    ];

    group('getCategories', () {
      test('fetches categories from API', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        final result = await repository.getCategories();

        expect(result, hasLength(3));
        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('returns cached result on second call', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        await repository.getCategories();

        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('bypasses cache when forceRefresh is true', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        await repository.getCategories(forceRefresh: true);

        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });

      test('filters out empty names', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: '', videoCount: 100),
          ],
        );

        final result = await repository.getCategories();

        expect(result, hasLength(1));
        expect(result.first.name, equals('comedy'));
      });

      test('filters out zero video counts', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: 'empty', videoCount: 0),
          ],
        );

        final result = await repository.getCategories();

        expect(result, hasLength(1));
      });

      test('filters denied discovery categories case-insensitively', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: ' adult ', videoCount: 319),
            VideoCategory(name: 'Violence', videoCount: 212),
            VideoCategory(name: 'Porn', videoCount: 39),
            VideoCategory(name: 'animals', videoCount: 300),
          ],
        );

        final result = await repository.getCategories();

        expect(result.map((category) => category.name), ['animals', 'comedy']);
      });

      test('sorts featured categories first', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: 'animals', videoCount: 300),
            VideoCategory(name: 'unknown_category', videoCount: 100),
          ],
        );

        final result = await repository.getCategories();

        // 'animals' is featured, so should come first
        expect(result.first.name, equals('animals'));
      });
    });

    group('watchCategoriesCached', () {
      const categoriesCacheKey = 'global:categories:v1';
      late FakeCacheDao cacheDao;

      setUp(() async {
        cacheDao = FakeCacheDao();
        await CacheSync.init(dao: cacheDao);
      });

      test('emits disk-cached categories before live refresh', () async {
        const refreshedCategories = <VideoCategory>[
          VideoCategory(name: 'animals', videoCount: 350),
          VideoCategory(name: 'music', videoCount: 250),
        ];
        var calls = 0;
        when(() => apiClient.getCategories(limit: 100)).thenAnswer((_) async {
          calls += 1;
          return calls == 1 ? sampleCategories : refreshedCategories;
        });

        await repository.watchCategoriesCached().toList();

        final restartedRepository = CategoriesRepository(
          funnelcakeApiClient: apiClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final results = await restartedRepository
            .watchCategoriesCached()
            .toList();

        expect(results, hasLength(2));
        expect(results[0].isStale, isTrue);
        expect(results[0].data, [
          const VideoCategory(name: 'animals', videoCount: 300),
          const VideoCategory(name: 'music', videoCount: 200),
          const VideoCategory(name: 'comedy', videoCount: 500),
        ]);
        expect(results[1].isLive, isTrue);
        expect(results[1].data, refreshedCategories);
        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });

      test('filters denied categories from disk-cached payloads', () async {
        await cacheDao.write(
          key: categoriesCacheKey,
          payload: jsonEncode([
            {'name': 'animals', 'video_count': 300},
            {'name': ' adult ', 'video_count': 319},
            {'name': 'Violence', 'video_count': 212},
          ]),
        );
        const refreshedCategories = [
          VideoCategory(name: 'music', videoCount: 250),
        ];
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => refreshedCategories);

        final results = await repository.watchCategoriesCached().toList();

        expect(results, hasLength(2));
        expect(results[0].isStale, isTrue);
        expect(results[0].data, [
          const VideoCategory(name: 'animals', videoCount: 300),
        ]);
        expect(results[1].isLive, isTrue);
        expect(results[1].data, refreshedCategories);
        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('force refresh bypasses the disk cache', () async {
        var calls = 0;
        when(() => apiClient.getCategories(limit: 100)).thenAnswer((_) async {
          calls += 1;
          return calls == 1
              ? sampleCategories
              : const [VideoCategory(name: 'music', videoCount: 250)];
        });

        await repository.watchCategoriesCached().toList();

        final results = await repository
            .watchCategoriesCached(forceRefresh: true)
            .toList();

        expect(results, hasLength(1));
        expect(results.single.isLive, isTrue);
        expect(results.single.data, [
          const VideoCategory(name: 'music', videoCount: 250),
        ]);
        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });
    });

    group('watchVideosForCategoryCached', () {
      const viewer =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const author =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const eventId =
          '3333333333333333333333333333333333333333333333333333333333333333';
      late FakeCacheDao cacheDao;

      setUp(() async {
        cacheDao = FakeCacheDao();
        await CacheSync.init(dao: cacheDao);
        when(
          () => apiClient.getVideosByCategory(
            category: any(named: 'category'),
            sort: any(named: 'sort'),
            platform: any(named: 'platform'),
          ),
        ).thenAnswer((_) async => [_videoStats(id: eventId, pubkey: author)]);
      });

      test(
        'shows persisted first page while the live request is pending',
        () async {
          await repository
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          final pending = Completer<List<VideoStats>>();
          when(
            () => apiClient.getVideosByCategory(category: 'music'),
          ).thenAnswer((_) => pending.future);
          final restarted = CategoriesRepository(
            funnelcakeApiClient: apiClient,
          );
          final iterator = StreamIterator(
            restarted.watchVideosForCategoryCached(
              category: ' Music ',
              viewerPubkey: viewer,
            ),
          );
          expect(await iterator.moveNext(), isTrue);
          expect(iterator.current.isStale, isTrue);
          expect(iterator.current.data.videos.single.id, eventId);
          expect(iterator.current.data.hasMore, isFalse);
          pending.complete([]);
          expect(await iterator.moveNext(), isTrue);
          expect(iterator.current.isLive, isTrue);
          expect(iterator.current.data.videos, isEmpty);
          await iterator.cancel();
        },
      );

      test(
        'reapplies current block filter to stored videos and live results',
        () async {
          var blocked = false;
          final scoped = CategoriesRepository(
            funnelcakeApiClient: apiClient,
            blockFilter: (pubkey) => blocked && pubkey == author,
          );
          await scoped
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          blocked = true;
          final results = await scoped
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          expect(results, hasLength(2));
          expect(
            results,
            everyElement(
              isA<CacheResult<CategoryVideosPage>>().having(
                (result) => result.data.videos,
                'videos',
                isEmpty,
              ),
            ),
          );
        },
      );

      test(
        "sign-out's prefix invalidation clears the viewer's snapshot",
        () async {
          await repository
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          expect(cacheDao.length, 1);
          await CacheSync.invalidatePrefix(viewer);
          final results = await repository
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          expect(results.single.isLive, isTrue);
        },
      );

      test('isolates category, sort, platform and account snapshots', () async {
        await repository
            .watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: viewer,
            )
            .toList();
        for (final selection in [
          (
            category: 'animals',
            sort: 'trending',
            platform: null,
            scope: viewer,
          ),
          (category: 'music', sort: 'timestamp', platform: null, scope: viewer),
          (
            category: 'music',
            sort: 'trending',
            platform: 'vine',
            scope: viewer,
          ),
          (
            category: 'music',
            sort: 'trending',
            platform: null,
            scope: null,
          ),
        ]) {
          final results = await repository
              .watchVideosForCategoryCached(
                category: selection.category,
                sort: selection.sort,
                platform: selection.platform,
                viewerPubkey: selection.scope,
              )
              .toList();
          expect(results.single.isLive, isTrue);
        }
      });

      test(
        'drops snapshots older than 24 hours before serving content',
        () async {
          await repository
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          final key = cacheDao.keys.single;
          final payload =
              jsonDecode(cacheDao.rawRead(key)!) as Map<String, dynamic>;
          payload['cachedAt'] = DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 25))
              .toIso8601String();
          await cacheDao.write(key: key, payload: jsonEncode(payload));
          final results = await repository
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          expect(results.single.isLive, isTrue);
        },
      );

      test('serves snapshots younger than 24 hours', () async {
        await repository
            .watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: viewer,
            )
            .toList();
        final key = cacheDao.keys.single;
        final payload =
            jsonDecode(cacheDao.rawRead(key)!) as Map<String, dynamic>;
        payload['cachedAt'] = DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 23))
            .toIso8601String();
        await cacheDao.write(key: key, payload: jsonEncode(payload));
        final results = await repository
            .watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: viewer,
            )
            .toList();
        expect(results.map((result) => result.isStale), [true, false]);
        expect(results.first.data.videos.single.id, eventId);
      });

      test('drops snapshots dated after the current time', () async {
        await repository
            .watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: viewer,
            )
            .toList();
        final key = cacheDao.keys.single;
        final payload =
            jsonDecode(cacheDao.rawRead(key)!) as Map<String, dynamic>;
        payload['cachedAt'] = DateTime.now()
            .toUtc()
            .add(const Duration(days: 2))
            .toIso8601String();
        await cacheDao.write(key: key, payload: jsonEncode(payload));
        final results = await repository
            .watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: viewer,
            )
            .toList();
        expect(results.single.isLive, isTrue);
      });

      test('drops videos that expired after the snapshot was saved', () async {
        const expiredId =
            '4444444444444444444444444444444444444444444444444444444444444444';
        when(
          () => apiClient.getVideosByCategory(category: 'music'),
        ).thenAnswer(
          (_) async => [
            _videoStats(id: expiredId, pubkey: author),
            _videoStats(id: eventId, pubkey: author),
          ],
        );
        await repository
            .watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: viewer,
            )
            .toList();
        final key = cacheDao.keys.single;
        final payload =
            jsonDecode(cacheDao.rawRead(key)!) as Map<String, dynamic>;
        final expired = (payload['videos'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((video) => video['id'] == expiredId);
        expired['expirationTimestamp'] =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
        await cacheDao.write(key: key, payload: jsonEncode(payload));
        final pending = Completer<List<VideoStats>>();
        when(
          () => apiClient.getVideosByCategory(category: 'music'),
        ).thenAnswer((_) => pending.future);
        final iterator = StreamIterator(
          repository.watchVideosForCategoryCached(
            category: 'music',
            viewerPubkey: viewer,
          ),
        );
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.isStale, isTrue);
        expect(
          iterator.current.data.videos.map((video) => video.id),
          [eventId],
        );
        pending.complete([]);
        expect(await iterator.moveNext(), isTrue);
        await iterator.cancel();
      });

      test(
        'preserves hasMore when current blocks empty a cached full page',
        () async {
          when(
            () => apiClient.getVideosByCategory(category: 'music'),
          ).thenAnswer(
            (_) async => List.generate(
              50,
              (_) => _videoStats(id: eventId, pubkey: author),
            ),
          );
          await repository
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          final blocked = CategoriesRepository(
            funnelcakeApiClient: apiClient,
            blockFilter: (_) => true,
          );
          final results = await blocked
              .watchVideosForCategoryCached(
                category: 'music',
                viewerPubkey: viewer,
              )
              .toList();
          expect(results.first.data.videos, isEmpty);
          expect(results.first.data.hasMore, isTrue);
        },
      );

      test('never caches or fetches denied discovery categories', () async {
        final results = await repository
            .watchVideosForCategoryCached(
              category: ' ADULT ',
              viewerPubkey: viewer,
            )
            .toList();
        expect(results.single.data.videos, isEmpty);
        expect(results.single.data.hasMore, isFalse);
        expect(cacheDao.length, 0);
        verifyNever(
          () => apiClient.getVideosByCategory(
            category: any(named: 'category'),
            sort: any(named: 'sort'),
            platform: any(named: 'platform'),
          ),
        );
      });
    });

    group('getVideosForCategory', () {
      test(
        'filters blocked authors without breaking hasMore metadata',
        () async {
          when(
            () => apiClient.getVideosByCategory(
              category: 'music',
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          ).thenAnswer(
            (_) async => List<VideoStats>.generate(
              50,
              (index) => _videoStats(
                id: 'id-$index',
                pubkey: index == 0 ? blockedPubkey : allowedPubkey,
              ),
            ),
          );

          final page = await repository.getVideosForCategory(category: 'music');

          expect(page.videos, hasLength(49));
          expect(
            page.videos.every((video) => video.pubkey != blockedPubkey),
            isTrue,
          );
          expect(page.hasMore, isTrue);
        },
      );

      for (final denied in [' Violence ', 'porn']) {
        test(
          'returns empty page for denied category "$denied" without fetching',
          () async {
            final page = await repository.getVideosForCategory(
              category: denied,
            );

            expect(page.videos, isEmpty);
            expect(page.hasMore, isFalse);
            verifyNever(
              () => apiClient.getVideosByCategory(
                category: any(named: 'category'),
                before: any(named: 'before'),
                sort: any(named: 'sort'),
                platform: any(named: 'platform'),
              ),
            );
          },
        );
      }
    });

    group('getRecommendedVideos', () {
      test('filters blocked authors from recommendations', () async {
        when(
          () => apiClient.getRecommendations(
            pubkey: 'viewer_pubkey',
            limit: 50,
            category: 'music',
          ),
        ).thenAnswer(
          (_) async => RecommendationsResponse(
            videos: [
              _videoStats(id: 'blocked-id', pubkey: blockedPubkey),
              _videoStats(id: 'allowed-id', pubkey: allowedPubkey),
            ],
            source: 'personalized',
          ),
        );

        final videos = await repository.getRecommendedVideos(
          pubkey: 'viewer_pubkey',
          category: 'music',
        );

        expect(videos, hasLength(1));
        expect(videos.single.id, 'allowed-id');
        expect(videos.single.pubkey, allowedPubkey);
      });

      test(
        'collapses a republished coordinate returned twice in one page',
        () async {
          when(
            () => apiClient.getRecommendations(
              pubkey: 'viewer_pubkey',
              limit: 50,
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [
                _videoStats(
                  id: 'event-a',
                  pubkey: allowedPubkey,
                  dTag: 'shared-d-tag',
                ),
                _videoStats(
                  id: 'event-b',
                  pubkey: allowedPubkey,
                  dTag: 'shared-d-tag',
                ),
              ],
              source: 'personalized',
            ),
          );

          final videos = await repository.getRecommendedVideos(
            pubkey: 'viewer_pubkey',
          );

          expect(videos, hasLength(1));
          expect(videos.single.id, 'event-a');
        },
      );

      test(
        'returns empty recommendations for denied category without fetching',
        () async {
          final videos = await repository.getRecommendedVideos(
            pubkey: 'viewer_pubkey',
            category: 'ADULT',
          );

          expect(videos, isEmpty);
          verifyNever(
            () => apiClient.getRecommendations(
              pubkey: any(named: 'pubkey'),
              category: any(named: 'category'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      test('still fetches recommendations when category is null', () async {
        when(
          () =>
              apiClient.getRecommendations(pubkey: 'viewer_pubkey', limit: 50),
        ).thenAnswer(
          (_) async => RecommendationsResponse(
            videos: [_videoStats(id: 'allowed-id', pubkey: allowedPubkey)],
            source: 'personalized',
          ),
        );

        final videos = await repository.getRecommendedVideos(
          pubkey: 'viewer_pubkey',
        );

        expect(videos, hasLength(1));
        expect(videos.single.id, 'allowed-id');
        verify(
          () =>
              apiClient.getRecommendations(pubkey: 'viewer_pubkey', limit: 50),
        ).called(1);
      });
    });

    group('invalidateCache', () {
      test('clears cache so next call fetches fresh data', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        repository.invalidateCache();
        await repository.getCategories();

        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });
    });
  });
}

VideoStats _videoStats({
  required String id,
  required String pubkey,
  String? dTag,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    videoUrl: 'https://example.com/$id.mp4',
    thumbnail: 'https://example.com/$id.jpg',
    title: 'Video $id',
    createdAt: DateTime(2026),
    kind: 34236,
    dTag: dTag ?? id,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}
