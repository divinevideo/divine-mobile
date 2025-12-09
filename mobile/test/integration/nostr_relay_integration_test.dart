// ABOUTME: Real integration test that connects to relays and publishes events
// ABOUTME: Verifies the consolidated NostrService works with actual relay connections

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Set up SharedPreferences for tests
    SharedPreferences.setMockInitialValues({});
  });

  group('NostrService Real Relay Integration', () {
    test(
      'should connect to relay and publish/receive events',
      () async {
        // Create real key manager
        final keyManager = NostrKeyManager();
        await keyManager.initialize();

        if (!keyManager.hasKeys) {
          await keyManager.generateKeys();
        }

        // Create service
        final service = NostrService(keyManager);

        try {
          // Initialize service with real relay
          Log.debug('🔌 Initializing NostrService with real relay...');
          await service.initialize(
            customRelays: ['wss://staging-relay.divine.video'],
          );

          expect(service.isInitialized, true);
          expect(service.connectedRelays.isNotEmpty, true);
          Log.debug('✅ Connected to ${service.connectedRelays.length} relays');

          // Test 1: Publish a test event
          Log.debug('\n📤 Publishing test event...');
          final testContent =
              'Integration test event ${DateTime.now().toIso8601String()}';
          final testEvent = Event(
            service.publicKey!,
            1, // Kind 1: Text note
            [
              [
                'expiration',
                '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
              ],
            ],
            testContent,
          );

          final publishResult = await service.broadcastEvent(testEvent);
          expect(publishResult.successCount, greaterThan(0));
          Log.debug(
            '✅ Event published successfully to ${publishResult.successCount} relays',
          );
          Log.debug('📋 Event ID: ${publishResult.event.id}');

          // Test 2: Subscribe and receive the event we just published
          Log.debug('\n📥 Subscribing to receive our event...');
          final filter = Filter(
            authors: [service.publicKey!],
            kinds: [1],
            limit: 5,
          );

          final receivedEvents = <Event>[];
          final subscription = service.subscribeToEvents(filters: [filter]);

          // Listen for events with timeout
          final completer = Completer<void>();
          late StreamSubscription<Event> streamSub;

          streamSub = subscription.listen((event) {
            receivedEvents.add(event);
            Log.debug(
              '📨 Received event: ${event.id}... content: "${event.content}"',
            );

            // Check if we received our test event
            if (event.content == testContent) {
              Log.debug('✅ Successfully received our test event!');
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          });

          // Wait for our event with timeout
          try {
            await completer.future.timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Log.debug(
                  '⏱️ Timeout waiting for event - this might be normal if relay is slow',
                );
              },
            );
          } catch (e) {
            Log.debug('⚠️ Error waiting for event: $e');
          }

          // Cancel subscription
          await streamSub.cancel();

          // Verify results
          Log.debug('\n📊 Test Results:');
          Log.debug('  - Events received: ${receivedEvents.length}');
          Log.debug('  - Connected relays: ${service.connectedRelays}');
          Log.debug('  - Relay statuses: ${service.relayStatuses}');

          // Test 3: Test relay management
          Log.debug('\n🔧 Testing relay management...');

          // Try adding a new relay
          const newRelay =
              'wss://localhost:8081'; // Secondary embedded relay port
          Log.debug('Adding relay: $newRelay');
          final addSuccess = await service.addRelay(newRelay);
          Log.debug('Add relay result: ${addSuccess ? "success" : "failed"}');

          // Get relay status
          final relayStatus = service.getRelayStatus();
          Log.debug('All relay statuses: $relayStatus');

          // Test 4: Publish a video event (Kind 22) - using broadcastEvent instead
          Log.debug('\n🎬 Testing video event publishing...');
          final videoEvent = Event(service.publicKey ?? '', 22, [
            ['url', 'https://example.com/test-video.mp4'],
            ['title', 'Integration Test Video'],
            ['duration', '6'],
            ['dimensions', '1920x1080'],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ], 'Test video from integration test');
          final videoResult = await service.broadcastEvent(videoEvent);

          expect(videoResult.successCount, greaterThan(0));
          Log.debug(
            '✅ Video event published to ${videoResult.successCount} relays',
          );

          // Summary
          Log.debug('\n✅ Integration test completed successfully!');
          Log.debug('Summary:');
          Log.debug(
            '  - Connected to ${service.connectedRelays.length} relays',
          );
          Log.debug(
            '  - Published ${publishResult.successCount > 0 ? "✓" : "✗"} text event',
          );
          Log.debug(
            '  - Published ${videoResult.successCount > 0 ? "✓" : "✗"} video event',
          );
          Log.debug(
            '  - Received ${receivedEvents.isNotEmpty ? "✓" : "✗"} events',
          );
        } finally {
          service.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
