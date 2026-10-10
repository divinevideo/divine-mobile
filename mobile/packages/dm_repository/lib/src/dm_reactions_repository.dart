// ABOUTME: Repository for NIP-25 emoji reactions on NIP-17 DMs.
// ABOUTME: Reactions ride the same seal+gift-wrap envelope as DM
// ABOUTME: messages — kind 7 rumor wrapped to recipient + self. Privacy
// ABOUTME: comes from envelope reuse, not a custom kind or scheme.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/src/dm_reactions_repository_reportable_sites.dart';
import 'package:dm_repository/src/dm_repository.dart';
import 'package:dm_repository/src/group_conversation_recovery.dart';
import 'package:dm_repository/src/nip17_message_service.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reporter port for forwarding DAO-layer surprises to Crashlytics.
///
/// Wired in the app layer to `CrashReportingService.instance.recordError`.
/// Network/IO failures from `sendRumor` are NOT routed through this —
/// only DAO surprises are Reportable per the error-handling matrix.
typedef DmReactionsRepositoryErrorReporter =
    void Function(Object error, StackTrace stackTrace, {required String site});

/// Public outcome of an outgoing reaction publish attempt.
@immutable
class DmReactionPublishResult {
  /// Construct a publish result.
  const DmReactionPublishResult({
    required this.success,
    required this.rumorId,
    this.errorMessage,
    this.optimisticInsertSucceeded = false,
  });

  /// Whether the gift-wrap publish landed for the recipient.
  final bool success;

  /// The reaction rumor id used. Stable across retries.
  final String rumorId;

  /// One-line summary for logs; never user-facing copy.
  final String? errorMessage;

  /// Whether the durable optimistic row was written to the DAO before the
  /// publish attempt. When `true`, even a failed publish leaves a persisted
  /// row the chip render + retry sweep can recover — so the cubit keeps the
  /// optimistic chip instead of dropping it as an orphan while the DAO stream
  /// catches up. `false` only when the repo was uninitialized or the insert
  /// itself failed (no durable row exists).
  final bool optimisticInsertSucceeded;
}

/// Outcome of one own-reaction deletion delivery attempt.
enum DmReactionDeletionOutcome {
  /// Every recipient confirmed the kind-5 wrap.
  sent,

  /// Every failed recipient was refused by send policy. Automatic retries
  /// stop, while the retained rumor remains available for a user retry.
  refused,

  /// Delivery was not confirmed. The pending row remains sweep-retryable.
  unconfirmed,

  /// No initialized repository or stored deletion was available to drive.
  unavailable,
}

/// Outcome of ingesting an incoming wrapped rumor — a reaction, or a kind-5
/// deletion targeting either a reaction or a message — used by `DmRepository`
/// to decide whether to record the gift wrap in the processed-wrap dedup
/// ledger (#5452).
enum DmWrapOutcome {
  /// The wrap reached a terminal state — persisted, or permanently dropped for
  /// a reason that will not change (malformed content/tags, author mismatch).
  /// Safe to record so the wrap is never re-decrypted.
  processed,

  /// The wrap could not be applied yet: the signer is not ready, or the target
  /// the rumor names has not synced. Must NOT be recorded so it re-decrypts on
  /// a later launch once the target exists — preserving eventual consistency.
  ///
  /// Prefer this whenever the outcome is in doubt. `ProcessedGiftWrapsDao`
  /// reads the ledger globally rather than per-owner, so a wrap recorded
  /// terminally by mistake is suppressed for *every* account on the device,
  /// and switching accounts away and back does not recover it.
  deferred,
}

/// A pending/failed own reaction the retry sweep can re-drive, projected from
/// its `dm_message_reactions` row.
@immutable
class DmReactionRetryTarget {
  /// Construct a retry target.
  const DmReactionRetryTarget({
    required this.rumorId,
    required this.targetMessageAuthor,
    required this.publishStatus,
    required this.createdAt,
  });

  /// Reaction rumor id — the argument `retry` expects.
  final String rumorId;

  /// Author of the reacted message. It does not choose the recipients: they
  /// come from the row, and the author only helps prove a 1:1 when the row
  /// stores none.
  final String targetMessageAuthor;

  /// Persisted publish status: `'failed'` or `'pending'`.
  final String publishStatus;

  /// Rumor `created_at` (unix seconds). Lets the sweep hold back a still-in-
  /// flight `'pending'` reaction until its original publish has resolved.
  final int createdAt;
}

/// Resolves [pubkey]'s NIP-17 kind-10050 DM inbox relays, and says why the
/// lookup returned what it did.
///
/// A function port rather than a `DmRepository` reference: `dmRepository`'s
/// provider already watches `dmReactionsRepositoryProvider`
/// (`repository_providers.dart`), so reading it back from here would close a
/// Riverpod dependency cycle — and `ref.read` trips that guard at call time,
/// not only during build.
///
/// The state travels with the relays because `null` relays mean two different
/// things: [DmInboxResolution.absent] (the recipient reads the default pool,
/// so a pool `OK` is delivery) and [DmInboxResolution.unreadable] (we never
/// read their inbox, so a pool `OK` proves nothing). A resolver that returns
/// only the relay list would flatten both to `null` and must not be wired here
/// — that flattening is #8443.
///
/// Contract: **must not throw**. `DmRepository.resolveDmInboxRelaysDetailed`
/// satisfies this — its whole body is wrapped in `on Object catch`. A resolver
/// that throws anyway is treated as [DmInboxResolution.unreadable]: the wrap
/// still goes to the default pool, and the pool's `OK` is not scored as
/// delivery.
typedef DmInboxRelayResolver = Future<DmInboxLookup> Function(String pubkey);

/// Repository for DM emoji reactions.
///
/// Public surface:
/// - `publish` — optimistic insert + wrap + send.
/// - `removeOwn` — NIP-09 kind-5 deletion of an own reaction.
/// - `watchForConversation` — Drift stream for the chip render path.
/// - `persistIncoming` — entry point for the receive pipeline (called
///   from `DmRepository._handleGiftWrapEvent` when `rumor.kind == 7`).
/// - `applyDeletion` — applies one already-classified kind-5 target;
///   `DmRepository` owns the routing and calls this for reaction targets.
/// - `backfillQueuedRecipients` — records who queued rows are for, run by
///   `DmRepository` after sign-in.
class DmReactionsRepository {
  /// Construct the repository. Most fields are nullable for the legacy
  /// dependency-injection pattern where credentials are bound after
  /// auth via [setCredentials].
  DmReactionsRepository({
    required DmReactionsDao reactionsDao,
    NIP17MessageService? messageService,
    String? userPubkey,
    DmReactionsRepositoryErrorReporter? errorReporter,
    ConversationsDao? conversationsDao,
    DirectMessagesDao? directMessagesDao,
  }) : _reactionsDao = reactionsDao,
       _messageService = messageService,
       _userPubkey = userPubkey ?? '',
       _errorReporter = errorReporter,
       _conversationsDao = conversationsDao,
       _directMessagesDao = directMessagesDao;

  final DmReactionsDao _reactionsDao;
  NIP17MessageService? _messageService;
  String _userPubkey;
  final DmReactionsRepositoryErrorReporter? _errorReporter;

  /// Source of conversation participant sets, used to fan a group reaction's
  /// gift wrap out to every member. Null in legacy/test wiring: only a set
  /// proven another way is sent to, anything else is held.
  final ConversationsDao? _conversationsDao;

  /// Source of the reacted message's stored row: the conversation an
  /// incoming reaction belongs to, and the room the message names when an
  /// outgoing reaction's conversation row is gone (#7880). Null in
  /// legacy/test wiring: 1:1 inference only.
  final DirectMessagesDao? _directMessagesDao;

  final Map<String, Future<DmReactionDeletionOutcome>>
  _deletionRecoveriesInFlight = <String, Future<DmReactionDeletionOutcome>>{};

  // The pending-age guard is not proof a group fan-out finished: each
  // recipient has its own timeout. Share original publishes and retries so
  // a late failure cannot overwrite a concurrent successful delivery.
  final Map<(String, String), Future<DmReactionPublishResult>>
  _reactionPublishesInFlight = {};

  /// Fires whenever a publish or removal leaves a row for the retry sweep: an
  /// unconfirmed or failed reaction, a removal whose kind-5 did not confirm,
  /// or a removal recorded before its recipients were known. The retry
  /// service listens and arms its in-session follow-up pass. Without it, such
  /// a row waits for the next foreground transition or connectivity change,
  /// and a removal has no chip left for the user to re-tap.
  ///
  /// Some emissions follow a database write that other work may still be
  /// reading, so listeners MUST NOT touch the database synchronously: arm a
  /// timer instead.
  final StreamController<void> _retryableWorkController =
      StreamController<void>.broadcast();

