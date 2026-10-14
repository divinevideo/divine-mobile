part of 'comment_reactions_bloc.dart';

/// Base class for all reactions events.
sealed class CommentReactionsEvent {
  const CommentReactionsEvent();
}

/// Clear any error message.
final class CommentReactionsErrorCleared extends CommentReactionsEvent {
  const CommentReactionsErrorCleared();
}

/// Direction of a comment vote.
enum Vote {
  /// Upvote (kind-7 reaction with content "+").
  up,

  /// Downvote (kind-7 reaction with content "-").
  down,
}

/// Toggle a vote on a comment (optimistic update + relay publish).
///
/// A single event for both upvotes and downvotes so that one `droppable()`
/// handler serializes all votes — same-comment rapid up→down (or down→up)
/// within publish-RTT can no longer run two handlers concurrently and produce
/// interleaved kind-7 / kind-5 publishes on the relay.
final class CommentVoteToggled extends CommentReactionsEvent {
  const CommentVoteToggled({
    required this.commentId,
    required this.authorPubkey,
    required this.vote,
    this.addressableId,
    this.targetKind,
  });

  /// The ID of the comment being voted on.
  final String commentId;

  /// The pubkey of the comment author.
  final String authorPubkey;

  /// Whether this is an upvote or a downvote tap.
  final Vote vote;

  /// The target's **own** addressable coordinate, when it has one.
  ///
  /// A Kind 34236 video reply is addressable, and an edit re-publishes it
  /// under the same coordinate with a new event id — so without this the
  /// reaction strands on the superseded id (#6124). Null for Kind 1111
  /// comments, which are regular events.
  final String? addressableId;

  /// The kind of the event being reacted to, for NIP-25's `k` tag.
  ///
  /// Null when the source did not report one, in which case the handler falls
  /// back to [EventKind.comment].
  final int? targetKind;
}

/// Request to batch-fetch vote counts for a set of comments.
///
/// Dispatched by the UI (via a [BlocListener] on [CommentsListBloc]) whenever
/// the loaded-comment set changes so the reactions cubit can populate counts
/// for the visible list.
final class CommentVoteCountsFetchRequested extends CommentReactionsEvent {
  const CommentVoteCountsFetchRequested(
    this.commentIds, {
    this.addressableIdsByCommentId = const {},
  });

  /// The set of comment IDs to fetch vote counts for.
  final List<String> commentIds;

  /// Own addressable coordinates for those of [commentIds] that have one,
  /// keyed by comment id.
  ///
  /// Votes on an addressable target carry its coordinate, and an edit mints a
  /// new event id — so without this the counts and the viewer's own arrow
  /// read as zero/unvoted for every revision after the first (#6124). Empty
  /// for threads of plain Kind 1111 comments.
  final Map<String, String> addressableIdsByCommentId;
}

/// Block a user from comments (updates Kind 10000 mute list / NIP-51).
///
/// After the persist + relay broadcast succeeds, the reactions bloc emits a
/// [ReactionsOutboxRemoveByAuthor] signal that the UI bridges to
/// [CommentsListBloc] for store cleanup.
final class CommentBlockUserRequested extends CommentReactionsEvent {
  const CommentBlockUserRequested(this.authorPubkey);

  /// The pubkey of the user to block.
  final String authorPubkey;
}

/// Request to delete a comment.
///
/// After the relay broadcast succeeds, the reactions bloc emits a
/// [ReactionsOutboxRemoveComment] signal that the UI bridges to
/// [CommentsListBloc] for store cleanup.
final class CommentDeleteRequested extends CommentReactionsEvent {
  const CommentDeleteRequested(this.commentId);

  /// The ID of the comment to delete.
  final String commentId;
}

/// Acknowledge that the UI has bridged the current [ReactionsOutbox] item to
/// [CommentsListBloc]. Clears [CommentReactionsState.outbox] back to null.
final class ReactionsOutboxConsumed extends CommentReactionsEvent {
  const ReactionsOutboxConsumed();
}
