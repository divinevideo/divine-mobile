// ABOUTME: Events for VideoInteractionsBloc
// ABOUTME: Handles like toggle, count fetching for a single video

part of 'video_interactions_bloc.dart';

/// Base class for video interactions events.
sealed class VideoInteractionsEvent extends Equatable {
  const VideoInteractionsEvent();

  @override
  List<Object?> get props => [];
}

/// Request to fetch initial state (like status and counts).
///
/// Dispatched when the video feed item becomes visible/active.
class VideoInteractionsFetchRequested extends VideoInteractionsEvent {
  const VideoInteractionsFetchRequested();
}

/// Request to toggle like status.
///
/// Will like if not liked, unlike if already liked.
class VideoInteractionsLikeToggled extends VideoInteractionsEvent {
  const VideoInteractionsLikeToggled();
}

/// Request to toggle repost status.
///
/// Will repost if not reposted, unrepost if already reposted.
class VideoInteractionsRepostToggled extends VideoInteractionsEvent {
  const VideoInteractionsRepostToggled();
}

/// Request to start listening for liked IDs changes from the repository.
///
/// This should be dispatched once when the video feed item is initialized.
/// Uses emit.forEach internally to reactively update state when likes change.
class VideoInteractionsSubscriptionRequested extends VideoInteractionsEvent {
  const VideoInteractionsSubscriptionRequested();
}

/// Updates the comment count from an authoritative source.
///
/// Dispatched when the comments sheet is dismissed, carrying the actual
/// loaded comment count from `CommentsListBloc` so the feed sidebar stays
/// in sync without an extra relay round-trip.
class VideoInteractionsCommentCountUpdated extends VideoInteractionsEvent {
  const VideoInteractionsCommentCountUpdated(this.commentCount);

  /// The updated total comment count.
  final int commentCount;

  @override
  List<Object?> get props => [commentCount];
}

/// Internal event dispatched when a fire-and-forget like publish settles.
///
/// `_onLikeToggled` emits the optimistic state and returns immediately,
/// scheduling the publish via [Future]. When the publish settles, the
/// publisher dispatches this event so the bloc can reconcile state
/// inside a normal handler with a real [Emitter].
class _VideoInteractionsLikeSettled extends VideoInteractionsEvent {
  const _VideoInteractionsLikeSettled({
    required this.outcome,
    required this.wasCount,
    required this.revision,
  });

  final _LikeSettleOutcome outcome;
  final int? wasCount;
  final int revision;

  @override
  List<Object?> get props => [outcome, wasCount, revision];
}

/// Internal event dispatched when a fire-and-forget repost publish settles.
class _VideoInteractionsRepostSettled extends VideoInteractionsEvent {
  const _VideoInteractionsRepostSettled({
    required this.outcome,
    required this.wasCount,
  });

  final _RepostSettleOutcome outcome;
  final int? wasCount;

  @override
  List<Object?> get props => [outcome, wasCount];
}

/// Outcome of a fire-and-forget like publish.
sealed class _LikeSettleOutcome extends Equatable {
  const _LikeSettleOutcome();

  @override
  List<Object?> get props => const [];
}

/// Publish succeeded; repository now agrees with the optimistic state.
class _LikeSettleConfirmed extends _LikeSettleOutcome {
  const _LikeSettleConfirmed({required this.isLiked});

  final bool isLiked;

  @override
  List<Object?> get props => [isLiked];
}

/// Publish succeeded but the repository ended up in a different state
/// (e.g. another device flipped the like mid-tap).
class _LikeSettleOutOfBand extends _LikeSettleOutcome {
  const _LikeSettleOutOfBand({required this.actualIsLiked});

  final bool actualIsLiked;

  @override
  List<Object?> get props => [actualIsLiked];
}

/// Repository reported the event was already liked — the optimistic flip
/// to liked is correct, no transition occurred.
class _LikeSettleAlready extends _LikeSettleOutcome {
  const _LikeSettleAlready();
}

/// Repository reported the event was not liked — the optimistic flip to
/// unliked is correct, no transition occurred.
class _LikeSettleNotLiked extends _LikeSettleOutcome {
  const _LikeSettleNotLiked();
}

/// Publish threw an unexpected error — revert to the pre-tap baseline.
class _LikeSettleFailed extends _LikeSettleOutcome {
  const _LikeSettleFailed({required this.wasLiked});

  final bool wasLiked;

  @override
  List<Object?> get props => [wasLiked];
}

/// The authoritative relay rejected the action for account policy.
class _LikeSettleRestricted extends _LikeSettleOutcome {
  const _LikeSettleRestricted({required this.wasLiked});

  final bool wasLiked;

  @override
  List<Object?> get props => [wasLiked];
}

/// Outcome of a fire-and-forget repost publish.
sealed class _RepostSettleOutcome extends Equatable {
  const _RepostSettleOutcome();

  @override
  List<Object?> get props => const [];
}

/// Publish succeeded; repository now agrees with the optimistic state.
class _RepostSettleConfirmed extends _RepostSettleOutcome {
  const _RepostSettleConfirmed();
}

/// Publish succeeded but the repository ended up in a different state.
class _RepostSettleOutOfBand extends _RepostSettleOutcome {
  const _RepostSettleOutOfBand({required this.actualIsReposted});

  final bool actualIsReposted;

  @override
  List<Object?> get props => [actualIsReposted];
}

/// Repository reported the video was already reposted.
class _RepostSettleAlready extends _RepostSettleOutcome {
  const _RepostSettleAlready();
}

/// Repository reported the video was not reposted.
class _RepostSettleNotReposted extends _RepostSettleOutcome {
  const _RepostSettleNotReposted();
}

/// Publish threw an unexpected error — revert to the pre-tap baseline.
class _RepostSettleFailed extends _RepostSettleOutcome {
  const _RepostSettleFailed({required this.wasReposted});

  final bool wasReposted;

  @override
  List<Object?> get props => [wasReposted];
}
