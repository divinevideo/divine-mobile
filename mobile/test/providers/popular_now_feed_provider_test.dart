// ABOUTME: Tests for PopularNowFeed provider that shows newest videos
// ABOUTME: Validates subscription to SubscriptionType.popularNow with proper sorting

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:riverpod/riverpod.dart';

import 'popular_now_feed_provider_test.mocks.dart';

@GenerateMocks([VideoEventService])
void main() {
  group('PopularNowFeed Provider', () {
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
        ),
      ).thenAnswer((_) async => Future.value());

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockService),
          // Override appReadyProvider to return true so subscription proceeds
          appReadyProvider.overrideWithValue(true),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should subscribe to SubscriptionType.popularNow on build', () async {
      // Act
      final _ = container.read(popularNowFeedProvider);
      await container.read(popularNowFeedProvider.future);

      // Assert
      verify(
        mockService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: 100,
          sortBy: argThat(isNotNull, named: 'sortBy'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('should get videos from popularNowVideos getter', () async {
      // Arrange
      final video1 = _createMockVideo(
        id: 'v1',
        createdAt: DateTime(2025, 1, 1),
      );
      final video2 = _createMockVideo(
        id: 'v2',
        createdAt: DateTime(2025, 1, 2),
      );
      when(mockService.popularNowVideos).thenReturn([video1, video2]);

      // Act
      final state = await container.read(popularNowFeedProvider.future);

      // Assert
      expect(state.videos.length, 2);
      verify(mockService.popularNowVideos).called(greaterThanOrEqualTo(1));
    });

    test('should sort videos by timestamp (newest first)', () async {
      // Arrange
      final video1 = _createMockVideo(
        id: 'v1',
        createdAt: DateTime(2025, 1, 1),
      );
      final video2 = _createMockVideo(
        id: 'v2',
        createdAt: DateTime(2025, 1, 3),
      );
      final video3 = _createMockVideo(
        id: 'v3',
        createdAt: DateTime(2025, 1, 2),
      );
      when(mockService.popularNowVideos).thenReturn([video1, video2, video3]);

      // Act
      final state = await container.read(popularNowFeedProvider.future);

      // Assert
      expect(state.videos.length, 3);
      expect(state.videos[0].id, 'v2'); // Newest (Jan 3)
      expect(state.videos[1].id, 'v3'); // Middle (Jan 2)
      expect(state.videos[2].id, 'v1'); // Oldest (Jan 1)
    });

    test('should return empty feed when no videos', () async {
      // Arrange
      when(mockService.popularNowVideos).thenReturn([]);

      // Act
      final state = await container.read(popularNowFeedProvider.future);

      // Assert
      expect(state.videos, isEmpty);
      expect(state.hasMoreContent, false);
    });

    test('should set hasMoreContent true when videos >= 10', () async {
      // Arrange
      final videos = List.generate(
        15,
        (i) => _createMockVideo(
          id: 'v$i',
          createdAt: DateTime.now().subtract(Duration(hours: i)),
        ),
      );
      when(mockService.popularNowVideos).thenReturn(videos);

      // Act
      final state = await container.read(popularNowFeedProvider.future);

      // Assert
      expect(state.videos.length, 15);
      expect(state.hasMoreContent, true);
    });

    test('should load more videos when loadMore is called', () async {
      // Arrange
      final initialVideos = [_createMockVideo(id: 'v1')];
      when(mockService.popularNowVideos).thenReturn(initialVideos);
      when(
        mockService.loadMoreEvents(
          SubscriptionType.popularNow,
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async => Future.value());

      // Mock getEventCount to return different values on consecutive calls
      var callCount = 0;
      when(
        mockService.getEventCount(SubscriptionType.popularNow),
      ).thenAnswer((_) => callCount++ == 0 ? 1 : 3);

      // Get initial state
      await container.read(popularNowFeedProvider.future);

      // Act
      await container.read(popularNowFeedProvider.notifier).loadMore();

      // Assert
      verify(
        mockService.loadMoreEvents(SubscriptionType.popularNow, limit: 50),
      ).called(1);
    });

    test('should refresh feed when refresh is called', () async {
      // Arrange
      when(mockService.popularNowVideos).thenReturn([]);
      when(
        mockService.subscribeToVideoFeed(
          subscriptionType: anyNamed('subscriptionType'),
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
          force: anyNamed('force'),
        ),
      ).thenAnswer((_) async => Future.value());

      // Get initial state
      await container.read(popularNowFeedProvider.future);

      // Act
      await container.read(popularNowFeedProvider.notifier).refresh();

      // Assert
      verify(
        mockService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.popularNow,
          limit: 100,
          sortBy: argThat(isNotNull, named: 'sortBy'),
          force: true, // Should force refresh
        ),
      ).called(1);
    });

    test('should return empty state when appReady is false', () async {
      // Arrange - create container with appReady=false
      final notReadyContainer = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(mockService),
          appReadyProvider.overrideWithValue(false),
        ],
      );

      // Act
      final state = await notReadyContainer.read(popularNowFeedProvider.future);

      // Assert
      expect(state.videos, isEmpty);
      expect(
        state.hasMoreContent,
        true,
      ); // True because we assume content will load when ready
      verifyNever(
        mockService.subscribeToVideoFeed(
          subscriptionType: anyNamed('subscriptionType'),
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
        ),
      );

      notReadyContainer.dispose();
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
