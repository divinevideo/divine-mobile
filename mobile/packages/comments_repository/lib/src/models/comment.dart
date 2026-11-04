// ABOUTME: Comment model representing a single comment or reply in a thread.
// ABOUTME: Contains metadata for threading, author info, and Nostr event
// ABOUTME: relationships. Uses Equatable for value-based equality.

import 'package:equatable/equatable.dart';

/// A comment on a Nostr event (Kind 1 text note).
///
/// Comments are threaded using Nostr's NIP-10 reply threading:
/// - `rootEventId`: The original event being commented on (e.g., a video)
/// - `rootAddressableId`: Optional addressable root identifier for
///   parameterized replaceable roots.
/// - `replyToEventId`: The parent comment ID for nested replies
///
/// The `e` tags in the Nostr event use markers:
/// - `root`: Points to the original event
/// - `reply`: Points to the direct parent comment
class Comment extends Equatable {
  /// Creates a new comment.
  const Comment({
    required this.id,
    required this.content,
    required this.authorPubkey,
    required this.createdAt,
    required this.rootEventId,
    required this.rootAuthorPubkey,
    this.rootAddressableId,
    this.addressableId,
    this.eventKind,
    this.replyToEventId,
    this.replyToAuthorPubkey,
    this.videoUrl,
    this.thumbnailUrl,
    this.videoDimensions,
    this.videoDuration,
    this.videoBlurhash,
    this.stickerTags = const [],
  });

  /// Unique comment ID (Nostr event ID).
  final String id;

  /// Comment text content.
  final String content;

  /// Author's public key (hex format).
  final String authorPubkey;

  /// When the comment was created.
  final DateTime createdAt;

  /// The root event ID this comment is replying to (e.g., video event).
  final String rootEventId;

  /// Public key of the root event author.
  final String rootAuthorPubkey;

  /// Addressable identifier of the root event, when the root is parameterized.
  final String? rootAddressableId;

  /// This comment's **own** addressable coordinate (`kind:pubkey:d-tag`).
  ///
  /// Non-null only when the comment wraps an addressable event that carries a
  /// `d` tag — a Kind 34236 video reply, for example. Plain Kind 1111 comments
  /// are regular events with no coordinate, and so are `null`.
  ///
  /// Distinct from [rootAddressableId], which addresses the *parent* video.
  /// Reactions must be tagged with this one: NIP-25's `a` tag identifies the
  /// event being reacted to, and using the parent's coordinate would credit
  /// the parent video's engagement counts instead (#6124).
  final String? addressableId;

  /// The Nostr event kind this comment was parsed from.
  ///
  /// `null` when the source did not report a kind or reported the REST
  /// omitted-kind sentinel. Reactions use this for NIP-25's `k` tag, which
  /// must name the kind of the event being reacted to.
  final int? eventKind;

  /// If this is a reply, the ID of the parent comment.
  ///
  /// `null` for top-level comments.
  final String? replyToEventId;

  /// If this is a reply, the public key of the parent comment author.
  final String? replyToAuthorPubkey;

  /// URL of an attached video (NIP-92 imeta).
  final String? videoUrl;

  /// Thumbnail URL for the attached video (NIP-92 imeta `image` field).
  final String? thumbnailUrl;

  /// Video dimensions as "widthxheight" (NIP-92 imeta `dim` field).
  final String? videoDimensions;

  /// Video duration in seconds (NIP-92 imeta `duration` field).
  final int? videoDuration;

  /// Blurhash of the video thumbnail (NIP-92 imeta `blurhash` field).
  final String? videoBlurhash;

  /// The `sticker` tags of a video reply, as it was published: where each
  /// sticker a viewer can tap stands on the video and what it opens.
  final List<List<String>> stickerTags;

  /// Whether this comment has an attached video.
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// Creates a copy with updated fields.
  Comment copyWith({
    String? id,
    String? content,
    String? authorPubkey,
    DateTime? createdAt,
    String? rootEventId,
    String? rootAuthorPubkey,
    String? rootAddressableId,
    String? addressableId,
    int? eventKind,
    String? replyToEventId,
    String? replyToAuthorPubkey,
    String? videoUrl,
    String? thumbnailUrl,
    String? videoDimensions,
    int? videoDuration,
    String? videoBlurhash,
    List<List<String>>? stickerTags,
  }) => Comment(
    id: id ?? this.id,
    content: content ?? this.content,
    authorPubkey: authorPubkey ?? this.authorPubkey,
    createdAt: createdAt ?? this.createdAt,
    rootEventId: rootEventId ?? this.rootEventId,
    rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
    rootAddressableId: rootAddressableId ?? this.rootAddressableId,
    addressableId: addressableId ?? this.addressableId,
    eventKind: eventKind ?? this.eventKind,
    replyToEventId: replyToEventId ?? this.replyToEventId,
    replyToAuthorPubkey: replyToAuthorPubkey ?? this.replyToAuthorPubkey,
    videoUrl: videoUrl ?? this.videoUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    videoDimensions: videoDimensions ?? this.videoDimensions,
    videoDuration: videoDuration ?? this.videoDuration,
    videoBlurhash: videoBlurhash ?? this.videoBlurhash,
    stickerTags: stickerTags ?? this.stickerTags,
  );

  @override
  List<Object?> get props => [
    id,
    content,
    authorPubkey,
    createdAt,
    rootEventId,
    rootAuthorPubkey,
    rootAddressableId,
    addressableId,
    eventKind,
    replyToEventId,
    replyToAuthorPubkey,
    videoUrl,
    thumbnailUrl,
    videoDimensions,
    videoDuration,
    videoBlurhash,
    stickerTags,
  ];
}
