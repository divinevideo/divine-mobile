// ABOUTME: Tests that curation provider refreshes when Editor's Pick tab becomes active
// ABOUTME: Verifies the fix for videos showing blank when navigating from video back to tab

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/riverpod.dart';

import 'curation_provider_lifecycle_test.mocks.dart';

@GenerateMocks([
  NostrClient,
  VideoEventService,
  SocialService,
  AuthService,
  AnalyticsApiService,
])
void main() {
  group('CurationProvider Tab Refresh', () {
    late MockNostrClient mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late MockAnalyticsApiService mockAnalyticsApiService;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
      mockAnalyticsApiService = MockAnalyticsApiService();

      // Stub nostr service to return empty stream (no async fetch for this test)
      when(
        mockNostrService.subscribe(
          argThat(anything),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      // Stub social service
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
    });

    test(
      'refreshAll() picks up videos added to cache after provider initialization',
      () async {
        // ARRANGE: Start with empty discoveryVideos
        when(mockVideoEventService.discoveryVideos).thenReturn([]);
        when(mockVideoEventService.addVideoEvent(any)).thenReturn(null);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
          ],
        );

        // ACT: Wait for initialization
        container.read(curationProvider);
        // Wait for initialization
        await Future.delayed(Duration(milliseconds: 50));

        final stateAfterInit = container.read(curationProvider);
        expect(
          stateAfterInit.editorsPicks,
          isEmpty,
          reason: 'Should be empty initially with no videos',
        );

        // SIMULATE: Videos fetched asynchronously and added to cache
        final newVideos = List.generate(
          5,
          (i) => VideoEvent(
            id: 'video_$i',
            pubkey: 'editor_pubkey',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'Editor pick $i',
            timestamp: DateTime.now(),
            vineId: 'video_$i',
            videoUrl: 'https://example.com/video_$i.mp4',
          ),
        );

        // Update mock to return new videos
        when(mockVideoEventService.discoveryVideos).thenReturn(newVideos);

        // ACT: Call refreshAll() (simulates tab change to Editor's Pick)
        await container.read(curationProvider.notifier).refreshAll();

        // ASSERT: Should now have videos from cache
        final stateAfterRefresh = container.read(curationProvider);
        expect(
          stateAfterRefresh.editorsPicks.length,
          greaterThan(0),
          reason: 'Should have videos after refreshAll() picks up cache',
        );

        container.dispose();
      },
    );

    test(
      'navigating from video back to Editor\'s Pick tab triggers refresh',
      () async {
        // This test documents the expected behavior:
        // 1. User opens Editor's Pick tab (provider initializes)
        // 2. Async fetch starts, adds videos to _editorPicksVideoCache
        // 3. User clicks a video (navigates within Explore)
        // 4. User presses back (returns to Editor's Pick tab)
        // 5. _onTabChanged() detects tab index == 2 and calls refreshAll()
        // 6. refreshAll() reads updated cache and displays videos

        // ARRANGE: Create sample editor's picks videos
        final editorVideos = List.generate(
          3,
          (i) => VideoEvent(
            id: 'editor_video_$i',
            pubkey: 'curator_pubkey',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'Curated video $i',
            timestamp: DateTime.now(),
            vineId: 'editor_video_$i',
            videoUrl: 'https://example.com/editor_$i.mp4',
          ),
        );

        // Initially empty, then populated (simulating async fetch)
        when(mockVideoEventService.discoveryVideos).thenReturn([]);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            analyticsApiServiceProvider.overrideWithValue(
              mockAnalyticsApiService,
            ),
          ],
        );

        // ACT: Initialize and wait for async work
        container.read(curationProvider);
        await Future.delayed(Duration(milliseconds: 50));

        final stateBeforeNav = container.read(curationProvider);
        expect(
          stateBeforeNav.editorsPicks,
          isEmpty,
          reason: 'Empty before navigation',
        );

        // SIMULATE: Videos fetched, cache populated
        // Update mock to return videos now
        when(mockVideoEventService.discoveryVideos).thenReturn(editorVideos);

        // SIMULATE: User navigates back to Editor's Pick tab
        // _onTabChanged() calls refreshAll()
        await container.read(curationProvider.notifier).refreshAll();

        // ASSERT: Videos should now be visible
        final stateAfterReturn = container.read(curationProvider);
        expect(
          stateAfterReturn.editorsPicks.length,
          equals(editorVideos.length),
          reason: 'Videos visible after tab return and refresh',
        );

        container.dispose();
      },
    );
  });
}
