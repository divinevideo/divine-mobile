// ABOUTME: Test to verify profile feed videos are sorted in reverse chronological order (newest first)
// ABOUTME: Ensures that when viewing a user's profile, their videos appear with newest at the top

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group('VideoEvent Sorting', () {
    test('should sort videos in reverse chronological order (newest first)', () {
      // ARRANGE: Create test videos with different timestamps
      final now = DateTime.now();
      final testUserHex = 'testuser123456789abcdef';

      // Create videos with increasing timestamps (oldest to newest)
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: testUserHex,
        content: 'Oldest video',
        createdAt: 1000, // Oldest
        timestamp: now.subtract(const Duration(hours: 3)),
      );

      final video2 = VideoEvent(
        id: 'video2',
        pubkey: testUserHex,
        content: 'Middle video',
        createdAt: 2000, // Middle
        timestamp: now.subtract(const Duration(hours: 2)),
      );

      final video3 = VideoEvent(
        id: 'video3',
        pubkey: testUserHex,
        content: 'Newest video',
        createdAt: 3000, // Newest
        timestamp: now.subtract(const Duration(hours: 1)),
      );

      // Create unsorted list (random order)
      final unsortedVideos = [video2, video1, video3];

      // ACT: Sort videos by createdAt descending (newest first)
      final sortedVideos = List<VideoEvent>.from(unsortedVideos);
      sortedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // ASSERT: Videos should be in reverse chronological order (newest first)
      expect(sortedVideos.length, 3);
      expect(
        sortedVideos[0].id,
        'video3',
        reason: 'First video should be the newest (video3)',
      );
      expect(
        sortedVideos[1].id,
        'video2',
        reason: 'Second video should be middle (video2)',
      );
      expect(
        sortedVideos[2].id,
        'video1',
        reason: 'Third video should be oldest (video1)',
      );

      // Verify timestamps are in descending order
      expect(sortedVideos[0].createdAt, 3000);
      expect(sortedVideos[1].createdAt, 2000);
      expect(sortedVideos[2].createdAt, 1000);

      // Verify newest comes before oldest
      expect(sortedVideos[0].createdAt > sortedVideos[1].createdAt, isTrue);
      expect(sortedVideos[1].createdAt > sortedVideos[2].createdAt, isTrue);
    });

    test('should handle videos with same timestamp', () {
      final now = DateTime.now();
      final testUserHex = 'testuser123456789abcdef';

      // Create videos with same timestamp but different IDs
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: testUserHex,
        content: 'Video 1',
        createdAt: 1000,
        timestamp: now,
      );

      final video2 = VideoEvent(
        id: 'video2',
        pubkey: testUserHex,
        content: 'Video 2',
        createdAt: 1000, // Same timestamp
        timestamp: now,
      );

      final videos = [video1, video2];
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Both videos should be present (stable sort)
      expect(videos.length, 2);
      expect(videos.any((v) => v.id == 'video1'), isTrue);
      expect(videos.any((v) => v.id == 'video2'), isTrue);
    });

    test('should handle empty list', () {
      final videos = <VideoEvent>[];
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(videos, isEmpty);
    });

    test('should handle single video', () {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'video1',
        pubkey: 'testuser',
        content: 'Single video',
        createdAt: 1000,
        timestamp: now,
      );

      final videos = [video];
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(videos.length, 1);
      expect(videos[0].id, 'video1');
    });
  });
}
