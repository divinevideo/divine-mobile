// ABOUTME: Tests for NIP-18 repost system functionality
// ABOUTME: Verifies repost event creation, display, and user interactions

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('Repost System Tests', () {
    group('VideoEvent Repost Model', () {
      test('should create repost VideoEvent with correct metadata', () {
        // Create original video event
        final originalEvent = VideoEvent(
          id: 'original123',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Original video content',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000000),
          title: 'Test Video',
          videoUrl: 'https://example.com/video.mp4',
        );

        // Create repost event
        final repostEvent = VideoEvent.createRepostEvent(
          originalEvent: originalEvent,
          repostEventId: 'repost789',
          reposterPubkey: 'reposter101',
          repostedAt: DateTime.fromMillisecondsSinceEpoch(2000000),
        );

        // Verify repost metadata
        expect(repostEvent.isRepost, isTrue);
        expect(repostEvent.reposterId, equals('repost789'));
        expect(repostEvent.reposterPubkey, equals('reposter101'));
        expect(
          repostEvent.repostedAt,
          equals(DateTime.fromMillisecondsSinceEpoch(2000000)),
        );

        // Verify original content is preserved
        expect(repostEvent.id, equals('original123'));
        expect(repostEvent.pubkey, equals('author456'));
        expect(repostEvent.title, equals('Test Video'));
        expect(repostEvent.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('should create regular VideoEvent as non-repost by default', () {
        final videoEvent = VideoEvent(
          id: 'video123',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Video content',
          timestamp: DateTime.now(),
        );

        expect(videoEvent.isRepost, isFalse);
        expect(videoEvent.reposterId, isNull);
        expect(videoEvent.reposterPubkey, isNull);
        expect(videoEvent.repostedAt, isNull);
      });

      test('should copy VideoEvent with repost fields', () {
        final originalEvent = VideoEvent(
          id: 'video123',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Video content',
          timestamp: DateTime.now(),
          title: 'Original Title',
        );

        final modifiedEvent = originalEvent.copyWith(
          isRepost: true,
          reposterId: 'repost789',
          reposterPubkey: 'reposter101',
          repostedAt: DateTime.fromMillisecondsSinceEpoch(2000000),
        );

        expect(modifiedEvent.isRepost, isTrue);
        expect(modifiedEvent.reposterId, equals('repost789'));
        expect(modifiedEvent.reposterPubkey, equals('reposter101'));
        expect(
          modifiedEvent.title,
          equals('Original Title'),
        ); // Original data preserved
      });

      test('should handle null repost fields gracefully', () {
        final videoEvent = VideoEvent(
          id: 'video123',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Video content',
          timestamp: DateTime.now(),
          isRepost: true,
          reposterId: null,
          reposterPubkey: null,
          repostedAt: null,
        );

        expect(videoEvent.isRepost, isTrue);
        expect(videoEvent.reposterId, isNull);
        expect(videoEvent.reposterPubkey, isNull);
        expect(videoEvent.repostedAt, isNull);
      });
    });

    group('Repost Event Validation', () {
      test('should identify repost events correctly', () {
        final originalEvent = VideoEvent(
          id: 'original123',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Original content',
          timestamp: DateTime.now(),
        );

        final repostEvent = VideoEvent.createRepostEvent(
          originalEvent: originalEvent,
          repostEventId: 'repost789',
          reposterPubkey: 'reposter101',
          repostedAt: DateTime.now(),
        );

        expect(originalEvent.isRepost, isFalse);
        expect(repostEvent.isRepost, isTrue);
      });

      test('should preserve all original video metadata in reposts', () {
        final originalEvent = VideoEvent(
          id: 'original123',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Original content',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000000),
          title: 'Test Video',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          duration: 30,
          hashtags: ['test', 'video'],
        );

        final repostEvent = VideoEvent.createRepostEvent(
          originalEvent: originalEvent,
          repostEventId: 'repost789',
          reposterPubkey: 'reposter101',
          repostedAt: DateTime.fromMillisecondsSinceEpoch(2000000),
        );

        // All original metadata should be preserved
        expect(repostEvent.title, equals('Test Video'));
        expect(repostEvent.videoUrl, equals('https://example.com/video.mp4'));
        expect(
          repostEvent.thumbnailUrl,
          equals('https://example.com/thumb.jpg'),
        );
        expect(repostEvent.duration, equals(30));
        expect(repostEvent.hashtags, equals(['test', 'video']));
        expect(repostEvent.content, equals('Original content'));
      });
    });
  });
}
