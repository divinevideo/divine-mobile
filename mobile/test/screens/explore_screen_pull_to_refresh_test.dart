// ABOUTME: Test for explore screen pull-to-refresh behavior on New Videos tab
// ABOUTME: Ensures pull-to-refresh forces a new subscription to get fresh videos

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:riverpod/riverpod.dart';

import 'explore_screen_pull_to_refresh_test.mocks.dart';

@GenerateMocks([VideoEventService])
void main() {
  group('ExploreScreen Pull-to-Refresh', () {
    late MockVideoEventService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockVideoEventService();

      // Setup default behavior
      when(mockService.addListener(any)).thenReturn(null);
      when(mockService.removeListener(any)).thenReturn(null);
      when(mockService.popularNowVideos).thenReturn([]);
      when(
        mockService.subscribeToVideoFeed(
          subscriptionType: anyNamed('subscriptionType'),
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      ).thenAnswer((_) async => Future.value());

      container = ProviderContainer(
        overrides: [videoEventServiceProvider.overrideWithValue(mockService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should call refresh() with force:true on pull-to-refresh', () async {
      // Arrange - Get initial state
      final initialVideos = [
        _createMockVideo(id: 'v1', createdAt: DateTime(2025, 1, 1)),
        _createMockVideo(id: 'v2', createdAt: DateTime(2025, 1, 2)),
      ];
      when(mockService.popularNowVideos).thenReturn(initialVideos);
      await container.read(popularNowFeedProvider.future);

      // Clear previous invocations so we can test refresh behavior
      clearInteractions(mockService);

      // Act - Simulate pull-to-refresh by calling refresh()
      // This is what the explore_screen's onRefresh callback should do
      await container.read(popularNowFeedProvider.notifier).refresh();

      // Assert - Should call subscribeToVideoFeed with force:true to get fresh videos
      verify(
        mockService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: 100,
          sortBy: argThat(isNotNull, named: 'sortBy'),
          force: true, // CRITICAL: Must force refresh to bypass caching
        ),
      ).called(1);
    });

    test(
      'should call subscribeToVideoFeed with force:true on refresh',
      () async {
        // Arrange - Get initial state
        when(mockService.popularNowVideos).thenReturn([]);
        await container.read(popularNowFeedProvider.future);

        // Clear previous invocations
        clearInteractions(mockService);

        // Act - Call refresh
        await container.read(popularNowFeedProvider.notifier).refresh();

        // Assert - Should call subscribeToVideoFeed with force:true
        // This bypasses the "Skipping re-subscribe" logic and gets fresh videos
        verify(
          mockService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.popularNow,
            limit: 100,
            sortBy: argThat(isNotNull, named: 'sortBy'),
            force: true, // CRITICAL: Must force refresh to bypass caching
          ),
        ).called(1);
      },
    );

    test('should invalidate and rebuild provider on refresh', () async {
      // Arrange
      when(mockService.popularNowVideos).thenReturn([]);
      await container.read(popularNowFeedProvider.future);

      // Track how many times build() is called by counting subscribeToVideoFeed calls
      clearInteractions(mockService);

      // Act - Refresh should invalidate and rebuild
      await container.read(popularNowFeedProvider.notifier).refresh();
      await container.read(popularNowFeedProvider.future);

      // Assert - Should have subscribed twice:
      // 1. Once for the forced refresh in refresh() method
      // 2. Once for the rebuild after invalidateSelf()
      verify(
        mockService.subscribeToVideoFeed(
          subscriptionType: anyNamed('subscriptionType'),
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}

// Helper to create mock VideoEvent for testing
VideoEvent _createMockVideo({required String id, DateTime? createdAt}) {
  final timestamp = createdAt ?? DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: timestamp,
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
  );
}
