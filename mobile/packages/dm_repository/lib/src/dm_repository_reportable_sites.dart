// ABOUTME: Stable identifiers for the swallow sites in DmRepository.
// ABOUTME: Used as the `site:` annotation on DmRepositoryErrorReporter calls.

/// Stable site identifiers for the DAO-bookkeeping swallow points in
/// `DmRepository`. The wiring layer forwards each call to Crashlytics
/// with `reason: 'DmRepository.<site>'` so the dashboard aggregates per
/// site.
abstract class DmRepositoryReportableSites {
  /// `recoverSelfWrap`: `Event.fromJson(row.rumorEventJson)` threw.
  /// Programming-invariant violation — the repository wrote that JSON.
  static const String recoverSelfWrapRumorJsonParse =
      'recoverSelfWrap.rumorJsonParse';

  /// `recoverSelfWrap`: the salvage `markSelfWrapStatus(failed)` after
  /// a JSON parse failure also threw. Silent inner swallow today.
  static const String recoverSelfWrapMarkFailedAfterJsonParse =
      'recoverSelfWrap.markFailedAfterJsonParse';

  /// `recoverSelfWrap`: publish landed; `deleteById` threw. The
  /// fallback `markSelfWrapStatus(sent)` is attempted next.
  static const String recoverSelfWrapDeleteAfterPublish =
      'recoverSelfWrap.deleteAfterPublish';

  /// `recoverSelfWrap`: publish landed; both `deleteById` and the
  /// fallback `markSelfWrapStatus(sent)` threw. The doubly-degraded
  /// path — primary target of #4127.
  static const String recoverSelfWrapBookkeepingDoubleFailure =
      'recoverSelfWrap.bookkeepingDoubleFailure';

  /// `recoverSelfWrap`: publish failed; the salvage
  /// `markSelfWrapStatus(failed)` threw.
  static const String recoverSelfWrapMarkFailedAfterPublishFailure =
      'recoverSelfWrap.markFailedAfterPublishFailure';

  /// `_finalizeAfterRecipientFailure`: marking the queue row failed
  /// threw. Caller already has the publish-failure result.
  static const String finalizeAfterRecipientFailure =
      'finalizeAfterRecipientFailure';

  /// `_finalizeAfterRecipientBlocked`: terminalizing the policy-blocked queue
  /// row threw. Caller already has the blocked result.
  static const String finalizeAfterRecipientBlocked =
      'finalizeAfterRecipientBlocked';

  /// `_finalizeAfterRecipientUnconfirmed`: bumping the retry count for a
  /// soft, retryable-pending send threw. Caller already has the
  /// retryable-pending result; the row stays pending and the next sweep
  /// re-drives it.
  static const String finalizeAfterRecipientUnconfirmed =
      'finalizeAfterRecipientUnconfirmed';

  /// `_holdFallbackPoolDelivery` or `_recordHeldDeletionWrap`: recording on a
  /// held message row, or on a held retraction, the recipient wrap the
  /// fallback pool accepted threw. Caller still gets the retryable-pending
  /// result; the next retry republishes, as it did before #10012.
  static const String recordHeldPoolWrap = 'recordHeldPoolWrap';

  /// `_chargeFailedReplay`: bumping the retry count for a failed
  /// `recoverFullSend` / `recoverSelfWrap` attempt threw. The caller already
  /// has the failure result; a missed bump only means one extra retry.
  static const String chargeFailedReplay = 'chargeFailedReplay';

  /// `retryPendingCollaboratorInvites*`: `recoverFullSend` threw an
  /// unexpected error while replaying a queued collaborator invite row.
  /// The expected `ArgumentError` race (row deleted by a concurrent drain
  /// sweep, or a foreign-owner row) is skipped and does NOT report here.
  static const String retryPendingCollaboratorInviteUnexpectedThrow =
      'retryPendingCollaboratorInvite.unexpectedThrow';

  /// A repository-owned background transport threw outside its domain result.
  /// The durable row remains available for recovery.
  static const String backgroundDeliveryUnexpectedThrow =
      'backgroundDelivery.unexpectedThrow';

  /// `sendMessage` outer transaction catch: persisting the local
  /// message row or running `_finalizeAfterRecipientSuccess` threw
  /// after the recipient publish landed.
  static const String sendMessageOuterTransaction =
      'sendMessage.outerTransaction';

  /// `sendGroupMessage`: parking one sibling's `outgoing_dms` row threw.
  /// The batch is unwound before publish so no sibling is silently dropped.
  static const String sendGroupMessageEnqueueSibling =
      'sendGroupMessage.enqueueSibling';

  /// `sendGroupMessage`: after one sibling failed to enqueue, deleting a
  /// sibling already parked for that same not-yet-published batch also threw.
  /// The row survives and is returned to the caller as a retry handle.
  static const String sendGroupMessageUnwindQueuedSibling =
      'sendGroupMessage.unwindQueuedSibling';

  /// `backfillHistoryIfNeeded`: the history drain hit a programming
  /// invariant failure while paging or processing recovered events.
  static const String historyDrainUnexpectedFailure =
      'historyDrain.unexpectedFailure';

  /// The catch-up debt walk, or the save that records the debt before it
  /// moves the window, hit a programming invariant failure.
  static const String catchUpDebtUnexpectedFailure =
      'catchUpDebt.unexpectedFailure';

  /// `retryPendingDecryptions`: a queued gift wrap's stored JSON failed to
  /// parse. We wrote that JSON ourselves, so this is an invariant violation,
  /// and it costs the user an inbound message.
  static const String pendingDecryptCorruptPayload =
      'retryPendingDecryptions.corruptPayload';

  /// `retryPendingDecryptions`: gift wraps exhausted the decrypt retry cap
  /// and were deleted. Each one is an inbound DM the user will never see,
  /// and the wrap carries no decryptable sender or conversation, so there is
  /// nothing to surface in the UI — this is the only signal that it happened.
  ///
  /// Reported once per drain pass with an aggregate count, never per wrap, so
  /// a spam burst of undecryptable kind-1059 events costs one event rather
  /// than one per wrap. After #5202 and the decrypt-retry fix on this branch,
  /// reaching the cap at all should be exceptional — if this turns out to be
  /// routine in the dashboard, that is the finding, not noise to suppress.
  static const String pendingDecryptExhausted =
      'retryPendingDecryptions.exhausted';
}
