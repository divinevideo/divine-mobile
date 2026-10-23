// ABOUTME: Actor-anchored notification — follows, mentions, system, and
// ABOUTME: reactions without a video anchor, including grouped comment likes.

part of 'notification_item.dart';

/// A notification anchored to an actor (follow, mention, system, or an
/// addressable reaction without a concrete video event ID).
///
/// Comment likes with a confirmed comment ID share a row; other kinds
/// remain one row per event.
@immutable
class ActorNotification extends NotificationItem {
  /// Creates an [ActorNotification], normalizing [commentText] to well-formed
  /// UTF-16.
  ///
  /// [commentText] is the source event's body — relay text the row renders as
  /// a quote. See [VideoNotification] for the boundary rationale.
  ActorNotification({
    required super.id,
    required super.type,
    required this.actor,
    required super.timestamp,
    this.additionalActors = const [],
    this.commentEventId,
    super.isRead,
    super.targetEventId,
    super.sourceEventIds,
    super.notificationIds,
    String? commentText,
    this.isFollowingBack = false,
    this.videoAddressableId,
    this.hasCommentTarget = false,
  }) : commentText = sanitizeUtf16OrNull(commentText),
       assert(
         type == NotificationKind.follow ||
             type == NotificationKind.like ||
             type == NotificationKind.mention ||
             type == NotificationKind.system ||
             type == NotificationKind.likeComment ||
             type == NotificationKind.reply,
         'ActorNotification only supports follow, like, mention, system, '
         'likeComment, reply',
       );

  /// The actor who triggered this notification.
  final ActorInfo actor;

  /// Other distinct people represented by a grouped comment-like row.
  /// Kept in full so pagination can deduplicate people beyond the avatar cap.
  final List<ActorInfo> additionalActors;

  /// All distinct actors, with the visible lead actor first.
  List<ActorInfo> get actors => [actor, ...additionalActors];

  /// Confirmed liked comment ID, separate from the navigation fallback in
  /// [targetEventId], which can instead identify the parent video.
  /// Only rows with this explicit target may be grouped as comment likes.
  final String? commentEventId;

  /// Optional row quote/context text.
  ///
  /// For comment-like rows this is the liked comment's body. For reply and
  /// mention rows this is the source event's surrounding text/body.
  final String? commentText;

  /// Whether the current user already follows this actor back.
  final bool isFollowingBack;

  /// Stable NIP-33 addressable ID (`34236:pubkey:d-tag`) of the video context
  /// for actor-anchored [NotificationKind.like],
  /// [NotificationKind.likeComment], and [NotificationKind.reply]
  /// notifications, when the server provided a usable root video coordinate.
  ///
  /// When set, the tap handler navigates directly to the video using
  /// this ID without a relay round-trip through the resolver.
  /// Falls back to the resolver when null.
  final String? videoAddressableId;

  /// Whether this actor row targets a concrete comment/reply thread.
  ///
  /// Mentions can be either a plain actor mention or a comment mention. The
  /// tap router uses this explicit signal to decide whether a mention should
  /// auto-open comments after resolving the video.
  final bool hasCommentTarget;

  /// Returns a copy with the given fields replaced.
  ActorNotification copyWith({
    String? id,
    NotificationKind? type,
    ActorInfo? actor,
    List<ActorInfo>? additionalActors,
    String? commentEventId,
    DateTime? timestamp,
    bool? isRead,
    String? commentText,
    bool? isFollowingBack,
    String? targetEventId,
    List<String>? sourceEventIds,
    List<String>? notificationIds,
    String? videoAddressableId,
    bool? hasCommentTarget,
  }) {
    return ActorNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      additionalActors: additionalActors ?? this.additionalActors,
      commentEventId: commentEventId ?? this.commentEventId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      commentText: commentText ?? this.commentText,
      isFollowingBack: isFollowingBack ?? this.isFollowingBack,
      targetEventId: targetEventId ?? this.targetEventId,
      sourceEventIds: sourceEventIds ?? this.sourceEventIds,
      notificationIds: notificationIds ?? this.notificationIds,
      videoAddressableId: videoAddressableId ?? this.videoAddressableId,
      hasCommentTarget: hasCommentTarget ?? this.hasCommentTarget,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    actor,
    additionalActors,
    commentEventId,
    timestamp,
    isRead,
    commentText,
    isFollowingBack,
    targetEventId,
    sourceEventIds,
    notificationIds,
    videoAddressableId,
    hasCommentTarget,
  ];
}
