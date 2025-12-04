// ABOUTME: Stub ReadyEventData model for backward compatibility with tests
// ABOUTME: Minimal implementation to resolve compilation errors in legacy test files

/// Ready event data model for legacy test compatibility
class ReadyEventData {
  final String? id;
  final String? videoId;
  final String? publicId;
  final String? secureUrl;
  final String? contentSuggestion;
  final String? title;
  final String? description;
  final List<String>? hashtags;
  final List<List<String>>? tags;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? processedAt;

  ReadyEventData({
    this.id,
    this.videoId,
    this.publicId,
    this.secureUrl,
    this.contentSuggestion,
    this.title,
    this.description,
    this.hashtags,
    this.tags,
    this.metadata,
    this.createdAt,
    this.processedAt,
  });

  // Factory constructor for tests
  factory ReadyEventData.test({
    String? id,
    String? videoId,
    String? title,
    String? description,
    List<String>? hashtags,
    DateTime? createdAt,
    DateTime? processedAt,
    String? secureUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ReadyEventData(
      id: id ?? 'test_id',
      videoId: videoId ?? 'test_video_id',
      title: title,
      description: description,
      hashtags: hashtags,
      createdAt: createdAt ?? DateTime.now(),
      processedAt: processedAt,
      secureUrl: secureUrl,
      metadata: metadata,
    );
  }

  /// Check if the event data is ready for publishing to Nostr
  bool get isReadyForPublishing {
    return secureUrl != null && secureUrl!.isNotEmpty;
  }

  /// Generate NIP-94 tags from the event data
  List<List<String>> get nip94Tags {
    final List<List<String>> tags = [];

    if (secureUrl != null) {
      tags.add(['url', secureUrl!]);
      // Add MIME type based on URL extension or default to mp4
      tags.add(['m', 'video/mp4']);
    }

    // Add dimensions if available in metadata
    if (metadata != null) {
      final width = metadata!['width'];
      final height = metadata!['height'];
      if (width != null && height != null) {
        tags.add(['dim', '${width}x$height']);
      }

      // Add duration if available (round to nearest second)
      final duration = metadata!['duration'];
      if (duration != null) {
        final durationSeconds = (duration is double)
            ? duration.round()
            : duration as int;
        tags.add(['duration', durationSeconds.toString()]);
      }
    }

    return tags;
  }

  /// Estimate the size of the Nostr event in bytes
  int get estimatedEventSize {
    int size = 0;

    // Base event structure overhead
    size += 200; // JSON structure, timestamps, etc.

    // Content (title + description)
    if (title != null) size += title!.length;
    if (description != null) size += description!.length;

    // Hashtags
    if (hashtags != null) {
      for (final hashtag in hashtags!) {
        size += hashtag.length + 1; // +1 for # prefix
      }
    }

    // NIP-94 tags
    for (final tag in nip94Tags) {
      for (final value in tag) {
        size += value.length + 4; // +4 for JSON formatting
      }
    }

    return size;
  }
}
