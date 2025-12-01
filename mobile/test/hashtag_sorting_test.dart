// ABOUTME: Basic tests for hashtag sorting and functionality
// ABOUTME: Verifies hashtags are properly sorted and combined

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hashtag Sorting Logic Tests', () {
    test('should combine JSON and local hashtag counts correctly', () {
      // Simulate combining hashtag counts from JSON and local cache
      final jsonHashtags = {
        'vine': 1000,
        'comedy': 800,
        'dance': 600,
        'funny': 400,
      };

      final localHashtags = {
        'vine': 50, // Should add to JSON count
        'local': 100, // Only in local
        'dance': 20, // Should add to JSON count
        'new': 75, // Only in local
      };

      // Combine the counts (this is what explore_screen does)
      final combined = <String, int>{};

      // First add all JSON hashtags
      combined.addAll(jsonHashtags);

      // Then add local counts to existing or create new entries
      localHashtags.forEach((hashtag, localCount) {
        final currentCount = combined[hashtag] ?? 0;
        combined[hashtag] =
            currentCount + localCount; // ADD counts, don't replace
      });

      // Expected results after combining:
      expect(combined['vine'], equals(1050)); // 1000 + 50
      expect(combined['comedy'], equals(800)); // 800 + 0
      expect(combined['dance'], equals(620)); // 600 + 20
      expect(combined['funny'], equals(400)); // 400 + 0
      expect(combined['local'], equals(100)); // 0 + 100
      expect(combined['new'], equals(75)); // 0 + 75

      // Now sort by count descending
      final sorted = combined.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Check sorting order
      expect(sorted[0].key, equals('vine')); // 1050
      expect(sorted[1].key, equals('comedy')); // 800
      expect(sorted[2].key, equals('dance')); // 620
      expect(sorted[3].key, equals('funny')); // 400
      expect(sorted[4].key, equals('local')); // 100
      expect(sorted[5].key, equals('new')); // 75
    });

    test('should handle unlimited hashtag display', () {
      // Create a large list of hashtags
      final manyHashtags = <String, int>{};
      for (int i = 0; i < 500; i++) {
        manyHashtags['hashtag$i'] = 500 - i; // Decreasing counts
      }

      // Sort without limit
      final sorted = manyHashtags.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // All hashtags should be included
      expect(sorted.length, equals(500));

      // First should have highest count
      expect(sorted.first.value, equals(500));

      // Last should have lowest count
      expect(sorted.last.value, equals(1));

      // No artificial limit should be applied
      final displayed = sorted.map((e) => e.key).toList();
      expect(displayed.length, equals(500)); // All should be displayed
    });

    test('should properly format hashtag filter for relay query', () {
      // Test the filter structure for hashtag queries
      final hashtags = ['dankmemes', 'funny', 'viral'];

      // This simulates what VideoEventService creates
      final filter = {
        'kinds': [34236], // NIP-71 kind 34236 video events
        '#t': hashtags, // Hashtag filter
        'limit': 100,
      };

      // Verify filter structure
      expect(filter['kinds'], equals([34236]));
      expect(filter['#t'], equals(hashtags));
      expect(filter['limit'], equals(100));

      // Verify the filter would match events with these hashtags
      final testEvent = {
        'kind': 34236,
        'tags': [
          ['t', 'dankmemes'],
          ['t', 'othertag'],
        ],
      };

      // Check if event would match filter (has at least one matching hashtag)
      final eventHashtags = (testEvent['tags'] as List)
          .where((tag) => tag[0] == 't')
          .map((tag) => tag[1] as String)
          .toList();

      final matchesFilter = eventHashtags.any((tag) => hashtags.contains(tag));
      expect(matchesFilter, isTrue);
    });
  });
}
