import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/filter.dart';

void main() {
  group('Subscription Deduplication via Filter Hashing', () {
    // Helper function to generate filter hash (same logic as in NostrService)
    String generateFilterHash(List<Filter> filters) {
      final parts = <String>[];

      for (final filter in filters) {
        final filterParts = <String>[];

        if (filter.kinds != null && filter.kinds!.isNotEmpty) {
          final sortedKinds = List<int>.from(filter.kinds!)..sort();
          filterParts.add('k:${sortedKinds.join(",")}');
        }

        if (filter.authors != null && filter.authors!.isNotEmpty) {
          final sortedAuthors = List<String>.from(filter.authors!)..sort();
          filterParts.add('a:${sortedAuthors.join(",")}');
        }

        if (filter.since != null) filterParts.add('s:${filter.since}');
        if (filter.until != null) filterParts.add('u:${filter.until}');
        if (filter.limit != null) filterParts.add('l:${filter.limit}');

        if (filter.t != null && filter.t!.isNotEmpty) {
          final sortedTags = List<String>.from(filter.t!)..sort();
          filterParts.add('t:${sortedTags.join(",")}');
        }

        parts.add(filterParts.join('|'));
      }

      final filterString = parts.join('||');
      var hash = 0;
      for (var i = 0; i < filterString.length; i++) {
        hash = ((hash << 5) - hash) + filterString.codeUnitAt(i);
        hash = hash & 0xFFFFFFFF;
      }
      return hash.abs().toString();
    }

    test('identical filters should generate same subscription ID', () {
      final filter1 = Filter(
        kinds: [34236],
        authors: ['pubkey1', 'pubkey2'],
        limit: 100,
      );

      final filter2 = Filter(
        kinds: [34236],
        authors: ['pubkey1', 'pubkey2'],
        limit: 100,
      );

      final hash1 = generateFilterHash([filter1]);
      final hash2 = generateFilterHash([filter2]);

      expect(
        hash1,
        equals(hash2),
        reason: 'Identical filters should generate the same hash',
      );
    });

    test('different filters should generate different subscription IDs', () {
      final filter1 = Filter(kinds: [34236], authors: ['pubkey1'], limit: 100);

      final filter2 = Filter(
        kinds: [34236],
        authors: ['pubkey2'], // Different author
        limit: 100,
      );

      final hash1 = generateFilterHash([filter1]);
      final hash2 = generateFilterHash([filter2]);

      expect(
        hash1,
        isNot(equals(hash2)),
        reason: 'Different filters should generate different hashes',
      );
    });

    test('filter order should not affect hash', () {
      final filter1 = Filter(
        kinds: [34236, 16], // Order 1
        authors: ['pubkey1', 'pubkey2', 'pubkey3'],
        t: ['hashtag1', 'hashtag2'],
      );

      final filter2 = Filter(
        kinds: [16, 34236], // Order 2 (reversed)
        authors: ['pubkey3', 'pubkey1', 'pubkey2'], // Different order
        t: ['hashtag2', 'hashtag1'], // Different order
      );

      final hash1 = generateFilterHash([filter1]);
      final hash2 = generateFilterHash([filter2]);

      expect(
        hash1,
        equals(hash2),
        reason: 'Filter element order should not affect the hash',
      );
    });

    test('multiple discovery subscriptions should use same ID', () {
      // Simulate what happens when multiple UI components request discovery feed
      final discoveryFilter = Filter(kinds: [34236], limit: 100);

      // Multiple calls with same filter (as from different UI components)
      final hash1 = generateFilterHash([discoveryFilter]);
      final hash2 = generateFilterHash([discoveryFilter]);
      final hash3 = generateFilterHash([discoveryFilter]);

      expect(hash1, equals(hash2));
      expect(hash2, equals(hash3));

      // They would all map to same subscription ID
      final subId1 = 'sub_$hash1';
      final subId2 = 'sub_$hash2';
      final subId3 = 'sub_$hash3';

      expect(subId1, equals(subId2));
      expect(subId2, equals(subId3));
    });

    test('home feed with same following list should use same ID', () {
      final followingList = ['user1', 'user2', 'user3', 'user4', 'user5'];

      final homeFeedFilter1 = Filter(
        kinds: [34236],
        authors: followingList,
        limit: 100,
      );

      final homeFeedFilter2 = Filter(
        kinds: [34236],
        authors: List.from(followingList), // Copy of same list
        limit: 100,
      );

      final hash1 = generateFilterHash([homeFeedFilter1]);
      final hash2 = generateFilterHash([homeFeedFilter2]);

      expect(
        hash1,
        equals(hash2),
        reason:
            'Same home feed parameters should generate same subscription ID',
      );
    });

    test('changing limit should create different subscription', () {
      final filter1 = Filter(kinds: [34236], authors: ['pubkey1'], limit: 50);

      final filter2 = Filter(
        kinds: [34236],
        authors: ['pubkey1'],
        limit: 100, // Different limit
      );

      final hash1 = generateFilterHash([filter1]);
      final hash2 = generateFilterHash([filter2]);

      expect(
        hash1,
        isNot(equals(hash2)),
        reason: 'Different limits should generate different subscription IDs',
      );
    });

    test('adding time constraints should create different subscription', () {
      final filter1 = Filter(kinds: [34236], authors: ['pubkey1'], limit: 100);

      final filter2 = Filter(
        kinds: [34236],
        authors: ['pubkey1'],
        limit: 100,
        since: 1234567890, // Added time constraint
      );

      final hash1 = generateFilterHash([filter1]);
      final hash2 = generateFilterHash([filter2]);

      expect(
        hash1,
        isNot(equals(hash2)),
        reason:
            'Adding time constraints should generate different subscription IDs',
      );
    });
  });
}
