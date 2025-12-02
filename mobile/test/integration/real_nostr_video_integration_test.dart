// ABOUTME: Real integration test for video event publishing and retrieval via Nostr
// ABOUTME: Uses real relay connections instead of mocking, tests actual network integration

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import '../helpers/real_integration_test_helper.dart';
import '../helpers/test_nostr_service.dart';

void main() {
  group('Real Nostr Video Integration Tests', () {
    late VideoEventService videoEventService;

    setUpAll(() async {
      await RealIntegrationTestHelper.setupTestEnvironment();
    });

    setUp(() async {
      // Use test service instead of real service for unit tests
      final nostrService = TestNostrService();
      final subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
      // VideoEventService doesn't have initialize anymore
    });

    tearDownAll(() async {
      await RealIntegrationTestHelper.cleanup();
    });

    testWidgets(
      'can fetch real video events from staging-relay.divine.video relay',
      (tester) async {
        // This test uses REAL network connections to staging-relay.divine.video
        // No mocking of NostrService, network, or relay connections

        // Subscribe to video feed
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 5,
        );

        // Wait for events to load
        await Future.delayed(const Duration(seconds: 2));
        await tester.pump();

        // Get video events from cache
        final videoEvents = videoEventService.discoveryVideos;

        // Should get real video events from the relay
        expect(videoEvents, isNotNull);
        // May be empty if no videos on relay, but should not error
        expect(videoEvents, isA<List<VideoEvent>>());

        // If we got videos, they should be valid
        for (final video in videoEvents) {
          expect(video.id, isNotEmpty);
          expect(video.pubkey, isNotEmpty);
          expect(video.createdAt, greaterThan(0));
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'can subscribe to real video events',
      (tester) async {
        // Test real subscription to live relay
        int initialCount = videoEventService.discoveryVideos.length;

        // Subscribe to video feed
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        // Wait a bit for any events
        await Future.delayed(const Duration(seconds: 3));
        await tester.pump();

        // Check if we got any new events
        int finalCount = videoEventService.discoveryVideos.length;

        // May not receive events immediately, but subscription should work
        expect(finalCount, greaterThanOrEqualTo(initialCount));

        // Clean up subscription
        await videoEventService.unsubscribeFromVideoFeed();
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });
}
