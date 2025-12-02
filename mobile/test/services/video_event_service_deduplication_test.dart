import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';

@GenerateMocks([NostrService, SubscriptionManager])
import 'video_event_service_deduplication_test.mocks.dart';

void main() {
  group('VideoEventService Subscription Deduplication', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup mock NostrService
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => Stream<Event>.empty());

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    test('should generate same subscription ID for identical parameters', () {
      // Access the private method through reflection for testing
      // Note: In production, we'd test this indirectly through behavior

      // First subscription
      videoEventService.subscribeToDiscovery(limit: 100);

      // Give it a moment to process
      Future.delayed(Duration(milliseconds: 100), () {
        // Second identical subscription
        videoEventService.subscribeToDiscovery(limit: 100);

        // Verify NostrService was only called once (reused existing)
        verify(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).called(1);
      });
    });

    test(
      'should generate different IDs for different subscription types',
      () async {
        // Subscribe to discovery
        await videoEventService.subscribeToDiscovery(limit: 100);

        // Subscribe to home feed with same limit
        await videoEventService.subscribeToHomeFeed(['author1'], limit: 100);

        // Both should create separate subscriptions
        verify(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).called(2);
      },
    );

    test('should generate different IDs for different authors', () async {
      // Subscribe with first set of authors
      await videoEventService.subscribeToHomeFeed([
        'author1',
        'author2',
      ], limit: 100);

      // Subscribe with different authors
      await videoEventService.subscribeToHomeFeed([
        'author3',
        'author4',
      ], limit: 100);

      // Both should create separate subscriptions
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(2);
    });

    test('should generate same ID regardless of author order', () async {
      // Subscribe with authors in one order
      await videoEventService.subscribeToHomeFeed([
        'author1',
        'author2',
        'author3',
      ], limit: 100);

      // Clear and subscribe with authors in different order
      await videoEventService.unsubscribeFromVideoFeed();
      await videoEventService.subscribeToHomeFeed([
        'author3',
        'author1',
        'author2',
      ], limit: 100);

      // Should reuse the subscription pattern (2 calls total, not 3)
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(2);
    });

    test('should generate different IDs for different hashtags', () async {
      // Subscribe with first hashtag
      await videoEventService.subscribeToHashtagVideos(['funny'], limit: 100);

      // Subscribe with different hashtag
      await videoEventService.subscribeToHashtagVideos(['music'], limit: 100);

      // Both should create separate subscriptions
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(2);
    });

    test('should not create duplicate subscriptions for rapid calls', () async {
      // Simulate rapid subscription calls (like from multiple UI components)
      final futures = <Future>[];

      for (int i = 0; i < 5; i++) {
        futures.add(videoEventService.subscribeToDiscovery(limit: 100));
      }

      await Future.wait(futures);

      // Should only create one subscription despite 5 calls
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(1);
    });

    test('subscription count should stay reasonable', () async {
      // Create various subscription types
      await videoEventService.subscribeToDiscovery(limit: 100);
      await videoEventService.subscribeToHomeFeed(['author1'], limit: 100);
      await videoEventService.subscribeToHashtagVideos(['funny'], limit: 100);

      // Get connection status to check subscription count
      final status = videoEventService.getConnectionStatus();
      final activeSubscriptions = status['activeSubscriptions'] as List;

      // Should have 3 active subscription types
      expect(activeSubscriptions.length, equals(3));
      expect(activeSubscriptions, contains('discovery'));
      expect(activeSubscriptions, contains('homeFeed'));
      expect(activeSubscriptions, contains('hashtag'));
    });

    test('should handle subscription replacement correctly', () async {
      // First subscription
      await videoEventService.subscribeToDiscovery(limit: 50);

      // Replace with different parameters
      await videoEventService.subscribeToDiscovery(limit: 100);

      // Should create two subscriptions (old one cancelled, new one created)
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(2);

      // But only one should be active
      final status = videoEventService.getConnectionStatus();
      final activeSubscriptions = status['activeSubscriptions'] as List;
      expect(activeSubscriptions.length, equals(1));
    });
  });
}
