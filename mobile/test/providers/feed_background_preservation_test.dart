// ABOUTME: Tests that feed providers preserve cached videos during background
// ABOUTME: Verifies fix for feeds going empty when app resumes from background

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

/// Test override for FunnelcakeAvailable that always returns false
/// (forces Nostr fallback path for simpler mocking)
class _TestFunnelcakeUnavailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => false;
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(<VideoEvent>[]);
  });

  group('Feed background state preservation', () {
    late _MockFunnelcakeApiClient mockFunnelcakeClient;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late SharedPreferences sharedPreferences;

    // Test videos with originalLoops for ClassicVines Nostr fallback
    final testVideos = List.generate(
      5,
      (i) => VideoEvent(
        id: 'video_$i' * 8, // 64 char hex-like ID
        pubkey: 'pubkey_$i' * 7,
        createdAt:
            DateTime.now()
                .subtract(Duration(hours: i))
                .millisecondsSinceEpoch ~/
            1000,
        content: 'Test video $i',
        timestamp: DateTime.now().subtract(Duration(hours: i)),
        videoUrl: 'https://example.com/video_$i.mp4',
        thumbnailUrl: 'https://example.com/thumb_$i.jpg',
        originalLoops: 1000 - i * 100,
        rawTags: const {'platform': 'vine'},
      ),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockFunnelcakeClient = _MockFunnelcakeApiClient();
      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();

      when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);

      // Nostr fallback data: discoveryVideos for ClassicVines
      when(() => mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      when(() => mockVideoEventService.addListener(any())).thenReturn(null);
      when(() => mockVideoEventService.removeListener(any())).thenReturn(null);
      when(
        () => mockVideoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(
        () => mockVideoEventService.filterVideoList(any()),
      ).thenAnswer((inv) => inv.positionalArguments.first as List<VideoEvent>);
      when(
        () => mockVideoEventService.subscribeToVideoFeed(
          subscriptionType: any(named: 'subscriptionType'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
        ),
      ).thenAnswer((_) async {});
    });

    /// Helper to create a container with standard test overrides
    ProviderContainer createContainer({required bool appReady}) {
      return ProviderContainer(
        overrides: [
          appReadyProvider.overrideWithValue(appReady),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ],
      );
    }

    group(ClassicVinesFeed, () {
      test(
        'returns empty state when appReady is false and no prior data',
        () async {
          final container = createContainer(appReady: false);
          addTearDown(container.dispose);

          await container.read(funnelcakeAvailableProvider.future);
          final state = await container.read(classicVinesFeedProvider.future);

          expect(state.videos, isEmpty);
        },
      );

      test('preserves cached videos when appReady becomes false', () async {
        // Start with appReady=true to load videos via Nostr fallback
        final container = createContainer(appReady: true);
        addTearDown(container.dispose);

        // Pre-resolve funnelcake, then read the feed
        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          initialState.videos,
          hasLength(5),
          reason: 'Should load 5 videos initially via Nostr fallback',
        );

        // Simulate going to background — appReady becomes false
        container.updateOverrides([
          appReadyProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);

        // Allow provider to rebuild
        await container.read(funnelcakeAvailableProvider.future);
        await container.pump();

        final afterBackgroundState = await container.read(
          classicVinesFeedProvider.future,
        );

        expect(
          afterBackgroundState.videos,
          hasLength(5),
          reason: 'Should preserve videos during background',
        );
      });

      test('re-filters preserved videos when appReady is false', () async {
        final container = createContainer(appReady: true);
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos, hasLength(5));

        when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
          inv,
        ) {
          final videos = List<VideoEvent>.from(
            inv.positionalArguments.first as List,
          );
          return videos.where((video) => video.id != testVideos[1].id).toList();
        });

        container.updateOverrides([
          appReadyProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);

        await container.read(funnelcakeAvailableProvider.future);
        await container.pump();

        final afterBackgroundState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          afterBackgroundState.videos.map((v) => v.id),
          isNot(contains(testVideos[1].id)),
        );
        expect(afterBackgroundState.videos, hasLength(4));
      });

      test('reloads fresh data when appReady returns to true', () async {
        final container = createContainer(appReady: true);
        addTearDown(container.dispose);

        // Initial load
        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos, hasLength(5));

        // Go to background
        container.updateOverrides([
          appReadyProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);
        await container.read(funnelcakeAvailableProvider.future);
        await container.pump();

        // Verify preserved
        final backgroundState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          backgroundState.videos,
          hasLength(5),
          reason: 'Should preserve during background',
        );

        // Return to foreground
        container.updateOverrides([
          appReadyProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);
        await container.read(funnelcakeAvailableProvider.future);
        await container.pump();

        final resumedState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          resumedState.videos,
          hasLength(5),
          reason: 'Should have videos after resuming',
        );
      });
    });
  });
}
