// ABOUTME: Simple integration test to verify we get real kind 34236 events from relay
// ABOUTME: Tests the actual pagination fix against the real OpenVine relay

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:openvine/utils/unified_logger.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real Relay Kind 34236 Events Test', () {
    test(
      'should get real kind 34236 video events from staging-relay.divine.video',
      () async {
        Log.info('🚀 Starting real relay test...', name: 'Test');

        // Create embedded relay
        final embeddedRelay = embedded.EmbeddedNostrRelay();

        // Initialize the embedded relay
        Log.info('📡 Initializing embedded relay...', name: 'Test');
        await embeddedRelay.initialize();

        // Add external relay
        Log.info(
          '🔗 Connecting to wss://staging-relay.divine.video...',
          name: 'Test',
        );
        await embeddedRelay.addExternalRelay(
          'wss://staging-relay.divine.video',
        );

        // Wait for connection to establish
        for (int i = 0; i < 20; i++) {
          final connected = embeddedRelay.connectedRelays;
          if (connected.isNotEmpty) {
            Log.info('Connected to ${connected.length} relay(s)', name: 'Test');
            break;
          }
          await Future.delayed(Duration(milliseconds: 100));
        }

        // Subscribe to kind 34236 events (NIP-71 kind 34236 addressable video events)
        Log.info('📹 Subscribing to kind 34236 events...', name: 'Test');

        // First batch - get most recent videos
        final filter1 = embedded.Filter(kinds: [34236], limit: 10);

        final events1 = <embedded.NostrEvent>[];
        final completer1 = Completer<void>();

        // Subscribe and collect events
        final subscription1 = embeddedRelay.subscribe(
          filters: [filter1],
          onEvent: (event) {
            events1.add(event);
            Log.info(
              '  Got video event: ${event.id}... created at ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}',
              name: 'Test',
            );

            // Complete after getting some events
            if (events1.length >= 5 && !completer1.isCompleted) {
              completer1.complete();
            }
          },
        );

        // Wait for events with timeout
        await completer1.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            Log.info(
              'Timeout waiting for first batch (got ${events1.length} events)',
              name: 'Test',
            );
          },
        );

        await subscription1.close();

        Log.info('✅ First batch results:', name: 'Test');
        Log.info('  Total events: ${events1.length}', name: 'Test');
        expect(
          events1,
          isNotEmpty,
          reason: 'Should get some kind 34236 events',
        );

        // Get the oldest timestamp from first batch
        if (events1.isNotEmpty) {
          final oldestTimestamp = events1
              .map((e) => e.createdAt)
              .reduce((a, b) => a < b ? a : b);
          Log.info(
            '  Oldest event: ${DateTime.fromMillisecondsSinceEpoch(oldestTimestamp * 1000)}',
            name: 'Test',
          );

          // Second batch - test pagination with 'until' parameter
          Log.info(
            '🔄 Testing pagination with until parameter...',
            name: 'Test',
          );

          final filter2 = embedded.Filter(
            kinds: [34236],
            until:
                oldestTimestamp -
                1, // Get events older than the oldest from first batch
            limit: 10,
          );

          final events2 = <embedded.NostrEvent>[];
          final completer2 = Completer<void>();

          final subscription2 = embeddedRelay.subscribe(
            filters: [filter2],
            onEvent: (event) {
              events2.add(event);
              Log.info(
                '  Got older video: ${event.id}... created at ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}',
                name: 'Test',
              );

              if (events2.length >= 3 && !completer2.isCompleted) {
                completer2.complete();
              }
            },
          );

          await completer2.future.timeout(
            Duration(seconds: 10),
            onTimeout: () {
              Log.info(
                'Timeout waiting for second batch (got ${events2.length} events)',
                name: 'Test',
              );
            },
          );

          await subscription2.close();

          Log.info('✅ Pagination results:', name: 'Test');
          Log.info(
            '  Additional older events: ${events2.length}',
            name: 'Test',
          );

          // Verify pagination worked - new events should be older
          if (events2.isNotEmpty) {
            final newestInBatch2 = events2
                .map((e) => e.createdAt)
                .reduce((a, b) => a > b ? a : b);
            expect(
              newestInBatch2,
              lessThan(oldestTimestamp),
              reason: 'Paginated events should be older than first batch',
            );
            Log.info('  ✓ Pagination working correctly!', name: 'Test');
          }
        }

        // Cleanup
        await embeddedRelay.shutdown();

        Log.info('🎉 Test completed successfully!', name: 'Test');
      },
      timeout: Timeout(Duration(seconds: 30)),
    );
  });
}
