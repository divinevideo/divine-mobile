// ABOUTME: Repository for NIP-17 and NIP-04 direct message management.
// ABOUTME: Handles subscribing to gift-wrapped (NIP-17) and legacy encrypted
// ABOUTME: (NIP-04) events, decrypting messages, persisting to the database,
// ABOUTME: and providing reactive streams.
// ABOUTME: Supports Kind 14 (text), Kind 15 (file), and Kind 4 (NIP-04 DM).
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/src/build_mode.dart';
import 'package:dm_repository/src/collaborator_invite_recovery.dart';
import 'package:dm_repository/src/compute.dart';
import 'package:dm_repository/src/dm_batch_send_budget.dart';
import 'package:dm_repository/src/dm_clock.dart';
import 'package:dm_repository/src/dm_decrypt_isolate.dart';
import 'package:dm_repository/src/dm_decryption_worker.dart';
import 'package:dm_repository/src/dm_message_size.dart';
import 'package:dm_repository/src/dm_reactions_repository.dart';
import 'package:dm_repository/src/dm_removal_policy.dart';
import 'package:dm_repository/src/dm_repository_reportable_sites.dart';
import 'package:dm_repository/src/dm_send_budget.dart';
import 'package:dm_repository/src/dm_shared_video_citation.dart';
import 'package:dm_repository/src/dm_subscription_ids.dart';
import 'package:dm_repository/src/dm_sync_state.dart';
import 'package:dm_repository/src/dm_verify_isolate.dart';
import 'package:dm_repository/src/group_conversation_recovery.dart';
import 'package:dm_repository/src/nip17_message_service.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:nostr_sdk/nip59/gift_wrap_batch_unwrap.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/signer/isolate_decrypt_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:nostr_sdk/utils/relay_url_policy.dart';
import 'package:unified_logger/unified_logger.dart';

/// Decrypts a gift-wrapped event (kind 1059) through the NIP-17 layers
/// (gift wrap → seal → rumor) and returns the inner rumor event.
///
/// Returns `null` if decryption fails at any layer.
typedef RumorDecryptor = Future<Event?> Function(Nostr nostr, Event giftWrap);

/// Decrypts a NIP-04 encrypted direct message (kind 4).
///
/// [peerPubkey] is the other party's pubkey (the counterpart in the
/// conversation, NOT the current user's pubkey).
/// [ciphertext] is the NIP-04 ciphertext from the event content.
///
/// Returns the decrypted plaintext, or `null` if decryption fails.
typedef Nip04Decryptor =
    Future<String?> Function(String peerPubkey, String ciphertext);

/// Forwarder for DAO-bookkeeping failures inside [DmRepository].
///
/// The repository swallows these failures after [Log.error] to keep the
/// recovery primitive idempotent on doubly-degraded paths (publish
/// landed, bookkeeping write failed — see #4127). Wiring an
/// implementation routes the same signal to Crashlytics without
/// crossing the `dm_repository` → app package boundary.
///
/// [site] is one of `DmRepositoryReportableSites`'s constants and is
/// used as the Crashlytics `reason:` suffix so the dashboard aggregates
/// per swallow site.
///
/// Implementations MUST NOT throw — the repository invokes after the
/// existing `Log.error` and any throw would defeat the swallow.
typedef DmRepositoryErrorReporter =
    void Function(Object error, StackTrace stackTrace, {required String site});

/// Supported NIP-17 rumor event kinds.
const Set<int> _supportedDmKinds = {
  EventKind.privateDirectMessage, // 14
  EventKind.fileMessage, // 15
};

/// Process-local key for support-only DM content correlation tokens.
///
/// Never persist or log this key: changing it on restart prevents tokens from
/// linking message content across separately submitted support reports.
final List<int> _dmContentCorrelationKey = _newDmContentCorrelationKey();

List<int> _newDmContentCorrelationKey() {
  final random = Random.secure();
  return List<int>.unmodifiable(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}

String _dmContentCorrelation({
  required String conversationId,
  required String senderPubkey,
  required String content,
}) {
  final scopedContent = jsonEncode([conversationId, senderPubkey, content]);
  return Hmac(
    sha256,
    _dmContentCorrelationKey,
  ).convert(utf8.encode(scopedContent)).toString().substring(0, 16);
}

/// Tuning for the one-time full-history drain
/// (`DmRepository.backfillHistoryIfNeeded`).
///
/// The drain pages relays newest→oldest until the relay runs out of
/// events or [maxPages] is reached, whichever comes first. The cap is a
/// safety valve for pathological histories: because the drain walks
/// newest-first and a conversation appears as soon as *any* of its
/// messages is persisted, the most-recent [maxPages] × [pageSize] window
/// already contains the latest message of essentially every active
/// conversation.
abstract class DmHistoryDrainConfig {
  /// Events requested per relay page.
  static const int pageSize = 100;

  /// Maximum pages fetched in a single drain (≈ [pageSize] × this events).
  static const int maxPages = 50;

  /// Maximum NIP-44 decryption attempts for a single gift wrap before the
  /// failed-decrypt retry queue gives up on it. Generous so a transient
  /// remote-signer (Keycast RPC) outage spanning several inbox opens still
  /// recovers, while a permanently-undecryptable wrap cannot loop forever.
  /// See #5202.
  static const int maxDecryptRetries = 10;

  /// Gift wraps decrypted per hop fed to the drain-scoped long-lived decrypt
  /// isolate on the history-drain path. Sub-chunks a [pageSize] page to bound
  /// peak isolate memory, the off-lock decrypt duration, and the per-message
  /// port payload. See #5391.
  static const int decryptBatchSize = 20;

  /// Events processed between cooperative event-loop yields in the serial
  /// backfill loops, so a large drain cannot starve frame rendering. See
  /// #5391.
  static const int drainYieldInterval = 16;

  /// Remote-signer (Keycast RPC / Amber / NIP-46) gift-wrap decrypts kept in
  /// flight at once during the history drain.
  ///
  /// Remote signers cannot cross the [compute] isolate boundary, so each wrap
  /// is decrypted by a network round trip to the signer (~250-400 ms each, two
  /// per wrap: gift→seal, seal→rumor). Draining a large history one RPC at a
  /// time serializes those into minutes. A bounded worker pool keeps several in
  /// flight, collapsing the wall-clock to roughly 1/N. Held under Keycast's
  /// per-connection DB pool (default 10) so parallel calls don't contend, and
  /// only *decryption* is parallelized — persistence stays serialized under the
  /// event lock. Local-key signers are unaffected (they use the batch isolate).
  static const int remoteDecryptConcurrency = 8;

  /// Gift wraps unwrapped per server round trip on the remote-signer drain via
  /// the Keycast `nip17_unwrap_batch` verb. Capped at the server's batch limit
  /// (100), so a [pageSize] page is one chunk. See #5471.
  static const int unwrapBatchSize = 100;
}

/// Compile-time gate for temporary per-conversation classification
/// diagnostics. Off by default and structurally disabled in release builds:
/// the `!kReleaseMode` term folds the constant to `false` under AOT product
/// mode, so `DM_CLASSIFY_DIAGNOSTICS` can never enable follow-graph logging
/// in a distributed build. Enable for a targeted repro on a debug/profile
/// build with `--dart-define=DM_CLASSIFY_DIAGNOSTICS=true`.
// TODO(realmeylisdev): remove DM classify diagnostics after #5374.
const bool _classifyDiagnostics =
    bool.fromEnvironment('DM_CLASSIFY_DIAGNOSTICS') && !kReleaseMode;

/// Caps how long `ensureDmRelayListPublished` waits for the
/// signer when self-publishing the user's kind-10050 DM inbox relay list.
/// A hung remote signer (Keycast RPC) must not block login; on timeout the
/// publish is abandoned with the persistence flag left unset so the next
/// login retries. Mirrors AuthService's kind-10002 bootstrap discipline.
/// See #4974.
const Duration _dmRelayListSignTimeout = Duration(seconds: 10);

/// Budget for an ordinary kind-10050 lookup — the recipient resolve on the
/// send path and the memoized own-inbox read. Restates `NostrClient`'s own
/// default so the two call shapes read alike; changing it changes nothing
/// about which relays answer.
const Duration _dmInboxQueryTimeout = Duration(seconds: 5);

/// A discovery-only relay is optional coverage, not the primary read path.
/// Keep its cold handshake below the pool lookup budget so one unreachable
/// indexer cannot hold the whole recipient resolution open (#7317).
const Duration _dmInboxDiscoveryQueryTimeout = Duration(seconds: 2);

/// Budget for the authoritative own-inbox read that gates the RC3 publish.
///
/// Deliberately shorter than [_dmInboxQueryTimeout]. `requireAllRelaysSettled`
/// waits for every relay that took the REQ, so one connected-but-silent relay
/// spends the whole budget even after a healthy relay has answered (measured
/// at 6004ms on a 6s budget). Every relay in the default pool that answers at
/// all answers in 0.5-1.1s, so a shorter budget stays conclusive in the normal
/// case and halves the cost of the pathological one. An expiry reports
/// `timedOut`, which is `failed`, which does not publish — so erring short errs
/// toward not overwriting. See #8212.
const Duration _ownDmInboxAuthoritativeTimeout = Duration(seconds: 3);

/// Hard backstop on a single NIP-17 message publish (wrap build + recipient
/// wrap OK-confirm + self-wrap). On timeout the send is reported as a soft,
/// retryable-pending failure (the frame may already be written), so the
/// durable queue keeps the row and the retry sweep re-drives it rather than
/// parking a red chip.
///
/// Every sub-step carries its own bound — see [DmSendBudget], which owns the
/// derivation. This cap exists only to bound a truly hung await, and it must
/// sit ABOVE [DmBatchSendBudget.chainWorstCase] or it fires mid-send and
/// misclassifies it.
///
/// That is exactly what went wrong in #6586. The bound was hand-derived from a
/// Keycast per-RPC timeout of 12s; #6075 raised that timeout to 30s (correctly
/// — 12s had regressed video-publish signing, likes, reposts and follows) and
/// the derivation here was never redone. A 1:1 send costs **four** measured
/// signer round trips, so the honest chain became (2 × 30s) + 10s + (2 × 30s)
/// + 10s = 140s against a 90s cap.
///
/// Because the self-wrap is built only after the recipient's `OK true`
/// arrives, that 140s path was the *delivery* path: the cap fired on sends the
/// recipient had already received, parking them as soft-unconfirmed until the
/// retry budget terminalised them into a red bubble. The cure is not a bigger
/// number — the wrap builds now carry explicit bounds
/// ([DmSendBudget.recipientWrapBuild], [DmSendBudget.selfWrapBuild]), which is
/// what stops the *signing chain* outrunning this cap even when the signer path
/// is slower. Amber's NIP-55 intent path for `nip44Encrypt` and `signEvent` is
/// human-gated and unbounded, so a recipient-build timeout leaves the durable
/// row pending for retry instead of red-failed.
///
/// That covers the signing chain, not the whole send. Three awaited steps
/// inside this cap are still unbounded and deliberately NOT in
/// [DmBatchSendBudget.chainWorstCase]: `refreshPublicKey()` (a real round trip
/// for any signer that doesn't cache the pubkey, e.g. a NIP-46 bunker —
/// Keycast does cache it), the send-policy protected-minor check, and the
/// connectivity probe. So this cap remains a genuine backstop for those, and
/// [DmBatchSendBudget.chainWorstCase] is a floor on what a send can cost, not a
/// ceiling. Bounding them is tracked separately.
///
/// A 15s cap here (the original value) fired during routine slow-Keycast
/// sends, turning sends that were still legitimately in flight into
/// eternally-retrying rows — the reason this backstop must stay generous.
const Duration _messagePublishTimeout = DmBatchSendBudget.messagePublishTimeout;

/// Outcome of resolving a user's own kind-10050 DM inbox relay list (#4974).
///
/// Distinguishes a genuine absence from a transient query failure so callers
/// don't conflate them: the live subscription / drain fall back to the
/// default pool on either, but RC3 must only publish-when-`absent` and never
/// overwrite a real list when the lookup merely `failed`.
/// Which local account terminally handled an already-processed event.
///
/// Only meaningful for NIP-04. A kind-1059 wrap id belongs to exactly one
/// recipient, so "processed" and "processed by us" are the same fact there.
enum _Nip04DedupHit {
  /// Not processed by anyone on this device.
  none,

  /// Processed by the account that is receiving it now.
  thisAccount,

  /// Processed by a different local account, so this one never stored it.
  otherAccount,
}

/// What a removal request resolves to, before anything is written.
///
/// [absent] and [removable] both report `removed` to the caller — a stale id
/// must never become an undeletable row — but they differ in what they leave
/// behind. Only [removable] earns a `removed_conversations` tombstone, because
/// that marker is permanent and suppresses every replayed message at or before
/// its timestamp (#7850).
enum _RemovalDisposition {
  /// No row for this id under this owner. Nothing to delete, nothing to
  /// suppress.
  absent,

  /// The injected policy protects this conversation.
  protected,

  /// On disk and not protected.
  removable,
}

enum _OwnDmInboxState {
  /// The user advertises a kind-10050 with at least one allowed relay.
  found,

  /// The query succeeded but the user has no kind-10050 (or none with an
  /// allowed relay) — safe for RC3 to self-publish.
  absent,

  /// The query threw / timed out — outcome unknown; do not publish, retry.
  failed,
}

/// Why a recipient's NIP-17 DM inbox lookup returned what it did.
///
/// The relay list alone cannot answer this: [DmInboxResolution.absent] and
/// [DmInboxResolution.unreadable] both yield `null` relays and both fall back
/// to the default pool, but only the first is a fact about the recipient. The
/// second is a fact about our own read, and scoring a fallback-pool `OK` as
/// delivery on it tells the sender a message arrived when it was written where
/// the recipient does not look (#7317).
enum DmInboxResolution {
  /// The recipient advertises a kind-10050 and we read it.
  found,

  /// The relays answered, and the recipient advertises no usable inbox.
  /// NIP-17 calls this "not ready to receive messages"; we still fall back to
  /// the default pool so reachability is preserved (#570).
  absent,

  /// We could not read the recipient's inbox: no relay took the REQ, or
  /// nothing settled inside the budget. Says nothing about the recipient.
  unreadable,
}

/// A recipient's resolved NIP-17 DM inbox: the relays to route a gift wrap to,
/// and why the lookup returned what it did.
///
/// `relays` is `null` for both [DmInboxResolution.absent] and
/// [DmInboxResolution.unreadable]; `state` is what lets a caller that reports
/// delivery tell the two apart (#7317, #8443).
typedef DmInboxLookup = ({List<String>? relays, DmInboxResolution state});

/// Re-classifies a publish that a relay confirmed but which was routed to the
/// default pool because the recipient's inbox could not be read.
///
/// [DmInboxResolution.absent] is left alone: the recipient advertises no
/// inbox, so the pool is where they read and the `OK` is real delivery.
/// [DmInboxResolution.unreadable] is a fact about our own read — the wrap may
/// be sitting on relays the recipient never queries, so it is reported
/// soft-unconfirmed and the durable row is kept for the sweep to re-resolve
/// (#7317). Shared by every gift-wrap publisher that also reports delivery —
/// the 1:1 send, its retry, the reaction fan-out (#8443), the deletion
/// fan-out (#8515), and the group send (#8434) — so no sweep can undo what a
/// send path preserved. A fan-out applies it per recipient: NIP-17 states the
/// rule against "the recipient's kind 10050 event" (17.md:77), so a readable
/// member is delivered even when a sibling in the same batch is not.
///
/// Logs the hold. The message service has already logged `Successfully
/// published` for this wrap — the relay did confirm it — so without this line
/// a support log reads as a delivered send with no trace of why the row is
/// still pending. Both ids are logged whole: the wrap id is what a relay
/// read-back finds, the rumor id is what the durable row is keyed by.
NIP17SendResult downgradeFallbackPoolDelivery(
  NIP17SendResult result,
  DmInboxResolution state,
) {
  if (result is! NIP17SendSuccess || state != DmInboxResolution.unreadable) {
    return result;
  }
  Log.info(
    'NIP-17 wrap ${result.messageEventId} (rumor ${result.rumorEventId}) to '
    '${pubkeyForLogs(result.recipientPubkey)} was confirmed only by the '
    'fallback pool while their inbox was unreadable — holding it pending, not '
    'scoring it delivered (#7317, #8443)',
    category: LogCategory.system,
  );
  return const NIP17SendResult.failure(
    'Recipient DM inbox unreadable; published to the fallback pool',
    retryablePending: true,
  );
}

/// Who authored the kind-10050 a relay list is being read out of.
///
/// The two are admitted on different terms. Our own list may name the local
/// stack; a counterparty's may not name anything on this device's network.
enum _DmRelayListSource {
  /// The signed-in user's own kind-10050.
  selfAuthored,

  /// A counterparty's kind-10050, resolved to route a gift wrap to them.
  remote,
}

/// Terminal state of one delete-for-everyone delivery attempt.
enum DmMessageDeletionOutcome {
  /// A relay confirmed the wrap. The row is settled; stop re-driving.
  sent,

  /// Send policy blocked every failed recipient. Terminal, but not fully
  /// delivered — some recipients may already have received the retraction.
  /// The row records `deletion_blocked` rather than claiming full delivery.
  blocked,

  /// Nothing confirmed. The row stays pending for the next sweep.
  unconfirmed,

  /// Nothing to drive: no credentials, no row, no stored rumor, or no
  /// recipient. Not an attempt, so it does not consume a retry budget.
  unavailable,
}

/// A soft-deleted own message whose kind-5 wrap has not been confirmed,
/// projected from its `direct_messages` row for the retry sweep.
@immutable
class DmMessageDeletionRetryTarget {
  /// Construct a retry target.
  const DmMessageDeletionRetryTarget({
    required this.rumorId,
    required this.conversationId,
    required this.createdAt,
  });

  /// Rumor id of the deleted message — the argument
  /// [DmRepository.retryMessageDeletion] expects.
  final String rumorId;

  /// Conversation the message belongs to; the wrap recipients are resolved
  /// from its participant set.
  final String conversationId;

  /// Deleted message's `created_at` (unix seconds). Orders the sweep.
  final int createdAt;
}

/// Repository for NIP-17 direct message operations.
///
/// Manages the full DM lifecycle:
/// - **Receiving**: Subscribes to kind 1059 gift-wrap events, decrypts
///   through the three-layer encryption, and persists decrypted messages.
///   Supports both kind 14 (text) and kind 15 (file) messages.
/// - **Sending**: Delegates to [NIP17MessageService] for encryption and
///   publishing.
/// - **Querying**: Provides reactive streams for conversation lists and
///   individual conversation messages via Drift DAOs.
///
/// Accepts any [NostrSigner] implementation (local keys, Keycast RPC,
/// Amber, etc.) for NIP-17 gift-wrap decryption. The signer is held for
/// the lifetime of this object; callers should ensure the repository is
/// disposed when the user logs out.
///
/// ## Retention
///
/// Nothing here expires. No DM table is pruned by age or size: rows leave only
/// when the user removes a conversation, when an account is switched or signed
/// out, or when the account's data is deleted. `pending_gift_wraps` is the one
/// exception, bounded by its decrypt-attempt cap.
///
/// That makes the **relay** the binding constraint on how long a message
/// survives, not this repository. NIP-59 makes storing a `kind:1059` optional
/// and tells relays to delete wraps addressed to a pubkey that requests a
/// NIP-62 vanish, so a copy this device drops may be unrecoverable rather than
/// merely re-fetched. [removeConversation]'s tombstone is written with that in
/// mind, and is why it must never be recorded for a conversation this device
/// does not actually have.
///
/// The full cross-store picture, including the server-side moderation DM log
/// that behaves in the opposite direction, is in `mobile/docs/DM_RETENTION.md`.
class DmRepository {
  /// Creates a [DmRepository] with the given dependencies.
  ///
  /// [errorReporter] is invoked from each DAO-bookkeeping swallow site
  /// (see [DmRepositoryErrorReporter] and `DmRepositoryReportableSites`)
  /// after the in-repo [Log.error] call. Defaults to `null` so existing
  /// test fixtures keep working without rewiring; production wires it
  /// through `dmRepositoryProvider` to forward to Crashlytics.
  DmRepository({
    required NostrClient nostrClient,
    required DirectMessagesDao directMessagesDao,
    required ConversationsDao conversationsDao,
    OutgoingDmsDao? outgoingDmsDao,
    PendingGiftWrapsDao? pendingGiftWrapsDao,
    ProcessedGiftWrapsDao? processedGiftWrapsDao,
    RemovedConversationsDao? removedConversationsDao,
    DmSyncState? syncState,
    NIP17MessageService? messageService,
    String? userPubkey,
    NostrSigner? signer,
    RumorDecryptor? rumorDecryptor,
    Nip04Decryptor? nip04Decryptor,
    DmDecryptIsolateSpawner? decryptIsolateSpawner,
    DmVerifyIsolateSpawner? verifyIsolateSpawner,
    DmRepositoryErrorReporter? errorReporter,
    DmReactionsRepository? reactionsRepository,
    DmConversationRemovalPolicy? removalPolicy,
    String? dmInboxRelayUrl,
    List<String> dmInboxDiscoveryRelays = const <String>[],
    List<String> dmInboxLookupRelays = const <String>[],
    List<String> dmInboxTaggedRelays = const <String>[],
    Duration readMarkerDebounceDelay = _defaultReadMarkerDebounceDelay,
    String Function()? sendBatchIdGenerator,
  }) : _nostrClient = nostrClient,
       _readMarkerDebounceDelay = readMarkerDebounceDelay,
       _directMessagesDao = directMessagesDao,
       _conversationsDao = conversationsDao,
       _outgoingDmsDao = outgoingDmsDao,
       _pendingGiftWrapsDao = pendingGiftWrapsDao,
       _processedGiftWrapsDao = processedGiftWrapsDao,
       _removedConversationsDao = removedConversationsDao,
       _syncState = syncState,
       _messageService = messageService,
       _userPubkey = userPubkey ?? '',
       _signer = signer,
       _rumorDecryptor = rumorDecryptor ?? GiftWrapUtil.getRumorEvent,
       _nip04Decryptor = nip04Decryptor,
       _decryptIsolateSpawner = decryptIsolateSpawner ?? DmDecryptIsolate.spawn,
       _verifyIsolateSpawner = verifyIsolateSpawner ?? DmVerifyIsolate.spawn,
       _errorReporter = errorReporter,
       _reactionsRepository = reactionsRepository,
       _removalPolicy = removalPolicy ?? allowAllConversationRemoval,
       _dmInboxRelayUrl = dmInboxRelayUrl,
       _dmInboxDiscoveryRelays = dmInboxDiscoveryRelays,
       _dmInboxLookupRelays = dmInboxLookupRelays,
       _dmInboxTaggedRelays = dmInboxTaggedRelays,
       _newSendBatchId = sendBatchIdGenerator ?? _defaultSendBatchId;

  final NostrClient _nostrClient;
  final DirectMessagesDao _directMessagesDao;
  final ConversationsDao _conversationsDao;

  /// Optional DAO for the durable outgoing-DM queue. When provided,
  /// [sendMessage] enqueues a row before publishing so a crash mid-send
  /// leaves a recoverable trace; the retry service introduced later in
  /// the #3909 stack uses this same queue. Nullable to keep older test
  /// fixtures working without rewiring — when `null`, [sendMessage]
  /// keeps its previous direct-write behaviour.
  final OutgoingDmsDao? _outgoingDmsDao;

  /// Optional DAO for the durable failed-decrypt gift-wrap retry queue.
  /// When provided, gift wraps that fail NIP-44 decryption are persisted
  /// here (instead of being silently dropped) so [retryPendingDecryptions]
  /// can recover them on a later inbox open — the H2 resilience path for
  /// flaky remote-signer (Keycast RPC) decryption. Nullable to keep older
  /// test fixtures working without rewiring. See #5202.
  final PendingGiftWrapsDao? _pendingGiftWrapsDao;

  /// Optional dedup ledger for gift wraps whose decrypted rumor writes no
  /// `directMessages` row — reactions (kind 7), deletions (kind 5),
  /// unsupported kinds, cross-protocol duplicates, degenerate participant
  /// sets, and messages suppressed by a removed-conversation tombstone. The
  /// ledger also carries NIP-04 event ids suppressed by a tombstone, so both
  /// protocols treat replayed removed history as terminally processed.
  /// Consulted alongside [DirectMessagesDao.hasGiftWrap] in the pre-decrypt
  /// dedup so those wraps are not re-decrypted on every launch (a serial
  /// remote-signer RPC each). Nullable to keep older test fixtures working
  /// without rewiring. See #5452.
  final ProcessedGiftWrapsDao? _processedGiftWrapsDao;

  /// Durable owner-scoped removal markers. Relay events are replayable, so a
  /// hard delete without this ledger would restore the thread on restart.
  final RemovedConversationsDao? _removedConversationsDao;

  final DmSyncState? _syncState;
  NIP17MessageService? _messageService;
  String _userPubkey;
  NostrSigner? _signer;
  RumorDecryptor _rumorDecryptor;

  /// Latches true once the active signer's keycast is found not to support the
  /// `nip17_unwrap_batch` verb, so the drain stops probing it and uses the
  /// per-wrap fallback pool for the rest of the session. Reset when the signer
  /// changes. See #5471.
  bool _batchUnwrapUnsupported = false;
  Nip04Decryptor? _nip04Decryptor;
  final DmDecryptIsolateSpawner _decryptIsolateSpawner;
  final DmVerifyIsolateSpawner _verifyIsolateSpawner;
  final DmRepositoryErrorReporter? _errorReporter;

  /// Optional sibling repository for NIP-25 reactions on DMs. When wired,
  /// [_handleGiftWrapEvent] routes kind-7 rumors to it instead of
  /// persisting them as DMs. Nullable to keep existing tests working
  /// without rewiring; production injects it via `dmRepositoryProvider`.
  final DmReactionsRepository? _reactionsRepository;

  /// Which peers hold a conversation this repository refuses to remove.
  ///
  /// Injected so the package never learns Divine's own pubkeys. Defaults to
  /// [allowAllConversationRemoval], so a fixture that wires nothing behaves as
  /// it did before the policy existed; production injects the moderation
  /// identities via `dmRepositoryProvider`.
  final DmConversationRemovalPolicy _removalPolicy;

  /// The stable relay URL advertised by the kind-10050 publish (the
  /// environment's canonical DM relay, mirroring the kind-10002 bootstrap).
  /// `null` in fixtures that don't exercise the publish; when `null`,
  /// [ensureDmRelayListPublished] is a no-op (nothing to advertise).
  ///
  /// This is the primary `relay` tag in the published list and the relay whose
  /// `OK` decides success — it is where Divine always reads.
  final String? _dmInboxRelayUrl;

  /// Extra relays the kind-10050 EVENT is published to so third-party senders
  /// can discover it. The tagged subset also belongs in Divine's active pool
  /// so the session reads every relay it advertises; discovery-only relays
  /// receive the event but are not advertised.
  ///
  /// Discovery publication is best-effort by construction. A relay here that
  /// refuses kind 10050 is
  /// logged once and otherwise ignored: it neither fails the publish nor
  /// blocks the idempotence flag, so it can never cause a republish loop.
  final List<String> _dmInboxDiscoveryRelays;

  /// Read-only indexers used to locate somebody else's kind-10050.
  /// Kept separate from [_dmInboxDiscoveryRelays], whose members are selected
  /// because they accept publication of Divine's own list. Read coverage and
  /// write acceptance are different relay capabilities (#7317).
  final List<String> _dmInboxLookupRelays;
  final List<String> _dmInboxTaggedRelays;

  /// Mints the durable, collision-proof identity for one send invocation.
  /// Group sends share it across the fan-out. Injected so tests can pin a
  /// deterministic value; production defaults to [_defaultSendBatchId]
  /// (256 bits of secure random).
  final String Function() _newSendBatchId;

  StreamSubscription<Event>? _giftWrapSubscription;
  Timer? _reconnectTimer;

  /// One-shot relay-status listener armed by a deferred history drain, so
  /// the drain resumes when a relay connects instead of waiting for the next
  /// inbox open. See [_resumeDrainWhenRelayConnects].
  StreamSubscription<Map<String, RelayConnectionStatus>>?
  _drainRelayReadySubscription;
  late bool _disposed = false;

  /// Guards against a double-subscribe race: [startListening] now awaits the
  /// user's own kind-10050 resolution before opening the live subscription,
  /// so a concurrent call could otherwise slip past the
  /// `_giftWrapSubscription == null` check during that await. See #4974.
  bool _subscribing = false;

  /// Monotonic session-identity token. Bumped at the start of [_resetState]
  /// (account switch / logout) so any `await` that began under the previous
  /// session can detect the switch on resume and bail instead of acting on a
  /// stale `_userPubkey` (e.g. opening the live subscription with the old
  /// user's filter, or completing an RC3 publish for the wrong session).
  /// See #4974.
  int _resetGeneration = 0;

  /// Memoized resolution of the CURRENT user's own kind-10050 DM inbox
  /// relays (#4974 RC2). Resolved at most once per session and shared by the
  /// live subscription, the history drain, and the RC3 existence check;
  /// `null` until first requested. Cleared in [_resetState] so it never leaks
  /// across an account switch. A `found`/`absent` outcome is cached so
  /// reconnects don't re-query; a `failed` (transient relay error) outcome is
  /// NOT cached — the memo is cleared once it resolves so the next caller
  /// re-queries, and RC3 never overwrites a real list on a transient failure.
  Future<({_OwnDmInboxState state, List<String>? relays})>? _ownInboxFuture;

  /// Debounced cross-device DM read-state marker publish (#4977). Reading a
  /// conversation advances its read cursor and schedules this; a burst of
  /// reads (e.g. paging through many threads) coalesces into ONE self-encrypted
  /// kind-30078 marker publish — bounding 1059 accumulation, metadata cadence,
  /// and the relay's 60-events/min/pubkey rate limit. Cancelled on reset/stop.
  Timer? _readMarkerDebounce;
  final Duration _readMarkerDebounceDelay;
  static const _defaultReadMarkerDebounceDelay = Duration(seconds: 3);

  /// Rumor tag key carrying the per-send token that [sendMessage] and
  /// [sendGroupMessage] both mint. Client-internal: injected only so two
  /// identical sends in the same Unix second produce distinct rumor ids.
  /// Divine's own receive path and other clients ignore unrecognised rumor
  /// tags, so it is inert on the wire.
  static const _sendBatchTagKey = 'batch';

  /// Default [_newSendBatchId]: a 256-bit secure-random, event-id-shaped hex
  /// token. Independent of rumor content, so two byte-identical same-second
  /// sends never share a token.
  static String _defaultSendBatchId() {
    const hexDigits = '0123456789abcdef';
    final random = Random.secure();
    return String.fromCharCodes(
      List<int>.generate(64, (_) => hexDigits.codeUnitAt(random.nextInt(16))),
    );
  }

  static final _sendBatchIdPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Durable queue handle for one recipient of a group send.
  ///
  /// A group send wraps ONE shared rumor for every recipient (#8188), so the
  /// rumor id no longer identifies a single queue row — but `outgoing_dms`
  /// tracks delivery PER RECIPIENT, and `enqueue` is `insertOrIgnore`, which
  /// would silently drop the siblings rather than throw.
  ///
  /// This needs no migration: nothing reads the column's format. Every
  /// consumer treats it as an opaque handle: `recoverFullSend` takes the rumor
  /// from `row.rumorEventJson` and the recipient from `row.recipientPubkey`,
  /// while `recoverSelfWrap` resolves the same row after partial delivery. A
  /// 64-hex rumor id can never contain `:`, so group handles and the plain 1:1
  /// ids (and any row written before this change) stay in disjoint keyspaces —
  /// the same property `ConversationState._batchKeyOf` already relies on.
  static String _groupQueueId(String rumorId, String recipientPubkey) =>
      '$rumorId:$recipientPubkey';

  /// Whether [value] is a well-formed batch token — the 64-char lowercase-hex
  /// shape [_defaultSendBatchId] mints. Ingest only stamps a self-wrap's
  /// `batch` tag onto the persisted row when it matches, keeping the batch-id
  /// keyspace disjoint from the legacy (content, createdAt) dedup tuple.
  static bool _isValidSendBatchId(String value) =>
      _sendBatchIdPattern.hasMatch(value);

  static const _readMarkerDTag = 'divine/dm-read/v1';
  static const _readMarkerPayloadVersion = 1;

  /// Read cursors parsed from a restored marker whose conversation row did not
  /// exist yet — a marker processed before its messages during the reinstall
  /// drain. Flushed once the drain completes (all conversations present), keyed
  /// by conversation id → max read timestamp. Cleared on reset. Loss on a
  /// kill mid-drain self-heals on the next read + marker publish.
  final Map<String, int> _pendingReadCursors = {};

  /// A single long-lived decrypt isolate, alive only for the duration of a
  /// history drain. Spawned in [_runHistoryDrain] for local-key signers and
  /// killed in its `finally`, so a large backfill pays one isolate spawn
  /// instead of one per chunk and the resident private key is reclaimed when
  /// the drain ends. `null` outside a drain or for remote/test signers. See
  /// PR #5405 review / #5391.
  DmDecryptWorker? _drainDecryptIsolate;

  /// A single long-lived, KEY-LESS verify isolate so the per-event id +
  /// Schnorr verification in `GiftWrapUtil.getRumorEvent` runs off the main
  /// isolate. Spawned on demand via [_ensureVerifyIsolate] — at drain start
  /// for remote signers and lazily on the first live-subscription / retry
  /// wrap — and kept until [stopListening] (the production disposal path:
  /// dmRepositoryProvider rebuilds dispose the old repository through it)
  /// or account switch ([_resetState]).
  ///
  /// Originally drain-scoped (#5424), which left every wrap arriving
  /// OUTSIDE a drain verifying inline: two pure-Dart Schnorr verifies
  /// (~20ms of BigInt math) per wrap on the main isolate — 47% of
  /// main-isolate CPU in on-device profiling of a live DM burst. The worker
  /// holds no key (unlike [_drainDecryptIsolate], whose teardown reclaims
  /// the resident private key), so keeping it alive costs one idle isolate.
  /// `null` until first needed or when the spawn failed.
  DmVerifyWorker? _verifyIsolate;

  /// In-flight [_ensureVerifyIsolate] spawn, so concurrent wraps share one
  /// spawn instead of racing several.
  Future<DmVerifyWorker?>? _verifyIsolateSpawn;

  /// Set when a verify-isolate spawn failed; suppresses per-wrap respawn
  /// attempts (and their log spam) until the next account switch. Wraps
  /// verify inline in that state, unchanged.
  bool _verifyIsolateSpawnFailed = false;

  /// Returns the shared key-less verify isolate, spawning it on first use.
  ///
  /// Returns `null` (callers verify inline) when the spawn fails or when the
  /// user switched while spawning; a worker spawned for a stale user is
  /// closed, never installed.
  Future<DmVerifyWorker?> _ensureVerifyIsolate() {
    final existing = _verifyIsolate;
    if (existing != null) return Future.value(existing);
    if (_verifyIsolateSpawnFailed) return Future<DmVerifyWorker?>.value();
    return _verifyIsolateSpawn ??= _spawnVerifyIsolate();
  }

  Future<DmVerifyWorker?> _spawnVerifyIsolate() async {
    final pubkey = _userPubkey;
    // Session token guard: [stopListening] closes the worker but leaves
    // _userPubkey/_disposed untouched, so a spawn in flight across a stop
    // would re-install a worker nothing ever closes. The generation bump in
    // stopListening/_resetState invalidates such a spawn; the late worker is
    // closed, never installed.
    final generation = _resetGeneration;
    try {
      final spawned = await _verifyIsolateSpawner();
      if (_disposed ||
          _userPubkey != pubkey ||
          _resetGeneration != generation) {
        spawned.close();
        return null;
      }
      _verifyIsolate = spawned;
      return spawned;
    } on Object catch (e, stackTrace) {
      _verifyIsolateSpawnFailed = true;
      Log.error(
        'DM verify isolate spawn failed; validating on main isolate: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      _verifyIsolateSpawn = null;
    }
  }

  /// Serializes event processing so concurrent subscription events
  /// never race into the dedup/insert path.
  Future<void>? _eventLock;

  /// Preserves subscription ordering while gift-wrap decryption runs outside
  /// [_eventLock]. A suspended remote signer must not block account cleanup;
  /// generation checks prevent its late result from entering persistence.
  Future<void>? _giftWrapProcessingLock;

  /// Tracks the first post-auth cleanup pass so conversation queries can avoid
  /// emitting stale denormalized previews before repairs land.
  Future<void>? _postAuthMaintenance;

  /// The owner [_postAuthMaintenance] was started for, so a run is not
  /// repeated for the same identity and is not reused across an account
  /// switch that left the credentials untouched.
  String? _maintenanceOwner;

  /// The in-flight one-time history drain, shared by concurrent callers so
  /// repeated [backfillHistoryIfNeeded] calls (e.g. every inbox open) never
  /// launch overlapping drains. Cleared when the drain settles.
  Future<void>? _historyDrain;

  /// The in-flight failed-decrypt retry pass, shared by concurrent callers so
  /// repeated [retryPendingDecryptions] calls (every inbox open, plus
  /// load-more / blocklist re-dispatches) never run overlapping passes that
  /// would double the Keycast RPC decrypts or race the per-wrap attempt
  /// counter. Cleared when the pass settles. See #5202.
  Future<void>? _pendingDecryptRetry;

  /// Count of in-flight recovery operations doing real work — history-drain
  /// paging and failed-decrypt replay passes. Drives [isRecoveringHistory] /
  /// [historyRecoveryStream] so the inbox can show a restore progress
  /// indicator while a reinstall backfill runs (it can take a while on
  /// remote-signer accounts that decrypt each wrap over RPC). See #5202.
  int _activeRecoveryOps = 0;
  final StreamController<bool> _recoveryStateController =
      StreamController<bool>.broadcast();

  /// Fires whenever a send, deletion, or recovery leaves durable outgoing work
  /// behind — a soft-unconfirmed publish, a hard failure, a partial delivery
  /// whose self-wrap is still missing, or a pending message deletion. The retry
  /// service listens and bootstraps its in-session follow-up sweep. Without
  /// this, a row created while the app stays foregrounded on stable
  /// connectivity sat pending (a delivered-looking bubble) until the next
  /// background/
  /// foreground flip or connectivity change.
  ///
  /// Some emissions fire from inside a database transaction, so listeners
  /// MUST NOT touch the database synchronously — schedule work (e.g. arm a
  /// timer) instead.
  final StreamController<void> _retryableWorkController =
      StreamController<void>.broadcast();

  /// See [_retryableWorkController]. App-scoped like [historyRecoveryStream];
  /// never closed.
  Stream<void> get retryableOutgoingWork => _retryableWorkController.stream;

  void _notifyRetryableWork() {
    if (!_retryableWorkController.isClosed) {
      _retryableWorkController.add(null);
    }
  }

  /// Per-row recovery attempts currently in flight, keyed by primitive
  /// (`full:<id>` / `self:<id>`). A manual Resend and a sweep pass can race
  /// [recoverFullSend] on the same queue row: the second entrant would only
  /// duplicate signer round-trips and wire copies (receiver-side rumor-id
  /// dedup absorbs them) and then trip the cancel interlock in the winner's
  /// shadow. The second entrant instead JOINS the in-flight attempt — it
  /// awaits the stored future and returns that attempt's real outcome. The
  /// previous shape (an instant synthetic retryable-pending failure) made a
  /// manual Resend racing the 30s sweep a silent no-op: nothing was
  /// published, no feedback surfaced, and the user read it as "resend does
  /// nothing" (#6046).
  final Map<String, Future<NIP17SendResult>> _recoveriesInFlight =
      <String, Future<NIP17SendResult>>{};

  /// Message retractions have their own result type, but need the same
  /// per-rumor join: a tap on Try again can race the background sweep.
  final Map<String, Future<DmMessageDeletionOutcome>>
  _messageDeletionRecoveriesInFlight =
      <String, Future<DmMessageDeletionOutcome>>{};

  /// Runs [attempt] under the per-row in-flight key [key], or joins an
  /// attempt already running under the same key. Exceptions propagate to
  /// every joiner (both callers handle the documented [StateError] /
  /// [ArgumentError] contract).
  ///
  /// The queue row's finalization belongs to whichever caller RAN the
  /// attempt. A joiner receives an outcome the owner has already recorded
  /// against the row — [_recoverFullSendLocked] finalizes every branch
  /// inside its body — so a joiner that finalized again would charge one
  /// underlying attempt twice (#8619). [sendGroupMessage] learns which side
  /// it was on from a flag the closure sets when it actually runs.
  Future<NIP17SendResult> _joinOrStartRecovery(
    String key,
    Future<NIP17SendResult> Function() attempt,
  ) {
    final existing = _recoveriesInFlight[key];
    if (existing != null) return existing;
    final future = attempt();
    _recoveriesInFlight[key] = future;
    return future.whenComplete(() => _recoveriesInFlight.remove(key));
  }

  /// Broadcasts the user's pubkey whenever credentials are attached.
  ///
  /// Consumers that classify rows by identity (e.g. the conversation-list
  /// "Message requests" split) must re-run when this fires, otherwise a cold
  /// start can classify with a signed-out empty pubkey — which fails to filter
  /// self out of a conversation's participants, making every 1:1 look like a
  /// group and land in Message Requests. See #5374.
  final StreamController<String> _userPubkeyController =
      StreamController<String>.broadcast();

  /// User-scoped subscription ID to prevent collision when the provider
  /// rebuilds during auth transitions (old unsubscribe won't kill new sub).
  String _subscriptionId = 'dm_inbox';

  /// The current identity's pubkey for DAO scoping, or `null` if signed out or
  /// tearing down.
  ///
  /// Passes through to `_ownedOrLegacy` in DAO queries, where `null` means
  /// "return all rows" (legacy/unscoped mode).
  String? get _ownerPubkey => _userPubkey.isEmpty ? null : _userPubkey;

  /// Whether the repository has been initialized with auth credentials.
  ///
  /// Write operations (send) and the relay subscription require this. It is
  /// strictly stronger than "an owner is known", because it also needs a
  /// signer — the owner-scoped reads and writes ([watchMessages],
  /// [getConversation], [markConversationAsRead], …) gate on
  /// [_ownerPubkey] instead, so they still serve a signer-less identity.
  bool get isInitialized => _signer != null && _userPubkey.isNotEmpty;

  /// Set auth credentials on the repository.
  ///
  /// Called by `dmRepositoryProvider` when the current identity's signer and
  /// client become ready. Owner-scoped local operations only need the identity
  /// supplied at construction; signing, publishing, and relay work need these
  /// credentials.
  ///
  /// This wires credentials only — the gift-wrap subscription is opened
  /// separately by the provider via [startListening] right after this
  /// returns, so DM ingestion runs for the whole authenticated session.
  /// Cold-start cost stays bounded thanks to the count-based windowing
  /// (`since: (newestWireSyncedAt ?? newestSyncedAt) - 2d`) and the isolate
  /// decryption worker.
  /// See docs/plans/2026-04-05-dm-scaling-fix-design.md and #2931.
  ///
  /// Safe to call multiple times — subsequent calls for the same user are
  /// no-ops. If called with a different user, resets and re-initializes.
  void setCredentials({
    required String userPubkey,
    required NostrSigner signer,
    required NIP17MessageService messageService,
    RumorDecryptor? rumorDecryptor,
    Nip04Decryptor? nip04Decryptor,
  }) {
    if (isInitialized && _userPubkey == userPubkey) return;

    // If switching users, stop the old subscription first.
    if (isInitialized && _userPubkey != userPubkey) {
      Log.info(
        'DmRepository: switching user from ${pubkeyForLogs(_userPubkey)} to '
        '${pubkeyForLogs(userPubkey)}',
        category: LogCategory.system,
      );
      _resetState();
    }

    _userPubkey = userPubkey;
    _signer = signer;
    // A new signer may be a keycast that supports (or lacks) the batch verb;
    // re-probe it. See #5471.
    _batchUnwrapUnsupported = false;
    _messageService = messageService;
    if (rumorDecryptor != null) _rumorDecryptor = rumorDecryptor;
    if (nip04Decryptor != null) _nip04Decryptor = nip04Decryptor;

    // Notify identity-scoped consumers (e.g. the conversation-list classifier)
    // so a cold-start subscription that first ran with the empty pre-auth
    // pubkey re-classifies with the real identity. See #5374.
    if (!_userPubkeyController.isClosed) {
      _userPubkeyController.add(userPubkey);
    }

    unawaited(_ensurePostAuthMaintenance());
  }

  /// Reset internal state so the repository can be re-initialized for a
  /// different user. Stops the relay subscription and clears credentials.
  ///
  /// Synchronous so [setCredentials] can call it inline. Subscription cancel
  /// is fire-and-forget — the old subscription filtered by the old pubkey
  /// so any late arrivals are harmless (dedup rejects them).
  void _resetState() {
    // Bump the session-identity token first so any in-flight `await` started
    // under the outgoing session detects the switch on resume and bails
    // instead of acting on the new `_userPubkey`. Release `_subscribing` too,
    // so the incoming user's startListening() is not blocked at its entry
    // guard by the outgoing user's still-resolving subscribe. See #4974.
    _resetGeneration++;
    _subscribing = false;
    _disposed = true;
    _eventLock = null;
    unawaited(_drainRelayReadySubscription?.cancel());
    _drainRelayReadySubscription = null;
    // Drop the in-flight history drain and decrypt-retry pass so the next
    // user can start fresh; the running loops bail on the _userPubkey change.
    _historyDrain = null;
    _pendingDecryptRetry = null;
    // Kill any drain-scoped decrypt isolate immediately so the outgoing user's
    // key is not left resident in a worker while the next user signs in. The
    // bailing drain's `finally` is idempotent if it also runs.
    _drainDecryptIsolate?.close();
    _drainDecryptIsolate = null;
    // Likewise kill the shared verify isolate (key-less, but still a live
    // worker) so the next user starts with a fresh one. An in-flight spawn
    // detects the pubkey change on resume and closes its worker itself.
    _verifyIsolate?.close();
    _verifyIsolate = null;
    _verifyIsolateSpawnFailed = false;
    // Abandon the recovery signal for the outgoing user. The bailing loops'
    // _endRecovery() then no-ops (guarded on the zeroed counter).
    if (_activeRecoveryOps > 0) {
      _activeRecoveryOps = 0;
      if (!_recoveryStateController.isClosed) {
        _recoveryStateController.add(false);
      }
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Drop a pending read-marker publish and any un-flushed read cursors so
    // they never leak across an account switch. #4977.
    _readMarkerDebounce?.cancel();
    _readMarkerDebounce = null;
    _pendingReadCursors.clear();
    unawaited(_giftWrapSubscription?.cancel());
    _giftWrapSubscription = null;
    // Drop the outgoing user's resolved own-inbox relays so the next user
    // re-resolves their own kind-10050 (never reuses a stale set). #4974.
    _ownInboxFuture = null;
    final subId = _subscriptionId;
    try {
      unawaited(_nostrClient.unsubscribe(subId));
    } on Object {
      // Ignore if subscription doesn't exist
    }
    _postAuthMaintenance = null;
    _maintenanceOwner = null;
    _userPubkey = '';
    _signer = null;
    _batchUnwrapUnsupported = false;
    _messageService = null;
    _disposed = false;
    _subscriptionId = 'dm_inbox';
  }

  /// Delay before attempting to re-subscribe after stream closure.
  static const _reconnectDelay = Duration(seconds: 2);

  /// Schedule a single reconnect attempt, cancelling any pending one.
  ///
  /// Using a [Timer] (not `Future.delayed`) keeps the reconnect cancellable
  /// from [stopListening] / [_resetState], preventing leaked async work from
  /// firing after the repository has been torn down (e.g. in tests or user
  /// switch flows).
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, startListening);
  }

  // -------------------------------------------------------------------------
  // Subscription lifecycle
  // -------------------------------------------------------------------------

  /// Start listening for incoming gift-wrapped DMs.
  ///
  /// Subscribes to kind 1059 events p-tagged to the current user.
  /// Each received event is decrypted and persisted automatically.
  ///
  /// Uses count-based windowing to avoid replaying the full event history:
  /// - First open (no messages in DB): fetches the most recent 50 events.
  /// - Subsequent opens: fetches events since the newest synced timestamp
  ///   minus a 2-day overlap (absorbs NIP-17 randomized timestamps).
  ///
  /// If the relay stream closes unexpectedly (e.g. relay disconnect,
  /// NostrClient rebuild), automatically re-subscribes after a brief delay.
  Future<void> startListening() async {
    // Reset _disposed so that the subscription can restart after a prior
    // stopListening() call (e.g. tab switch away and back). The flag is
    // only meant to suppress the onDone reconnect during intentional stop;
    // a new explicit startListening() should always be honored.
    _disposed = false;
    // A pending reconnect is made stale by this call — cancel it so the
    // timer doesn't fire later and try to re-subscribe on top of the
    // fresh subscription we're about to establish.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_giftWrapSubscription != null || _subscribing || !isInitialized) return;

    // Claim the subscribe slot BEFORE the first await. `_subscribing` is what
    // stops a concurrent startListening() from opening a duplicate
    // subscription, so every suspension point below must be inside it — the
    // re-entrancy check above is only sound while the code between it and this
    // assignment stays synchronous. The `finally` below always releases it.
    _subscribing = true;
    try {
      // Heal boundaries a pre-guard build may have poisoned with an
      // unauthenticated rumor timestamp before deriving `since:` from them —
      // otherwise an already-affected install stays silently blackholed.
      await _syncState?.repairPoisonedBoundaries(_userPubkey);

      // Count-based windowing: first open fetches a bounded backlog
      // (limit:50), later opens fetch only recent events via a `since:`
      // filter. The 2-day overlap absorbs NIP-17 randomized created_at
      // jitter (gift wraps tweak their outer created_at within a ~2 day
      // window). See docs/plans/2026-04-05-dm-scaling-fix-design.md.
      //
      // The boundary must come from the clock the relay filters in. A relay
      // evaluates `since:` against the stamp on the event it stored — the
      // outer kind-1059 wrap, never the inner rumor — and NIP-17 requires
      // that outer stamp to be backdated by a random 0..2 days. Deriving the
      // boundary from the rumor clock therefore consumes part of the 2-day
      // overlap before the window opens, and a wrap whose backdate exceeds
      // the remainder is dropped by the relay. Nothing asks for it again:
      // `newestWireSyncedAt` only advances, so `since:` only rises, and the
      // history drain that would otherwise repair the gap latches complete.
      // The measured erosion equals the newest wrap's own backdate, which is
      // uniform on [0, 2d) — half the intended margin, on average. See #8209.
      //
      // Falling back to the rumor boundary keeps the previous behavior for an
      // install that has not processed an event since upgrading. A delayed
      // retry may re-wrap an old rumor with a recent wire stamp, so switching
      // to the wire boundary can narrow that fallback window. It still keeps
      // the full required overlap in the relay's clock: a compliant wrap's
      // wire stamp is at most its publication time, and every later compliant
      // wrap is stamped no earlier than its publication time minus two days.
      final newest = _syncState?.newestSyncedAt(_userPubkey);
      final newestWire = _syncState?.newestWireSyncedAt(_userPubkey);
      final isFirstOpen = newest == null;
      final filter = nostr_filter.Filter(
        kinds: [
          EventKind.giftWrap,
          EventKind.directMessage,
          EventKind.eventDeletion,
        ],
        p: [_userPubkey],
        limit: isFirstOpen ? 50 : null,
        since: newest == null ? null : (newestWire ?? newest) - 2 * 86400,
      );

      Log.info(
        'Starting DM subscription for pubkey ${pubkeyForLogs(_userPubkey)} '
        '(connected relays: '
        '${_nostrClient.connectedRelayCount}/'
        '${_nostrClient.configuredRelayCount}, '
        'filter: ${filter.toJson()})',
        category: LogCategory.system,
      );

      // Resolve the user's OWN kind-10050 inbox relays and dial them as
      // `tempRelays`, so gift wraps a NIP-17 sender delivered outside divine's
      // default pool are read. `tempRelays` ADDS those connections; the pool
      // keeps its own subscription. A `null` result (no kind-10050 / resolve
      // failure) is the plain default-pool read. Memoized per session, so the
      // resolve (bounded by the queryEvents ~5s timeout) only delays the FIRST
      // open. See #4974.
      //
      // Deliberately NOT `targetRelays`: that parameter is a filter over the
      // pool, not an addition — `RelayPool.subscribe` skips every pooled relay
      // the list does not name. Passing the own-inbox list there subtracted
      // divine's own relay and the four `safeFallbackRelays` that #2931 added
      // precisely so DMs written to other relays stay visible, which is the
      // opposite of the intent above. See #7320.
      //
      // Capture the session token before the await: `filter` was built with
      // the current `_userPubkey`, so if an account switch lands during the
      // resolve we must NOT open a subscription targeting the previous user.
      final gen = _resetGeneration;
      final ownInbox = await _ownInboxRelays();
      // A teardown (stopListening), account switch (generation bumped), or a
      // competing call may have run during the await — bail rather than open
      // a stale or duplicate subscription.
      if (_disposed ||
          _resetGeneration != gen ||
          !isInitialized ||
          _giftWrapSubscription != null) {
        return;
      }

      _subscriptionId = dmInboxSubscriptionId(_userPubkey);
      final stream = _nostrClient.subscribe(
        [filter],
        subscriptionId: _subscriptionId,
        tempRelays: ownInbox,
      );

      _giftWrapSubscription = stream.listen(
        _handleIncomingEvent,
        onError: (Object error) {
          Log.error(
            'DM subscription error: $error',
            category: LogCategory.system,
          );
          // Release the failed subscription so its onDone cannot fire later
          // and schedule a reconnect. stopListening() now sets _disposed,
          // which suppresses that path as well (#7318); this cancel remains
          // the local cleanup for a stream that has already failed.
          unawaited(_giftWrapSubscription?.cancel());
          _giftWrapSubscription = null;
          if (!_disposed) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          // Stream closed (relay disconnect, NostrClient rebuild, etc.)
          // Clear the subscription so startListening() can re-subscribe.
          _giftWrapSubscription = null;
          if (!_disposed) {
            Log.info(
              'DM subscription stream closed, re-subscribing '
              'in ${_reconnectDelay.inSeconds}s',
              category: LogCategory.system,
            );
            _scheduleReconnect();
          }
        },
      );
    } finally {
      _subscribing = false;
    }

    // No poll timer: the live WebSocket subscription is the sole event
    // source for the entire authenticated session. Poller was removed
    // because it re-fetched duplicate events every 10s forever on the UI
    // isolate. See docs/plans/2026-04-05-dm-scaling-fix-design.md and #2931.
  }

  /// Resolves and memoizes the CURRENT user's own kind-10050 DM inbox
  /// resolution for the session (#4974 RC2).
  ///
  /// Shared by the live subscription and history drain.
  /// The RC3 existence check deliberately performs its own authoritative read.
  /// A `found`/`absent` outcome is cached; a `failed` (transient) outcome is NOT
  /// — the memo clears itself once it resolves `failed` so the next caller
  /// re-queries instead of degrading the whole session to the default pool.
  /// [_resetState] clears the memo on account switch.
  Future<({_OwnDmInboxState state, List<String>? relays})>
  _resolveOwnDmInbox() {
    final cached = _ownInboxFuture;
    if (cached != null) return cached;
    final future = _queryOwnDmInbox(
      _userPubkey,
      // Deliberately NOT authoritative. Every consumer of this memo — the live
      // gift-wrap subscription and the history drain —
      // falls back to the default pool on `absent` and `failed` alike, and
      // `startListening` awaits it before opening the subscription. Making it
      // strict would put a full timeout in front of DM delivery on every login
      // and every reconnect to protect a write that happens at most once per
      // device. The publish path reads authoritatively on its own instead.
      // See #8212.
      requireAuthoritative: false,
      source: _DmRelayListSource.selfAuthored,
    );
    _ownInboxFuture = future;
    unawaited(
      future.then((res) {
        // Don't strand the session on a transient failure: drop the memo so
        // a later reconnect / login re-queries. Guard with `identical` so a
        // concurrent _resetState (which nulls or replaces the memo) wins.
        if (res.state == _OwnDmInboxState.failed &&
            identical(_ownInboxFuture, future)) {
          _ownInboxFuture = null;
        }
      }),
    );
    return future;
  }

  /// The user's own kind-10050 relays when `found`, else `null` on
  /// `absent`/`failed`.
  ///
  /// Every reader treats a non-null result as relays to reach IN ADDITION to
  /// the pool — `tempRelays` on the live subscription and on each drain page.
  /// Read markers deliberately publish through the normal pool so they retain
  /// the pool's write redundancy; the publish API can also open temporary
  /// connections for explicit targets, unlike subscription/query filtering.
  Future<List<String>?> _ownInboxRelays() async {
    final res = await _resolveOwnDmInbox();
    return res.state == _OwnDmInboxState.found ? res.relays : null;
  }

  /// The user's own kind-10050 inbox relays for the history drain, together
  /// with whether the answer can be trusted.
  ///
  /// [_ownInboxRelays] is the wrong reader here. It collapses "the user
  /// advertises nothing" and "we could not read what the user advertises" into
  /// the same `null`, which is free for a caller that merely routes to the
  /// default pool and wrong for one that latches a permanent flag off the
  /// result.
  ///
  /// The two are easy to confuse because the fast read cannot tell them apart:
  /// a relay that stays connected and never answers is skipped after the
  /// settle window and the query still reports success, so a silent relay
  /// arrives as an ordinary empty list. `absent` then swallows it — and unlike
  /// `failed`, `absent` is memoized for the rest of the session.
  ///
  /// That matters because the advertised inbox is usually NOT in the default
  /// pool: the relays published in every kind-10050 join the pool only when
  /// relay discovery came back empty. So a drain that guesses `absent` pages
  /// the one relay set least likely to hold the missing history, and then
  /// records that history as fully recovered.
  ///
  /// The live subscription cannot afford a conclusive read — it is awaited on
  /// every login and reconnect (#8212). The drain can: it is unawaited
  /// background work that already runs fully-settled page queries, and it pays
  /// this at most once per run, and not at all when the fast read already
  /// returned a list.
  Future<({List<String>? relays, bool conclusive})> _drainOwnInboxRelays(
    String pubkey,
    int generation,
  ) async {
    final memoFuture = _resolveOwnDmInbox();
    final memo = await memoFuture;
    if (memo.state == _OwnDmInboxState.found) {
      return (relays: memo.relays, conclusive: true);
    }
    if (_ingestSessionEnded(pubkey, generation)) {
      return (relays: null, conclusive: false);
    }
    final strict = await _queryOwnDmInbox(
      pubkey,
      requireAuthoritative: true,
      source: _DmRelayListSource.selfAuthored,
    );
    if (_ingestSessionEnded(pubkey, generation)) {
      return (relays: null, conclusive: false);
    }
    // Repair the session memo with the better answer, so the live
    // subscription's next re-subscribe stops routing by a silence we have
    // since resolved. Guarded like the `failed` self-clear so a concurrent
    // reset wins.
    if (_ownInboxFuture == null || identical(_ownInboxFuture, memoFuture)) {
      _ownInboxFuture = strict.state == _OwnDmInboxState.failed
          ? null
          : Future.value(strict);
    }
    return switch (strict.state) {
      _OwnDmInboxState.found => (relays: strict.relays, conclusive: true),
      _OwnDmInboxState.absent => (relays: null, conclusive: true),
      _OwnDmInboxState.failed => (relays: null, conclusive: false),
    };
  }

  /// Where the sender's own gift-wrap copy of an outgoing DM should land: the
  /// configured pool UNION the user's advertised kind-10050 DM inbox.
  ///
  /// `null` when no inbox is advertised (`absent`/`failed`), which keeps the
  /// historic plain-pool publish for those accounts.
  ///
  /// The union is the whole point. `NostrClient.publishEvent` forwards one set
  /// as BOTH `targetRelays` and `tempRelays`, and `targetRelays` FILTERS the
  /// pool (`RelayPool._sendCollect`) rather than adding to it — so passing the
  /// inbox alone would have swapped the pool's write redundancy for inbox
  /// reach instead of gaining both. Naming the pool's own URLs alongside the
  /// inbox keeps every pool relay past that filter, while the unpooled inbox
  /// relays get a temporary connection. #7328.
  ///
  /// Before this, the self-copy went to the pool only. Divine advertises
  /// `nos.lol` and `relay.primal.net` in every account's kind-10050 (the app
  /// layer's `IndexerRelayConfig.dmInboxTaggedRelays`, passed in as
  /// [_dmInboxTaggedRelays]), and neither joins the pool unless NIP-65
  /// discovery came back empty — so the sender's own replies were absent from
  /// two of the three relays their own inbox list points at.
  Future<List<String>?> _selfWrapTargetRelays() async {
    final ownInbox = await _ownInboxRelays();
    if (ownInbox == null || ownInbox.isEmpty) return null;
    return <String>{..._nostrClient.configuredRelays, ...ownInbox}.toList();
  }

  /// Fetches a single older page of DM events (gift wraps, NIP-04,
  /// deletions) addressed to [pubkey] from the relay older than [until]
  /// (inclusive), capped to [limit]. Each event flows through
  /// [_handleIncomingEvent] so dedup, transaction integrity, and
  /// sync-boundary tracking apply automatically. Returns the raw events so
  /// the caller can advance its own pagination cursor by their outer
  /// `created_at`, or `null` if the user switched / the repository was torn
  /// down mid-fetch (so the caller stops paging for the stale user).
  ///
  /// `authoritative` is false when nothing answered this page — no relay took
  /// the REQ, a relay refused it with `CLOSED`, the client was disposed, or
  /// only some relays answered. An empty page is proof of exhaustion only when
  /// it is authoritative; see the guard in [_runHistoryDrain]. See #8209.
  Future<({List<Event> events, bool authoritative})?> _fetchHistoryPage({
    required int until,
    required int limit,
    required String subscriptionId,
    required String pubkey,
    required int generation,
    List<String>? tempRelays,
  }) async {
    final filter = nostr_filter.Filter(
      kinds: [
        EventKind.giftWrap,
        EventKind.directMessage,
        EventKind.eventDeletion,
      ],
      p: [pubkey],
      until: until,
      limit: limit,
    );

    // Target the user's OWN kind-10050 inbox relays (in addition to the
    // default pool) so the #4953/#4973 history drain reads gift wraps a
    // sender delivered outside the default pool. `null` keeps the prior
    // default-pool-only behavior. See #4974.
    //
    // queryEventsDetailed, not queryEvents: the latter discards `timedOut` and
    // `noRelays`, so a page nothing answered arrives as an ordinary empty one
    // and the drain reads it as exhaustion. `requireAllRelaysSettled` is what
    // makes a relay's `CLOSED` refusal and a partial fan-out surface as
    // `timedOut` rather than completing on whichever relays did answer. #8209.
    final result = await _nostrClient.queryEventsDetailed(
      [filter],
      subscriptionId: subscriptionId,
      useCache: false,
      tempRelays: tempRelays,
      requireAllRelaysSettled: true,
    );
    final events = result.events;
    final authoritative = !result.noRelays && !result.timedOut;
    if (_ingestSessionEnded(pubkey, generation)) return null;

    // Pass 1 (off the _eventLock): batch-decrypt this page's gift wraps in one
    // isolate hop per chunk for local-key signers, instead of one isolate
    // spawn per wrap. Remote signers and undecryptable wraps stay out of the
    // map and fall through to the per-event path in pass 2. See #5391.
    final preDecrypted = await _batchDecryptGiftWraps(events);
    // The batch decrypt above can span many events with no inner guard, so
    // re-check before persisting that the user did not switch / tear down.
    if (_ingestSessionEnded(pubkey, generation)) return null;

    // Pass 2 (original page order): persist. Pre-decrypted gift wraps skip the
    // per-event decrypt; everything else (NIP-04, deletions, remote-signer or
    // failed wraps) routes through the unchanged per-event handler.
    for (var i = 0; i < events.length; i++) {
      if (_ingestSessionEnded(pubkey, generation)) return null;
      final event = events[i];
      final rumor = preDecrypted[event.id];
      if (rumor != null) {
        await _withEventLock(
          () => _persistDecryptedGiftWrap(event, rumor, ownerPubkey: pubkey),
        );
      } else {
        await _handleIncomingEvent(event);
      }
      await _maybeYieldDuringDrain(i);
    }
    return (events: events, authoritative: authoritative);
  }

  /// Recovers the user's OWN outgoing NIP-04 (kind-4) messages after a wipe.
  ///
  /// The live subscription and history drain both filter `p:[self]`, which
  /// matches incoming NIP-04 (`author=peer, p=self`) and the user's NIP-17
  /// self-wraps, but never the user's outgoing NIP-04 (`author=self,
  /// p=recipient`, per NIP-04). Without this pass a legacy conversation the
  /// user only ever replied to over NIP-04 cannot re-prove `currentUserHasSent`
  /// and is stranded under "Message requests". Pages `authors:[self]` kind-4
  /// newest→oldest and routes each through [_handleIncomingEvent], which
  /// already sets `currentUserHasSent` for self-authored messages. Bounded by
  /// [DmHistoryDrainConfig.maxPages].
  ///
  /// Returns `true` when the pass completed against a relay that actually
  /// answered — genuine exhaustion or the page budget — and `false` when it
  /// could not run: nothing answered the page, the repository was torn down /
  /// the user switched, or a relay error. A `false` result MUST NOT mark the
  /// drain complete, mirroring the gift-wrap drain's authoritative-page guard
  /// so a momentary outage in this window doesn't silently skip recovery *and*
  /// permanently strand the user's outgoing NIP-04 history. See #5304, #8209.
  Future<bool> _recoverOutgoingNip04(String pubkey, int generation) async {
    try {
      var cursor = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var sawUnansweredPage = false;
      for (var page = 0; page < DmHistoryDrainConfig.maxPages; page++) {
        if (_ingestSessionEnded(pubkey, generation)) return false;
        final result = await _nostrClient.queryEventsDetailed(
          [
            nostr_filter.Filter(
              authors: [pubkey],
              kinds: [EventKind.directMessage],
              until: cursor,
              limit: DmHistoryDrainConfig.pageSize,
            ),
          ],
          subscriptionId: dmNip04DrainSubscriptionId(pubkey, page),
          useCache: false,
          requireAllRelaysSettled: true,
        );
        final events = result.events;
        if (_ingestSessionEnded(pubkey, generation)) return false;
        final authoritative = !result.noRelays && !result.timedOut;
        if (events.isEmpty) {
          // An empty page is genuine exhaustion only if a relay actually
          // ANSWERED it. Nothing answering — no relay took the REQ, a relay
          // refused it with `CLOSED`, or only some answered — arrives as an
          // ordinary empty list, and concluding "nothing to recover" would let
          // the caller mark the drain complete and permanently strand the
          // user's outgoing NIP-04 (the #5202 failure mode, mirrored here).
          return authoritative && !sawUnansweredPage;
        }
        if (!authoritative) sawUnansweredPage = true;
        for (var i = 0; i < events.length; i++) {
          if (_ingestSessionEnded(pubkey, generation)) return false;
          await _handleIncomingEvent(events[i]);
          await _maybeYieldDuringDrain(i);
        }
        // Step strictly below the oldest event seen so the loop terminates;
        // `until` is inclusive, so a re-requested boundary is absorbed by the
        // hasGiftWrap dedup in [_handleNip04Event].
        final minCreatedAt = events
            .map((event) => event.createdAt)
            .reduce((a, b) => a < b ? a : b);
        final next = minCreatedAt < cursor ? minCreatedAt : cursor - 1;
        if (next <= 0) return !sawUnansweredPage;
        cursor = next;
      }
      // Page budget exhausted. NIP-04 is legacy/low-volume and the gift-wrap
      // drain already reached the end, so treat this as done rather than
      // looping a re-drain for a pathologically long kind-4 history.
      return !sawUnansweredPage;
    } on Object catch (e) {
      // Relay/IO failures are expected on flaky networks. Returning false
      // defers drain completion so recovery retries on the next inbox open
      // rather than silently skipping it and marking complete. See #5304.
      Log.warning(
        'Outgoing NIP-04 recovery did not finish for ${pubkeyForLogs(pubkey)}: '
        '$e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Whether a DM history recovery (the backfill drain or a failed-decrypt
  /// replay) is actively doing work right now. The inbox surfaces this as a
  /// restore progress indicator so the user knows chats are still being
  /// recovered after a reinstall. See #5202.
  bool get isRecoveringHistory => _activeRecoveryOps > 0;

  /// Broadcasts changes to [isRecoveringHistory]. Does not replay the current
  /// value, so callers should seed with [isRecoveringHistory] (e.g.
  /// `historyRecoveryStream.startWith(repo.isRecoveringHistory)`). See #5202.
  Stream<bool> get historyRecoveryStream => _recoveryStateController.stream;

  /// Whether history recovery has completed at least once for the current user.
  ///
  /// Until this is `true` — notably the post-reinstall window while the drain
  /// pages back through history — the inbox MUST NOT segregate conversations
  /// into message requests. After a wipe a previously-accepted chat
  /// re-materializes from the peer's message before the user's own
  /// (self-wrapped) message is re-ingested, so `currentUserHasSent` is still
  /// `false` and the conversation would transiently classify as a request even
  /// though the user had replied. Gating the request split on this flag closes
  /// that window; it flips `true` (and re-fires the recovery stream via
  /// [_endRecovery]) when the drain reaches relay exhaustion. Falls back to
  /// `true` when uninitialized so the inbox never hides the split forever.
  /// See #5304.
  ///
  /// It stays `true` through a later forced recovery pass — a drain-version
  /// bump, or the own-inbox coverage re-arm — on an install that already
  /// completed a drain once. That install's own replies are already in its
  /// database, so the misclassification this guards against cannot happen,
  /// while a closed gate would hide every request the user could see
  /// yesterday and raise the "haven't finished restoring" banner each time
  /// the pass deferred. Those passes recover history the user never saw;
  /// they must not read as history the user lost. See #8550.
  bool get hasCompletedHistoryRecoveryBefore {
    final syncState = _syncState;
    if (syncState == null || _userPubkey.isEmpty) return true;
    return syncState.historyDrainCompletedBefore(_userPubkey);
  }

  /// Whether history recovery has run, completed, or is currently running for
  /// the current user.
  ///
  /// A fresh install starts with `historyDrainComplete == false`, but that does
  /// not mean every brand-new empty conversation should be qualified as
  /// incomplete before the user has ever opened Messages and armed the drain.
  /// The drain stamps the current logic version before it does relay work, so
  /// this distinguishes "not attempted yet" from "attempted but still not
  /// complete" without inventing per-conversation sync state.
  bool get hasAttemptedHistoryRecovery {
    final syncState = _syncState;
    if (syncState == null || _userPubkey.isEmpty) return true;
    return isRecoveringHistory ||
        syncState.historyDrainComplete(_userPubkey) ||
        syncState.drainVersion(_userPubkey) >= DmSyncState.currentDrainVersion;
  }

  void _beginRecovery() {
    _activeRecoveryOps++;
    if (_activeRecoveryOps == 1 && !_recoveryStateController.isClosed) {
      _recoveryStateController.add(true);
    }
  }

  void _endRecovery() {
    if (_activeRecoveryOps == 0) return;
    _activeRecoveryOps--;
    if (_activeRecoveryOps == 0 && !_recoveryStateController.isClosed) {
      _recoveryStateController.add(false);
    }
  }

  /// Recovers the user's full DM history from relays once per install.
  ///
  /// On reinstall the local DB and [DmSyncState] are wiped, so the live
  /// subscription's bounded first-open window (`limit:50`) only persists
  /// the most-recent conversations; the rest are absent from the
  /// conversation list (a pure local-DB projection) with no UI path to
  /// recover them. This drains older pages newest→oldest until the relay
  /// is exhausted (or [DmHistoryDrainConfig.maxPages] is reached),
  /// backfilling every conversation that still has events on a relay.
  /// See #4953.
  ///
  /// Idempotent and resumable: returns immediately once a clean drain has
  /// completed for the user ([DmSyncState.historyDrainComplete]); an
  /// interrupted drain resumes from the persisted boundary on the next
  /// call. Concurrent callers share one in-flight run. Runs in the
  /// background — per-event decryption already offloads to a [compute]
  /// isolate — so it is safe to fire-and-forget from the inbox BLoC on
  /// every open.
  Future<void> backfillHistoryIfNeeded() {
    final existing = _historyDrain;
    if (existing != null) return existing;
    final drain = _runHistoryDrain();
    _historyDrain = drain;
    unawaited(
      drain.whenComplete(() {
        if (identical(_historyDrain, drain)) _historyDrain = null;
      }),
    );
    return drain;
  }

  /// Replays gift wraps that previously failed NIP-44 decryption.
  ///
  /// On remote-signer accounts (Keycast RPC) each gift-wrap decrypt is a
  /// network call, so a transient failure during the history-drain burst
  /// would otherwise silently drop the conversation. Those wraps are
  /// persisted raw (see [_handleGiftWrapEvent]); this replays each back
  /// through the decrypt + persist pipeline, newest first, capped at
  /// [DmHistoryDrainConfig.maxDecryptRetries] attempts per wrap so a
  /// permanently-undecryptable wrap cannot loop forever (rows that exhaust
  /// the cap are dropped). Each replay routes through [_handleIncomingEvent]
  /// so it serializes on the same `_eventLock` as the live subscription and
  /// the drain. Concurrent callers share one in-flight pass. A no-op when no
  /// failed-decrypt DAO is wired. Safe to fire-and-forget from the inbox
  /// BLoC on every open. See #5202.
  Future<void> retryPendingDecryptions() {
    final existing = _pendingDecryptRetry;
    if (existing != null) return existing;
    final run = _runPendingDecryptRetry();
    _pendingDecryptRetry = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_pendingDecryptRetry, run)) _pendingDecryptRetry = null;
      }),
    );
    return run;
  }

  /// Whether the session a background ingest pass started under has ended —
  /// the repository was torn down, the user switched, or an explicit
  /// [stopListening] bumped the session token.
  ///
  /// Every ingest-loop guard reads this one predicate so they cannot drift
  /// apart: #7318 was six guards that all tested `_disposed || _userPubkey`
  /// while the live-subscription path had already moved on to the token.
  bool _ingestSessionEnded(String pubkey, int generation) =>
      _disposed || _userPubkey != pubkey || _resetGeneration != generation;

  Future<void> _runPendingDecryptRetry() async {
    // Same shape as the drain: deleteExhausted below is a write, and it runs
    // ahead of the first session guard. See #7318.
    if (_disposed || !isInitialized) return;
    final dao = _pendingGiftWrapsDao;
    if (dao == null) return;
    final pubkey = _userPubkey;
    final gen = _resetGeneration;
    var began = false;
    try {
      // Drop wraps that exhausted the retry cap so the queue cannot grow
      // without bound — a permanently-undecryptable wrap or spammed kind-1059
      // events addressed to the user would otherwise linger forever. See #5202.
      final abandoned = await dao.deleteExhausted(
        ownerPubkey: pubkey,
        maxAttempts: DmHistoryDrainConfig.maxDecryptRetries,
      );
      if (abandoned > 0) {
        // These are inbound DMs the user will never see. The wrap carries no
        // decryptable sender or conversation, so there is nothing to surface in
        // the UI — but dropping it with no trace at all made permanent message
        // loss invisible in triage.
        Log.warning(
          'Abandoned $abandoned undecryptable gift wrap(s) for '
          '${pubkeyForLogs(pubkey)} after '
          '${DmHistoryDrainConfig.maxDecryptRetries} attempts; those inbound '
          'messages are permanently unrecoverable',
          category: LogCategory.system,
        );
        // A local warning is invisible in triage, and permanent inbound-message
        // loss is exactly what we cannot afford to discover only from user
        // reports. Bounded on purpose: one report per drain pass carrying the
        // aggregate count, so a spam burst cannot flood the dashboard.
        _errorReporter?.call(
          StateError(
            'Abandoned $abandoned undecryptable gift wrap(s) after '
            '${DmHistoryDrainConfig.maxDecryptRetries} attempts',
          ),
          StackTrace.current,
          site: DmRepositoryReportableSites.pendingDecryptExhausted,
        );
      }
      final pending = await dao.getRetryable(
        ownerPubkey: pubkey,
        maxAttempts: DmHistoryDrainConfig.maxDecryptRetries,
      );
      if (pending.isEmpty) return;
      // Only signal "recovering" once there is genuine work, so a normal
      // inbox open (empty queue) never flickers the progress indicator.
      _beginRecovery();
      began = true;
      for (var i = 0; i < pending.length; i++) {
        if (_ingestSessionEnded(pubkey, gen)) return;
        final row = pending[i];
        // Already recovered by the live sub / drain — clear the stale row so
        // it does not linger and re-query on every inbox open.
        if (await _directMessagesDao.hasGiftWrap(row.giftWrapId)) {
          await dao.deletePending(
            giftWrapId: row.giftWrapId,
            ownerPubkey: pubkey,
          );
          continue;
        }
        final Event giftWrapEvent;
        try {
          giftWrapEvent = Event.fromJson(
            jsonDecode(row.rawJson) as Map<String, dynamic>,
          );
        } on Object catch (e, stackTrace) {
          // Corrupt stored JSON — drop it so it cannot loop. We wrote this
          // JSON ourselves, so a parse failure is a programming invariant and
          // costs the user an inbound message; report it rather than dropping
          // silently.
          Log.error(
            'Corrupt pending gift wrap ${row.giftWrapId} for '
            '${pubkeyForLogs(pubkey)}; '
            'dropping an unrecoverable inbound message',
            category: LogCategory.system,
            error: e,
            stackTrace: stackTrace,
          );
          _errorReporter?.call(
            e,
            stackTrace,
            site: DmRepositoryReportableSites.pendingDecryptCorruptPayload,
          );
          await dao.deletePending(
            giftWrapId: row.giftWrapId,
            ownerPubkey: pubkey,
          );
          continue;
        }
        // Re-check after the awaits above so an account switch or a teardown
        // mid-pass never replays the old user's wrap under the new session.
        if (_ingestSessionEnded(pubkey, gen)) return;
        // Route through _handleIncomingEvent so the replay serializes on the
        // same _eventLock as the live subscription and the drain. A
        // successful decrypt deletes the pending row inside
        // _handleGiftWrapEvent; a failure increments its attempts.
        await _handleIncomingEvent(giftWrapEvent);
        // WS3: yield periodically so a large retry queue cannot starve frame
        // rendering. See #5391.
        await _maybeYieldDuringDrain(i);
      }
    } on Object catch (e, stackTrace) {
      // Relay/DB/IO failures here are expected (e.g. a transient read-only
      // DB) and NOT reportable; the pass resumes on the next inbox open since
      // rows are removed only on success, cap, or corruption.
      Log.error(
        'DM decrypt-retry pass failed (will resume on next inbox open): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (began) _endRecovery();
    }
  }

  Future<void> _runHistoryDrain() async {
    // Ahead of isInitialized, which stopListening() deliberately leaves true so
    // a restart can re-open: the preamble below writes before reaching the
    // first session guard. upgradeDrainVersionIfNeeded re-stamps the drain
    // version, and an absent key reads as version 0, so once the account
    // cleanup has wiped DmSyncState this pass always writes. See #7318.
    if (_disposed || !isInitialized) return;
    final syncState = _syncState;
    if (syncState == null) return;
    // Pin the user for the whole drain so an account switch mid-drain can
    // never mark the wrong pubkey complete or query for the new user.
    final pubkey = _userPubkey;
    // Pin the session token alongside the user. _disposed alone would stop a
    // drain on the stopListening() path, but a stop immediately followed by a
    // restart on this instance clears it again under an in-flight drain.
    final gen = _resetGeneration;
    // A run in progress supersedes a resume armed by an earlier deferral; if
    // this run defers too it arms a fresh one against the pool it saw.
    unawaited(_drainRelayReadySubscription?.cancel());
    _drainRelayReadySubscription = null;
    // Run this before the ordinary version stamp: that ordering distinguishes
    // a pre-fix generation-5 install from a fresh install starting its first
    // drain on this build. See #8550 and #8646.
    await syncState.migrateHistoryDrainCompletion(pubkey);
    // One-time forced re-drain: installs that completed under an older,
    // buggy drain (pre-#5202) are stuck with historyDrainComplete=true while
    // the relay still holds unrecovered history. A drain-version bump clears
    // the stale flag once so recovery runs again. No-op once at the current
    // version, so it does not loop on every inbox open. See #5202.
    await syncState.upgradeDrainVersionIfNeeded(pubkey);
    if (syncState.historyDrainComplete(pubkey) &&
        !syncState.drainCoveredOwnInbox(pubkey)) {
      // Completed before the drain recorded whether it knew the user's
      // advertised inbox relays — so it may have declared history complete
      // having never asked them. Fixing that forward helps nobody already
      // latched, and there is no user-facing resync, so spend one conclusive
      // read to find out.
      final recovery = await _drainOwnInboxRelays(pubkey, gen);
      if (_ingestSessionEnded(pubkey, gen)) return;
      if (recovery.conclusive) {
        // Either answer settles it. A list means the earlier run may have
        // missed whole relays, so re-arm once. No list means the pool was
        // always the whole story and the completion was honest. Recording it
        // either way is what stops this costing a read on every inbox open.
        await syncState.setDrainCoveredOwnInbox(pubkey);
        if (recovery.relays != null) {
          await syncState.rearmDrainForOwnInbox(pubkey);
          Log.info(
            'DM history drain re-armed for ${pubkeyForLogs(pubkey)}: the '
            "completed run never read the account's own DM inbox relays, "
            'which are now known',
            category: LogCategory.system,
          );
        }
      }
    }
    if (syncState.historyDrainComplete(pubkey)) {
      Log.info(
        'DM history drain skipped for ${pubkeyForLogs(pubkey)}: already '
        'complete',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      'DM history drain starting for ${pubkeyForLogs(pubkey)} '
      '(connected relays ${_nostrClient.connectedRelayCount}/'
      '${_nostrClient.configuredRelayCount})',
      category: LogCategory.system,
    );

    _beginRecovery();
    DmDecryptWorker? drainDecryptIsolate;
    try {
      // Spawn one drain-scoped decrypt isolate for local-key signers so the
      // whole backfill pays a single isolate spawn instead of one per chunk
      // (#5391 review). Remote / test signers leave it null and the batch path
      // falls through to the unchanged per-event decryptor. Inside the `try`
      // so the `finally` always reclaims it. See #5391.
      final drainSigner = _signer;
      if (drainSigner is IsolateDecryptSigner &&
          drainSigner.canDecryptInIsolate) {
        try {
          final spawned = await _decryptIsolateSpawner(
            drainSigner.withPrivateKeyHex((k) => k),
          );
          if (_ingestSessionEnded(pubkey, gen)) {
            spawned.close();
            return;
          }
          drainDecryptIsolate = spawned;
          _drainDecryptIsolate = spawned;
        } on Object catch (e, stackTrace) {
          Log.error(
            'DM decrypt isolate spawn failed; using per-event decrypt: $e',
            category: LogCategory.system,
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      // Remote signers (no decrypt isolate) validate each gift wrap on the
      // main isolate inside GiftWrapUtil.getRumorEvent. Bring up the shared
      // key-less verify isolate so that id + Schnorr work moves off the main
      // isolate; local-key signers already validate inside their decrypt
      // isolate, so they skip this. On spawn failure _ensureVerifyIsolate
      // logs, returns null, and wraps validate inline. See #5424.
      if (drainDecryptIsolate == null) {
        await _ensureVerifyIsolate();
        if (_ingestSessionEnded(pubkey, gen)) return;
      }

      // The relay filters `until:` on the OUTER gift-wrap created_at, which
      // NIP-59 randomizes up to 2 days into the past — so the cursor tracks
      // fetched events' outer timestamps, NOT the rumor times recorded in
      // oldestSyncedAt. Resume from the persisted drain cursor when an
      // earlier run was interrupted or page-capped; otherwise seed below
      // the live subscription's discovered boundary (oldestSyncedAt); else
      // now.
      var cursor =
          syncState.historyDrainCursor(pubkey) ??
          syncState.oldestSyncedAt(pubkey) ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Resolve the user's OWN kind-10050 inbox relays once for the whole
      // drain and dial every page at them as well as the pool, so the backfill
      // reads gift wraps delivered outside the default pool. `null` keeps
      // default-pool-only behavior. See #4974.
      final inbox = await _drainOwnInboxRelays(pubkey, gen);
      if (_ingestSessionEnded(pubkey, gen)) return;
      final ownInbox = inbox.relays;

      var reachedEnd = false;
      // Set by any page not every relay settled — empty or not. Freezes the
      // durable cursor and blocks completion for the rest of this run, so a
      // window one relay never answered is re-requested rather than skipped
      // past. See the partial-page guard below. #8209.
      //
      // Seeded true when the inbox itself could not be read: that is the same
      // defect one level up — the fan-out is missing whole relays rather than
      // one relay in it staying silent — and it must not latch completion
      // either.
      var sawUnansweredPage = !inbox.conclusive;
      var partialViewReason = 'an earlier page was not fully settled';
      if (sawUnansweredPage) {
        partialViewReason =
            "the account's own DM inbox relays could not be read, so this run "
            'paged the default pool only';
        // Pin the resume point before paging, for the same reason the in-loop
        // pins exist: this run persists messages, which drags oldestSyncedAt
        // down, and an unpinned next run would seed below the windows the
        // inbox relays still have to be asked for.
        await syncState.setHistoryDrainCursor(pubkey, cursor);
        Log.warning(
          'DM history drain for ${pubkeyForLogs(pubkey)} could not read the '
          "account's own DM inbox relays; holding the resume cursor at "
          '$cursor and deferring completion to the next inbox open.',
          category: LogCategory.system,
        );
      }
      var pagesRun = 0;
      var totalEvents = 0;
      for (var page = 0; page < DmHistoryDrainConfig.maxPages; page++) {
        // Bail if the user switched or the repository was torn down.
        if (_ingestSessionEnded(pubkey, gen)) return;
        final historyPage = await _fetchHistoryPage(
          until: cursor,
          limit: DmHistoryDrainConfig.pageSize,
          subscriptionId: dmHistoryDrainSubscriptionId(pubkey, page),
          pubkey: pubkey,
          generation: gen,
          tempRelays: ownInbox,
        );
        if (historyPage == null) return;
        final events = historyPage.events;
        // _fetchHistoryPage's own guard sits at the top of its persist loop,
        // so the last event's persist and the yield after it are both
        // suspension points it cannot see past — it returns the page either
        // way. Re-check here or a teardown landing in that gap still reaches
        // setHistoryDrainCursor below and re-seeds the wiped state. See #7318.
        if (_ingestSessionEnded(pubkey, gen)) return;
        pagesRun++;
        totalEvents += events.length;
        if (events.isEmpty) {
          // An empty page is genuine history exhaustion ONLY if a relay
          // actually ANSWERED it. Connected is not answered: a write-only
          // relay and one whose socket died since its last status update both
          // still count as connected, so the old `connectedRelayCount` test
          // could not see a fan-out nobody took, a relay that refused the REQ
          // with `CLOSED`, or a page the settle window completed on the
          // relays that did answer. Marking the drain complete on any of those
          // permanently strands unrecovered history (#5202 root cause, #8209).
          // Defer instead: leave historyDrainComplete unset and resume on the
          // next inbox open from the window this run pins below.
          if (!historyPage.authoritative) {
            if (!sawUnansweredPage) {
              // Pin the resume point at this window before giving up on the
              // run. Falling back to the seed is not safe: with no cursor
              // persisted the next run seeds from oldestSyncedAt, which this
              // run's own persisted messages drag downward (recordSeen), so
              // the window would be skipped by the events it did return.
              await syncState.setHistoryDrainCursor(pubkey, cursor);
              Log.warning(
                'DM history drain saw an empty page that no relay answered for '
                '${pubkeyForLogs(pubkey)}; holding the resume cursor at '
                '$cursor and deferring completion to the next inbox open.',
                category: LogCategory.system,
              );
            }
            _resumeDrainWhenRelayConnects(pubkey, gen);
            return;
          }
          reachedEnd = true;
          break;
        }

        if (!historyPage.authoritative) {
          // A page that carried events but which not every relay settled: one
          // relay answered while another never did, so this window can still
          // hold events this page did not see. The events it did return are
          // real and already persisted. What must not happen is the durable
          // cursor moving below a window we have only partly seen — the
          // unanswered relay's events in it would never be requested again,
          // and a later authoritative empty page would then latch completion
          // over the gap. That is the same permanent strand as latching on an
          // empty page, one window wide instead of the whole tail.
          //
          // So: keep paging, because this run should still recover everything
          // the relays that DID answer hold; stop persisting, so the next run
          // resumes from the last window every relay settled and re-requests
          // this one (dedup absorbs the overlap); and do not complete off this
          // run. See #8209.
          if (!sawUnansweredPage) {
            // Pin the resume point at the top of this window, for the same
            // reason as the empty case above: an unpinned run falls back to
            // oldestSyncedAt, which this page's own persisted messages have
            // already dragged below the window we still need to re-read.
            await syncState.setHistoryDrainCursor(pubkey, cursor);
            Log.warning(
              'DM history drain saw a page not every relay settled for '
              '${pubkeyForLogs(pubkey)}; holding the resume cursor at '
              '$cursor and deferring completion to the next inbox open.',
              category: LogCategory.system,
            );
          }
          sawUnansweredPage = true;
        }

        // Step strictly below the oldest event seen so the loop always
        // makes progress. `until` is inclusive, so re-requesting the
        // boundary on a saturated page is absorbed by hasGiftWrap dedup
        // rather than lost.
        final minCreatedAt = events
            .map((event) => event.createdAt)
            .reduce((a, b) => a < b ? a : b);
        cursor = minCreatedAt < cursor ? minCreatedAt : cursor - 1;
        if (cursor <= 0) {
          reachedEnd = true;
          break;
        }
        // Persist the boundary so an interrupted or page-capped run
        // resumes from here on the next inbox open rather than restarting
        // from the top. Frozen once a page went unanswered, so the resume
        // point never moves below a window that page may not have seen whole.
        if (!sawUnansweredPage) {
          await syncState.setHistoryDrainCursor(pubkey, cursor);
        }
      }

      if (reachedEnd && !sawUnansweredPage) {
        // Before declaring history complete, recover the user's OWN outgoing
        // NIP-04 messages. The paged drain above filters `p:[self]`, which
        // matches incoming NIP-04 and the user's NIP-17 self-wraps but never
        // the user's outgoing kind-4 (`author=self, p=recipient`, per NIP-04),
        // so a legacy conversation the user only ever replied to over NIP-04
        // could not re-prove `currentUserHasSent` and stayed stranded under
        // "Message requests". See #5304.
        //
        // Defer completion if this pass couldn't run against a live relay
        // (e.g. a momentary disconnect in this window) so a flaky network
        // never silently skips recovery AND marks the drain complete — it
        // resumes on the next inbox open instead.
        final nip04Recovered = await _recoverOutgoingNip04(pubkey, gen);
        if (nip04Recovered) {
          // This run reached a conclusive answer about the account's own
          // inbox relays — completion is only reachable when it did — so a
          // later session never has to spend a read finding that out.
          await syncState.setDrainCoveredOwnInbox(pubkey);
          await syncState.markHistoryDrainComplete(pubkey);
          // Restore read state now that the full conversation set is present:
          // last-sent floor + any read markers stashed during the drain. #4977.
          await _restoreReadStateAfterDrain(pubkey, gen);
          Log.info(
            'DM history drain complete for ${pubkeyForLogs(pubkey)}: '
            'pages=$pagesRun, eventsFetched=$totalEvents',
            category: LogCategory.system,
          );
        } else {
          Log.warning(
            'DM history drain reached the end for ${pubkeyForLogs(pubkey)} but '
            'outgoing '
            'NIP-04 recovery could not complete (no live relay); deferring '
            'completion to the next inbox open.',
            category: LogCategory.system,
          );
          _resumeDrainWhenRelayConnects(pubkey, gen);
        }
      } else if (reachedEnd) {
        // Reached the end of what the answering relays hold, but an earlier
        // page in this run was not fully settled, so the run has no standing
        // to call history exhausted. The resume cursor is still parked above
        // that window; the next inbox open re-requests it. #8209.
        Log.warning(
          'DM history drain reached the end for ${pubkeyForLogs(pubkey)} but '
          '$partialViewReason; deferring completion to the '
          'next inbox open.',
          category: LogCategory.system,
        );
        _resumeDrainWhenRelayConnects(pubkey, gen);
      } else {
        // Page cap hit: leave historyDrainComplete unset and the cursor
        // persisted so the next inbox open resumes the remaining history
        // instead of permanently truncating it for heavy users. See #4953.
        // Report the DURABLE cursor, not the loop's: once a page goes
        // unsettled the persist above is frozen while `cursor` keeps
        // descending, so the two diverge in exactly the case a reader of
        // this line is trying to diagnose. See #8209.
        Log.warning(
          'DM history drain paused at the page cap '
          '(${DmHistoryDrainConfig.maxPages}) for ${pubkeyForLogs(pubkey)} '
          'after '
          '$totalEvents events; will resume from the persisted cursor '
          '(${syncState.historyDrainCursor(pubkey) ?? cursor}) on the next '
          'inbox open.',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      // Relay/IO failures are expected on flaky networks and are NOT
      // reportable (see error_handling.md). Leaving historyDrainComplete
      // unset lets the next inbox open resume the drain.
      Log.error(
        'DM history drain failed (will resume on next inbox open): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      if (e is StateError || e is TypeError || e is RangeError) {
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites.historyDrainUnexpectedFailure,
        );
      }
    } finally {
      // Kill the drain-scoped decrypt isolate (reclaiming the resident key)
      // before clearing the recovery flag. Runs on every exit path — page
      // cap, exhaustion, user-switch / teardown bail, or error. See #5391.
      // The shared verify isolate deliberately survives the drain: it holds
      // no key, and live-subscription wraps keep verifying through it.
      drainDecryptIsolate?.close();
      if (identical(_drainDecryptIsolate, drainDecryptIsolate)) {
        _drainDecryptIsolate = null;
      }
      _endRecovery();
    }
  }

  /// Resumes a deferred history drain once a relay connects that was not
  /// connected the last time the pool was observed.
  ///
  /// Every relay-availability deferral leaves `historyDrainComplete` unset
  /// and waits for "the next inbox open". But the inbox is already open,
  /// showing the restore-paused banner, and its Retry re-runs the drain
  /// against whatever the pool looks like at that instant — against an
  /// idle-disconnected pool that is the same failure again. Like the labeler
  /// and feed services, this holds a one-shot relay-status listener, but uses
  /// a finer trigger: a rising edge. It re-runs the drain when a relay becomes
  /// connected that was not connected at the previous observation — one the
  /// deferral did not have, or one it had whose socket has since dropped and
  /// come back. The second case is how a relay that took the REQ and never
  /// answered gets a second chance: it still counts as connected when the
  /// drain gives up, the SDK's silent-relay repair then cycles that socket,
  /// and only the reconnection can say the relay is answering again. Keyed on
  /// the deferral-time snapshot alone, that reconnection was ignored and the
  /// banner stayed up until a manual retry (verified against a paused relay,
  /// #8643). A relay merely reporting again while still connected is not an
  /// edge. A relay that repeatedly reconnects without answering can therefore
  /// re-drive the bounded drain. At most one listener is armed at a time, a
  /// new run supersedes it, and teardown cancels it. A page-cap pause
  /// deliberately does not arm one: that budget resumes on the next inbox
  /// open by design. See #8550.
  void _resumeDrainWhenRelayConnects(String pubkey, int generation) {
    unawaited(_drainRelayReadySubscription?.cancel());
    _drainRelayReadySubscription = null;
    if (_ingestSessionEnded(pubkey, generation)) return;
    final lastConnected = <String>{
      for (final entry in _nostrClient.relayStatuses.entries)
        if (entry.value.isConnected) entry.key,
    };
    Log.info(
      'DM history drain for ${pubkeyForLogs(pubkey)} will resume when a relay '
      'connects (connected now: ${lastConnected.length}/'
      '${_nostrClient.configuredRelayCount})',
      category: LogCategory.system,
    );
    _drainRelayReadySubscription = _nostrClient.relayStatusStream.listen((
      statuses,
    ) {
      final nowConnected = <String>{
        for (final entry in statuses.entries)
          if (entry.value.isConnected) entry.key,
      };
      final newlyConnected = nowConnected.any(
        (url) => !lastConnected.contains(url),
      );
      lastConnected
        ..clear()
        ..addAll(nowConnected);
      if (!newlyConnected) return;
      unawaited(_drainRelayReadySubscription?.cancel());
      _drainRelayReadySubscription = null;
      if (_ingestSessionEnded(pubkey, generation)) return;
      Log.info(
        'Resuming DM history drain for ${pubkeyForLogs(pubkey)} after a relay '
        'connected',
        category: LogCategory.system,
      );
      unawaited(backfillHistoryIfNeeded());
    });
  }

  /// Stops listening for incoming DMs and tears this repository down.
  ///
  /// This is the production disposal path — `dmRepositoryProvider` wires it to
  /// `ref.onDispose`, and the account cleanup awaits it before wiping the DM
  /// tables — so it stops the background ingest loops too, not just the
  /// subscription. See #7318.
  Future<void> stopListening() async {
    // _disposed is what stops the history drain and the decrypt-retry pass:
    // their guards read it, and nothing else those guards check flips here
    // (_userPubkey is cleared only by _resetState, which the provider never
    // reaches). It also suppresses the onDone reconnect. A later
    // startListening() on this instance still re-opens cleanly — it clears the
    // flag as its first statement, precisely so a stop can be followed by a
    // restart, and nothing user-facing reads it.
    _disposed = true;
    final postAuthMaintenance = _postAuthMaintenance;
    // Bump the session token too: an intentional stop must invalidate any
    // startListening()/ensureDmRelayListPublished() resolve already in flight,
    // so its post-await continuation bails instead of re-opening the
    // subscription (or completing a publish) after the stop. See #4974.
    _resetGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _drainRelayReadySubscription?.cancel();
    _drainRelayReadySubscription = null;
    // Drop the loop handles so a later startListening() starts a fresh pass
    // rather than re-awaiting a stale future, and reclaim the drain-scoped
    // decrypt isolate holding this user's key now rather than whenever the
    // bailing drain unwinds. The drain's own `finally` is idempotent if it
    // also runs. Mirrors _resetState. See #7318.
    final historyDrain = _historyDrain;
    final pendingDecryptRetry = _pendingDecryptRetry;
    _historyDrain = null;
    _pendingDecryptRetry = null;
    _drainDecryptIsolate?.close();
    _drainDecryptIsolate = null;
    // Close the shared verify isolate: in production this is the disposal
    // path — dmRepositoryProvider rebuilds construct a fresh repository and
    // dispose the old one via stopListening, never via _resetState — so
    // without this close every provider rebuild would orphan a live worker
    // (PR #5957 review). Re-spawns lazily on the next wrap; a spawn in
    // flight is invalidated by the generation bump above.
    _verifyIsolate?.close();
    _verifyIsolate = null;
    _verifyIsolateSpawnFailed = false;
    // Cancel a pending read-marker publish; the cursor is persisted, so it
    // republishes on the next read or session. Keep _pendingReadCursors — the
    // same user may resume listening. #4977.
    _readMarkerDebounce?.cancel();
    _readMarkerDebounce = null;
    await _giftWrapSubscription?.cancel();
    _giftWrapSubscription = null;
    try {
      await _nostrClient.unsubscribe(_subscriptionId);
    } on Object {
      // Ignore if subscription doesn't exist
    }

    // stopListening() is awaited immediately before account cleanup wipes the
    // DM tables. Session guards stop future iterations, but the current event
    // persist can already be past its final guard, and the drain can still
    // have cursor/read-state writes after it. Preserve the handles captured
    // above and wait for every writer to observe the teardown before declaring
    // the repository quiescent. See #7318.
    await postAuthMaintenance;
    await historyDrain;
    await pendingDecryptRetry;
    while (_eventLock != null) {
      await _eventLock;
    }
  }

  // -------------------------------------------------------------------------
  // Receive pipeline
  // -------------------------------------------------------------------------

  /// Routes an incoming event to the correct handler based on kind.
  ///
  /// Serialized via [_eventLock] so that subscription events never race
  /// into the dedup/insert path concurrently.
  Future<void> _handleIncomingEvent(Event event) async {
    if (event.kind == EventKind.giftWrap) {
      final gen = _resetGeneration;
      final ownerPubkey = _userPubkey;
      await _withGiftWrapProcessingLock(() async {
        if (_disposed ||
            _resetGeneration != gen ||
            _userPubkey != ownerPubkey) {
          return;
        }
        await _handleGiftWrapEvent(event);
      });
      return;
    }
    await _withEventLock(() async {
      if (event.kind == EventKind.eventDeletion) {
        await _handleDeletionEvent(event);
      } else if (event.kind == EventKind.directMessage) {
        await _handleNip04Event(event);
      }
    });
  }

  Future<void> _withGiftWrapProcessingLock(Future<void> Function() body) async {
    while (_giftWrapProcessingLock != null) {
      await _giftWrapProcessingLock;
    }
    final completer = Completer<void>();
    _giftWrapProcessingLock = completer.future;
    try {
      await body();
    } finally {
      _giftWrapProcessingLock = null;
      completer.complete();
    }
  }

  /// Runs [body] under the [_eventLock] so dedup/insert work is serialized,
  /// whether it comes from the live subscription ([_handleIncomingEvent]) or
  /// the batched history-drain persist path ([_fetchHistoryPage]). The lock
  /// guards only persistence; batched decryption runs off-lock. See #5391.
  Future<void> _withEventLock(Future<void> Function() body) async {
    // Wait for any in-flight event processing to complete.
    while (_eventLock != null) {
      await _eventLock;
    }
    final completer = Completer<void>();
    _eventLock = completer.future;
    try {
      await body();
    } finally {
      _eventLock = null;
      completer.complete();
    }
  }

  /// Handles an incoming NIP-09 kind 5 deletion event.
  ///
  /// For each `e` tag, validates that the event author matches the original
  /// message sender (NIP-09 requirement) before soft-deleting.
  Future<void> _handleDeletionEvent(Event deletionEvent) async {
    try {
      for (final tag in deletionEvent.tags) {
        if (tag.length < 2 || tag[0] != 'e') continue;
        await _applyMessageDeletion(rumorId: tag[1], deletion: deletionEvent);
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process kind 5 event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Applies a wrapped NIP-09 kind-5 rumor to whichever store holds each
  /// target it names — the reaction rows, the message rows, or both.
  ///
  /// Routing resolves each `e` target against local state rather than
  /// believing the rumor's `k` tag. `k` is only a hint for which store to try
  /// first. Three reasons, and each one has bitten:
  ///
  ///  * NIP-09 makes `k` a SHOULD (`09.md:9`), so a conforming foreign client
  ///    may omit it entirely (#7329).
  ///  * Our own sender hardcodes `['k','14']` even when deleting a kind-15
  ///    file message, so the tag is already wrong on our own wire.
  ///  * Before this, *every* wrapped kind-5 went to the reactions handler,
  ///    which answered `processed` for anything not tagged `['k','7']`. That
  ///    recorded the wrap terminally and lost message deletions for good
  ///    (#7809).
  ///
  /// The outcome across targets is a conjunction that only ever downgrades:
  /// [DmWrapOutcome.processed] requires *every* target to have reached a
  /// terminal state. NIP-09 permits several `e` tags, and a rumor naming one
  /// known and one unsynced target must not be recorded — doing so would lose
  /// the unsynced one permanently, which is the very bug this fixes.
  Future<DmWrapOutcome> _routeWrappedDeletion({
    required Event rumor,
    required String giftWrapId,
  }) async {
    final reactions = _reactionsRepository;
    final tryReactionsFirst = _hasKindHint(rumor.tags, EventKind.reaction);

    var outcome = DmWrapOutcome.processed;
    for (final tag in rumor.tags) {
      if (tag.length < 2 || tag[0] != 'e') continue;
      final rumorId = tag[1];

      Future<DmWrapOutcome?> asReaction() async => reactions?.applyDeletion(
        rumorId: rumorId,
        deleterPubkey: rumor.pubkey,
        giftWrapId: giftWrapId,
      );
      Future<DmWrapOutcome?> asMessage() async =>
          _applyMessageDeletion(rumorId: rumorId, deletion: rumor);

      final resolved = tryReactionsFirst
          ? await asReaction() ?? await asMessage()
          : await asMessage() ?? await asReaction();

      // Neither store holds the target — it may still arrive, since NIP-59
      // randomizes gift-wrap `created_at` and a deletion can drain ahead of
      // the event it names. A null `_reactionsRepository` (legacy fixtures)
      // lands here too: that is "cannot resolve", not "nothing to do", and
      // cementing it would burn the wrap for every account on the device.
      if ((resolved ?? DmWrapOutcome.deferred) == DmWrapOutcome.deferred) {
        outcome = DmWrapOutcome.deferred;
      }
    }
    return outcome;
  }

  /// Whether [tags] carries a `['k', <kind>]` hint naming [kind].
  static bool _hasKindHint(List<List<String>> tags, int kind) {
    final wanted = kind.toString();
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == 'k' && tag[1] == wanted) return true;
    }
    return false;
  }

  /// Applies [deletion] to [rumorId], the
  /// single place the NIP-09 author rule is enforced for messages.
  ///
  /// Returns `null` when this account holds no message with that id, so the
  /// wrapped classifier can try the reaction store instead — the apply
  /// doubles as the probe, keeping routing to one DAO read when the `k` hint
  /// is right.
  ///
  /// Every other outcome is [DmWrapOutcome.processed] — applied, already
  /// deleted, or refused for author mismatch. A mismatch will never become
  /// valid, so re-decrypting it forever buys nothing.
  ///
  /// The deletion author's pubkey must be authenticated. For a wrapped
  /// deletion that is `rumor.pubkey`, which `getRumorEvent` rebuilds from the
  /// signed seal — never the gift wrap's own pubkey, which is an ephemeral
  /// NIP-59 key carrying no identity.
  Future<DmWrapOutcome?> _applyMessageDeletion({
    required String rumorId,
    required Event deletion,
  }) async {
    final row = await _directMessagesDao.getMessageById(
      rumorId,
      ownerPubkey: _ownerPubkey,
    );
    if (row == null) return null;

    // NIP-09: only the original author may delete.
    if (row.senderPubkey != deletion.pubkey) {
      Log.debug(
        'Ignoring kind 5 for $rumorId: author mismatch '
        '(event=${pubkeyForLogs(deletion.pubkey)}, '
        'sender=${pubkeyForLogs(row.senderPubkey)})',
        category: LogCategory.system,
      );
      return DmWrapOutcome.processed;
    }

    // A self-wrap proves that another device requested the retraction, not
    // that every recipient accepted it. Start a local pending lifecycle only
    // when this row has no deletion lifecycle of its own. An echo carries a
    // distinct kind-5 from the local attempt, so overwriting an existing
    // pending/blocked rumor would defeat replay identity; reopening `sent`
    // would resurrect a confirmed-deleted bubble and re-publish it.
    if (deletion.pubkey == _ownerPubkey) {
      if (row.deletionPublishStatus != null) {
        return DmWrapOutcome.processed;
      }
      await _directMessagesDao.markMessageDeletionPending(
        rumorId,
        deletionRumorJson: jsonEncode(deletion.toJson()),
        ownerPubkey: _ownerPubkey,
      );
      await _refreshConversationPreview(row.conversationId);
      return DmWrapOutcome.processed;
    }

    if (row.isDeleted) return DmWrapOutcome.processed; // Already processed.

    await _directMessagesDao.markMessageDeleted(
      rumorId,
      ownerPubkey: _ownerPubkey,
    );
    await _refreshConversationPreview(row.conversationId);

    Log.debug(
      'Applied kind 5 deletion for message $rumorId',
      category: LogCategory.system,
    );
    return DmWrapOutcome.processed;
  }

  /// Pre-decrypt dedup: has this gift wrap (or NIP-04 event) already been
  /// processed, by either path? Text/file messages (kind 14/15) leave a
  /// `directMessages` row; the outcomes that write no message row (reactions,
  /// deletions, unsupported kinds, cross-protocol dups, degenerate
  /// participants, messages suppressed by a removed-conversation tombstone)
  /// leave a `processed_gift_wraps` ledger row instead. Checking both means a
  /// re-delivered wrap of any kind is skipped before paying a decrypt. #5452.
  Future<bool> _alreadyProcessed(String giftWrapId) async {
    if (await _directMessagesDao.hasGiftWrap(giftWrapId)) return true;
    final ledger = _processedGiftWrapsDao;
    if (ledger == null) return false;
    return ledger.hasGiftWrap(giftWrapId);
  }

  /// Attributes an already-processed kind-4 to a local account.
  ///
  /// [_alreadyProcessed] is global on the documented reasoning that a
  /// gift-wrap event id is globally unique. That holds for kind 1059, where
  /// NIP-59 mints a fresh ephemeral key and a separate wrap per recipient, so
  /// one id can only ever belong to one local account. A kind 4 has no
  /// envelope — one signed event, one author, one `p` recipient — so when both
  /// ends are accounts on this device they genuinely share an id, and
  /// `_recoverOutgoingNip04` makes that concrete by paging the whole outgoing
  /// history of one account into tables the other one reads.
  ///
  /// The global probe still runs first and still decides whether to pay for a
  /// decrypt: the event is terminally handled on this device either way. What
  /// this adds is who handled it, which is what decides whether this account
  /// may move its own sync boundary past it.
  Future<_Nip04DedupHit> _nip04DedupHit(
    String eventId, {
    required String ownerPubkey,
  }) async {
    if (!await _alreadyProcessed(eventId)) return _Nip04DedupHit.none;
    if (ownerPubkey.isEmpty) return _Nip04DedupHit.thisAccount;
    // The kind-4 insert writes the same id into both `id` and `giftWrapId`,
    // so an owner-scoped lookup by id is the exact counterpart of the global
    // `hasGiftWrap` probe on this path — and it already applies the legacy
    // unowned-row allowance.
    if (await _directMessagesDao.getMessageById(
          eventId,
          ownerPubkey: ownerPubkey,
        ) !=
        null) {
      return _Nip04DedupHit.thisAccount;
    }
    final ledger = _processedGiftWrapsDao;
    if (ledger != null &&
        await ledger.hasGiftWrapForOwner(
          giftWrapId: eventId,
          ownerPubkey: ownerPubkey,
        )) {
      return _Nip04DedupHit.thisAccount;
    }
    return _Nip04DedupHit.otherAccount;
  }

  /// Batched form of [_alreadyProcessed] for the history-drain dedup probe.
  /// Resolves which of [giftWrapIds] are already persisted or in the dedup
  /// ledger with TWO `IN` queries instead of 2×N sequential single-id lookups,
  /// collapsing a full page's probe from ~200 bg-isolate round trips to 2. The
  /// in-transaction `hasGiftWrap` re-check in the persist path still guards
  /// TOCTOU races, so this is purely a fast-path filter. #5452.
  Future<Set<String>> _alreadyProcessedBatch(Set<String> giftWrapIds) async {
    if (giftWrapIds.isEmpty) return const <String>{};
    final present = <String>{
      ...await _directMessagesDao.giftWrapIdsPresent(giftWrapIds),
    };
    final ledger = _processedGiftWrapsDao;
    if (ledger != null) {
      present.addAll(await ledger.giftWrapIdsPresent(giftWrapIds));
    }
    return present;
  }

  /// Records a terminally-processed gift wrap (or suppressed NIP-04 event) in
  /// the dedup ledger so it is not re-decrypted on a later launch. No-op when
  /// the ledger DAO is absent (older test fixtures). Recorded AFTER the
  /// outcome write so a crash in between only ever costs a benign re-decrypt,
  /// never a lost reaction/deletion. #5452.
  Future<void> _recordProcessedWrap(
    String giftWrapId, {
    String? ownerPubkey,
  }) async {
    final owner = ownerPubkey ?? _ownerPubkey;
    if (owner == null) return;
    await _processedGiftWrapsDao?.record(
      giftWrapId: giftWrapId,
      ownerPubkey: owner,
    );
  }

  /// Single-event gift-wrap entry (live subscription + retry replay): dedup,
  /// decrypt, then persist. The persist body is shared with the batched
  /// history-drain path via [_persistDecryptedGiftWrap]. Callers must already
  /// hold the [_eventLock] (via [_handleIncomingEvent]).
  Future<void> _handleGiftWrapEvent(Event giftWrapEvent) async {
    final gen = _resetGeneration;
    final ownerPubkey = _userPubkey;
    if (ownerPubkey.isEmpty) return;
    final Event? rumorEvent;
    try {
      // Dedup: skip if already processed (message row or ledger). #5452.
      if (await _alreadyProcessed(giftWrapEvent.id)) {
        // Still advance the wire boundary. A duplicate is by definition a
        // wrap we have processed, so its outer stamp belongs in the maximum
        // this boundary tracks, and without this an install that upgraded
        // into the #8209 fix keeps the old eroded window until its next
        // genuinely new message — every wrap already in the window returns
        // here first. Monotonic, so the drain replaying old pages cannot
        // drag it backwards.
        await _syncState?.recordWireSeen(
          ownerPubkey,
          createdAt: giftWrapEvent.createdAt,
        );
        // History drain pass 2 re-routes already-persisted wraps through this
        // handler (preDecrypted miss). Per-wrap debug would fill the 50k
        // capture ring and evict the persist lines that diagnose #7631.
        if (_historyDrain == null) {
          Log.debug(
            'Skipping already-processed gift wrap ${giftWrapEvent.id}',
            category: LogCategory.system,
          );
        }
        return;
      }

      // Decrypt: gift wrap → seal → rumor
      final signer = _signer;
      if (signer == null) return;
      final nostr = Nostr(signer, [], _dummyRelay);
      await nostr.refreshPublicKey();

      // A stop or account switch landed during the awaits above (a
      // multi-hundred-ms RPC for remote signers): bail before _decryptRumor,
      // whose _ensureVerifyIsolate would otherwise start a spawn that only
      // sees post-stop session values — installing a verify worker into the
      // torn-down repository that nothing ever closes (PR #5957 review).
      // The wrap re-arrives via the next session's subscription window /
      // history drain, so nothing is lost.
      if (_disposed || _resetGeneration != gen || _userPubkey != ownerPubkey) {
        return;
      }

      rumorEvent = await _decryptRumor(nostr, giftWrapEvent);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process gift wrap event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      // A THROWING decrypt must queue for retry exactly like a null return.
      // Only the null path reached the queue, so a remote-signer (Keycast RPC)
      // failure that raised — the very case #5202's queue exists for — dropped
      // the wrap permanently with no retry. Skip when the session moved on:
      // Queue only under the immutable owner that began this operation.
      if (_disposed || _resetGeneration != gen || _userPubkey != ownerPubkey) {
        return;
      }
      await _withEventLock(() async {
        if (_disposed ||
            _resetGeneration != gen ||
            _userPubkey != ownerPubkey) {
          return;
        }
        await _persistDecryptedGiftWrap(
          giftWrapEvent,
          null,
          ownerPubkey: ownerPubkey,
        );
      });
      return;
    }

    // A successful remote decrypt can outlive the account that started it.
    // Never enter persistence after teardown or under a replacement identity;
    // relay replay will deliver the wrap to the correct session later.
    if (_disposed || _resetGeneration != gen || _userPubkey != ownerPubkey) {
      return;
    }
    await _withEventLock(() async {
      if (_disposed || _resetGeneration != gen || _userPubkey != ownerPubkey) {
        return;
      }
      await _persistDecryptedGiftWrap(
        giftWrapEvent,
        rumorEvent,
        ownerPubkey: ownerPubkey,
      );
    });
  }

  /// Persists a single (already-decrypted) gift wrap. [rumorEvent] is the
  /// decrypted inner rumor, or `null` when decryption failed (the wrap is
  /// then queued for a later retry). Shared by the single-event path
  /// ([_handleGiftWrapEvent]) and the batched history-drain path. Callers must
  /// hold the [_eventLock]. See #5391.
  Future<void> _persistDecryptedGiftWrap(
    Event giftWrapEvent,
    Event? rumorEvent, {
    required String ownerPubkey,
  }) async {
    try {
      if (rumorEvent == null) {
        // Persist the still-encrypted wrap so a later retry can recover the
        // conversation instead of losing it — flaky remote-signer (Keycast
        // RPC) decryption must not be permanent data loss. See #5202.
        await _pendingGiftWrapsDao?.recordFailedDecrypt(
          giftWrapId: giftWrapEvent.id,
          ownerPubkey: ownerPubkey,
          rawJson: jsonEncode(giftWrapEvent.toJson()),
          createdAt: giftWrapEvent.createdAt,
        );
        Log.debug(
          'Failed to decrypt gift wrap event ${giftWrapEvent.id}; '
          'queued for retry',
          category: LogCategory.system,
        );
        return;
      }
      // The pending row is dropped in the `finally` below, AFTER the
      // writes commit — deliberately not here. Deleting it first is what
      // made a persist failure unrecoverable: the transaction rolls back,
      // no ledger row is written, and the queue row that would have
      // replayed this wrap is already gone, so it survives in no table at
      // all. It also erased the attempt count, so a wrap that kept failing
      // re-inserted at 1 on every pass and [DmHistoryDrainConfig
      // .maxDecryptRetries] could never be reached. See #5202 for the
      // queue itself.
      var persistFailed = false;
      try {
        // Bind to a final local so the non-null type promotes inside the
        // runInTransaction closure below (a nullable parameter would not).
        final rumor = rumorEvent;

        // A NIP-59 rumor is unsigned, so `created_at` is chosen freely by the
        // sender. Keep the message, but clamp the timestamp used for local
        // ordering/cursors so a bad clock cannot blackhole future subscriptions
        // or pin the thread above honest messages forever.
        final clock = DmClock.now();
        final persistedCreatedAt = clock.atMostNow(rumor.createdAt);
        if (rumor.createdAt >
            clock.nowSeconds + DmSyncState.maxFutureSkewSeconds) {
          Log.warning(
            'Clamped DM (kind ${rumor.kind}) from '
            '${pubkeyForLogs(rumor.pubkey)}: rumor '
            'created_at ${rumor.createdAt} is beyond the expected skew of '
            '${DmSyncState.maxFutureSkewSeconds}s (now ${clock.nowSeconds})',
            category: LogCategory.system,
          );
        }

        // NIP-17 spec line 14 explicitly permits kind 7 reactions inside
        // the gift-wrap envelope. Reaction deletions are also wrapped by
        // this feature so the remove path preserves DM privacy. Route both
        // before the DM-only kinds gate below. #4633.
        if (rumor.kind == EventKind.reaction) {
          final outcome = await _reactionsRepository?.persistIncoming(
            rumorEvent: rumor,
            giftWrapId: giftWrapEvent.id,
          );
          // Record only terminal outcomes: a reaction whose target message has
          // not synced is left out so it re-decrypts and lands later. #5452.
          if (outcome == DmWrapOutcome.processed) {
            await _recordProcessedWrap(
              giftWrapEvent.id,
              ownerPubkey: ownerPubkey,
            );
          }
          return;
        }
        if (rumor.kind == EventKind.eventDeletion) {
          final outcome = await _routeWrappedDeletion(
            rumor: rumor,
            giftWrapId: giftWrapEvent.id,
          );
          if (outcome == DmWrapOutcome.processed) {
            await _recordProcessedWrap(
              giftWrapEvent.id,
              ownerPubkey: ownerPubkey,
            );
          }
          return;
        }

        // Cross-device DM read-state marker (#4977). Route only Divine's read
        // marker d-tag to the reconciler before the DM-only kinds gate so it is
        // never rendered as a message, then record it terminally so it is not
        // re-decrypted every launch. Other app-specific self-wraps must remain
        // unrecorded so future/foreign kind-30078 handlers can still process
        // them instead of losing them to the processed-wrap ledger.
        if (rumor.kind == EventKind.appSpecificData) {
          if (_hasReadMarkerDTag(rumor)) {
            await _reconcileReadMarker(rumor);
            await _recordProcessedWrap(
              giftWrapEvent.id,
              ownerPubkey: ownerPubkey,
            );
          }
          return;
        }

        // Accept kind 14 (text) and kind 15 (file). Any other kind is
        // terminally
        // unsupported — record it so it is not re-decrypted on every launch.
        // Note: the ledger survives upgrades, so a future version that adds
        // support for a new kind will not reprocess wraps already recorded
        // here;
        // such a kind would need a one-off backfill. Acceptable vs.
        // re-decrypting
        // every unknown wrap on every launch today. #5452.
        if (!_supportedDmKinds.contains(rumor.kind)) {
          await _recordProcessedWrap(
            giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
          return;
        }

        // Extract conversation participants from pubkey + p tags, then
        // resolve against existing conversations to prevent duplicates
        // from non-compliant clients that add extra p-tags.
        final rawParticipants = _extractParticipants(rumor);
        if (rawParticipants.length < 2) {
          await _recordProcessedWrap(
            giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
          return;
        }

        final participants = await _resolveConversationParticipants(
          rawParticipants,
          rumor.pubkey,
        );

        // Reject self-conversations (all participants are the same pubkey).
        // Defense-in-depth: should not happen after the self-wrap fix above,
        // but guards against any future code path producing degenerate lists.
        if (!containsDistinctPubkeys(participants)) {
          await _recordProcessedWrap(
            giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
          return;
        }

        final conversationId = computeConversationId(participants);

        // Extract common tags
        String? replyToId;
        String? subject;
        String? sendBatchId;
        for (final tag in rumor.tags) {
          if (tag.length >= 2) {
            if (tag[0] == 'e') replyToId = tag[1];
            if (tag[0] == 'subject') subject = tag[1];
            // Stamp the batch id from the sender's OWN self-wrap echo so a
            // group send's local persist / recovery dedups (both owner-scoped
            // via hasMessageWithSendBatchId) against this pre-persisted row
            // instead of inserting a duplicate bubble. Honour the tag only on
            // a self-authored rumor: hasMessageWithSendBatchId is owner-scoped,
            // so accepting a peer-authored 'batch' tag would let a sender
            // suppress the local user's own in-flight group persist. The
            // well-formed-hex check keeps this keyspace disjoint from the
            // legacy (content, createdAt) dedup tuple.
            if (tag[0] == _sendBatchTagKey &&
                rumor.pubkey == ownerPubkey &&
                _isValidSendBatchId(tag[1])) {
              sendBatchId = tag[1];
            }
          }
        }

        // Extract file metadata for kind 15
        final fileMetadata = rumor.kind == EventKind.fileMessage
            ? _extractFileMetadata(rumor)
            : null;

        // Cross-protocol dedup: if a NIP-04 copy of this message was
        // processed first (network reordering), skip the duplicate. Record the
        // wrap so the skipped NIP-17 copy is not re-decrypted every launch.
        // #5452.
        //
        // Only a NIP-04 copy may suppress a peer's rumor: a row that also
        // arrived over NIP-17 is a genuine earlier message (#7324).
        //
        // Our own self-wrap echo is the exception. A group send persists
        // one row
        // but publishes one self-wrap per recipient for the shared rumor. Every
        // echo dedups on the batch token, or the unfiltered window when
        // the send
        // predates it (#6046).
        final isSentByMe = rumor.pubkey == ownerPubkey;
        final isGroup = participants.length > 2;
        final bool isDuplicate;
        if (isSentByMe && sendBatchId != null) {
          isDuplicate = await _directMessagesDao.hasMessageWithSendBatchId(
            batchId: sendBatchId,
            ownerPubkey: ownerPubkey,
          );
        } else if (isSentByMe && isGroup) {
          isDuplicate = await _directMessagesDao.hasMatchingMessage(
            conversationId: conversationId,
            senderPubkey: rumor.pubkey,
            content: rumor.content,
            createdAt: persistedCreatedAt,
            ownerPubkey: ownerPubkey,
            counterpart: DmDedupCounterpart.unconstrained,
          );
        } else {
          // A peer's rumor may only be collapsed onto the ONE NIP-04 twin of
          // this same message, which the claim consumes so a second same-text
          // rumor in the window cannot be collapsed onto it too (#8211).
          isDuplicate = await _directMessagesDao.claimCrossProtocolTwin(
            conversationId: conversationId,
            senderPubkey: rumor.pubkey,
            content: rumor.content,
            createdAt: persistedCreatedAt,
            ownerPubkey: ownerPubkey,
            counterpart: DmDedupCounterpart.nip04Copy,
          );
        }
        if (isDuplicate) {
          // A twin from the PEER is proof they speak NIP-17, and it is the only
          // place that proof ever appears: the rumor is about to be
          // dropped as a
          // duplicate, so without this the evidence is discarded and the thread
          // stays latched to 'nip04' forever. That latch is what makes the
          // legacy dual-send the steady state rather than an edge case — every
          // later pair hits this same early return, so the decision the first
          // arrival race made is never revisited (#8499).
          //
          // `!isSentByMe` is load-bearing on this duplicate branch. The `else`
          // above is reached by a peer's rumor AND by a self-authored 1:1 rumor
          // with no send batch token; clearing here on our own self-wrap would
          // invert *this* path into "clear when *I* speak NIP-17". It does not
          // cover a unique self-authored NIP-17, which is not a twin and still
          // hits the persist upsert's `dmProtocol: 'nip17'` below.
          // Ledger first, unlatch second, and the unlatch can never throw
          // out of
          // here. It is an opportunistic upgrade on evidence we happen to be
          // holding; the dedup bookkeeping below it is what stops this wrap
          // being decrypted again on every redelivery. Ordering them the other
          // way round made a failed unlatch abort `_recordProcessedWrap`, so a
          // transient DB error would have cost a signer round trip per replay,
          // forever. A dropped unlatch costs nothing — the next message
          // from the
          // peer presents the same evidence again.
          await _recordProcessedWrap(
            giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
          if (!isSentByMe) {
            try {
              final cleared = await _conversationsDao.clearNip04ProtocolLatch(
                conversationId,
                ownerPubkey: ownerPubkey,
              );
              if (cleared) {
                Log.info(
                  'Cleared the nip04 protocol latch on conversation '
                  '$conversationId: ${pubkeyForLogs(rumor.pubkey)} sent '
                  'NIP-17, '
                  'so the legacy kind-4 copy is no longer published to them',
                  category: LogCategory.system,
                );
              }
            } on Object catch (e) {
              Log.warning(
                'Could not clear the nip04 protocol latch on conversation '
                '$conversationId: $e — the thread keeps dual-sending until the '
                'next NIP-17 message from the peer',
                category: LogCategory.system,
              );
            }
          }
          Log.debug(
            'Skipping duplicate NIP-17 DM ${rumor.id} in conversation '
            '$conversationId from ${pubkeyForLogs(rumor.pubkey)}: matching '
            'message already '
            'stored',
            category: LogCategory.system,
          );
          return;
        }

        // Persist message + conversation atomically inside a transaction.
        // The inner hasGiftWrap re-check guards against TOCTOU races where
        // a poll and subscription event both pass the outer fast-path check.
        final previewContent = rumor.kind == EventKind.fileMessage
            ? _filePreviewText(fileMetadata?.fileType)
            : rumor.content;

        var inserted = false;
        var skippedByTransactionalGiftWrapDedup = false;
        var suppressedByRemovedConversation = false;
        int? removedAt;
        await _conversationsDao.runInTransaction(() async {
          // Re-check dedup inside transaction (TOCTOU protection). The skip is
          // logged after the transaction below; logging here too would emit one
          // line per skip twice.
          if (await _directMessagesDao.hasGiftWrap(giftWrapEvent.id)) {
            skippedByTransactionalGiftWrapDedup = true;
            return;
          }

          removedAt = await _removedConversationsDao?.removedAtFor(
            conversationId: conversationId,
            ownerPubkey: ownerPubkey,
          );
          if (removedAt != null && persistedCreatedAt <= removedAt!) {
            suppressedByRemovedConversation = true;
            return;
          }

          inserted = await _directMessagesDao.insertMessage(
            id: rumor.id,
            conversationId: conversationId,
            senderPubkey: rumor.pubkey,
            content: rumor.content,
            createdAt: persistedCreatedAt,
            giftWrapId: giftWrapEvent.id,
            messageKind: rumor.kind,
            replyToId: replyToId,
            subject: subject,
            tagsJson: jsonEncode(rumor.tags),
            fileType: fileMetadata?.fileType,
            encryptionAlgorithm: fileMetadata?.encryptionAlgorithm,
            decryptionKey: fileMetadata?.decryptionKey,
            decryptionNonce: fileMetadata?.decryptionNonce,
            fileHash: fileMetadata?.fileHash,
            originalFileHash: fileMetadata?.originalFileHash,
            fileSize: fileMetadata?.fileSize,
            dimensions: fileMetadata?.dimensions,
            blurhash: fileMetadata?.blurhash,
            thumbnailUrl: fileMetadata?.thumbnailUrl,
            ownerPubkey: ownerPubkey,
            sendBatchId: sendBatchId,
          );
          if (!inserted) return;

          final existing = await _conversationsDao.getConversation(
            conversationId,
            ownerPubkey: ownerPubkey,
          );

          await _conversationsDao.upsertConversation(
            id: conversationId,
            participantPubkeys: jsonEncode(participants),
            isGroup: isGroup,
            createdAt: existing?.createdAt ?? persistedCreatedAt,
            lastMessageContent: previewContent,
            lastMessageTimestamp: persistedCreatedAt,
            lastMessageSenderPubkey: rumor.pubkey,
            subject: subject,
            isRead: isSentByMe,
            currentUserHasSent:
                isSentByMe || (existing?.currentUserHasSent ?? false),
            ownerPubkey: ownerPubkey,
            dmProtocol: 'nip17',
          );
          // A newer message reopens a removed conversation: the row is
          // recreated above, while the tombstone is deliberately kept so
          // replayed history stamped at or before the removal stays
          // suppressed. #7804.
        });

        if (skippedByTransactionalGiftWrapDedup) {
          Log.debug(
            'Skipping NIP-17 gift wrap ${giftWrapEvent.id}: already persisted '
            'during transaction',
            category: LogCategory.system,
          );
          return;
        }
        if (suppressedByRemovedConversation) {
          // Terminal: record the wrap so replays skip it before decryption.
          // The tombstone is authoritative for the account's lifetime, so the
          // ledger is not racing a reopening that clears it.
          await _recordProcessedWrap(
            giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
          Log.debug(
            'Suppressed NIP-17 DM ${rumor.id} in removed conversation '
            '$conversationId: createdAt $persistedCreatedAt is at or before '
            'removal at $removedAt',
            category: LogCategory.system,
          );
          return;
        }
        if (!inserted) {
          await _recordProcessedWrap(
            giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
          Log.debug(
            'Skipped duplicate NIP-17 DM ${rumor.id} in conversation '
            '$conversationId: insert was ignored by local dedup constraints',
            category: LogCategory.system,
          );
          return;
        }

        // Advance sync boundaries in BOTH clocks, because they answer two
        // different questions. The rumor timestamp is the honest send time the
        // UI orders by, and its randomized outer wrap must not be used for
        // that. But the relay indexes and filters the outer stamp, so the live
        // subscription's `since:` has to be derived from that one instead —
        // recording only the rumor clock is what made a backdated wrap fall
        // outside the window and never be requested again. See #8209.
        await _syncState?.recordSeen(
          ownerPubkey,
          createdAt: persistedCreatedAt,
        );
        await _syncState?.recordWireSeen(
          ownerPubkey,
          createdAt: giftWrapEvent.createdAt,
        );

        final contentCorrelation = _dmContentCorrelation(
          conversationId: conversationId,
          senderPubkey: rumor.pubkey,
          content: rumor.content,
        );
        Log.debug(
          // Process-local HMAC correlates equal content without exposing it
          // or its length in the support logs that carry this line. See #6522.
          'Persisted NIP-17 DM ${rumor.id} (kind ${rumor.kind}) in '
          'conversation '
          '$conversationId from ${pubkeyForLogs(rumor.pubkey)} '
          'createdAt=$persistedCreatedAt '
          'contentCorrelation=$contentCorrelation',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        persistFailed = true;
        // The wrap decrypted but did not persist, so it is in no table:
        // the transaction rolled back and nothing was ledgered. Put it
        // back on the retry queue rather than dropping it — this is the
        // same durable path a failed decrypt takes, under the same attempt
        // budget. Without this the wrap is lost the moment the live
        // window moves past its outer stamp, with one log line to show
        // for it.
        //
        // NIP-04 deliberately has no equivalent: `_handleNip04Event` has
        // no queue to re-enter, because [PendingGiftWraps] stores raw
        // kind-1059 JSON for `Event.fromJson` + `_decryptRumor` and a
        // kind 4 needs a different replay path. Out of scope here.
        Log.error(
          'Persisting decrypted gift wrap ${giftWrapEvent.id} failed after '
          'the decrypt succeeded; re-queued for retry: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        await _pendingGiftWrapsDao?.recordFailedDecrypt(
          giftWrapId: giftWrapEvent.id,
          ownerPubkey: ownerPubkey,
          rawJson: jsonEncode(giftWrapEvent.toJson()),
          createdAt: giftWrapEvent.createdAt,
        );
      } finally {
        // Every exit that got here without throwing has handled the wrap
        // terminally — persisted, deduped, or recorded in the ledger — so
        // the queue row is stale and goes. A `return` inside the `try`
        // runs this first, which is what keeps parity with the twelve
        // early returns above that relied on the delete happening up top.
        if (!persistFailed) {
          await _pendingGiftWrapsDao?.deletePending(
            giftWrapId: giftWrapEvent.id,
            ownerPubkey: ownerPubkey,
          );
        }
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process gift wrap event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Decrypts a page's gift wraps in chunks on the drain-scoped long-lived
  /// decrypt isolate ([_drainDecryptIsolate]), returning a
  /// `{giftWrapId: rumor}` map of the SUCCESSFUL decrypts only. Each
  /// `DmHistoryDrainConfig.decryptBatchSize`-wrap chunk is one hop fed to the
  /// *same* worker over a port, so the whole backfill pays a single isolate
  /// spawn instead of one per chunk (#5391 review). Wraps that are already
  /// persisted, fail to decrypt, or belong to a remote signer (the isolate is
  /// absent) are missing from the map — the caller routes those through the
  /// unchanged per-event path (which preserves the isolate→main-isolate
  /// fallback and failed-decrypt bookkeeping). Runs OFF the [_eventLock].
  Future<Map<String, Event>> _batchDecryptGiftWraps(List<Event> events) async {
    final isolate = _drainDecryptIsolate;
    if (isolate == null) {
      // Remote signer (Keycast RPC / Amber / NIP-46), or the drain isolate
      // could not spawn: there is no batch worker. Rather than serialize one
      // network decrypt at a time on the _eventLock, decrypt this page with a
      // bounded worker pool OFF the lock — persistence still serializes in the
      // caller. This is the difference between a multi-minute and a few-second
      // drain for remote-signer accounts.
      return _parallelDecryptGiftWraps(events);
    }

    // Only wraps not already persisted, to avoid re-decrypting on resume
    // drains. One batched dedup probe per page instead of 2 queries per wrap;
    // the in-transaction hasGiftWrap re-check still protects races. #5452.
    final giftWraps = [
      for (final event in events)
        if (event.kind == EventKind.giftWrap) event,
    ];
    final processed = await _alreadyProcessedBatch({
      for (final event in giftWraps) event.id,
    });
    final pending = [
      for (final event in giftWraps)
        if (!processed.contains(event.id)) event,
    ];
    if (pending.isEmpty) return const {};

    final decrypted = <String, Event>{};
    for (
      var start = 0;
      start < pending.length;
      start += DmHistoryDrainConfig.decryptBatchSize
    ) {
      if (_disposed) break;
      final end = start + DmHistoryDrainConfig.decryptBatchSize;
      final chunk = pending.sublist(
        start,
        end < pending.length ? end : pending.length,
      );
      try {
        final results = await isolate.decryptBatch([
          for (final event in chunk) event.toJson(),
        ]);
        for (var i = 0; i < chunk.length; i++) {
          final result = results[i];
          if (result.isSuccess) {
            decrypted[chunk[i].id] = Event.fromJson(result.rumor!);
          }
        }
      } on Object catch (e, stackTrace) {
        // Whole-chunk isolate failure: leave these wraps out of the map so
        // they fall back to the per-event decryptor in the caller.
        Log.error(
          'Batch gift-wrap decrypt threw: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
      }
      // WS3: yield an event-loop turn between isolate hops so a large
      // backfill cannot starve frame rendering. See #5391.
      await _yieldToEventLoop();
    }
    return decrypted;
  }

  /// Decrypts a page's gift wraps for a REMOTE signer (Keycast RPC / Amber /
  /// NIP-46) using a bounded worker pool, OFF the [_eventLock].
  ///
  /// Remote signers cannot cross the [compute] isolate boundary, so each wrap
  /// is decrypted by a network round trip to the signer. Doing that one wrap at
  /// a time — the previous behaviour, where every wrap fell through to the
  /// serial per-event path under the lock — serializes hundreds of ~250-400 ms
  /// RPCs into a multi-minute drain. Keeping
  /// [DmHistoryDrainConfig.remoteDecryptConcurrency] decrypts in flight
  /// collapses the wall-clock to roughly 1/N; the Keycast server does not
  /// serialize per-token decrypts, so the concurrency is real.
  ///
  /// When the remote signer is Keycast (a [GiftWrapBatchUnwrapper]), the page
  /// is FIRST run through [_serverBatchUnwrapGiftWraps] — one
  /// `nip17_unwrap_batch` round trip per chunk that unwraps both NIP-59 layers
  /// server-side (#5471). Only the wraps that path leaves behind — an older
  /// keycast without the verb, a transient chunk error, or a per-item failure —
  /// fall back to the bounded worker pool described above.
  ///
  /// Returns a `{giftWrapId: rumor}` map of the SUCCESSFUL decrypts only, with
  /// the same contract as [_batchDecryptGiftWraps]: wraps that are already
  /// persisted, undecryptable, or fail are absent and fall through to the
  /// per-event path in the caller (which preserves failed-decrypt bookkeeping
  /// for the retry queue, see #5202). Only *decryption* is parallelized here —
  /// the caller persists each result serially under the [_eventLock], so
  /// dedup and transaction integrity are unchanged.
  Future<Map<String, Event>> _parallelDecryptGiftWraps(
    List<Event> events,
  ) async {
    final signer = _signer;
    if (signer == null) return const {};

    // Probe the dedup index before paying any network decrypt, so a resume
    // drain over already-persisted history costs DB reads, not RPCs. One
    // batched probe per page instead of 2 queries per wrap; the
    // in-transaction hasGiftWrap re-check in the caller still guards races.
    final giftWraps = [
      for (final event in events)
        if (event.kind == EventKind.giftWrap) event,
    ];
    final processed = await _alreadyProcessedBatch({
      for (final event in giftWraps) event.id,
    });
    final pending = [
      for (final event in giftWraps)
        if (!processed.contains(event.id)) event,
    ];
    if (pending.isEmpty) return const {};
    if (_disposed) return const {};

    final decrypted = <String, Event>{};

    // #5471: when the remote signer is Keycast, unwrap a whole chunk of gift
    // wraps in ONE server round trip (`nip17_unwrap_batch`) instead of two
    // `nip44Decrypt` RPCs per wrap. Wraps the batch cannot handle — an older
    // keycast without the verb, a transient error, or a per-item failure — fall
    // back to the per-wrap pool below, preserving the #5426 behaviour.
    var fallback = pending;
    if (signer case final GiftWrapBatchUnwrapper unwrapper
        when !_batchUnwrapUnsupported) {
      fallback = await _serverBatchUnwrapGiftWraps(
        unwrapper,
        pending,
        decrypted,
      );
    }
    if (fallback.isEmpty || _disposed) return decrypted;

    // Per-wrap fallback pool (#5426): a bounded set of decrypts in flight, each
    // two RPCs (gift wrap -> seal, seal -> rumor). Shares one signer handle
    // with the public key refreshed once up front. Used for non-Keycast remote
    // signers (Amber / NIP-46), an older keycast without the batch verb, or
    // wraps a transient batch error skipped.
    final nostr = Nostr(signer, [], _dummyRelay);
    await nostr.refreshPublicKey();
    await _workerPoolDecrypt(nostr, fallback, decrypted);
    return decrypted;
  }

  /// Per-wrap fallback decrypt pool: keeps
  /// [DmHistoryDrainConfig.remoteDecryptConcurrency] gift-wrap decrypts in
  /// flight, each via the per-wrap [_decryptRumor] path (two RPCs to a remote
  /// signer). Successful rumors land in [decrypted]; failures are left out so
  /// the caller routes them to the per-event path and the failed-decrypt retry
  /// queue. See #5426 / #5202.
  Future<void> _workerPoolDecrypt(
    Nostr nostr,
    List<Event> events,
    Map<String, Event> decrypted,
  ) async {
    var next = 0;

    Future<void> worker() async {
      while (true) {
        if (_disposed) return;
        // Read-then-increment with no await in between, so two workers never
        // claim the same index on a single isolate.
        final index = next;
        if (index >= events.length) return;
        next = index + 1;
        final event = events[index];
        try {
          final rumor = await _decryptRumor(nostr, event);
          if (rumor != null) decrypted[event.id] = rumor;
        } on Object catch (e, stackTrace) {
          // Leave the wrap out of the map so it falls through to the per-event
          // path, which records the failed decrypt for the retry queue. See
          // #5202.
          Log.error(
            'Parallel gift-wrap decrypt threw for ${event.id}: $e',
            category: LogCategory.system,
            error: e,
            stackTrace: stackTrace,
          );
        }
        // Hand back a real event-loop turn between decrypts so the backfill
        // cannot starve frame rendering — a real remote RPC await yields
        // anyway, but a fast/synthetic signer would otherwise drain a whole
        // page in one microtask burst. See #5391.
        await _yieldToEventLoop();
      }
    }

    final workerCount =
        events.length < DmHistoryDrainConfig.remoteDecryptConcurrency
        ? events.length
        : DmHistoryDrainConfig.remoteDecryptConcurrency;
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
  }

  /// #5471: unwraps [pending] gift wraps via the Keycast `nip17_unwrap_batch`
  /// verb in chunks of [DmHistoryDrainConfig.unwrapBatchSize], one server round
  /// trip per chunk. Successful slots are written into [decrypted]; per-item
  /// error slots are left out so they fall through to the per-event path and
  /// the failed-decrypt retry queue (the lenient per-wrap path recovers the
  /// rare sender mismatch the strict server rejects). Returns the wraps that
  /// still need the per-wrap fallback pool: every wrap from the chunk where the
  /// verb turned out to be unsupported onward, plus any chunk a transient error
  /// (e.g. a timeout) skipped.
  Future<List<Event>> _serverBatchUnwrapGiftWraps(
    GiftWrapBatchUnwrapper unwrapper,
    List<Event> pending,
    Map<String, Event> decrypted,
  ) async {
    final fallback = <Event>[];
    for (
      var start = 0;
      start < pending.length;
      start += DmHistoryDrainConfig.unwrapBatchSize
    ) {
      if (_disposed) break;
      final end = start + DmHistoryDrainConfig.unwrapBatchSize;
      final chunk = pending.sublist(
        start,
        end < pending.length ? end : pending.length,
      );

      // The verb was found missing on an earlier chunk: don't keep probing it.
      if (_batchUnwrapUnsupported) {
        fallback.addAll(chunk);
        continue;
      }

      List<GiftWrapUnwrapSlot>? slots;
      try {
        slots = await unwrapper.nip17UnwrapBatch([
          for (final event in chunk) event.toJson(),
        ]);
      } on Object catch (e, stackTrace) {
        // Transient failure (e.g. a TimeoutException): route this chunk to the
        // per-wrap pool but keep trying the verb for later chunks.
        Log.error(
          'Batch gift-wrap unwrap chunk threw: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        fallback.addAll(chunk);
        await _yieldToEventLoop();
        continue;
      }

      if (slots == null) {
        // Older keycast without the verb: latch off and fall the rest back.
        _batchUnwrapUnsupported = true;
        fallback.addAll(chunk);
        continue;
      }

      for (var i = 0; i < chunk.length; i++) {
        final slot = i < slots.length ? slots[i] : null;
        if (slot != null && slot.isSuccess) {
          final rumor = _rumorFromSlot(slot);
          if (rumor != null) decrypted[chunk[i].id] = rumor;
        }
        // Error or missing slots are intentionally omitted: the caller routes
        // them to the per-event path, which records the failed decrypt for the
        // retry queue and recovers a sender mismatch via the lenient per-wrap
        // path. See #5202.
      }

      // Yield between chunks so a large backfill cannot starve frame
      // rendering. See #5391.
      await _yieldToEventLoop();
    }
    return fallback;
  }

  /// Builds the kind:14 rumor [Event] from a successful unwrap [slot],
  /// attributing it to the server-authenticated [GiftWrapUnwrapSlot.sender].
  /// The server already verified both the gift-wrap and seal signatures and
  /// rejects a rumor whose author disagrees with the seal signer (#5471), so
  /// the client neither re-verifies nor re-checks the sender.
  ///
  /// Reads ONLY the fields it keeps — `kind`, `tags`, `content`, `created_at` —
  /// straight from [GiftWrapUnwrapSlot.rumor], NOT via [Event.fromJson] (which
  /// mandates `id` and `pubkey`). A NIP-59 rumor is unsigned, so its `id` is
  /// derivable and a sender may legitimately omit it; keycast forwards the
  /// rumor verbatim, so depending on those discarded fields would make such a
  /// slot throw → fall silently to the per-wrap pool, quietly degrading the
  /// batch verb to a no-op on prod while CI (which always injects `id`/`pubkey`)
  /// stayed green.
  ///
  /// The id is recomputed by the constructor from [GiftWrapUnwrapSlot.sender] —
  /// always the canonical NIP-01 id for the authenticated sender, the same
  /// unconditional recompute [GiftWrapUtil.getRumorEvent] performs locally.
  /// For a well-formed sender (every Divine client embeds the canonical id) it
  /// equals the claimed id, so there is no observable divergence; for a
  /// non-canonical claimed id the recompute is the more correct, interoperable
  /// choice (the DB primary key is the rumor id).
  Event? _rumorFromSlot(GiftWrapUnwrapSlot slot) {
    try {
      final rumor = slot.rumor!;
      final tags = (rumor['tags'] as List<dynamic>)
          .map((tag) => (tag as List<dynamic>).map((e) => e as String).toList())
          .toList();
      return Event(
        slot.sender!,
        rumor['kind'] as int,
        tags,
        rumor['content'] as String,
        createdAt: rumor['created_at'] as int,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to build rumor from unwrap slot: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Cooperative-scheduling yield (NOT UI timing): a zero-duration delay is a
  /// real event-loop turn that lets frame rendering run between drain steps;
  /// a microtask (`await null`) would not. dm_repository is a pure-Dart
  /// package, so SchedulerBinding is unavailable here. See #5391.
  Future<void> _yieldToEventLoop() => Future<void>.delayed(Duration.zero);

  /// Yields to the event loop every [DmHistoryDrainConfig.drainYieldInterval]
  /// events in a serial backfill loop ([index] is the 0-based position), so a
  /// large history drain cannot starve frame rendering. See #5391.
  Future<void> _maybeYieldDuringDrain(int index) async {
    if ((index + 1) % DmHistoryDrainConfig.drainYieldInterval == 0) {
      await _yieldToEventLoop();
    }
  }

  /// Decrypts a single gift-wrap rumor, routing through a [compute]
  /// isolate for local signers that can safely expose their private key
  /// bytes, and falling back to the injected [_rumorDecryptor] on the
  /// main isolate for remote signers (Amber, Keycast RPC, NIP-46) and
  /// test-injected decryptors.
  ///
  /// This single-event path serves the live subscription and the retry
  /// replay; the high-volume history drain instead batches many wraps per hop
  /// on a long-lived isolate via [_batchDecryptGiftWraps]. It intentionally
  /// stays on per-event [compute] (not the long-lived worker): it fires
  /// sporadically across the whole session, so a persistent worker here would
  /// hold the private key resident session-long for no spawn-cost win. See
  /// #5391.
  Future<Event?> _decryptRumor(Nostr nostr, Event giftWrapEvent) async {
    final signer = _signer;
    if (signer is IsolateDecryptSigner && signer.canDecryptInIsolate) {
      try {
        final hex = signer.withPrivateKeyHex((k) => k);
        final results = await compute(
          decryptGiftWrapBatch,
          DecryptBatchRequest(
            events: [giftWrapEvent.toJson()],
            privateKeyHex: hex,
          ),
        );
        final result = results.single;
        if (result.isSuccess) {
          return Event.fromJson(result.rumor!);
        }
        Log.debug(
          'Isolate decrypt returned failure for ${giftWrapEvent.id}: '
          '${result.error}; falling back to main-isolate decryptor',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Isolate decrypt threw for ${giftWrapEvent.id}: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Fall through to main-isolate decryptor.
      }
    }
    // Route the production decryptor's id + Schnorr verification through the
    // shared key-less verify isolate so the CPU-bound work leaves the main
    // isolate — spawned lazily here on the first wrap, since live-subscription
    // and retry wraps arrive outside a history drain too (two pure-Dart
    // Schnorr verifies per wrap were ~47% of main-isolate CPU in on-device
    // profiling of a live DM burst). Only GiftWrapUtil.getRumorEvent accepts
    // a verifier; a test-injected decryptor is used unchanged. If the isolate
    // is torn down mid-flight (account switch) verifyPart throws StateError.
    // The parallel-decrypt drain worker falls through to the per-event path,
    // and the live _handleGiftWrapEvent path records the failed decrypt for
    // retry as long as the session generation is still current.
    // See #5424.
    if (identical(_rumorDecryptor, GiftWrapUtil.getRumorEvent)) {
      final verifyWorker = await _ensureVerifyIsolate();
      if (verifyWorker != null) {
        return GiftWrapUtil.getRumorEvent(
          nostr,
          giftWrapEvent,
          verifyPart: verifyWorker.verifyPart,
        );
      }
    }
    return _rumorDecryptor(nostr, giftWrapEvent);
  }

  Future<void> _handleNip04Event(Event nip04Event) async {
    final ownerPubkey = _userPubkey;
    try {
      // Dedup: use event ID as giftWrapId for the unique index. The
      // processed-wraps ledger also carries NIP-04 event ids that were
      // suppressed by a removed-conversation tombstone, so replays skip
      // decryption entirely — matching the terminal NIP-17 behavior. #7804.
      final dedupHit = await _nip04DedupHit(
        nip04Event.id,
        ownerPubkey: ownerPubkey,
      );
      if (dedupHit != _Nip04DedupHit.none) {
        if (dedupHit == _Nip04DedupHit.thisAccount) {
          // Advance the wire boundary for the same reason the gift-wrap dedup
          // path does. A kind 4 is its own envelope, so the stamp the relay
          // filtered to deliver this replay is the event's own `created_at`.
          await _syncState?.recordWireSeen(
            ownerPubkey,
            createdAt: nip04Event.createdAt,
          );
        } else {
          // A different local account processed this kind 4 — its id is shared
          // by both ends, unlike a gift wrap's. This account never stored the
          // message, so moving its boundary past the event would raise the
          // floor of every future window over a message it does not have, and
          // the boundary only ever rises. See #8209.
          // A drain deliberately re-requests this event while its cursor stays
          // above it. Logging every replay would fill the capture ring and
          // evict the persist diagnostics the warning is meant to support.
          if (_historyDrain == null) {
            Log.warning(
              'Skipping kind-4 ${nip04Event.id} for '
              '${pubkeyForLogs(ownerPubkey)}: another local account processed '
              'it, so this account is not advancing its sync boundary past a '
              'message it never stored',
              category: LogCategory.system,
            );
          }
        }
        if (_historyDrain == null) {
          Log.debug(
            'Skipping already-processed NIP-04 event ${nip04Event.id}',
            category: LogCategory.system,
          );
        }
        return;
      }

      // A kind-4's `created_at` is signed, but by its own author — nothing
      // binds it to real time. Bound it once here, before any store sees it,
      // the same way the NIP-17 rumor path does (#7343): the conversation
      // upsert only follows the newest timestamp, so a future-dated value pins
      // the thread to the top and stops its unread badge from ever flipping
      // back. Every use below reads this local, never the raw event, so a
      // later write site cannot reintroduce the gap. Placed after the replay
      // check so a replayed event does not re-log the warning. #8001.
      final clock = DmClock.now();
      final persistedCreatedAt = clock.atMostNow(nip04Event.createdAt);
      if (nip04Event.createdAt >
          clock.nowSeconds + DmSyncState.maxFutureSkewSeconds) {
        Log.warning(
          'Clamped DM (kind ${EventKind.directMessage}) from '
          '${pubkeyForLogs(nip04Event.pubkey)}: event created_at '
          '${nip04Event.createdAt} is '
          'beyond the expected skew of ${DmSyncState.maxFutureSkewSeconds}s '
          '(now ${clock.nowSeconds})',
          category: LogCategory.system,
        );
      }

      // Extract the recipient and optional reply target from their NIP-04
      // wire tags. Preserve only the first value for each tag type.
      String? recipientPubkey;
      String? replyToId;
      for (final tag in nip04Event.tags) {
        if (tag.length < 2) continue;
        if (tag[0] == 'p') recipientPubkey ??= tag[1];
        if (tag[0] == 'e') replyToId ??= tag[1];
      }
      // A missing recipient is rejected before decryption, so recording it in
      // the processed ledger would not avoid cryptographic work on replay.
      if (recipientPubkey == null) return;

      // Determine sender and the other party's pubkey for decryption
      final senderPubkey = nip04Event.pubkey;
      final isSentByMe = senderPubkey == _userPubkey;
      final peerPubkey = isSentByMe ? recipientPubkey : senderPubkey;

      // Decrypt using injected decryptor or signer fallback
      final signer = _signer;
      // Keep missing-decryptor events retryable: signer availability can
      // change without the relay event changing.
      if (signer == null && _nip04Decryptor == null) return;
      final decryptor =
          _nip04Decryptor ??
          (String pubkey, String ciphertext) =>
              signer!.decrypt(pubkey, ciphertext);
      final plaintext = await decryptor(peerPubkey, nip04Event.content);
      if (plaintext == null) {
        // Keep failed decryptions retryable; a later attempt may succeed.
        Log.debug(
          'Failed to decrypt NIP-04 event ${nip04Event.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Build participants and conversation ID
      final participants = [senderPubkey, recipientPubkey]..sort();
      final conversationId = computeConversationId(participants);

      // Cross-protocol dedup: when a Divine user sends a message, the
      // dual-send fires both NIP-17 and NIP-04 copies. The receiver (also
      // Divine) will process the NIP-17 first, then see the NIP-04 copy.
      // Since the two events have different IDs, hasGiftWrap won't catch it.
      // Match on sender+content within a narrow createdAt window because the
      // NIP-17 rumor and NIP-04 event may have slightly different timestamps.
      // The peer branch CLAIMS that twin, so one stored rumor can absorb only
      // the one kind-4 it was dual-sent with (#8211).
      //
      // Only the NIP-17 copy may suppress a PEER's event. Another NIP-04 row
      // with the same text is a genuine earlier message — the mirror of #7324
      // on this side of the dual-send.
      //
      // Our own replayed kind-4 is the exception, and takes no arrival-shape
      // filter. It matches the user's own persisted send rather than a
      // cross-protocol twin, and that send may carry either shape: every
      // NIP-17 send path before #2654 wrote the gift-wrap id into BOTH
      // columns, so a row from that window reads as NIP-04 and would be
      // missed by nip17Copy — inserting a second bubble for a message the
      // user already sent (#8211).
      final isDuplicate = isSentByMe
          ? await _directMessagesDao.hasMatchingMessage(
              conversationId: conversationId,
              senderPubkey: senderPubkey,
              content: plaintext,
              createdAt: persistedCreatedAt,
              ownerPubkey: _userPubkey,
              counterpart: DmDedupCounterpart.unconstrained,
            )
          : await _directMessagesDao.claimCrossProtocolTwin(
              conversationId: conversationId,
              senderPubkey: senderPubkey,
              content: plaintext,
              createdAt: persistedCreatedAt,
              ownerPubkey: _userPubkey,
              counterpart: DmDedupCounterpart.nip17Copy,
            );
      if (isDuplicate) {
        // Burn the suppressed event in the ledger, exactly as the NIP-17 side
        // does. Without it this decision is never remembered: the live
        // subscription's two-day `since` overlap re-delivers the same kind-4
        // on every launch, and each replay pays a full remote-signer
        // `nip04_decrypt` round trip to reach the same answer (#8211).
        await _recordProcessedWrap(nip04Event.id, ownerPubkey: _userPubkey);
        Log.debug(
          'Skipping NIP-04 duplicate (NIP-17 copy already stored) '
          '${nip04Event.id}',
          category: LogCategory.system,
        );
        return;
      }

      // Persist message + conversation atomically inside a transaction.
      var inserted = false;
      var skippedByTransactionalGiftWrapDedup = false;
      var suppressedByRemovedConversation = false;
      int? removedAt;
      await _conversationsDao.runInTransaction(() async {
        // Snapshot the owner for the whole transaction: an account switch
        // mid-flight must not mix one account's reads with another's writes.
        final ownerPubkey = _userPubkey;
        // Re-check dedup inside transaction (TOCTOU protection). The skip is
        // logged after the transaction below; logging here too would emit one
        // line per skip twice.
        if (await _directMessagesDao.hasGiftWrap(nip04Event.id)) {
          skippedByTransactionalGiftWrapDedup = true;
          return;
        }

        removedAt = await _removedConversationsDao?.removedAtFor(
          conversationId: conversationId,
          ownerPubkey: ownerPubkey,
        );
        if (removedAt != null && persistedCreatedAt <= removedAt!) {
          suppressedByRemovedConversation = true;
          return;
        }

        inserted = await _directMessagesDao.insertMessage(
          id: nip04Event.id,
          conversationId: conversationId,
          senderPubkey: senderPubkey,
          content: plaintext,
          createdAt: persistedCreatedAt,
          giftWrapId: nip04Event.id,
          messageKind: EventKind.directMessage,
          replyToId: replyToId,
          ownerPubkey: ownerPubkey,
        );
        if (!inserted) return;

        final existing = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: ownerPubkey,
        );

        await _conversationsDao.upsertConversation(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: false,
          createdAt: existing?.createdAt ?? persistedCreatedAt,
          lastMessageContent: plaintext,
          lastMessageTimestamp: persistedCreatedAt,
          lastMessageSenderPubkey: senderPubkey,
          isRead: isSentByMe,
          currentUserHasSent:
              isSentByMe || (existing?.currentUserHasSent ?? false),
          ownerPubkey: ownerPubkey,
          dmProtocol: existing?.dmProtocol ?? 'nip04',
        );
        // A newer message reopens a removed conversation: the row is
        // recreated above, while the tombstone is deliberately kept so
        // replayed history stamped at or before the removal stays
        // suppressed. #7804.
      });

      if (skippedByTransactionalGiftWrapDedup) {
        Log.debug(
          'Skipping NIP-04 event ${nip04Event.id}: already persisted during '
          'transaction',
          category: LogCategory.system,
        );
        return;
      }
      if (suppressedByRemovedConversation) {
        // Terminal: record the event id in the processed-wraps ledger so
        // replays skip it before decryption. The tombstone is authoritative
        // for the account's lifetime, so the ledger is not racing a
        // reopening that clears it.
        await _recordProcessedWrap(nip04Event.id);
        Log.debug(
          'Suppressed NIP-04 DM ${nip04Event.id} in removed conversation '
          '$conversationId: createdAt $persistedCreatedAt is at or '
          'before removal at $removedAt',
          category: LogCategory.system,
        );
        return;
      }
      if (!inserted) {
        // Terminal: local uniqueness constraints already represent this
        // event in the message store. Record it even though hasGiftWrap will
        // normally catch the same row, preserving the terminal outcome if
        // the conflicting constraint was the message id instead.
        await _recordProcessedWrap(nip04Event.id);
        Log.debug(
          'Skipped duplicate NIP-04 event ${nip04Event.id}: insert was '
          'ignored by local dedup constraints',
          category: LogCategory.system,
        );
        return;
      }

      // NIP-04 created_at values are not randomized (unlike NIP-17 gift
      // wraps), so this bounded timestamp is a real send time and safe to
      // record as a cursor. A kind 4 is its own envelope — the stamp the
      // relay filters and the stamp the UI orders by are the same value — so
      // it advances both boundaries. The live subscription's `since:` covers
      // kinds [1059, 4, 5] with one filter, so the wire boundary has to track
      // whichever kind carried the newest wire stamp. See #8209.
      // Scoped to the delivering account, not whichever is current after the
      // decrypt and transaction return: this handler has no generation guard
      // to abandon on, and a switch inside that window would import this
      // stamp into the next account's maximum, narrowing its `since:`.
      await _syncState?.recordSeen(ownerPubkey, createdAt: persistedCreatedAt);
      await _syncState?.recordWireSeen(
        ownerPubkey,
        createdAt: nip04Event.createdAt,
      );

      Log.debug(
        'Persisted NIP-04 DM ${nip04Event.id} '
        '(kind ${EventKind.directMessage}) in conversation '
        '$conversationId from ${pubkeyForLogs(senderPubkey)} '
        'createdAt=$persistedCreatedAt',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to process NIP-04 event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Send - Text (Kind 14)
  // -------------------------------------------------------------------------

  /// Resolves [pubkey]'s NIP-17 DM inbox relays and reports whether the lookup
  /// found an inbox, conclusively found none, or could not be completed.
  ///
  /// The returned relays are the recipient's preferred gift-wrap targets, or
  /// `null` when the caller must fall back to the default relay pool. The state
  /// preserves whether that fallback means the recipient advertised no inbox
  /// or the lookup was unreadable, because those cases route identically but
  /// carry different delivery evidence (#7317).
  ///
  /// The list is admitted on remote-supplied terms and capped at
  /// [RelayListCaps.dmInbox]: each entry becomes an outbound connection from
  /// this device carrying the gift wrap, so a counterparty decides neither
  /// how many hosts we dial nor whether any of them sit on the sender's own
  /// network (#6585).
  ///
  /// The read is deliberately non-authoritative: it runs on every send,
  /// degrades to the default pool whether the list is absent or unreadable,
  /// and overwrites nothing — so it keeps the cache and the first answer it
  /// gets rather than waiting for full relay settlement (#8212).
  ///
  /// Callers that route a gift wrap need the relays; callers that also report
  /// delivery need the reason. A `null` list from [DmInboxResolution.absent]
  /// and from [DmInboxResolution.unreadable] send to the same place, but only
  /// the first means the default pool is where the recipient reads — so only
  /// the first may be scored as delivered (#7317).
  Future<DmInboxLookup> resolveDmInboxRelaysDetailed(String pubkey) async {
    final resolved = await _queryOwnDmInbox(
      pubkey,
      requireAuthoritative: false,
    );
    return (
      relays: resolved.relays,
      state: switch (resolved.state) {
        _OwnDmInboxState.found => DmInboxResolution.found,
        _OwnDmInboxState.absent => DmInboxResolution.absent,
        _OwnDmInboxState.failed => DmInboxResolution.unreadable,
      },
    );
  }

  /// End-to-end bound on one inbox resolution.
  ///
  /// [_dmInboxQueryTimeout] bounds the relay read; this bounds the whole
  /// resolution. The distinction matters because resolution runs OUTSIDE the
  /// publish backstop, and `OutgoingDmRetryService.interruptedMinAge` budgets
  /// a fixed margin for it — so any segment that escapes the read's own bound
  /// silently erodes that margin. On device the resolution took 51s on a real
  /// send while the capped publish took 10ms (#7091).
  ///
  /// Mutable only so a test can shorten it; nothing in the app writes it.
  @visibleForTesting
  static Duration inboxResolutionBudget = DmSendBudget.inboxResolution;

  /// Filters and bounds the relay URLs advertised in a kind-10050.
  ///
  /// A relay list is untrusted input and nothing in the protocol bounds its
  /// length, so the client bounds it. When [source] is
  /// [_DmRelayListSource.remote] the URLs came from the person being messaged,
  /// and each one becomes an outbound connection from this device carrying
  /// the gift wrap — so private, loopback and link-local targets are refused
  /// on top of the usual scheme rule. Our own list keeps the loopback
  /// allowance the local Docker stack needs.
  ///
  /// The cap is well above NIP-17's own "keep it to 1-3 relays" guidance:
  /// the point is to turn unbounded into a small constant, not to be tight,
  /// because truncating a real user silently costs them reachability.
  List<String> _admitDmRelays(
    Iterable<String> urls,
    String pubkey,
    _DmRelayListSource source,
  ) {
    if (source == _DmRelayListSource.selfAuthored) {
      final admitted = <String>{};
      for (final url in urls) {
        if (isRelayUrlAllowed(url)) {
          admitted.add(url);
          continue;
        }
        // Their own list, so a rejection is a typo they can fix — say so
        // rather than dropping the entry the way the remote branch does.
        Log.warning(
          'Ignoring unusable relay in own kind-10050: $url',
          category: LogCategory.system,
        );
      }
      if (admitted.length <= RelayListCaps.dmInbox) return admitted.toList();
      Log.warning(
        'Own kind-10050 lists ${admitted.length} relays; using the first '
        '${RelayListCaps.dmInbox}',
        category: LogCategory.system,
      );
      return admitted.take(RelayListCaps.dmInbox).toList();
    }
    return admitRemoteSuppliedRelays(
      urls,
      cap: RelayListCaps.dmInbox,
      onRejected: (url) => Log.warning(
        'Refusing DM inbox relay advertised by ${pubkeyForLogs(pubkey)}: $url',
        category: LogCategory.system,
      ),
      onTruncated: (kept, total) => Log.warning(
        'kind-10050 for ${pubkeyForLogs(pubkey)} lists $total relays; routing '
        'to the first '
        '$kept',
        category: LogCategory.system,
      ),
    );
  }

  /// Queries [pubkey]'s kind-10050 DM inbox relay list and reports a
  /// found / absent / failed outcome (#4974).
  ///
  /// Absent and failed both route through the default pool, but anything that
  /// reports delivery or replaces the list it read must tell them apart: see
  /// [resolveDmInboxRelaysDetailed] (#7317) and [ensureDmRelayListPublished]
  /// (#8212) respectively.
  ///
  /// [requireAuthoritative] is what makes `absent` trustworthy enough to
  /// publish over. RC3 REPLACES whatever the user advertises, so it may only
  /// act on an answer the relays actually gave: `useCache: false` stops a
  /// stale local row standing in for a relay answer, and
  /// `requireAllRelaysSettled: true` turns a fan-out nobody took and a REQ a
  /// relay refused with `CLOSED` into `timedOut` rather than a prompt empty
  /// list. Without it `queryEvents` reports every one of those as an ordinary
  /// empty result, `absent` swallows them, and the publish guard below can
  /// never fire — which is how a transient read replaced a real list (#8212).
  ///
  /// Resolving a COUNTERPARTY's inbox passes `false`: it runs on every send,
  /// degrades to the default pool on either outcome, and overwrites nothing,
  /// so it keeps the cache and the first answer it gets.
  Future<({_OwnDmInboxState state, List<String>? relays})> _queryOwnDmInbox(
    String pubkey, {
    required bool requireAuthoritative,
    // Defaults to the strict reading so a call site added later fails closed.
    // Every path here except the signed-in user's own inbox is resolving
    // somebody else's list.
    _DmRelayListSource source = _DmRelayListSource.remote,
  }) async {
    try {
      final filter = [
        nostr_filter.Filter(
          authors: [pubkey],
          kinds: [EventKind.dmRelaysList],
          limit: 1,
        ),
      ];

      // A recipient lookup has two independent legs. The pool leg retains the
      // reconnect preflight that a temp relay used to suppress (#8550), while
      // the lookup-only leg dials the small indexer set in parallel. A cold or
      // dead indexer is capped independently, so it cannot consume the pool's
      // five-second budget. Both must settle before an empty answer means
      // `absent`; if either is incomplete the send stays pending and retries.
      //
      // Own-inbox reads deliberately keep the existing single pool-only leg.
      // The fast read is in front of the receiving subscription, while the
      // authoritative read protects publication (#8212); widening receipt is
      // a separate asynchronous concern and must not add a cold connection to
      // either synchronous path.
      final queryFutures = [
        _nostrClient.queryEventsDetailed(
          filter,
          useCache: !requireAuthoritative,
          requireAllRelaysSettled:
              requireAuthoritative || source == _DmRelayListSource.remote,
          timeout: requireAuthoritative
              ? _ownDmInboxAuthoritativeTimeout
              : _dmInboxQueryTimeout,
        ),
        if (source == _DmRelayListSource.remote &&
            _dmInboxLookupRelays.isNotEmpty)
          _nostrClient.queryEventsDetailed(
            filter,
            useCache: false,
            tempRelays: _dmInboxLookupRelays,
            requireAllRelaysSettled: true,
            timeout: _dmInboxDiscoveryQueryTimeout,
          ),
      ];
      final results = await Future.wait(queryFutures).timeout(
        inboxResolutionBudget,
      );
      final events = [for (final result in results) ...result.events];
      // Computed here but applied ONLY at the two exits below where nothing
      // matching came back. A read that DID return the list stays `found` even
      // when some relay never settled: the list is in hand, and RC3's job is
      // not to publish over it. Checking the flags before `events` — as the
      // obvious form of this fix does — would discard a real answer from a
      // relay that settled before another relay timed out.
      final _OwnDmInboxState absentOrFailed;
      String? inconclusiveReason;
      // NOT gated on [requireAuthoritative], so the send path can tell an
      // unreadable inbox from an absent one at no extra round trip and no
      // settle wait — #8220's decision to keep the strict read off the send
      // path is untouched (#7317).
      //
      // But the two modes do NOT produce the same flags, and treating a fast
      // read's `absent` as conclusive is a real defect rather than a
      // conservative approximation. `Nostr.queryEventsDetailed` composes
      // `timedOut` with `requireAllRelaysSettled` in the expression itself,
      // and more importantly the two modes complete at different moments: a
      // relay that stays connected and never sends a terminal frame is skipped
      // after the settle window for a fast caller, which still reports
      // `timedOut: false`. So a silent relay reaches here as an ordinary empty
      // answer and is classified `absent`. Only a full-settlement caller sees
      // that as `failed`. Callers that merely route to the default pool can
      // live with the guess; callers that latch something permanent must make
      // their own strict read — see [_drainOwnInboxRelays].
      final noRelayAnswered = results.any((result) => result.noRelays);
      final didNotSettle = results.any((result) => result.timedOut);
      if (noRelayAnswered || didNotSettle) {
        absentOrFailed = _OwnDmInboxState.failed;
        // `noRelays` first: an offline device sets both flags, and reporting
        // that as a timeout misreads it.
        inconclusiveReason = noRelayAnswered
            ? 'no relay took the REQ'
            : 'not every relay settled';
      } else {
        absentOrFailed = _OwnDmInboxState.absent;
      }

      // Both callers reach this, and they act on it differently, so the line
      // has to say which one is speaking: RC3 is about to replace the list it
      // read, the send path is about to route a gift wrap by it.
      void logInconclusiveRead() {
        final reason = inconclusiveReason;
        if (reason == null) return;
        Log.warning(
          requireAuthoritative
              ? 'Own kind-10050 lookup for ${pubkeyForLogs(pubkey)} was '
                    'inconclusive ($reason) — not publishing over a list we '
                    'could not read; will retry'
              : 'Recipient kind-10050 lookup for ${pubkeyForLogs(pubkey)} was '
                    'inconclusive ($reason) — routing to the default pool, and '
                    'NOT scoring the publish as delivered (#7317)',
          category: LogCategory.system,
        );
      }

      if (events.isEmpty) {
        logInconclusiveRead();
        return (state: absentOrFailed, relays: null);
      }
      final matchingEvents = [
        for (final event in events)
          if (event.kind == EventKind.dmRelaysList && event.pubkey == pubkey)
            event,
      ];
      if (matchingEvents.isEmpty) {
        Log.warning(
          'Ignoring off-filter DM inbox relay response for '
          '${pubkeyForLogs(pubkey)}',
          category: LogCategory.system,
        );
        logInconclusiveRead();
        return (state: absentOrFailed, relays: null);
      }
      // Newest wins for a replaceable event served from multiple relays.
      matchingEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Accept both `relay` (the kind-10050 spec tag) and `r` tags. The
      // whole point of #4974 is reading a 10050 a user advertised from
      // ANOTHER client, and some clients write `r` tags; within a
      // kind-10050 event both unambiguously denote DM inbox relays. Matches
      // divine-web's resolveDmReadRelays. Shared with the send path via
      // resolveDmInboxRelaysDetailed, so it also widens recipient resolution
      // there.
      final relays = _admitDmRelays(
        [
          for (final tag in matchingEvents.first.tags)
            if (tag.length >= 2 &&
                (tag[0] == 'relay' || tag[0] == 'r') &&
                tag[1].isNotEmpty)
              tag[1],
        ],
        pubkey,
        source,
      );
      return relays.isEmpty
          ? (state: _OwnDmInboxState.absent, relays: null)
          : (state: _OwnDmInboxState.found, relays: relays);
    } on TimeoutException {
      // Deliberately `failed`, never `absent`. NIP-17 says an absent kind-10050
      // means the user "is not ready to receive messages"; a read we abandoned
      // says nothing about them. Collapsing the two is #7317, and routing a
      // new timeout into `absent` would make that defect more reachable.
      // The detailed result preserves that distinction for every caller.
      Log.warning(
        'DM inbox resolution for ${pubkeyForLogs(pubkey)} exceeded '
        '${inboxResolutionBudget.inMilliseconds}ms; treating as unread',
        category: LogCategory.system,
      );
      return (state: _OwnDmInboxState.failed, relays: null);
    } on Object catch (e) {
      Log.warning(
        'Failed to resolve DM inbox relays for ${pubkeyForLogs(pubkey)}: $e',
        category: LogCategory.system,
      );
      return (state: _OwnDmInboxState.failed, relays: null);
    }
  }

  /// Publishes a minimal NIP-17 kind-10050 DM inbox relay list for the
  /// current user when they don't already advertise one, so compliant
  /// senders deliver gift-wrapped DMs to the relay where divine receives
  /// them (#4974, #7336).
  ///
  /// Without this, NIP-17 §Publishing makes a divine account undeliverable to
  /// any spec-following sender: "If such a list is not found that indicates
  /// the user is not ready to receive messages and clients shouldn't try."
  /// Absence is a positive signal of unreadiness, not "unknown, try the
  /// defaults" — and the sender sees nothing worth surfacing, so the divine
  /// user never learns a message was withheld.
  ///
  /// Published to [_dmInboxRelayUrl] plus [_dmInboxDiscoveryRelays]. The
  /// advertised relay and [_dmInboxTaggedRelays] are tagged as DM inboxes;
  /// discovery-only relays receive the event but are not advertised.
  ///
  /// Publish-when-absent: a kind-10050 the user advertised from any client is
  /// left untouched. The own-inbox lookup distinguishes `found` / `absent` /
  /// `failed`, so a transient relay failure (`failed`) NEVER triggers a
  /// publish that could overwrite a real list divine simply couldn't fetch —
  /// it retries next login.
  ///
  /// The lookup is its OWN authoritative read, not the shared session memo.
  /// The memo is tuned for the live read — cached, and satisfied by the first
  /// relay that answers — which is right for a caller that falls back to the
  /// default pool but not for one about to replace what it read. Sharing it
  /// was what made the guard above unreachable (#8212). The extra query is
  /// bounded: this method returns early once `dmRelayListPublished` is set, so
  /// it runs at most once per (device, pubkey), and it is never awaited by
  /// login. Idempotent per (device, pubkey) via
  /// `DmSyncState.dmRelayListPublished`, with the flag set ONLY once
  /// [_dmInboxRelayUrl] itself confirms `OK`. A rejection there, or a
  /// slow/failed signer, leaves the flag unset and the next login retries —
  /// the publish never blocks login and self-heals.
  ///
  /// No-op when uninitialized, when no signer / sync state is wired, or when
  /// no valid advertised relay URL is configured.
  Future<void> ensureDmRelayListPublished() async {
    if (!isInitialized) return;
    final syncState = _syncState;
    final signer = _signer;
    final relayUrl = _dmInboxRelayUrl;
    if (syncState == null || signer == null) return;
    if (relayUrl == null || !isRelayUrlAllowed(relayUrl)) return;
    final pubkey = _userPubkey;
    // Session-identity token: bail after any await if an account switch /
    // logout (or other teardown) bumped it while we were in flight.
    final gen = _resetGeneration;
    try {
      if (syncState.dmRelayListPublished(pubkey)) return;

      // Its own authoritative read, NOT the shared session memo: this is the
      // one caller that replaces what it read. See #8212.
      final resolution = await _queryOwnDmInbox(
        pubkey,
        requireAuthoritative: true,
        source: _DmRelayListSource.selfAuthored,
      );
      if (_disposed || _resetGeneration != gen) return;
      if (resolution.state == _OwnDmInboxState.found) {
        // Already advertising an inbox — never overwrite a richer list.
        // Record the flag so we stop re-checking every login.
        await syncState.markDmRelayListPublished(pubkey);
        return;
      }
      if (resolution.state == _OwnDmInboxState.failed) {
        // Outcome unknown: do NOT publish (could clobber an existing list)
        // and do NOT set the flag — retry on the next login.
        return;
      }
      // _OwnDmInboxState.absent — safe to self-advertise.

      final taggedRelays = <String>[
        relayUrl,
        ..._dmInboxTaggedRelays
            .where(_nostrClient.isRelayAllowed)
            .where((relay) => relay != relayUrl),
      ];
      final unsigned = Event(
        pubkey,
        EventKind.dmRelaysList,
        taggedRelays.map((relay) => <String>['relay', relay]).toList(),
        '',
      );

      final Event? signed;
      try {
        signed = await signer
            .signEvent(unsigned)
            .timeout(_dmRelayListSignTimeout);
      } on TimeoutException {
        Log.warning(
          'kind-10050 publish: signer timed out after '
          '${_dmRelayListSignTimeout.inSeconds}s — will retry next login',
          category: LogCategory.system,
        );
        return;
      }
      if (signed == null || signed.sig.isEmpty) return;
      if (_disposed || _resetGeneration != gen) return;

      // Publish to the advertised relay AND the discovery relays. An
      // env-locked build drops the latter in `NostrClient._allowedRelays`, so
      // a LOCAL run still targets only its own relay.
      final discoveryTargets = _dmInboxDiscoveryRelays
          .where(_nostrClient.isRelayAllowed)
          .toList();
      final outcome = await _nostrClient.publishEventAwaitOk(
        signed,
        targetRelays: <String>[relayUrl, ...discoveryTargets],
      );
      if (_disposed || _resetGeneration != gen) return;
      // Success is the advertised relay's own `OK`, not "something accepted".
      // A discovery relay accepting while divine's relay refused would mark
      // the list published and stop retrying, leaving the one relay divine
      // reads from without it.
      if (!outcome.acceptedBy.contains(relayUrl)) {
        Log.warning(
          'kind-10050 publish: $relayUrl did not accept '
          '(${outcome.rejectedBy[relayUrl] ?? 'no response'}) — will retry '
          'next login',
          category: LogCategory.system,
        );
        return;
      }
      for (final url in discoveryTargets) {
        if (outcome.acceptedBy.contains(url)) continue;
        // Best-effort by design: discoverability only. Logged so a relay
        // changing its kind policy is visible in a bug report, never retried.
        Log.warning(
          'kind-10050 discovery publish to $url did not land '
          '(${outcome.rejectedBy[url] ?? 'no response'}) — not retried',
          category: LogCategory.system,
        );
      }

      await syncState.markDmRelayListPublished(pubkey);
      // The event id is the anchor: a relay serves only the newest revision of
      // a replaceable kind for a coordinate query, so an id is the one handle
      // that still reaches an earlier one. Logged whole.
      Log.info(
        'Published kind-10050 DM inbox relay list for ${pubkeyForLogs(pubkey)} '
        '-> $relayUrl (event ${signed.id})',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'kind-10050 publish failed: $e — will retry next login',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Upserts a conversation for a LIVE outgoing send and marks it read in
  /// the same transaction as the caller. Sending a message implies the
  /// thread is read.
  ///
  /// MUST be called from within a [ConversationsDao.runInTransaction] block
  /// so the upsert and the read flip stay atomic with the message insert.
  ///
  /// Scoped to live sends ONLY. The history-drain / ingest paths
  /// ([_persistDecryptedGiftWrap], NIP-04 ingest) MUST NOT call this — they
  /// pass `isRead: isSentByMe` to [ConversationsDao.upsertConversation]
  /// directly, so re-ingesting our own historical sent wraps during a
  /// reinstall drain does not mark threads read.
  ///
  /// Read state is flipped via an explicit [ConversationsDao.markAsRead]
  /// rather than the upsert's `isRead` argument: the `isRead` conflict gate
  /// only writes when the incoming event is strictly newer, so a send that
  /// lands in the same epoch-second as the last received message (NIP-17
  /// timestamps are seconds) would otherwise leave the thread unread.
  Future<void> _upsertSentConversationAndMarkRead({
    required String id,
    required String participantPubkeys,
    required bool isGroup,
    required int createdAt,
    required int lastMessageTimestamp,
    required String lastMessageSenderPubkey,
    String? lastMessageContent,
    String? ownerPubkey,
    String? dmProtocol,
  }) async {
    await _conversationsDao.upsertConversation(
      id: id,
      participantPubkeys: participantPubkeys,
      isGroup: isGroup,
      createdAt: createdAt,
      lastMessageContent: lastMessageContent,
      lastMessageTimestamp: lastMessageTimestamp,
      lastMessageSenderPubkey: lastMessageSenderPubkey,
      currentUserHasSent: true,
      ownerPubkey: ownerPubkey,
      dmProtocol: dmProtocol,
    );
    await _conversationsDao.markAsRead(id, ownerPubkey: ownerPubkey);
  }

  /// Make a conversation whose FIRST send did not deliver visible in the
  /// inbox list. Creates the `dm_conversations` row only when none exists —
  /// without this, the first-ever message of a new thread composed offline
  /// (or otherwise hard-failed) leaves no conversation row at all, so the
  /// thread is invisible in the inbox and the user cannot find the failed
  /// bubble to retry or delete it. Established threads are left untouched.
  /// Non-throwing: visibility is best-effort on an already-failing path.
  Future<void> _ensureConversationVisibleAfterSendFailure({
    required String conversationId,
    required List<String> participants,
    required bool isGroup,
    required String content,
  }) async {
    try {
      final existing = await _conversationsDao.getConversation(
        conversationId,
        ownerPubkey: _userPubkey,
      );
      if (existing != null) return;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _conversationsDao.runInTransaction(() async {
        await _upsertSentConversationAndMarkRead(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: isGroup,
          createdAt: now,
          lastMessageContent: content,
          lastMessageTimestamp: now,
          lastMessageSenderPubkey: _userPubkey,
          ownerPubkey: _userPubkey,
        );
      });
    } on Object catch (e) {
      Log.warning(
        'Failed to surface conversation $conversationId after send failure: '
        '$e',
        category: LogCategory.system,
      );
    }
  }

  /// Refuses a rumor the NIP-17 double encryption cannot carry, or `null` when
  /// it fits.
  ///
  /// The NIP-44 plaintext is `jsonEncode(rumor)`, so tags count as much as the
  /// body — which is why this measures the rumor rather than the message text.
  /// The rumor ceiling is invariant in the tag set where a content ceiling is
  /// not, so one number covers a 1:1 send, a group fan-out and a reply alike.
  ///
  /// Callers invoke this BEFORE enqueuing, because NIP-44's throw is
  /// deterministic — the same rumor fails identically every time — and a
  /// hard-failed row is re-driven by `OutgoingDmRetryService.sweep()` on every
  /// foreground and reconnect, so a parked row would spend the whole retry
  /// budget on work that cannot succeed.
  ///
  /// Returns rather than throws so a caller that loops over recipients — such
  /// as `CollaboratorInviteService.sendInvites` — is not aborted mid-fan-out.
  NIP17SendResult? _refuseIfOversized(Event rumor) {
    final rumorBytes = utf8.encode(jsonEncode(rumor.toJson())).length;
    if (rumorBytes <= maxDmRumorBytes) return null;
    Log.info(
      'DM refused: rumor serializes to $rumorBytes bytes, over the '
      '$maxDmRumorBytes-byte limit',
      category: LogCategory.system,
    );
    return NIP17SendResult.tooLong(
      'message is too large to send: the rumor is $rumorBytes bytes, over '
      'the $maxDmRumorBytes-byte limit',
    );
  }

  /// Send a text message to a 1:1 conversation.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if [recipientPubkey] is not a 64-character
  /// hex string or if [content] is empty.
  ///
  /// Returns a failure result, publishing nothing, when [recipientPubkey] is
  /// the sender — see the refusal below.
  ///
  /// Returns [NIP17SendResult.tooLong], publishing nothing and leaving no
  /// queue row, when the built rumor exceeds [maxDmRumorBytes].
  ///
  /// When an [OutgoingDmsDao] is injected, the send goes through the
  /// durable queue: build the rumor, enqueue a `pending`/`pending` row
  /// keyed by the rumor's id, publish, then transition the queue row
  /// by wrap outcome:
  ///
  /// - Full NIP-17 delivery (`selfWrapPublished == true`): delete the
  ///   queue row in the same transaction that inserts `direct_messages`.
  /// - Partial delivery (`selfWrapPublished == false`): keep the row,
  ///   mark the recipient wrap `sent`, and mark the self-wrap `failed`
  ///   so only the missing self-wrap is retried later.
  /// - Recipient publish failure: mark both wraps `failed` and leave
  ///   the row queued for replay.
  @useResult
  Future<NIP17SendResult> sendMessage({
    required String recipientPubkey,
    required String content,
    String? replyToId,
    List<List<String>> additionalTags = const [],
    bool skipNip04Fallback = false,
  }) async {
    _assertInitialized();
    validatePubkey(recipientPubkey);
    if (content.trim().isEmpty) {
      throw ArgumentError.value(content, 'content', 'must not be empty');
    }

    // Divine does not support a self-addressed conversation (#8351, decided
    // on #8261). Refused here rather than in the UI so every caller is
    // covered — share-to-DM, collaborator invites, and whatever is added
    // next. Returned rather than thrown because callers
    // already branch on `success` and one of them,
    // `CollaboratorInviteService.sendInvites`, loops without a catch: a
    // throw would abort the remaining invites.
    //
    // A published self-send is not merely useless, it is permanent. The
    // receive path drops a wrap whose participants collapse to a single
    // pubkey (#2824), so the app cannot read its own message back; and a
    // NIP-59 gift wrap is signed by a throwaway ephemeral key, which is the
    // author funnelcake matches a kind-5 against, so the real sender is never
    // authorized to delete it.
    if (_isSelf(recipientPubkey)) {
      return const NIP17SendResult.failure(
        'refused: a message cannot be addressed to its own sender',
      );
    }

    // Send gate (#176): block before building or enqueuing a doomed intent.
    // NIP17MessageService.sendRumor is the authoritative choke point (it also
    // covers the drain replay); this earlier check avoids storing a queue row
    // that would only ever re-fail the gate.
    if (!await _messageService!.canSendTo(recipientPubkey)) {
      return const NIP17SendResult.blocked(
        'blocked: recipient not permitted by send policy',
      );
    }

    final rumorTags = <List<String>>[
      ...additionalTags,
      if (replyToId != null) ['e', replyToId],
    ];
    final participants = [_userPubkey, recipientPubkey]..sort();
    final conversationId = computeConversationId(participants);

    // Durable, collision-proof identity for this send, minted BEFORE the
    // rumor is built — the 1:1 counterpart of the token [sendGroupMessage]
    // mints, for the same reason. A rumor's event id is
    // sha256([0, pubkey, created_at(seconds), kind, tags, content]) with no
    // nonce, so two sends of byte-identical text to the same recipient in the
    // SAME Unix second would otherwise build byte-identical rumors, and every
    // layer below keys on that id: the queue row PK (`OutgoingDm.id`, enqueued
    // with insertOrIgnore), the local message PK (likewise insertOrIgnore),
    // and — beyond this device — the RECIPIENT's own rumor-id dedup. The
    // second send would report success while vanishing from the queue, from
    // local history, and from the recipient, leaving no failure status and
    // nothing for the retry sweep to re-drive.
    //
    // The token is injected into the rumor as the same client-internal `batch`
    // tag the group path uses, so both paths stay symmetric and the ingest
    // side needs no new case. It rides inside the encrypted gift-wrapped rumor
    // (only the recipient and the sender's own self-wrap ever decrypt it) and
    // is independent secure random, so it discloses nothing. See #7326.
    final sendBatchId = _newSendBatchId();

    // Build the rumor up front so the queue row PK matches the rumor id
    // the relay will see — receiver-side gift-wrap dedup keys on this id
    // and a re-mint between enqueue and publish would defeat it.
    //
    // The batch tag is deliberately NOT part of [rumorTags]: that list is what
    // the happy path persists as the local row's `tagsJson`, and the group path
    // likewise keeps its wire-only token out of the happy-path persisted tags.
    // Recovery reconstructs `tagsJson` from the full stored rumor instead.
    final rumor = _messageService!.buildRumor(
      recipientPubkey: recipientPubkey,
      content: content,
      additionalTags: [
        ...rumorTags,
        [_sendBatchTagKey, sendBatchId],
      ],
    );

    final oversized = _refuseIfOversized(rumor);
    if (oversized != null) return oversized;

    // Enqueue before publish so an app crash mid-send leaves a
    // recoverable trace. No-op when the queue dao isn't wired in
    // (older test fixtures, NIP-04-only callers).
    final outgoingDao = _outgoingDmsDao;
    if (outgoingDao != null) {
      await outgoingDao.enqueue(
        OutgoingDm(
          id: rumor.id,
          conversationId: conversationId,
          recipientPubkey: recipientPubkey,
          content: content,
          createdAt: rumor.createdAt,
          rumorEventJson: jsonEncode(rumor.toJson()),
          messageKind: rumor.kind,
          replyToId: replyToId,
          recipientWrapStatus: OutgoingWrapStatus.pending,
          selfWrapStatus: OutgoingWrapStatus.pending,
          queuedAt: DateTime.now(),
          ownerPubkey: _userPubkey,
          // Stamped verbatim, as the group path stamps its siblings: a 1:1
          // row has no siblings, but carrying the token makes a deleted
          // bubble's cancellation match by exact value instead of falling
          // back to the collision-prone `(createdAt, content)` tuple.
          sendBatchId: sendBatchId,
        ),
      );
    }

    // Route the gift wrap to the recipient's NIP-17 DM inbox relays
    // (kind 10050) when they advertise one; null falls back to the
    // default relay pool so reachability is preserved for recipients who
    // have not published a DM inbox. Resolved after the queue enqueue
    // above so the optimistic UI echo is never delayed by this lookup.
    // Both lookups together: the sender's own inbox is memoized per session,
    // so pairing it with the recipient's costs no extra round trip (#7328).
    // The recipient side resolves DETAILED: routing only needs the relays, but
    // reporting delivery needs to know whether we could read them at all
    // (#7317).
    final (inbox, selfWrapRelays) = await (
      resolveDmInboxRelaysDetailed(recipientPubkey),
      _selfWrapTargetRelays(),
    ).wait;

    // A recipient who advertises a kind-10050 implements NIP-17 — the kind is
    // defined by it (17.md:63) and NIP-51 scopes it to NIP-17 DMs explicitly
    // (51.md:42) — so they can read the gift wrap and do not need a cleartext
    // twin. #8505 already unlatches on a NIP-17 event FROM the peer, but that
    // needs them to send something. A one-way thread never gets that evidence,
    // so it dual-sent a kind 4 on every message forever (#8519).
    //
    // This runs BEFORE the persist transaction on purpose: the gate below
    // reads `dmProtocol` from the row that transaction loads, so clearing here
    // means THIS send already skips the kind 4 rather than only later ones.
    //
    // `found` only. `absent` and `unreadable` route to the same place but mean
    // different things — `unreadable` is a failed lookup, not evidence the
    // peer cannot read NIP-17 — and treating them alike is the #7317 mistake.
    await _clearLatchOnAdvertisedInbox(conversationId, inbox.state);

    // OK-confirm the recipient wrap: a WebSocket frame-accept is a false
    // positive on a flaky single relay (the relay may never store the event),
    // so require a NIP-20 `OK` before treating the message as delivered. A
    // lost/late OK comes back soft (retryablePending) and keeps the durable
    // queue row pending for the sweep — never a false "delivered". See #5977
    // for the reaction precedent this mirrors.
    final publishResult = await _sendRumorWithTimeout(
      rumor: rumor,
      recipientPubkey: recipientPubkey,
      targetRelays: inbox.relays,
      selfWrapTargetRelays: selfWrapRelays,
      awaitRecipientOk: true,
    );

    // An `OK` from the DEFAULT POOL is not delivery when we never read the
    // recipient's inbox. Absent and unreadable both routed here, but only
    // absent means the pool is where they read; on unreadable the wrap may sit
    // on relays the recipient never queries, and deleting the queue row would
    // destroy the only handle that could ever re-resolve and republish (#7317).
    //
    // Reuses the soft-unconfirmed contract verbatim: row stays `pending`,
    // `incrementRetry` charges the budget, and `recoverFullSend` re-resolves on
    // the next sweep. The bubble is unchanged — `pending` and `delivered`
    // render identically — so this buys durability, not a new indicator.
    //
    // Only when the queue is wired: with no row to preserve there is nothing to
    // gain, and downgrading would skip the local persist and drop the message
    // from the conversation.
    final result = outgoingDao == null
        ? publishResult
        : downgradeFallbackPoolDelivery(publishResult, inbox.state);

    if (result.success) {
      // Persist our own sent message locally so it appears immediately
      // without waiting for a relay round-trip.
      try {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Persist message + conversation atomically. When the queue is
        // wired in, the queue transition also lives in this transaction
        // so a watcher never observes a window where the message is in
        // neither table and so partial delivery preserves the retry row.
        String? protocol;
        var persistedLocally = false;
        await _conversationsDao.runInTransaction(() async {
          // Cancel interlock (mirrors _recoverFullSendLocked): the row may be
          // gone by the time this publish lands — the user deleted the send
          // (cancelOutgoingSend) during the publish window (OK-confirmation
          // can legitimately take tens of seconds), or the retry sweep's
          // interrupted arm recovered and finalized the same rumor. The wire
          // copy is out and receiver dedup keeps it single, but do NOT
          // resurrect the message locally from a row that no longer exists.
          //
          // Naming only the cancel here actively misled: before #7326 a
          // colliding same-second sibling deleted the row, and this line
          // reported a cancellation that never happened.
          if (outgoingDao != null &&
              await outgoingDao.getById(rumor.id) == null) {
            Log.info(
              'Publish for ${rumor.id} landed after the queue row was '
              'already removed (cancelled mid-flight, or finalized by a '
              'concurrent recovery); skipping local persist.',
              category: LogCategory.system,
            );
            return;
          }
          await _directMessagesDao.insertMessage(
            id: result.rumorEventId!,
            conversationId: conversationId,
            senderPubkey: _userPubkey,
            content: content,
            // The rumor's canonical timestamp, NOT confirm-time `now`: the
            // optimistic bubble sorts by rumor.createdAt, so stamping the
            // persisted row with a later time (OK-confirm adds up to tens of
            // seconds) made the bubble jump on confirm.
            createdAt: rumor.createdAt,
            giftWrapId: result.messageEventId!,
            replyToId: replyToId,
            tagsJson: rumorTags.isEmpty ? null : jsonEncode(rumorTags),
            ownerPubkey: _userPubkey,
            sendBatchId: sendBatchId,
          );

          final existingSend = await _conversationsDao.getConversation(
            conversationId,
            ownerPubkey: _userPubkey,
          );
          // Mark the conversation as NIP-17 once we successfully publish
          // a NIP-17 message ourselves. Without this, `dmProtocol` only
          // ever flips when the peer sends us a NIP-17 message, so a
          // send-first conversation stayed `null` forever and every
          // subsequent send fired the NIP-04 fallback (#3663).
          //
          // `protocol` carries that decision out to the fallback gate
          // below, which runs after this transaction. Reading the
          // pre-upsert row there left it null on a conversation the user
          // initiates, so message #1 of every self-initiated thread also
          // published a cleartext kind-4 copy (#7342).
          final nextProtocol = existingSend?.dmProtocol ?? 'nip17';
          protocol = nextProtocol;
          await _upsertSentConversationAndMarkRead(
            id: conversationId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            createdAt: existingSend?.createdAt ?? now,
            lastMessageContent: content,
            lastMessageTimestamp: now,
            lastMessageSenderPubkey: _userPubkey,
            ownerPubkey: _userPubkey,
            dmProtocol: nextProtocol,
          );

          if (outgoingDao != null) {
            await _finalizeAfterRecipientSuccess(
              outgoingDao: outgoingDao,
              rumorId: rumor.id,
              result: result,
            );
          }
          persistedLocally = true;
        });

        if (persistedLocally) {
          Log.debug(
            'Persisted sent message locally in conversation '
            '$conversationId',
            category: LogCategory.system,
          );
        }

        // Fire NIP-04 fallback for interop with legacy clients. Skip
        // when the conversation is known NIP-17-only, or when the caller
        // opts out — structured DMs that cannot be represented in NIP-04
        // (e.g. collaborator invites) would degrade to a plaintext
        // duplicate. `persistedLocally` also covers the cancel interlock:
        // it stays false when the transaction bailed out, and a plaintext
        // copy of a message the user just deleted must not go out.
        if (persistedLocally && protocol != 'nip17' && !skipNip04Fallback) {
          unawaited(
            _sendNip04Message(
              recipientPubkey: recipientPubkey,
              content: content,
              replyToId: replyToId,
            ).catchError((Object e) {
              // Thrown failures only — a signer that reports by THROWING
              // (Keycast's RPC layer raises RpcException on 401/403/504, and a
              // bunker request raises TimeoutException) lands here. Signers
              // that report by returning null, and every relay refusal, are
              // logged inside `_sendNip04Message` instead, because a returned
              // failure never reaches this handler (#8262).
              Log.error(
                'NIP-04 fallback threw — the legacy kind-4 copy was not '
                'sent: $e',
                category: LogCategory.system,
              );
              // The value is discarded by design: this leg is best-effort
              // legacy interop and is deliberately kept off the send's
              // critical path, so it stays `unawaited`. Every outcome is
              // observable in the log rather than in this return.
              return NIP17SendResult.failure('NIP-04 fallback failed: $e');
            }),
          );
        }
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to persist sent message locally: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites.sendMessageOuterTransaction,
        );
        // Don't rethrow — the message was published successfully.
        // Local persistence failure is a degraded state, not a send failure.
      }
    } else if (result.blocked && outgoingDao != null) {
      // A policy block is terminal, not a transient failure.
      // _finalizeAfterRecipientBlocked discards or retains the row per the
      // block's disposition, so the sweep stops re-driving a send the gate
      // refuses every time (no doomed Resend bubble). Mirrors
      // sendGroupMessage's per-recipient classification and the drain's
      // blocked arm.
      await _finalizeAfterRecipientBlocked(
        outgoingDao: outgoingDao,
        rumorId: rumor.id,
        result: result,
      );
    } else if (result.retryablePending && outgoingDao != null) {
      // Soft retry: either the recipient frame was written but no NIP-20 OK
      // arrived, or the pre-publish wrap build timed out while a human-gated
      // signer approval may still be pending. Keep the row pending — it renders
      // as a plain optimistic bubble, never a red failure — and let the retry
      // sweep re-drive it.
      await _finalizeAfterRecipientUnconfirmed(
        outgoingDao: outgoingDao,
        rumorId: rumor.id,
      );
      await _ensureConversationVisibleAfterSendFailure(
        conversationId: conversationId,
        participants: participants,
        isGroup: false,
        content: content,
      );
      return _stampQueuedRow(result, rumor.id);
    } else if (outgoingDao != null) {
      // Recipient publish hard-failed (explicit rejection / offline / error)
      // before the self-wrap could land, so both wrap statuses remain
      // retryable on the queue row.
      await _finalizeAfterRecipientFailure(
        outgoingDao: outgoingDao,
        rumorId: rumor.id,
        errorMessage: result.error ?? 'Unknown publish failure',
      );
      // Make a brand-new thread visible so the user can find the red bubble
      // to retry or delete it. A blocked result is handled terminally above
      // and never reaches here.
      await _ensureConversationVisibleAfterSendFailure(
        conversationId: conversationId,
        participants: participants,
        isGroup: false,
        content: content,
      );
      return _stampQueuedRow(result, rumor.id);
    }

    return result;
  }

  /// Tag a failure with the `outgoing_dms` row it left parked, so the caller
  /// can re-drive that row ([recoverFullSend]) instead of calling
  /// [sendMessage] again — a second call mints a fresh rumor and a second
  /// durable row, and the sweep then delivers one copy while the retry
  /// delivers another.
  ///
  /// Called only for a row that survives the call: retryable failures and
  /// partial successes whose recipient wrap landed but self-wrap did not.
  NIP17SendResult _stampQueuedRow(NIP17SendResult result, String rumorId) =>
      switch (result) {
        NIP17SendSuccess() when !result.selfWrapPublished => NIP17SendSuccess(
          rumorEventId: result.rumorEventId,
          messageEventId: result.messageEventId,
          recipientPubkey: result.recipientPubkey,
          selfWrapPublished: false,
          queuedRumorId: rumorId,
          timestamp: result.timestamp,
        ),
        NIP17SendSuccess() => result,
        NIP17SendFailure() => NIP17SendFailure(
          result.error,
          retryablePending: result.retryablePending,
          queuedRumorId: rumorId,
        ),
      };

  /// Shares a video into a 1:1 NIP-17 DM as a kind-14 rumor that cites the
  /// video with a NIP-18 `q` tag and a NIP-21 `nostr:` URI, in addition to the
  /// human-readable [baseContent] (which keeps the `https://divine.video` URL
  /// so non-Nostr clients still render a link).
  ///
  /// [videoKind] selects the citation form — addressable (34236/34235) emits a
  /// coordinate + `naddr`; regular (22) emits an id + `nevent`. When a valid
  /// citation can't be built, falls back to a plain-text [sendMessage] so the
  /// share still goes through (the URL remains in [baseContent]).
  ///
  /// [skipNip04Fallback] forwards to [sendMessage]: pass `true` to suppress the
  /// legacy plaintext kind-4 copy (recommended for shares — see the caller in
  /// `VideoSharingService`).
  ///
  /// Throws the same errors as [sendMessage].
  @useResult
  Future<NIP17SendResult> sendSharedVideo({
    required String recipientPubkey,
    required String baseContent,
    required int videoKind,
    required String videoAuthorPubkey,
    String? videoDTag,
    String? videoEventId,
    String? relayHint,
    String? replyToId,
    bool skipNip04Fallback = false,
  }) async {
    final citation = DmSharedVideoCitation.build(
      videoKind: videoKind,
      authorPubkey: videoAuthorPubkey,
      relayHint: relayHint ?? DmShareConstants.defaultRelayHint,
      dTag: videoDTag,
      eventId: videoEventId,
    );

    if (citation == null) {
      // The structured reference couldn't be built (most commonly a regular
      // kind-22 ref whose source `q` tag omitted the author). Degrading to a
      // plain message is acceptable, but log it so the lost cross-device /
      // other-client durability isn't silent.
      Log.warning(
        'Shared-video citation could not be built (kind=$videoKind, '
        'hasAuthor=${videoAuthorPubkey.isNotEmpty}, '
        'hasDTag=${videoDTag?.isNotEmpty ?? false}, '
        'hasEventId=${videoEventId?.isNotEmpty ?? false}); sending plain '
        'message without the durable video reference.',
        category: LogCategory.system,
      );
      return sendMessage(
        recipientPubkey: recipientPubkey,
        content: baseContent,
        replyToId: replyToId,
        skipNip04Fallback: skipNip04Fallback,
      );
    }

    return sendMessage(
      recipientPubkey: recipientPubkey,
      content: '$baseContent\n${citation.nostrUri}',
      additionalTags: [citation.qTag],
      replyToId: replyToId,
      skipNip04Fallback: skipNip04Fallback,
    );
  }

  /// Group counterpart of [sendSharedVideo]: cites a video with a NIP-18 `q`
  /// tag + NIP-21 `nostr:` URI on a kind-14 rumor sent to every member of a
  /// group conversation.
  ///
  /// Used for a reel reply in a group so the reply self-carries the video
  /// reference end-to-end (cross-device + other Nostr clients can resolve it
  /// without the parent message). When a valid citation can't be built, falls
  /// back to a plain-text [sendGroupMessage].
  ///
  /// Throws the same errors as [sendGroupMessage].
  @useResult
  Future<List<NIP17SendResult>> sendSharedVideoGroup({
    required List<String> recipientPubkeys,
    required String baseContent,
    required int videoKind,
    required String videoAuthorPubkey,
    String? videoDTag,
    String? videoEventId,
    String? relayHint,
    String? replyToId,
  }) async {
    final citation = DmSharedVideoCitation.build(
      videoKind: videoKind,
      authorPubkey: videoAuthorPubkey,
      relayHint: relayHint ?? DmShareConstants.defaultRelayHint,
      dTag: videoDTag,
      eventId: videoEventId,
    );

    if (citation == null) {
      // See [sendSharedVideo]: log the degradation so a reel reply silently
      // losing its durable video reference is observable.
      Log.warning(
        'Shared-video group citation could not be built (kind=$videoKind, '
        'hasAuthor=${videoAuthorPubkey.isNotEmpty}, '
        'hasDTag=${videoDTag?.isNotEmpty ?? false}, '
        'hasEventId=${videoEventId?.isNotEmpty ?? false}); sending plain '
        'group message without the durable video reference.',
        category: LogCategory.system,
      );
      return sendGroupMessage(
        recipientPubkeys: recipientPubkeys,
        content: baseContent,
        replyToId: replyToId,
      );
    }

    return sendGroupMessage(
      recipientPubkeys: recipientPubkeys,
      content: '$baseContent\n${citation.nostrUri}',
      additionalTags: [citation.qTag],
      replyToId: replyToId,
    );
  }

  /// Re-publish only the sender self-addressed gift wrap for an
  /// already-sent rumor whose recipient publish landed but whose
  /// self-wrap did not.
  ///
  /// Looks up the queue row for [rumorId] (must have been enqueued by
  /// [sendMessage] / [sendGroupMessage]), rebuilds the rumor from the
  /// stored JSON, calls [NIP17MessageService.publishSelfWrap], and
  /// transitions the queue row by outcome:
  ///
  /// - Success: delete the queue row — both wraps have now landed.
  /// - Failure: mark the self-wrap status [OutgoingWrapStatus.failed]
  ///   so the row stays retryable.
  ///
  /// Returns the underlying [NIP17SendResult] so callers can chain a
  /// per-rumor recovery and aggregate the result.
  ///
  /// Idempotent: if the row's `selfWrapStatus` is already
  /// [OutgoingWrapStatus.sent] (e.g. a concurrent recovery already
  /// landed), returns success without republishing.
  ///
  /// Throws [StateError] if the repository or its queue DAO are not
  /// wired in. Throws [ArgumentError] if no row exists for [rumorId]
  /// or the row belongs to a different account.
  @useResult
  Future<NIP17SendResult> recoverSelfWrap({required String rumorId}) async {
    _assertInitialized();
    final dao = _outgoingDmsDao;
    if (dao == null) {
      throw StateError(
        'recoverSelfWrap requires the outgoing_dms queue DAO; '
        'wire OutgoingDmsDao into DmRepository before calling.',
      );
    }
    return _joinOrStartRecovery(
      'self:$rumorId',
      () => _recoverSelfWrapLocked(dao: dao, rumorId: rumorId),
    );
  }

  Future<NIP17SendResult> _recoverSelfWrapLocked({
    required OutgoingDmsDao dao,
    required String rumorId,
  }) async {
    final row = await dao.getById(rumorId);
    if (row == null) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'no queued outgoing DM with this id',
      );
    }
    if (row.ownerPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'queue row belongs to a different account',
      );
    }

    // Idempotent re-tap. Reached when a prior recovery attempt's publish
    // already landed: either a concurrent recovery for this rumor, or
    // the previous sweep's deleteById threw and the fallback below
    // marked self_wrap_status=sent. Return success so the caller's
    // aggregation treats this rumor as done without re-publishing.
    if (row.selfWrapStatus == OutgoingWrapStatus.sent) {
      return NIP17SendResult.success(
        rumorEventId: rumorId,
        messageEventId: row.selfWrapEventId ?? rumorId,
        recipientPubkey: _userPubkey,
      );
    }

    final Event rumor;
    try {
      final json = jsonDecode(row.rumorEventJson) as Map<String, dynamic>;
      rumor = Event.fromJson(json);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to parse rumor JSON for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      _errorReporter?.call(
        e,
        stackTrace,
        site: DmRepositoryReportableSites.recoverSelfWrapRumorJsonParse,
      );
      // Mark the self-wrap status failed so the row surfaces in the
      // next retry sweep with a record of the parse failure.
      try {
        await dao.markSelfWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: 'rumor JSON parse failed: $e',
        );
      } on Object catch (markError, markStack) {
        Log.error(
          'Failed to mark self-wrap failed after JSON parse error for '
          '$rumorId: $markError',
          category: LogCategory.system,
          error: markError,
          stackTrace: markStack,
        );
        _errorReporter?.call(
          markError,
          markStack,
          site: DmRepositoryReportableSites
              .recoverSelfWrapMarkFailedAfterJsonParse,
        );
        // Swallow — caller still gets the failure result below.
      }
      // Row stays retryable (self-wrap failed) — nudge the sweep.
      _notifyRetryableWork();
      return NIP17SendResult.failure('rumor JSON parse failed: $e');
    }

    // Session-identity token before the inbox lookup: `ownerPubkey` was checked
    // against `_userPubkey` above, but an account switch during this await
    // would otherwise resolve the NEW account's inbox and publish the previous
    // account's rumor to it. Bail retryable instead — the row stays queued and
    // the next sweep re-drives it under the right identity.
    final gen = _resetGeneration;
    final selfWrapRelays = await _selfWrapTargetRelays();
    if (_disposed || _resetGeneration != gen) {
      return const NIP17SendResult.failure(
        'self-wrap recovery abandoned: account changed mid-flight',
        retryablePending: true,
      );
    }

    final result = await _messageService!.publishSelfWrap(
      rumorEvent: rumor,
      targetRelays: selfWrapRelays,
    );

    if (result.success) {
      // Both wraps have landed. Mirror sendMessage's full-delivery
      // path: drop the queue row so the retry sweep stops returning it.
      try {
        await dao.deleteById(rumorId);
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to delete outgoing_dms row $rumorId after self-wrap '
          'recovery: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites.recoverSelfWrapDeleteAfterPublish,
        );
        // Publish landed but the row is still here. Mark
        // self_wrap_status=sent with the published event id so the next
        // recovery sweep short-circuits via the idempotent guard above
        // instead of republishing the self-wrap.
        try {
          await dao.markSelfWrapStatus(
            id: rumorId,
            status: OutgoingWrapStatus.sent,
            eventId: result.messageEventId,
          );
        } on Object catch (markError, markStack) {
          Log.error(
            'Fallback markSelfWrapStatus(sent) also failed for $rumorId: '
            '$markError',
            category: LogCategory.system,
            error: markError,
            stackTrace: markStack,
          );
          _errorReporter?.call(
            markError,
            markStack,
            site: DmRepositoryReportableSites
                .recoverSelfWrapBookkeepingDoubleFailure,
          );
          // Both bookkeeping writes failed. The row stays
          // `recipient: sent / self: failed` and the next sweep
          // republishes the self-wrap. Self-wraps to the sender are
          // idempotent on receive (NIP-17 dedup keys on the rumor id),
          // so the doubly-degraded path is safe — surfaced via logs.
        }
      }
    } else {
      try {
        await dao.markSelfWrapStatus(
          id: rumorId,
          status: OutgoingWrapStatus.failed,
          lastError: result.error ?? 'self-wrap recovery failed',
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to mark outgoing_dms self-wrap failed for $rumorId: '
          '$e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          e,
          stackTrace,
          site: DmRepositoryReportableSites
              .recoverSelfWrapMarkFailedAfterPublishFailure,
        );
        // Don't rethrow — caller already gets the failure result.
      } finally {
        // The self-wrap is still missing — nudge the sweep. Manual
        // recoveries (sentPartial Retry) reach here without a sweep pass
        // to reschedule them.
        _notifyRetryableWork();
      }
    }

    return result;
  }

  /// Re-publish both gift wraps for a stored rumor whose recipient
  /// publish previously failed.
  ///
  /// Used by `OutgoingDmRetryService`'s strategy-table dispatch for
  /// rows in `recipient_wrap_status == failed`. Re-publishing the
  /// rumor against a relay that already accepted the original wire
  /// copy is safe: NIP-17 receiver-side dedup keys on the rumor id
  /// (preserved verbatim via `rumor_event_json`), so the receiver sees
  /// one logical message even when the wire copy was sent twice.
  ///
  /// Looks up the queue row for [rumorId] (must have been enqueued by
  /// [sendMessage] / [sendGroupMessage]), rebuilds the rumor from the
  /// stored JSON, calls [NIP17MessageService.sendRumor], and
  /// transitions the queue row by outcome:
  ///
  /// - Full success: delete the row in the same transaction that
  ///   inserts `direct_messages`. Same atomicity contract as
  ///   [sendMessage]'s happy path.
  /// - Partial success (recipient sent, self failed): mark recipient
  ///   `sent` and self `failed` so the next sweep replays only the
  ///   missing self-wrap via [recoverSelfWrap].
  /// - Recipient failure: re-mark both wraps `failed` so the row
  ///   stays retryable.
  ///
  /// Idempotent: if the row's `recipientWrapStatus` is already
  /// [OutgoingWrapStatus.sent] (a concurrent recovery raced ahead or
  /// the row was already mid-recovery), defers to [recoverSelfWrap]
  /// so the recipient wrap is never republished.
  ///
  /// Returns the underlying [NIP17SendResult] so callers can chain a
  /// per-rumor recovery and aggregate the result.
  ///
  /// Throws [StateError] if the repository or its queue DAO are not
  /// wired in. Throws [ArgumentError] if no row exists for [rumorId]
  /// or the row belongs to a different account.
  ///
  /// When a recovery for the same rumor is already in flight (a manual
  /// Resend racing the reconnect sweep), the call JOINS that attempt and
  /// returns its outcome instead of publishing a duplicate.
  ///
  /// [resetRetryBudget] zeroes the row's retry counter before dispatch. Pass
  /// `true` from the manual Resend path: each soft-unconfirmed attempt burns
  /// the shared sweep budget, and once `retry_count` reaches the sweep's
  /// `maxRetries` the sweep abandons the row permanently — an explicit user
  /// resend is the signal to hand it back with a fresh budget.
  @useResult
  Future<NIP17SendResult> recoverFullSend({
    required String rumorId,
    bool resetRetryBudget = false,
  }) async {
    _assertInitialized();
    final dao = _outgoingDmsDao;
    if (dao == null) {
      throw StateError(
        'recoverFullSend requires the outgoing_dms queue DAO; '
        'wire OutgoingDmsDao into DmRepository before calling.',
      );
    }
    if (resetRetryBudget) {
      // Before the in-flight join, so a resend that lands mid-sweep still
      // refreshes the budget for the sweep's follow-up passes. Owner-checked
      // first (same pattern as cancelOutgoingSend): resetRetryCount is not
      // owner-scoped, so without the check a foreign account's row would get
      // its budget re-armed before the locked body's ArgumentError fires.
      // Non-fatal: a missed reset only means the sweep may give up earlier.
      try {
        final row = await dao.getById(rumorId);
        if (row != null && row.ownerPubkey == _userPubkey) {
          await dao.resetRetryCount(rumorId);
        }
      } on Object catch (e) {
        Log.warning(
          'Failed to reset retry budget for $rumorId: $e',
          category: LogCategory.system,
        );
      }
    }
    return _joinOrStartRecovery(
      'full:$rumorId',
      () => _recoverFullSendLocked(dao: dao, rumorId: rumorId),
    );
  }

  Future<NIP17SendResult> _recoverFullSendLocked({
    required OutgoingDmsDao dao,
    required String rumorId,
  }) async {
    final row = await dao.getById(rumorId);
    if (row == null) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'no queued outgoing DM with this id',
      );
    }
    if (row.ownerPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'queue row belongs to a different account',
      );
    }

    // Idempotent guard: if a concurrent recovery (or the original
    // send's partial-success path) already promoted the recipient
    // wrap to sent, defer to recoverSelfWrap so the recipient wrap
    // is never republished. The two recovery primitives share the
    // same per-row state machine; this branch keeps them composable.
    if (row.recipientWrapStatus == OutgoingWrapStatus.sent) {
      return recoverSelfWrap(rumorId: rumorId);
    }

    final Event rumor;
    try {
      final json = jsonDecode(row.rumorEventJson) as Map<String, dynamic>;
      rumor = Event.fromJson(json);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to parse rumor JSON for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      // Mark both wraps failed with the parse error so the row stays
      // visible to the retry sweep with a record of why this attempt
      // produced no publish.
      await _finalizeAfterRecipientFailure(
        outgoingDao: dao,
        rumorId: rumorId,
        errorMessage: 'rumor JSON parse failed: $e',
      );
      return NIP17SendResult.failure('rumor JSON parse failed: $e');
    }

    // Re-resolve the recipient's kind-10050 DM inbox at retry time (10050 is
    // replaceable, so it may have changed since the original send) and route
    // the wrap there; null falls back to the default pool. Without this the
    // OK-confirm below would be satisfied by the default pool rather than the
    // recipient's own inbox — a false "confirmed" for a recipient who only
    // reads their advertised inbox. Resolution never throws (it degrades to
    // null), so it cannot abort a sweep pass.
    final (inbox, selfWrapRelays) = await (
      resolveDmInboxRelaysDetailed(row.recipientPubkey),
      _selfWrapTargetRelays(),
    ).wait;

    // The sweep resolves the same inbox the send path does, so it holds the
    // same evidence and must reach the same conclusion. A thread whose only
    // traffic is a queued message the sweep drives would otherwise stay
    // latched no matter how many times we re-read the peer's kind-10050, and
    // the next foreground send would publish the twin this pass already knew
    // was unnecessary (#8519).
    //
    // Keying on the row's conversationId is safe even though recovery also
    // drives GROUP rows: only the 1:1 kind-4 receive path ever writes
    // 'nip04', so a group row can never be latched and the DAO's
    // `WHERE dm_protocol = 'nip04'` matches nothing.
    await _clearLatchOnAdvertisedInbox(row.conversationId, inbox.state);

    final publishResult = await _sendRumorWithTimeout(
      rumor: rumor,
      recipientPubkey: row.recipientPubkey,
      targetRelays: inbox.relays,
      selfWrapTargetRelays: selfWrapRelays,
      awaitRecipientOk: true,
    );

    // Same rule as the initial send: a default-pool `OK` is not delivery when
    // the recipient's inbox stayed unreadable. Without this the sweep undoes
    // the send path's fix — it re-resolves to null, republishes to the pool,
    // scores the OK as success and deletes the row, converging on the old
    // false-`delivered` outcome one sweep later (#7317).
    //
    // `dao` is non-null here (guarded above), so unlike `sendMessage` there is
    // always a row to preserve.
    final result = downgradeFallbackPoolDelivery(publishResult, inbox.state);

    if (result.success) {
      // Mirror sendMessage's happy-path transaction: persist
      // direct_messages + conversation upsert + queue finalize
      // atomically so a watcher never sees a window where the message
      // is in neither table, and so a partial delivery preserves the
      // retry row.
      try {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // Recovered rows may belong to a GROUP send (one queue row per
        // recipient, all sharing the group conversationId). Derive the
        // topology instead of hardcoding 1:1: the pair id differing from the
        // row's conversationId proves a group row, and the rumor's p-tags
        // carry the other members when no conversation row survives.
        final pairParticipants = [_userPubkey, row.recipientPubkey]..sort();
        final isGroupRow =
            row.conversationId != computeConversationId(pairParticipants);
        var persistedLocally = false;
        await _conversationsDao.runInTransaction(() async {
          // Cancel interlock: the queue row may be gone by the time this
          // publish lands — the user deleted the send (cancelOutgoingSend),
          // or a concurrent recovery of the same rumor already finalized
          // (and persisted) it. The wire copy is out — receiver dedup keeps
          // it single — but do NOT resurrect the message or the conversation
          // from a row that no longer exists: for a cancel the user said
          // "give up", and for a concurrent recovery the winner has already
          // persisted the message.
          final liveRow = await dao.getById(rumorId);
          if (liveRow == null) {
            Log.info(
              'Recovered publish for $rumorId landed after the queue row '
              'was already removed (cancelled, or finalized by a concurrent '
              'recovery); skipping local persist.',
              category: LogCategory.system,
            );
            return;
          }

          // Sibling dedup: a group send persists ONE local message for the
          // whole batch (keyed to the first confirmed sibling). When a later
          // sibling row of the same batch is recovered, the message is
          // already there — only finalize the queue row. Match on the queue
          // row's durable batch id (stamped at enqueue). Rows enqueued by a
          // build before send_batch_id existed carry null; those fall back to
          // the legacy `(content, createdAt ±5s)` window so an in-flight
          // legacy batch still dedups (its persisted winner is likewise
          // null-batch, so the two reconcile on the same tuple).
          final batchId = row.sendBatchId;
          final alreadyPersisted =
              isGroupRow &&
              (batchId != null
                  ? await _directMessagesDao.hasMessageWithSendBatchId(
                      batchId: batchId,
                      ownerPubkey: _userPubkey,
                    )
                  : await _directMessagesDao.hasMatchingMessage(
                      conversationId: row.conversationId,
                      senderPubkey: _userPubkey,
                      content: row.content,
                      createdAt: row.createdAt,
                      ownerPubkey: _userPubkey,
                      // Matches our OWN persisted send, not a cross-protocol
                      // twin, so the arrival-shape filter does not apply.
                      counterpart: DmDedupCounterpart.unconstrained,
                    ));

          if (!alreadyPersisted) {
            await _directMessagesDao.insertMessage(
              id: result.rumorEventId!,
              conversationId: row.conversationId,
              senderPubkey: _userPubkey,
              content: row.content,
              // The rumor's canonical timestamp (row.createdAt mirrors it),
              // NOT recovery-time `now` — keeps the bubble from jumping.
              createdAt: row.createdAt,
              giftWrapId: result.messageEventId!,
              messageKind: row.messageKind,
              replyToId: row.replyToId,
              // Carry the row's send label onto the persisted message so a
              // later group sibling's recovery dedups against it (null only
              // for legacy rows).
              sendBatchId: batchId,
              // Reconstruct tagsJson from the rebuilt rumor so a recovered
              // row hydrates the same read-time-derived fields (e.g.
              // sharedVideoRef from a NIP-18 q tag) as the happy-path send.
              // Without this the queue-recovery row drops its tags and the
              // sender loses the shared-video reference locally. This
              // intentionally also persists the rumor's leading recipient
              // `p` tag — matching the receive path (L1121), not the
              // happy-path 1:1 send which stores only its own rumorTags;
              // harmless since only the `q` tag is read back.
              tagsJson: rumor.tags.isEmpty ? null : jsonEncode(rumor.tags),
              ownerPubkey: _userPubkey,
            );
          }

          final existing = await _conversationsDao.getConversation(
            row.conversationId,
            ownerPubkey: _userPubkey,
          );
          // Preserve the existing conversation's topology — a group row
          // recovered through this path must NOT rewrite the group as a
          // 1:1 (participants reduced to [self, recipient], isGroup false),
          // which corrupted the thread for every future render and send.
          // With no surviving conversation row, reconstruct the membership
          // from the rumor's p-tags (the other members) for group rows, or
          // fall back to the plain pair for 1:1 rows.
          final String participantsJson;
          final bool isGroup;
          if (existing != null) {
            participantsJson = existing.participantPubkeys;
            isGroup = existing.isGroup;
          } else if (isGroupRow) {
            final members = <String>{
              _userPubkey,
              row.recipientPubkey,
              for (final tag in rumor.tags)
                if (tag.length >= 2 && tag[0] == 'p') tag[1],
            }.toList()..sort();
            participantsJson = jsonEncode(members);
            isGroup = true;
          } else {
            participantsJson = jsonEncode(pairParticipants);
            isGroup = false;
          }
          // Mirror sendMessage: once we successfully publish a NIP-17
          // message ourselves, mark the conversation NIP-17 so the
          // legacy NIP-04 fallback path doesn't fire on future sends.
          final nextProtocol = existing?.dmProtocol ?? 'nip17';
          await _upsertSentConversationAndMarkRead(
            id: row.conversationId,
            participantPubkeys: participantsJson,
            isGroup: isGroup,
            createdAt: existing?.createdAt ?? now,
            lastMessageContent: row.content,
            lastMessageTimestamp: now,
            lastMessageSenderPubkey: _userPubkey,
            ownerPubkey: _userPubkey,
            dmProtocol: nextProtocol,
          );

          await _finalizeAfterRecipientSuccess(
            outgoingDao: dao,
            rumorId: rumorId,
            result: result,
          );
          persistedLocally = true;
        });

        // Guarded: the interlock's early return above skips the persist, and
        // logging success for it made the race read as a delivered-and-saved
        // message in field logs.
        if (persistedLocally) {
          Log.debug(
            'Recovered full send and persisted locally in conversation '
            '${row.conversationId}',
            category: LogCategory.system,
          );
        }
      } on Object catch (e, stackTrace) {
        Log.error(
          'Failed to persist recovered send locally for $rumorId: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Publish landed but local persistence failed — degraded
        // state. Don't rethrow: the caller still gets the success
        // result. The retry sweep will not pick this row up again
        // because the publish succeeded; missing local persistence
        // surfaces only as a sender-side gap until the self-wrap
        // arrives via the receive pipeline.
      }
    } else if (result.blocked) {
      // A confirmed policy block is terminal, not a transient error.
      // _finalizeAfterRecipientBlocked discards or retains the row per the
      // block's disposition, so the retry sweep stops re-attempting a send the
      // gate refuses every time. This attempt delivered nothing.
      await _finalizeAfterRecipientBlocked(
        outgoingDao: dao,
        rumorId: rumorId,
        result: result,
      );
    } else if (result.retryablePending) {
      // Soft retry: frame written with no OK yet, or a pre-publish wrap build
      // timeout while a human-gated signer approval may still be pending. Keep
      // the row pending (plain optimistic bubble, not a red failure) and let
      // the next sweep re-drive it; only bump the retry count so it eventually
      // exhausts.
      await _finalizeAfterRecipientUnconfirmed(
        outgoingDao: dao,
        rumorId: rumorId,
      );
    } else {
      await _finalizeAfterRecipientFailure(
        outgoingDao: dao,
        rumorId: rumorId,
        errorMessage: result.error ?? 'Unknown publish failure',
      );
    }

    return result;
  }

  /// Watches the durable outgoing DM queue for collaborator invites whose
  /// recipient delivery still needs recovery.
  ///
  /// Returns an empty stream when the queue DAO is not wired or the
  /// repository has not been scoped to an authenticated owner yet.
  Stream<List<PendingCollaboratorInviteGroup>>
  watchPendingCollaboratorInviteGroups() {
    final dao = _outgoingDmsDao;
    final ownerPubkey = _ownerPubkey;
    if (dao == null || ownerPubkey == null) {
      return Stream.value(const <PendingCollaboratorInviteGroup>[]);
    }

    return dao.watchAllForOwner(ownerPubkey).map((rows) {
      final pending = rows
          .map((row) => _tryParsePendingCollaboratorInvite(row, ownerPubkey))
          .whereType<PendingCollaboratorInvite>()
          .where((invite) => invite.requiresRecipientRecovery)
          .toList(growable: false);

      final grouped = <String, List<PendingCollaboratorInvite>>{};
      for (final invite in pending) {
        grouped.putIfAbsent(invite.videoAddress, () => []).add(invite);
      }

      final groups =
          grouped.entries
              .map((entry) {
                final invites = entry.value.toList(growable: false)
                  ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
                final first = invites.first;
                return PendingCollaboratorInviteGroup(
                  creatorPubkey: first.creatorPubkey,
                  videoAddress: first.videoAddress,
                  title: first.title,
                  thumbnailUrl: first.thumbnailUrl,
                  relayHint: first.relayHint,
                  invites: invites,
                );
              })
              .toList(growable: false)
            ..sort(
              (a, b) =>
                  b.invites.first.queuedAt.compareTo(a.invites.first.queuedAt),
            );

      return groups;
    });
  }

  /// Retries the given queued collaborator invites by replaying their original
  /// rumors through [recoverFullSend].
  Future<CollaboratorInviteRetrySummary> retryPendingCollaboratorInvites(
    Iterable<PendingCollaboratorInvite> invites,
  ) async {
    final matchingInvites = invites
        .where((invite) => invite.requiresRecipientRecovery)
        .toList(growable: false);
    if (matchingInvites.isEmpty) {
      return const CollaboratorInviteRetrySummary(
        attemptedCount: 0,
        successCount: 0,
        failureCount: 0,
      );
    }

    var attempted = 0;
    var success = 0;
    var blocked = 0;
    var failure = 0;
    for (final invite in matchingInvites) {
      attempted++;
      try {
        final result = await recoverFullSend(rumorId: invite.rumorId);
        if (result.success) {
          success++;
        } else if (result.blocked) {
          // A confirmed #176 policy block is terminal: recoverFullSend already
          // deleted the row, so the invite is neither delivered nor retryable.
          // Count it apart from transient failures so the banner does not
          // report a dropped row as "still needs to send".
          blocked++;
          Log.warning(
            'Collaborator invite blocked by policy for rumor '
            '${invite.rumorId} '
            '(recipient=${pubkeyForLogs(invite.collaboratorPubkey)}, '
            'video=${invite.videoAddress}); row dropped',
            category: LogCategory.system,
          );
        } else {
          failure++;
          Log.warning(
            'Collaborator invite retry failed for rumor ${invite.rumorId} '
            '(recipient=${pubkeyForLogs(invite.collaboratorPubkey)}, '
            'video=${invite.videoAddress}): ${result.error}',
            category: LogCategory.system,
          );
        }
      } on Object catch (error, stackTrace) {
        if (error is ArgumentError) {
          // recoverFullSend throws ArgumentError when the queue row is missing
          // or owned by another account. A concurrent drain sweep
          // recovering/deleting the row between the banner's read and this
          // retry is an expected race, not a defect — terminal for this
          // invite, so skip it without a Crashlytics report (mirrors
          // OutgoingDmRetryService's dispatch-error policy).
          Log.warning(
            'Skipping collaborator invite ${invite.rumorId}: $error',
            category: LogCategory.system,
          );
          continue;
        }
        failure++;
        Log.error(
          'Collaborator invite retry threw for rumor ${invite.rumorId} '
          '(recipient=${pubkeyForLogs(invite.collaboratorPubkey)}, '
          'video=${invite.videoAddress}): $error',
          category: LogCategory.system,
          error: error,
          stackTrace: stackTrace,
        );
        _errorReporter?.call(
          error,
          stackTrace,
          site: DmRepositoryReportableSites
              .retryPendingCollaboratorInviteUnexpectedThrow,
        );
      }
    }

    return CollaboratorInviteRetrySummary(
      attemptedCount: attempted,
      successCount: success,
      failureCount: failure,
      blockedCount: blocked,
    );
  }

  /// Finds queued collaborator invites for a specific video and retries the
  /// unresolved rows whose collaborator pubkeys match [collaboratorPubkeys].
  Future<CollaboratorInviteRetrySummary>
  retryPendingCollaboratorInvitesForVideo({
    required String videoAddress,
    Iterable<String> collaboratorPubkeys = const [],
  }) async {
    final groups = await watchPendingCollaboratorInviteGroups().first;
    final targetPubkeys = collaboratorPubkeys.toSet();
    final matchingInvites = groups
        .where((group) => group.videoAddress == videoAddress)
        .expand((group) => group.invites)
        .where((invite) {
          if (targetPubkeys.isEmpty) return true;
          return targetPubkeys.contains(invite.collaboratorPubkey);
        })
        .toList(growable: false);

    return retryPendingCollaboratorInvites(matchingInvites);
  }

  /// Cancel a queued outgoing DM: drop its `outgoing_dms` row so the failed
  /// bubble disappears and the retry sweep never re-drives it. The user's
  /// explicit "give up" on a send that keeps failing.
  ///
  /// Idempotent — a missing row (already delivered, already cancelled, or
  /// swept away) is a no-op returning `false`; returns `true` when a row
  /// was actually dropped. A replay already in flight for this row
  /// re-checks the row inside its success transaction ([recoverFullSend]),
  /// so a cancel that lands mid-publish does not resurrect the message
  /// locally. Throws [StateError] if the queue DAO is not wired in, and
  /// [ArgumentError] if the row belongs to a different account (never
  /// delete another identity's queued send).
  Future<bool> cancelOutgoingSend({required String rumorId}) async {
    _assertInitialized();
    final dao = _outgoingDmsDao;
    if (dao == null) {
      throw StateError(
        'cancelOutgoingSend requires the outgoing_dms queue DAO; '
        'wire OutgoingDmsDao into DmRepository before calling.',
      );
    }
    final row = await dao.getById(rumorId);
    if (row == null) return false;
    if (row.ownerPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'queue row belongs to a different account',
      );
    }
    await dao.deleteById(rumorId);
    return true;
  }

  /// Cancel every queued row of the send batch containing [rumorId] — the
  /// group-send counterpart of [cancelOutgoingSend], for deleting a message.
  ///
  /// A group send enqueues one row per recipient, all stamped with the same
  /// durable `sendBatchId` (the identity [sendGroupMessage] assigns and the
  /// recovery path dedups on). Deleting a partially delivered group bubble
  /// must drop ALL of them: the persisted bubble carries the first confirmed
  /// sibling's rumor id, whose own row is already gone, so cancelling just
  /// that id leaves pending and failed siblings for the retry sweep to
  /// re-publish — and a surviving delivered-awaiting-self-wrap row would
  /// re-persist the deleted message on the sender's own devices via the
  /// self-wrap recovery.
  ///
  /// [rumorId] may be a live queue row's id or the persisted batch winner's
  /// message id; the batch identity is resolved from whichever exists.
  /// Returns the number of rows dropped (`0` when nothing matched — already
  /// delivered everywhere, already cancelled, or not ours). A 1:1 row has no
  /// siblings and cancels exactly itself.
  ///
  /// Throws [StateError] if the queue DAO is not wired in, and
  /// [ArgumentError] if the queue row belongs to a different account (a
  /// foreign persisted message resolves to `0` instead, matching
  /// [deleteMessageForEveryone]'s sender-only contract enforced upstream).
  Future<int> cancelOutgoingBatch({required String rumorId}) async {
    _assertInitialized();
    final owner = _ownerPubkey!;
    final dao = _outgoingDmsDao;
    if (dao == null) {
      throw StateError(
        'cancelOutgoingBatch requires the outgoing_dms queue DAO; '
        'wire OutgoingDmsDao into DmRepository before calling.',
      );
    }

    final String conversationId;
    final int createdAt;
    final String content;
    // The durable batch id when available; null for a legacy (pre-column)
    // in-flight batch, which falls back to the `(createdAt, content)` tuple.
    final String? batchId;
    var row = await dao.getById(rumorId);
    if (row != null) {
      if (row.ownerPubkey != _userPubkey) {
        throw ArgumentError.value(
          rumorId,
          'rumorId',
          'queue row belongs to a different account',
        );
      }
      final pairParticipants = [_userPubkey, row.recipientPubkey]..sort();
      if (row.conversationId == computeConversationId(pairParticipants)) {
        // 1:1 rows have no siblings.
        await dao.deleteById(rumorId);
        return 1;
      }
      conversationId = row.conversationId;
      createdAt = row.createdAt;
      content = row.content;
      batchId = row.sendBatchId;
    } else {
      // No queue row — the bubble may be the persisted group winner whose
      // own row was deleted on confirm. Resolve the batch identity from the
      // persisted message instead.
      final message = await _directMessagesDao.getMessageById(
        rumorId,
        ownerPubkey: owner,
      );
      if (message != null) {
        if (message.senderPubkey != _userPubkey) return 0;
        conversationId = message.conversationId;
        createdAt = message.createdAt;
        content = message.content;
        batchId = message.sendBatchId;
      } else {
        // A queue-only group bubble exposes the shared wire rumor id, while
        // each durable row is keyed by its per-recipient queue handle. Resolve
        // one sibling from the stored rumor before expanding the whole batch.
        row = await dao.getByRumorId(
          rumorId: rumorId,
          ownerPubkey: _userPubkey,
        );
        if (row == null) return 0;
        conversationId = row.conversationId;
        createdAt = row.createdAt;
        content = row.content;
        batchId = row.sendBatchId;
      }
    }

    final rows = await dao.getForConversation(
      conversationId: conversationId,
      ownerPubkey: _userPubkey,
    );
    var cancelled = 0;
    for (final sibling in rows) {
      final isSibling = batchId != null
          ? sibling.sendBatchId == batchId
          : sibling.createdAt == createdAt && sibling.content == content;
      if (!isSibling) continue;
      await dao.deleteById(sibling.id);
      cancelled++;
    }
    return cancelled;
  }

  /// Apply the queue-row transition for a successful per-recipient
  /// rumor publish. Shared between [sendMessage] and [sendGroupMessage]
  /// so both call sites agree on the partial-vs-full delivery
  /// bookkeeping. The caller is responsible for invoking this inside
  /// the same transaction that persists the local message row.
  Future<void> _finalizeAfterRecipientSuccess({
    required OutgoingDmsDao outgoingDao,
    required String rumorId,
    required NIP17SendResult result,
  }) async {
    if (result.selfWrapPublished == true) {
      await outgoingDao.deleteById(rumorId);
    } else {
      await outgoingDao.markRecipientWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.sent,
        eventId: result.messageEventId,
      );
      await outgoingDao.markSelfWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: 'Recipient delivered, but self-wrap publish failed',
      );
      // The row survives with a retryable self-wrap — nudge the sweep.
      _notifyRetryableWork();
    }
  }

  /// Apply the queue-row transition for a failed per-recipient rumor
  /// publish. Shared between [sendMessage] and [sendGroupMessage] so
  /// both call sites keep recipient/self wrap failure bookkeeping in
  /// lockstep.
  Future<void> _finalizeAfterRecipientFailure({
    required OutgoingDmsDao outgoingDao,
    required String rumorId,
    required String errorMessage,
  }) async {
    try {
      await outgoingDao.markRecipientWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: errorMessage,
      );
      await outgoingDao.markSelfWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: errorMessage,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to mark outgoing_dms row failed for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      _errorReporter?.call(
        e,
        stackTrace,
        site: DmRepositoryReportableSites.finalizeAfterRecipientFailure,
      );
      // Don't rethrow — caller already gets the failure result. The
      // queue row stays retryable and the next sweep can pick it up.
    } finally {
      // Whether the marks landed or threw, the row is still retryable —
      // nudge the sweep so it converges without a foreground flip.
      _notifyRetryableWork();
    }
  }

  /// Apply the terminal queue-row transition for a policy-blocked recipient.
  ///
  /// Protected-minor refusals discard the row because the intent must not
  /// remain visible. A retired moderation recipient retains it in the
  /// non-retryable `blocked` state because the row is the sender's only copy.
  /// Non-rethrowing to match the failure path: the caller still receives the
  /// blocked result when the durable transition fails.
  Future<void> _finalizeAfterRecipientBlocked({
    required OutgoingDmsDao outgoingDao,
    required String rumorId,
    required NIP17SendResult result,
  }) async {
    try {
      if (result.blockedDisposition == NIP17BlockedSendDisposition.retain) {
        await outgoingDao.markRecipientBlocked(
          id: rumorId,
          lastError: result.error ?? 'Blocked by send policy',
        );
      } else {
        await outgoingDao.deleteById(rumorId);
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to terminalize blocked outgoing_dms row $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      _errorReporter?.call(
        e,
        stackTrace,
        site: DmRepositoryReportableSites.finalizeAfterRecipientBlocked,
      );
    }
  }

  /// Apply the queue-row transition for a soft, retryable-pending failure: an
  /// inconclusive recipient publish (frame written, no NIP-20 `OK`, no explicit
  /// rejection) or a bounded pre-publish wrap build timeout where a human-gated
  /// signer approval may still be pending. The row stays `pending` (rendering
  /// as a plain optimistic bubble, never a red failure) and the retry sweep
  /// re-drives it.
  ///
  /// Only `incrementRetry` runs: it records the attempt timestamp so the
  /// next sweep applies backoff, and counts this attempt toward the retry
  /// budget so a permanently-unconfirmable send eventually exhausts to a
  /// terminal `failed` state instead of retrying forever. Deliberately does
  /// NOT mark either wrap `failed` (that is the hard-failure path) and does
  /// NOT delete the row (that is the terminal-blocked path). Non-rethrowing:
  /// the caller already has the retryable-pending result.
  Future<void> _finalizeAfterRecipientUnconfirmed({
    required OutgoingDmsDao outgoingDao,
    required String rumorId,
  }) async {
    try {
      await outgoingDao.incrementRetry(rumorId);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to record unconfirmed attempt for outgoing_dms row '
        '$rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      _errorReporter?.call(
        e,
        stackTrace,
        site: DmRepositoryReportableSites.finalizeAfterRecipientUnconfirmed,
      );
      // Don't rethrow — the row stays pending and the next sweep re-drives
      // it; a missed retry-count bump only means one extra retry.
    } finally {
      // The row stays pending either way — nudge the sweep so a
      // soft-unconfirmed send converges without a foreground flip.
      _notifyRetryableWork();
    }
  }

  /// Wrap [NIP17MessageService.sendRumor] with a hard [_messagePublishTimeout]
  /// backstop so a truly hung await (stalled socket, wedged signer) surfaces
  /// as a soft, retryable-pending failure instead of pending forever. Shared
  /// by [sendMessage], [recoverFullSend], and [sendGroupMessage] so all three
  /// publish paths share one timeout and classification discipline. Note
  /// `Future.timeout` does NOT cancel the underlying publish — it may still
  /// land after the cap, which is why the timeout result is classified
  /// retryable-pending (receiver-side rumor-id dedup absorbs the overlap).
  Future<NIP17SendResult> _sendRumorWithTimeout({
    required Event rumor,
    required String recipientPubkey,
    List<String>? targetRelays,
    List<String>? selfWrapTargetRelays,
    bool awaitRecipientOk = false,
  }) {
    return _messageService!
        .sendRumor(
          rumorEvent: rumor,
          recipientPubkey: recipientPubkey,
          targetRelays: targetRelays,
          selfWrapTargetRelays: selfWrapTargetRelays,
          awaitRecipientOk: awaitRecipientOk,
          // A soft-unconfirmed message send must NOT publish the self-wrap:
          // the durable queue replays the full send until the recipient wrap
          // confirms (publishing both wraps then), while a soft self-wrap
          // that lands echoes back through the receive pipeline and persists
          // a sent-looking row for a message the recipient may never have
          // received (#6046). Reactions keep the service default.
          selfWrapOnSoftUnconfirmed: false,
        )
        .timeout(
          _messagePublishTimeout,
          onTimeout: () => NIP17SendResult.failure(
            'Message publish timed out after '
            '${_messagePublishTimeout.inSeconds}s',
            retryablePending: true,
          ),
        );
  }

  PendingCollaboratorInvite? _tryParsePendingCollaboratorInvite(
    OutgoingDm row,
    String ownerPubkey,
  ) {
    try {
      final json = jsonDecode(row.rumorEventJson);
      if (json is! Map<String, dynamic>) return null;
      final rumorEvent = Event.fromJson(json);
      final metadata = parseCollaboratorInviteRumor(rumorEvent);
      if (metadata == null || metadata.creatorPubkey != ownerPubkey) {
        return null;
      }

      return PendingCollaboratorInvite(
        rumorId: row.id,
        collaboratorPubkey: row.recipientPubkey,
        creatorPubkey: metadata.creatorPubkey,
        videoAddress: metadata.videoAddress,
        title: metadata.title,
        thumbnailUrl: metadata.thumbnailUrl,
        relayHint: metadata.relayHint,
        recipientWrapStatus: row.recipientWrapStatus,
        selfWrapStatus: row.selfWrapStatus,
        retryCount: row.retryCount,
        queuedAt: row.queuedAt,
        lastError: row.recipientWrapLastError ?? row.selfWrapLastError,
      );
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Skipping outgoing_dms row ${row.id}; failed to parse '
        'collaborator invite rumor JSON: $error\n$stackTrace',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Send a text message to a group conversation.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if any pubkey in [recipientPubkeys] is not
  /// a 64-character hex string, if [content] is empty, or if
  /// [recipientPubkeys] is empty.
  ///
  /// Returns failure results, publishing nothing, when every recipient is the
  /// sender. One result is returned for each supplied recipient.
  ///
  /// When an [OutgoingDmsDao] is injected, each per-recipient send
  /// goes through the durable queue with the same atomicity contract
  /// as [sendMessage]: enqueue a `pending`/`pending` row keyed by a
  /// per-recipient queue handle, publish, then transition the row by wrap
  /// outcome (full delivery → row deleted in the same transaction
  /// that inserts `direct_messages`; partial delivery → recipient
  /// `sent` + self `failed` so the recovery path can replay only the
  /// missing self-wraps without re-delivering to recipients).
  ///
  /// Each failure that leaves a row behind carries that row's
  /// [NIP17SendResult.queuedRumorId], so a caller retries by re-driving the
  /// surviving siblings ([recoverFullSend]) rather than fanning out again.
  ///
  /// If a sibling enqueue fails before any publish starts, the whole batch is
  /// failed and the siblings already parked are best-effort deleted. Any row
  /// that cannot be deleted is returned with its `queuedRumorId` so retry can
  /// re-drive the surviving parked rumor instead of minting a fresh fan-out.
  @useResult
  Future<List<NIP17SendResult>> sendGroupMessage({
    required List<String> recipientPubkeys,
    required String content,
    String? replyToId,
    List<List<String>> additionalTags = const [],
  }) async {
    _assertInitialized();
    if (recipientPubkeys.isEmpty) {
      throw ArgumentError.value(
        recipientPubkeys,
        'recipientPubkeys',
        'must not be empty',
      );
    }
    recipientPubkeys.forEach(validatePubkey);
    if (content.trim().isEmpty) {
      throw ArgumentError.value(content, 'content', 'must not be empty');
    }

    // Divine does not support a self-addressed conversation (#8351, decided on
    // #8261). [sendMessage] and the file path already refuse one; this path did
    // not, so a group whose only recipient was the sender still published a
    // wrap the app cannot read back — the receive path drops a participant list
    // that collapses to one pubkey (#2824) — and that nobody can delete, since
    // funnelcake matches a kind-5 against the wrap's throwaway ephemeral author
    // rather than the real sender (#8699).
    //
    // Returned rather than thrown, and one result per recipient, matching the
    // send gate below: callers branch on `success` per recipient.
    //
    // Only the self-ONLY case is refused. Whether a group send keeps its sender
    // in the recipient list is an open product decision (#8359), so a group
    // that also carries real recipients is left exactly as it was. Note
    // `recipientPubkeys` is non-empty by the guard above, so `every` cannot be
    // vacuously true here.
    if (recipientPubkeys.every(_isSelf)) {
      return [
        for (final _ in recipientPubkeys)
          const NIP17SendResult.failure(
            'refused: a message cannot be addressed to its own sender',
          ),
      ];
    }

    // Send gate (#176) — group all-or-nothing: a restricted sender (protected
    // minor) may only message a group where EVERY recipient is approved.
    // Per-recipient gating in sendRumor alone would still deliver to the
    // approved participants, so an attacker could p-tag the minor with a pinned
    // decoy to slip content to the rest. Refuse the whole send if any recipient
    // is blocked — before building or enqueuing anything.
    for (final pubkey in recipientPubkeys) {
      if (!await _messageService!.canSendTo(pubkey)) {
        return [
          for (final _ in recipientPubkeys)
            const NIP17SendResult.blocked(
              'blocked: group contains a non-approved recipient',
            ),
        ];
      }
    }

    final participants = [_userPubkey, ...recipientPubkeys]..sort();
    final conversationId = computeConversationId(participants);
    final outgoingDao = _outgoingDmsDao;

    // Resolve every recipient's kind-10050 DM inbox concurrently BEFORE the
    // per-recipient send loop. Each wrap must route to its own recipient's
    // inbox (NIP-17), and OK-confirm below is only meaningful against that
    // inbox. Doing this up front (rather than one await per loop iteration)
    // keeps N sequential ~5s inbox queries from stacking and delaying the
    // visible group bubble. Resolution never throws (it degrades to null →
    // default pool), so a failed lookup just falls back.
    //
    // Resolved through the DETAILED reader: routing only needs the relays, but
    // this fan-out also REPORTS delivery, and `absent` and `unreadable` both
    // route to the pool while meaning opposite things (#8434). Kept per
    // recipient rather than collapsed to one batch verdict because NIP-17
    // states the rule per recipient — "the relays listed in the recipient's
    // kind 10050 event" (17.md:77) — and the queue already holds one row per
    // member, so a readable sibling stays genuinely delivered.
    final inboxByRecipient = <String, DmInboxLookup>{};
    await Future.wait([
      for (final pubkey in recipientPubkeys)
        resolveDmInboxRelaysDetailed(
          pubkey,
        ).then((inbox) => inboxByRecipient[pubkey] = inbox),
    ]);

    // One destination for every self-copy in the batch — it is addressed to
    // the sender, not to a recipient, so it does not vary per wrap.
    final selfWrapRelays = await _selfWrapTargetRelays();

    // Per-recipient durable handle for the queue row. The wire rumor is shared
    // across the batch, so the rumor id alone can no longer key a row: the
    // queue tracks per-recipient delivery, and `enqueue` is `insertOrIgnore`,
    // which would silently discard the siblings WITHOUT throwing. Composed
    // rather than migrated because nothing reads this column's format — see
    // [_groupQueueId].
    final queueIds = <String>[];
    final results = <NIP17SendResult>[];

    // Durable, collision-proof identity for this whole fan-out, minted BEFORE
    // any rumor is built. A rumor's event id is
    // sha256([0, pubkey, created_at(seconds), kind, tags, content]) with no
    // nonce, so two group sends of identical text in the SAME Unix second
    // would otherwise build byte-identical rumors: identical event ids ⇒
    // identical queue-row PKs (`OutgoingDm.id`, enqueued with insertOrIgnore
    // so the second is silently dropped) ⇒ identical `full:<queueId>` recovery
    // locks (the second publish joins the first) ⇒ identical batch id (the
    // persist dedup drops the second local message). The user's second send
    // would vanish from the queue, local history, AND recipients. Deriving the
    // batch id from the rumor's own id would inherit that same-second
    // collision — and since #8188 the whole batch shares ONE rumor id, so the
    // rumor can no longer distinguish two invocations at all.
    //
    // Instead this token is independent secure random, and it is injected into
    // the batch's one rumor (a client-internal `batch` tag, below) so each
    // invocation's wire events — and therefore their ids, queue-row handles,
    // and recovery locks — are unique even at same-second identical text. The
    // same value is stamped verbatim on every sibling queue row AND the batch's
    // one persisted local message, so persistence dedup, optimistic grouping,
    // sibling lookup, and cancellation all match a batch by one exact stored
    // value. The token rides inside the encrypted gift-wrapped rumor (only the
    // recipient and the sender's own self-wrap ever decrypt it) and is random,
    // so it discloses nothing.
    final sendBatchId = _newSendBatchId();

    // ONE rumor for the whole fan-out, wrapped once per recipient (#8188).
    // NIP-59 59.md:108 permits exactly this — "a single `rumor` may be wrapped
    // and addressed for each recipient individually" — and it is what every
    // shipping group-DM client does. It is also already the shape of this
    // repository's OWN kind-5 deletions (`_fanOutDeletion`) and kind-7
    // reactions (`DmReactionsRepository._fanOutRumor`); kind-14/15 messages
    // were the outlier.
    //
    // Building one rumor per recipient forked the id: `buildRumor` prepends
    // `['p', recipientPubkey]`, so each sibling carried the same p-tag SET in a
    // rotated ORDER, and a NIP-01 id hashes the tags array. A retraction can
    // name only one id, so delete-for-everyone reached exactly one participant;
    // a reaction naming one sibling was never persisted by the others at all.
    //
    // The batch token still separates two whole invocations of identical text
    // in the same second (#6046) — it is one shared tag, so it does not
    // re-fork the id within a batch.
    final batchCreatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final groupRumor = _messageService!.buildGroupRumor(
      recipientPubkeys: recipientPubkeys,
      content: content,
      additionalTags: <List<String>>[
        ...additionalTags,
        if (replyToId != null) ['e', replyToId],
        [_sendBatchTagKey, sendBatchId],
      ],
      createdAt: batchCreatedAt,
    );
    // Same pre-enqueue refusal as [sendMessage] (#7331), and the reason the
    // bound is on the rumor rather than the body: a group rumor carries one
    // `p` tag per recipient, so its usable body shrinks as the group grows
    // while this ceiling stays put.
    final oversized = _refuseIfOversized(groupRumor);
    if (oversized != null) {
      return [for (final _ in recipientPubkeys) oversized];
    }

    for (final recipient in recipientPubkeys) {
      queueIds.add(_groupQueueId(groupRumor.id, recipient));
    }

    // Enqueue every sibling before publish so an app crash mid-send leaves a
    // recoverable trace per recipient, and all N optimistic bubbles' rows
    // exist before the first (potentially slow) publish. Same contract as
    // sendMessage: no-op when the queue dao isn't wired in (older test
    // fixtures, NIP-04-only callers).
    // `enqueue` swallows PK conflicts but still throws on a real write error
    // (SQLite BUSY/LOCKED — OutgoingDmRetryService writes this table
    // concurrently). Because every sibling is queued before any publish, an
    // enqueue failure can still be made atomic from the user's perspective:
    // unwind rows already parked, skip publish entirely, and return failures
    // for the whole batch. If a parked row cannot be deleted, stamp that row's
    // id onto its failure so retry re-drives the surviving rumor instead of
    // minting a duplicating fresh fan-out (#7316).
    if (outgoingDao != null) {
      for (var i = 0; i < recipientPubkeys.length; i++) {
        final queueId = queueIds[i];
        try {
          await outgoingDao.enqueue(
            OutgoingDm(
              id: queueId,
              conversationId: conversationId,
              recipientPubkey: recipientPubkeys[i],
              content: content,
              createdAt: groupRumor.createdAt,
              rumorEventJson: jsonEncode(groupRumor.toJson()),
              messageKind: groupRumor.kind,
              replyToId: replyToId,
              recipientWrapStatus: OutgoingWrapStatus.pending,
              selfWrapStatus: OutgoingWrapStatus.pending,
              queuedAt: DateTime.now(),
              ownerPubkey: _userPubkey,
              sendBatchId: sendBatchId,
            ),
          );
        } on Object catch (e, stackTrace) {
          _errorReporter?.call(
            e,
            stackTrace,
            site: DmRepositoryReportableSites.sendGroupMessageEnqueueSibling,
          );

          final failure = NIP17SendResult.failure(
            'could not queue send for recipient: $e',
          );
          final unwindResults = List<NIP17SendResult>.filled(
            recipientPubkeys.length,
            failure,
          );
          for (var j = 0; j < i; j++) {
            final parkedRumorId = queueIds[j];
            try {
              await outgoingDao.deleteById(parkedRumorId);
            } on Object catch (deleteError, deleteStackTrace) {
              _errorReporter?.call(
                deleteError,
                deleteStackTrace,
                site: DmRepositoryReportableSites
                    .sendGroupMessageUnwindQueuedSibling,
              );
              unwindResults[j] = _stampQueuedRow(failure, parkedRumorId);
            }
          }
          // A row that survived the unwind still holds the user's message, so
          // a brand-new group thread must be visible for them to reach that
          // bubble and retry or delete it — the same reason the publish-failure
          // path below surfaces one. A fully unwound batch leaves no row and
          // must not resurrect a thread.
          if (unwindResults.any((r) => r.queuedRumorId != null)) {
            await _ensureConversationVisibleAfterSendFailure(
              conversationId: conversationId,
              participants: participants,
              isGroup: true,
              content: content,
            );
          }
          return unwindResults;
        }
      }
    }

    // Delivery below is per-recipient and NOT atomic: a mid-loop publish
    // failure can leave the group partially delivered. That is a reliability/UX
    // concern only, not a safety leak for the #176 restriction — the
    // all-or-nothing gate above already guarantees EVERY recipient is approved,
    // so a partial send can only ever reach approved recipients, never a
    // blocked one.
    // Siblings whose queue row was deleted (cancelOutgoingBatch, reachable
    // via long-press delete on the pending bubble) before this loop reached
    // them. Recorded so the finalize below skips them too — a cancelled
    // index must never resurrect a queue transition or a thread.
    final cancelledBeforePublish = <int>{};
    // Siblings whose outcome came from a recovery another caller already
    // owned — the sweep's recoverFullSend registered `full:<queueId>` before
    // this loop reached the row. That owner finalized the row inside its
    // locked body, so the non-success pass below must not run the same
    // transition again: a second _finalizeAfterRecipientUnconfirmed charged
    // one underlying attempt twice, and a five-retry budget then covered four
    // attempts (#8619). Only the durable handle is stamped for these.
    final joinedRecovery = <int>{};
    for (var i = 0; i < recipientPubkeys.length; i++) {
      final pubkey = recipientPubkeys[i];
      // Cancel interlock, mirroring _recoverFullSendLocked's pre-publish row
      // re-read: each publish can take up to the OK-confirm timeout, a long
      // window in which the user may delete the whole batch. Re-read the
      // sibling row immediately before publishing; if it is gone, record a
      // non-success and skip the publish entirely. Otherwise this rumor would
      // reach the recipient after the sender cancelled — invisible to the
      // sender and unretractable, since no local row survives to build a
      // kind-5 from. The currently-publishing sibling's inherent TOCTOU is
      // accepted, the same trade-off as recoverFullSend.
      if (outgoingDao != null &&
          await outgoingDao.getById(queueIds[i]) == null) {
        cancelledBeforePublish.add(i);
        results.add(
          const NIP17SendResult.failure('send cancelled before publish'),
        );
        continue;
      }
      // Coalesce through the recovery lock: the sequential publishes of a
      // group send can outlive the retry sweep's interrupted-send min-age
      // (all sibling rows share the batch queuedAt), so a sweep
      // recoverFullSend for this rumor may fire while THIS publish is still
      // in flight. Registering the publish under the same per-rumor key
      // makes the sweep JOIN the live attempt instead of dispatching a
      // concurrent duplicate. The reverse interleaving (sweep registered
      // first) hands back the recovery's real outcome, and the persistence
      // transaction below dedups on it. That reverse interleaving is the
      // common one once a sweep overlaps a batch at all: after both sides
      // resume from a joined sibling, this loop still has to re-read the next
      // row before it can register, while the sweep registers synchronously.
      // A joined recovery can throw (ArgumentError after a mid-flight cancel);
      // convert it to a plain failure so one bad join cannot abort the rest of
      // the batch — _sendRumorWithTimeout itself classifies instead of
      // throwing.
      NIP17SendResult result;
      final inbox = inboxByRecipient[pubkey];
      // Set only when this call runs the attempt; a join never invokes the
      // closure, so the flag is exact.
      var attemptRanHere = false;
      try {
        result = await _joinOrStartRecovery('full:${queueIds[i]}', () async {
          attemptRanHere = true;
          final published = await _sendRumorWithTimeout(
            rumor: groupRumor,
            recipientPubkey: pubkey,
            targetRelays: inbox?.relays,
            selfWrapTargetRelays: selfWrapRelays,
            awaitRecipientOk: true,
          );
          // An `OK` from the DEFAULT POOL is not delivery for a recipient
          // whose inbox we never read: their wrap may sit on relays they never
          // query, and finalizing this sibling deletes the one handle that
          // could re-resolve and republish it (#8434). Per recipient, because
          // the batch holds one queue row per member — a sibling we DID reach
          // on its advertised inbox is still genuinely delivered.
          //
          // Applied INSIDE the closure, not around the join. A second entrant
          // does not run this attempt; it awaits an in-flight recovery that
          // resolved its own inbox and already applied this same rule. Judging
          // that outcome out here would re-judge it against this send's older
          // snapshot, and could hold a wrap that did reach the advertised
          // inbox.
          //
          // Only when the queue is wired, mirroring `sendMessage`: with no row
          // to preserve there is nothing to gain, and downgrading every
          // sibling would leave `results.any(success)` false, skipping the
          // local persist that puts the message in the sender's own thread.
          return outgoingDao == null || inbox == null
              ? published
              : downgradeFallbackPoolDelivery(published, inbox.state);
        });
      } on Object catch (e) {
        result = NIP17SendResult.failure(
          'joined in-flight recovery failed: $e',
        );
      }
      if (!attemptRanHere) joinedRecovery.add(i);
      results.add(result);
    }

    // If at least one send succeeded, persist locally (atomically). The
    // per-recipient queue updates for successful tuples ride inside the
    // same transaction so a watcher never observes a window where the
    // message is in neither table — and partial deliveries preserve
    // the retry row for the recovery path.
    if (results.any((r) => r.success)) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final localTags = <List<String>>[
        ...additionalTags,
        for (final pk in recipientPubkeys) ['p', pk],
        if (replyToId != null) ['e', replyToId],
      ];

      await _conversationsDao.runInTransaction(() async {
        // Cancel interlock (mirrors _recoverFullSendLocked, per successful
        // sibling): the user may have deleted the whole batch
        // (cancelOutgoingBatch) while the sequential per-recipient publishes
        // were still running. Successful tuples whose queue row is gone must
        // not be persisted or finalized; if none survive, persist nothing —
        // the wire copies are out, receiver dedup keeps them single, but the
        // local message must not resurrect.
        final liveSuccessIndexes = <int>[];
        for (var i = 0; i < results.length; i++) {
          if (!results[i].success) continue;
          if (outgoingDao != null &&
              await outgoingDao.getById(queueIds[i]) == null) {
            continue;
          }
          liveSuccessIndexes.add(i);
        }
        if (liveSuccessIndexes.isEmpty) {
          Log.info(
            'Group publish landed after every successful sibling row was '
            'already removed (cancelled mid-flight, or finalized by a '
            'concurrent recovery); skipping local persist for conversation '
            '$conversationId.',
            category: LogCategory.system,
          );
          return;
        }

        // Sibling dedup (same guard as _recoverFullSendLocked): a group
        // send's sequential publishes can outlive the retry sweep's
        // interrupted-send min-age, so the sweep may recover a sibling and
        // persist the batch's ONE local message first. Match on the durable
        // batch id, not a content/timestamp window — two distinct sends of
        // the same text carry different batch ids even in the same second.
        final alreadyPersisted =
            outgoingDao != null &&
            await _directMessagesDao.hasMessageWithSendBatchId(
              batchId: sendBatchId,
              ownerPubkey: _userPubkey,
            );

        // Key the insert off the first LIVE success so a cancelled sibling's
        // giftWrapId does not land in storage. If cancellation removed every
        // success, there is no local message to persist.
        final firstLiveSuccess = results[liveSuccessIndexes.first];
        if (!alreadyPersisted) {
          await _directMessagesDao.insertMessage(
            id: firstLiveSuccess.rumorEventId!,
            conversationId: conversationId,
            senderPubkey: _userPubkey,
            content: content,
            // The rumor's canonical batch timestamp, NOT confirm-time `now`:
            // the optimistic bubble sorts by rumor.createdAt, so stamping the
            // persisted row with a later time made the bubble jump on
            // confirm.
            createdAt: batchCreatedAt,
            giftWrapId: firstLiveSuccess.messageEventId!,
            replyToId: replyToId,
            tagsJson: localTags.isEmpty ? null : jsonEncode(localTags),
            ownerPubkey: _userPubkey,
            // Stamp the persisted row with the batch id so the recovery path
            // (and a racing sibling) dedup against it by exact match.
            sendBatchId: sendBatchId,
          );
        }

        final existingGroup = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _userPubkey,
        );
        await _upsertSentConversationAndMarkRead(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: true,
          createdAt: existingGroup?.createdAt ?? now,
          lastMessageContent: content,
          lastMessageTimestamp: now,
          lastMessageSenderPubkey: _userPubkey,
          ownerPubkey: _userPubkey,
          dmProtocol: existingGroup?.dmProtocol,
        );

        if (outgoingDao != null) {
          for (final i in liveSuccessIndexes) {
            await _finalizeAfterRecipientSuccess(
              outgoingDao: outgoingDao,
              rumorId: queueIds[i],
              result: results[i],
            );
            results[i] = _stampQueuedRow(results[i], queueIds[i]);
          }
        }
      });
    }

    // Per-recipient non-success finalize. Lives outside the success
    // transaction, mirroring sendMessage's split: a non-success tuple has
    // nothing to atomically tie a queue update to (no message row insert).
    // Classify each the same way the 1:1 path does — soft-unconfirmed stays
    // pending (plain optimistic bubble), a policy block is terminal (row
    // discarded or retained per disposition), and a hard failure marks both
    // wraps failed.
    //
    // The two surviving-row branches also stamp their sibling's queued rumor
    // id onto the returned result, exactly as [sendMessage] does. Without it
    // a group caller has no handle on the rows this send parked and its only
    // way to "retry" is a fresh fan-out, which mints a whole second set of
    // rumors the receiver cannot collapse (#7316). Cancelled and blocked
    // siblings are deliberately unstamped: a cancelled sibling leaves no row,
    // and a blocked sibling is terminal (retained or discarded) and must never
    // be handed back for retry.
    if (outgoingDao != null) {
      for (var i = 0; i < queueIds.length; i++) {
        // A sibling skipped for cancellation has no live row to transition; an
        // update-by-id would match zero rows anyway, but skipping is explicit
        // and keeps such an index from resurrecting a queue transition or a
        // thread.
        if (cancelledBeforePublish.contains(i)) {
          continue;
        }
        final result = results[i];
        if (result.success) continue;
        // A joined outcome was finalized by the recovery that owns it
        // (#8619): charging, failure marks and the blocked disposition are
        // all that owner's. Stamp the handle exactly as the surviving-row
        // branches below do, so the caller can still re-drive the row.
        if (joinedRecovery.contains(i)) {
          if (!result.blocked) {
            results[i] = _stampQueuedRow(result, queueIds[i]);
          }
          continue;
        }
        if (result.blocked) {
          await _finalizeAfterRecipientBlocked(
            outgoingDao: outgoingDao,
            rumorId: queueIds[i],
            result: result,
          );
        } else if (result.retryablePending) {
          await _finalizeAfterRecipientUnconfirmed(
            outgoingDao: outgoingDao,
            rumorId: queueIds[i],
          );
          results[i] = _stampQueuedRow(result, queueIds[i]);
        } else {
          await _finalizeAfterRecipientFailure(
            outgoingDao: outgoingDao,
            rumorId: queueIds[i],
            errorMessage: result.error ?? 'Unknown publish failure',
          );
          results[i] = _stampQueuedRow(result, queueIds[i]);
        }
      }
    }

    // No recipient succeeded but retryable rows exist: make sure a
    // brand-new group thread is visible in the inbox so the user can find
    // the failed bubbles to retry or delete. All-blocked sends leave no
    // rows behind (terminal), so they create no thread cruft. A fully
    // cancelled batch must NOT resurrect the thread the user just deleted,
    // so cancelled indexes don't count as retryable failures here.
    final hasRetryableFailure = results.asMap().entries.any(
      (entry) =>
          !cancelledBeforePublish.contains(entry.key) && !entry.value.blocked,
    );
    if (!results.any((r) => r.success) && hasRetryableFailure) {
      await _ensureConversationVisibleAfterSendFailure(
        conversationId: conversationId,
        participants: participants,
        isGroup: true,
        content: content,
      );
    }

    return results;
  }

  // -------------------------------------------------------------------------
  // Delete (NIP-09 Kind 5)
  // -------------------------------------------------------------------------

  /// Delete a sent message for everyone via NIP-09 kind 5.
  ///
  /// The kind-5 travels as a **NIP-17 rumor inside a kind-1059 gift wrap**
  /// addressed to each participant (`17.md:87`), not as a bare event on the
  /// public pool. The bare form named the counterparty in a plaintext `p` tag
  /// alongside a real timestamp and the rumor kind, which defeats NIP-17's
  /// first stated benefit (`17.md:97`) — and NIP-09 tells relays to keep
  /// deletion requests indefinitely (`09.md:33`), so each one was a permanent
  /// public record that these two pubkeys had a conversation (#7341).
  ///
  /// Returns once the deletion is **durable**, not once it is delivered. The
  /// row is soft-deleted and the rumor stored in one write; delivery is
  /// re-driven by the retry sweep until a relay confirms it, so a publish that
  /// reaches nobody can no longer be reported as a completed retraction
  /// (#8165).
  ///
  /// Only the sender of [rumorId] may delete it (NIP-09 requirement).
  ///
  /// Throws [StateError] if not initialized.
  /// Throws [ArgumentError] if the message doesn't exist, the current user is
  /// not the sender, or the conversation names no other participant to
  /// deliver to.
  Future<void> deleteMessageForEveryone(String rumorId) async {
    _assertInitialized();
    final owner = _ownerPubkey!;

    final row = await _directMessagesDao.getMessageById(
      rumorId,
      ownerPubkey: owner,
    );
    if (row == null) {
      throw ArgumentError.value(rumorId, 'rumorId', 'message not found');
    }
    if (row.senderPubkey != _userPubkey) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'only the sender can delete a message',
      );
    }

    // Already retracted — stop before the signer round trip. `getMessageById`
    // has no `isDeleted` predicate (the row is kept as dedup evidence), so
    // without this a repeat delete of the same rumor sails through both
    // checks above and signs + publishes a SECOND kind 5. That is reachable
    // from the UI: the bubble only disappears once this method finishes, so
    // a user who taps Delete and still sees the bubble taps it again.
    if (row.isDeleted) {
      Log.info(
        'Message $rumorId already deleted — skipping duplicate kind 5',
        category: LogCategory.system,
      );
      return;
    }

    final recipients = await _deletionWrapRecipients(row.conversationId);
    if (recipients.isEmpty) {
      throw ArgumentError.value(
        rumorId,
        'rumorId',
        'no recipient to deliver the deletion to',
      );
    }

    // `k` names the kind of the event being deleted (NIP-09 09.md:9), so it
    // reads the row rather than assuming 14 — a kind-15 file message was
    // previously mislabelled on the wire.
    final deletion = _messageService!.buildRumor(
      recipientPubkey: recipients.first,
      content: '',
      eventKind: EventKind.eventDeletion,
      additionalTags: [
        ['e', rumorId],
        ['k', row.messageKind.toString()],
      ],
    );

    // Durability boundary. One write hides the bubble AND stores the rumor,
    // so a crash in between cannot leave a message the user believes retracted
    // with nothing left to deliver. Everything after this point is recoverable
    // by the retry sweep.
    await _directMessagesDao.markMessageDeletionPending(
      rumorId,
      deletionRumorJson: jsonEncode(deletion.toJson()),
      ownerPubkey: owner,
    );
    _notifyRetryableWork();

    await _refreshConversationPreview(row.conversationId);

    // First attempt is unawaited: the caller returns as soon as the deletion
    // is durable, and a slow or offline wire never blocks the UI. A failure
    // here leaves the row `deletion_pending` for the sweep.
    unawaited(
      _driveMessageDeletion(
        rumorId: rumorId,
        conversationId: row.conversationId,
        deletion: deletion,
        recipients: recipients,
      ),
    );
  }

  /// Every other participant of [conversationId] — the gift-wrap recipients
  /// for a deletion.
  ///
  /// Resolved from the conversation's participant set rather than the
  /// message's own author, which for an own message is this user. Mirrors
  /// `DmReactionsRepository._resolveWrapRecipients`.
  Future<List<String>> _deletionWrapRecipients(String conversationId) async {
    final conversation = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
    if (conversation == null) return const [];
    try {
      final decoded = jsonDecode(conversation.participantPubkeys);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .where((p) => p != _userPubkey)
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  /// Deliver [deletion] to every recipient as a NIP-17 gift wrap and settle
  /// the row when the outcome is terminal.
  ///
  /// `awaitRecipientOk: true` requires a relay's NIP-20 `OK true` rather than
  /// a bare frame-accept, which is what makes the stored status honest: a
  /// wrap the relay never took leaves the row pending for the sweep instead
  /// of reporting the message retracted (#8165).
  Future<DmMessageDeletionOutcome> _driveMessageDeletion({
    required String rumorId,
    required String conversationId,
    required Event deletion,
    required List<String> recipients,
  }) async {
    try {
      final (:result, :anyRecipientAccepted) = await _fanOutDeletion(
        deletion: deletion,
        recipients: recipients,
      );
      switch (result) {
        case NIP17SendSuccess():
          await _directMessagesDao.markMessageDeletionSent(
            rumorId,
            ownerPubkey: _ownerPubkey,
          );
          Log.info(
            'Deleted message $rumorId via wrapped kind 5',
            category: LogCategory.system,
          );
          return DmMessageDeletionOutcome.sent;
        case NIP17SendFailure(:final error, :final blocked):
          if (blocked) {
            // Until every recipient confirms, keep the sender's recognizable
            // bubble in the thread with failed-retraction styling. This is
            // also honest for a mixed fan-out: the UI says only that deletion
            // for everyone was not confirmed, not who still has it (#8201).
            await _directMessagesDao.markMessageDeletionBlocked(
              rumorId,
              restoreToThread: true,
              ownerPubkey: _ownerPubkey,
            );
            try {
              await _refreshConversationPreview(conversationId);
            } on Object catch (e, stackTrace) {
              // The durable outcome is already blocked. A denormalized
              // preview failure must not relabel it unconfirmed and invite
              // retries.
              Log.error(
                'Failed to restore conversation preview after blocked '
                'deletion of $rumorId: $e',
                category: LogCategory.system,
                error: e,
                stackTrace: stackTrace,
              );
            }
            Log.info(
              'Deletion of $rumorId refused by send policy; not retrying '
              '(partiallyDelivered=$anyRecipientAccepted)',
              category: LogCategory.system,
            );
            return DmMessageDeletionOutcome.blocked;
          }
          Log.warning(
            'Deletion of $rumorId unconfirmed ($error); left for the sweep',
            category: LogCategory.system,
          );
          return DmMessageDeletionOutcome.unconfirmed;
      }
    } on Object catch (e, stackTrace) {
      // Leave the row pending: an exception here is exactly the case the
      // durable row exists for.
      Log.error(
        'Deletion drive threw for $rumorId: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return DmMessageDeletionOutcome.unconfirmed;
    }
  }

  /// Own message deletions still awaiting confirmed delivery, for the retry
  /// sweep to re-drive via [retryMessageDeletion]. Empty when credentials
  /// have not been wired.
  Future<List<DmMessageDeletionRetryTarget>> retryableMessageDeletions() async {
    if (_messageService == null || _userPubkey.isEmpty) return const [];
    final rows = await _directMessagesDao.getRetryableOwnMessageDeletions(
      ownerPubkey: _userPubkey,
    );
    return rows
        .map(
          (r) => DmMessageDeletionRetryTarget(
            rumorId: r.id,
            conversationId: r.conversationId,
            createdAt: r.createdAt,
          ),
        )
        .toList(growable: false);
  }

  /// Re-drive a delete-for-everyone that no relay confirmed.
  ///
  /// Replays the **stored** rumor rather than rebuilding one, so every attempt
  /// carries a byte-identical rumor id and the retraction stays a single
  /// kind-5 no matter how many attempts it takes. Rebuilding would mint a
  /// fresh id per pass, putting N distinct retractions on the wire for one
  /// user action. No receive-side dedup collapses them either way — that is
  /// keyed on gift-wrap id, and NIP-59 gives every wrap a fresh ephemeral key
  /// and `created_at` — so what makes a replay safe is that re-applying a
  /// deletion is a no-op.
  ///
  /// When there is no stored rumor to replay — nulled by the settle helper
  /// before #8232, or unreadable — it mints one, because that row has no
  /// other route back: [deleteMessageForEveryone] returns early on
  /// `is_deleted` and the sweep's worklist requires a non-null rumor (#8284).
  Future<DmMessageDeletionOutcome> retryMessageDeletion({
    required String rumorId,
  }) {
    final existing = _messageDeletionRecoveriesInFlight[rumorId];
    if (existing != null) return existing;
    final future = _retryMessageDeletion(rumorId: rumorId);
    _messageDeletionRecoveriesInFlight[rumorId] = future;
    return future.whenComplete(
      () => _messageDeletionRecoveriesInFlight.remove(rumorId),
    );
  }

  Future<DmMessageDeletionOutcome> _retryMessageDeletion({
    required String rumorId,
  }) async {
    if (_messageService == null || _userPubkey.isEmpty) {
      return DmMessageDeletionOutcome.unavailable;
    }
    final owner = _ownerPubkey!;
    final row = await _directMessagesDao.getMessageById(
      rumorId,
      ownerPubkey: owner,
    );
    if (row == null) return DmMessageDeletionOutcome.unavailable;
    final recipients = await _deletionWrapRecipients(row.conversationId);
    if (recipients.isEmpty) return DmMessageDeletionOutcome.unavailable;

    final storedRumor = row.deletionRumorJson;
    Event? replayable;
    if (storedRumor != null) {
      try {
        replayable = Event.fromJson(
          jsonDecode(storedRumor) as Map<String, dynamic>,
        );
      } on Object catch (e) {
        Log.warning(
          'Stored deletion rumor for $rumorId is unreadable ($e) - '
          'minting a fresh kind 5',
          category: LogCategory.system,
        );
      }
    }

    // Nothing to replay. A row blocked before #8232 had its rumor nulled by
    // the settle helper, and an unreadable payload dead-ends the same way, so
    // minting a fresh kind 5 is the only route left for them.
    // [deleteMessageForEveryone] cannot serve it: that path returns early on
    // `is_deleted`, which every such row carries, and the sweep's worklist
    // requires a non-null rumor. Without this the restored bubble offers a
    // Try again that can never do anything (#8284).
    final mintedFresh = replayable == null;
    final deletion =
        replayable ??
        _messageService!.buildRumor(
          recipientPubkey: recipients.first,
          content: '',
          eventKind: EventKind.eventDeletion,
          additionalTags: [
            ['e', rumorId],
            ['k', row.messageKind.toString()],
          ],
        );

    // A user-driven retry moves a blocked row back through pending so the
    // bubble swaps its warning icon for progress. A freshly minted rumor must
    // also cross the durability boundary before the wire, so the sweep can
    // re-drive it. Sweep retries of an already-pending row need neither.
    if (mintedFresh ||
        row.deletionPublishStatus == DirectMessagesDao.deletionBlocked) {
      await _directMessagesDao.markMessageDeletionPending(
        rumorId,
        deletionRumorJson: mintedFresh
            ? jsonEncode(deletion.toJson())
            : storedRumor!,
        ownerPubkey: _ownerPubkey,
      );
      if (mintedFresh) _notifyRetryableWork();
    }

    return _driveMessageDeletion(
      rumorId: rumorId,
      conversationId: row.conversationId,
      deletion: deletion,
      recipients: recipients,
    );
  }

  /// Wrap [deletion] to each recipient in turn.
  ///
  /// Terminal success only when EVERY recipient's wrap lands. One row cannot
  /// track per-recipient delivery, so a partial fan-out must not settle it —
  /// the sweep re-drives the whole rumor and the recipients that already have
  /// it dedup on the (identical) rumor id. Mirrors
  /// `DmReactionsRepository._fanOutRumor`.
  ///
  /// A recipient's wrap "lands" only when the relay that confirmed it is one
  /// the recipient reads. When their kind-10050 could not be READ the wrap
  /// falls back to the default pool, and the pool's `OK` is downgraded to a
  /// soft failure through [downgradeFallbackPoolDelivery] — the same rule the
  /// 1:1 send and its retry apply (#7317) and the reaction fan-out applies
  /// (#8443). A recipient who genuinely advertises NO inbox is also left
  /// alone, on different terms: the pool fallback stays because reachability
  /// is preserved (#570) — a deliberate deviation from NIP-17's "clients
  /// shouldn't try" — and its `OK` is scored as delivery because we keep
  /// that deviation, not because NIP-17 licenses it.
  ///
  /// Scoring the unreadable case as landed is #8515, and it is not merely a
  /// mislabel: [DirectMessagesDao.markMessageDeletionSent] clears the stored
  /// rumor, and `getRetryableOwnMessageDeletions` selects on `deletion_pending`
  /// AND a non-null rumor — so the row leaves the sweep's worklist on two
  /// counts and the retraction becomes unrecoverable.
  ///
  /// Unlike `_fanOutRumor`, the aggregate failure does NOT carry
  /// `retryablePending`. Nothing can observe it here: this result is consumed
  /// only by [_driveMessageDeletion], which branches on `blocked` alone and
  /// returns a [DmMessageDeletionOutcome]. The record also reports whether
  /// any post-downgrade recipient result was accepted, so the caller can
  /// distinguish wholly refused from partly delivered fan-outs (#8201).
  Future<({NIP17SendResult result, bool anyRecipientAccepted})>
  _fanOutDeletion({
    required Event deletion,
    required List<String> recipients,
  }) async {
    // Resolve every recipient's kind-10050 inbox concurrently BEFORE the loop,
    // exactly as `sendMessage` and `sendGroupMessage` do. Without it the
    // OK-confirm below is satisfied by the default pool rather than the
    // recipient's own inbox — a false "confirmed" for a recipient who only
    // reads their advertised inbox. Resolution never throws (it degrades to
    // null → default pool), so a failed lookup cannot abort the fan-out.
    //
    // Resolved through the DETAILED reader: routing only needs the relays, but
    // this fan-out also REPORTS delivery, and `absent` and `unreadable` both
    // route to the pool while meaning opposite things (#8515).
    final inboxByRecipient = <String, DmInboxLookup>{};
    final selfWrapRelays = _selfWrapTargetRelays();
    await Future.wait([
      for (final recipient in recipients)
        resolveDmInboxRelaysDetailed(
          recipient,
        ).then((inbox) => inboxByRecipient[recipient] = inbox),
    ]);
    final selfWrapTargets = await selfWrapRelays;
    NIP17SendSuccess? lastSuccess;
    final failures = <NIP17SendFailure>[];
    for (final recipient in recipients) {
      final inbox = inboxByRecipient[recipient];
      final published = await _messageService!
          .sendRumor(
            rumorEvent: deletion,
            recipientPubkey: recipient,
            targetRelays: inbox?.relays,
            selfWrapTargetRelays: selfWrapTargets,
            awaitRecipientOk: true,
          )
          .timeout(
            _messagePublishTimeout,
            // A hung socket is inconclusive, not a rejection: the frame may
            // already be written. Time out into a retryable failure so the
            // drive returns and the sweep re-drives, rather than leaving an
            // unawaited future alive alongside every later attempt.
            onTimeout: () => NIP17SendResult.failure(
              'Deletion publish timed out after '
              '${_messagePublishTimeout.inSeconds}s',
              retryablePending: true,
            ),
          );
      // A pool `OK` for a recipient whose inbox we could not READ is not
      // delivery: the retraction may be sitting where they never look, and
      // `markMessageDeletionSent` would clear the stored rumor, taking the row
      // off the sweep's worklist for good (#8515).
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
    final anyRecipientAccepted = lastSuccess != null;
    if (failures.isEmpty) {
      return (
        result:
            lastSuccess ??
            const NIP17SendResult.failure('No deletion wrap recipients'),
        anyRecipientAccepted: anyRecipientAccepted,
      );
    }
    final summary = failures.map((f) => f.error).join('; ');
    // Terminal-refused only when every failure was a policy block — the
    // non-blocked members have all confirmed by then, and no retry can change
    // a refusal. A mixed outcome is still recorded blocked rather than sent,
    // because `sent` is the claim that would be false. The accepted-recipient
    // bit is retained for diagnostics; the UI deliberately presents both
    // wholly refused and mixed outcomes as uncertain (#8201).
    return (
      result: failures.every((f) => f.blocked)
          ? NIP17SendResult.blocked(summary)
          : NIP17SendResult.failure(summary),
      anyRecipientAccepted: anyRecipientAccepted,
    );
  }

  /// Refreshes the denormalized preview columns of [conversationId] from its
  /// actual messages (called after a deletion and after a duplicate merge).
  ///
  /// If the last shown message was deleted, the preview falls back to the
  /// next most recent non-deleted message.
  ///
  /// This is a preview-only operation: it forwards the conversation's current
  /// `isRead` back through the upsert so read state is never changed here.
  /// Because `forceUpdateLastMessage` bypasses the timestamp guard, omitting
  /// `isRead` would let the gate's default (`true`) overwrite an unread
  /// conversation whenever the refreshed preview is strictly newer than the
  /// stored timestamp — e.g. a stale-preview canonical row right after a
  /// duplicate merge. Passing the current value makes preservation explicit
  /// and immune to timestamp ordering.
  Future<void> _refreshConversationPreview(String conversationId) async {
    final remaining = await _directMessagesDao.getMessagesForConversation(
      conversationId,
      limit: 1,
      ownerPubkey: _ownerPubkey,
    );

    final conversation = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: _ownerPubkey,
    );
    if (conversation == null) return;

    if (remaining.isEmpty) {
      // All messages deleted — clear the preview. Force the update so the
      // conditional timestamp check in upsertConversation does not block
      // a null timestamp from overwriting the existing value.
      await _conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: conversation.participantPubkeys,
        isGroup: conversation.isGroup,
        createdAt: conversation.createdAt,
        // Explicit nulls clear the previous preview after deletion.
        // ignore: avoid_redundant_argument_values, clears preview
        lastMessageContent: null,
        // ignore: avoid_redundant_argument_values, clears preview
        lastMessageTimestamp: null,
        // ignore: avoid_redundant_argument_values, clears preview
        lastMessageSenderPubkey: null,
        // Preview-only refresh — preserve the current read state explicitly.
        isRead: conversation.isRead,
        currentUserHasSent: conversation.currentUserHasSent,
        ownerPubkey: conversation.ownerPubkey,
        dmProtocol: conversation.dmProtocol,
        forceUpdateLastMessage: true,
      );
    } else {
      final latest = remaining.first;
      final previewContent = latest.messageKind == EventKind.fileMessage
          ? _filePreviewText(latest.fileType)
          : latest.content;

      // Force the update: after a deletion the replacement message is the
      // newest *remaining* one, but its timestamp may be older than the
      // deleted message that was previously shown.
      await _conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: conversation.participantPubkeys,
        isGroup: conversation.isGroup,
        createdAt: conversation.createdAt,
        lastMessageContent: previewContent,
        lastMessageTimestamp: latest.createdAt,
        lastMessageSenderPubkey: latest.senderPubkey,
        // Preview-only refresh — preserve the current read state explicitly.
        isRead: conversation.isRead,
        currentUserHasSent: conversation.currentUserHasSent,
        ownerPubkey: conversation.ownerPubkey,
        dmProtocol: conversation.dmProtocol,
        forceUpdateLastMessage: true,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Send - File (Kind 15)
  // -------------------------------------------------------------------------

  /// Send an encrypted file message to a 1:1 conversation.
  ///
  /// No NIP-04 fallback is sent for file messages because NIP-04 only
  /// supports plaintext content. File sharing requires NIP-17's kind 15
  /// with encrypted file metadata tags.
  ///
  /// The file should already be encrypted with AES-GCM and uploaded to a
  /// Blossom server. This method wraps the file URL and metadata in a
  /// Kind 15 event, then encrypts with NIP-59 gift wrapping.
  ///
  /// Throws [StateError] if the repository has not been initialized.
  /// Throws [ArgumentError] if [recipientPubkey] is invalid or required
  /// metadata is missing.
  @useResult
  Future<NIP17SendResult> sendFileMessage({
    required String recipientPubkey,
    required String fileUrl,
    required DmFileMetadata fileMetadata,
    String? replyToId,
  }) async {
    _assertInitialized();
    validatePubkey(recipientPubkey);
    if (fileUrl.trim().isEmpty) {
      throw ArgumentError.value(fileUrl, 'fileUrl', 'must not be empty');
    }

    // Self-addressed sends are refused (#8351) — see [sendMessage] for why a
    // published one cannot be read back or deleted.
    if (_isSelf(recipientPubkey)) {
      return const NIP17SendResult.failure(
        'refused: a message cannot be addressed to its own sender',
      );
    }

    // Protected-minor gate (#176): the file path intentionally relies on the
    // single authoritative choke point in `sendRumor` (via sendPrivateMessage)
    // rather than adding its own pre-check like sendMessage/sendGroupMessage. A
    // blocked recipient is refused there before any publish; the extra pre-gate
    // on the text paths is only an early-out to avoid enqueuing a doomed 1:1/
    // group intent, which the single-shot file send does not create.

    final additionalTags = <List<String>>[
      ['file-type', fileMetadata.fileType],
      ['encryption-algorithm', fileMetadata.encryptionAlgorithm],
      ['decryption-key', fileMetadata.decryptionKey],
      ['decryption-nonce', fileMetadata.decryptionNonce],
      ['x', fileMetadata.fileHash],
      if (fileMetadata.originalFileHash != null)
        ['ox', fileMetadata.originalFileHash!],
      if (fileMetadata.fileSize != null)
        ['size', fileMetadata.fileSize.toString()],
      if (fileMetadata.dimensions != null) ['dim', fileMetadata.dimensions!],
      if (fileMetadata.blurhash != null) ['blurhash', fileMetadata.blurhash!],
      if (fileMetadata.thumbnailUrl != null)
        ['thumb', fileMetadata.thumbnailUrl!],
      if (replyToId != null) ['e', replyToId],
    ];

    final result = await _messageService!.sendPrivateMessage(
      recipientPubkey: recipientPubkey,
      content: fileUrl,
      eventKind: EventKind.fileMessage,
      additionalTags: additionalTags,
    );

    if (result.success) {
      final participants = [_userPubkey, recipientPubkey]..sort();
      final conversationId = computeConversationId(participants);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Persist message + conversation atomically.
      await _conversationsDao.runInTransaction(() async {
        await _directMessagesDao.insertMessage(
          id: result.rumorEventId!,
          conversationId: conversationId,
          senderPubkey: _userPubkey,
          content: fileUrl,
          createdAt: now,
          giftWrapId: result.messageEventId!,
          messageKind: EventKind.fileMessage,
          replyToId: replyToId,
          fileType: fileMetadata.fileType,
          encryptionAlgorithm: fileMetadata.encryptionAlgorithm,
          decryptionKey: fileMetadata.decryptionKey,
          decryptionNonce: fileMetadata.decryptionNonce,
          fileHash: fileMetadata.fileHash,
          originalFileHash: fileMetadata.originalFileHash,
          fileSize: fileMetadata.fileSize,
          dimensions: fileMetadata.dimensions,
          blurhash: fileMetadata.blurhash,
          thumbnailUrl: fileMetadata.thumbnailUrl,
          tagsJson: jsonEncode(additionalTags),
          ownerPubkey: _userPubkey,
        );

        final existingFile = await _conversationsDao.getConversation(
          conversationId,
          ownerPubkey: _userPubkey,
        );
        await _upsertSentConversationAndMarkRead(
          id: conversationId,
          participantPubkeys: jsonEncode(participants),
          isGroup: false,
          createdAt: existingFile?.createdAt ?? now,
          lastMessageContent: _filePreviewText(fileMetadata.fileType),
          lastMessageTimestamp: now,
          lastMessageSenderPubkey: _userPubkey,
          ownerPubkey: _userPubkey,
          dmProtocol: existingFile?.dmProtocol,
        );
      });
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Send - NIP-04 fallback (Kind 4)
  // -------------------------------------------------------------------------

  /// Clears a `'nip04'` latch when the peer advertises a kind-10050 DM inbox.
  ///
  /// Weaker evidence than a NIP-17 event from them, and deliberately so: it is
  /// the only signal available on a thread where they never send anything. A
  /// client that publishes a kind-10050 implements NIP-17 and can read a gift
  /// wrap, so the cleartext twin buys them nothing.
  ///
  /// The clearing is one-way: nothing re-latches a thread
  /// (`_handleNip04Event` preserves the stored value — a property inherited
  /// from the pre-latch upsert, not a designed guard), so a kind-10050 left
  /// behind by a client the peer has since abandoned can permanently cut a
  /// legacy-only reader off from the one copy they can read. Accepted:
  /// #8519 weighs exactly this residual, the mirror cache-staleness case is
  /// filed as #8528, and whether a later peer-authored kind-4 may re-latch
  /// is a receive-path decision of the same "decide whether" family,
  /// deliberately not taken here.
  ///
  /// Best-effort. A failure leaves the thread latched and the next send
  /// presents the same evidence again, so it must never cost the message.
  Future<void> _clearLatchOnAdvertisedInbox(
    String conversationId,
    DmInboxResolution state,
  ) async {
    if (state != DmInboxResolution.found) return;
    try {
      final cleared = await _conversationsDao.clearNip04ProtocolLatch(
        conversationId,
        ownerPubkey: _userPubkey,
      );
      if (cleared) {
        Log.info(
          'Cleared the nip04 protocol latch on conversation $conversationId: '
          'the recipient advertises a kind-10050 DM inbox, so the legacy '
          'kind-4 copy is no longer published to them',
          category: LogCategory.system,
        );
      }
    } on Object catch (e) {
      Log.warning(
        'Could not clear the nip04 protocol latch on conversation '
        '$conversationId from the advertised inbox: $e — the thread keeps '
        'dual-sending until the next attempt',
        category: LogCategory.system,
      );
    }
  }

  /// The event id to put in a kind-4 `e` tag for a reply, or `null` when the
  /// reply target is not one the legacy recipient can resolve.
  ///
  /// Returns the id only for a peer-authored row with the NIP-04 arrival shape,
  /// so the reference names a public event the recipient has seen. Own NIP-17
  /// sends before #2654 also have `id == giftWrapId` (#8211/#8216), so sender
  /// identity is required to keep those private wrap ids out of public tags.
  Future<String?> _resolveNip04ReplyTag(String? replyToId) async {
    if (replyToId == null) return null;
    try {
      final row = await _directMessagesDao.getMessageById(
        replyToId,
        ownerPubkey: _userPubkey,
      );
      if (row == null) return null;
      final arrivedFromPeerOverNip04 =
          row.senderPubkey != _userPubkey && row.id == row.giftWrapId;
      return arrivedFromPeerOverNip04 ? row.id : null;
    } on Object catch (e) {
      // Best-effort threading must never cost the message. A lookup failure
      // sends the copy untagged rather than not at all.
      Log.warning(
        'Could not resolve a NIP-04 reply tag for $replyToId: $e — sending '
        'the legacy kind-4 copy unthreaded',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Sends a NIP-04 encrypted direct message (kind 4) for legacy client
  /// interoperability.
  ///
  /// Reuses [NIP17SendResult] as the return type for simplicity — the
  /// semantics (success/failure with optional event ID) are identical.
  Future<NIP17SendResult> _sendNip04Message({
    required String recipientPubkey,
    required String content,
    String? replyToId,
  }) async {
    // Reuses NIP17SendResult for simplicity — this is an internal helper.
    //
    // Every failure below is LOGGED as well as returned. The caller fires this
    // leg unawaited, so a returned failure that logged nothing was invisible on
    // both devices: the sender saw a delivered message and the legacy recipient
    // never got one (#8262).
    final signer = _signer;
    if (signer == null) {
      Log.warning(
        'NIP-04 fallback: no signer for ${pubkeyForLogs(recipientPubkey)} — '
        'the legacy kind-4 copy was not sent',
        category: LogCategory.system,
      );
      return const NIP17SendResult.failure('Signer not available');
    }

    final ciphertext = await signer.encrypt(recipientPubkey, content);
    if (ciphertext == null) {
      // A signer can do NIP-44 (used by the NIP-17 leg) and still refuse or
      // lack NIP-04: it is a separate capability, and a null here is the
      // signer's silent refusal rather than an exception.
      Log.warning(
        'NIP-04 fallback: encrypt returned null for '
        '${pubkeyForLogs(recipientPubkey)} — the legacy kind-4 copy was not '
        'sent',
        category: LogCategory.system,
      );
      return const NIP17SendResult.failure('NIP-04 encrypt returned null');
    }

    // NIP-04 reply tags are public. Resolve through the stored row so only a
    // kind-4 id already visible to the peer can leave this private store.
    final replyTag = await _resolveNip04ReplyTag(replyToId);
    final event = Event(_userPubkey, EventKind.directMessage, [
      ['p', recipientPubkey],
      if (replyTag != null) ['e', replyTag],
    ], ciphertext);

    final signed = await signer.signEvent(event);
    if (signed == null) {
      Log.warning(
        'NIP-04 fallback: signEvent returned null for '
        '${pubkeyForLogs(recipientPubkey)} — the legacy kind-4 copy was not '
        'sent',
        category: LogCategory.system,
      );
      return const NIP17SendResult.failure('NIP-04 sign returned null');
    }

    // OK-confirm the kind 4. `publishEvent` reports success on a WebSocket
    // frame write, so a relay answering `OK false` — rate limited, blocked by
    // policy, caught by a spam filter — came back as a delivered message.
    // Branch on the OK boolean and never on the reason prefix: NIP-01 puts
    // `duplicate:` and `pow:` on `true` (01.md:166-167).
    final outcome = await _nostrClient.publishEventAwaitOk(signed);
    if (!outcome.acceptedByAny) {
      Log.error(
        'NIP-04 fallback: no relay accepted the legacy kind-4 copy for '
        '${pubkeyForLogs(recipientPubkey)} (event ${signed.id}) — '
        '${outcome.summary}',
        category: LogCategory.system,
      );
      return const NIP17SendResult.failure('NIP-04 publish failed');
    }

    // Partial acceptance still counts as sent, but a relay that refused is
    // worth a line: a policy or rate-limit refusal is invisible otherwise.
    if (outcome.rejectedBy.isNotEmpty) {
      Log.warning(
        'NIP-04 fallback: legacy kind-4 copy (event ${signed.id}) refused by '
        '${outcome.rejectedBy.length} relay(s) but accepted elsewhere — '
        '${outcome.summary}',
        category: LogCategory.system,
      );
    }

    // Say so on SUCCESS too, not only on the failure paths #8262 instrumented.
    // A cleartext kind 4 leaving the device is the event worth a line: the
    // NIP-17 leg logs `Successfully published` either way, so without this a
    // support log for a latched thread reads as an ordinary private send with
    // no trace that a public-metadata copy went out beside it (#8519).
    Log.info(
      'NIP-04 fallback: published the legacy kind-4 copy for '
      '${pubkeyForLogs(recipientPubkey)} (event ${signed.id}) — this thread is '
      'still latched to nip04, so its metadata is public',
      category: LogCategory.system,
    );

    return NIP17SendResult.success(
      rumorEventId: signed.id,
      messageEventId: signed.id,
      recipientPubkey: recipientPubkey,
    );
  }

  // -------------------------------------------------------------------------
  // Query - Conversations
  // -------------------------------------------------------------------------

  /// Watch conversations (reactive stream), newest first.
  ///
  /// When [limit] is provided, only the top [limit] conversations are
  /// watched. Omit for all conversations.
  Stream<List<DmConversation>> watchConversations({int? limit}) {
    final owner = _ownerPubkey;
    if (owner == null) return Stream.value(const <DmConversation>[]);
    return _watchConversationRows(
      () => _conversationsDao.watchAllConversations(
        limit: limit,
        ownerPubkey: owner,
      ),
    );
  }

  /// Get a single conversation by ID.
  ///
  /// Returns `null` if no conversation with the given ID exists, or if no
  /// owner is known. Ownerless reads fail closed because the DAO's legacy
  /// null-owner contract otherwise widens them to every row.
  Future<DmConversation?> getConversation(String conversationId) async {
    final owner = _ownerPubkey;
    if (owner == null) return null;
    await _awaitInitialConversationMaintenance();
    final row = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: owner,
    );
    return row == null ? null : _conversationFromRow(row);
  }

  /// Get all conversations.
  Future<List<DmConversation>> getConversations() async {
    final owner = _ownerPubkey;
    if (owner == null) return const [];
    await _awaitInitialConversationMaintenance();
    final rows = await _conversationsDao.getAllConversations(
      ownerPubkey: owner,
    );
    return rows.map(_conversationFromRow).toList();
  }

  /// Watch conversations where the user has sent at least one message.
  ///
  /// Supports pagination via [limit]. These conversations are never
  /// message requests.
  ///
  /// A conversation whose participants collapse to the viewer alone is
  /// omitted. Divine does not support a conversation with only yourself
  /// (#8261), and the row is unusable: every caller resolves the counterparty
  /// by dropping the viewer, so it renders as a chat with yourself, with
  /// Report, Block and Mute all addressing the viewer's own account.
  ///
  /// [classifyPotentialRequests] already drops the same shape, but it only
  /// ever sees conversations the user has NOT sent to. Legacy self-wrap bugs
  /// and malformed data can leave an already-sent row on this stream instead.
  /// Startup maintenance removes known rows; this filter remains as defense in
  /// depth so the Messages list and unread badge cannot disagree (#4976).
  Stream<List<DmConversation>> watchAcceptedConversations({int? limit}) {
    final owner = _ownerPubkey;
    if (owner == null) return Stream.value(const <DmConversation>[]);
    return _watchConversationRows(
      () => _conversationsDao.watchAcceptedConversations(
        limit: limit,
        ownerPubkey: owner,
      ),
    ).map(
      (conversations) => conversations
          .where(
            (conversation) => !_containsOnlyPubkey(
              conversation.participantPubkeys,
              owner,
            ),
          )
          .toList(),
    );
  }

  /// Watch conversations where the user has never sent a message.
  ///
  /// These are potential message requests. Final classification (based on
  /// follow state) is applied by [classifyPotentialRequests]. Returned
  /// without pagination since the list is typically small and needed in full.
  Stream<List<DmConversation>> watchPotentialRequests() {
    final owner = _ownerPubkey;
    if (owner == null) return Stream.value(const <DmConversation>[]);
    return _watchConversationRows(
      () => _conversationsDao.watchPotentialRequestConversations(
        ownerPubkey: owner,
      ),
    );
  }

  /// Classifies potential request conversations by follow state.
  ///
  /// Conversations where `currentUserHasSent == false` are "potential
  /// requests". A conversation goes to the followed list (Messages tab)
  /// when EVERY deduplicated non-self participant is followed — a 1:1
  /// from a followed contact, or a group made up entirely of followed
  /// contacts. Any unfollowed participant makes it a true request, so a
  /// stranger added to a group still lands under Message requests.
  ///
  /// Participant counting uses the deduplicated non-self set, NOT the
  /// denormalized `DmConversation.isGroup` flag. That column is written
  /// from `participants.length > 2` and overwritten on every upsert, so
  /// it can drift from a row's real participants — which was stranding
  /// followed 1:1 peers under "Message requests" (#5374).
  ///
  /// A participant set that collapses to the viewer alone is a
  /// self-conversation, which Divine does not support (#8261). It is omitted
  /// from both user-facing lists: moving an unusable row from Messages to
  /// Message requests would only relocate the same broken experience. #2219
  /// routed the empty case to the followed list explicitly; #6294 folded that
  /// branch into `Set.every`'s vacuous truth, leaving the behaviour implicit.
  /// The diagnostics branch below still records the malformed row.
  ///
  /// NIP-17 ingest rejects case-insensitively collapsed participant lists,
  /// while post-auth maintenance cleans the known legacy `[self, self]`
  /// shape. Classification remains defensive because older or otherwise
  /// malformed rows can use a different participant shape.
  static ({List<DmConversation> followed, List<DmConversation> requests})
  classifyPotentialRequests(
    List<DmConversation> potentialRequests, {
    required String userPubkey,
    required bool Function(String) isFollowing,
  }) {
    final followed = <DmConversation>[];
    final requests = <DmConversation>[];

    for (final conversation in potentialRequests) {
      // Case-insensitive, matching [_isSelf]: `validatePubkey` accepts
      // upper-case hex, so an exact `!=` would keep the viewer in
      // `otherPubkeys` under a different casing and strand a followed 1:1
      // peer under Message requests — the #5374 failure mode.
      final otherPubkeys = conversation.participantPubkeys
          .where((pk) => !pubkeysEqual(pk, userPubkey))
          .toSet();

      if (otherPubkeys.isEmpty) {
        if (_classifyDiagnostics) {
          Log.debug(
            'classifyPotentialRequests → hidden self-only conversation: '
            '${conversation.id}',
            category: LogCategory.system,
          );
        }
        continue;
      }

      // A conversation whose every (deduplicated) non-self participant is
      // followed is not a request even if the user hasn't replied yet —
      // 1:1 or group alike. Derived from actual participants rather than
      // the stored `isGroup` flag, which can drift from the row's real
      // participants and mis-route followed 1:1 peers to requests (#5374).
      //
      final allFollowed = otherPubkeys.every(isFollowing);

      if (allFollowed) {
        followed.add(conversation);
      } else {
        if (_classifyDiagnostics) {
          final follows = otherPubkeys
              .map((pk) => '$pk:${isFollowing(pk)}')
              .join(', ');
          Log.debug(
            'classifyPotentialRequests → request: '
            'conversationId=${conversation.id} '
            'isGroup=${conversation.isGroup} '
            'participantCount=${conversation.participantPubkeys.length} '
            'otherPubkeys=${otherPubkeys.map(pubkeyForLogs).join(", ")} '
            'follows={$follows}',
            category: LogCategory.system,
          );
        }
        requests.add(conversation);
      }
    }

    return (followed: followed, requests: requests);
  }

  /// Merges accepted conversations with followed-but-unreplied ones
  /// and sorts by timestamp descending.
  static List<DmConversation> mergeAndSort(
    List<DmConversation> accepted,
    List<DmConversation> followedPotential,
  ) {
    if (followedPotential.isEmpty) return accepted;
    return [...accepted, ...followedPotential]..sort((a, b) {
      return b.effectiveTimestamp.compareTo(a.effectiveTimestamp);
    });
  }

  /// Lifts the Divine Moderation support thread out of the inbox and request
  /// lists so it renders once, as the pinned row (#6283).
  ///
  /// Only a thread on [supportPubkey] is touched: the row routes on the
  /// returned conversation's own participants and nothing remaps the recipient
  /// between there and [sendMessage], so adopting a pre-rotation thread would
  /// send support replies to a retired key.
  ///
  /// A thread on a *retired* moderation key is therefore left in whichever list
  /// it arrived in, exactly like any other conversation. Those rows carry
  /// inbound moderation history that was visible before #6283, and until the
  /// archived read-only shape exists (#6416) keeping the original row is safer
  /// than hiding the user's only in-app entry point to that history.
  ///
  /// Shared with the unread badge rather than reimplemented there, so the
  /// count cannot drift from the rows the list actually renders (#4976).
  ///
  /// `supportConversationId` is the id the pinned row must open: non-null
  /// whenever a pin is possible at all, so a caller that wants to synthesize a
  /// stand-in row has both the go/no-go answer and the id without re-deriving
  /// either. It is null — along with `pinned` — when there is no identity to
  /// key on, or when the signed-in user *is* the moderation account, in which
  /// case both lists come back untouched.
  static ({
    DmConversation? pinned,
    String? supportConversationId,
    List<DmConversation> inbox,
    List<DmConversation> requests,
  })
  extractPinnedSupport({
    required String userPubkey,
    required String? supportPubkey,
    required List<DmConversation> inbox,
    required List<DmConversation> requests,
  }) {
    if (userPubkey.isEmpty ||
        supportPubkey == null ||
        supportPubkey.isEmpty ||
        userPubkey == supportPubkey) {
      return (
        pinned: null,
        supportConversationId: null,
        inbox: inbox,
        requests: requests,
      );
    }

    final currentId = computeConversationId([userPubkey, supportPubkey]);

    DmConversation? pinned;
    final remainingInbox = <DmConversation>[];
    for (final conversation in inbox) {
      if (conversation.id == currentId) {
        pinned ??= conversation;
      } else {
        remainingInbox.add(conversation);
      }
    }

    // An inbound-only moderation DM (the team wrote first) has
    // currentUserHasSent == false and lands in requests, not the inbox.
    final remainingRequests = <DmConversation>[];
    for (final conversation in requests) {
      if (conversation.id == currentId) {
        pinned ??= conversation;
      } else {
        remainingRequests.add(conversation);
      }
    }

    return (
      pinned: pinned,
      supportConversationId: currentId,
      inbox: remainingInbox,
      requests: remainingRequests,
    );
  }

  /// Watch unread conversation count (all conversations).
  Stream<int> watchUnreadCount() {
    final owner = _ownerPubkey;
    if (owner == null) return Stream.value(0);
    return _conversationsDao.watchUnreadCount(ownerPubkey: owner);
  }

  /// Watch unread count for accepted conversations only (excludes requests).
  Stream<int> watchUnreadAcceptedCount() {
    final owner = _ownerPubkey;
    if (owner == null) return Stream.value(0);
    return _conversationsDao.watchUnreadAcceptedCount(ownerPubkey: owner);
  }

  /// Mark a conversation as read.
  ///
  /// Advances the conversation's read cursor (see
  /// [ConversationsDao.markAsRead]) and schedules a debounced cross-device
  /// read-state marker publish (#4977).
  /// No-op when no owner is known: [ConversationsDao.markAsRead] drops its
  /// owner clause entirely for a null owner, leaving a bare
  /// `UPDATE ... WHERE id = ?` that would advance any account's cursor.
  Future<void> markConversationAsRead(String conversationId) async {
    final owner = _ownerPubkey;
    if (owner == null) return;
    await _conversationsDao.markAsRead(conversationId, ownerPubkey: owner);
    _scheduleReadMarkerPublish();
  }

  /// Mark multiple conversations as read in a single batch.
  ///
  /// No-op when [conversationIds] is empty, or when no owner is known — see
  /// [markConversationAsRead]. Advances each cursor and schedules a single
  /// debounced read-state marker publish (#4977).
  Future<void> markConversationsAsRead(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    final owner = _ownerPubkey;
    if (owner == null) return;
    await _conversationsDao.markMultipleAsRead(
      conversationIds,
      ownerPubkey: owner,
    );
    _scheduleReadMarkerPublish();
  }

  // ---------------------------------------------------------------------------
  // Cross-device read-state sync (#4977)
  // ---------------------------------------------------------------------------

  /// Schedule a debounced publish of the read-state marker so a burst of reads
  /// coalesces into one self-encrypted kind-30078 marker.
  void _scheduleReadMarkerPublish() {
    if (!isInitialized) return;
    _readMarkerDebounce?.cancel();
    _readMarkerDebounce = Timer(
      _readMarkerDebounceDelay,
      () => unawaited(_publishReadMarker()),
    );
  }

  /// Build the current per-conversation read-cursor map and publish it as a
  /// self-addressed, NIP-44-sealed kind-30078 marker (#4977 v1).
  ///
  /// Best-effort: a failed publish just means read state syncs on the next
  /// read. Published through the normal pool so the marker keeps the pool's
  /// write redundancy; other devices and a reinstall recover it from the
  /// same pool that receives Divine's DM traffic.
  Future<void> _publishReadMarker() async {
    final service = _messageService;
    if (service == null || !isInitialized) return;
    final gen = _resetGeneration;
    try {
      final conversations = await _conversationsDao.getAllConversations(
        ownerPubkey: _ownerPubkey,
      );
      if (_disposed || _resetGeneration != gen) return;
      final readMap = <String, int>{};
      for (final convo in conversations) {
        final cursor = convo.lastReadTimestamp;
        if (cursor == null || cursor <= 0) continue;
        final tupleKey = _participantTupleKey(convo.participantPubkeys);
        if (tupleKey == null) continue;
        final existing = readMap[tupleKey];
        if (existing == null || cursor > existing) readMap[tupleKey] = cursor;
      }
      if (readMap.isEmpty) return;
      final content = jsonEncode(<String, dynamic>{
        'v': _readMarkerPayloadVersion,
        'read': readMap,
      });
      await service.publishSelfApplicationMarker(
        content: content,
        tags: const [
          ['d', _readMarkerDTag],
        ],
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'DM read-marker publish failed (non-fatal): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// The canonical cross-client wire key for a conversation: its participant
  /// pubkeys, sorted, comma-joined (matching divine-web's form). Each client
  /// maps this tuple to its own internal conversation id. Returns null when
  /// [participantPubkeysJson] can't be parsed.
  String? _participantTupleKey(String participantPubkeysJson) {
    try {
      final list = (jsonDecode(participantPubkeysJson) as List<dynamic>)
          .cast<String>();
      if (list.isEmpty) return null;
      final sorted = List<String>.from(list)..sort();
      return sorted.join(',');
    } on Object {
      return null;
    }
  }

  /// Reconcile a restored kind-30078 read-state marker rumor (#4977): advance
  /// each conversation's read cursor to the marker's timestamp (forward-only
  /// max). A conversation not yet ingested (marker processed before its
  /// messages during the drain) is stashed in [_pendingReadCursors] and
  /// applied when the drain completes.
  Future<void> _reconcileReadMarker(Event rumor) async {
    if (!_hasReadMarkerDTag(rumor)) return;
    // The marker is a self-authored control message: the sender gift-wraps it
    // to their own pubkey, so the only legitimate author is the local user.
    // `rumor.pubkey` is the seal signer, authenticated by the Schnorr check in
    // GiftWrapUtil on every unwrap path, so anything else is forged — the
    // conversation id below is derived from participant pubkeys alone, which
    // are public. Fail closed when the local pubkey is unknown. #7343.
    if (_userPubkey.isEmpty || rumor.pubkey != _userPubkey) {
      Log.debug(
        'Ignoring DM read marker ${rumor.id}: author mismatch '
        '(event=${pubkeyForLogs(rumor.pubkey)}, '
        'user=${pubkeyForLogs(_userPubkey)})',
        category: LogCategory.system,
      );
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(rumor.content);
    } on Object {
      return;
    }
    if (decoded is! Map) return;
    final read = decoded['read'];
    if (read is! Map) return;
    // The cursor only ever moves forward, so an out-of-range value can never be
    // undone: one marker published by a device with a corrupt clock would pin
    // every conversation read for good. Clamp to the local clock, the same way
    // an incoming rumor's own created_at is clamped for ordering. #7343.
    final clock = DmClock.now();
    for (final entry in read.entries) {
      final tupleKey = entry.key;
      final ts = entry.value;
      if (tupleKey is! String || ts is! int) continue;
      final cursor = clock.atMostNow(ts);
      final pubkeys = tupleKey.split(',');
      if (pubkeys.length < 2) continue;
      final conversationId = computeConversationId(pubkeys);
      final applied = await _conversationsDao.applyReadCursor(
        conversationId,
        cursor,
        ownerPubkey: _ownerPubkey,
      );
      if (!applied) {
        final existing = _pendingReadCursors[conversationId];
        if (existing == null || cursor > existing) {
          _pendingReadCursors[conversationId] = cursor;
        }
      }
    }
  }

  bool _hasReadMarkerDTag(Event rumor) {
    for (final tag in rumor.tags) {
      if (tag.length >= 2 && tag[0] == 'd') return tag[1] == _readMarkerDTag;
    }
    return false;
  }

  /// After the history drain completes, restore read state (#4977):
  /// (1) the last-sent floor — for each conversation the user replied in,
  /// advance the cursor to their own most-recent sent message; and
  /// (2) flush [_pendingReadCursors] — markers whose conversations had not yet
  /// been ingested when the marker was first processed.
  Future<void> _restoreReadStateAfterDrain(
    String pubkey,
    int generation,
  ) async {
    try {
      final floors = await _conversationsDao.lastSentTimestampsByConversation(
        pubkey,
        ownerPubkey: pubkey,
      );
      for (final entry in floors.entries) {
        if (_ingestSessionEnded(pubkey, generation)) return;
        await _conversationsDao.applyReadCursor(
          entry.key,
          entry.value,
          ownerPubkey: pubkey,
        );
      }
      if (_pendingReadCursors.isNotEmpty) {
        final pending = Map<String, int>.from(_pendingReadCursors);
        _pendingReadCursors.clear();
        for (final entry in pending.entries) {
          if (_ingestSessionEnded(pubkey, generation)) return;
          await _conversationsDao.applyReadCursor(
            entry.key,
            entry.value,
            ownerPubkey: pubkey,
          );
        }
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'DM read-state restore after drain failed: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Whether [conversation] is one the injected policy refuses to remove.
  ///
  /// Exposed so a caller can withdraw a destructive affordance before offering
  /// it, rather than letting the user meet a refusal. The enforcement itself is
  /// in [removeConversation] / [removeConversations]; this is the cheap,
  /// synchronous question the UI asks.
  ///
  /// Self is excluded, so a signed-in moderation account can still clear its
  /// own threads. **Any** other participant is enough, which covers a group
  /// that happens to include one — `.any`, never `.first`.
  bool isRemovalProtected(DmConversation conversation) {
    final me = _userPubkey;
    return conversation.participantPubkeys.any(
      (pubkey) => pubkey != me && _removalPolicy(pubkey),
    );
  }

  /// What a removal request resolves to before any row is touched.
  ///
  /// Three-valued because [_RemovalDisposition.absent] and
  /// [_RemovalDisposition.removable] both report success to the caller but must
  /// write different things: only a conversation that is actually on disk earns
  /// a suppression tombstone. See [_resolveRemoval].
  ///
  /// Resolving once and reusing the answer is also what keeps the guard's read
  /// and the delete on the same account by construction rather than by comment.
  Future<_RemovalDisposition> _resolveRemoval(
    String conversationId, {
    required String ownerPubkey,
  }) async {
    await _awaitInitialConversationMaintenance();
    final row = await _conversationsDao.getConversation(
      conversationId,
      ownerPubkey: ownerPubkey,
    );
    if (row == null) return _RemovalDisposition.absent;
    return isRemovalProtected(_conversationFromRow(row))
        ? _RemovalDisposition.protected
        : _RemovalDisposition.removable;
  }

  /// Remove a conversation, its messages, its queued sends, and its queued
  /// reactions atomically.
  ///
  /// Records an owner-scoped tombstone first so relay replay cannot restore
  /// history at or before the removal time. The marker is kept for the
  /// account's lifetime: a newer message recreates the conversation while
  /// earlier history stays suppressed.
  ///
  /// The tombstone is written **only for a conversation that is on disk**. It
  /// is a record of what this device removed, not of what it was asked to
  /// remove, and it is permanent — so writing one for an id with no local row
  /// suppresses a conversation the user never had (#7850).
  ///
  /// The `dm_message_reactions` delete is not housekeeping. Those rows are
  /// the durable outgoing queue for unpublished reactions and pending kind-5
  /// removals, and the retry sweep selects them by owner alone. Left behind,
  /// the sweep publishes a gift wrap into a conversation the user removed
  /// (#7857) — the reaction counterpart of the `outgoing_dms` delete above.
  ///
  /// Returns [ConversationRemovalOutcome.refused] without deleting anything
  /// when the injected [DmConversationRemovalPolicy] protects the peer — the
  /// single chokepoint every removal path inherits, so a new caller cannot
  /// forget it (#8391).
  ///
  /// A conversation that is **absent** fails OPEN and reports
  /// [ConversationRemovalOutcome.removed]: a stale id must never become an
  /// undeletable row.
  ///
  /// Throws:
  ///
  /// * `InvalidDataException` if a database constraint is violated.
  Future<ConversationRemovalOutcome> removeConversation(
    String conversationId,
  ) async {
    final owner = _ownerPubkey;
    if (owner == null) {
      throw StateError('Cannot remove a conversation without a known owner.');
    }
    final disposition = await _resolveRemoval(
      conversationId,
      ownerPubkey: owner,
    );
    switch (disposition) {
      case _RemovalDisposition.protected:
        return ConversationRemovalOutcome.refused;
      case _RemovalDisposition.absent:
        // Fails open, as before — a stale id must never become an undeletable
        // row. What changed is that it no longer leaves a tombstone behind
        // (#7850). Nothing local was removed, so there is no local history to
        // suppress; a marker here would instead drop every future relay replay
        // of a conversation this device never had, permanently and silently.
        // A moderation enforcement notice is the case that matters: its
        // created_at is always in the past, so it would never arrive again.
        return ConversationRemovalOutcome.removed;
      case _RemovalDisposition.removable:
        break;
    }
    await _conversationsDao.runInTransaction<void>(() async {
      // Snapshot the owner for the whole transaction: an account switch
      // mid-flight must not mix one account's reads with another's writes.
      final removedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _removedConversationsDao?.record(
        conversationId: conversationId,
        ownerPubkey: owner,
        removedAt: removedAt,
      );
      await _directMessagesDao.deleteConversationMessages(
        conversationId,
        ownerPubkey: owner,
      );
      await _conversationsDao.deleteConversation(
        conversationId,
        ownerPubkey: owner,
      );
      await _outgoingDmsDao?.deleteForConversation(
        conversationId: conversationId,
        ownerPubkey: owner,
      );
      await _reactionsRepository?.deleteForConversations([
        conversationId,
      ], ownerPubkey: owner);
    });
    return ConversationRemovalOutcome.removed;
  }

  /// Remove multiple conversations, their messages, their queued sends, and
  /// their queued reactions atomically. See [removeConversation] for why the
  /// reaction rows go with them.
  ///
  /// No-op when [conversationIds] is empty.
  ///
  /// **Filters rather than refusing the batch.** Protected conversations are
  /// skipped and counted in `refused`; the rest are removed. Refusing the whole
  /// batch would break the shipped "sweep the spam, keep the notice" behaviour
  /// (#6971), so the caller gets counts and decides what to say (#8391). The
  /// transaction still covers every row it does remove.
  ///
  /// Throws:
  ///
  /// * `InvalidDataException` if a database constraint is violated.
  Future<({int removed, int refused})> removeConversations(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) return (removed: 0, refused: 0);
    final owner = _ownerPubkey;
    if (owner == null) {
      throw StateError('Cannot remove conversations without a known owner.');
    }

    final removable = <String>[];
    var refused = 0;
    for (final conversationId in conversationIds) {
      switch (await _resolveRemoval(conversationId, ownerPubkey: owner)) {
        case _RemovalDisposition.protected:
          refused++;
        case _RemovalDisposition.absent:
          // Dropped from the batch rather than tombstoned, for the reason on
          // [removeConversation]. This is the reachable form of that bug: ids
          // are collected when the list renders and acted on later, so a row
          // that goes away in between arrives here absent. It stays out of
          // `removed` too, which already counted DAO deletes rather than
          // requests.
          break;
        case _RemovalDisposition.removable:
          removable.add(conversationId);
      }
    }
    if (removable.isEmpty) return (removed: 0, refused: refused);
    var removed = 0;
    await _conversationsDao.runInTransaction<void>(() async {
      // Snapshot the owner for the whole transaction: an account switch
      // mid-flight must not mix one account's reads with another's writes.
      final removedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _removedConversationsDao?.recordAll(
        conversationIds: removable,
        ownerPubkey: owner,
        removedAt: removedAt,
      );
      await _directMessagesDao.deleteMultipleConversationMessages(
        removable,
        ownerPubkey: owner,
      );
      removed = await _conversationsDao.deleteMultiple(
        removable,
        ownerPubkey: owner,
      );
      await _outgoingDmsDao?.deleteForConversations(
        conversationIds: removable,
        ownerPubkey: owner,
      );
      await _reactionsRepository?.deleteForConversations(
        removable,
        ownerPubkey: owner,
      );
    });
    return (removed: removed, refused: refused);
  }

  /// Count the total number of messages in a conversation.
  ///
  /// Returns `0` when no owner is known. Ownerless reads fail closed because
  /// the DAO's legacy null-owner contract otherwise widens them to every row.
  Future<int> countMessagesInConversation(String conversationId) async {
    final owner = _ownerPubkey;
    if (owner == null) return 0;
    return _directMessagesDao.countMessages(conversationId, ownerPubkey: owner);
  }

  // -------------------------------------------------------------------------
  // Query - Messages
  // -------------------------------------------------------------------------

  /// Watch messages in a conversation (reactive stream).
  ///
  /// Emits a single empty list when no owner is known. Ownerless reads fail
  /// closed because the DAO's legacy null-owner contract otherwise widens them
  /// to every row.
  /// It emits rather than staying silent so a consumer combining this with
  /// another stream still ticks; `ConversationBloc` holds its own loading
  /// state over that window rather than rendering an empty thread.
  Stream<List<DmMessage>> watchMessages(String conversationId) {
    final owner = _ownerPubkey;
    if (owner == null) {
      return Stream<List<DmMessage>>.value(const []);
    }
    return _directMessagesDao
        .watchMessagesForConversation(conversationId, ownerPubkey: owner)
        .map((rows) => rows.map(_messageFromRow).toList());
  }

  /// Watch the durable `outgoing_dms` queue rows for [conversationId],
  /// scoped to the active owner. Empty stream when no row is queued or
  /// when no [OutgoingDmsDao] is wired (legacy test fixtures).
  ///
  /// Pair with [watchMessages] in the conversation bloc to render in-flight,
  /// partial-delivery, and recipient-failed bubbles alongside the
  /// persisted timeline. [sendMessage] enqueues a row before any signer
  /// round-trip, so the first tick of this stream lands within
  /// microseconds of dispatch — replacing the in-memory
  /// `pendingOptimistic` slice introduced for #4193.
  Stream<List<OutgoingDm>> watchOutgoing(String conversationId) {
    final dao = _outgoingDmsDao;
    final owner = _ownerPubkey;
    // Signed-out / not-yet-ready states leave the queue invisible to
    // the bloc — there is no owner to scope the rows to. The next
    // auth flip recreates the bloc (BlocProvider keyed on repo
    // identity) and the subscription starts fresh.
    if (dao == null || owner == null) {
      return Stream<List<OutgoingDm>>.value(const []);
    }
    return dao.watchForConversation(
      conversationId: conversationId,
      ownerPubkey: owner,
    );
  }

  /// One-shot read of the durable `outgoing_dms` queue rows for
  /// [conversationId], scoped to the active owner — the non-reactive companion
  /// to [watchOutgoing]. Returns `[]` when no row is queued or when no
  /// [OutgoingDmsDao] / owner is wired.
  ///
  /// The conversation bloc calls this right after a send resolves so a failed
  /// (or partial) bubble repaints immediately, without depending on a
  /// `watchOutgoing` tick that the bloc's stream subscription can miss when the
  /// row transitions while the send event handler is still in flight.
  Future<List<OutgoingDm>> getOutgoing(String conversationId) async {
    final dao = _outgoingDmsDao;
    final owner = _ownerPubkey;
    if (dao == null || owner == null) return const [];
    return dao.getForConversation(
      conversationId: conversationId,
      ownerPubkey: owner,
    );
  }

  /// Get messages in a conversation.
  ///
  /// Returns `[]` when no owner is known. Ownerless reads fail closed because
  /// the DAO's legacy null-owner contract otherwise widens them to every row.
  Future<List<DmMessage>> getMessages(
    String conversationId, {
    int? limit,
  }) async {
    final owner = _ownerPubkey;
    if (owner == null) return const [];
    final rows = await _directMessagesDao.getMessagesForConversation(
      conversationId,
      limit: limit,
      ownerPubkey: owner,
    );
    return rows.map(_messageFromRow).toList();
  }

  /// Starts post-auth maintenance for the current owner unless it has
  /// already run for them, and returns the future the owner-scoped reads
  /// gate on.
  ///
  /// Keyed on the OWNER, not on credentials. Every step is local database
  /// work scoped by `ownerPubkey` and none of it needs a signer, while the
  /// reads it repairs are deliberately served for a signer-less identity
  /// (see [isInitialized]). Scheduling it only from [setCredentials] left
  /// those reads ungated between `identityKnown` and `nostrReady` — and
  /// permanently un-repaired for an identity whose signer never became
  /// ready, so replied-to conversations stayed under Message requests
  /// (#8703, the state #2834's backfill exists to correct).
  ///
  /// Returns a completed future when no owner is known; the callers below
  /// already return early in that case, so nothing is gated on nothing.
  Future<void> _ensurePostAuthMaintenance() {
    final owner = _ownerPubkey;
    if (owner == null || _disposed) return Future<void>.value();
    final existing = _postAuthMaintenance;
    if (existing != null && _maintenanceOwner == owner) return existing;
    // Sequential inside, so each step operates on the previous one's result.
    final started = _runPostAuthMaintenance();
    _maintenanceOwner = owner;
    _postAuthMaintenance = started;
    unawaited(started);
    return started;
  }

  Future<void> _awaitInitialConversationMaintenance() async {
    await _ensurePostAuthMaintenance();
  }

  Stream<List<DmConversation>> _watchConversationRows(
    Stream<List<ConversationRow>> Function() watchRows,
  ) {
    final maintenance = _ensurePostAuthMaintenance();
    return Stream.fromFuture(
      maintenance,
    ).asyncExpand((_) => watchRows()).map((streamRows) {
      return streamRows.map(_conversationFromRow).toList();
    });
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Removes phantom self-conversations created by legacy self-wrap bugs or
  /// malformed participant lists.
  ///
  /// Idempotent — safe to call on every init.
  Future<void> _cleanupSelfConversations() async {
    try {
      final rows = await _conversationsDao.getAllConversations(
        ownerPubkey: _ownerPubkey,
      );
      final selfConversations = rows.where(
        (row) => _containsOnlyPubkey(
          _conversationFromRow(row).participantPubkeys,
          _userPubkey,
        ),
      );
      if (selfConversations.isEmpty) return;

      await _conversationsDao.runInTransaction(() async {
        for (final conversation in selfConversations) {
          await _directMessagesDao.deleteConversationMessages(
            conversation.id,
            ownerPubkey: _ownerPubkey,
          );
          await _conversationsDao.deleteConversation(
            conversation.id,
            ownerPubkey: _ownerPubkey,
          );
        }
      });

      Log.info(
        'Cleaned up ${selfConversations.length} phantom self-conversation(s)',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to clean up self-conversation: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _containsOnlyPubkey(
    Iterable<String> participantPubkeys,
    String pubkey,
  ) =>
      participantPubkeys.isNotEmpty &&
      participantPubkeys.every(
        (participantPubkey) => pubkeysEqual(participantPubkey, pubkey),
      );

  /// Runs post-auth cleanup and migration tasks sequentially so each step
  /// operates on the final state of the previous one.
  Future<void> _runPostAuthMaintenance() async {
    await _cleanupSelfConversations();
    await _backfillCurrentUserHasSent();
    await _backfillConversationPreviews();
    await _purgeReactionsStrandedByRemoval();
    await _recoverGroupConversations();
  }

  /// Rebuilds group conversations a startup dedup pass destroyed (#8407).
  ///
  /// Until #8401 a per-launch pass bucketed conversations by their
  /// alphabetically-first peer and merged any bucket with more than one entry,
  /// reading nothing about `isGroup`. A group `[me, A, B]` and a 1:1 `[me, A]`
  /// share the key `A`, so the group's messages were re-parented onto the 1:1
  /// and the group row was deleted. That destroyed the participant list, and
  /// it keeps destroying the room's future: nothing recreates a group row, so
  /// replies reach only the surviving peer and every other member's next
  /// message forks into its own 1:1.
  ///
  /// The membership survived on the messages. `reassignConversation` wrote a
  /// single column, so each re-parented row still carries the rumor's `p`
  /// tags, and NIP-17 defines the room as `pubkey` + `p` tags.
  ///
  /// Additive by construction: this only ever inserts a conversation row and
  /// moves messages, never deletes a row. A destructive per-launch pass is
  /// what caused the damage.
  Future<void> _recoverGroupConversations() async {
    final owner = _ownerPubkey;
    if (owner == null) return;
    final syncState = _syncState;
    // The pass is naturally idempotent — once the rows are moved, the 1:1 no
    // longer holds foreign-participant messages — so the marker is a cost
    // guard, not a correctness one. `_watchConversationRows` gates the
    // conversation-list stream on this maintenance future, and a full scan on
    // every launch would delay inbox render. With no sync state (most
    // fixtures) just run: idempotency makes that safe.
    if (syncState != null &&
        syncState.groupRecoveryVersion(owner) >=
            DmSyncState.currentGroupRecoveryVersion) {
      return;
    }
    try {
      final conversations = await _conversationsDao.getAllConversations(
        ownerPubkey: owner,
      );
      final restoredRoomIds = <String>{};
      final failedConversationIds = <String>{};
      var recoveryFailed = false;
      for (final conversation in conversations) {
        final restored = await _tryRecoverGroupsFrom(conversation, owner);
        if (restored == null) {
          recoveryFailed = true;
          failedConversationIds.add(conversation.id);
        } else {
          restoredRoomIds.addAll(restored);
        }
      }
      // A message received after the destructive pass could fork into another
      // 1:1 with only one sender, so that bucket cannot attest itself. Once an
      // exact room has been restored above, its existence supplies the missing
      // evidence. Sweep the remaining 1:1s again and reunite those forks.
      if (restoredRoomIds.isNotEmpty) {
        for (final conversation in conversations) {
          if (failedConversationIds.contains(conversation.id)) continue;
          final restored = await _tryRecoverGroupsFrom(
            conversation,
            owner,
            alreadyRestoredRoomIds: restoredRoomIds,
          );
          if (restored == null) recoveryFailed = true;
        }
      }
      if (!recoveryFailed) {
        await syncState?.setGroupRecoveryVersion(
          owner,
          DmSyncState.currentGroupRecoveryVersion,
        );
      }
      if (restoredRoomIds.isNotEmpty) {
        Log.info(
          'Restored ${restoredRoomIds.length} group conversation(s) erased by '
          'the startup dedup pass',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to recover group conversations: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Set<String>?> _tryRecoverGroupsFrom(
    ConversationRow conversation,
    String owner, {
    Set<String> alreadyRestoredRoomIds = const <String>{},
  }) async {
    try {
      return await _recoverGroupsFrom(
        conversation,
        owner,
        alreadyRestoredRoomIds: alreadyRestoredRoomIds,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to recover groups from one conversation: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Restores every attested room hiding inside [conversation].
  ///
  /// [alreadyRestoredRoomIds] permits a second sweep to reunite single-sender
  /// forks with a room that the first sweep positively attested.
  Future<Set<String>> _recoverGroupsFrom(
    ConversationRow conversation,
    String owner, {
    Set<String> alreadyRestoredRoomIds = const <String>{},
  }) async {
    if (conversation.isGroup) return const <String>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(conversation.participantPubkeys);
    } on FormatException {
      return const <String>{};
    }
    if (decoded is! List || decoded.any((value) => value is! String)) {
      return const <String>{};
    }
    final declared = decoded.cast<String>().toSet();
    if (declared.length != 2) return const <String>{};

    // Raw read: the rendering read filters `is_deleted`, and a room whose
    // surviving rows are soft-deleted would look like an ordinary 1:1.
    final rows = await _directMessagesDao
        .getAllMessagesForConversationIncludingDeleted(
          conversation.id,
          ownerPubkey: owner,
        );
    if (rows.isEmpty) return const <String>{};

    final facts = <RecoveryMessageFacts>[];
    for (final row in rows) {
      // Read the raw column, not `DmMessage.tags`: `_parseTagsJson` maps null,
      // empty and malformed alike to `const []`, and a legacy row can be null
      // because `tags_json` arrived through ADD COLUMN, which does not
      // backfill.
      final participants = reconstructParticipants(
        row.tagsJson,
        row.senderPubkey,
      );
      if (participants.isEmpty) continue;
      facts.add(
        RecoveryMessageFacts(
          id: row.id,
          senderPubkey: row.senderPubkey,
          participants: participants,
          replyToId: row.replyToId,
          subject: row.subject,
          createdAt: row.createdAt,
        ),
      );
    }
    if (facts.isEmpty) return const <String>{};

    final roomsByMessageId = {for (final f in facts) f.id: f.participants};
    final declaredKey = canonicalParticipantKey(declared);
    final restoredRoomIds = <String>{};

    for (final entry in bucketByRoom(facts).entries) {
      if (entry.key == declaredKey) continue;
      final bucket = entry.value;
      final room = bucket.first.participants;
      // Only a strictly wider room is damage; anything else is a shape this
      // pass does not understand and must not touch.
      if (!declared.every(room.contains) || room.length <= declared.length) {
        continue;
      }
      final restoredId = computeConversationId(room.toList());
      if (!isAttestedGroup(
        bucket,
        roomsByMessageId,
        requireMultipleSenders: !alreadyRestoredRoomIds.contains(restoredId),
      )) {
        continue;
      }
      if (await _restoreGroupConversation(
        conversation: conversation,
        room: room,
        bucket: bucket,
        owner: owner,
      )) {
        restoredRoomIds.add(restoredId);
      }
    }
    return restoredRoomIds;
  }

  /// Recreates one room and moves its messages. Returns whether it ran.
  Future<bool> _restoreGroupConversation({
    required ConversationRow conversation,
    required Set<String> room,
    required List<RecoveryMessageFacts> bucket,
    required String owner,
  }) async {
    final participants = room.toList()..sort();
    final restoredId = computeConversationId(participants);
    if (restoredId == conversation.id) return false;

    // Never resurrect a room the user deliberately removed (#7811).
    final removedAt = await _removedConversationsDao?.removedAtFor(
      conversationId: restoredId,
      ownerPubkey: owner,
    );
    if (removedAt != null) return false;

    final newest = bucket.reduce((a, b) => b.createdAt >= a.createdAt ? b : a);
    final oldest = bucket.reduce((a, b) => b.createdAt < a.createdAt ? b : a);
    final messageIds = [for (final m in bucket) m.id];

    await _conversationsDao.runInTransaction(() async {
      await _conversationsDao.upsertConversation(
        id: restoredId,
        participantPubkeys: jsonEncode(participants),
        isGroup: true,
        // The surviving 1:1 predates or postdates this room independently.
        // The oldest recovered room message is the closest surviving creation
        // boundary for the deleted group row.
        createdAt: oldest.createdAt,
        lastMessageTimestamp: newest.createdAt,
        lastMessageSenderPubkey: newest.senderPubkey,
        // NIP-17: the newest subject in the room is the room's subject.
        subject: newestSubject(bucket),
        // Inherited, not derived. `currentUserHasSent: false` plus an
        // unfollowed peer routes a conversation into Message Requests, so
        // deriving these from the moved messages would let a repair hide
        // content the user could already see in the damaged thread.
        isRead: conversation.isRead,
        currentUserHasSent: conversation.currentUserHasSent,
        ownerPubkey: owner,
        // Group rooms are NIP-17. The surviving 1:1 may instead be NIP-04.
        dmProtocol: 'nip17',
      );
      await _directMessagesDao.reassignMessages(
        messageIds: messageIds,
        toConversationId: restoredId,
        ownerPubkey: owner,
      );
      // Reactions record the conversation their target belongs to and render
      // off that pair, so they move with the messages or the chips vanish.
      await _reactionsRepository?.reassignForMovedMessages(
        targetMessageIds: messageIds,
        toConversationId: restoredId,
        ownerPubkey: owner,
      );
    });

    await _refreshConversationPreview(restoredId);
    await _refreshConversationPreview(conversation.id);
    return true;
  }

  /// Drops reaction rows left behind by a conversation removal on a build that
  /// predates the removal-time cleanup (#7857).
  ///
  /// Those rows are an outgoing queue, not a render cache, so the retry sweep
  /// keeps re-driving them and can publish a gift wrap into a conversation the
  /// user removed. The sweep's attempt budget is in memory, so it resets on
  /// every cold start and they never age out.
  ///
  /// The read side is guarded independently — the retry queries exclude
  /// tombstoned rows — so a sweep that fires before this finishes still cannot
  /// publish one. This reclaims the rows.
  ///
  /// Idempotent — a no-op once the account has none left.
  Future<void> _purgeReactionsStrandedByRemoval() async {
    final owner = _ownerPubkey;
    if (owner == null) return;
    try {
      final purged = await _reactionsRepository?.purgeStrandedByRemoval(
        ownerPubkey: owner,
      );
      if (purged != null && purged > 0) {
        Log.info(
          'Purged $purged DM reaction rows stranded by a removed conversation',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to purge reactions stranded by removed conversations: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Backfills `currentUserHasSent` for conversations where the column
  /// was added with DEFAULT 0 but the user has actually sent messages.
  ///
  /// Fixes #2834 — without this, all pre-existing conversations appear
  /// as message requests instead of in the Messages tab.
  ///
  /// Idempotent — safe to call on every init. Becomes a no-op once all
  /// conversations are correctly flagged.
  Future<void> _backfillCurrentUserHasSent() async {
    try {
      final updated = await _conversationsDao.backfillCurrentUserHasSent(
        _userPubkey,
      );
      if (updated > 0) {
        Log.info(
          'Backfilled currentUserHasSent for $updated conversations',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to backfill currentUserHasSent: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Backfills denormalized latest-message preview columns in conversations.
  ///
  /// Fixes stale previews created before the write-path timestamp guard landed,
  /// after which conversation rows become the source of truth again.
  Future<void> _backfillConversationPreviews() async {
    try {
      final updated = await _conversationsDao.backfillLatestMessagePreviews(
        ownerPubkey: _ownerPubkey,
      );
      if (updated > 0) {
        Log.info(
          'Backfilled latest message previews for $updated conversations',
          category: LogCategory.system,
        );
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to backfill latest message previews: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Compute a deterministic conversation ID from sorted participant pubkeys.
  static String computeConversationId(List<String> participants) {
    final sorted = List<String>.from(participants)..sort();
    final joined = sorted.join(':');
    return sha256.convert(utf8.encode(joined)).toString();
  }

  /// The current user's public key.
  ///
  /// Returns an empty string if no storage owner is known. This is independent
  /// of signer/client readiness; use [isInitialized] for publish capability.
  String get userPubkey => _userPubkey;

  /// Emits the user's pubkey each time credentials are attached (see
  /// [setCredentials]). Seed a listener with the current [userPubkey] via
  /// `userPubkeyStream.startWith(repo.userPubkey)` so it has a value before the
  /// first credential change. Drives re-classification of identity-scoped
  /// streams on cold-start auth. See #5374.
  Stream<String> get userPubkeyStream => _userPubkeyController.stream;

  void _assertInitialized() {
    if (!isInitialized) {
      throw StateError(
        'DmRepository has not been initialized. '
        'Call initialize() before sending messages.',
      );
    }
  }

  List<String> _extractParticipants(Event rumorEvent) {
    final pubkeys = <String>{rumorEvent.pubkey};
    for (final tag in rumorEvent.tags) {
      if (tag.length >= 2 && tag[0] == 'p') {
        pubkeys.add(tag[1]);
      }
    }
    return pubkeys.toList()..sort();
  }

  /// Resolves the participant list for conversation routing.
  ///
  /// When a rumor has more p-tags than a standard 1:1 (sender + us),
  /// determines whether to route to the full participant group (if one
  /// already exists) or to the canonical 1:1 pair.
  ///
  /// Priority: existing group → existing 1:1 → default to 1:1.
  ///
  /// Defaulting to 1:1 when no conversation exists prevents phantom
  /// groups caused by non-compliant clients adding extra p-tags to
  /// what should be a 1:1 DM.
  Future<List<String>> _resolveConversationParticipants(
    List<String> extractedParticipants,
    String senderPubkey,
  ) async {
    final canonical1to1 = [_userPubkey, senderPubkey]..sort();

    // Standard 1:1 message — no ambiguity.
    if (extractedParticipants.length <= 2) {
      // Self-wrap: sender is the current user, so canonical1to1 would be
      // [self, self]. Use extracted participants which contain the actual
      // recipient from the rumor's p-tags.
      if (_userPubkey == senderPubkey) return extractedParticipants;
      return canonical1to1;
    }

    // Extra p-tags present. Check if a group conversation with the
    // full participant set already exists — if so, it's a genuine group.
    final fullId = computeConversationId(extractedParticipants);
    final existingFull = await _conversationsDao.getConversation(
      fullId,
      ownerPubkey: _ownerPubkey,
    );
    if (existingFull != null) return extractedParticipants;

    // No existing group. Check if a 1:1 conversation exists.
    final canonical1to1Id = computeConversationId(canonical1to1);
    final existing1to1 = await _conversationsDao.getConversation(
      canonical1to1Id,
      ownerPubkey: _ownerPubkey,
    );
    if (existing1to1 != null) return canonical1to1;

    // Neither exists. Default to 1:1 — prevents phantom groups from
    // non-compliant clients that add extra p-tags to 1:1 DMs.
    return canonical1to1;
  }

  /// Extracts Kind 15 file metadata from event tags.
  DmFileMetadata? _extractFileMetadata(Event rumorEvent) {
    String? fileType;
    String? encryptionAlgorithm;
    String? decryptionKey;
    String? decryptionNonce;
    String? fileHash;
    String? originalFileHash;
    int? fileSize;
    String? dimensions;
    String? blurhash;
    String? thumbnailUrl;

    for (final tag in rumorEvent.tags) {
      if (tag.length < 2) continue;
      switch (tag[0]) {
        case 'file-type':
          fileType = tag[1];
        case 'encryption-algorithm':
          encryptionAlgorithm = tag[1];
        case 'decryption-key':
          decryptionKey = tag[1];
        case 'decryption-nonce':
          decryptionNonce = tag[1];
        case 'x':
          fileHash = tag[1];
        case 'ox':
          originalFileHash = tag[1];
        case 'size':
          fileSize = int.tryParse(tag[1]);
        case 'dim':
          dimensions = tag[1];
        case 'blurhash':
          blurhash = tag[1];
        case 'thumb':
          thumbnailUrl = tag[1];
      }
    }

    // Required fields per NIP-17
    if (fileType == null ||
        encryptionAlgorithm == null ||
        decryptionKey == null ||
        decryptionNonce == null ||
        fileHash == null) {
      Log.warning(
        'Kind 15 event missing required file metadata tags',
        category: LogCategory.system,
      );
      return null;
    }

    return DmFileMetadata(
      fileType: fileType,
      encryptionAlgorithm: encryptionAlgorithm,
      decryptionKey: decryptionKey,
      decryptionNonce: decryptionNonce,
      fileHash: fileHash,
      originalFileHash: originalFileHash,
      fileSize: fileSize,
      dimensions: dimensions,
      blurhash: blurhash,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Returns a human-readable preview for file messages in conversation list.
  static String _filePreviewText(String? mimeType) {
    if (mimeType == null) return 'Sent a file';
    if (mimeType.startsWith('image/')) return 'Sent a photo';
    if (mimeType.startsWith('video/')) return 'Sent a video';
    if (mimeType.startsWith('audio/')) return 'Sent an audio message';
    return 'Sent a file';
  }

  DmConversation _conversationFromRow(ConversationRow row) {
    final pubkeys = (jsonDecode(row.participantPubkeys) as List<dynamic>)
        .cast<String>();
    return DmConversation(
      id: row.id,
      participantPubkeys: pubkeys,
      isGroup: row.isGroup,
      createdAt: row.createdAt,
      lastMessageContent: row.lastMessageContent,
      lastMessageTimestamp: row.lastMessageTimestamp,
      lastMessageSenderPubkey: row.lastMessageSenderPubkey,
      subject: row.subject,
      isRead: row.isRead,
      currentUserHasSent: row.currentUserHasSent,
      dmProtocol: row.dmProtocol,
    );
  }

  DmMessage _messageFromRow(DirectMessageRow row) {
    final DmFileMetadata? fileMetadata;
    if (row.messageKind == EventKind.fileMessage &&
        row.fileType != null &&
        row.decryptionKey != null &&
        row.decryptionNonce != null &&
        row.fileHash != null) {
      fileMetadata = DmFileMetadata(
        fileType: row.fileType!,
        encryptionAlgorithm: row.encryptionAlgorithm ?? 'aes-gcm',
        decryptionKey: row.decryptionKey!,
        decryptionNonce: row.decryptionNonce!,
        fileHash: row.fileHash!,
        originalFileHash: row.originalFileHash,
        fileSize: row.fileSize,
        dimensions: row.dimensions,
        blurhash: row.blurhash,
        thumbnailUrl: row.thumbnailUrl,
      );
    } else {
      fileMetadata = null;
    }

    final tags = _parseTagsJson(row.tagsJson);
    return DmMessage(
      id: row.id,
      conversationId: row.conversationId,
      senderPubkey: row.senderPubkey,
      content: row.content,
      createdAt: row.createdAt,
      giftWrapId: row.giftWrapId,
      messageKind: row.messageKind,
      replyToId: row.replyToId,
      subject: row.subject,
      tags: tags,
      fileMetadata: fileMetadata,
      sharedVideoRef: DmSharedVideoCitation.parse(tags),
      sendBatchId: row.sendBatchId,
      retractionStatus: switch (row.deletionPublishStatus) {
        DirectMessagesDao.deletionPending => DmRetractionStatus.pending,
        DirectMessagesDao.deletionBlocked => DmRetractionStatus.failed,
        _ => DmRetractionStatus.none,
      },
    );
  }

  List<List<String>> _parseTagsJson(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is! List) return const [];
      final tags = <List<String>>[];
      for (final tag in decoded) {
        if (tag is! List) continue;
        tags.add(tag.whereType<String>().toList());
      }
      return tags;
    } on FormatException {
      return const [];
    }
  }

  /// Validates that [pubkey] is a 64-character hex string.
  ///
  /// Throws [ArgumentError] if the pubkey is invalid.
  static void validatePubkey(String pubkey) {
    if (!NostrHexUtils.isValidPubkey(pubkey)) {
      throw ArgumentError.value(
        pubkey,
        'pubkey',
        'must be a 64-character hex string',
      );
    }
  }

  /// Whether [pubkey] addresses the signed-in user.
  ///
  /// Compared case-insensitively because [validatePubkey] accepts upper-case
  /// hex (`[0-9a-fA-F]{64}`), so an exact `==` would let `A1B2…` through as a
  /// different person from `a1b2…`.
  bool _isSelf(String pubkey) => pubkeysEqual(pubkey, _userPubkey);

  Never _dummyRelay(String url) {
    throw UnimplementedError('Relay not needed for decryption');
  }
}
