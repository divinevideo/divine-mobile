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
