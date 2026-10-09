// ABOUTME: Stable identifiers for the failures DmReactionsRepository reports.
// ABOUTME: Used as the `site:` annotation on the reporter port calls. Per
// ABOUTME: the error-handling matrix, only DAO-layer invariants reach
// ABOUTME: Crashlytics — network/IO publish failures stay local.

/// Stable site identifiers for the failures `DmReactionsRepository`
/// reports. The wiring layer forwards each call to
/// Crashlytics with `reason: 'DmReactionsRepository.<site>'` so the
/// dashboard aggregates per site.
abstract class DmReactionsRepositoryReportableSites {
  /// `persistIncoming`: DAO upsert threw despite valid event shape.
  /// Programming-invariant violation — the validator above passed.
  static const String persistIncomingDaoUpsert = 'persistIncoming.daoUpsert';

  /// `applyDeletion`: DAO soft-delete threw despite a validated matching
  /// reaction row.
  ///
  /// The wire value still says `handleIncomingDeletion` — the method's name
  /// before #7809 split message routing out of it. Crashlytics aggregates on
  /// this string, so renaming it would fork the dashboard history for a
  /// failure whose cause has not changed.
  static const String handleIncomingDeletionSoftDelete =
      'handleIncomingDeletion.softDelete';

  /// `publish`: optimistic DAO insert threw before any send attempt.
  /// Programming-invariant violation — placeholder ids are uuid-shaped
  /// and the row is fresh.
  static const String publishOptimisticInsert = 'publish.optimisticInsert';

  /// `publish`: send succeeded but the placeholder-id swap threw.
  /// The row stays in `pending` state and won't refresh to `sent` until
  /// the next app start picks up the rescue sweep.
  static const String publishSwapPlaceholder = 'publish.swapPlaceholder';

  /// `removeOwn`: building or recording the removal (the soft-delete and its
  /// stored kind-5) threw. Nothing was sent and the reaction stays as it was;
  /// the error is rethrown so the caller can show the reaction again.
  static const String removeOwnSoftDelete = 'removeOwn.softDelete';

  /// `publish`: building or recording the durable `deletion_pending` row for a
  /// superseded prior reaction (cap-at-one emoji swap) threw. The new reaction
  /// still publishes; the superseded emoji's kind-5 removal is lost (#9915).
  static const String publishSupersedeDeletion = 'publish.supersedeDeletion';

  /// `publish`: reading a superseded prior reaction's row, to see who it was
  /// sent to, threw. Its removal is recorded, if that write succeeds, and
  /// held for the retry sweep, which reads the row again.
  static const String publishSupersedeRecipients =
      'publish.supersedeRecipients';

  /// Recording a queue row's resolved gift-wrap recipients threw. A send in
  /// progress still goes to the resolved set; the row stays without one and
  /// is resolved again on its next attempt, which for a superseded reaction's
  /// removal no longer includes the replacing reaction's recipients.
  static const String wrapRecipientsStore = 'wrapRecipients.store';

  /// Reading the conversation a reaction belongs to, for its participants,
  /// threw. Nothing is concluded from the failure: the recipients come from
  /// what can still be proven, and otherwise the send is held. A superseded
  /// reaction's removal is held in that case too, with nothing recorded.
  static const String wrapRecipientsConversationRead =
      'wrapRecipients.conversationRead';

  /// Reading the reacted message, for the room it names, threw. The send is
  /// held, with nothing recorded, and looked at again on its next attempt.
  static const String wrapRecipientsTargetMessageRead =
      'wrapRecipients.targetMessageRead';
}
