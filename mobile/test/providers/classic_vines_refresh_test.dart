// ABOUTME: Tests ClassicVines refresh recovery after transient API failures
// ABOUTME: Verifies refresh does not strand the feed without existing data

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/config/adaptive_classics.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _TestCurrentAuth extends CurrentAuthState {
  @override
  AuthState build() => AuthState.unauthenticated;

  void signIn() => state = AuthState.authenticated;
}

class _TestFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

Completer<bool>? _loadingAvailabilityCompleter;

class _LoadingFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => _loadingAvailabilityCompleter!.future;
}

void main() {
  group(ClassicVinesFeed, () {
    late _MockVideosRepository mockVideosRepository;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late SharedPreferences sharedPreferences;
    late _MockAnalyticsService analytics;
    late StreamController<void> privacyChanges;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      analytics = _MockAnalyticsService();
      privacyChanges = StreamController<void>.broadcast(sync: true);
      when(() => analytics.privacyChanges)
          .thenAnswer((_) => privacyChanges.stream);
      addTearDown(privacyChanges.close);
      mockVideosRepository = _MockVideosRepository();
      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();

      when(
        () => mockVideosRepository.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: [_videoEvent('classic-default')],
          paginationCursor: 'classic-offset:50',
          hasMore: true,
        ),
      );
      when(() => mockVideoEventService.discoveryVideos).thenReturn(const []);
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
        invocation,
      ) {
        return invocation.positionalArguments.first as List<VideoEvent>;
      });
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer({
      VideosRepository Function()? repository,
      bool adaptiveClassics = false,
    }) {
      return ProviderContainer(
        overrides: [
          appReadyProvider.overrideWithValue(true),
          if (adaptiveClassics)
            adaptiveClassicsEnabledProvider.overrideWithValue(true),
          analyticsServiceProvider.overrideWithValue(analytics),
          currentAuthStateProvider.overrideWith(_TestCurrentAuth.new),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          if (repository == null)
            videosRepositoryProvider.overrideWithValue(mockVideosRepository)
          else
            videosRepositoryProvider.overrideWith((_) => repository()),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeAvailable.new,
          ),
        ],
      );
    }

    test(
      'privacy reset rejects a late grid page even if consent returns',
      () async {
        final pending = Completer<HomeFeedResult>();
        final pageStarted = Completer<void>();
        var firstPages = 0;
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          if (invocation.namedArguments[#cursor] != null) {
            pageStarted.complete();
            return pending.future;
          }
          firstPages++;
          return HomeFeedResult(
            videos: [
              _videoEvent(firstPages.toRadixString(16).padLeft(64, '0')),
            ],
            paginationCursor: 'page-$firstPages',
            hasMore: true,
          );
        });
        final container = createContainer(adaptiveClassics: true);
        addTearDown(container.dispose);
        await container.read(funnelcakeAvailableProvider.future);
        await container.read(classicVinesFeedProvider.future);
        final next = container
            .read(classicVinesFeedProvider.notifier)
            .loadMore();
        await pageStarted.future;
        privacyChanges.add(null);
        privacyChanges.add(null);
        await container.pump();
        await container.read(classicVinesFeedProvider.future);
        pending.complete(
          HomeFeedResult(
            videos: [_videoEvent('obsolete')],
            paginationCursor: 'obsolete',
            hasMore: true,
          ),
        );
        await next;
        expect(
          container
              .read(classicVinesFeedProvider)
              .value!
              .videos
              .map((v) => v.id),
          [2.toRadixString(16).padLeft(64, '0')],
        );
      },
    );

    test(
      'late pagination failure cannot restore a previous account grid',
      () async {
        final pending = Completer<HomeFeedResult>();
        final pageStarted = Completer<void>();
        var firstPages = 0;
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          if (invocation.namedArguments[#cursor] != null) {
            pageStarted.complete();
            return pending.future;
          }
          return HomeFeedResult(
            videos: [
              _videoEvent((++firstPages).toRadixString(16).padLeft(64, '0')),
            ],
            paginationCursor: 'page-$firstPages',
            hasMore: true,
          );
        });
        final container = createContainer();
        addTearDown(container.dispose);
        await container.read(funnelcakeAvailableProvider.future);
        await container.read(classicVinesFeedProvider.future);
        final next = container
            .read(classicVinesFeedProvider.notifier)
            .loadMore();
        await pageStarted.future;
        (container.read(currentAuthStateProvider.notifier) as _TestCurrentAuth)
            .signIn();
        await container.pump();
        await container.read(classicVinesFeedProvider.future);
        pending.completeError(Exception('viewer changed'));
        await next;
        expect(
          container
              .read(classicVinesFeedProvider)
              .value!
              .videos
              .map((v) => v.id),
          [2.toRadixString(16).padLeft(64, '0')],
        );
      },
    );

    test('loads the first classics page through the repository', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      final state = await container.read(classicVinesFeedProvider.future);

      expect(state.videos.map((video) => video.id), ['classic-default']);
      expect(state.hasMoreContent, isTrue);
      verify(
        () => mockVideosRepository.getClassicVideos(
          limit: 50,
        ),
      ).called(1);
    });

    test('filters repository classics through app feed filters', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      when(
        () => mockVideosRepository.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: [
            _videoEvent('classic-supported'),
            _videoEvent('classic-blocked', pubkey: 'blocked-author'),
            _videoEvent(
              'classic-webm',
              videoUrl: 'https://example.com/classic-webm.webm',
            ),
          ],
          paginationCursor: 'classic-offset:50',
          hasMore: true,
        ),
      );
      final filteredIds = <List<String>>[];
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
        invocation,
      ) {
        final videos = invocation.positionalArguments.first as List<VideoEvent>;
        filteredIds.add(videos.map((video) => video.id).toList());
        return videos
            .where((video) => video.pubkey != 'blocked-author')
            .toList();
      });

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      final state = await container.read(classicVinesFeedProvider.future);

      expect(state.videos.map((video) => video.id), ['classic-supported']);
      expect(filteredIds, [
        ['classic-supported', 'classic-blocked'],
      ]);
    });

    test('refresh requests a fresh repository page', () async {
      var calls = 0;
      when(
        () => mockVideosRepository.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((invocation) async {
        calls++;
        return HomeFeedResult(
          videos: [_videoEvent('classic-$calls')],
          paginationCursor: 'classic-offset:${calls * 50}',
          hasMore: true,
        );
      });

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      await container.read(classicVinesFeedProvider.future);
      for (var i = 0; i < 12; i++) {
        await container.read(classicVinesFeedProvider.notifier).refresh();
      }

      expect(calls, 13);
      verify(
        () => mockVideosRepository.getClassicVideos(
          limit: 50,
          skipCache: true,
        ),
      ).called(12);
    });

    test(
      'tries the next classics page when the first page has no videos',
      () async {
        final cursors = <String?>[];
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          final cursor = invocation.namedArguments[#cursor] as String?;
          cursors.add(cursor);
          if (cursors.length == 1) {
            return const HomeFeedResult(
              videos: [],
              paginationCursor: 'classic-offset:50',
              hasMore: true,
            );
          }
          return HomeFeedResult(
            videos: [_videoEvent('classic-recovered')],
            paginationCursor: 'classic-offset:100',
            hasMore: true,
          );
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final state = await container.read(classicVinesFeedProvider.future);

        expect(state.videos.map((video) => video.id), ['classic-recovered']);
        expect(cursors, [null, 'classic-offset:50']);
      },
    );

    test('retries the first page on the current repository', () async {
      final replacement = _MockVideosRepository();
      when(
        () => replacement.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: [_videoEvent('classic-current')],
          paginationCursor: 'classic-offset:50',
          hasMore: true,
        ),
      );
      VideosRepository repository = mockVideosRepository;
      late ProviderContainer container;
      when(
        () => mockVideosRepository.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async {
        // The repository is replaced while its read is in flight.
        repository = replacement;
        container.invalidate(videosRepositoryProvider);
        throw Exception('read superseded');
      });
      container = createContainer(repository: () => repository);
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      final state = await container.read(classicVinesFeedProvider.future);

      expect(state.videos.map((video) => video.id), ['classic-current']);
    });

    test(
      'retries the first classics page after a transient API error',
      () async {
        var calls = 0;
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            throw Exception('network unavailable');
          }
          return HomeFeedResult(
            videos: [_videoEvent('classic-retry')],
            paginationCursor: 'classic-offset:50',
            hasMore: true,
          );
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final state = await container.read(classicVinesFeedProvider.future);

        expect(state.videos.map((video) => video.id), ['classic-retry']);
        expect(calls, 2);
      },
    );

    test(
      'preserves existing videos with an error when refresh API fails',
      () async {
        var calls = 0;
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return HomeFeedResult(
              videos: [_videoEvent('classic-initial')],
              paginationCursor: 'classic-offset:50',
              hasMore: true,
            );
          }
          throw Exception('server unavailable');
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'classic-initial',
        ]);

        await container.read(classicVinesFeedProvider.notifier).refresh();

        final asyncState = container.read(classicVinesFeedProvider);
        expect(asyncState.hasError, isFalse);

        final refreshedState = asyncState.value!;
        expect(refreshedState.videos.map((video) => video.id), [
          'classic-initial',
        ]);
        expect(refreshedState.isRefreshing, isFalse);
        expect(refreshedState.error, contains('server unavailable'));
      },
    );

    test(
      'preserves existing videos when refresh API returns an empty page',
      () async {
        var calls = 0;
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return HomeFeedResult(
              videos: [_videoEvent('classic-initial')],
              paginationCursor: 'classic-offset:50',
              hasMore: true,
            );
          }
          return const HomeFeedResult(videos: [], hasMore: false);
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'classic-initial',
        ]);

        await container.read(classicVinesFeedProvider.notifier).refresh();

        final refreshedState = container.read(classicVinesFeedProvider).value!;
        expect(refreshedState.videos.map((video) => video.id), [
          'classic-initial',
        ]);
        expect(refreshedState.isRefreshing, isFalse);
        expect(refreshedState.error, contains('returned no videos'));
      },
    );

    test('loadMore appends the next cursor page and dedupes videos', () async {
      when(
        () => mockVideosRepository.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return HomeFeedResult(
            videos: [_videoEvent('classic-initial')],
            paginationCursor: 'classic-offset:50',
            hasMore: true,
          );
        }
        return HomeFeedResult(
          videos: [
            _videoEvent('classic-initial'),
            _videoEvent('classic-more'),
          ],
          paginationCursor: 'classic-offset:100',
          hasMore: false,
        );
      });

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      await container.read(classicVinesFeedProvider.future);
      await container.read(classicVinesFeedProvider.notifier).loadMore();

      final state = container.read(classicVinesFeedProvider).value!;
      expect(state.videos.map((video) => video.id), [
        'classic-initial',
        'classic-more',
      ]);
      expect(state.hasMoreContent, isFalse);
      expect(state.isLoadingMore, isFalse);
      verify(
        () => mockVideosRepository.getClassicVideos(
          limit: 50,
          cursor: 'classic-offset:50',
          skipCache: true,
        ),
      ).called(1);
    });

    test(
      'loadMore preserves existing videos when the next page fails',
      () async {
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          final cursor = invocation.namedArguments[#cursor] as String?;
          if (cursor == null) {
            return HomeFeedResult(
              videos: [_videoEvent('classic-initial')],
              paginationCursor: 'classic-offset:50',
              hasMore: true,
            );
          }
          throw Exception('next page unavailable');
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        await container.read(classicVinesFeedProvider.future);
        await container.read(classicVinesFeedProvider.notifier).loadMore();

        final state = container.read(classicVinesFeedProvider).value!;
        expect(state.videos.map((video) => video.id), ['classic-initial']);
        expect(state.isLoadingMore, isFalse);
        expect(state.error, contains('next page unavailable'));
      },
    );

    test(
      'a failed refresh does not strand a superseded page load',
      () async {
        final pending = Completer<HomeFeedResult>();
        var reads = 0;
        var firstPages = 0;
        when(
          () => mockVideosRepository.getClassicVideos(
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          reads++;
          if (invocation.namedArguments[#cursor] != null) {
            return pending.future;
          }
          if (firstPages++ == 0) {
            return HomeFeedResult(
              videos: [_videoEvent('classic-initial')],
              paginationCursor: 'classic-offset:50',
              hasMore: true,
            );
          }
          throw Exception('server unavailable');
        });
        final container = createContainer();
        addTearDown(container.dispose);
        await container.read(funnelcakeAvailableProvider.future);
        await container.read(classicVinesFeedProvider.future);
        final notifier = container.read(classicVinesFeedProvider.notifier);

        final superseded = notifier.loadMore();
        expect(
          container.read(classicVinesFeedProvider).value!.isLoadingMore,
          isTrue,
        );
        await notifier.refresh();
        pending.complete(
          HomeFeedResult(
            videos: [_videoEvent('obsolete')],
            paginationCursor: 'obsolete',
            hasMore: true,
          ),
        );
        await superseded;

        final state = container.read(classicVinesFeedProvider).value!;
        expect(state.error, contains('server unavailable'));
        expect(state.isLoadingMore, isFalse);
        final readsBefore = reads;
        unawaited(notifier.loadMore());
        await pumpEventQueue();
        expect(reads, readsBefore + 1);
      },
    );

    test('stays loading while funnelcake availability is still resolving', () {
      _loadingAvailabilityCompleter = Completer<bool>();

      final container = ProviderContainer(
        overrides: [
          funnelcakeAvailableProvider.overrideWith(
            _LoadingFunnelcakeAvailable.new,
          ),
        ],
      );
      addTearDown(() {
        _loadingAvailabilityCompleter = null;
        container.dispose();
      });

      expect(container.read(classicVinesAvailableProvider).isLoading, isTrue);
    });
  });
}

VideoEvent _videoEvent(
  String id, {
  String? pubkey,
  bool isOriginalVine = false,
  String? videoUrl,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey ?? 'author-$id',
    createdAt: DateTime(2026, 3, 17).millisecondsSinceEpoch ~/ 1000,
    content: id,
    timestamp: DateTime(2026, 3, 17),
    title: id,
    videoUrl: videoUrl ?? 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    originalLoops: 100,
    rawTags: isOriginalVine ? const {'platform': 'vine'} : const {},
  );
}
