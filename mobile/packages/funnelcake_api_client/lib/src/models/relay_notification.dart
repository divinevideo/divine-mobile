/// Raw notification from the Divine Relay REST API.
///
/// Represents a single notification event before enrichment or grouping.
/// Plain class (no Equatable) -- matches other DTOs in this package.
class RelayNotification {
  /// Creates a parsed relay notification model.
  const RelayNotification({
    required this.id,
    required this.sourcePubkey,
    required this.sourceEventId,
    required this.sourceKind,
    required this.notificationType,
    required this.createdAt,
    required this.read,
    this.referencedEventId,
    this.referencedEventKind,
    this.content,
    this.isReferencedVideo = false,
    this.referencedVideoTitle,
    this.referencedVideoThumbnail,
    this.referencedDTag,
    this.rootEventId,
    this.rootEventKind,
    this.rootEventPubkey,
    this.rootDTag,
    this.rootAddressableId,
    this.targetCommentId,
    this.commentContent,
    this.listTitle,
    this.listCoordinate,
  });

  /// Parses a notification payload from the FunnelCake API.
  factory RelayNotification.fromJson(Map<String, dynamic> json) {
    final referencedVideo = json['referenced_video'];
    final referencedVideoMap = referencedVideo is Map<String, dynamic>
        ? referencedVideo
        : null;
    final videoTitle =
        referencedVideoMap?['title'] as String? ??
        json['referenced_event_title'] as String?;

    // d_tag is the stable vineId for the referenced video. It is sent in two
    // places by the server — prefer referenced_video.d_tag, fall back to the
    // top-level referenced_d_tag field.
    final rawDTag =
        referencedVideoMap?['d_tag'] as String? ??
        json['referenced_d_tag'] as String?;

    final rawThumbnail =
        referencedVideoMap?['thumbnail'] as String? ??
        json['referenced_event_thumbnail'] as String?;

    return RelayNotification(
      id: json['id'] as String? ?? '',
      sourcePubkey: json['source_pubkey'] as String? ?? '',
      sourceEventId: json['source_event_id'] as String? ?? '',
      sourceKind: json['source_kind'] as int? ?? 0,
      referencedEventId: json['referenced_event_id'] as String?,
      referencedEventKind: _intValue(json['referenced_event_kind']),
      notificationType: json['notification_type'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (_intValue(json['source_created_at']) ??
                _intValue(json['created_at']) ??
                0) *
            1000,
      ),
      read: _boolValue(json['read']),
      content: json['content'] as String?,
      isReferencedVideo: referencedVideoMap != null,
      referencedVideoTitle: (videoTitle != null && videoTitle.isNotEmpty)
          ? videoTitle
          : null,
      referencedVideoThumbnail:
          (rawThumbnail != null && rawThumbnail.isNotEmpty)
          ? rawThumbnail
          : null,
      referencedDTag: (rawDTag != null && rawDTag.isNotEmpty) ? rawDTag : null,
      rootEventId: _nonEmpty(json['root_event_id'] as String?),
      rootEventKind: _intValue(json['root_event_kind']),
      rootEventPubkey: _nonEmpty(
        (json['root_event_pubkey'] as String?)?.toLowerCase(),
      ),
      rootDTag: _nonEmpty(json['root_d_tag'] as String?),
      rootAddressableId: _nonEmpty(json['root_addressable_id'] as String?),
      targetCommentId: _nonEmpty(json['target_comment_id'] as String?),
      commentContent: _nonEmpty(json['comment_content'] as String?),
      listTitle: _nonEmpty(json['list_title'] as String?),
      listCoordinate: _nonEmpty(json['list_coordinate'] as String?),
    );
  }

  /// The notification ID assigned by the relay.
  final String id;

  /// The public key of the actor who triggered the notification.
  final String sourcePubkey;

  /// The Nostr event ID that caused the notification.
  final String sourceEventId;

  /// The Nostr kind of the source event.
  final int sourceKind;

  /// The event ID that was referenced (e.g. the video that was liked).
  final String? referencedEventId;

  /// Nostr kind of the event named by [referencedEventId], when Funnelcake
  /// knows it.
  ///
  /// `null` means unknown, never "a video": Funnelcake only sets it on rows
  /// materialized since 2026-08-24. A kind 6 or 16 means the activity
  /// targeted the recipient's repost event rather than their own content.
  final int? referencedEventKind;

