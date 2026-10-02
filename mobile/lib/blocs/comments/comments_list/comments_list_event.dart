part of 'comments_list_bloc.dart';

/// Base class for all comments-list events.
sealed class CommentsListEvent {
  const CommentsListEvent();
}

/// Request to load (or refresh) comments for a video.
final class CommentsLoadRequested extends CommentsListEvent {
  const CommentsLoadRequested();
}

/// Request to load more (older) comments for pagination.
final class CommentsLoadMoreRequested extends CommentsListEvent {
  const CommentsLoadMoreRequested();
}

/// Change the sort order for comments.
final class CommentsSortModeChanged extends CommentsListEvent {
  const CommentsSortModeChanged(this.sortMode);

  final CommentsSortMode sortMode;
}

/// A new comment was received from the real-time subscription.
final class NewCommentReceived extends CommentsListEvent {
  const NewCommentReceived(this.comment);

  /// The new comment received from the stream.
  final Comment comment;
}

/// The initial relay backfill reached EOSE; subsequent events are live.
final class CommentsInitialBackfillCompleted extends CommentsListEvent {
  const CommentsInitialBackfillCompleted();
}

/// User acknowledged the new comments (e.g., tapped the pill or scrolled to top).
final class NewCommentsAcknowledged extends CommentsListEvent {
  const NewCommentsAcknowledged();
}

/// Clear any transient error.
final class CommentsListErrorCleared extends CommentsListEvent {
  const CommentsListErrorCleared();
}

/// The UI has scrolled the [CommentsListState.scrollToCommentId] target into
/// view; clear the one-shot signal so it doesn't re-fire on the next rebuild.
final class CommentsScrollHandled extends CommentsListEvent {
  const CommentsScrollHandled();
}

// Cross-bloc store-mutation intents. Dispatched by the UI in response to
// outbox signals from [CommentComposerBloc] and [CommentReactionsBloc]. The
// list bloc owns the canonical [Comment] store; these events are the only
// path through which other blocs can mutate it, preserving the rule that
// BLoCs do not depend on or dispatch to each other (see
// rules/state_management.md).

/// Insert an optimistic placeholder comment.
final class OptimisticCommentInserted extends CommentsListEvent {
  const OptimisticCommentInserted(this.placeholder);

  final Comment placeholder;
}

/// Replace a placeholder with its confirmed canonical comment.
///
/// Race-safe: if the canonical comment is already in the store (because the
/// relay echo arrived first via [NewCommentReceived]), the handler removes
/// any leftover placeholder and is otherwise a no-op.
final class OptimisticCommentConfirmed extends CommentsListEvent {
  const OptimisticCommentConfirmed({
    required this.placeholderId,
    required this.confirmed,
  });

  final String placeholderId;
  final Comment confirmed;
}

/// Roll back a placeholder after publish failed.
final class OptimisticCommentRolledBack extends CommentsListEvent {
  const OptimisticCommentRolledBack(this.placeholderId);

  final String placeholderId;
}

/// Replace an existing comment with a fresh canonical one (edit flow).
final class CommentReplacedInStore extends CommentsListEvent {
  const CommentReplacedInStore({required this.oldId, required this.newComment});

  final String oldId;
  final Comment newComment;
}

/// Remove a single comment from the store (post-delete cleanup).
final class CommentRemovedFromStore extends CommentsListEvent {
  const CommentRemovedFromStore(this.commentId);

  final String commentId;
}

/// A live NIP-09 deletion request named a comment. The comment is removed only
/// when the request applies to it, that is when its author signed it.
final class CommentDeletionReceived extends CommentsListEvent {
  const CommentDeletionReceived(this.deletion);

  final CommentDeletion deletion;
}

/// Remove every comment authored by [authorPubkey] (post-block cleanup).
final class CommentsRemovedByAuthorFromStore extends CommentsListEvent {
  const CommentsRemovedByAuthorFromStore(this.authorPubkey);

  final String authorPubkey;
}
