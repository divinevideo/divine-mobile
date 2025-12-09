// ABOUTME: Integration test for VideoEventService to verify it can receive events from live relay
// ABOUTME: Tests the complete chain from relay connection to event handling in VideoEventService

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEventService Live Relay Integration', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late ContentBlocklistService blocklistService;

    setUp(() async {
      // Enable logging for debugging
      Log.setLogLevel(LogLevel.debug);
      Log.enableCategories({
        LogCategory.system,
        LogCategory.relay,
        LogCategory.video,
        LogCategory.auth,
      });

      // Initialize key manager
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      // Initialize services
      blocklistService = ContentBlocklistService();

      nostrService = NostrService(keyManager);
      await nostrService.initialize();

      subscriptionManager = SubscriptionManager(nostrService);

      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
      videoEventService.setBlocklistService(blocklistService);
    });

    tearDown(() async {
      videoEventService.dispose();
      subscriptionManager.dispose();
      nostrService.dispose();
    });

    test(
      'VideoEventService receives events from wss://staging-relay.divine.video',
      () async {
        Log.info('🧪 Starting VideoEventService relay test');

        // Verify nostr service is connected
        expect(nostrService.isInitialized, true);
        expect(nostrService.connectedRelays.isNotEmpty, true);
        Log.info(
          '✅ NostrService connected to ${nostrService.connectedRelays.length} relays: ${nostrService.connectedRelays}',
        );

        // Check initial state
        expect(videoEventService.getEventCount(SubscriptionType.discovery), 0);
        expect(videoEventService.hasEvents(SubscriptionType.discovery), false);

        // Subscribe to video feed
        Log.info('📡 Subscribing to video feed...');
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10, // Request 10 recent videos
        );

        // Wait for subscription to be established and events to arrive
        Log.info('⏳ Waiting for events to arrive...');
        var waitAttempts = 0;
        const maxWaitAttempts = 30; // 15 seconds total (500ms * 30)

        while (!videoEventService.hasEvents(SubscriptionType.discovery) &&
            waitAttempts < maxWaitAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          waitAttempts++;

          if (waitAttempts % 6 == 0) {
            // Log every 3 seconds
            Log.info(
              '⏳ Still waiting for events... attempt $waitAttempts/$maxWaitAttempts (${videoEventService.getEventCount(SubscriptionType.discovery)} events so far)',
            );

            // Log relay status (embedded relay)
            final relayStatus = nostrService.relayStatuses;
            Log.info('🔍 Relay status: $relayStatus');
          }
        }

        // Check results
        Log.info('📊 Final results after ${waitAttempts * 500}ms:');
        Log.info(
          '  - Events received: ${videoEventService.getEventCount(SubscriptionType.discovery)}',
        );
        Log.info(
          '  - Has events: ${videoEventService.hasEvents(SubscriptionType.discovery)}',
        );
        Log.info('  - Is subscribed: ${videoEventService.isSubscribed}');
        Log.info('  - Error: ${videoEventService.error}');

        // Log individual events if any were received
        if (videoEventService.hasEvents(SubscriptionType.discovery)) {
          Log.info('📝 Received events:');
          for (final event in videoEventService.discoveryVideos.take(5)) {
            Log.info(
              '  - Event ${event.id}: author=${event.pubkey}..., content="${event.content.length > 50 ? "${event.content.substring(0, 50)}..." : event.content}", hasVideo=${event.hasVideo}',
            );
          }
        }

        // The main assertion - should receive at least one video event
        expect(
          videoEventService.hasEvents(SubscriptionType.discovery),
          true,
          reason:
              'VideoEventService should receive at least one kind 22 video event from wss://staging-relay.divine.video relay within 15 seconds. '
              'This test confirms the relay connection and event subscription pipeline is working correctly. '
              'Events received: ${videoEventService.getEventCount(SubscriptionType.discovery)}',
        );

        expect(
          videoEventService.getEventCount(SubscriptionType.discovery),
          greaterThan(0),
          reason: 'Should have received at least one video event',
        );

        // Verify we got video events with valid video URLs
        final hasVideoEvents = videoEventService.discoveryVideos.any(
          (event) => event.hasVideo,
        );
        expect(
          hasVideoEvents,
          true,
          reason:
              'Should have received at least one video event with a valid video URL',
        );

        Log.info(
          '✅ Test passed! VideoEventService successfully received ${videoEventService.getEventCount(SubscriptionType.discovery)} events',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('VideoEventService subscription management works correctly', () async {
      Log.info('🧪 Testing VideoEventService subscription management');

      // Initial state
      expect(videoEventService.isSubscribed, false);
      expect(videoEventService.isLoading, false);

      // Start subscription
      final subscriptionFuture = videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 5,
      );

      // Should be loading
      expect(videoEventService.isLoading, true);

      await subscriptionFuture;

      // Should be subscribed and not loading
      expect(videoEventService.isSubscribed, true);
      expect(videoEventService.isLoading, false);
      expect(videoEventService.error, isNull);

      Log.info('✅ Subscription management test passed');
    });

    test('VideoEventService handles errors gracefully', () async {
      Log.info('🧪 Testing VideoEventService error handling');

      // Dispose the underlying nostr service to cause errors
      nostrService.dispose();

      // Try to subscribe - should handle error gracefully
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 5,
      );

      // Should have an error state
      expect(videoEventService.error, isNotNull);
      expect(videoEventService.isSubscribed, false);

      Log.info('✅ Error handling test passed');
    });
  });
}