  /// See [_retryableWorkController]. App-scoped like the repository itself;
  /// never closed.
  Stream<void> get retryableReactionWork => _retryableWorkController.stream;

  void _notifyRetryableWork() {
    if (!_retryableWorkController.isClosed) {
      _retryableWorkController.add(null);
    }
  }

  /// Maximum permitted reaction content length. NIP-25 has no hard cap,
  /// but anything over ~128 chars is almost certainly malformed.
  static const int _maxReactionContentLength = 128;

  /// Hard cap on a single publish round-trip. Nostr publishes have no
  /// inherent timeout — a stalled relay socket can leave the await
  /// hanging until the process is restarted. Capping at 15 s lets the
  /// UI surface a retryable failure within a tap-test attention span.
  static const Duration _publishTimeout = Duration(seconds: 15);

  /// Has the repository been wired with auth credentials?
  bool get isInitialized => _messageService != null && _userPubkey.isNotEmpty;

  /// Whether recipient inbox routing has been wired by the app layer.
  @visibleForTesting
  bool get hasDmInboxRelayResolver => _resolveDmInboxRelays != null;

  /// Set the credentials needed for outgoing publishes.
  void setCredentials({
    required String userPubkey,
    required NIP17MessageService messageService,
  }) {
    _userPubkey = userPubkey;
    _messageService = messageService;
  }

  /// Clear credentials (sign-out path).
  void clearCredentials() {
    _userPubkey = '';
    _messageService = null;
  }

  /// Resolves a recipient's kind-10050 DM inbox so a reaction gift wrap is
  /// published where they actually read (#7321), and reports whether that
  /// inbox was read at all (#8443). Null until wired — the pre-#7321
  /// behaviour, where every wrap goes to the default pool and a pool `OK` is
  /// delivery.
  DmInboxRelayResolver? _resolveDmInboxRelays;

  /// Wire the kind-10050 resolver.
  ///
  /// Injected downward by `DmRepository`'s provider rather than read from a
  /// provider here; see [DmInboxRelayResolver] for why. The only consumer that
  /// reaches this repository without also building `DmRepository` is the
  /// reaction retry sweep, and the app shell constructs `dmRepositoryProvider`
  /// eagerly at mount, so the resolver is always wired before a sweep can fire.
  /// Kept a method rather than a setter: a bare setter trips
  /// `avoid_setters_without_getters`, and satisfying that would mean exposing a
  /// getter no consumer wants purely to appease the pair. The `set*` shape also
  /// matches [setCredentials] / [clearCredentials] on this class.
  // ignore: use_setters_to_change_properties
  void setDmInboxRelayResolver(DmInboxRelayResolver? resolver) {
    _resolveDmInboxRelays = resolver;
  }

  /// Drop every reaction row this account holds for [conversationIds].
  ///
  /// Called by `DmRepository.removeConversation` from inside its removal
  /// transaction, so a removed conversation leaves no queued reaction or
  /// pending kind-5 removal behind (#7857). The retry queries skip rows a
  /// removal tombstone covers, but a queued row normally carries its own
  /// recipients and needs no conversation row to be sent, so the queue is
  /// emptied here rather than left to that filter.
  ///
  /// [ownerPubkey] is supplied by the caller rather than read from this
  /// repository's mutable credentials so an account transition cannot change
  /// the owner midway through the enclosing removal transaction.
  ///
  /// No-op when [conversationIds] is empty.
  Future<void> deleteForConversations(
    Iterable<String> conversationIds, {
    required String ownerPubkey,
  }) async {
    await _reactionsDao.deleteForConversations(
      conversationIds: conversationIds,
      ownerPubkey: ownerPubkey,
    );
  }

  /// Purge reaction rows stranded by a conversation removal that happened
  /// before removal started dropping them (#7857).
  ///
  /// [deleteForConversations] only closes the leak going forward. An install
  /// that removed a conversation on an older build still holds that
  /// conversation's rows. The retry queries already skip them, since the
  /// removal tombstone covers them; this reclaims the rows.
  ///
  /// Rows created after the removal marker are kept: they belong to a
  /// conversation the counterparty has since recreated and are still owed
  /// delivery.
  ///
  /// Idempotent — a no-op once the account has none left.
  Future<int> purgeStrandedByRemoval({required String ownerPubkey}) {
    return _reactionsDao.deleteSuppressedByRemoval(ownerPubkey: ownerPubkey);
  }

  /// Record the gift-wrap recipients of every queued reaction and removal
  /// that has none (#7880). Returns how many rows were filled in.
  ///
  /// A row without them — queued by a build that did not store them, queued
  /// while they could not be established, or just moved into its group by the
  /// recovery pass — has only local state to go by: its conversation row, or
  /// the stored message it reacts to. Both can go while the queue is kept, so
  /// this runs after sign-in rather than waiting for each row's next send; a
  /// row whose state is already gone stays held.
  ///
  /// [ownerPubkey] is supplied by the caller rather than read from this
  /// repository's mutable credentials, so an account transition cannot change
  /// the owner midway through the pass.
  ///
  /// Idempotent. A row whose recipients cannot be established is left as it
  /// is and looked at again on the next pass.
  ///
  /// Throws:
  ///
  /// * the database error when listing the queued rows fails. A row whose own
  ///   reads or recipient write fail is reported and skipped instead.
  Future<int> backfillQueuedRecipients({required String ownerPubkey}) async {
    final rows = await _reactionsDao.getOwnQueuedRowsMissingRecipients(
      ownerPubkey: ownerPubkey,
    );
    var filled = 0;
    for (final row in rows) {
      final recipients = await _resolveWrapRecipients(
        conversationId: row.conversationId,
        targetMessageId: row.targetMessageId,
        targetMessageAuthor: row.targetMessageAuthor,
        ownerPubkey: ownerPubkey,
      );
      if (recipients == null) continue;
      filled += await _storeRecipients(row, recipients);
    }
    if (rows.isNotEmpty) {
      Log.info(
        'Recorded the recipients of $filled of ${rows.length} queued DM '
        'reaction rows that had none',
        category: LogCategory.system,
      );
    }
    return filled;
  }

  /// Follow [targetMessageIds] to [toConversationId] after those messages
  /// were moved between conversations.
  ///
  /// A reaction row records the conversation its target message belongs to,
  /// and the live render index is keyed on that pair, so a move that leaves
  /// reactions behind silently drops the chips and strands rows the retry
  /// sweep still owns (#7857). Called by the group-conversation recovery pass
  /// (#8407) inside the same transaction as the message move.
  ///
  /// The moved rows' stored recipients are cleared (see
  /// [DmReactionsDao.reassignForTargetMessages]); the backfill that follows
  /// group recovery, or failing that the next send, works them out from
  /// [toConversationId].
  Future<int> reassignForMovedMessages({
    required Iterable<String> targetMessageIds,
    required String toConversationId,
    required String ownerPubkey,
  }) {
    return _reactionsDao.reassignForTargetMessages(
      targetMessageIds: targetMessageIds,
      toConversationId: toConversationId,
      ownerPubkey: ownerPubkey,
    );
  }

  /// Bring the received reactions on [messageId] into [conversationId], the
  /// conversation that message was just stored in.
  ///
  /// A reaction processed before its message cannot know the room (see
  /// [_resolveConversationIdForReaction]) and is filed under a 1:1, where it
  /// never shows on a message that then lands in a group (#8271). Called by
  /// `DmRepository` inside the transaction that stores a room message; a
  /// one-to-one message has nothing to move.
  ///
  /// The account's own queued and sent rows are left alone; see
  /// [DmReactionsDao.adoptReceivedForTargetMessage].
  ///
  /// [ownerPubkey] is supplied by the caller rather than read from this
  /// repository's mutable credentials, so an account transition cannot change
  /// the owner midway through the enclosing transaction.
  Future<int> adoptReceivedForStoredMessage({
    required String messageId,
    required String conversationId,
    required String ownerPubkey,
  }) {
    return _reactionsDao.adoptReceivedForTargetMessage(
      targetMessageId: messageId,
      toConversationId: conversationId,
      ownerPubkey: ownerPubkey,
    );
  }

  /// Reactive stream of every live reaction in [conversationId] for the
  /// current account, collapsed to at most one reaction per reactor per
  /// target message (the cap-at-one invariant — see [_collapsePerReactor]).
  /// Empty list when uninitialized.
  Stream<List<DmReaction>> watchForConversation(String conversationId) {
    if (_userPubkey.isEmpty) {
      return Stream<List<DmReaction>>.value(const <DmReaction>[]);
    }
    return _reactionsDao
        .watchForConversation(
          conversationId: conversationId,
          ownerPubkey: _userPubkey,
        )
        .map((rows) => _collapsePerReactor(rows.map(_rowToModel).toList()));
  }

