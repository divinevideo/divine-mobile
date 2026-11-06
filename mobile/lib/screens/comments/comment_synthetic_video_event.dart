import 'package:comments_repository/comments_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

extension CommentSyntheticVideoEventX on Comment {
  VideoEvent toSyntheticVideoEvent() {
    final title = content.trim();
    final createdAt = this.createdAt.millisecondsSinceEpoch ~/ 1000;
    final videoKind = EventKind.videoVertical.toString();
    final rootAddressableId = this.rootAddressableId;
    final ownCoordinate = _ownVideoReplyCoordinate;

    return VideoEvent(
      id: id,
      pubkey: authorPubkey,
      createdAt: createdAt,
      content: content,
      timestamp: this.createdAt,
      // A Kind 34236 video reply keeps its own d tag the way a relay-parsed
      // copy does, so a like, repost or share can address it (#6980).
      vineId: ownCoordinate?.dTag,
      addressableDTag: ownCoordinate?.dTag,
      // Retain a known addressable kind even if its coordinate is missing,
      // so the like writer can name the kind and report the missing a tag.
      eventKind: ownCoordinate != null || eventKind == EventKind.videoVertical
          ? EventKind.videoVertical
          : null,
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

  /// This comment's own coordinate when it is a Kind 34236 video reply, or
  /// null for a plain Kind 1111 comment.
  AId? get _ownVideoReplyCoordinate {
    final own = addressableId;
    final coordinate = own == null ? null : AId.fromString(own);
    return coordinate?.kind == EventKind.videoVertical ? coordinate : null;
  }
}
