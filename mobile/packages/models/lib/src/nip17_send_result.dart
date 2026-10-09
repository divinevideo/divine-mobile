// ABOUTME: Result type for NIP-17 encrypted message sending operations
// ABOUTME: Sealed class — Success carries per-wrap delivery state,
// ABOUTME: Failure carries the error and never carries selfWrapPublished

import 'package:meta/meta.dart';

/// Durable treatment for a queue row after a terminal policy refusal.
enum NIP17BlockedSendDisposition {
  /// Remove the row because the refused intent must not remain visible.
  discard,

  /// Keep the row as a visible, non-retryable record of the sender's intent.
  retain,
}

/// Result of NIP-17 encrypted message sending.
///
/// NIP-17 send is two independent publishes to relays:
///
/// 1. The **recipient** gift wrap (kind 1059), encrypted to the
///    recipient's pubkey. Without this, the recipient never sees the
///    message — its publish status is the headline success/failure
///    branch of this result.
/// 2. The **self-addressed** gift wrap (kind 1059), encrypted to the
///    sender's own pubkey. Without this, the sender's other devices
///    never see the message they just sent: the recipient gets it but
///    the sender's own conversation history won't have it after a
///    reinstall, account swap, or fresh login on a second device.
///
/// Use pattern matching (or the [success] / [selfWrapPublished]
/// getters) to handle each variant:
///
/// ```dart
/// switch (result) {
///   case NIP17SendSuccess(:final selfWrapPublished):
///     // recipient delivered; selfWrapPublished tells you whether
///     // the sender will see this message on other devices.
///   case NIP17SendFailure(:final error):
///     // recipient never received the message.
/// }
/// ```
///
/// Pre-existing callers that only check [success] continue to work
/// unchanged via the base-class getter. [selfWrapPublished] surfaces
/// partial delivery so a half-delivered send can be visibly
/// distinguished from a fully-delivered one. [queuedRumorId] identifies the
/// durable row when recovery must retry only the missing self-wrap without
/// re-publishing to the recipient.
sealed class NIP17SendResult {
  const NIP17SendResult();

  /// Build a success result. [selfWrapPublished] defaults to `true`
  /// so existing call sites that don't yet care about per-wrap status
  /// remain in the fully-delivered state. Pass `false` from the
  /// service layer when the self-addressed wrap could not be created
  /// or did not land on any relay.
  factory NIP17SendResult.success({
    required String rumorEventId,
    required String messageEventId,
    required String recipientPubkey,
    bool selfWrapPublished = true,
    String? queuedRumorId,
  }) => NIP17SendSuccess(
    rumorEventId: rumorEventId,
    messageEventId: messageEventId,
    recipientPubkey: recipientPubkey,
    selfWrapPublished: selfWrapPublished,
    queuedRumorId: queuedRumorId,
    timestamp: DateTime.now(),
  );

  /// Build a failure result.
  ///
  /// [retryablePending] marks a "soft" failure where the send should remain
  /// pending and be retried rather than turning into a hard failure. The usual
  /// case is a recipient wrap frame written to the relay with no NIP-20 `OK`
  /// within the window (and no explicit rejection): the send is *unconfirmed*,
  /// not proven-failed. It can also represent a bounded pre-publish crypto
  /// build timeout, such as a human-gated NIP-55 signer approval that has not
  /// returned yet. Defaults to `false` (a confirmed rejection or error).
  ///
  /// [queuedRumorId] is the durable `outgoing_dms` row the send left behind
  /// for the retry sweep — see [NIP17SendResult.queuedRumorId].
  const factory NIP17SendResult.failure(
    String error, {
    bool retryablePending,
    String? queuedRumorId,
  }) = NIP17SendFailure;

  /// Build a blocked result: a send that is refused for good, such as a policy
  /// block (protected-minor DM restriction, #176) or a queued one-to-one
  /// message addressed to its own sender (#8363). Unlike a transient failure, a
  /// blocked send must NOT be retried — retrying only re-hits the same refusal
  /// — so the UI surfaces distinct, no-retry copy.
  const factory NIP17SendResult.blocked(
    String error, {
    NIP17BlockedSendDisposition? disposition,
  }) = NIP17SendFailure.blocked;

