part of 'comment_reactions_bloc.dart';

/// l10n-friendly reactions-side errors.
///
/// The UI maps these to localized strings via [BlocListener].
enum ReactionsError {
  /// User must sign in to vote / block / delete.
  notAuthenticated,

  /// Failed to toggle vote on a comment.
  voteFailed,

  /// Failed to block a user.
  blockFailed,

  /// Failed to delete a comment.
  deleteCommentFailed,
}

/// One-shot signal from [CommentReactionsBloc] to UI: dispatch the
/// corresponding event onto [CommentsListBloc] then ack via
/// [ReactionsOutboxConsumed].
sealed class ReactionsOutbox extends Equatable {
  const ReactionsOutbox();

  @override
  bool? get stringify => true;
}

/// Remove a single comment from the canonical store (post-delete cleanup).
final class ReactionsOutboxRemoveComment extends ReactionsOutbox {
  const ReactionsOutboxRemoveComment(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

/// Remove every comment authored by [authorPubkey] (post-block cleanup).
final class ReactionsOutboxRemoveByAuthor extends ReactionsOutbox {
  const ReactionsOutboxRemoveByAuthor(this.authorPubkey);

  final String authorPubkey;

  @override
  List<Object?> get props => [authorPubkey];
}

/// State for [CommentReactionsBloc].
final class CommentReactionsState extends Equatable {
  const CommentReactionsState({
    this.commentUpvoteCounts = const {},
    this.commentDownvoteCounts = const {},
    this.upvotedCommentIds = const {},
    this.downvotedCommentIds = const {},
    this.error,
    this.outbox,
  });

  /// Upvote counts per comment ID.
  final Map<String, int> commentUpvoteCounts;

  /// Downvote counts per comment ID.
  final Map<String, int> commentDownvoteCounts;

  /// Set of comment IDs the current user has upvoted.
  final Set<String> upvotedCommentIds;

  /// Set of comment IDs the current user has downvoted.
  final Set<String> downvotedCommentIds;

  /// Error type for l10n-friendly error handling.
  final ReactionsError? error;

  /// One-shot signal for the UI to bridge into [CommentsListBloc].
  final ReactionsOutbox? outbox;

  CommentReactionsState copyWith({
    Map<String, int>? commentUpvoteCounts,
    Map<String, int>? commentDownvoteCounts,
    Set<String>? upvotedCommentIds,
    Set<String>? downvotedCommentIds,
    ReactionsError? error,
    ReactionsOutbox? outbox,
    bool clearError = false,
    bool clearOutbox = false,
  }) {
    return CommentReactionsState(
      commentUpvoteCounts: commentUpvoteCounts ?? this.commentUpvoteCounts,
      commentDownvoteCounts:
          commentDownvoteCounts ?? this.commentDownvoteCounts,
      upvotedCommentIds: upvotedCommentIds ?? this.upvotedCommentIds,
      downvotedCommentIds: downvotedCommentIds ?? this.downvotedCommentIds,
      error: clearError ? null : (error ?? this.error),
      outbox: clearOutbox ? null : (outbox ?? this.outbox),
    );
  }

  @override
  List<Object?> get props => [
    commentUpvoteCounts,
    commentDownvoteCounts,
    upvotedCommentIds,
    downvotedCommentIds,
    error,
    outbox,
  ];
}