  /// The notification type (e.g. 'reaction', 'reply', 'repost', 'zap').
  final String notificationType;

  /// When the notification was created.
  final DateTime createdAt;

  /// Whether the notification has been read.
  final bool read;

  /// Optional content from the source event (e.g. reaction emoji).
  final String? content;

  /// Whether the API populated a `referenced_video` join result for the
  /// notification's root video.
  ///
  /// This is enrichment metadata, not a reliable target-type signal: comment
  /// likes can include it because their root is a video, and video likes can
  /// omit it when that root video fails to resolve.
  final bool isReferencedVideo;

  /// Title of the referenced video, when the referenced event is a video
  /// with a non-empty title. `null` for non-video targets or untitled
  /// videos.
  final String? referencedVideoTitle;

  /// Thumbnail URL of the referenced video, when the server includes it in
  /// `referenced_video.thumbnail`. Stable — does not depend on event ID.
  final String? referencedVideoThumbnail;

  /// The `d` tag (vineId) of the referenced video.
  ///
  /// Populated from `referenced_video.d_tag` or the top-level
  /// `referenced_d_tag` field when the server includes it. Together with the
  /// notification recipient's pubkey this forms the NIP-33 addressable
  /// coordinate (`34236:pubkey:d-tag`) which is stable across metadata edits.
  final String? referencedDTag;

  /// Root video event ID included by Funnelcake for NIP-22 comment
  /// notifications and source-video mentions.
  ///
  /// For NIP-22 comments this is the video's event id. For kind 34236
  /// video-sourced mention rows this is the source video event id. App layers
  /// prefer [rootAddressableId] when present because the coordinate survives
  /// replaceable video edits.
  final String? rootEventId;

  /// Nostr kind of the root/source event, when Funnelcake includes it.
  final int? rootEventKind;

  /// Pubkey of the root video's author, when Funnelcake can resolve it
  /// (from the reaction's NIP-22 root `P` tag / root coordinate).
  ///
  /// This is the *root* author, not necessarily the owner of the event the
  /// notification anchors on: for a reaction on the user's comment on someone
  /// else's video it is the *other* creator, and for a reaction on the user's
  /// own video-reply it is again the other creator (the thread's root video
  /// author), even though the user owns the replied-with video. It equals the
  /// user's own pubkey only for a reaction on the user's own top-level video.
  ///
  /// Because of that, app layers use it as a *fallback* ownership signal —
  /// consulted only when the anchor event's own metadata can't resolve the
  /// owner — to detect a "liked your comment" that would otherwise be
  /// mislabelled "liked your video" without a metadata round-trip.
  final String? rootEventPubkey;

  /// The root/source video's NIP-33 `d` tag, when Funnelcake includes it.
  final String? rootDTag;

  /// Full NIP-33 coordinate for the root video, when Funnelcake can resolve it.
  ///
  /// For actor-anchored comment/reply rows this lets taps route directly to the
  /// stable root video (`34236:<root_event_pubkey>:<root_d_tag>`) instead of
  /// resolving the comment event first.
  final String? rootAddressableId;

  /// Comment event ID included by Funnelcake for NIP-22 comment notifications.
  final String? targetCommentId;

  /// Body of the comment identified by [targetCommentId], when Funnelcake
  /// resolves it.
  ///
  /// For a reaction this is the *liked* comment's text — [content] carries
  /// only the reaction emoji, so this is the sole source of context for a
  /// "liked your comment" row. For a comment or reply notification it is
  /// the source event's own body, which duplicates [content].
  final String? commentContent;

  /// Curated-list title for `notification_type: "list_add"`.
  final String? listTitle;

  /// Full kind-30005 coordinate for the curated list.
  ///
  /// Shape: `30005:<curator_pubkey>:<d-tag>`.
  final String? listCoordinate;

  /// Stable dedup key -- falls back to sourceEventId if id is empty.
  String get dedupeKey => id.isNotEmpty ? id : sourceEventId;

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  static int? _intValue(Object? value) => value is num ? value.toInt() : null;

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    return false;
  }
}
