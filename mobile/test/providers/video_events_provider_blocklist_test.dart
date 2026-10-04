// ABOUTME: Tests for blocklist filtering in videoEventsProvider
// ABOUTME: Verifies blocked/muted users are excluded from discovery emissions

import 'dart:ui';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(NIP50SortMode.hot);
  });

  group('VideoEventsProvider - Blocklist Filtering', () {
    late _MockNostrClient mockNostrClient;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockVideoEventService mockVideoEventService;
    late SharedPreferences sharedPreferences;
    late ProviderContainer container;

    final blockedPubkey = '1' * 64;
    final allowedPubkey = '2' * 64;

    VideoEvent createTestVideo(String id, {required String pubkey}) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockNostrClient = _MockNostrClient();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockVideoEventService = _MockVideoEventService();

      // Stub NostrClient
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(0);

      // Stub blocklist: blockedPubkey is filtered, allowedPubkey is not
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(blockedPubkey),
      ).thenReturn(true);
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(allowedPubkey),
      ).thenReturn(false);

      // Stub VideoEventService
      when(() => mockVideoEventService.isSubscribed(any())).thenReturn(false);
      when(
        () => mockVideoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
        invocation,
      ) {
        final videos = invocation.positionalArguments.first as List<VideoEvent>;
        return videos
            .where(
              (video) =>
                  !mockBlocklistRepository.shouldFilterFromFeeds(video.pubkey),
            )
            .toList();
      });
      when(() => mockVideoEventService.removeListener(any())).thenReturn(null);
      when(() => mockVideoEventService.addListener(any())).thenReturn(null);
      when(
        () => mockVideoEventService.subscribeToDiscovery(
          limit: any(named: 'limit'),
          nip50Sort: any(named: 'nip50Sort'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() {
      container.dispose();
    });

    test('filters blocked users from initial discovery emission', () {
      fakeAsync((async) {
        // Service returns videos including a blocked user
        final videos = [
          createTestVideo('v1', pubkey: allowedPubkey),
          createTestVideo('v2', pubkey: blockedPubkey),
          createTestVideo('v3', pubkey: allowedPubkey),
        ];
        when(() => mockVideoEventService.discoveryVideos).thenReturn(videos);

        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            appReadyProvider.overrideWith((ref) => true),
            isDiscoveryTabActiveProvider.overrideWith((ref) => true),
            isExploreTabActiveProvider.overrideWith((ref) => false),
          ],
        );

        final emissions = <List<VideoEvent>>[];
        container.listen(videoEventsProvider, (prev, next) {
          next.whenData(emissions.add);
        });

        // Give time for the Future.microtask in _startSubscription to fire
        async.flushMicrotasks();

        // Verify shouldFilterFromFeeds was called for each video
        verify(
          () => mockBlocklistRepository.shouldFilterFromFeeds(blockedPubkey),
        ).called(greaterThanOrEqualTo(1));
        verify(
          () => mockBlocklistRepository.shouldFilterFromFeeds(allowedPubkey),
        ).called(greaterThanOrEqualTo(1));

        expect(emissions, isNotEmpty);
        expect(emissions.last.map((video) => video.id), ['v1', 'v3']);
        container.dispose();
        async.flushMicrotasks();
      });
    });

    test('filters blocked users from change-triggered emission', () {
      fakeAsync((async) {
        // Start with empty discovery
        when(() => mockVideoEventService.discoveryVideos).thenReturn([]);

        // Capture the listener callback
        VoidCallback? capturedListener;
        when(() => mockVideoEventService.addListener(any())).thenAnswer((inv) {
          capturedListener = inv.positionalArguments[0] as VoidCallback;
        });

        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            appReadyProvider.overrideWith((ref) => true),
            isDiscoveryTabActiveProvider.overrideWith((ref) => true),
            isExploreTabActiveProvider.overrideWith((ref) => false),
          ],
        );

        // Listen to the stream for emissions
        final emissions = <List<VideoEvent>>[];
        container.listen(videoEventsProvider, (prev, next) {
          next.whenData(emissions.add);
        });

        // Wait for initial build
        async.flushMicrotasks();

        // Now simulate new videos arriving (with a blocked user)
        final newVideos = [
          createTestVideo('v1', pubkey: allowedPubkey),
          createTestVideo('v2', pubkey: blockedPubkey),
          createTestVideo('v3', pubkey: allowedPubkey),
        ];
        when(() => mockVideoEventService.discoveryVideos).thenReturn(newVideos);

        // Trigger the listener (simulating VideoEventService notifying)
        expect(capturedListener, isNotNull, reason: 'Listener should be set');
        capturedListener!();

        // Wait for debounce timer (500ms in the provider)
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(emissions, isNotEmpty);
        expect(emissions.last.map((video) => video.id), ['v1', 'v3']);

        // Verify the blocklist was consulted during the change callback
        verify(
          () => mockBlocklistRepository.shouldFilterFromFeeds(blockedPubkey),
        ).called(greaterThanOrEqualTo(1));
        container.dispose();
        async.flushMicrotasks();
      });
    });

    test('emits all videos when no users are blocked', () {
      fakeAsync((async) {
        // Nobody is blocked
        when(
          () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
        ).thenReturn(false);

        final videos = [
          createTestVideo('v1', pubkey: allowedPubkey),
          createTestVideo('v2', pubkey: blockedPubkey),
          createTestVideo('v3', pubkey: allowedPubkey),
        ];
        when(() => mockVideoEventService.discoveryVideos).thenReturn([]);

        // Capture the listener callback
        VoidCallback? capturedListener;
        when(() => mockVideoEventService.addListener(any())).thenAnswer((inv) {
          capturedListener = inv.positionalArguments[0] as VoidCallback;
        });

        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            appReadyProvider.overrideWith((ref) => true),
            isDiscoveryTabActiveProvider.overrideWith((ref) => true),
            isExploreTabActiveProvider.overrideWith((ref) => false),
          ],
        );

        // Listen to the stream
        final emissions = <List<VideoEvent>>[];
        container.listen(videoEventsProvider, (prev, next) {
          next.whenData(emissions.add);
        });

        // Wait for initial build
        async.flushMicrotasks();

        emissions.clear();
        when(() => mockVideoEventService.discoveryVideos).thenReturn(videos);

        // Trigger change
        expect(capturedListener, isNotNull);
        capturedListener!();

        // Wait for debounce
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(emissions, isNotEmpty);
        expect(
          emissions.last.length,
          equals(3),
          reason: 'All videos should be emitted when nothing is blocked',
        );
        container.dispose();
        async.flushMicrotasks();
      });
    });
  });
}
