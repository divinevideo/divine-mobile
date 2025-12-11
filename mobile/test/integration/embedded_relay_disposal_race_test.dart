// ABOUTME: Integration test to reproduce and fix the "Cannot add new events after calling close" race condition
// ABOUTME: Tests that embedded relay properly handles disposal while external relay events are still arriving

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Embedded Relay Disposal Race Condition', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;

    setUp(() async {
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      await keyManager.generateKeys();

      nostrService = NostrService(keyManager);
      await nostrService.initialize();
    });

    tearDown(() async {
      // Only dispose if not already disposed in test
      if (!nostrService.isDisposed) {
        await nostrService.dispose();
      }
    });

    test(
      'FAILING: should not throw "Cannot add new events after calling close" during disposal with active subscription',
      () async {
        Log.info('\n=== EMBEDDED RELAY DISPOSAL RACE TEST ===\n');

        // Step 1: Verify relay connection
        Log.info('1. Checking relay connection...');
        final connectedRelays = nostrService.connectedRelays;
        Log.info('   Connected relays: $connectedRelays');
        expect(connectedRelays, isNotEmpty);

        // Step 2: Create subscription for video events (these come frequently)
        Log.info('\n2. Creating subscription for video events...');
        final filter = Filter(
          kinds: [34236, 22], // Video event kinds
          limit: 50,
        );

        final subscription = nostrService.subscribeToEvents(filters: [filter]);

        // Step 3: Start collecting events
        Log.info('\n3. Starting event collection...');
        final events = <String>[];
        final errors = <String>[];

        // Listen for events and capture any errors
        final streamSubscription = subscription.listen(
          (event) {
            events.add(event.id);
            Log.info('   Received event: ${event.id}');
          },
          onError: (error) {
            final errorMsg = error.toString();
            errors.add(errorMsg);
            Log.error('   Stream error: $errorMsg');
          },
        );

        // Step 4: Wait briefly for events to start flowing
        await Future.delayed(Duration(milliseconds: 500));
        Log.info('   Received ${events.length} events so far');

        // Step 5: THE CRITICAL TEST - Dispose while events are actively flowing
        Log.info(
          '\n4. ⚠️ DISPOSING NostrService while external relay is still sending events...',
        );

        // This should trigger the race condition in the current implementation:
        // - dispose() closes stream controllers
        // - External relay sends more events
        // - Events try to add to closed stream
        // - ERROR: "Cannot add new events after calling close"

        try {
          await nostrService.dispose();
          Log.info('   ✅ Dispose completed successfully');
        } catch (e) {
          Log.error('   ❌ Dispose threw exception: $e');
          errors.add('Dispose exception: $e');
        }

        // Give a moment for any late errors to surface
        await Future.delayed(Duration(milliseconds: 200));

        // Cancel the stream subscription
        await streamSubscription.cancel();

        // Step 6: Verify no errors occurred
        Log.info('\n5. Verifying results...');
        Log.info('   Total events received: ${events.length}');
        Log.info('   Total errors: ${errors.length}');

        if (errors.isNotEmpty) {
          Log.error('\n   ❌ ERRORS DETECTED:');
          for (final error in errors) {
            Log.error('      - $error');
          }
        }

        // THE TEST EXPECTATION
        // This should FAIL initially because the current implementation has the race condition
        expect(
          errors
              .where(
                (e) => e.contains('Cannot add new events after calling close'),
              )
              .isEmpty,
          true,
          reason:
              'Should not have "Cannot add new events after calling close" errors during disposal',
        );

        expect(
          errors.where((e) => e.contains('Dispose exception')).isEmpty,
          true,
          reason: 'Dispose should complete without throwing exceptions',
        );

        Log.info('\n✅ TEST PASSED: No race condition errors detected');
      },
    );

    test(
      'FAILING: should handle rapid dispose-reinitialize cycles without errors',
      () async {
        Log.info(
          '\n=== RAPID DISPOSAL CYCLE TEST (simulates hot reload) ===\n',
        );

        // This test simulates what happens during hot reload:
        // 1. Service is running with active subscriptions
        // 2. Hot reload triggers dispose
        // 3. Service is immediately reinitialized
        // 4. New subscriptions are created

        final errors = <String>[];

        for (int cycle = 0; cycle < 3; cycle++) {
          Log.info('Cycle ${cycle + 1}/3');

          // Create subscription
          final filter = Filter(kinds: [34236], limit: 10);
          final subscription = nostrService.subscribeToEvents(
            filters: [filter],
          );

          // Start listening
          final streamSub = subscription.listen(
            (event) => Log.info('  Event: ${event.id}'),
            onError: (e) {
              errors.add('Cycle $cycle error: $e');
              Log.error('  Error: $e');
            },
          );

          // Let it run briefly
          await Future.delayed(Duration(milliseconds: 200));

          // Dispose (simulating hot reload)
          try {
            await nostrService.dispose();
          } catch (e) {
            errors.add('Cycle $cycle dispose error: $e');
          }

          await streamSub.cancel();

          // Reinitialize (simulating hot reload completion)
          if (cycle < 2) {
            nostrService = NostrService(keyManager);
            await nostrService.initialize();
          }

          await Future.delayed(Duration(milliseconds: 100));
        }

        Log.info('\nTotal errors across all cycles: ${errors.length}');

        expect(
          errors.where((e) => e.contains('Cannot add new events')).isEmpty,
          true,
          reason: 'Should handle rapid disposal cycles without stream errors',
        );
      },
    );
  });
}
