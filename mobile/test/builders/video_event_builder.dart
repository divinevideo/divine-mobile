// ABOUTME: Test data builder for creating VideoEvent instances for testing
// ABOUTME: Provides flexible factory methods with sensible defaults

import 'package:models/models.dart';

/// Builder class for creating test VideoEvent instances
class VideoEventBuilder {
  VideoEventBuilder({
    this.id = 'test-video-id',
    this.eventId = 'test-event-id',
    this.pubkey = 'test-pubkey',
    this.videoUrl = 'https://example.com/video.mp4',
    this.thumbnailUrl = 'https://example.com/thumb.jpg',
    this.gifUrl = 'https://example.com/preview.gif',
    this.blurhash = 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
    int? createdAt,
    this.title = 'Test Video',
    this.duration = 6,
    this.isProcessing = false,
    this.originalLoops,
    this.originalLikes,
    Map<String, dynamic>? metadata,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       metadata = metadata ?? {};
  String id;
  String eventId;
  String pubkey;
  String? videoUrl;
  String? thumbnailUrl;
  String? gifUrl;
  String? blurhash;
  int createdAt;
  String? title;
  int duration;
  bool isProcessing;
  int? originalLoops;
  int? originalLikes;
  Map<String, dynamic> metadata;

  /// Build the VideoEvent instance
  VideoEvent build() => VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: title ?? 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    title: title,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    originalLoops: originalLoops,
    originalLikes: originalLikes,
  );

  /// Create a processing video
  VideoEventBuilder processing() {
    isProcessing = true;
    videoUrl = null;
    thumbnailUrl = null;
    gifUrl = null;
    return this;
  }

  /// Create a video with custom metadata
  VideoEventBuilder withMetadata(Map<String, dynamic> newMetadata) {
    metadata = newMetadata;
    return this;
  }

  /// Create a video from a specific user
  VideoEventBuilder fromUser(String userPubkey) {
    pubkey = userPubkey;
    return this;
  }

  /// Create an old video (1 week ago)
  VideoEventBuilder old() {
    createdAt =
        DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch ~/
        1000;
    return this;
  }

  /// Create a recent video (1 minute ago)
  VideoEventBuilder recent() {
    createdAt =
        DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch ~/
        1000;
    return this;
  }

  /// Set original loops count (for imported Vine data)
  VideoEventBuilder withOriginalLoops(int? loops) {
    originalLoops = loops;
    return this;
  }

  /// Set original likes count (for imported Vine data)
  VideoEventBuilder withOriginalLikes(int? likes) {
    originalLikes = likes;
    return this;
  }

  /// Create multiple videos with sequential IDs
  static List<VideoEvent> buildMany({
    required int count,
    String Function(int index)? idGenerator,
    String Function(int index)? titleGenerator,
  }) => List.generate(
    count,
    (index) => VideoEventBuilder(
      id: idGenerator?.call(index) ?? 'video-$index',
      eventId: 'event-$index',
      title: titleGenerator?.call(index) ?? 'Video $index',
    ).build(),
  );
}
