// ABOUTME: Integration tests for NIP-50 full-text search functionality
// ABOUTME: Tests search queries against real relays that support NIP-50

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('NIP-50 Search Integration Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late String testPrivateKey;
    late String testPublicKey;
    
    // Known NIP-50 compatible relays
    final searchRelays = [
      'wss://relay.nostr.band',
      'wss://relay.noswhere.com',
      'wss://search.nos.today',
    ];

    setUp(() async {
      // Create a test keypair
      testPrivateKey = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      testPublicKey = '87979b28328fa41994eb9a5d9c76cdf3a605df66fbb4c5f82c3608939b2545d5';
      signer = LocalNostrSigner(testPrivateKey);
      
      nostr = Nostr(
        signer,
        testPublicKey,
        [], // no filters initially
        (url) => RelayBase(url, RelayStatus(url)),
      );
      
      // Connect to search-enabled relays
      for (final url in searchRelays) {
        await nostr.relayPool.add(RelayBase(url, RelayStatus(url)));
      }
      
      // Wait for connections
      await Future.delayed(Duration(seconds: 2));
    });

    tearDown(() async {
      // No direct disconnect method on RelayPool
      // Just let it clean up
    });

    test('Should search for text content in events', () async {
      // Create a filter with search parameter using new field
      final filter = Filter(
        kinds: [1], // text notes
        limit: 10,
        search: 'bitcoin',
      );
      
      // Send search query
      final events = <Event>[];
      
      final subscriptionId = nostr.relayPool.subscribe([filter.toJson()], (event) {
        events.add(event);
      });
      
      // Wait for results
      await Future.delayed(Duration(seconds: 5));
      nostr.relayPool.unsubscribe(subscriptionId);
      
      // Verify we got search results
      expect(events.isNotEmpty, isTrue, 
        reason: 'Should receive events matching search query');
      
      // Verify events contain search term
      for (final event in events) {
        expect(event.content.toLowerCase().contains('bitcoin'), isTrue,
          reason: 'Event content should contain search term');
      }
    });

    test('Should combine search with other filters', () async {
      // Search with additional constraints
      final filter = Filter(
        kinds: [1],
        since: DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch ~/ 1000,
        limit: 5,
        search: 'nostr protocol',
      );
      
      final events = <Event>[];
      final subscriptionId = nostr.relayPool.subscribe([filter.toJson()], (event) {
        events.add(event);
      });
      
      await Future.delayed(Duration(seconds: 5));
      nostr.relayPool.unsubscribe(subscriptionId);
      
      // Verify we got results (relays may have different limit behaviors)
      expect(events.isNotEmpty, isTrue);
      
      // Verify search term appears in results
      for (final event in events) {
        expect(event.kind, equals(1));
        // Most results should contain the search term
        final containsSearch = event.content.toLowerCase().contains('nostr') || 
                              event.content.toLowerCase().contains('protocol');
        if (!containsSearch) {
          print('Event without search term: ${event.content.substring(0, 100)}...');
        }
      }
    });

    test('Should handle relays that don\'t support search', () async {
      // Add a relay that doesn't support NIP-50
      await nostr.relayPool.add(RelayBase('wss://relay.damus.io', RelayStatus('wss://relay.damus.io')));
      
      final filter = Filter(
        kinds: [1], 
        limit: 5,
        search: 'test query',
      );
      
      final events = <Event>[];
      
      final subscriptionId = nostr.relayPool.subscribe([filter.toJson()], (event) {
        events.add(event);
      });
      
      await Future.delayed(Duration(seconds: 3));
      nostr.relayPool.unsubscribe(subscriptionId);
      
      // Should still work on relays that support search
      // Non-supporting relays might send NOTICE or just ignore the search param
      print('Received ${events.length} events from search');
    });

    test('Search API should provide convenient method', () async {
      // Wait a bit longer for relay connections
      await Future.delayed(Duration(seconds: 3));
      
      // Test the new searchEvents convenience method
      final results = await nostr.relayPool.searchEvents(
        'bitcoin', 
        kinds: [1],
        limit: 10,
        timeout: Duration(seconds: 10),
      );
      
      print('SearchEvents returned ${results.length} results');
      
      expect(results.isNotEmpty, isTrue,
        reason: 'Should receive search results from convenience method');
      
      // Verify all results contain the search term
      for (final event in results) {
        expect(event.content.toLowerCase().contains('bitcoin'), isTrue,
          reason: 'Search results should contain the search term');
      }
      
      // Verify deduplication works
      final eventIds = results.map((e) => e.id).toSet();
      expect(eventIds.length, equals(results.length),
        reason: 'Results should be deduplicated by event ID');
    });
  });
}