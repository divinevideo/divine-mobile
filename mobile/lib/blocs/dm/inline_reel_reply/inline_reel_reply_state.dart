part of 'inline_reel_reply_cubit.dart';

/// Lifecycle of a single reel-reply submit round-trip.
enum InlineReelReplyStatus {
  /// No send in flight; the bar can accept a new reply.
  initial,

  /// A send is awaiting its outcome.
  sending,

  /// The most recent reply send succeeded.
  success,

  /// The most recent reply send failed (queued for retry).
  failure,

  /// Refused before enqueue because the rumor was too large. There is no
  /// durable row to re-drive, and retrying unchanged content cannot succeed.
  tooLong,

  /// A retry found its parked row gone, and delivery can be neither confirmed
  /// nor re-driven.
  ///
  /// `recoverFullSend` raises `ArgumentError` both when the row has been
  /// consumed (the sweep may already have delivered it, or the user deleted
  /// it) and when it belongs to another account, so the outcome is genuinely
  /// unknown. Distinct from [success] because nothing proved delivery, and
  /// from [failure] because there is no row left to retry — offering one
  /// would fall through to a fresh send and mint the duplicate this flow
  /// exists to prevent.
  unverifiable,
}

/// State for [InlineReelReplyCubit] — the lifecycle status plus the durable
/// rows a failed send left parked. The composed text lives in the View's
/// [TextEditingController].
class InlineReelReplyState extends Equatable {
  /// Construct a state.
  const InlineReelReplyState({
    this.status = InlineReelReplyStatus.initial,
    this.queuedRumorIds = const [],
  });

  /// Current send lifecycle status.
  final InlineReelReplyStatus status;

  /// The `outgoing_dms` rows the last failed send left parked — one per
  /// recipient that came back carrying a `NIP17SendResult.queuedRumorId`.
  ///
  /// Empty when there is nothing to re-drive: a policy-blocked send returns
  /// before the enqueue, and an unwired queue DAO never creates a row at all.
  /// Retrying on an empty list falls back to a fresh send, which is safe
  /// precisely because no row exists that could deliver a second copy.
  ///
  /// This is a *snapshot for the View to capture*, not a live handle for a
  /// retry to read back. It describes the most recent send only, so a later
  /// success clears it while an earlier failure's rows may still be parked.
  /// Whoever offers a retry must capture this list at that moment and pass it
  /// to [InlineReelReplyCubit.retry] — see that method for what reading the
  /// live value instead would cost.
  final List<String> queuedRumorIds;

  /// Copy with an updated [status] and/or [queuedRumorIds].
  InlineReelReplyState copyWith({
    InlineReelReplyStatus? status,
    List<String>? queuedRumorIds,
  }) => InlineReelReplyState(
    status: status ?? this.status,
    queuedRumorIds: queuedRumorIds ?? this.queuedRumorIds,
  );

  @override
  List<Object?> get props => [status, queuedRumorIds];
}
