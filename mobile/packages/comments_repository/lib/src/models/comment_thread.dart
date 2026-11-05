// ABOUTME: Thread structure model for organizing comments in a flat list.
// ABOUTME: CommentThread contains all comments chronologically ordered with
// ABOUTME: reply relationships maintained via replyToEventId fields.

import 'package:comments_repository/src/models/comment.dart';
import 'package:equatable/equatable.dart';

/// A complete comment thread containing all comments for an event.
///
/// Comments are organized in a flat list, chronologically ordered
/// (newest first).
/// Reply relationships are maintained through the Comment model's
/// replyToEventId field.
class CommentThread extends Equatable {
  /// Creates a new comment thread.
  const CommentThread({
    required this.rootEventId,
    this.comments = const [],
    this.totalCount = 0,
    this.hasMore,
    this.hasExactTotal = true,
    this.commentCache = const {},
    this.nextOffset,
  });

  /// Creates an empty thread for a given root event.
  const CommentThread.empty(this.rootEventId)
    : comments = const [],
      totalCount = 0,
      hasMore = false,
      hasExactTotal = true,
      commentCache = const {},
      nextOffset = null;

  /// The ID of the root event these comments belong to.
  final String rootEventId;

  /// All comments in chronological order (newest first).
  final List<Comment> comments;

  /// Total number of comments in the thread (including replies).
  final int totalCount;

  /// Whether another page is available when the source reports pagination
  /// explicitly.
  final bool? hasMore;

  /// Whether [totalCount] is an exact server count rather than a pagination
  /// lower bound.
  final bool hasExactTotal;

  /// Cache of all comments by ID for quick lookup.
  final Map<String, Comment> commentCache;

  /// Where the next REST page starts, or `null` when the page did not come
  /// from REST.
  ///
  /// Counts every comment REST returned, including ones hidden afterwards,
  /// so a caller can continue the same REST listing.
  /// A combined video-reply page consumes only the raw REST prefix inside
  /// its shared time window; older comments are deferred, not skipped.
  final int? nextOffset;

  /// Whether the thread has any comments.
  bool get isEmpty => totalCount == 0;

  /// Whether the thread has comments.
  bool get isNotEmpty => totalCount > 0;

  /// Gets a comment by ID from the cache.
  Comment? getComment(String id) => commentCache[id];

  /// Creates a copy with updated fields.
  CommentThread copyWith({
    String? rootEventId,
    List<Comment>? comments,
    int? totalCount,
    bool? hasMore,
    bool? hasExactTotal,
    Map<String, Comment>? commentCache,
    int? nextOffset,
  }) => CommentThread(
    rootEventId: rootEventId ?? this.rootEventId,
    comments: comments ?? this.comments,
    totalCount: totalCount ?? this.totalCount,
    hasMore: hasMore ?? this.hasMore,
    hasExactTotal: hasExactTotal ?? this.hasExactTotal,
    commentCache: commentCache ?? this.commentCache,
    nextOffset: nextOffset ?? this.nextOffset,
  );

  @override
  List<Object?> get props => [
    rootEventId,
    comments,
    totalCount,
    hasMore,
    hasExactTotal,
    commentCache,
    nextOffset,
  ];
}
