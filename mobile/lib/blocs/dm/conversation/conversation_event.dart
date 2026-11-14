// ABOUTME: Events for ConversationBloc.

part of 'conversation_bloc.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching messages in this conversation.
class ConversationStarted extends ConversationEvent {
  const ConversationStarted();
}

/// Send a message to the conversation recipients.
class ConversationMessageSent extends ConversationEvent {
  const ConversationMessageSent({
    required this.recipientPubkeys,
    required this.content,
  });

  final List<String> recipientPubkeys;
  final String content;

  @override
  List<Object?> get props => [recipientPubkeys, content];
}

/// Delete a sent message for everyone via NIP-09 kind 5.
class ConversationMessageDeleted extends ConversationEvent {
  const ConversationMessageDeleted({required this.rumorId});

  final String rumorId;

  @override
  List<Object?> get props => [rumorId];
}

/// Retry delivery of the stored delete-for-everyone rumor.
class ConversationMessageDeletionRetryRequested extends ConversationEvent {
  const ConversationMessageDeletionRetryRequested({required this.rumorId});

  final String rumorId;

  @override
  List<Object?> get props => [rumorId];
}

/// Re-publish only the sender self-addressed gift wraps for rumors
/// whose recipient publish landed but whose self-wrap did not.
///
/// Dispatched by the retry action on the `sentPartial` SnackBar. The
/// repository's [recoverSelfWrap] never republishes the recipient
/// wrap, so recipients are not re-delivered to. Carries the affected
/// [rumorIds] explicitly rather than reading them from state — the
/// handler stays decoupled from state shape and tests can act on the
/// event payload alone.
class ConversationSelfWrapRecoveryRequested extends ConversationEvent {
  const ConversationSelfWrapRecoveryRequested({required this.rumorIds});

  /// Rumor ids to re-publish self-wraps for. Sourced from
  /// [PartialSend.rumorIds] in the originating sentPartial state.
  final List<String> rumorIds;

  @override
  List<Object?> get props => [rumorIds];
}

/// Re-drive a previously-failed full send for the existing queue rows with
/// the given [rumorIds] via `DmRepository.recoverFullSend`.
///
/// This is the queue-aware manual retry: it replays the SAME rumor from the
/// durable `outgoing_dms` row (preserving `rumor.id` so NIP-17 receiver
/// dedup collapses any redundant copy). It must be used instead of
/// re-dispatching [ConversationMessageSent], which would build a fresh rumor
/// with a new id — leaving the old failed row still sweep-retryable and
/// risking a duplicate at the recipient.
///
/// Ids are sourced from the conversation's failed outgoing rows (a failed
/// bubble's id is its rumor id) either at SnackBar-Retry tap time or from a
/// per-bubble retry affordance.
class ConversationFullSendRecoveryRequested extends ConversationEvent {
  const ConversationFullSendRecoveryRequested({required this.rumorIds});

  /// Rumor ids of failed queue rows to replay in full.
  final List<String> rumorIds;

  @override
  List<Object?> get props => [rumorIds];
}

/// Stop a queued outgoing DM so the retry sweep no longer re-drives it.
/// Dispatched once per undelivered row by the failed bubble's "Stop trying"
/// action.
///
/// The row is dropped and the bubble disappears with it, unless the bubble is
/// a stored group message some members already have: then the row is kept as
/// the record that this member was not reached (#8180).
class ConversationOutgoingSendCancelled extends ConversationEvent {
  const ConversationOutgoingSendCancelled({required this.rumorId});

  /// Rumor id (== the failed bubble's id) of the queue row to drop.
  final String rumorId;

  @override
  List<Object?> get props => [rumorId];
}

/// Send [file] to [recipientPubkey] as a video DM in this conversation,
/// through the account's video outbox.
class ConversationVideoSendRequested extends ConversationEvent {
  const ConversationVideoSendRequested({
    required this.recipientPubkey,
    required this.file,
  });

  /// Hex public key of the recipient.
  final String recipientPubkey;

  /// The picked video file.
  final File file;

  @override
  List<Object?> get props => [recipientPubkey, file];
}

/// Send library [clips] to [recipientPubkey] in this conversation, through
/// the account's video outbox.
class ConversationClipsSendRequested extends ConversationEvent {
  const ConversationClipsSendRequested({
    required this.recipientPubkey,
    required this.clips,
  });

  /// Hex public key of the recipient.
  final String recipientPubkey;

  /// The picked library clips, in send order.
  final List<DivineVideoClip> clips;

  @override
  List<Object?> get props => [recipientPubkey, clips];
}

/// Retry the failed outgoing video DM [id].
class ConversationVideoSendRetried extends ConversationEvent {
  const ConversationVideoSendRetried(this.id);

  /// The outbox entry id.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Discard the failed outgoing video DM [id].
class ConversationVideoSendRemoved extends ConversationEvent {
  const ConversationVideoSendRemoved(this.id);

  /// The outbox entry id.
  final String id;

  @override
  List<Object?> get props => [id];
}
