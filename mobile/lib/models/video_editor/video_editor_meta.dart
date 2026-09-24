// ABOUTME: Metadata model for video editor containing publication info
// ABOUTME: Stores title, description, hashtags, and privacy settings for videos

import 'package:openvine/models/divine_video_draft.dart';

/// Metadata for video editor including title, description, and settings.
class VideoEditorMeta {
  /// Creates video editor metadata.
  VideoEditorMeta({
    required this.title,
    required this.description,
    required this.hashtags,
    this.allowAudioReuse = false,
    this.expireTime,
  });

  /// Creates empty metadata for new draft.
  factory VideoEditorMeta.draft() {
    return VideoEditorMeta(title: '', description: '', hashtags: {});
  }

  /// Creates metadata from existing vine draft.
  factory VideoEditorMeta.fromVineDraft(DivineVideoDraft draft) {
    return VideoEditorMeta(
      title: draft.title,
      description: draft.description,
      hashtags: draft.hashtags,
      allowAudioReuse: draft.allowAudioReuse,
      expireTime: draft.expireTime,
    );
  }

  /// Video title.
  final String title;

  /// Video description.
  final String description;

  /// Hashtags attached to the video.
  final Set<String> hashtags;

  /// Whether audio can be reused by others.
  final bool allowAudioReuse;

  /// Optional expiration time for the video.
  final Duration? expireTime;

  /// Creates a copy with updated fields.
  VideoEditorMeta copyWith({
    String? title,
    String? description,
    Set<String>? hashtags,
    bool? allowAudioReuse,
    Duration? expireTime,
  }) {
    return VideoEditorMeta(
      title: title ?? this.title,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
      expireTime: expireTime ?? this.expireTime,
    );
  }
}