  /// Whether the current account has a pending or refused removal for the
  /// target message. This reads the durable queue because pending removals are
  /// deliberately absent from [watchForConversation].
  Future<bool> hasOutstandingOwnDeletion({
    required String targetMessageId,
  }) {
    if (_userPubkey.isEmpty) return Future<bool>.value(false);
    return _reactionsDao.hasOutstandingOwnDeletion(
      targetMessageId: targetMessageId,
      ownerPubkey: _userPubkey,
    );
  }

  /// Enforce the cap-at-one invariant at the read boundary: keep at most one
  /// live reaction per (targetMessageId, reactorPubkey), the most recent by
  /// `createdAt`.
  ///
  /// The DAO can momentarily hold several live rows for one reactor on one
  /// message — a superseding kind-5 deletion that never arrived (the reactor
  /// was offline, or a remote client switched emoji without deleting the old
  /// reaction), or the dual-cubit optimistic-insert race tracked by #5419.
  /// The render path (pill avatar stack + who-reacted sheet) assumes one row
  /// per reactor; collapsing here keeps it correct regardless of stored
  /// duplicates. Returned in ascending `createdAt` order, matching the DAO's
  /// `ORDER BY created_at ASC` so the pill's "reversed == most-recent-first"
  /// assumption holds.
  static List<DmReaction> _collapsePerReactor(List<DmReaction> reactions) {
    if (reactions.length < 2) return reactions;
    final latestByReactor = <(String, String), DmReaction>{};
    for (final reaction in reactions) {
      final key = (reaction.targetMessageId, reaction.reactorPubkey);
      final existing = latestByReactor[key];
      if (existing == null || reaction.createdAt >= existing.createdAt) {
        latestByReactor[key] = reaction;
      }
    }
    if (latestByReactor.length == reactions.length) return reactions;
    return latestByReactor.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Publish a new reaction. Performs cap-at-one supersede when the
  /// reactor already has a live reaction on this target.
  ///
  /// When the recipients cannot be established, the reaction is still queued
  /// — `'failed'`, with no recipients recorded — and nothing is sent until
  /// they can be.
  Future<DmReactionPublishResult> publish({
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String emoji,
  }) async {
    final messageService = _messageService;
    // Read once. The row below is written after an await, and it must go to
    // the account that built the rumor even if the session changes meanwhile.
    final ownerPubkey = _userPubkey;
    if (messageService == null || ownerPubkey.isEmpty) {
      return const DmReactionPublishResult(
        success: false,
        rumorId: '',
        errorMessage: 'Repository not initialized',
      );
    }

    final additionalTags = <List<String>>[
      ['e', targetMessageId],
      ['p', targetMessageAuthor],
      ['k', EventKind.privateDirectMessage.toString()],
    ];
    final rumor = messageService.buildRumor(
      recipientPubkey: targetMessageAuthor,
      content: emoji,
      eventKind: EventKind.reaction,
      additionalTags: additionalTags,
    );
    final rumorId = rumor.id;

    return _coalesceReactionAttempt(
      ownerPubkey,
      rumorId,
      () => _publishRumor(
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetMessageAuthor,
        emoji: emoji,
        rumor: rumor,
        ownerPubkey: ownerPubkey,
        messageService: messageService,
      ),
    );
  }

  Future<DmReactionPublishResult> _publishRumor({
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String emoji,
    required Event rumor,
    required String ownerPubkey,
    required NIP17MessageService messageService,
  }) async {
    final rumorId = rumor.id;

    // Worked out before the row is written, so the row carries the people it
    // is for whenever they can be established: the retry sweep sends it to
    // this set (#7880).
    final knownRecipients = await _resolveWrapRecipients(
      conversationId: conversationId,
      targetMessageId: targetMessageId,
      targetMessageAuthor: targetMessageAuthor,
      ownerPubkey: ownerPubkey,
    );

    final List<String> superseded;
    try {
      // Atomic cap-at-one: soft-deletes any prior live own reaction on this
      // target and inserts the new pending row in one transaction, returning
      // the superseded ids for the wire-side kind-5 below (#5419).
      superseded = await _reactionsDao.insertOwnReactionSuperseding(
        placeholderId: rumorId,
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetMessageAuthor,
        reactorPubkey: ownerPubkey,
        emoji: emoji,
        createdAt: rumor.createdAt,
        ownerPubkey: ownerPubkey,
        rumorEventJson: jsonEncode(rumor.toJson()),
        recipientPubkeys: knownRecipients == null
            ? null
            : jsonEncode(knownRecipients),
      );
    } on Object catch (e, st) {
      _errorReporter?.call(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.publishOptimisticInsert,
      );
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: 'Optimistic insert failed',
      );
    }

    if (knownRecipients == null) {
      _logHeld(
        rumorId,
        targetMessageId: targetMessageId,
        conversationId: conversationId,
      );
    }
    final recipients = knownRecipients ?? const <String>[];

    // A superseded reaction is removed for the people IT was sent to, which
    // is not always this reaction's set: the same message can be shown in
    // another conversation by the time the emoji is swapped.
    final priors = <String, List<String>>{
      for (final priorId in superseded)
        priorId: await _recipientsForSuperseded(
          priorId,
          targetMessageId: targetMessageId,
          replacementRecipients: recipients,
          ownerPubkey: ownerPubkey,
        ),
    };
    final inboxes = _inboxesForTap(recipients, priors.values);
    await _removeSuperseded(
      priors,
      targetMessageAuthor: targetMessageAuthor,
      ownerPubkey: ownerPubkey,
      messageService: messageService,
      inboxes: inboxes,
    );

    final inboxByRecipient = await inboxes;
    try {
      final result = await _fanOutRumor(
        messageService: messageService,
        rumor: rumor,
        recipients: recipients,
        inboxByRecipient: inboxByRecipient,
        awaitRecipientOk: true,
      );
      switch (result) {
        case NIP17SendSuccess():
          try {
            await _reactionsDao.swapPlaceholderId(
              placeholderId: rumorId,
              realRumorId: rumorId,
              ownerPubkey: ownerPubkey,
            );
          } on Object catch (e, st) {
            _errorReporter?.call(
              e,
              st,
              site: DmReactionsRepositoryReportableSites.publishSwapPlaceholder,
            );
          }
          return DmReactionPublishResult(
            success: true,
            rumorId: rumorId,
            optimisticInsertSucceeded: true,
          );
        case NIP17SendFailure(
          :final error,
          :final retryablePending,
          :final blocked,
        ):
          // Policy-blocked (#176): terminal and non-retryable — retrying only
          // re-hits the same policy. Mark 'blocked' so the sweep and a chip
          // re-tap both leave it alone (unlike 'failed', which they re-drive).
          if (blocked) {
            await _reactionsDao.markBlocked(
              id: rumorId,
              ownerPubkey: ownerPubkey,
            );
          } else if (retryablePending) {
            // Unconfirmed (frame written, no relay OK): keep the row 'pending'
            // so it stays a dim, sweep-retryable chip — a lost OK is not proof
            // of loss. Only a confirmed rejection/error flips it to 'failed'.
            await _reactionsDao.markPending(
              id: rumorId,
              ownerPubkey: ownerPubkey,
            );
            _notifyRetryableWork();
          } else {
            await _reactionsDao.markFailed(
              placeholderId: rumorId,
              ownerPubkey: ownerPubkey,
            );
            _notifyRetryableWork();
          }
          return DmReactionPublishResult(
            success: false,
            rumorId: rumorId,
            errorMessage: error,
            optimisticInsertSucceeded: true,
          );
      }
    } on Object catch (e) {
      Log.warning(
        'DM reaction publish threw: $e',
        category: LogCategory.system,
      );
      await _reactionsDao.markFailed(
        placeholderId: rumorId,
        ownerPubkey: ownerPubkey,
      );
      _notifyRetryableWork();
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: e.toString(),
        optimisticInsertSucceeded: true,
      );
    }
  }

  /// Retry a previously-failed reaction publish by replaying the same
  /// rumor (read from `rumor_event_json`) to the recipients stored on its
  /// row.
  ///
  /// A row whose recipients cannot be established is not sent: it ends
  /// `'failed'` with its rumor kept, rather than going to the reacted
  /// message's author alone (#7880).
  ///
  /// Reliability contract:
  /// 1. Marks the DAO row `'pending'` BEFORE the send so the chip
  ///    reflects in-flight state in the persistent layer — survives a
  ///    cubit rebuild / hot-restart.
  /// 2. Wraps the underlying `sendRumor` in a 15 s timeout so a hung
  ///    relay socket can't lock the user out of further retries.
  /// 3. A confirmed rejection or throw flips the DAO row back to `'failed'`
  ///    so the chip is tappable again immediately. A soft outcome — a lost
  ///    `OK`, or an inbox we could not read (#8443) — leaves the pre-send
  ///    `'pending'` so the sweep keeps re-driving it.
  /// 4. When an attempt for this rumor is already running — the original
  ///    [publish] of a group reaction, or an earlier retry — nothing is sent
  ///    again: the call joins that attempt and returns its outcome.
  Future<DmReactionPublishResult> retry({
    required String rumorId,
    required String targetMessageAuthor,
  }) async {
    final messageService = _messageService;
    final ownerPubkey = _userPubkey;
    if (messageService == null || ownerPubkey.isEmpty) {
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: 'Repository not initialized',
      );
    }

    return _coalesceReactionAttempt(
      ownerPubkey,
      rumorId,
      () => _retryReaction(
        rumorId: rumorId,
        targetMessageAuthor: targetMessageAuthor,
        ownerPubkey: ownerPubkey,
        messageService: messageService,
      ),
    );
  }

  Future<DmReactionPublishResult> _retryReaction({
    required String rumorId,
    required String targetMessageAuthor,
    required String ownerPubkey,
    required NIP17MessageService messageService,
  }) async {
    final row = await _reactionsDao.getById(
      id: rumorId,
      ownerPubkey: ownerPubkey,
    );
    final rumorJson = row?.rumorEventJson;
    if (row == null || rumorJson == null) {
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: 'No stored rumor to retry',
      );
    }
    final rumor = Event.fromJson(jsonDecode(rumorJson) as Map<String, dynamic>);
    final recipients = await _recipientsOrHold(
      row,
      targetMessageAuthor: targetMessageAuthor,
    );

    // Persist `pending` so the chip surfaces in-flight state across
    // a cubit rebuild. If this DAO write fails, we still attempt the
    // send — the user-visible recovery path is the chip falling back
    // to `failed` via the next branch.
    try {
      await _reactionsDao.markPending(id: rumorId, ownerPubkey: ownerPubkey);
    } on Object {
      // best-effort
    }

    try {
      final result = await _fanOutRumor(
        messageService: messageService,
        rumor: rumor,
        recipients: recipients,
        awaitRecipientOk: true,
      );
      switch (result) {
        case NIP17SendSuccess():
          await _reactionsDao.swapPlaceholderId(
            placeholderId: rumorId,
            realRumorId: rumorId,
            ownerPubkey: ownerPubkey,
          );
          return DmReactionPublishResult(
            success: true,
            rumorId: rumorId,
            optimisticInsertSucceeded: true,
          );
        case NIP17SendFailure(
          :final error,
          :final retryablePending,
          :final blocked,
        ):
          // Policy-blocked (#176): terminal — flip the row out of the
          // retryable pending/failed set so the sweep and a chip re-tap stop
          // re-driving a send the policy will always refuse.
          if (blocked) {
            await _reactionsDao.markBlocked(
              id: rumorId,
              ownerPubkey: ownerPubkey,
            );
          } else {
            // Confirmed rejection/error: flip to 'failed' so the chip is
            // tappable again. A soft (retryablePending) failure instead
            // leaves the pre-send 'pending' untouched, so the sweep keeps
            // re-driving it. Both stay on the sweep's worklist.
            if (!retryablePending) {
              await _reactionsDao.markFailed(
                placeholderId: rumorId,
                ownerPubkey: ownerPubkey,
              );
            }
            _notifyRetryableWork();
          }
          return DmReactionPublishResult(
            success: false,
            rumorId: rumorId,
            errorMessage: error,
            optimisticInsertSucceeded: true,
          );
      }
    } on Object catch (e) {
      Log.warning('DM reaction retry threw: $e', category: LogCategory.system);
      await _reactionsDao.markFailed(
        placeholderId: rumorId,
        ownerPubkey: ownerPubkey,
      );
      _notifyRetryableWork();
      return DmReactionPublishResult(
        success: false,
        rumorId: rumorId,
        errorMessage: e.toString(),
      );
    }
  }

  Future<DmReactionPublishResult> _coalesceReactionAttempt(
    String ownerPubkey,
    String rumorId,
    Future<DmReactionPublishResult> Function() attempt,
  ) {
    final key = (ownerPubkey, rumorId);
    final existing = _reactionPublishesInFlight[key];
    if (existing != null) return existing;
    final future = attempt().whenComplete(() {
      _reactionPublishesInFlight.removeWhere(
        (activeKey, _) => activeKey == key,
      );
    });
    _reactionPublishesInFlight[key] = future;
    return future;
  }

  /// List this user's own outgoing reactions still awaiting durable delivery
  /// (publish `'failed'`, or `'pending'` from an interrupted send), for the
  /// foreground retry sweep to re-drive via [retry]. Returns empty when
  /// credentials have not been wired.
  Future<List<DmReactionRetryTarget>> retryableReactions() async {
    if (_userPubkey.isEmpty) return const [];
    final rows = await _reactionsDao.getRetryableOwnReactions(
      ownerPubkey: _userPubkey,
    );
    return rows
        .map(
          (r) => DmReactionRetryTarget(
            rumorId: r.id,
            targetMessageAuthor: r.targetMessageAuthor,
            publishStatus: r.publishStatus ?? 'pending',
            createdAt: r.createdAt,
          ),
        )
        .toList(growable: false);
  }

  /// Soft-delete an own reaction locally and durably (re)deliver its NIP-09
  /// kind-5 deletion on the wire.
  ///
  /// Returns after the local update; the wire publish is durable — a
  /// failed/offline attempt is re-driven by the retry sweep via
  /// [retryDeletion] rather than being dropped. When the recipients cannot be
  /// established, the removal is recorded all the same and left for the retry
  /// sweep.
  ///
  /// Does nothing when this account holds no row for [rumorId].
  ///
  /// Throws:
  ///
  /// * the database error when the reaction row cannot be read, or the
  ///   error when the removal cannot be built or recorded. Nothing is sent
  ///   and the reaction stays live, so a caller that already hid it must
  ///   show it again.
  Future<void> removeOwn({
    required String rumorId,
    required String targetMessageAuthor,
  }) async {
    final messageService = _messageService;
    final ownerPubkey = _userPubkey;
    if (messageService == null || ownerPubkey.isEmpty) return;
    final row = await _reactionsDao.getById(
      id: rumorId,
      ownerPubkey: ownerPubkey,
    );
    if (row == null) {
      Log.debug(
        'No DM reaction $rumorId to remove for this account',
        category: LogCategory.system,
      );
      return;
    }
    final recipients = await _recipientsOrHold(
      row,
      targetMessageAuthor: targetMessageAuthor,
      removal: true,
    );

    await _durablyDeleteReaction(
      rumorId: rumorId,
      recipients: recipients,
      targetMessageAuthor: targetMessageAuthor,
      ownerPubkey: ownerPubkey,
      messageService: messageService,
      reportSite: DmReactionsRepositoryReportableSites.removeOwnSoftDelete,
    );
  }

  /// Soft-delete the reaction row [rumorId] locally and durably record its
  /// NIP-09 kind-5 deletion, then fire the first (non-blocking) delivery
  /// attempt. Shared by the explicit un-react ([removeOwn]) and the cap-at-one
  /// emoji-swap supersede in [publish].
  ///
  /// The kind-5 is built once so every (re)delivery replays an identical event
  /// — recipients treat repeats as idempotent. The `deletion_pending` row is
  /// awaited (durability boundary) so a crash before it lands can't lose the
  /// removal; the wire publish itself is `unawaited` and re-driven by the sweep
  /// via [retryDeletion] on any failed/offline attempt. The first attempt and
  /// every retry are coalesced by rumor id, so only one fan-out can drive the
  /// stored kind-5 at a time.
  ///
  /// When the kind-5 cannot be built or recorded, the failure is reported to
  /// [reportSite] and rethrown, with no wire attempt: no kind-5 is queued for
  /// the sweep to deliver.
  ///
  /// An empty [recipients] means they could not be established. The removal
  /// is recorded all the same, tagged with [targetMessageAuthor] like the
  /// reaction it removes, and left for the retry sweep: dropping it would
  /// leave the reaction live while the UI shows it removed.
  Future<void> _durablyDeleteReaction({
    required String rumorId,
    required List<String> recipients,
    required String targetMessageAuthor,
    required String ownerPubkey,
    required NIP17MessageService messageService,
    required String reportSite,
    Future<Map<String, DmInboxLookup>>? inboxes,
  }) async {
    final Event deletion;
    try {
      deletion = messageService.buildRumor(
        recipientPubkey: recipients.firstOrNull ?? targetMessageAuthor,
        content: '',
        eventKind: EventKind.eventDeletion,
        additionalTags: [
          ['e', rumorId],
          ['k', EventKind.reaction.toString()],
        ],
      );
      await _reactionsDao.markOwnDeletionPending(
        id: rumorId,
        ownerPubkey: ownerPubkey,
        deletionRumorJson: jsonEncode(deletion.toJson()),
      );
    } on Object catch (e, st) {
      _errorReporter?.call(e, st, site: reportSite);
      rethrow;
    }
    if (recipients.isEmpty) {
      _notifyRetryableWork();
      return;
    }

    unawaited(
      _coalesceDeletionAttempt(
        rumorId,
        () => _driveDeletion(
          rumorId: rumorId,
          deletion: deletion,
          recipients: recipients,
          ownerPubkey: ownerPubkey,
          messageService: messageService,
          inboxes: inboxes,
        ),
      ),
    );
  }

  /// List this user's own reaction removals still awaiting durable kind-5
  /// delivery, for the foreground/reconnect retry sweep to re-drive via
  /// [retryDeletion]. Empty when credentials have not been wired.
  Future<List<DmReactionRetryTarget>> retryableDeletions() async {
    if (_userPubkey.isEmpty) return const [];
    final rows = await _reactionsDao.getRetryableOwnDeletions(
      ownerPubkey: _userPubkey,
    );
    return rows
        .map(
          (r) => DmReactionRetryTarget(
            rumorId: r.id,
            targetMessageAuthor: r.targetMessageAuthor,
            publishStatus: r.publishStatus ?? '',
            createdAt: r.createdAt,
          ),
        )
        .toList(growable: false);
  }

  /// Retry a previously-failed/interrupted own reaction removal by replaying
  /// the stored kind-5 rumor to the recipients stored on its row. When they
  /// cannot be established, nothing is sent and the removal stays queued.
  ///
  /// Marks the row `deletion_sent` on a confirmed publish and
  /// `deletion_refused` when send policy blocks it — off the sweep's
  /// worklist, rumor retained for a user-driven retry; leaves it pending
  /// otherwise so the sweep tries again.
  Future<DmReactionDeletionOutcome> retryDeletion({
    required String rumorId,
    required String targetMessageAuthor,
  }) {
    return _coalesceDeletionAttempt(
      rumorId,
      () => _retryDeletion(
        rumorId: rumorId,
        targetMessageAuthor: targetMessageAuthor,
      ),
    );
  }

  Future<DmReactionDeletionOutcome> _retryDeletion({
    required String rumorId,
    required String targetMessageAuthor,
  }) async {
    final messageService = _messageService;
    final ownerPubkey = _userPubkey;
    if (messageService == null || ownerPubkey.isEmpty) {
      return DmReactionDeletionOutcome.unavailable;
    }
    final row = await _reactionsDao.getById(
      id: rumorId,
      ownerPubkey: ownerPubkey,
    );
    final deletionJson = row?.rumorEventJson;
    if (row == null || deletionJson == null) {
      return DmReactionDeletionOutcome.unavailable;
    }
    final deletion = Event.fromJson(
      jsonDecode(deletionJson) as Map<String, dynamic>,
    );
    final recipients = await _recipientsOrHold(
      row,
      targetMessageAuthor: targetMessageAuthor,
      removal: true,
    );
    try {
      final result = await _fanOutRumor(
        messageService: messageService,
        rumor: deletion,
        recipients: recipients,
        awaitRecipientOk: true,
      );
      switch (result) {
        case NIP17SendSuccess():
          await _reactionsDao.markDeletionSent(
            id: rumorId,
            ownerPubkey: ownerPubkey,
          );
          return DmReactionDeletionOutcome.sent;
        case NIP17SendFailure(:final error, :final blocked):
          if (blocked) {
            await _reactionsDao.markDeletionRefused(
              id: rumorId,
              ownerPubkey: ownerPubkey,
            );
            return DmReactionDeletionOutcome.refused;
          }
          Log.warning(
            'DM reaction deletion retry was unconfirmed: $error',
            category: LogCategory.system,
          );
          _notifyRetryableWork();
          return DmReactionDeletionOutcome.unconfirmed;
      }
    } on Object catch (e) {
      Log.warning(
        'DM reaction deletion retry threw: $e',
        category: LogCategory.system,
      );
      _notifyRetryableWork();
      return DmReactionDeletionOutcome.unconfirmed;
    }
  }

  /// Publish [deletion], preserving an honest durable state for every result.
  Future<DmReactionDeletionOutcome> _driveDeletion({
    required String rumorId,
    required Event deletion,
    required List<String> recipients,
    required String ownerPubkey,
    required NIP17MessageService messageService,
    Future<Map<String, DmInboxLookup>>? inboxes,
  }) async {
    try {
      final inboxByRecipient = await inboxes;
      final result = await _fanOutRumor(
        messageService: messageService,
        rumor: deletion,
        recipients: recipients,
        inboxByRecipient: inboxByRecipient,
        awaitRecipientOk: true,
      );
      switch (result) {
        case NIP17SendSuccess():
          await _reactionsDao.markDeletionSent(
            id: rumorId,
            ownerPubkey: ownerPubkey,
          );
          return DmReactionDeletionOutcome.sent;
        case NIP17SendFailure(:final blocked):
          if (blocked) {
            await _reactionsDao.markDeletionRefused(
              id: rumorId,
              ownerPubkey: ownerPubkey,
            );
            return DmReactionDeletionOutcome.refused;
          }
          _notifyRetryableWork();
          return DmReactionDeletionOutcome.unconfirmed;
      }
    } on Object catch (e) {
      Log.warning(
        'DM reaction deletion publish threw: $e',
        category: LogCategory.system,
      );
      _notifyRetryableWork();
      return DmReactionDeletionOutcome.unconfirmed;
    }
  }

  Future<DmReactionDeletionOutcome> _coalesceDeletionAttempt(
    String rumorId,
    Future<DmReactionDeletionOutcome> Function() attempt,
  ) {
    final existing = _deletionRecoveriesInFlight[rumorId];
    if (existing != null) return existing;
    final future = attempt();
    _deletionRecoveriesInFlight[rumorId] = future;
    return future.whenComplete(
      () => _deletionRecoveriesInFlight.remove(rumorId),
    );
  }

  /// Persist an incoming kind-7 reaction rumor. Called from
  /// `DmRepository._handleGiftWrapEvent` after rumor extraction.
  ///
  /// Returns [DmWrapOutcome.processed] when the wrap reached a terminal
  /// state (persisted, or permanently dropped for malformed content/tags), and
  /// [DmWrapOutcome.deferred] when it could not be applied yet (signer
  /// not ready, or the target message has not synced) so the caller leaves it
  /// out of the dedup ledger and lets it re-decrypt later. See #5452.
  Future<DmWrapOutcome> persistIncoming({
    required Event rumorEvent,
    required String giftWrapId,
  }) async {
    if (_userPubkey.isEmpty) return DmWrapOutcome.deferred;
    if (rumorEvent.kind != EventKind.reaction) {
      return DmWrapOutcome.processed;
    }
    final content = rumorEvent.content;
    if (content.isEmpty || content.length > _maxReactionContentLength) {
      Log.debug(
        'Dropping invalid reaction rumor ${rumorEvent.id} '
        '(content length: ${content.length})',
        category: LogCategory.system,
      );
      return DmWrapOutcome.processed;
    }
    String? targetMessageId;
    String? targetAuthor;
    // Last tag wins in each family. NIP-25 puts the reaction's target last
    // when a client includes extras ("the target event `id` should be last
    // of the `e` tags", likewise the pubkey "last the `p` tags"), so a peer
    // that leads with the thread root would otherwise bind the reaction to
    // the wrong message. #7333.
    for (final tag in rumorEvent.tags) {
      if (tag.length < 2) continue;
      if (tag[0] == 'e') targetMessageId = tag[1];
      if (tag[0] == 'p') targetAuthor = tag[1];
    }
    if (targetMessageId == null ||
        targetMessageId.isEmpty ||
        targetMessageId.length != 64) {
      Log.debug(
        'Dropping reaction rumor ${rumorEvent.id} — missing/invalid e tag',
        category: LogCategory.system,
      );
      return DmWrapOutcome.processed;
    }
    targetAuthor ??= rumorEvent.pubkey;
    final conversationId = await _resolveConversationIdForReaction(
      reactorPubkey: rumorEvent.pubkey,
      targetAuthor: targetAuthor,
      targetMessageId: targetMessageId,
    );
    // Target message not synced yet: leave undecided so a later launch retries
    // and the reaction lands once the message arrives. See #5452 (D4-terminal).
    if (conversationId == null) return DmWrapOutcome.deferred;
    try {
      await _reactionsDao.upsertIncoming(
        id: rumorEvent.id,
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetAuthor,
        reactorPubkey: rumorEvent.pubkey,
        emoji: content,
        createdAt: rumorEvent.createdAt,
        giftWrapId: giftWrapId,
        ownerPubkey: _userPubkey,
      );
      return DmWrapOutcome.processed;
    } on Object catch (e, st) {
      _errorReporter?.call(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.persistIncomingDaoUpsert,
      );
      // Transient DAO failure — let it retry rather than cement a skip.
      return DmWrapOutcome.deferred;
    }
  }

  /// Apply an incoming NIP-09 kind-5 deletion to the reaction row [rumorId],
  /// on behalf of [deleterPubkey].
  ///
  /// This takes one already-classified target rather than a whole rumor:
  /// [DmRepository] owns the `e`-tag loop and decides, per target, whether it
  /// names a reaction or a message. It used to decide that here by demanding a
  /// literal `['k','7']` tag, which is wrong twice over — NIP-09 makes `k` a
  /// SHOULD, and a deletion aimed at a *message* was answered
  /// [DmWrapOutcome.processed] and lost for good (#7809, #7329).
  ///
  /// [deleterPubkey] must be the rumor's authenticated author — `rumor.pubkey`
  /// as rebuilt from the signed seal, never the gift wrap's own ephemeral key.
  ///
  /// Returns `null` when this account holds no reaction with that id, so the
  /// caller can try the message store instead — the apply doubles as the
  /// probe, which keeps routing to one DAO read in the common case.
  ///
  /// Returns [DmWrapOutcome.deferred] — leaving the wrap out of the dedup
  /// ledger so it re-decrypts on a later launch — when the signer is not
  /// ready or on a transient soft-delete failure. Otherwise returns
  /// [DmWrapOutcome.processed] (terminal): the deletion applied, the target
  /// was already deleted, or the deletion is invalid (author mismatch). The
  /// soft-delete is idempotent, so re-applying on a benign re-decrypt is
  /// safe. #5452.
  Future<DmWrapOutcome?> applyDeletion({
    required String rumorId,
    required String deleterPubkey,
    required String giftWrapId,
  }) async {
    if (_userPubkey.isEmpty) return DmWrapOutcome.deferred;

    final row = await _reactionsDao.getById(
      id: rumorId,
      ownerPubkey: _userPubkey,
    );
    // `null` means no such reaction row, which is NOT the same as "give up":
    // the caller tries the message store next, and only defers if neither
    // holds the target. Deferring here matters because gift wraps carry
    // NIP-59 randomized `created_at`, so a deletion can drain before the
    // reaction it removes; recording it as terminal would let the reaction
    // insert live afterwards and never be soft-deleted. Symmetric with
    // persistIncoming's unsynced-target handling. #5452.
    if (row == null) return null;
    if (row.isDeleted) return DmWrapOutcome.processed;

    // NIP-09: only the original reaction author may delete their reaction.
    if (row.reactorPubkey != deleterPubkey) {
      Log.debug(
        'Ignoring wrapped reaction deletion for $rumorId: author mismatch '
        '(event=${pubkeyForLogs(deleterPubkey)}, '
        'reactor=${pubkeyForLogs(row.reactorPubkey)}, '
        'giftWrap=$giftWrapId)',
        category: LogCategory.system,
      );
      return DmWrapOutcome.processed;
    }

    try {
      await _reactionsDao.softDelete(id: rumorId, ownerPubkey: _userPubkey);
    } on Object catch (e, st) {
      _errorReporter?.call(
        e,
        st,
        site: DmReactionsRepositoryReportableSites
            .handleIncomingDeletionSoftDelete,
      );
      // Transient DAO failure — let it retry rather than cement a skip.
      return DmWrapOutcome.deferred;
    }
    return DmWrapOutcome.processed;
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Wrap `sendRumor` with a hard timeout. Nostr publishes have no
  /// built-in timeout — a stalled socket can keep the await pending
  /// indefinitely, which (under a `sequential()` event transformer)
  /// quietly swallows every subsequent retry tap. The `_publishTimeout`
  /// cap converts those hangs into surfaced `NIP17SendFailure` results.
  Future<NIP17SendResult> _sendRumorWithTimeout({
    required NIP17MessageService messageService,
    required Event rumor,
    required String recipientPubkey,
    List<String>? targetRelays,
    bool awaitRecipientOk = false,
  }) {
    return messageService
        .sendRumor(
          rumorEvent: rumor,
          recipientPubkey: recipientPubkey,
          // Route the wrap to the recipient's advertised NIP-17 inbox when it
          // resolved; null falls back to the default pool, preserving
          // reachability for recipients who publish no kind-10050 (#7321).
          targetRelays: targetRelays,
          awaitRecipientOk: awaitRecipientOk,
        )
        .timeout(
          _publishTimeout,
          // A hung socket is inconclusive, not a confirmed rejection — the
          // frame may already be written. Keep it retryable-pending so the
          // sweep re-drives it rather than parking a red failed chip.
          onTimeout: () => NIP17SendResult.failure(
            'Reaction publish timed out after '
            '${_publishTimeout.inSeconds}s',
            retryablePending: true,
          ),
        );
  }

  /// The gift-wrap recipients of the reaction or removal queued on [row], or
  /// `null` when they cannot be established.
  ///
  /// A usable set stored on the row wins. Otherwise the set is resolved now,
  /// for the account that owns the row, and recorded for later attempts if
  /// the row has none (#7880).
  Future<List<String>?> _recipientsForRow(
    DmReactionRow row, {
    required String targetMessageAuthor,
  }) async {
    final stored = _storedRecipients(row);
    if (stored != null) return stored;
    final resolved = await _resolveWrapRecipients(
      conversationId: row.conversationId,
      targetMessageId: row.targetMessageId,
      targetMessageAuthor: targetMessageAuthor,
      ownerPubkey: row.ownerPubkey,
    );
    if (resolved == null) return null;
    await _storeRecipients(row, resolved);
    return resolved;
  }

  /// [_recipientsForRow], or an empty set when the recipients are not known,
  /// which holds the send: nothing goes on the wire and the rumor stays on
  /// the row for a later attempt.
  Future<List<String>> _recipientsOrHold(
    DmReactionRow row, {
    required String targetMessageAuthor,
    bool removal = false,
  }) async {
    final recipients = await _recipientsForRow(
      row,
      targetMessageAuthor: targetMessageAuthor,
    );
    if (recipients != null) return recipients;
    _logHeld(
      row.id,
      targetMessageId: row.targetMessageId,
      conversationId: row.conversationId,
      removal: removal,
    );
    return const <String>[];
  }

  /// The recipients of the kind-5 that removes [rumorId], a prior reaction
  /// [publish] has just superseded.
  ///
  /// The set stored on its row is used alone. A row without one may have
  /// reached the people its own conversation yields or the ones the replacing
  /// reaction goes to, [replacementRecipients], so the removal goes to both,
  /// and that set is recorded on the row for later attempts.
  ///
  /// When the row fails to read, or a read fails and nothing can be proven
  /// without it, the removal is held for the retry sweep and nothing is
  /// recorded. When the row is already gone there is nothing to hold, and
  /// this one attempt goes to [replacementRecipients].
  Future<List<String>> _recipientsForSuperseded(
    String rumorId, {
    required String targetMessageId,
    required List<String> replacementRecipients,
    required String ownerPubkey,
  }) async {
    final DmReactionRow? row;
    try {
      row = await _reactionsDao.getById(id: rumorId, ownerPubkey: ownerPubkey);
    } on Object catch (e, st) {
      _reportRecipientsFailure(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.publishSupersedeRecipients,
      );
      _logHeld(rumorId, targetMessageId: targetMessageId, removal: true);
      return const <String>[];
    }
    if (row == null) return replacementRecipients;
    final stored = _storedRecipients(row);
    if (stored != null) return stored;
    var readFailed = false;
    final derived = await _resolveWrapRecipients(
      conversationId: row.conversationId,
      targetMessageId: row.targetMessageId,
      targetMessageAuthor: row.targetMessageAuthor,
      ownerPubkey: ownerPubkey,
      onReadFailed: () => readFailed = true,
    );
    final recipients = derived == null && readFailed
        ? const <String>[]
        : <String>{...?derived, ...replacementRecipients}.toList();
    if (recipients.isEmpty) {
      _logHeld(
        rumorId,
        targetMessageId: row.targetMessageId,
        conversationId: row.conversationId,
        removal: true,
      );
      return recipients;
    }
    await _storeRecipients(row, recipients);
    return recipients;
  }

  /// Record [recipients] on the queue row [row] if it has none yet and is
  /// still in the conversation they were worked out for. Returns the number
  /// of rows written.
  Future<int> _storeRecipients(
    DmReactionRow row,
    List<String> recipients,
  ) async {
    try {
      return await _reactionsDao.setRecipientPubkeysIfMissing(
        id: row.id,
        ownerPubkey: row.ownerPubkey,
        conversationId: row.conversationId,
        recipientPubkeys: jsonEncode(recipients),
      );
    } on Object catch (e, st) {
      _reportRecipientsFailure(
        e,
        st,
        site: DmReactionsRepositoryReportableSites.wrapRecipientsStore,
      );
      return 0;
    }
  }

  /// The recipient set stored on [row], or `null` when it holds none or one
  /// that cannot be used. An unusable one is logged, since the row then falls
  /// back to being resolved like a row that never stored a set.
  List<String>? _storedRecipients(DmReactionRow row) {
    final stored = _decodePubkeys(row.recipientPubkeys);
    if (stored == null && row.recipientPubkeys != null) {
      Log.warning(
        'DM reaction ${row.id}: its stored recipients cannot be used, so they '
        'are worked out again',
        category: LogCategory.system,
      );
    }
    return stored;
  }

  void _logHeld(
    String rumorId, {
    required String targetMessageId,
    String? conversationId,
    bool removal = false,
  }) {
    final inConversation = conversationId == null
        ? ''
        : ', conversation $conversationId';
    Log.warning(
      'DM reaction ${removal ? 'removal' : 'publish'} held for $rumorId '
      '(message $targetMessageId$inConversation): its recipients cannot be '
      'established from local data, so it stays queued',
      category: LogCategory.system,
    );
  }

  /// Log a failed read or write of a reaction's recipients, or of the state
  /// they are worked out from, by type only, and report it to [site].
  void _reportRecipientsFailure(
    Object error,
    StackTrace stackTrace, {
    required String site,
  }) {
    Log.warning(
      'DM reaction recipients: $site failed (${error.runtimeType})',
      category: LogCategory.system,
    );
    _errorReporter?.call(error, stackTrace, site: site);
  }

  /// Work out who a reaction in [conversationId] is gift-wrapped to: every
  /// conversation participant except [ownerPubkey]. Returns `null` when that
  /// cannot be established; the caller must then not send.
  ///
  /// Resolved from the conversation's participant set, never from
  /// [targetMessageAuthor] alone. Reacting to your OWN message makes you the
  /// target author, and addressing the wrap to the author would send the
  /// reaction only back to yourself. For a 1:1 this yields the single other
  /// participant; for a group, every other member.
  ///
  /// When the conversation row yields no participants (missing, unreadable,
  /// or naming nobody else), a set is accepted only when it is proven. A
  /// conversation id is the hash of its participants, so a set of valid
  /// pubkeys that includes the owner and hashes to [conversationId] is the
  /// whole room. Two are tried: the owner with the author, which is a 1:1,
  /// and the room the reacted message itself names. Anything else stays
  /// unknown, because naming the author alone would drop the other members of
  /// a group (#7880).
  ///
  /// [onReadFailed] is called when a read of that state fails, so a caller
  /// can tell "not provable" from "could not look".
  Future<List<String>?> _resolveWrapRecipients({
    required String conversationId,
    required String targetMessageId,
    required String targetMessageAuthor,
    required String ownerPubkey,
    void Function()? onReadFailed,
  }) async {
    final participants = await _otherParticipants(
      conversationId: conversationId,
      ownerPubkey: ownerPubkey,
      onReadFailed: onReadFailed,
    );
    if (participants != null) return participants;
    List<String>? othersIfRoomIs(Set<String> room) {
      final provable =
          room.every(NostrHexUtils.isValidPubkey) &&
          room.any((pubkey) => pubkeysEqual(pubkey, ownerPubkey)) &&
          DmRepository.computeConversationId(room.toList()) == conversationId;
      if (!provable) return null;
      final others = room
          .where((pubkey) => !pubkeysEqual(pubkey, ownerPubkey))
          .toList();
      return others.isEmpty ? null : others;
    }

    return othersIfRoomIs({ownerPubkey, targetMessageAuthor}) ??
        othersIfRoomIs(
          await _roomNamedByMessage(
            targetMessageId,
            ownerPubkey: ownerPubkey,
            onReadFailed: onReadFailed,
          ),
        );
  }

  /// Every participant of [conversationId] except [ownerPubkey], or `null`
  /// when there is no participant source, or the row is missing, unreadable,
  /// lists something other than pubkeys, leaves out the owner, or names
  /// nobody else.
  Future<List<String>?> _otherParticipants({
    required String conversationId,
    required String ownerPubkey,
    void Function()? onReadFailed,
  }) async {
    final ConversationRow? conversation;
    try {
      conversation = await _conversationsDao?.getConversation(
        conversationId,
        ownerPubkey: ownerPubkey,
      );
    } on Object catch (e, st) {
      _reportRecipientsFailure(
        e,
        st,
        site:
            DmReactionsRepositoryReportableSites.wrapRecipientsConversationRead,
      );
      onReadFailed?.call();
      return null;
    }
    final participants = _decodePubkeys(conversation?.participantPubkeys);
    if (participants == null ||
        !participants.any((pubkey) => pubkeysEqual(pubkey, ownerPubkey))) {
      return null;
    }
    final others = participants
        .where((pubkey) => !pubkeysEqual(pubkey, ownerPubkey))
        .toList();
    return others.isEmpty ? null : others;
  }

  /// The room the stored message [messageId] names: its sender and `p` tags
  /// (NIP-17). Empty when the message is not stored or cannot be read.
  Future<Set<String>> _roomNamedByMessage(
    String messageId, {
    required String ownerPubkey,
    void Function()? onReadFailed,
  }) async {
    final DirectMessageRow? message;
    try {
      message = await _directMessagesDao?.getMessageById(
        messageId,
        ownerPubkey: ownerPubkey,
      );
    } on Object catch (e, st) {
      _reportRecipientsFailure(
        e,
        st,
        site: DmReactionsRepositoryReportableSites
            .wrapRecipientsTargetMessageRead,
      );
      onReadFailed?.call();
      return const {};
    }
    if (message == null) return const {};
    return reconstructParticipants(message.tagsJson, message.senderPubkey);
  }

  /// Decode a JSON list of pubkeys, or `null` when [json] is not a non-empty
  /// list made only of valid pubkeys.
  static List<String>? _decodePubkeys(String? json) {
    if (json == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;
    final pubkeys = <String>[];
    for (final entry in decoded) {
      if (entry is! String || !NostrHexUtils.isValidPubkey(entry)) return null;
      pubkeys.add(entry);
    }
    return pubkeys;
  }

  /// Resolve each recipient's kind-10050 inbox once for the whole tap.
  ///
  /// An emoji swap drives two fan-outs milliseconds apart — the kind-5 that
  /// removes the old emoji and the kind-7 that adds the new one — to sets that
  /// usually coincide, so looking the same person up twice would be redundant
  /// latency for an answer that cannot have changed. Resolved once, for
  /// everyone either fan-out names, rather than inside `_fanOutRumor` so both
  /// share it; the optimistic row is already written by then, so this never
  /// delays the visible chip.
  Future<Map<String, DmInboxLookup>> _inboxesForTap(
    List<String> recipients,
    Iterable<List<String>> priorRecipients,
  ) {
    return _resolveInboxes(
      <String>{
        ...recipients,
        for (final prior in priorRecipients) ...prior,
      }.toList(),
    );
  }

  /// Durably remove each superseded prior reaction (cap-at-one emoji swap).
  ///
  /// Routed through the same `deletion_pending` + sweep machinery as an
  /// explicit un-react, so a flaky/offline relay can't strand the old emoji on
  /// the recipient. Only the durable DAO write is awaited; the wire publish is
  /// fire-and-forget inside [_durablyDeleteReaction], kept outside the
  /// optimistic insert transaction so a stalled socket never blocks the local
  /// write.
  ///
  /// Intentional ordering tradeoff: the removal commits before the new
  /// emoji's fan-out is confirmed, so a hard-failed swap degrades into a bare
  /// removal on the recipient rather than rolling back to the old emoji. That
  /// matches the sender's view — the old row is already soft-deleted locally
  /// and the new emoji stays as a retryable failed chip — whereas a wire
  /// rollback would desync the two sides. Recovery is re-tapping (or the sweep
  /// re-driving) the new emoji.
  Future<void> _removeSuperseded(
    Map<String, List<String>> priors, {
    required String targetMessageAuthor,
    required String ownerPubkey,
    required NIP17MessageService messageService,
    required Future<Map<String, DmInboxLookup>> inboxes,
  }) async {
    for (final MapEntry(key: priorId, value: priorRecipients)
        in priors.entries) {
      try {
        await _durablyDeleteReaction(
          rumorId: priorId,
          recipients: priorRecipients,
          targetMessageAuthor: targetMessageAuthor,
          ownerPubkey: ownerPubkey,
          messageService: messageService,
          reportSite:
              DmReactionsRepositoryReportableSites.publishSupersedeDeletion,
          inboxes: inboxes,
        );
      } on Object {
        // Already reported by _durablyDeleteReaction. The new reaction is
        // persisted by now, so it is still sent; this prior's kind-5 is lost
        // (#9915).
      }
    }
  }

  /// Resolve every recipient's NIP-17 kind-10050 DM inbox concurrently.
  ///
  /// Hoisted out of the per-recipient send loop and run in parallel, exactly as
  /// `DmRepository.sendGroupMessage` does: resolution is a live relay query
  /// capped at 5 s and is not meaningfully cached, so resolving inside the loop
  /// would cost N sequential waits before the last wrap is even attempted.
  ///
  /// Every lookup is isolated. [DmInboxRelayResolver]'s contract forbids
  /// throwing and `DmRepository.resolveDmInboxRelaysDetailed` honours it, but
  /// the resolver is an injected port rather than a method this class owns —
  /// and an unguarded `Future.wait` fails *whole* on a single rejection, which
  /// would turn one bad lookup into a failed fan-out instead of one recipient
  /// falling back to the default pool. A lookup that threw is recorded as
  /// [DmInboxResolution.unreadable]: we did not read that inbox, so the pool
  /// `OK` it falls back to cannot be scored as delivery (#8443).
  ///
  /// Returns an empty map when no resolver is wired, so every recipient reads
  /// back `null` and routing is byte-identical to the pre-#7321 behaviour.
  Future<Map<String, DmInboxLookup>> _resolveInboxes(
    List<String> recipients,
  ) async {
    final resolve = _resolveDmInboxRelays;
    if (resolve == null) return const <String, DmInboxLookup>{};
    final inboxes = <String, DmInboxLookup>{};
    // try/catch rather than `.catchError(...)`: on a typed `Future` that
    // handler is only type-checked at runtime, and Dart rejects it with "The
    // error handler of Future.catchError must return a value of the future's
    // type" — turning the guard into the very crash it exists to prevent.
    // Caught by the throwing-resolver test.
    Future<void> resolveOne(String recipient) async {
      try {
        inboxes[recipient] = await resolve(recipient);
      } on Object {
        inboxes[recipient] = (
          relays: null,
          state: DmInboxResolution.unreadable,
        );
      }
    }

    await Future.wait(recipients.map(resolveOne));
    return inboxes;
  }

  /// Wrap [rumor] to each of [recipients] (each send also self-wraps for
  /// cross-device recovery; self-wrap copies dedupe on the rumor id at the
  /// receiver). Terminal success ONLY when EVERY recipient wrap lands.
  ///
  /// A group reaction persists as one row that can't track per-recipient
  /// delivery, so a partial fan-out (one member confirmed, another timed
  /// out/rejected) must NOT report success — the caller would mark the row
  /// `sent` and clear its stored rumor, leaving the missed member's wrap
  /// unrecoverable. Instead any non-confirming recipient makes the whole
  /// fan-out a retryable failure; the sweep re-drives the full rumor and the
  /// receiver-side dedup on rumor id makes re-delivery to already-confirmed
  /// members idempotent.
  ///
  /// [awaitRecipientOk] requires the relay's NIP-20 `OK true` for each
  /// recipient wrap before it counts as landed (see
  /// [NIP17MessageService.sendRumor]). Reaction sends/retries opt in so a
  /// flaky relay's frame-accept false positive can't mark an undelivered
  /// reaction as sent.
  ///
  /// A recipient's wrap "lands" only when the relay it was sent to confirms
  /// it AND that relay is one the recipient reads. When their kind-10050
  /// could not be read the wrap falls back to the default pool, and the
  /// pool's `OK` is downgraded to a soft failure — the same rule the 1:1
  /// send and its retry apply through [downgradeFallbackPoolDelivery]
  /// (#7317). Scoring it as landed here is #8443: the row goes `sent`, its
  /// stored rumor is cleared, and a reaction the recipient never saw becomes
  /// unrecoverable. A recipient with no lookup at all (no resolver wired)
  /// keeps the pre-#7321 contract, where a pool `OK` is delivery.
  ///
  /// An empty [recipients] is a hard failure with nothing sent;
  /// [_recipientsOrHold] relies on that to hold a row.
  ///
  /// Aggregate failure classification:
  /// - every failure is a policy [NIP17SendResult.blocked] → aggregate blocked
  ///   (terminal, non-retryable — the non-blocked members all confirmed).
  /// - otherwise → a retryable failure whose `retryablePending` is `true` only
  ///   when every failure is itself soft (`retryablePending`, which the
  ///   unreadable-inbox downgrade is); a single hard rejection/offline member
  ///   makes the whole fan-out hard-failed so the sweep re-drives it without
  ///   the in-flight min-age hold.
  Future<NIP17SendResult> _fanOutRumor({
    required NIP17MessageService messageService,
    required Event rumor,
    required List<String> recipients,
    Map<String, DmInboxLookup>? inboxByRecipient,
    bool awaitRecipientOk = false,
  }) async {
    if (recipients.isEmpty) {
      return const NIP17SendResult.failure('No reaction wrap recipients');
    }
    final inboxes = inboxByRecipient ?? await _resolveInboxes(recipients);
    NIP17SendSuccess? lastSuccess;
    final failures = <NIP17SendFailure>[];
    for (final recipient in recipients) {
      final inbox = inboxes[recipient];
      final published = await _sendRumorWithTimeout(
        messageService: messageService,
        rumor: rumor,
        recipientPubkey: recipient,
        targetRelays: inbox?.relays,
        awaitRecipientOk: awaitRecipientOk,
      );
      final result = inbox == null
          ? published
          : downgradeFallbackPoolDelivery(published, inbox.state);
      switch (result) {
        case NIP17SendSuccess():
          lastSuccess = result;
        case NIP17SendFailure():
          failures.add(result);
      }
    }
    if (failures.isEmpty) {
      // Every recipient confirmed — terminal success.
      return lastSuccess ??
          const NIP17SendResult.failure('No reaction wrap recipients');
    }
    final summary = failures.map((f) => f.error).join('; ');
    if (failures.every((f) => f.blocked)) {
      return NIP17SendResult.blocked(summary);
    }
    return NIP17SendResult.failure(
      summary,
      retryablePending: failures.every((f) => f.retryablePending),
    );
  }

  /// Resolve the conversation id for an incoming reaction.
  ///
  /// A kind-7 reaction only carries `e`/`p`/`k` tags, never the full group
  /// participant set, so the authoritative source is the reacted message's
  /// stored row (looked up by its rumor id) — this resolves both 1:1 and
  /// group conversations correctly. When the target isn't in the local store
  /// (e.g. a group reaction arriving before the reel message synced — a
  /// narrow window since the reel is persisted at send time), falls back to
  /// 1:1 inference, dropping group reactions rather than mis-attributing them.
  /// A reaction filed by that fallback is moved once its message is stored in
  /// a room; see [adoptReceivedForStoredMessage].
  Future<String?> _resolveConversationIdForReaction({
    required String reactorPubkey,
    required String targetAuthor,
    required String targetMessageId,
  }) async {
    final messagesDao = _directMessagesDao;
    if (messagesDao != null) {
      try {
        final targetRow = await messagesDao.getMessageById(
          targetMessageId,
          ownerPubkey: _userPubkey,
        );
        if (targetRow != null) return targetRow.conversationId;
      } on Object {
        // Fall through to 1:1 inference.
      }
    }
    if (reactorPubkey != _userPubkey && targetAuthor != _userPubkey) {
      return null;
    }
    final participants = <String>{reactorPubkey, targetAuthor}.toList();
    if (participants.length != 2) return null;
    return DmRepository.computeConversationId(participants);
  }

  DmReaction _rowToModel(DmReactionRow row) {
    final publishStatus = switch (row.publishStatus) {
      'pending' => DmReactionPublishStatus.pending,
      'failed' => DmReactionPublishStatus.failed,
      'sent' => DmReactionPublishStatus.sent,
      'blocked' => DmReactionPublishStatus.blocked,
      DmReactionsDao.deletionRefused => DmReactionPublishStatus.removalRefused,
      _ => DmReactionPublishStatus.received,
    };
    return DmReaction(
      id: row.id,
      conversationId: row.conversationId,
      targetMessageId: row.targetMessageId,
      targetMessageAuthor: row.targetMessageAuthor,
      reactorPubkey: row.reactorPubkey,
      emoji: row.emoji,
      createdAt: row.createdAt,
      ownerPubkey: row.ownerPubkey,
      publishStatus: publishStatus,
      giftWrapId: row.giftWrapId,
    );
  }
}
