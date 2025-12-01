// ABOUTME: Unit tests for NIP-50 search field in Filter class
// ABOUTME: Tests serialization and deserialization of search parameter

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('Filter Search Tests', () {
    test('Should serialize search field to JSON', () {
      final filter = Filter(
        kinds: [1],
        limit: 10,
        search: 'bitcoin',
      );
      
      final json = filter.toJson();
      
      expect(json['search'], equals('bitcoin'));
      expect(json['kinds'], equals([1]));
      expect(json['limit'], equals(10));
    });

    test('Should deserialize search field from JSON', () {
      final json = {
        'kinds': [1],
        'limit': 20,
        'search': 'nostr protocol',
      };
      
      final filter = Filter.fromJson(json);
      
      expect(filter.search, equals('nostr protocol'));
      expect(filter.kinds, equals([1]));
      expect(filter.limit, equals(20));
    });

    test('Should handle null search field', () {
      final filter = Filter(
        kinds: [1],
        limit: 10,
      );
      
      final json = filter.toJson();
      
      expect(json.containsKey('search'), isFalse);
    });

    test('Should serialize complex search queries', () {
      final filter = Filter(
        kinds: [1, 30023],
        authors: ['pubkey1', 'pubkey2'],
        search: 'bitcoin AND lightning OR "layer 2"',
        since: 1234567890,
        until: 1234567999,
        limit: 50,
      );
      
      final json = filter.toJson();
      
      expect(json['search'], equals('bitcoin AND lightning OR "layer 2"'));
      expect(json['kinds'], equals([1, 30023]));
      expect(json['authors'], equals(['pubkey1', 'pubkey2']));
      expect(json['since'], equals(1234567890));
      expect(json['until'], equals(1234567999));
      expect(json['limit'], equals(50));
    });

    test('Round trip serialization preserves search field', () {
      final originalFilter = Filter(
        kinds: [1],
        search: 'test search query',
        limit: 25,
      );
      
      final json = originalFilter.toJson();
      final deserializedFilter = Filter.fromJson(json);
      
      expect(deserializedFilter.search, equals(originalFilter.search));
      expect(deserializedFilter.kinds, equals(originalFilter.kinds));
      expect(deserializedFilter.limit, equals(originalFilter.limit));
    });
  });
}