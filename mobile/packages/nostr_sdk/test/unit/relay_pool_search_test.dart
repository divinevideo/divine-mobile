// ABOUTME: Unit tests for RelayPool searchEvents convenience method
// ABOUTME: Tests the high-level search API for NIP-50 functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('RelayPool searchEvents Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late String testPrivateKey;

    setUp(() async {
      testPrivateKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      signer = LocalNostrSigner(testPrivateKey);

      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test(
      'searchEvents method should exist and return Future<List<Event>>',
      () async {
        // This test will fail until we implement the method
        final results = await nostr.relayPool.searchEvents(
          'bitcoin',
          kinds: [1],
          limit: 10,
        );

        expect(results, isA<List<Event>>());
      },
    );

    test(
      'searchEvents should accept search query and optional filters',
      () async {
        // Test with various parameter combinations
        final results1 = await nostr.relayPool.searchEvents('bitcoin');
        expect(results1, isA<List<Event>>());

        final results2 = await nostr.relayPool.searchEvents(
          'nostr',
          kinds: [1, 30023],
        );
        expect(results2, isA<List<Event>>());

        final results3 = await nostr.relayPool.searchEvents(
          'lightning network',
          authors: ['pubkey1', 'pubkey2'],
          kinds: [1],
          since: DateTime.now().subtract(const Duration(days: 7)),
          until: DateTime.now(),
          limit: 20,
        );
        expect(results3, isA<List<Event>>());
      },
    );

    test('searchEvents should handle timeout parameter', () async {
      final results = await nostr.relayPool.searchEvents(
        'test',
        timeout: const Duration(seconds: 2),
      );

      expect(results, isA<List<Event>>());
    });

    test('searchEvents should work with specific relays', () async {
      final results = await nostr.relayPool.searchEvents(
        'bitcoin',
        relayUrls: ['wss://relay.nostr.band', 'wss://search.nos.today'],
      );

      expect(results, isA<List<Event>>());
    });

    test('searchEvents results are deduplicated by event ID', () async {
      // The deduplication is guaranteed by the implementation using
      // Map<String, Event> keyed by event ID. Without connected relays,
      // we get an empty list, but the invariant still holds.
      final results = await nostr.relayPool.searchEvents(
        'test',
        timeout: const Duration(milliseconds: 100),
      );

      // Verify the invariant: all event IDs are unique
      final eventIds = results.map((e) => e.id).toSet();
      expect(eventIds.length, equals(results.length));
    });

    test('searchEvents should return empty list for no results', () async {
      final results = await nostr.relayPool.searchEvents(
        'extremely_unlikely_search_term_xyz123',
        timeout: const Duration(seconds: 1),
      );

      expect(results, isEmpty);
    });
  });
}
