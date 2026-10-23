// ABOUTME: Video-anchored notification — likes, comments, reposts on a
// ABOUTME: video. One row per (video × kind) regardless of actor count.

part of 'notification_item.dart';

/// A notification anchored to a video — likes, comments, reposts, or source
/// video mentions.
///
/// One row per (video × kind) regardless of how many actors interacted.
/// The list of [actors] is capped for stacked-avatar display; [totalCount]
/// holds the full actor count.
@immutable
class VideoNotification extends NotificationItem {
  /// Creates a [VideoNotification], normalizing its quoted text to
  /// well-formed UTF-16.
  ///
  /// [videoTitle], [commentText] and [listTitle] are relay-authored strings —
  /// a video's title, a commenter's body, someone else's curated-list name —
  /// that the notification row renders straight into a `Text.rich` span. A
  /// lone surrogate there throws `Invalid argument(s): string is not
  /// well-formed UTF-16` out of Flutter's paragraph builder. The repository
  /// builds these rows from four different sources (REST payload, Drift
  /// placeholder rows, grouped merges, cache rehydration), so the constructor
  /// is the one boundary all of them cross.
  VideoNotification({
    required super.id,
    required super.type,
    required this.videoEventId,
    required this.actors,
    required this.totalCount,
    required super.timestamp,
    this.actorPubkeys = const [],
    super.isRead,
    super.sourceEventIds,
    super.notificationIds,
    this.videoThumbnailUrl,
    String? videoTitle,
    this.videoAddressableId,
    String? commentText,
    String? listTitle,
    this.listCoordinate,
    this.addedVideoCount,
  }) : videoTitle = sanitizeUtf16OrNull(videoTitle),
       commentText = sanitizeUtf16OrNull(commentText),
       listTitle = sanitizeUtf16OrNull(listTitle),
       assert(
         type == NotificationKind.like ||
             type == NotificationKind.likeComment ||
             type == NotificationKind.comment ||
             type == NotificationKind.mention ||
             type == NotificationKind.repost ||
             type == NotificationKind.newPost ||
             type == NotificationKind.listAdd,
         'VideoNotification only supports like, likeComment, comment, '
         'mention, repost, newPost, listAdd',
       ),
       assert(actors.isNotEmpty, 'must have at least one actor'),
       assert(
         totalCount >= actors.length,
         'totalCount cannot be less than actors.length',
       ),
       super(targetEventId: videoEventId);

  /// The Nostr event id of the video that was acted on.
  ///
  /// May become stale after a metadata update (NIP-33 replacement).
  /// Prefer [videoAddressableId] for navigation when available.
  final String videoEventId;

  /// The NIP-33 addressable ID (`34236:pubkey:d-tag`) of the video.
  ///
  /// Stable across metadata updates. Use this for navigation instead of
  /// [videoEventId] whenever it is non-null.
  final String? videoAddressableId;

  /// Thumbnail URL of the referenced video, if available.
  final String? videoThumbnailUrl;

  /// Title of the referenced video, if available.
  final String? videoTitle;

  /// First N actors (newest-first) for stacked avatar display.
  final List<ActorInfo> actors;

  /// Complete distinct liker identities for counts across paginated groups.
  /// [actors] remains capped for display. Empty for legacy placeholders and
  /// notification types whose count represents events rather than people.
  final List<String> actorPubkeys;

  /// Total number of distinct actors who interacted (may exceed the length of
  /// [actors]).
  final int totalCount;

  /// Optional excerpt of the most recent comment when [type] is
  /// [NotificationKind.comment]. Truncated by the repository so a long
  /// comment doesn't blow out the row layout. Other kinds (like, repost,
  /// likeComment) leave this null because they have no associated body
  /// text.
  final String? commentText;

  /// Title of the public curated list for [NotificationKind.listAdd].
  final String? listTitle;

  /// Full kind-30005 coordinate for the public curated list.
  final String? listCoordinate;

  /// Number of the user's videos added to [listCoordinate].
  ///
  /// Only meaningful for [NotificationKind.listAdd]. This is intentionally
  /// separate from [totalCount], which remains the actor/avatar count.
  final int? addedVideoCount;

  /// Returns a copy with the given fields replaced.
  VideoNotification copyWith({
    String? id,
    NotificationKind? type,
    String? videoEventId,
    String? videoAddressableId,
    String? videoThumbnailUrl,
    String? videoTitle,
    List<ActorInfo>? actors,
    List<String>? actorPubkeys,
    int? totalCount,
    DateTime? timestamp,
    bool? isRead,
    String? commentText,
    String? listTitle,
    String? listCoordinate,
    int? addedVideoCount,
    List<String>? sourceEventIds,
    List<String>? notificationIds,
  }) {
    return VideoNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      videoEventId: videoEventId ?? this.videoEventId,
      videoAddressableId: videoAddressableId ?? this.videoAddressableId,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      actors: actors ?? this.actors,
      actorPubkeys: actorPubkeys ?? this.actorPubkeys,
      totalCount: totalCount ?? this.totalCount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      commentText: commentText ?? this.commentText,
      listTitle: listTitle ?? this.listTitle,
      listCoordinate: listCoordinate ?? this.listCoordinate,
      addedVideoCount: addedVideoCount ?? this.addedVideoCount,
      sourceEventIds: sourceEventIds ?? this.sourceEventIds,
      notificationIds: notificationIds ?? this.notificationIds,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    videoEventId,
    videoAddressableId,
    videoThumbnailUrl,
    videoTitle,
    actors,
    actorPubkeys,
    totalCount,
    timestamp,
    isRead,
    commentText,
    listTitle,
    listCoordinate,
    addedVideoCount,
    sourceEventIds,
    notificationIds,
  ];
}
