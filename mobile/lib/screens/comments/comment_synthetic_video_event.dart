import 'package:comments_repository/comments_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

extension CommentSyntheticVideoEventX on Comment {
  VideoEvent toSyntheticVideoEvent() {
    final title = content.trim();
    final createdAt = this.createdAt.millisecondsSinceEpoch ~/ 1000;
    final videoKind = EventKind.videoVertical.toString();
    final rootAddressableId = this.rootAddressableId;

    return VideoEvent(
      id: id,
      pubkey: authorPubkey,
      createdAt: createdAt,
      content: content,
      timestamp: this.createdAt,
      title: title.isNotEmpty ? title : null,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: videoDuration,
      dimensions: videoDimensions,
      blurhash: videoBlurhash,
      // The video reply's own stickers, so a viewer can tap them here too.
      stickerRegions: VideoStickerRegion.fromTags(stickerTags),
      // Synthetic tags for navigation only. Thread semantics still come from
      // the comment model, not from these placeholder kind values.
      rawTags: {
        'E': rootEventId,
        'K': videoKind,
        'P': rootAuthorPubkey,
        if (rootAddressableId case final rootAddressableId?) ...{
          'A': rootAddressableId,
          if (replyToEventId == null) 'a': rootAddressableId,
        },
        if (replyToEventId case final replyToEventId?) ...{
          'e': replyToEventId,
          'k': videoKind,
        },
        if (replyToAuthorPubkey case final replyToAuthorPubkey?) ...{
          'p': replyToAuthorPubkey,
        },
      },
    );
  }
}
