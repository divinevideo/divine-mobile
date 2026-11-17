// ABOUTME: Tests for the CategoriesBloc
// ABOUTME: Verifies category loading, selection, pagination, sorting, and deselection

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:categories_repository/categories_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';

class _MockCategoriesRepository extends Mock implements CategoriesRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _viewerPubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

void main() {
  late _MockCategoriesRepository mockRepository;
  late _MockContentBlocklistRepository mockBlocklistRepository;

  setUp(() {
    mockRepository = _MockCategoriesRepository();
    mockBlocklistRepository = _MockContentBlocklistRepository();
    when(
      () => mockRepository.watchVideosForCategoryCached(
        category: any(named: 'category'),
        sort: any(named: 'sort'),
        platform: any(named: 'platform'),
        viewerPubkey: any(named: 'viewerPubkey'),
      ),
    ).thenAnswer((invocation) async* {
      yield CacheResult.live(
        await mockRepository.getVideosForCategory(
          category: invocation.namedArguments[#category] as String,
          sort: invocation.namedArguments[#sort] as String,
          platform: invocation.namedArguments[#platform] as String?,
        ),
      );
    });
  });

  group(CategoriesBloc, () {
    group('CategoriesLoadRequested', () {
      final categories = [
        const VideoCategory(name: 'music', videoCount: 1500),
        const VideoCategory(name: 'comedy', videoCount: 900),
        const VideoCategory(name: 'dance', videoCount: 800),
      ];

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, loaded] when categories load successfully',
        setUp: () {
          when(
            () => mockRepository.watchCategoriesCached(),
          ).thenAnswer((_) => Stream.value(CacheResult.live(categories)));
        },
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'music', videoCount: 1500),
              VideoCategory(name: 'comedy', videoCount: 900),
              VideoCategory(name: 'dance', videoCount: 800),
            ],
          ),
        ],
        verify: (_) {
          verify(() => mockRepository.watchCategoriesCached()).called(1);
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, error] when repository throws',
        setUp: () {
          when(() => mockRepository.watchCategoriesCached()).thenAnswer(
            (_) => Stream.error(const FunnelcakeException('Network error')),
          );
        },
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          isA<CategoriesState>()
              .having(
                (s) => s.categoriesStatus,
                'categoriesStatus',
                CategoriesStatus.error,
              )
              .having(
                (s) => s.categoriesStatus,
                'failure status',
                CategoriesStatus.error,
              ),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'shows cached categories as refreshing until live categories arrive',
        setUp: () {
          when(() => mockRepository.watchCategoriesCached()).thenAnswer(
            (_) => Stream.fromIterable([
              const CacheResult.cached([
                VideoCategory(name: 'animals', videoCount: 300),
              ]),
              const CacheResult.live([
                VideoCategory(name: 'animals', videoCount: 350),
              ]),
            ]),
          );
        },
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'animals', videoCount: 300)],
            isRefreshing: true,
          ),
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'animals', videoCount: 350)],
          ),
        ],
      );

      test('does not re-fetch while a load is already in progress', () async {
        // Use a Completer to keep the first request suspended so the second
        // event arrives while the bloc is still in loading state.
        final controller = StreamController<CacheResult<List<VideoCategory>>>();
        when(
          () => mockRepository.watchCategoriesCached(),
        ).thenAnswer((_) => controller.stream);

        final bloc = CategoriesBloc(categoriesRepository: mockRepository);

        // First request — bloc enters loading state.
        bloc.add(const CategoriesLoadRequested());
        await pumpEventQueue();

        // Second request while first is still suspended.
        bloc.add(const CategoriesLoadRequested());
        await pumpEventQueue();

        // Only one network call should have been made.
        verify(() => mockRepository.watchCategoriesCached()).called(1);

        // Clean up.
        await controller.close();
        await bloc.close();
      });
    });

    group('cached video selection', () {
      const music = VideoCategory(name: 'music', videoCount: 100);
      const animals = VideoCategory(name: 'animals', videoCount: 100);
      final oldVideo = _createDefaultVideoStats(
        '4444444444444444444444444444444444444444444444444444444444444444',
      ).toVideoEvent();
      final newVideo = _createDefaultVideoStats(
        '5555555555555555555555555555555555555555555555555555555555555555',
      ).toVideoEvent();
      late StreamController<CacheResult<CategoryVideosPage>> results;
      late CategoriesBloc bloc;

      setUp(() {
        results = StreamController<CacheResult<CategoryVideosPage>>();
        when(
          () => mockRepository.watchVideosForCategoryCached(
            category: any(named: 'category'),
            sort: any(named: 'sort'),
            platform: any(named: 'platform'),
            viewerPubkey: any(named: 'viewerPubkey'),
          ),
        ).thenAnswer((_) => results.stream);
        bloc = CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        );
      });
      tearDown(() async {
        await results.close();
        await bloc.close();
      });

      test(
        'keeps cached videos visible during refresh and after a failed refresh',
        () async {
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          results.add(
            CacheResult.cached(
              CategoryVideosPage(videos: [oldVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          expect(bloc.state.videos, [oldVideo]);
          expect(bloc.state.videosStatus, CategoriesVideosStatus.loaded);
          expect(bloc.state.isRefreshingVideos, isTrue);
          results.addError(const FunnelcakeException('Offline'));
          await pumpEventQueue();
          expect(bloc.state.videos, [oldVideo]);
          expect(bloc.state.videosStatus, CategoriesVideosStatus.loaded);
          expect(bloc.state.isRefreshingVideos, isFalse);
        },
      );

      test(
        'does not paginate cached content until fresh metadata arrives',
        () async {
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          results.add(
            CacheResult.cached(
              CategoryVideosPage(videos: [oldVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          bloc.add(const CategoryVideosLoadMore());
          await pumpEventQueue();
          verifyNever(
            () => mockRepository.getVideosForCategory(
              category: any(named: 'category'),
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          );
          results.add(
            CacheResult.live(
              CategoryVideosPage(videos: [newVideo], hasMore: false),
            ),
          );
          await pumpEventQueue();
          expect(bloc.state.videos, [newVideo]);
          expect(bloc.state.hasMoreVideos, isFalse);
          expect(bloc.state.isRefreshingVideos, isFalse);
        },
      );

      test(
        'late selection refresh cannot overwrite another category',
        () async {
          final next = StreamController<CacheResult<CategoryVideosPage>>();
          when(
            () => mockRepository.watchVideosForCategoryCached(
              category: 'animals',
              viewerPubkey: _viewerPubkey,
            ),
          ).thenAnswer((_) => next.stream);
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          bloc.add(const CategorySelected(animals));
          await pumpEventQueue();
          next.add(
            CacheResult.live(
              CategoryVideosPage(videos: [newVideo], hasMore: false),
            ),
          );
          await pumpEventQueue();
          results.add(
            CacheResult.live(
              CategoryVideosPage(videos: [oldVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          expect(bloc.state.selectedCategory, animals);
          expect(bloc.state.videos, [newVideo]);
          await next.close();
        },
      );

      test('sort response wins over an older pending refresh', () async {
        final next = StreamController<CacheResult<CategoryVideosPage>>();
        when(
          () => mockRepository.watchVideosForCategoryCached(
            category: 'music',
            sort: 'timestamp',
            viewerPubkey: _viewerPubkey,
          ),
        ).thenAnswer((_) => next.stream);
        bloc.add(const CategorySelected(music));
        await pumpEventQueue();
        bloc.add(const CategoryVideosSortChanged('timestamp'));
        await pumpEventQueue();
        results.addError(const FunnelcakeException('Old request failed'));
        await pumpEventQueue();
        expect(bloc.state.videosStatus, CategoriesVideosStatus.loading);
        next.add(
          CacheResult.live(
            CategoryVideosPage(videos: [newVideo], hasMore: false),
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.sortOrder, 'timestamp');
        expect(bloc.state.videos, [newVideo]);
        expect(bloc.state.videosStatus, CategoriesVideosStatus.loaded);
        await next.close();
      });

      test('a sort change during load-more leaves paging usable', () async {
        final pending = Completer<CategoryVideosPage>();
        final next = StreamController<CacheResult<CategoryVideosPage>>();
        when(
          () => mockRepository.getVideosForCategory(
            category: 'music',
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) => pending.future);
        when(
          () => mockRepository.watchVideosForCategoryCached(
            category: 'music',
            sort: 'timestamp',
            viewerPubkey: _viewerPubkey,
          ),
        ).thenAnswer((_) => next.stream);
        bloc.add(const CategorySelected(music));
        await pumpEventQueue();
        results.add(
          CacheResult.live(
            CategoryVideosPage(videos: [oldVideo], hasMore: true),
          ),
        );
        await pumpEventQueue();
        bloc.add(const CategoryVideosLoadMore());
        await pumpEventQueue();
        expect(bloc.state.isLoadingMore, isTrue);
        bloc.add(const CategoryVideosSortChanged('timestamp'));
        await pumpEventQueue();
        next.add(
          CacheResult.live(
            CategoryVideosPage(videos: [newVideo], hasMore: true),
          ),
        );
        await pumpEventQueue();
        pending.complete(CategoryVideosPage(videos: [oldVideo], hasMore: true));
        await pumpEventQueue();
        expect(bloc.state.videos, [newVideo]);
        expect(bloc.state.isLoadingMore, isFalse);
        await next.close();
      });

      test(
        'manual refresh keeps all loaded pages through cache and failure',
        () async {
          final next = StreamController<CacheResult<CategoryVideosPage>>();
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          results.add(
            CacheResult.live(
              CategoryVideosPage(videos: [oldVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          when(
            () => mockRepository.getVideosForCategory(
              category: 'music',
              before: oldVideo.createdAt,
            ),
          ).thenAnswer(
            (_) async => CategoryVideosPage(
              videos: [newVideo],
              hasMore: false,
            ),
          );
          bloc.add(const CategoryVideosLoadMore());
          await pumpEventQueue();
          expect(bloc.state.videos, [oldVideo, newVideo]);
          expect(bloc.state.hasMoreVideos, isFalse);
          when(
            () => mockRepository.watchVideosForCategoryCached(
              category: 'music',
              viewerPubkey: _viewerPubkey,
            ),
          ).thenAnswer((_) => next.stream);
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          expect(bloc.state.videosStatus, CategoriesVideosStatus.loaded);
          expect(bloc.state.videos, [oldVideo, newVideo]);
          expect(bloc.state.isRefreshingVideos, isTrue);
          next.add(
            CacheResult.cached(
              CategoryVideosPage(videos: [oldVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          expect(bloc.state.videos, [oldVideo, newVideo]);
          expect(bloc.state.hasMoreVideos, isFalse);
          next.addError(const FunnelcakeException('Offline'));
          await pumpEventQueue();
          expect(bloc.state.videos, [oldVideo, newVideo]);
          expect(bloc.state.hasMoreVideos, isFalse);
          expect(bloc.state.isRefreshingVideos, isFalse);
          await next.close();
        },
      );

      test('late pagination cannot append to a different selection', () async {
        final pending = Completer<CategoryVideosPage>();
        final next = StreamController<CacheResult<CategoryVideosPage>>();
        when(
          () => mockRepository.getVideosForCategory(
            category: 'music',
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) => pending.future);
        when(
          () => mockRepository.watchVideosForCategoryCached(
            category: 'animals',
            viewerPubkey: _viewerPubkey,
          ),
        ).thenAnswer((_) => next.stream);
        bloc.add(const CategorySelected(music));
        await pumpEventQueue();
        results.add(
          CacheResult.live(
            CategoryVideosPage(videos: [oldVideo], hasMore: true),
          ),
        );
        await pumpEventQueue();
        bloc.add(const CategoryVideosLoadMore());
        await pumpEventQueue();
        expect(bloc.state.isLoadingMore, isTrue);
        bloc.add(const CategorySelected(animals));
        await pumpEventQueue();
        next.add(
          CacheResult.live(
            CategoryVideosPage(videos: [newVideo], hasMore: false),
          ),
        );
        await pumpEventQueue();
        pending.complete(CategoryVideosPage(videos: [oldVideo], hasMore: true));
        await pumpEventQueue();
        expect(bloc.state.videos, [newVideo]);
        expect(bloc.state.hasMoreVideos, isFalse);
        expect(bloc.state.isLoadingMore, isFalse);
        await next.close();
      });

      blocTest<CategoriesBloc, CategoriesState>(
        'reports a refresh failure that arrives after cached videos',
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) async {
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          results
            ..add(
              CacheResult.cached(
                CategoryVideosPage(videos: [oldVideo], hasMore: true),
              ),
            )
            ..addError(const FunnelcakeException('Offline'));
          await pumpEventQueue();
        },
        verify: (bloc) {
          expect(bloc.state.videosStatus, CategoriesVideosStatus.loaded);
          expect(bloc.state.videos, [oldVideo]);
        },
        errors: () => [isA<FunnelcakeException>()],
      );

      test('a late failure cannot fail a newer category', () async {
        final next = StreamController<CacheResult<CategoryVideosPage>>();
        when(
          () => mockRepository.watchVideosForCategoryCached(
            category: 'animals',
            viewerPubkey: _viewerPubkey,
          ),
        ).thenAnswer((_) => next.stream);
        bloc.add(const CategorySelected(music));
        await pumpEventQueue();
        bloc.add(const CategorySelected(animals));
        await pumpEventQueue();
        results.addError(const FunnelcakeException('Old request failed'));
        await pumpEventQueue();
        expect(bloc.state.selectedCategory, animals);
        expect(bloc.state.videosStatus, CategoriesVideosStatus.loading);
        await next.close();
      });

      test(
        'late For You recommendations cannot replace a newer sort',
        () async {
          final recommendations = Completer<List<VideoEvent>>();
          final next = StreamController<CacheResult<CategoryVideosPage>>();
          when(
            () => mockRepository.getRecommendedVideos(
              pubkey: _viewerPubkey,
              category: 'music',
            ),
          ).thenAnswer((_) => recommendations.future);
          when(
            () => mockRepository.watchVideosForCategoryCached(
              category: 'music',
              sort: 'timestamp',
              viewerPubkey: _viewerPubkey,
            ),
          ).thenAnswer((_) => next.stream);
          bloc.add(const CategorySelected(music));
          await pumpEventQueue();
          results.add(
            CacheResult.live(
              CategoryVideosPage(videos: [oldVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          bloc.add(const CategoryVideosSortChanged('forYou'));
          await pumpEventQueue();
          bloc.add(const CategoryVideosSortChanged('timestamp'));
          await pumpEventQueue();
          next.add(
            CacheResult.live(
              CategoryVideosPage(videos: [newVideo], hasMore: true),
            ),
          );
          await pumpEventQueue();
          recommendations.complete([oldVideo]);
          await pumpEventQueue();
          expect(bloc.state.sortOrder, 'timestamp');
          expect(bloc.state.videos, [newVideo]);
          expect(bloc.state.hasMoreVideos, isTrue);
          await next.close();
        },
      );

      test('late refresh cannot restore videos after deselection', () async {
        bloc.add(const CategorySelected(music));
        await pumpEventQueue();
        bloc.add(const CategoryDeselected());
        await pumpEventQueue();
        results.add(
          CacheResult.live(
            CategoryVideosPage(videos: [oldVideo], hasMore: true),
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.selectedCategory, isNull);
        expect(bloc.state.videos, isEmpty);
      });

      test(
        'a block made while a refresh is pending also filters its result',
        () async {
          final blocked = <String>{};
          when(
            () =>
                mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
          ).thenAnswer(
            (invocation) =>
                (invocation.positionalArguments.first as List<VideoEvent>)
                    .where((video) => !blocked.contains(video.pubkey))
                    .toList(),
          );
          final filteringBloc = CategoriesBloc(
            categoriesRepository: mockRepository,
            contentBlocklistRepository: mockBlocklistRepository,
            currentUserPubkey: _viewerPubkey,
          );
          addTearDown(filteringBloc.close);
          filteringBloc.add(const CategorySelected(music));
          await pumpEventQueue();
          blocked.add(oldVideo.pubkey);
          filteringBloc.add(const CategoriesBlocklistChanged());
          await pumpEventQueue();
          results.add(
            CacheResult.live(
              CategoryVideosPage(videos: [oldVideo], hasMore: false),
            ),
          );
          await pumpEventQueue();
          expect(
            filteringBloc.state.videosStatus,
            CategoriesVideosStatus.loaded,
          );
          expect(filteringBloc.state.videos, isEmpty);
        },
      );
    });

    group('CategorySelected', () {
      const category = VideoCategory(name: 'music', videoCount: 1500);

      final mockVideoStats = [
        _createDefaultVideoStats('id1'),
        _createDefaultVideoStats('id2'),
      ];

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, loaded] with videos for selected category',
        setUp: () {
          when(
            () => mockRepository.getVideosForCategory(
              category: 'music',
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          ).thenAnswer(
            (_) async => CategoryVideosPage(
              videos: mockVideoStats.toVideoEvents(),
              hasMore: false,
            ),
          );
        },
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategorySelected(category)),
        expect: () => [
          const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loading,
            hasMoreVideos: true,
          ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 2)
              .having((s) => s.hasMoreVideos, 'hasMoreVideos', false),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'emits error when API throws on category selection',
        setUp: () {
          when(
            () => mockRepository.getVideosForCategory(
              category: 'music',
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          ).thenThrow(const FunnelcakeException('Failed'));
        },
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategorySelected(category)),
        expect: () => [
          const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loading,
            hasMoreVideos: true,
          ),
          isA<CategoriesState>().having(
            (s) => s.videosStatus,
            'videosStatus',
            CategoriesVideosStatus.error,
          ),
        ],
      );
    });

    group(CategoryVideosLoadMore, () {
      final loadedVideo = _createDefaultVideoStats('loaded-id').toVideoEvent();

      blocTest<CategoriesBloc, CategoriesState>(
        'reports a failed page and clears the loading flag',
        setUp: () {
          when(
            () => mockRepository.getVideosForCategory(
              category: 'music',
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Offline'));
        },
        seed: () => CategoriesState(
          selectedCategory: const VideoCategory(
            name: 'music',
            videoCount: 1500,
          ),
          videosStatus: CategoriesVideosStatus.loaded,
          videos: [loadedVideo],
          hasMoreVideos: true,
        ),
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryVideosLoadMore()),
        expect: () => [
          isA<CategoriesState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<CategoriesState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videos, 'videos', [loadedVideo]),
        ],
        errors: () => [isA<FunnelcakeException>()],
      );
    });

    group('CategoryVideosSortChanged', () {
      const category = VideoCategory(name: 'music', videoCount: 1500);

      blocTest<CategoriesBloc, CategoriesState>(
        'loads category-scoped recommendations when sort changes to forYou',
        setUp: () {
          when(
            () => mockRepository.getRecommendedVideos(
              pubkey: _viewerPubkey,
              category: 'music',
            ),
          ).thenAnswer(
            (_) async => [
              _createDefaultVideoStats('recommended-id').toVideoEvent(),
            ],
          );
        },
        seed: () => const CategoriesState(
          selectedCategory: category,
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('forYou')),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.sortOrder, 'sortOrder', 'forYou')
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loading,
              ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 1),
        ],
        verify: (_) {
          verify(
            () => mockRepository.getRecommendedVideos(
              pubkey: _viewerPubkey,
              category: 'music',
            ),
          ).called(1);
          verifyNever(
            () => mockRepository.getVideosForCategory(
              category: any(named: 'category'),
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          );
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'falls back to Hot when forYou recommendations are empty after filtering',
        setUp: () {
          when(
            () => mockRepository.getRecommendedVideos(
              pubkey: _viewerPubkey,
              category: 'music',
            ),
          ).thenAnswer((_) async => const []);
          when(
            () => mockRepository.getVideosForCategory(
              category: 'music',
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          ).thenAnswer(
            (_) async => CategoryVideosPage(
              videos: [
                _createDefaultVideoStats('hot-fallback-id').toVideoEvent(),
              ],
              hasMore: true,
            ),
          );
        },
        seed: () => const CategoriesState(
          selectedCategory: category,
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('forYou')),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.sortOrder, 'sortOrder', 'forYou')
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loading,
              ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 1),
        ],
        verify: (_) {
          verify(
            () => mockRepository.getRecommendedVideos(
              pubkey: _viewerPubkey,
              category: 'music',
            ),
          ).called(1);
          verify(
            () => mockRepository.getVideosForCategory(category: 'music'),
          ).called(1);
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'reloads videos with new sort order',
        setUp: () {
          when(
            () => mockRepository.getVideosForCategory(
              category: 'music',
              before: any(named: 'before'),
              sort: 'loops',
              platform: 'vine',
            ),
          ).thenAnswer(
            (_) async => CategoryVideosPage(
              videos: [_createDefaultVideoStats('id1').toVideoEvent()],
              hasMore: false,
            ),
          );
        },
        seed: () => const CategoriesState(
          selectedCategory: category,
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('classic')),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.sortOrder, 'sortOrder', 'classic')
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loading,
              ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 1),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'does nothing when no category selected',
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('classic')),
        expect: () => <CategoriesState>[],
      );
    });

    group('CategoriesBlocklistChanged', () {
      final blockedVideo = _createVideoStats(
        'blocked-id',
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ).toVideoEvent();
      final allowedVideo = _createVideoStats(
        'allowed-id',
        pubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ).toVideoEvent();

      blocTest<CategoriesBloc, CategoriesState>(
        'drops the just-blocked pubkey from in-memory videos',
        seed: () => CategoriesState(
          selectedCategory: const VideoCategory(
            name: 'music',
            videoCount: 1500,
          ),
          videosStatus: CategoriesVideosStatus.loaded,
          videos: [blockedVideo, allowedVideo],
        ),
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(
          CategoriesBlocklistChanged(blockedPubkey: blockedVideo.pubkey),
        ),
        expect: () => [
          isA<CategoriesState>().having((s) => s.videos, 'videos', [
            allowedVideo,
          ]),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        're-filters current videos when the blocklist version changes',
        setUp: () {
          when(
            () =>
                mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
          ).thenReturn([allowedVideo]);
        },
        seed: () => CategoriesState(
          selectedCategory: const VideoCategory(
            name: 'music',
            videoCount: 1500,
          ),
          videosStatus: CategoriesVideosStatus.loaded,
          videos: [blockedVideo, allowedVideo],
        ),
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          contentBlocklistRepository: mockBlocklistRepository,
        ),
        act: (bloc) => bloc.add(const CategoriesBlocklistChanged()),
        expect: () => [
          isA<CategoriesState>().having((s) => s.videos, 'videos', [
            allowedVideo,
          ]),
        ],
      );
    });

    group('CategoryDeselected', () {
      blocTest<CategoriesBloc, CategoriesState>(
        'clears selected category and videos',
        seed: () => const CategoriesState(
          selectedCategory: VideoCategory(name: 'music', videoCount: 1500),
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryDeselected()),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.selectedCategory, 'selectedCategory', isNull)
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.initial,
              )
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );
    });
  });
}

VideoStats _createDefaultVideoStats(String id) {
  return _createVideoStats(id, pubkey: _defaultVideoPubkey);
}

const _defaultVideoPubkey =
    'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

VideoStats _createVideoStats(String id, {required String pubkey}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    videoUrl: 'https://example.com/video.mp4',
    thumbnail: 'https://example.com/thumb.jpg',
    title: 'Test Video $id',
    createdAt: DateTime.now(),
    kind: 34236,
    dTag: id,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}
