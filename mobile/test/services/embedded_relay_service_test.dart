// ABOUTME: Tests for NostrService - embedded relay implementation
// ABOUTME: Verifies initialization, video event subscriptions, and publishing

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;

void main() {
  // Initialize Flutter bindings for tests that use platform channels
  TestWidgetsFlutterBinding.ensureInitialized();

  // Enable test mode for embedded relay to use in-memory database
  embedded.DatabaseHelper.enableTestMode();

  group('NostrService', () {
    late NostrService service;
    late NostrKeyManager keyManager;

    setUp(() {
      keyManager = NostrKeyManager();
      service = NostrService(keyManager);
    });

    tearDown(() async {
      if (service.isInitialized) {
        service.dispose();
      }
    });

    group('Initialization', () {
      test('should initialize embedded relay successfully', () async {
        expect(service.isInitialized, false);

        await service.initialize();

        expect(service.isInitialized, true);
        expect(service.isDisposed, false);
        expect(service.primaryRelay, 'ws://localhost:7447');
        expect(service.connectedRelays, contains('ws://localhost:7447'));
      });

      test('should handle multiple initialize calls gracefully', () async {
        await service.initialize();
        expect(service.isInitialized, true);

        // Second call should not throw
        await service.initialize();
        expect(service.isInitialized, true);
      });

      test(
        'should initialize with OpenVine video-optimized configuration',
        () async {
          await service.initialize();

          // Verify configuration is set for video optimization
          expect(service.isInitialized, true);

          // Should be ready to handle video events (kind 34236)
          final stats = await service.getRelayStats();
          expect(stats, isNotNull);
        },
      );
    });

    group('Video Event Subscriptions', () {
      setUp(() async {
        await service.initialize();
      });

      test('should subscribe to video events (kind 34236)', () async {
        bool receivedEvent = false;
        Event? capturedEvent;

        // Subscribe to video events
        final stream = service.subscribeToEvents(
          filters: [
            Filter(kinds: [34236]),
          ],
        );

        stream.listen((event) {
          receivedEvent = true;
          capturedEvent = event;
        });

        // Create a test video event
        final testEvent = Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': [
            ['url', 'https://example.com/video.mp4'],
            ['title', 'Test Video'],
          ],
          'content': 'Test video description',
          'sig': 'test_signature',
        });

        // Publish the event
        final result = await service.broadcastEvent(testEvent);

        expect(result.isSuccessful, true);

        // Wait for event to be processed
        await Future.delayed(Duration(milliseconds: 100));

        expect(receivedEvent, true);
        expect(capturedEvent?.kind, 34236);
        expect(capturedEvent?.content, 'Test video description');
      });

      test('should handle subscription to home feed (following)', () async {
        final followedPubkey = 'followed_user_pubkey';

        // Subscribe to events from followed users
        final stream = service.subscribeToEvents(
          filters: [
            Filter(kinds: [34236], authors: [followedPubkey]),
          ],
        );

        bool receivedEvent = false;
        stream.listen((event) {
          receivedEvent = true;
        });

        // Publish event from followed user
        final followedUserEvent = Event.fromJson({
          'id': 'followed_event_id',
          'pubkey': followedPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': [],
          'content': 'Video from followed user',
          'sig': 'test_signature',
        });

        await service.broadcastEvent(followedUserEvent);
        await Future.delayed(Duration(milliseconds: 100));

        expect(receivedEvent, true);
      });
    });

    group('Event Broadcasting', () {
      setUp(() async {
        await service.initialize();
      });

      test('should broadcast video events to embedded relay', () async {
        final testEvent = Event.fromJson({
          'id': 'broadcast_test_id',
          'pubkey': 'test_pubkey',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': [
            ['url', 'https://example.com/test-video.mp4'],
            ['blurhash', 'test-blurhash'],
          ],
          'content': 'Broadcasting test video',
          'sig': 'test_signature',
        });

        final result = await service.broadcastEvent(testEvent);

        expect(result, isNotNull);
        expect(result.isSuccessful, true);
        expect(result.successCount, 1);
        expect(result.totalRelays, 1);
        expect(result.successfulRelays, contains('ws://localhost:7447'));
      });
    });

    group('Relay Management', () {
      setUp(() async {
        await service.initialize();
      });

      test('should report correct relay status', () async {
        final status = service.getRelayStatus();

        expect(status, isNotEmpty);
        expect(status['ws://localhost:7447'], true);
      });

      test(
        'should handle external relay addition for discoverability',
        () async {
          final externalRelay = 'wss://example-relay.com';

          final added = await service.addRelay(externalRelay);

          expect(added, true);
          expect(service.relays, contains(externalRelay));
        },
      );
    });

    group('Performance', () {
      setUp(() async {
        await service.initialize();
      });

      test('should achieve sub-100ms query response times', () async {
        // Publish some test events first
        for (int i = 0; i < 10; i++) {
          final event = Event.fromJson({
            'id': 'perf_test_$i',
            'pubkey': 'test_pubkey',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 34236,
            'tags': [],
            'content': 'Performance test video $i',
            'sig': 'test_signature',
          });

          await service.broadcastEvent(event);
        }

        // Measure query time
        final stopwatch = Stopwatch()..start();

        final stream = service.subscribeToEvents(
          filters: [
            Filter(kinds: [34236], limit: 10),
          ],
        );

        int eventCount = 0;
        await for (final _ in stream.take(10)) {
          eventCount++;
          if (eventCount >= 10) break;
        }

        stopwatch.stop();

        // Should be much faster than 100ms (target <10ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(eventCount, 10);
      });
    });

    group('Cleanup', () {
      test('should dispose cleanly', () async {
        await service.initialize();
        expect(service.isInitialized, true);

        service.dispose();

        expect(service.isDisposed, true);
        expect(service.isInitialized, false);
      });
    });
  });
}
