#!/usr/bin/env dart
// ABOUTME: Direct test script to debug embedded relay subscription forwarding
// ABOUTME: Tests whether the embedded relay properly forwards REQ messages to external relays

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:openvine/utils/unified_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.info(
    '\n=== EMBEDDED RELAY DIRECT TEST ===\n',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  // Initialize embedded relay
  Log.info(
    '1. Initializing embedded relay...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  final embeddedRelay = embedded.EmbeddedNostrRelay();
  await embeddedRelay.initialize(enableGarbageCollection: true);
  Log.info(
    '   ✅ Embedded relay initialized',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  // Add external relay
  Log.info(
    '\n2. Adding external relay...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  const relayUrl = 'wss://relay3.openvine.co';
  await embeddedRelay.addExternalRelay(relayUrl);
  Log.info(
    '   ✅ Added relay: $relayUrl',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  // Check connection status
  Log.info(
    '\n3. Checking connection status...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  final connectedRelays = embeddedRelay.connectedRelays;
  Log.info(
    '   Connected relays: $connectedRelays',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  if (!connectedRelays.contains(relayUrl)) {
    Log.info(
      '   ⚠️ WARNING: Not connected to $relayUrl yet',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      '   Waiting 2 seconds for connection...',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    await Future.delayed(Duration(seconds: 2));
    final connectedRelaysAfter = embeddedRelay.connectedRelays;
    Log.info(
      '   Connected relays after wait: $connectedRelaysAfter',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  }

  // Test 1: Query with NO author filter (should work)
  Log.info(
    '\n4. Testing query with NO author filter...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  final openFilter = embedded.Filter(
    kinds: [32222], // Video events
    limit: 5,
  );

  final openEvents = await embeddedRelay.queryEvents([openFilter]);
  Log.info(
    '   Received ${openEvents.length} events with open filter',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  if (openEvents.isNotEmpty) {
    Log.info(
      '   ✅ Open filter works - relay is responding',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      '   First event author: ${openEvents.first.pubkey.substring(0, 8)}...',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  } else {
    Log.info(
      '   ❌ No events received with open filter',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  }

  // Test 2: Query with specific author filter
  Log.info(
    '\n5. Testing query with specific author filter...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  // Use authors we know have videos from the logs
  final knownAuthors = [
    '377d059b8e4154c95e45c951b5b2b1b15d6f11c17e59e6a7b1c70ba7f3f7e079', // ＊emi＊
    '46322367c46f0fd68e587c8b3f0a967bb3e0c97a6b96c48ae40be08a78c73b64', // 일곱숨결7ᴴᴱᴬᴿᵀ
  ];

  final authorFilter = embedded.Filter(
    kinds: [32222],
    authors: knownAuthors,
    limit: 10,
  );

  final authorEvents = await embeddedRelay.queryEvents([authorFilter]);
  Log.info(
    '   Received ${authorEvents.length} events with author filter',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  if (authorEvents.isNotEmpty) {
    Log.info(
      '   ✅ Author filter works',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    for (var i = 0; i < authorEvents.length && i < 3; i++) {
      Log.info(
        '   Event $i: author=${authorEvents[i].pubkey.substring(0, 8)}...',
        name: 'EmbeddedRelayTest',
        category: LogCategory.relay,
      );
    }
  } else {
    Log.info(
      '   ❌ No events received with author filter',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  }

  // Test 3: Create a subscription and see if it gets events
  Log.info(
    '\n6. Testing subscription (REQ message)...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  final subscriptionId = 'test_sub_${DateTime.now().millisecondsSinceEpoch}';
  var receivedCount = 0;
  final completer = Completer<void>();

  Log.info(
    '   Creating subscription with ID: $subscriptionId',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  final subscription = embeddedRelay.subscribe(
    subscriptionId: subscriptionId,
    filters: [
      embedded.Filter(kinds: [32222], limit: 5),
    ],
    onEvent: (event) {
      receivedCount++;
      Log.info(
        '   📨 Received event $receivedCount: kind=${event.kind}, author=${event.pubkey.substring(0, 8)}...',
        name: 'EmbeddedRelayTest',
        category: LogCategory.relay,
      );
      if (receivedCount >= 3 && !completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (error) {
      Log.info(
        '   ❌ Subscription error: $error',
        name: 'EmbeddedRelayTest',
        category: LogCategory.relay,
      );
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    },
  );

  // Wait for events with timeout
  try {
    await completer.future.timeout(Duration(seconds: 5));
    Log.info(
      '   ✅ Subscription received $receivedCount events',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  } catch (e) {
    if (e is TimeoutException) {
      Log.info(
        '   ⏱️ Timeout after 5 seconds - received $receivedCount events',
        name: 'EmbeddedRelayTest',
        category: LogCategory.relay,
      );
    } else {
      Log.info(
        '   ❌ Error: $e',
        name: 'EmbeddedRelayTest',
        category: LogCategory.relay,
      );
    }
  }

  subscription.close();

  // Test 4: Test with the actual followed users
  Log.info(
    '\n7. Testing with actual followed users from home feed...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  final followedUsers = [
    '2646f4c01362b3b48d4b4e31d9c96a4eabe06c4eb97fe1a482ef651f1bf023b7',
    '2d85b149e9eb1b56720b7123e303ead76e4d7cc3aa24073c5b909ae89aaabe38',
    '1f90a3fdecb318d01a150e0e6980de03359659895e94669ba2a0c889d531d879',
    '4a88417a9502445bbdae41c2e7fc9289dd1e8c5cbcc8e6c2a2e2f5f38b5ac5f4',
    'f3c4705c2539f244b35df1f8e5c76c5e1dee0f68f07eee7bc959177f604b16bd',
    'e47336b1b91a97dd2c88e4c2f6d9d396837c96577f3e69f84b5fc088f06faaef',
    'cb1e36bb7f690c92b8aac951c7fd1c5ad90e8c45e037c8c37a951e39cfbcb9a7',
    '4f62e079b8e44cffe1173ea87e90e604c8c92e5e93e7c616e3e9fff10f98e23a',
    '032a9cf96e1965f3f96a13bb6e8f4c6b5a1c7e17c973d6e3bc674cc91bbf4f69',
  ];

  final followedFilter = embedded.Filter(
    kinds: [32222],
    authors: followedUsers,
    limit: 50,
  );

  Log.info(
    '   Querying for videos from ${followedUsers.length} followed users...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  final followedEvents = await embeddedRelay.queryEvents([followedFilter]);
  Log.info(
    '   Received ${followedEvents.length} events from followed users',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  if (followedEvents.isEmpty) {
    Log.info(
      '   ❌ No videos found from followed users',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      '   This confirms the issue - these users should have videos!',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  } else {
    Log.info(
      '   ✅ Found videos from followed users',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    // Group by author
    final eventsByAuthor = <String, int>{};
    for (final event in followedEvents) {
      eventsByAuthor[event.pubkey] = (eventsByAuthor[event.pubkey] ?? 0) + 1;
    }
    Log.info(
      '   Videos per author:',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    eventsByAuthor.forEach((pubkey, count) {
      Log.info(
        '     ${pubkey.substring(0, 8)}...: $count videos',
        name: 'EmbeddedRelayTest',
        category: LogCategory.relay,
      );
    });
  }

  // Clean up
  Log.info(
    '\n8. Shutting down...',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  await embeddedRelay.shutdown();
  Log.info(
    '   ✅ Embedded relay shut down',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  Log.info(
    '\n=== TEST COMPLETE ===\n',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  // Summary
  Log.info('SUMMARY:', name: 'EmbeddedRelayTest', category: LogCategory.relay);
  Log.info(
    '- Open query (no filter): ${openEvents.length} events',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  Log.info(
    '- Known authors query: ${authorEvents.length} events',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  Log.info(
    '- Subscription received: $receivedCount events',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );
  Log.info(
    '- Followed users query: ${followedEvents.length} events',
    name: 'EmbeddedRelayTest',
    category: LogCategory.relay,
  );

  if (followedEvents.isEmpty && openEvents.isNotEmpty) {
    Log.info(
      '\n❌ PROBLEM CONFIRMED: Embedded relay works but fails with specific author filters!',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      'This suggests the issue is either:',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      '1. The followed users have no videos on the relay',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      '2. There\'s a bug in author filtering in the embedded relay',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
    Log.info(
      '3. The relay is not properly querying external relays with author filters',
      name: 'EmbeddedRelayTest',
      category: LogCategory.relay,
    );
  }

  exit(0);
}