  /// Build an oversized-message result (#7331): the rumor serializes to more
  /// than the NIP-44 double encryption can carry, so no wrap could be built.
  ///
  /// The size is a property of the rumor — its tags as much as its body — so
  /// every retry fails identically. Like [blocked] it must NOT be retried and
  /// leaves no queue row, and it is distinct from [blocked] because the user
  /// can act on it by shortening the message, which needs its own copy.
  const factory NIP17SendResult.tooLong(String error) =
      NIP17SendFailure.tooLong;

  /// Whether the recipient gift wrap (kind 1059, encrypted to the
  /// recipient) reached at least one relay. The headline send status.
  bool get success => this is NIP17SendSuccess;

  /// Whether this failure is a terminal refusal — a policy block (#176), or a
  /// queued message addressed to its own sender (#8363) — not a
  /// transient/network error. Blocked sends are not retriable. Always `false`
  /// for success.
  bool get blocked => false;

  /// How an existing durable row should be treated for a policy block.
  ///
  /// `null` for every result other than [NIP17SendFailure.blocked].
  NIP17BlockedSendDisposition? get blockedDisposition => null;

  /// Whether this failure is an oversized message (#7331), refused before any
  /// wrap was built. Not retriable — the size is a property of the rumor, so
  /// every retry fails identically. Always `false` for success.
  bool get tooLong => false;

  /// Whether a failure should stay in a pending, sweep-retryable state instead
  /// of being marked failed. Covers inconclusive recipient publishes
  /// (frame written, no relay `OK`, no explicit rejection) and bounded
  /// pre-publish crypto build timeouts where retry is still the honest outcome.
  bool get retryablePending => false;

  /// The `outgoing_dms` row this send left parked for recovery.
  ///
  /// On [NIP17SendFailure], a caller that wants to try the same message again
  /// must re-drive **this** row (`DmRepository.recoverFullSend`) rather than
  /// calling `sendMessage` again: a second call mints a fresh rumor and a
  /// second durable row, so the sweep and the retry each deliver a copy.
  /// Receiver-side gift-wrap dedup keys on the rumor id and cannot collapse
  /// two of them.
  ///
  /// `null` on a fully delivered success, on a [blocked] result (the send gate
  /// returns before the enqueue), and whenever the queue DAO is not wired in.
  /// On [NIP17SendSuccess] with [selfWrapPublished] false, a group send carries
  /// the surviving row so `recoverSelfWrap` can publish only the missing
  /// self-wrap without re-delivering to the recipient. A 1:1 partial success
  /// may omit it because its rumor event id is also its queue-row handle.
  String? get queuedRumorId => null;

  /// The rumor event ID (kind 14/15) — the canonical message
  /// identifier. Use this as the primary key when persisting sent
  /// messages. `null` on the failure branch.
  String? get rumorEventId;

  /// The recipient's gift wrap event ID (kind 1059). `null` on the
  /// failure branch.
  String? get messageEventId;

  /// Recipient's public key (hex). `null` on the failure branch.
  String? get recipientPubkey;

  /// Failure reason. `null` on the success branch.
  String? get error;

  /// When the result was constructed. `null` on the failure branch.
  DateTime? get timestamp;

  /// Whether the **self-addressed** gift wrap (kind 1059, encrypted
  /// to the sender's own pubkey) reached at least one relay.
  ///
  /// - `true` on [NIP17SendSuccess] when the self-wrap was published.
  ///   The recipient sees the message, and the sender's other devices
  ///   / future installs will see it after relay re-fetch.
  /// - `false` on [NIP17SendSuccess] when the self-wrap was not
  ///   published. The recipient saw the message but the sender will
  ///   not see this message after a reinstall or on a second device.
  ///   Surfaced so callers can persist enough state to act on it once
  ///   retry handling lands (see #3909). Re-publishing the recipient
  ///   wrap on retry would double-deliver, so any future retry must
  ///   target only the self-wrap.
  /// - `null` on [NIP17SendFailure] — the self-wrap is not attempted
  ///   when the recipient publish fails.
  bool? get selfWrapPublished;
}

