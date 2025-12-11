// ABOUTME: Integration test for NostrServiceV2 event reception
// ABOUTME: Tests actual connection to relay and event subscription

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import '../helpers/real_integration_test_helper.dart';

void main() {
  group('NostrServiceV2 Integration', () {
    test('receives events from relay', () async {
      // Setup test environment with platform channel mocks
      await RealIntegrationTestHelper.setupTestEnvironment();

      // Create real key manager
      final keyManager = NostrKeyManager();
      await keyManager.initialize();

      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      // Create service
      final service = NostrService(keyManager);

      try {
        // Initialize service
        await service.initialize();

        expect(service.isInitialized, true);
        expect(service.connectedRelays.isNotEmpty, true);

        // Create subscription for video events
        final filter = Filter(
          kinds: [34236], // Addressable video events (kind 34236)
          limit: 5,
        );

        final eventStream = service.subscribeToEvents(filters: [filter]);

        // Collect events for 3 seconds (embedded relay should respond quickly)
        final events = <dynamic>[];
        final subscription = eventStream.listen((event) {
          events.add(event);
          Log.debug('Received event: ${event.kind} - ${event.id}...');
        });

        // Wait for events using proper async pattern instead of arbitrary delay
        final completer = Completer<void>();
        Timer(const Duration(seconds: 3), () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        });

        // Also complete early if we get events
        if (events.isNotEmpty) {
          Timer(const Duration(milliseconds: 100), () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        }

        await completer.future;

        // Cancel subscription
        await subscription.cancel();

        // Should have received at least one event
        expect(
          events.isNotEmpty,
          true,
          reason: 'Should receive at least one event from relay',
        );

        if (events.isNotEmpty) {
          Log.debug('✅ Received ${events.length} events');
        }
      } finally {
        service.dispose();
      }
    });
  });
}
