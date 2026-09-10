import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _AlwaysAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

class _DelayedSecondGeoBlockingService extends GeoBlockingService {
  _DelayedSecondGeoBlockingService(this.secondCallCompleter);

  final Completer<GeoBlockResponse> secondCallCompleter;
  int _callCount = 0;

  @override
  Future<GeoBlockResponse> getGeoInfo() {
    _callCount += 1;
    if (_callCount == 2) {
      return secondCallCompleter.future;
    }
    return Future.value(_geoResponse());
  }
}

void main() {
  group('Explore feed refresh retention', () {
    late SharedPreferences sharedPreferences;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late _MockAuthService mockAuthService;
    late _MockNostrClient mockNostrClient;

    setUpAll(() {
      registerFallbackValue(PopularVideosVariant.native);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockVideosRepository = _MockVideosRepository();
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();
      mockAuthService = _MockAuthService();
      mockNostrClient = _MockNostrClient();

      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
        invocation,
      ) {
        return List<VideoEvent>.from(
          invocation.positionalArguments.first as List,
        );
      });
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('viewer-pubkey');
    });

    test(
      'popular videos keeps existing videos visible while refresh is in flight',
      () async {
        final initialVideos = [_video('popular-initial')];
        final refreshedVideos = [_video('popular-refreshed')];
        final refreshCompleter = Completer<PopularVideosPage>();
        var requestCount = 0;

        when(
          () => mockVideosRepository.getPopularVideosPage(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            variant: any(named: 'variant'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          requestCount += 1;
          final skipCache = invocation.namedArguments[#skipCache] as bool?;
          if (requestCount == 1) {
            expect(skipCache, isNot(true));
            return Future.value(_popularPage(initialVideos));
          }
          expect(skipCache, isTrue);
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          popularVideosFeedProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final initialState = await container.read(
          popularVideosFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'popular-initial',
        ]);

        final refreshFuture = container
            .read(popularVideosFeedProvider.notifier)
            .refresh();
        await pumpEventQueue();

        final refreshingState = container.read(popularVideosFeedProvider).value;
        expect(refreshingState, isNotNull);
        expect(refreshingState!.videos.map((video) => video.id), [
          'popular-initial',
        ]);
        expect(refreshingState.isRefreshing, isTrue);

        refreshCompleter.complete(_popularPage(refreshedVideos));
        await refreshFuture;

        final finalState = container.read(popularVideosFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-refreshed',
        ]);
        expect(finalState.isRefreshing, isFalse);
        verify(
          () => mockVideosRepository.getPopularVideosPage(
            limit: AppConstants.paginationBatchSize,
            variant: PopularVideosVariant.native,
            skipCache: true,
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).called(1);
      },
    );

    test('popular videos native source uses age-decayed v2 popular', () async {
      when(
        () => mockVideosRepository.getPopularVideosPage(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          variant: any(named: 'variant'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((_) async => _popularPage([_video('popular-age-decayed')]));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(popularVideosFeedProvider.future);

      expect(state.videos.map((video) => video.id), ['popular-age-decayed']);
      verify(
        () => mockVideosRepository.getPopularVideosPage(
          limit: AppConstants.paginationBatchSize,
          variant: PopularVideosVariant.native,
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).called(1);
    });

    test(
      'popular videos exposes selected variant as loading until its page resolves',
      () async {
        final classicCompleter = Completer<PopularVideosPage>();
        final requestedVariants = <PopularVideosVariant>[];

        when(
          () => mockVideosRepository.getPopularVideosPage(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            variant: any(named: 'variant'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          final variant =
              invocation.namedArguments[#variant] as PopularVideosVariant;
          requestedVariants.add(variant);
          if (variant == PopularVideosVariant.native) {
            return Future.value(_popularPage([_video('popular-native')]));
          }
          return classicCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          popularVideosFeedProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final loadedVariantSubscription = container.listen(
          popularVideosLoadedVariantProvider,
          (_, next) {
            if (next != PopularVideosVariant.classic) return;
            final currentFeed = container.read(popularVideosFeedProvider).value;
            expect(
              currentFeed?.videos.map((video) => video.id),
              ['popular-classic'],
              reason: 'Loaded variant must not update before matching feed data is published.',
            );
          },
        );
        addTearDown(loadedVariantSubscription.close);

        final nativeState = await container.read(
          popularVideosFeedProvider.future,
        );
        expect(nativeState.videos.map((video) => video.id), ['popular-native']);
        expect(
          container.read(popularVideosLoadedVariantProvider),
          PopularVideosVariant.native,
        );

        container.read(popularVideosVariantProvider.notifier).state =
            PopularVideosVariant.classic;
        await pumpEventQueue();

        expect(requestedVariants, [
          PopularVideosVariant.native,
          PopularVideosVariant.classic,
        ]);
        expect(
          container.read(popularVideosLoadedVariantProvider),
          isNull,
          reason: 'The UI must not treat the old Native page as the selected Classic page.',
        );

        classicCompleter.complete(
          _popularPage([_vineArchiveVideo('popular-classic')]),
        );
        final classicState = await container.read(
          popularVideosFeedProvider.future,
        );

        expect(classicState.videos.map((video) => video.id), [
          'popular-classic',
        ]);
        expect(
          container.read(popularVideosLoadedVariantProvider),
          PopularVideosVariant.classic,
        );
      },
    );

    test(
      'popular videos preserves existing videos when refresh fails',
      () async {
        final initialVideos = [_video('popular-initial')];
        var requestCount = 0;

        when(
          () => mockVideosRepository.getPopularVideosPage(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            variant: any(named: 'variant'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          requestCount += 1;
          final skipCache = invocation.namedArguments[#skipCache] as bool?;
          if (requestCount == 1) {
            return Future.value(_popularPage(initialVideos));
          }
          expect(skipCache, isTrue);
          throw StateError('age-decayed refresh failed');
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          popularVideosFeedProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final initialState = await container.read(
          popularVideosFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'popular-initial',
        ]);

        await container.read(popularVideosFeedProvider.notifier).refresh();

        final finalState = container.read(popularVideosFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-initial',
        ]);
        expect(finalState.isRefreshing, isFalse);
        expect(finalState.error, contains('age-decayed refresh failed'));
      },
    );

    test(
      'popular videos load more uses opaque cursor and filters duplicates',
      () async {
        final initialRawVideos = [
          _video('popular-initial'),
          for (var i = 1; i < AppConstants.paginationBatchSize; i++)
            _vineArchiveVideo('popular-vine-$i', createdAt: 1_742_169_600 - i),
        ];
        final loadMoreRawVideos = [
          _video('popular-initial'),
          _video('popular-more'),
        ];
        const oldestInitialCursor =
            '${1_742_169_600 - (AppConstants.paginationBatchSize - 1)}';
        final requestedCursors = <String?>[];

        when(
          () => mockVideosRepository.getPopularVideosPage(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            variant: any(named: 'variant'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) async {
          final cursor = invocation.namedArguments[#cursor] as String?;
          requestedCursors.add(cursor);
          if (cursor == null) {
            return _popularPage(
              initialRawVideos,
              nextCursor: oldestInitialCursor,
            );
          }
          if (cursor == oldestInitialCursor) {
            return _popularPage(loadMoreRawVideos, hasMore: false);
          }
          throw StateError('unexpected cursor $cursor');
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          popularVideosFeedProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final initialState = await container.read(
          popularVideosFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'popular-initial',
        ]);
        expect(initialState.hasMoreContent, isTrue);

        await container.read(popularVideosFeedProvider.notifier).loadMore();

        final finalState = container.read(popularVideosFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-initial',
          'popular-more',
        ]);
        expect(finalState.hasMoreContent, isFalse);
        expect(finalState.isLoadingMore, isFalse);
        expect(requestedCursors, [null, oldestInitialCursor]);
      },
    );

    test('popular videos does not fall back to native leaderboard', () async {
      when(
        () => mockVideosRepository.getPopularVideosPage(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          variant: any(named: 'variant'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenThrow(StateError('age-decayed popular unavailable'));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(popularVideosFeedProvider.future);

      expect(state.videos, isEmpty);
      expect(state.hasMoreContent, isFalse);
      expect(state.error, contains('age-decayed popular unavailable'));
    });

    test(
      'for you keeps existing videos visible while refresh is in flight',
      () async {
        final refreshCompleter = Completer<HomeFeedResult>();
        final skipCacheRequests = <bool?>[];
        var requestCount = 0;

        when(
          () => mockVideosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          skipCacheRequests.add(invocation.namedArguments[#skipCache] as bool?);
          requestCount += 1;
          if (requestCount == 1) {
            return Future.value(_recommendedResult(['for-you-initial']));
          }
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final initialState = await container.read(forYouFeedProvider.future);
        expect(initialState.videos.map((video) => video.id), [
          'for-you-initial',
        ]);

        final refreshFuture = container
            .read(forYouFeedProvider.notifier)
            .refresh();
        await pumpEventQueue();

        final refreshingState = container.read(forYouFeedProvider).value;
        expect(refreshingState, isNotNull);
        expect(refreshingState!.videos.map((video) => video.id), [
          'for-you-initial',
        ]);
        expect(refreshingState.isRefreshing, isTrue);

        refreshCompleter.complete(_recommendedResult(['for-you-refreshed']));
        await refreshFuture;

        final finalState = container.read(forYouFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'for-you-refreshed',
        ]);
        expect(finalState.isRefreshing, isFalse);
        expect(skipCacheRequests, [false, true]);
      },
    );

    test('for you preserves existing pagination when refresh fails', () async {
      var requestCount = 0;
      final requestedCursors = <String?>[];
      final skipCacheRequests = <bool?>[];

      when(
        () => mockVideosRepository.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((invocation) {
        requestedCursors.add(invocation.namedArguments[#cursor] as String?);
        skipCacheRequests.add(invocation.namedArguments[#skipCache] as bool?);
        requestCount += 1;
        if (requestCount == 1) {
          return Future.value(
            _recommendedResult(['for-you-initial'], nextCursor: 'cursor-2'),
          );
        }
        if (requestCount == 2) {
          throw StateError('recommendations refresh failed');
        }
        return Future.value(
          _recommendedResult(['for-you-page-2'], nextCursor: 'cursor-3'),
        );
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          authServiceProvider.overrideWithValue(mockAuthService),
          funnelcakeAvailableProvider.overrideWith(
            _AlwaysAvailableFunnelcake.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      final subscription = container.listen(forYouFeedProvider, (_, _) {});
      addTearDown(subscription.close);

      final initialState = await container.read(forYouFeedProvider.future);
      expect(initialState.videos.map((video) => video.id), ['for-you-initial']);
      expect(initialState.hasMoreContent, isTrue);

      await container.read(forYouFeedProvider.notifier).refresh();

      final refreshedState = container.read(forYouFeedProvider).value;
      expect(refreshedState, isNotNull);
      expect(refreshedState!.videos.map((video) => video.id), [
        'for-you-initial',
      ]);
      expect(refreshedState.hasMoreContent, isTrue);
      expect(refreshedState.isRefreshing, isFalse);
      expect(refreshedState.error, contains('recommendations refresh failed'));

      await container.read(forYouFeedProvider.notifier).loadMore();

      final loadedState = container.read(forYouFeedProvider).value;
      expect(loadedState, isNotNull);
      expect(loadedState!.videos.map((video) => video.id), [
        'for-you-initial',
        'for-you-page-2',
      ]);
      expect(loadedState.hasMoreContent, isTrue);
      expect(requestedCursors, [null, null, 'cursor-2']);
      expect(skipCacheRequests, [false, true, false]);
    });

    test(
      'for you load more uses recommendation cursor and appends unseen videos',
      () async {
        final requestedCursors = <String?>[];
        var recommendationsCallCount = 0;

        when(
          () => mockVideosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          requestedCursors.add(invocation.namedArguments[#cursor] as String?);
          recommendationsCallCount += 1;
          if (recommendationsCallCount == 1) {
            return Future.value(
              _recommendedResult([
                'for-you-a',
                'for-you-b',
              ], nextCursor: 'cursor-2'),
            );
          }
          return Future.value(
            _recommendedResult([
              'for-you-b',
              'for-you-c',
            ], nextCursor: 'cursor-3'),
          );
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final initialState = await container.read(forYouFeedProvider.future);
        expect(initialState.videos.map((video) => video.id), [
          'for-you-a',
          'for-you-b',
        ]);
        expect(initialState.hasMoreContent, isTrue);

        await container.read(forYouFeedProvider.notifier).loadMore();

        final loadedState = container.read(forYouFeedProvider).value;
        expect(loadedState, isNotNull);
        expect(loadedState!.videos.map((video) => video.id), [
          'for-you-a',
          'for-you-b',
          'for-you-c',
        ]);
        expect(loadedState.hasMoreContent, isTrue);
        expect(requestedCursors, [null, 'cursor-2']);
      },
    );

    test(
      'for you collapses a republished coordinate returned twice in one page',
      () async {
        when(
          () => mockVideosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer(
          (_) => Future.value(
            HomeFeedResult(
              videos: [
                _video(
                  'for-you-a',
                  pubkey: 'author-shared',
                  dTag: 'shared-d-tag',
                ),
                _video(
                  'for-you-b',
                  pubkey: 'author-shared',
                  dTag: 'shared-d-tag',
                ),
              ],
            ),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final state = await container.read(forYouFeedProvider.future);
        expect(state.videos.map((video) => video.id), ['for-you-a']);
      },
    );

    test(
      'for you uses repository deep-fetch when the first page is all seen',
      () async {
        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(() => mockNostrClient.publicKey).thenReturn('');
        when(
          () => mockFunnelcakeApiClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            seed: any(named: 'seed'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer(
          (_) async => _recommendationsResponse([
            'for-you-seen',
          ], nextCursor: 'cursor-2'),
        );
        when(
          () => mockFunnelcakeApiClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            cursor: 'cursor-2',
            seed: any(named: 'seed'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((_) async => _recommendationsResponse(['for-you-fresh']));

        final repository = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeApiClient,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id == 'for-you-seen',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(repository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final state = await container.read(forYouFeedProvider.future);
        expect(state.videos.map((video) => video.id), [
          'for-you-fresh',
          'for-you-seen',
        ]);
        verify(
          () => mockFunnelcakeApiClient.getRecommendations(
            pubkey: 'viewer-pubkey',
            limit: 50,
            cursor: 'cursor-2',
            seed: any(named: 'seed'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).called(1);
      },
    );

    test('for you discards stale cursor pages across rebuilds', () async {
      final geoCompleter = Completer<GeoBlockResponse>();
      final requests = <String?>[];

      when(
        () => mockVideosRepository.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((invocation) {
        final cursor = invocation.namedArguments[#cursor] as String?;
        requests.add(cursor);
        return Future.value(
          _recommendedResult(
            cursor == null ? ['for-you-rebuilt'] : ['for-you-page-2'],
            nextCursor: cursor == null ? 'cursor-2' : 'cursor-3',
          ),
        );
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          authServiceProvider.overrideWithValue(mockAuthService),
          funnelcakeAvailableProvider.overrideWith(
            _AlwaysAvailableFunnelcake.new,
          ),
          geoBlockingServiceProvider.overrideWithValue(
            _DelayedSecondGeoBlockingService(geoCompleter),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      final subscription = container.listen(forYouFeedProvider, (_, _) {});
      addTearDown(subscription.close);

      final initialState = await container.read(forYouFeedProvider.future);
      expect(initialState.hasMoreContent, isTrue);
      expect(requests, [null]);

      final loadMoreFuture = container
          .read(forYouFeedProvider.notifier)
          .loadMore();
      await pumpEventQueue();

      container.read(blocklistVersionProvider.notifier).increment();
      await pumpEventQueue();

      geoCompleter.complete(_geoResponse());
      await loadMoreFuture;
      await pumpEventQueue();

      expect(requests, [null, null, 'cursor-2']);

      await container.read(forYouFeedProvider.notifier).loadMore();

      expect(requests, [null, null, 'cursor-2', 'cursor-2']);

      final loadedState = container.read(forYouFeedProvider).value;
      expect(loadedState, isNotNull);
      expect(loadedState!.videos.map((video) => video.id), [
        'for-you-rebuilt',
        'for-you-page-2',
      ]);
    });

    test(
      'for you ignores stale first page results after a newer rebuild',
      () async {
        final staleRefreshCompleter = Completer<HomeFeedResult>();
        final requestedCursors = <String?>[];
        var requestCount = 0;

        when(
          () => mockVideosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          final cursor = invocation.namedArguments[#cursor] as String?;
          requestedCursors.add(cursor);
          requestCount += 1;

          if (cursor != null) {
            return Future.value(
              _recommendedResult(['for-you-page-2'], hasMore: false),
            );
          }
          if (requestCount == 1) {
            return Future.value(
              _recommendedResult(['for-you-initial'], nextCursor: 'cursor-2'),
            );
          }
          if (requestCount == 2) {
            return staleRefreshCompleter.future;
          }
          return Future.value(
            _recommendedResult(['for-you-rebuilt'], nextCursor: 'cursor-3'),
          );
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final initialState = await container.read(forYouFeedProvider.future);
        expect(initialState.videos.map((video) => video.id), [
          'for-you-initial',
        ]);
        expect(initialState.hasMoreContent, isTrue);

        final refreshFuture = container
            .read(forYouFeedProvider.notifier)
            .refresh();
        await pumpEventQueue();

        container.read(blocklistVersionProvider.notifier).increment();
        await pumpEventQueue();

        final rebuiltState = await container.read(forYouFeedProvider.future);
        expect(rebuiltState.videos.map((video) => video.id), [
          'for-you-rebuilt',
        ]);

        staleRefreshCompleter.complete(
          _recommendedResult([
            'for-you-stale-refresh',
          ], nextCursor: 'stale-cursor'),
        );
        await refreshFuture;
        await pumpEventQueue();

        final afterStaleRefresh = container.read(forYouFeedProvider).value;
        expect(afterStaleRefresh, isNotNull);
        expect(afterStaleRefresh!.videos.map((video) => video.id), [
          'for-you-rebuilt',
        ]);

        await container.read(forYouFeedProvider.notifier).loadMore();

        expect(requestedCursors, [null, null, null, 'cursor-3']);
        final loadedState = container.read(forYouFeedProvider).value;
        expect(loadedState, isNotNull);
        expect(loadedState!.videos.map((video) => video.id), [
          'for-you-rebuilt',
          'for-you-page-2',
        ]);
      },
    );

    test(
      'for you keeps loading when a cursor page adds no visible videos',
      () async {
        final requestedCursors = <String?>[];
        var recommendationsCallCount = 0;

        when(
          () => mockVideosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          requestedCursors.add(invocation.namedArguments[#cursor] as String?);
          recommendationsCallCount += 1;
          if (recommendationsCallCount == 1) {
            return Future.value(
              _recommendedResult([
                'for-you-a',
                'for-you-b',
              ], nextCursor: 'cursor-2'),
            );
          }
          if (recommendationsCallCount == 2) {
            return Future.value(
              _recommendedResult([
                'FOR-YOU-A',
                'for-you-b',
              ], nextCursor: 'cursor-3'),
            );
          }
          return Future.value(
            _recommendedResult(
              ['for-you-c'],
              nextCursor: 'cursor-4',
              hasMore: false,
            ),
          );
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final initialState = await container.read(forYouFeedProvider.future);
        expect(initialState.videos.map((video) => video.id), [
          'for-you-a',
          'for-you-b',
        ]);
        expect(initialState.hasMoreContent, isTrue);

        await container.read(forYouFeedProvider.notifier).loadMore();

        final duplicatePageState = container.read(forYouFeedProvider).value;
        expect(duplicatePageState, isNotNull);
        expect(duplicatePageState!.videos.map((video) => video.id), [
          'for-you-a',
          'for-you-b',
        ]);
        expect(duplicatePageState.hasMoreContent, isTrue);

        await container.read(forYouFeedProvider.notifier).loadMore();

        final nextPageState = container.read(forYouFeedProvider).value;
        expect(nextPageState, isNotNull);
        expect(nextPageState!.videos.map((video) => video.id), [
          'for-you-a',
          'for-you-b',
          'for-you-c',
        ]);
        expect(nextPageState.hasMoreContent, isFalse);
        expect(requestedCursors, [null, 'cursor-2', 'cursor-3']);
      },
    );

    test(
      'for you stops load more when recommendations omit pagination cursor',
      () async {
        var recommendationsCallCount = 0;

        when(
          () => mockVideosRepository.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((_) {
          recommendationsCallCount += 1;
          return Future.value(_recommendedResult(['for-you-legacy']));
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final initialState = await container.read(forYouFeedProvider.future);
        expect(initialState.videos.map((video) => video.id), [
          'for-you-legacy',
        ]);
        expect(initialState.hasMoreContent, isFalse);

        await container.read(forYouFeedProvider.notifier).loadMore();

        final loadedState = container.read(forYouFeedProvider).value;
        expect(loadedState, isNotNull);
        expect(loadedState!.videos.map((video) => video.id), [
          'for-you-legacy',
        ]);
        expect(loadedState.hasMoreContent, isFalse);
        expect(recommendationsCallCount, 1);
      },
    );
  });
}

RecommendationsResponse _recommendationsResponse(
  List<String> ids, {
  String? nextCursor,
  bool hasMore = true,
}) {
  return RecommendationsResponse(
    videos: ids.map(_videoStats).toList(),
    source: 'personalized',
    nextCursor: nextCursor,
    hasMore: hasMore,
  );
}

HomeFeedResult _recommendedResult(
  List<String> ids, {
  String? nextCursor,
  bool hasMore = true,
}) {
  return HomeFeedResult(
    videos: ids.map(_video).toList(),
    paginationCursor: nextCursor,
    hasMore: hasMore,
  );
}

GeoBlockResponse _geoResponse() {
  return GeoBlockResponse(
    blocked: false,
    country: 'UNKNOWN',
    region: 'UNKNOWN',
    city: 'UNKNOWN',
  );
}

PopularVideosPage _popularPage(
  List<VideoEvent> videos, {
  String? nextCursor,
  bool hasMore = true,
}) {
  return PopularVideosPage(
    videos: videos,
    nextCursor: nextCursor,
    hasMore: hasMore,
  );
}

VideoEvent _video(
  String id, {
  String? pubkey,
  String? dTag,
  int createdAt = 1_742_169_600,
  Map<String, String> rawTags = const {
    'd': 'seed',
    'x': '1',
    'y': '2',
    'z': '3',
  },
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey ?? 'author-$id',
    createdAt: createdAt,
    content: 'video $id',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: dTag == null ? rawTags : {...rawTags, 'd': dTag},
    addressableDTag: dTag,
    originalLoops: AppConstants.paginationBatchSize,
  );
}

VideoEvent _vineArchiveVideo(String id, {int createdAt = 1_742_169_600}) {
  return _video(
    id,
    createdAt: createdAt,
    rawTags: const {
      'd': 'seed',
      'x': '1',
      'y': '2',
      'z': '3',
      'platform': 'vine',
    },
  );
}

VideoStats _videoStats(String id, {String? pubkey, String? dTag}) {
  return VideoStats(
    id: id,
    pubkey: pubkey ?? 'author-$id',
    createdAt: DateTime(2026, 3, 17),
    kind: 34236,
    dTag: dTag ?? id,
    title: id,
    thumbnail: 'https://example.com/$id.jpg',
    videoUrl: 'https://example.com/$id.mp4',
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}
