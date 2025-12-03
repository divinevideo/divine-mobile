// ABOUTME: Tests that search results are sorted correctly
// ABOUTME: New vines (no loops) chronologically, then original vines by loop count

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('Search results sorting', () {
    test(
      'sorts new vines chronologically before original vines with loops',
      () {
        // Create test videos with various loop counts and timestamps
        final newVineRecent = VideoEvent(
          id: 'new-recent',
          pubkey: 'test1',
          createdAt: 1000000, // Most recent
          content: 'New vine recent',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000000 * 1000),
          originalLoops: null, // No loops = new vine
        );

        final newVineOlder = VideoEvent(
          id: 'new-older',
          pubkey: 'test2',
          createdAt: 900000, // Older
          content: 'New vine older',
          timestamp: DateTime.fromMillisecondsSinceEpoch(900000 * 1000),
          originalLoops: null, // No loops = new vine
        );

        final originalVineHighLoops = VideoEvent(
          id: 'original-high',
          pubkey: 'test3',
          createdAt: 800000,
          content: 'Original vine high loops',
          timestamp: DateTime.fromMillisecondsSinceEpoch(800000 * 1000),
          originalLoops: 10000, // High loop count
        );

        final originalVineLowLoops = VideoEvent(
          id: 'original-low',
          pubkey: 'test4',
          createdAt: 700000,
          content: 'Original vine low loops',
          timestamp: DateTime.fromMillisecondsSinceEpoch(700000 * 1000),
          originalLoops: 5000, // Lower loop count
        );

        final originalVineZeroLoops = VideoEvent(
          id: 'original-zero',
          pubkey: 'test5',
          createdAt: 600000,
          content: 'Original vine zero loops',
          timestamp: DateTime.fromMillisecondsSinceEpoch(600000 * 1000),
          originalLoops: 0, // Zero loops treated as new vine
        );

        // Mix them up
        final unsorted = [
          originalVineLowLoops,
          newVineOlder,
          originalVineHighLoops,
          originalVineZeroLoops,
          newVineRecent,
        ];

        // Sort using compareByLoopsThenTime
        final sorted = List<VideoEvent>.from(unsorted)
          ..sort(VideoEvent.compareByLoopsThenTime);

        // Expected order:
        // 1. new-recent (no loops, most recent)
        // 2. new-older (no loops, older)
        // 3. original-zero (zero loops treated as new vine)
        // 4. original-high (has loops, highest count)
        // 5. original-low (has loops, lower count)

        expect(
          sorted[0].id,
          'new-recent',
          reason: 'Most recent new vine should be first',
        );
        expect(
          sorted[1].id,
          'new-older',
          reason: 'Older new vine should be second',
        );
        expect(
          sorted[2].id,
          'original-zero',
          reason: 'Zero loops treated as new vine, oldest',
        );
        expect(
          sorted[3].id,
          'original-high',
          reason: 'Highest loop count should be fourth',
        );
        expect(
          sorted[4].id,
          'original-low',
          reason: 'Lower loop count should be last',
        );
      },
    );

    test('sorts vines with equal loops by timestamp', () {
      final vine1 = VideoEvent(
        id: 'vine1',
        pubkey: 'test1',
        createdAt: 1000000, // More recent
        content: 'Vine 1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000000 * 1000),
        originalLoops: 5000,
      );

      final vine2 = VideoEvent(
        id: 'vine2',
        pubkey: 'test2',
        createdAt: 900000, // Older
        content: 'Vine 2',
        timestamp: DateTime.fromMillisecondsSinceEpoch(900000 * 1000),
        originalLoops: 5000, // Same loop count
      );

      final unsorted = [vine2, vine1];
      final sorted = List<VideoEvent>.from(unsorted)
        ..sort(VideoEvent.compareByLoopsThenTime);

      // When loops are equal, newer should come first
      expect(
        sorted[0].id,
        'vine1',
        reason: 'More recent vine should be first when loops equal',
      );
      expect(
        sorted[1].id,
        'vine2',
        reason: 'Older vine should be second when loops equal',
      );
    });

    test('handles empty list', () {
      final empty = <VideoEvent>[];
      final sorted = List<VideoEvent>.from(empty)
        ..sort(VideoEvent.compareByLoopsThenTime);

      expect(sorted, isEmpty);
    });

    test('handles single item', () {
      final single = [
        VideoEvent(
          id: 'single',
          pubkey: 'test',
          createdAt: 1000000,
          content: 'Single vine',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000000 * 1000),
          originalLoops: 100,
        ),
      ];
      final sorted = List<VideoEvent>.from(single)
        ..sort(VideoEvent.compareByLoopsThenTime);

      expect(sorted.length, 1);
      expect(sorted[0].id, 'single');
    });
  });
}