/// Recipient gift wrap was published to at least one relay.
@immutable
final class NIP17SendSuccess extends NIP17SendResult {
  const NIP17SendSuccess({
    required this.rumorEventId,
    required this.messageEventId,
    required this.recipientPubkey,
    required this.selfWrapPublished,
    this.queuedRumorId,
    this.timestamp,
  });

  @override
  final String rumorEventId;

  @override
  final String messageEventId;

  @override
  final String recipientPubkey;

  @override
  final bool selfWrapPublished;

  @override
  final String? queuedRumorId;

  @override
  final DateTime? timestamp;

  @override
  String? get error => null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NIP17SendSuccess &&
        other.rumorEventId == rumorEventId &&
        other.messageEventId == messageEventId &&
        other.recipientPubkey == recipientPubkey &&
        other.selfWrapPublished == selfWrapPublished &&
        other.queuedRumorId == queuedRumorId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
    rumorEventId,
    messageEventId,
    recipientPubkey,
    selfWrapPublished,
    queuedRumorId,
    timestamp,
  );

  @override
  String toString() =>
      'NIP17SendSuccess(rumorEventId: $rumorEventId, '
      'messageEventId: $messageEventId, '
      'recipient: $recipientPubkey, '
      'selfWrapPublished: $selfWrapPublished, '
      'queuedRumorId: $queuedRumorId)';
}

/// Recipient gift wrap was not published — the message did not reach
/// the recipient at all. Self-wrap is not attempted on this branch.
@immutable
final class NIP17SendFailure extends NIP17SendResult {
  const NIP17SendFailure(
    this.error, {
    this.retryablePending = false,
    this.queuedRumorId,
  }) : blocked = false,
       _blockedDisposition = null,
       tooLong = false;

  /// A terminal refusal — a policy block (#176), or a queued message addressed
  /// to its own sender (#8363): same non-delivery as a failure, but not
  /// retriable.
  ///
  /// Never carries a [queuedRumorId]: the send gate returns before the
  /// enqueue, so a block leaves no row behind to coalesce onto.
  const NIP17SendFailure.blocked(
    this.error, {
    NIP17BlockedSendDisposition? disposition,
  }) : blocked = true,
       _blockedDisposition = disposition,
       tooLong = false,
       retryablePending = false,
       queuedRumorId = null;

  /// An oversized message (#7331): refused before any wrap build.
  ///
  /// Never carries a [queuedRumorId] — the size check runs before the enqueue,
  /// deliberately. A hard-failed row IS re-driven by
  /// `OutgoingDmRetryService.sweep()`, so leaving a row behind would spend the
  /// whole retry budget re-running a crypto chain that cannot succeed.
  const NIP17SendFailure.tooLong(this.error)
    : blocked = false,
      _blockedDisposition = null,
      tooLong = true,
      retryablePending = false,
      queuedRumorId = null;

  @override
  final String error;

  @override
  final bool blocked;

  final NIP17BlockedSendDisposition? _blockedDisposition;

  @override
  NIP17BlockedSendDisposition? get blockedDisposition => blocked
      ? _blockedDisposition ?? NIP17BlockedSendDisposition.discard
      : null;

  @override
  final bool tooLong;

  @override
  final bool retryablePending;

  @override
  final String? queuedRumorId;

  @override
  String? get rumorEventId => null;

  @override
  String? get messageEventId => null;

  @override
  String? get recipientPubkey => null;

  @override
  DateTime? get timestamp => null;

  @override
  bool? get selfWrapPublished => null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NIP17SendFailure &&
        other.error == error &&
        other.blocked == blocked &&
        other.blockedDisposition == blockedDisposition &&
        other.tooLong == tooLong &&
        other.retryablePending == retryablePending &&
        other.queuedRumorId == queuedRumorId;
  }

  @override
  int get hashCode => Object.hash(
    error,
    blocked,
    blockedDisposition,
    tooLong,
    retryablePending,
    queuedRumorId,
  );

  @override
  String toString() =>
      'NIP17SendFailure(error: $error, blocked: $blocked, '
      'blockedDisposition: $blockedDisposition, '
      'tooLong: $tooLong, '
      'retryablePending: $retryablePending, '
      'queuedRumorId: $queuedRumorId)';
}
