// ABOUTME: Stable identifiers for the local-storage swallow sites in
// ABOUTME: LikesRepository, used as the `site:` annotation on reporter calls.

/// Stable site identifiers for the best-effort local-storage swallow
/// points in `LikesRepository`. The wiring layer forwards each call to
/// Crashlytics with `reason: 'LikesRepository.<site>'` so the dashboard
/// aggregates per site.
///
/// Only programming-invariant violations (`Error` subtypes) reach the
/// reporter; expected IO and corruption failures stay in the unified log
/// per the decision matrix in `.claude/rules/error_handling.md`.
abstract class LikesRepositoryReportableSites {
  /// `_ensureInitialized`: reading the persisted like records threw, so the
  /// session continues on an in-memory-only cache.
  static const String ensureInitializedLoadRecords =
      'ensureInitialized.loadRecords';

  /// `likeEvent`: persisting the optimistic placeholder record threw.
  static const String likeEventSavePlaceholder = 'likeEvent.savePlaceholder';

  /// `likeEvent`: persisting the confirmed record (real reaction event id)
  /// threw after the Kind 7 publish landed.
  static const String likeEventSaveConfirmed = 'likeEvent.saveConfirmed';

  /// `likeEvent`: rolling the placeholder back after a publish failure
  /// threw, leaving a stale row behind.
  static const String likeEventRollbackPlaceholder =
      'likeEvent.rollbackPlaceholder';

  /// `unlikeEvent`: the fallback read of the like record threw, so the
  /// caller cannot tell "not liked" from "cannot tell".
  static const String unlikeEventReadRecord = 'unlikeEvent.readRecord';

  /// `unlikeEvent`: deleting the record ahead of the Kind 5 publish threw.
  static const String unlikeEventDeleteRecord = 'unlikeEvent.deleteRecord';

  /// `unlikeEvent`: restoring the record after a deletion-publish failure
  /// threw, so the optimistic removal is not undone locally.
  static const String unlikeEventRestoreRecord = 'unlikeEvent.restoreRecord';

  /// `toggleLike`: the authoritative already-liked read threw, so the toggle
  /// falls back to the in-memory cache to decide its direction.
  static const String toggleLikeReadState = 'toggleLike.readState';

  /// `syncUserReactions`: the warm read of persisted records threw, so the
  /// sync runs on relay data alone.
  static const String syncUserReactionsLoadRecords =
      'syncUserReactions.loadRecords';

  /// `syncUserReactions`: dropping a record whose reaction was deleted on
  /// the wire threw, so a stale row survives locally.
  static const String syncUserReactionsDeleteRecord =
      'syncUserReactions.deleteRecord';

  /// `syncUserReactions`: persisting the freshly-synced relay records threw.
  static const String syncUserReactionsSaveBatch =
      'syncUserReactions.saveBatch';

  /// `initialize`: the startup read of persisted records threw, so the
  /// session continues on an in-memory-only cache.
  static const String initializeLoadRecords = 'initialize.loadRecords';

  /// `_processIncomingReaction`: persisting a reaction that arrived on the
  /// live cross-device subscription threw.
  static const String processIncomingReactionSaveRecord =
      'processIncomingReaction.saveRecord';

  /// `likeEvent`: persisting a reaction adopted from the relay — this account
  /// already had a live `+` on the target (#7001) — threw.
  static const String likeEventSaveAdopted = 'likeEvent.saveAdopted';

  /// `executeLikeAction`: persisting a reaction adopted from the relay on
  /// replay (#7001) threw.
  static const String executeLikeActionSaveAdopted =
      'executeLikeAction.saveAdopted';

  /// `_adoptRemoteLikeRecord`: deleting a second local row that names the
  /// same adopted relay reaction under a superseded target id threw.
  static const String adoptRemoteLikeDeleteAlias =
      'adoptRemoteLike.deleteAlias';

  /// `_retractLikeUnlikedMidPublish`: dropping a retracted reaction that the
  /// live subscription or the startup snapshot had re-indexed (#7001) threw.
  static const String retractLikeDeleteEchoedRecord =
      'retractLike.deleteEchoedRecord';
}
