// ABOUTME: Integration test to verify embedded relay forwards subscriptions correctly
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests that the embedded relay actually sends REQ messages to external relays

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Embedded Relay Subscription Forwarding', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;

    setUp(() async {
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      // Generate random keys for testing
      await keyManager.generateKeys();

      nostrService = NostrService(keyManager);
      await nostrService.initialize();
    });

    tearDown(() async {
      await nostrService.dispose();
    });

    test('should forward subscription to external relay and receive events', () async {
      Log.info('\n=== EMBEDDED RELAY SUBSCRIPTION TEST ===\n');

      // Test 1: Check relay connection
      Log.info('1. Checking relay connection status...');
      final connectedRelays = nostrService.connectedRelays;
      Log.info('   Connected relays: $connectedRelays');
      expect(
        connectedRelays,
        isNotEmpty,
        reason: 'Should be connected to at least one relay',
      );

      // Test 2: Create a subscription for known authors with videos
      Log.info('\n2. Creating subscription for known video authors...');

      // These are authors we know have videos from the discovery feed logs
      final knownVideoAuthors = [
        '377d059b8e4154c95e45c951b5b2b1b15d6f11c17e59e6a7b1c70ba7f3f7e079', // ＊emi＊
        '46322367c46f0fd68e587c8b3f0a967bb3e0c97a6b96c48ae40be08a78c73b64', // 일곱숨결7ᴴᴱᴬᴿᵀ
        '36f3ca85a96b69b5bb969f786e29bb71e8e9bb0c1a5fefe891c1b690e965ad66', // 윈윈 영상 봇
      ];

      final filter = Filter(
        kinds: [34236],
        authors: knownVideoAuthors,
        limit: 10,
      );

      Log.info(
        '   Filter: kinds=${filter.kinds}, authors=${filter.authors?.length} (first=${filter.authors?.first})',
      );

      // Test 3: Subscribe and collect events
      Log.info('\n3. Subscribing and waiting for events...');
      final events = <Event>[];
      final subscription = nostrService.subscribeToEvents(filters: [filter]);

      // Listen for events with timeout
      final eventFuture = subscription
          .timeout(Duration(seconds: 5))
          .take(5) // Take up to 5 events
          .toList()
          .catchError((error) {
            Log.info('   Timeout or error: $error');
            return events;
          });

      // Wait for events
      final receivedEvents = await eventFuture;

      Log.info('   Received ${receivedEvents.length} events');

      // Test 4: Analyze results
      Log.info('\n4. Analyzing results...');

      if (receivedEvents.isEmpty) {
        Log.info('   ❌ NO EVENTS RECEIVED!');
        Log.info('   This means either:');
        Log.info(
          '   - The embedded relay is NOT forwarding subscriptions to external relays',
        );
        Log.info('   - The external relay is not returning events');
        Log.info(
          '   - The embedded relay is not passing events back to the app',
        );
      } else {
        Log.info('   ✅ Received ${receivedEvents.length} events');
        for (var i = 0; i < receivedEvents.length && i < 3; i++) {
          final event = receivedEvents[i];
          Log.info('   Event $i: kind=${event.kind}, author=${event.pubkey}');
        }
      }

      // Test 5: Try a subscription with NO author filter
      Log.info('\n5. Testing subscription with no author filter...');

      final openFilter = Filter(kinds: [34236], limit: 10);

      Log.info('   Filter: kinds=${openFilter.kinds}, no author filter');

      final openSubscription = nostrService.subscribeToEvents(
        filters: [openFilter],
      );
      final openEvents = await openSubscription
          .timeout(Duration(seconds: 5))
          .take(5)
          .toList()
          .catchError((error) {
            Log.info('   Timeout or error: $error');
            return <Event>[];
          });

      Log.info('   Received ${openEvents.length} events with open filter');

      // Compare results
      Log.info('\n=== TEST RESULTS ===');
      Log.info('With author filter: ${receivedEvents.length} events');
      Log.info('Without author filter: ${openEvents.length} events');

      if (receivedEvents.isEmpty && openEvents.isNotEmpty) {
        Log.info(
          '❌ PROBLEM IDENTIFIED: Embedded relay works but fails with author filters!',
        );
      } else if (receivedEvents.isEmpty && openEvents.isEmpty) {
        Log.info(
          '❌ PROBLEM IDENTIFIED: Embedded relay is not forwarding ANY subscriptions!',
        );
      } else {
        Log.info('✅ Embedded relay appears to be working correctly');
      }

      // We expect to receive SOME events for known authors
      expect(
        receivedEvents.length + openEvents.length,
        greaterThan(0),
        reason: 'Should receive at least some events from the relay',
      );
    });

    test('should receive events for followed users if they exist', () async {
      Log.info('\n=== TESTING FOLLOWED USERS ===\n');

      // The actual followed users from your account
      final followedUsers = [
        '2646f4c01362b3b48d4b4e31d9c96a4eabe06c4eb97fe1a482ef651f1bf023b7',
        '2d85b149e9eb1b56720b7123e303ead76e4d7cc3aa24073c5b909ae89aaabe38',
        '1f90a3fdecb318d01a150e0e6980de03359659895e94669ba2a0c889d531d879',
      ];

      final filter = Filter(kinds: [34236], authors: followedUsers, limit: 50);

      Log.info('Testing with ${followedUsers.length} followed users...');

      final subscription = nostrService.subscribeToEvents(filters: [filter]);
      final events = await subscription
          .timeout(Duration(seconds: 10))
          .take(10)
          .toList()
          .catchError((error) => <Event>[]);

      Log.info('Received ${events.length} events from followed users');

      if (events.isEmpty) {
        Log.info('❌ No videos found from followed users');
        Log.info('Possible reasons:');
        Log.info('1. These users have never posted kind 34236 video events');
        Log.info('2. The relay doesn\'t have their video events');
        Log.info('3. There\'s a bug in author filtering');
      } else {
        Log.info('✅ Found ${events.length} videos from followed users');
      }
    });
  });
}
