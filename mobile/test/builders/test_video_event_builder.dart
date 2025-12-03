// ABOUTME: Test builder for creating VideoEvent instances in tests
// ABOUTME: Replaces the removed DefaultContentService with a clean builder pattern

import 'package:models/models.dart';

/// Builder for creating test VideoEvent instances
class TestVideoEventBuilder {
  /// Create a basic test video event with sensible defaults
  static VideoEvent create({
    String? id,
    String? pubkey,
    String? content,
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    List<String>? hashtags,
    DateTime? timestamp,
    int? createdAt,
    Map<String, String>? rawTags,
  }) {
    final now = DateTime.now();
    return VideoEvent(
      id: id ?? 'test_video_${now.millisecondsSinceEpoch}',
      pubkey: pubkey ?? 'test_pubkey_${now.millisecondsSinceEpoch}',
      createdAt: createdAt ?? (now.millisecondsSinceEpoch ~/ 1000),
      content: content ?? 'Test video content #test',
      timestamp: timestamp ?? now,
      title: title ?? 'Test Video',
      videoUrl: videoUrl ?? 'https://example.com/test_video.mp4',
      thumbnailUrl: thumbnailUrl ?? 'https://example.com/test_thumbnail.jpg',
      hashtags: hashtags ?? ['test'],
      rawTags: rawTags ?? {},
    );
  }

  /// Create a video event with full metadata
  static VideoEvent createWithFullMetadata({
    String? id,
    String? title,
    int? duration,
    String? dimensions,
  }) {
    return create(
      id: id,
      title: title,
      rawTags: <String, String>{
        'duration': duration?.toString() ?? '6',
        'dimensions': dimensions ?? '1080x1920',
        'mime': 'video/mp4',
        'size': '1048576', // 1MB
      },
    );
  }

  /// Create a repost video event
  static VideoEvent createRepost({
    required String originalId,
    required String reposterPubkey,
    String? reposterId,
  }) {
    final now = DateTime.now();
    return VideoEvent(
      id: reposterId ?? 'repost_${now.millisecondsSinceEpoch}',
      pubkey: 'original_author_pubkey',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      content: 'Original video content',
      timestamp: now,
      videoUrl: 'https://example.com/original_video.mp4',
      isRepost: true,
      reposterPubkey: reposterPubkey,
      reposterId: reposterId ?? 'repost_event_${now.millisecondsSinceEpoch}',
      repostedAt: now,
    );
  }

  /// Create multiple test videos
  static List<VideoEvent> createMultiple({
    required int count,
    String? pubkeyPrefix,
  }) {
    return List.generate(
      count,
      (index) => create(
        id: 'test_video_$index',
        pubkey: '${pubkeyPrefix ?? 'test_pubkey'}_$index',
        title: 'Test Video $index',
      ),
    );
  }
}
