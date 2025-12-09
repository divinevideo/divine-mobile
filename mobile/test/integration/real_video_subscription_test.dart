// ABOUTME: Real world test to verify VideoEventService works with actual staging-relay.divine.video relay
// ABOUTME: This test connects to the real relay to debug why videos aren't showing in app

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  // Initialize Flutter bindings and mock platform dependencies for test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  const MethodChannel prefsChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        if (methodCall.method == 'setString' ||
            methodCall.method == 'setStringList')
          return true;
        return null;
      });

  // Mock connectivity
  const MethodChannel connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'check') return ['wifi'];
        return null;
      });

  // Mock secure storage
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'write') return null;
        if (methodCall.method == 'read') return null;
        if (methodCall.method == 'readAll') return <String, String>{};
        return null;
      });

  group('Real Video Subscription Test', () {
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late NostrKeyManager keyManager;

    setUpAll(() async {
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(
        customRelays: ['wss://staging-relay.divine.video'],
      );

      // Wait for connection to stabilize using proper async pattern
      Log.info(
        '⏳ Waiting for relay connection...',
        name: 'RealVideoSubscriptionTest',
        category: LogCategory.system,
      );

      final connectionCompleter = Completer<void>();
      Timer.periodic(Duration(milliseconds: 200), (timer) {
        if (nostrService.connectedRelayCount > 0) {
          timer.cancel();
          connectionCompleter.complete();
        }
      });

      try {
        await connectionCompleter.future.timeout(Duration(seconds: 15));
      } catch (e) {
        Log.warning(
          'Connection timeout, proceeding anyway: $e',
          name: 'RealVideoSubscriptionTest',
          category: LogCategory.system,
        );
      }

      Log.info(
        '✅ Connection status: ${nostrService.connectedRelayCount} relays connected',
        name: 'RealVideoSubscriptionTest',
        category: LogCategory.system,
      );

      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
      videoEventService.dispose();
      subscriptionManager.dispose();
    });

    test(
      'VideoEventService should receive videos from staging-relay.divine.video relay',
      () async {
        Log.debug(
          '🔍 Testing VideoEventService with real staging-relay.divine.video relay...',
          name: 'RealVideoSubscriptionTest',
          category: LogCategory.system,
        );

        final receivedVideos = <VideoEvent>[];
        final completer = Completer<void>();

        // Listen to VideoEventService changes
        void onVideoEventChange() {
          final events = videoEventService.discoveryVideos;
          Log.debug(
            '📹 VideoEventService updated: ${events.length} total events',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );

          for (final event in events) {
            if (!receivedVideos.any((v) => v.id == event.id)) {
              receivedVideos.add(event);
              Log.info(
                '✅ New video: ${event.title ?? event.id} (hasVideo: ${event.hasVideo})',
                name: 'RealVideoSubscriptionTest',
                category: LogCategory.system,
              );
              Log.info(
                '   - URL: ${event.videoUrl}',
                name: 'RealVideoSubscriptionTest',
                category: LogCategory.system,
              );
              Log.info(
                '   - Author: ${event.pubkey}',
                name: 'RealVideoSubscriptionTest',
                category: LogCategory.system,
              );
              Log.info(
                '   - Hashtags: ${event.hashtags}',
                name: 'RealVideoSubscriptionTest',
                category: LogCategory.system,
              );
            }
          }

          if (receivedVideos.length >= 2 && !completer.isCompleted) {
            completer.complete();
          }
        }

        // Note: VideoEventService no longer extends ChangeNotifier after refactor
        // Using polling approach to check for new events instead of listener
        Timer? eventPollingTimer;
        eventPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (
          _,
        ) {
          onVideoEventChange();
        });

        try {
          // Subscribe to video feed (same as app does)
          Log.debug(
            '📡 Subscribing to video feed...',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          await videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            limit: 10,
            includeReposts: false,
          );

          Log.debug(
            '📡 Subscription created. Waiting for events...',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.debug(
            '📡 VideoEventService isSubscribed: ${videoEventService.isSubscribed}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.debug(
            '📡 VideoEventService isLoading: ${videoEventService.isLoading}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.debug(
            '📡 VideoEventService error: ${videoEventService.error}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );

          // Wait for events with reasonable timeout
          await completer.future.timeout(Duration(seconds: 15));

          Log.info(
            '🎉 SUCCESS! Received ${receivedVideos.length} videos from real relay',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );

          // Verify we got videos
          expect(
            receivedVideos.length,
            greaterThan(0),
            reason:
                'Should receive videos from staging-relay.divine.video relay',
          );

          // Verify the videos have proper URLs
          final videosWithUrls = receivedVideos
              .where((v) => v.hasVideo)
              .toList();
          expect(
            videosWithUrls.length,
            greaterThan(0),
            reason: 'Should receive videos with valid URLs',
          );

          Log.info(
            '✅ Test passed! ${videosWithUrls.length} videos have valid URLs',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
        } catch (e) {
          Log.error(
            '❌ Test failed: $e',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '🔍 Final state:',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '  - VideoEventService isSubscribed: ${videoEventService.isSubscribed}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '  - VideoEventService eventCount: ${videoEventService.getEventCount(SubscriptionType.discovery)}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '  - VideoEventService hasEvents: ${videoEventService.hasEvents(SubscriptionType.discovery)}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '  - VideoEventService error: ${videoEventService.error}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '  - Received videos: ${receivedVideos.length}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );
          Log.error(
            '  - NostrService connectedRelayCount: ${nostrService.connectedRelayCount}',
            name: 'RealVideoSubscriptionTest',
            category: LogCategory.system,
          );

          rethrow;
        } finally {
          // Cancel the polling timer instead of removing listener
          eventPollingTimer.cancel();
        }
      },
    );
  });
}
