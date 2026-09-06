// ABOUTME: Repository for managing user reposts (Kind 16 generic reposts).
// ABOUTME: Coordinates between NostrClient for relay operations and
// ABOUTME: RepostsLocalStorage for persistence. Handles Kind 16 reposts
// ABOUTME: and Kind 5 deletions for repost/unrepost.
// ABOUTME: Supports offline queuing via callback injection.

import 'dart:async';
import 'dart:math';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:reposts_repository/src/blocked_reposter_filter.dart';
import 'package:reposts_repository/src/exceptions.dart';
import 'package:reposts_repository/src/models/repost_record.dart';
import 'package:reposts_repository/src/models/reposts_sync_result.dart';
import 'package:reposts_repository/src/reposts_local_storage.dart';
import 'package:reposts_repository/src/reposts_repository_reportable_sites.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Default limit for fetching user reposts from relays.
const _defaultRepostFetchLimit = 500;

/// Callback to check if the device is currently online
typedef IsOnlineCallback = bool Function();

/// Callback to queue an action for offline sync
typedef QueueOfflineRepostCallback =
    Future<void> Function({
      required bool isRepost,
      required String addressableId,
      required String originalAuthorPubkey,
      String? eventId,
    });

/// Reporter port for programming-invariant violations swallowed by the
/// best-effort local-storage paths.
///
/// The repository swallows local-storage failures so an unusable cache can
/// never block a relay publish. Expected IO and corruption failures stay in
/// the unified log, but an `Error` — `StateError`, `TypeError`,
/// `RangeError` — means the storage layer itself is broken, and a swallowed
/// bug is a bug nobody ever sees. Wiring an implementation routes that
/// signal to Crashlytics without crossing the `reposts_repository` → app
/// package boundary.
///
/// [site] is one of `RepostsRepositoryReportableSites`'s constants and is
/// used as the Crashlytics `reason:` suffix so the dashboard aggregates per
/// swallow site.
///
/// Implementations MUST NOT throw — the repository invokes this from inside
/// the swallow and any throw would defeat it.
typedef RepostsRepositoryErrorReporter =
    void Function(Object error, StackTrace stackTrace, {required String site});

/// Repository for managing user reposts (Kind 16 generic reposts) on videos.
///
/// This repository provides a unified interface for:
/// - Reposting videos (publishing Kind 16 generic repost events)
/// - Unreposting videos (publishing Kind 5 deletion events)
/// - Querying repost status
/// - Syncing user's reposts from relays
/// - Persisting repost records locally
///
/// The repository abstracts away the complexity of:
/// - Managing the mapping between addressable IDs and repost event IDs
/// - Coordinating between Nostr relays and local storage
/// - Handling optimistic updates and error recovery
///
/// This implementation:
/// - Uses `NostrClient` to publish reposts and deletions to relays
/// - Uses `RepostsLocalStorage` to persist repost records locally
/// - Maintains an in-memory cache for fast lookups
/// - Provides reactive streams for UI updates
/// - Supports real-time cross-device sync via persistent subscriptions
class RepostsRepository {
  /// Creates a new reposts repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication
  /// - [localStorage]: Optional local storage for persistence
  /// - [isOnline]: Optional callback to check connectivity status
  /// - [queueOfflineAction]: Optional callback to queue actions when offline
  /// - [blockFilter]: Optional callback to hide blocked/muted users from
  ///   engagement lists ([fetchEventReposters])
  /// - [errorReporter]: Optional reporter invoked from the best-effort
  ///   local-storage swallow sites when the swallowed failure is a
  ///   programming-invariant violation (see
  ///   [RepostsRepositoryErrorReporter]). Defaults to `null` so test
  ///   fixtures need no rewiring; production wires it through
  ///   `repostsRepositoryProvider` to forward to Crashlytics.
  RepostsRepository({
    required NostrClient nostrClient,
    RepostsLocalStorage? localStorage,
    IsOnlineCallback? isOnline,
    QueueOfflineRepostCallback? queueOfflineAction,
    BlockedReposterFilter? blockFilter,
    RepostsRepositoryErrorReporter? errorReporter,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction,
       _blockFilter = blockFilter,
       _errorReporter = errorReporter;

  final NostrClient _nostrClient;
  final RepostsLocalStorage? _localStorage;

  /// Reporter for invariant violations swallowed by the storage paths.
  final RepostsRepositoryErrorReporter? _errorReporter;

  /// Callback to hide blocked/muted users from engagement lists
  final BlockedReposterFilter? _blockFilter;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineRepostCallback? _queueOfflineAction;

  /// In-memory cache of repost records keyed by addressable ID.
  final Map<String, RepostRecord> _repostRecords = {};

  /// Local count cache keyed by addressable ID (or event ID for
  /// non-addressable videos).
  ///
  /// Populated on relay fetches and adjusted on toggle operations.
  /// This survives BLoC disposal (since the repository is a singleton) and
  /// prevents both redundant relay queries on scroll-back and stale NIP-45
  /// COUNT from relays that haven't processed Kind 5 deletions yet.
  final Map<String, int> _localCountCache = {};

  /// Reactive stream controller for reposted addressable IDs.
  final _repostedIdsController = BehaviorSubject<Set<String>>.seeded({});

  /// Whether the repository has been initialized with data from storage.
  bool _isInitialized = false;

  /// Whether local storage has proven unusable during this session.
  ///
  /// Latched by any swallowed storage failure. A store that cannot answer a
  /// read or a write also cannot serve a live query stream, so
  /// [watchRepostedAddressableIds] must not hand the UI a stream backed by
  /// it — see that method for why a dead stream costs the repost button its
  /// state.
  bool _storageDegraded = false;

  /// Whether [dispose] has been called.
  ///
  /// Once disposed, all stream emissions are no-ops.
  bool _isDisposed = false;

  /// Real-time sync subscription for cross-device synchronization.
  StreamSubscription<Event>? _repostSubscription;
  String? _repostSubscriptionId;

  /// Emits the current set of reposted addressable IDs.
  ///
  /// Guards against emitting after [dispose] has been called or the controller
  /// has been closed, which can happen if [clearCache] runs during or after
  /// [dispose] (e.g. on logout).
  void _emitRepostedIds() {
    if (_isDisposed || _repostedIdsController.isClosed) return;
    _repostedIdsController.add(_repostRecords.keys.toSet());
  }

  /// Stream of reposted addressable IDs (reactive).
  ///
  /// Emits a new set whenever the user's reposts change.
  /// This is useful for UI components that need to reactively update.
  ///
  /// Backed by local storage's own query stream when storage is healthy, and
  /// by the repository's in-memory cache when it is not. The fallback is what
  /// keeps the repost button honest on a device whose database is present but
  /// unreadable: storage's stream never emits there, while every mutation
  /// still ticks [_repostedIdsController], so a UI wired to the dead stream
  /// would show the publish succeed and the button never flip.
  Stream<Set<String>> watchRepostedAddressableIds() async* {
    // Initialize before choosing the source so a broken store has already
    // been observed by the time the choice is made.
    await _ensureInitialized();
    final localStorage = _localStorage;
    if (localStorage != null && !_storageDegraded) {
      yield* localStorage.watchRepostedAddressableIds();
    } else {
      yield* _repostedIdsController.stream;
    }
  }

  /// Get the current set of reposted addressable IDs.
  ///
  /// This is a one-shot query that returns the current state.
  Future<Set<String>> getRepostedAddressableIds() async {
    await _ensureInitialized();
    return _repostRecords.keys.toSet();
  }

  /// Get reposted addressable IDs ordered by recency (most recent first).
  ///
  /// Returns a list of addressable IDs sorted by the `createdAt` timestamp
  /// of the repost, with the most recent reposts first.
  Future<List<String>> getOrderedRepostedAddressableIds() async {
    await _ensureInitialized();

    // Sort records by createdAt descending (most recent first)
    final sortedRecords = _repostRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedRecords.map((r) => r.addressableId).toList();
  }

  /// Check if a specific video is reposted.
  ///
  /// Returns `true` if the user has reposted the video, `false` otherwise.
  Future<bool> isReposted(String addressableId) async {
    await _ensureInitialized();
    return _repostRecords.containsKey(addressableId);
  }

  /// Check if a video is reposted (synchronous, from cache only).
  ///
  /// This is useful for UI components that need immediate feedback.
  /// Note: May return stale data if cache hasn't been initialized.
  bool isRepostedSync(String addressableId) {
    return _repostRecords.containsKey(addressableId);
  }

  /// Cache a locally-adjusted repost count for a video.
  ///
  /// Called internally after a successful toggle to preserve the correct count
  /// across BLoC recreations (e.g. when scrolling away and back in the feed).
  /// This prevents stale NIP-45 COUNT from relays that haven't processed
  /// Kind 5 deletions yet.
  void _cacheRepostCount(String addressableId, int count) {
    _localCountCache[addressableId] = max(0, count);
  }

  /// Get the repost count for a video by its addressable ID.
  ///
  /// Returns a locally-cached count if available (set by recent toggle
  /// operations), otherwise queries relays via NIP-45 COUNT.
  ///
  /// Note: This counts all reposts from all users, not just the current user's.
  Future<int> getRepostCount(String addressableId) async {
    // Use local cache if available (set by recent toggle operations or a
    // previous relay fetch). This prevents redundant relay queries when
    // scrolling back to an already-viewed video.
    if (_localCountCache.containsKey(addressableId)) {
      return _localCountCache[addressableId]!;
    }

    // Query relays for count of Kind 16 reposts referencing this addressable ID
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      a: [addressableId],
    );

    final result = await _nostrClient.countEvents([filter]);
    _cacheRepostCount(addressableId, result.count);
    return result.count;
  }

  /// Get the repost count for a video by its event ID.
  ///
  /// Queries relays for the count of Kind 6 (repost) and Kind 16 (generic
  /// repost) events referencing the video by its event ID (using the `e` tag).
  ///
  /// Use this method for non-addressable videos (videos without a d-tag).
  ///
  /// Note: This counts all reposts from all users, not just the current user's.
  Future<int> getRepostCountByEventId(String eventId) async {
    if (_localCountCache.containsKey(eventId)) {
      return _localCountCache[eventId]!;
    }

    // Query relays for count of Kind 6 and Kind 16 reposts referencing this
    // event ID
    final filter = Filter(
      kinds: const [EventKind.repost, EventKind.genericRepost],
      e: [eventId],
    );

    final result = await _nostrClient.countEvents([filter]);
    _cacheRepostCount(eventId, result.count);
    return result.count;
  }

  /// Repost a video.
  ///
  /// Creates and publishes a Kind 16 generic repost event.
  /// The repost event is broadcast to Nostr relays and the mapping
  /// is stored locally for later retrieval.
  ///
  /// If the device is offline and offline queuing is enabled, the action
  /// is queued for later sync and the UI should be updated optimistically.
  ///
  /// Parameters:
  /// - [addressableId]: The addressable ID of the video (kind:pubkey:d-tag)
  /// - [originalAuthorPubkey]: The pubkey of the video's author
  /// - [eventId]: Optional event ID for better relay compatibility. Including
  ///   this allows relays to index the repost by `#e` tag, which is more
  ///   universally supported than `#a` tag.
  ///
  /// Returns the repost event ID (needed for unreposts), or a placeholder
  /// ID if the action was queued for offline sync.
  ///
  /// Throws `RepostFailedException` if the operation fails.
  /// Throws `AlreadyRepostedException` if the video is already reposted.
  /// Throws `MissingDTagException` if the video is missing a d-tag.
  Future<String> repostVideo({
    required String addressableId,
    required String originalAuthorPubkey,
    String? eventId,
  }) async {
    await _ensureInitialized();

    // Check if already reposted
    if (_repostRecords.containsKey(addressableId)) {
      throw AlreadyRepostedException(addressableId);
    }

    // Snapshot for rollback if the network publish fails
    final previousCount = _localCountCache[addressableId];

    // 1. Optimistic-first: write to memory + local storage and tick the
    // watchRepostedAddressableIds stream BEFORE any network I/O. The UI
    // flips here. Mirrors LikesRepository.likeEvent's order-of-operations
    // so reposts match the Follow pattern — local DB first, network confirms.
    // Storage write is awaited so the placeholder survives an app crash
    // before sync; PendingActionService (offline) and executeRepostAction
    // (sync) reconcile the placeholder ID with the real repost event ID.
    final placeholderId = 'pending_repost_$addressableId';
    final placeholder = RepostRecord(
      addressableId: addressableId,
      repostEventId: placeholderId,
      originalAuthorPubkey: originalAuthorPubkey,
      createdAt: DateTime.now(),
    );
    _repostRecords[addressableId] = placeholder;
    await _bestEffortLocalStorage(
      () async => _localStorage?.saveRepostRecord(placeholder),
      description: 'saving the repost placeholder',
      site: RepostsRepositoryReportableSites.repostVideoSavePlaceholder,
    );
    if (previousCount != null) {
      _cacheRepostCount(addressableId, previousCount + 1);
    }
    _emitRepostedIds();

    // 2. Offline → leave the optimistic state in place; queue replays later
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(
        isRepost: true,
        addressableId: addressableId,
        originalAuthorPubkey: originalAuthorPubkey,
        eventId: eventId,
      );
      return placeholderId;
    }

    // 3. Online → publish kind 16; on success swap placeholder for real id.
    // On failure, prefer queuing via [_queueOfflineAction] when wired so the
    // optimistic state survives transient relay-pool problems (mirror of
    // [LikesRepository.likeEvent]). Without a wired callback, fall back to
    // rollback + rethrow to preserve the original contract for tests and
    // non-app embedders.
    try {
      final sentEvent = await _nostrClient.sendGenericRepost(
        addressableId: addressableId,
        targetKind: EventKind.videoVertical,
        authorPubkey: originalAuthorPubkey,
        eventId: eventId,
      );

      if (sentEvent == null) {
        throw const RepostFailedException('Failed to publish repost to relays');
      }

      final confirmed = RepostRecord(
        addressableId: addressableId,
        repostEventId: sentEvent.id,
        originalAuthorPubkey: originalAuthorPubkey,
        createdAt: placeholder.createdAt,
      );
      _repostRecords[addressableId] = confirmed;
      await _bestEffortLocalStorage(
        () async => _localStorage?.saveRepostRecord(confirmed),
        description: 'saving the confirmed repost',
        site: RepostsRepositoryReportableSites.repostVideoSaveConfirmed,
      );

      return sentEvent.id;
    } catch (e, stackTrace) {
      if (_queueOfflineAction != null) {
        Log.error(
          'Repost publish failed; queuing optimistic action for retry',
          name: 'RepostsRepository',
          category: LogCategory.relay,
          error: e,
          stackTrace: stackTrace,
        );
        await _queueOfflineAction(
          isRepost: true,
          addressableId: addressableId,
          originalAuthorPubkey: originalAuthorPubkey,
          eventId: eventId,
        );
        return placeholderId;
      }
      _repostRecords.remove(addressableId);
      await _bestEffortLocalStorage(
        () async => _localStorage?.deleteRepostRecord(addressableId),
        description: 'rolling back the repost placeholder',
        site: RepostsRepositoryReportableSites.repostVideoRollbackPlaceholder,
      );
      if (previousCount != null) {
        _cacheRepostCount(addressableId, previousCount);
      }
      _emitRepostedIds();
      rethrow;
    }
  }

  /// Execute a repost action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly publishes to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<String> executeRepostAction({
    required String addressableId,
    required String originalAuthorPubkey,
    String? eventId,
  }) async {
    // Create and publish Kind 16 generic repost event
    final sentEvent = await _nostrClient.sendGenericRepost(
      addressableId: addressableId,
      targetKind: EventKind.videoVertical,
      authorPubkey: originalAuthorPubkey,
      eventId: eventId,
    );

    if (sentEvent == null) {
      throw const RepostFailedException('Failed to publish repost to relays');
    }

    // Update local record with real event ID if we have a placeholder
    final existingRecord = _repostRecords[addressableId];
    if (existingRecord != null &&
        existingRecord.repostEventId.startsWith('pending_')) {
      final record = RepostRecord(
        addressableId: addressableId,
        repostEventId: sentEvent.id,
        originalAuthorPubkey: originalAuthorPubkey,
        createdAt: existingRecord.createdAt,
      );
      _repostRecords[addressableId] = record;
      await _localStorage?.saveRepostRecord(record);
    }

    return sentEvent.id;
  }

  /// Unrepost a video.
  ///
  /// Creates and publishes a Kind 5 deletion event referencing the
  /// original repost event. Removes the repost record from local storage.
  ///
  /// If the device is offline and offline queuing is enabled, the action
  /// is queued for later sync and the UI should be updated optimistically.
  ///
  /// Throws `UnrepostFailedException` if the operation fails.
  /// Throws `NotRepostedException` if the video is not currently reposted.
  Future<void> unrepostVideo(String addressableId) async {
    await _ensureInitialized();

    // Try in-memory cache first, then fall back to database.
    // This handles the case where the cache hasn't been populated yet.
    var record = _repostRecords[addressableId];
    final localStorage = _localStorage;
    if (record == null && localStorage != null) {
      record = await _bestEffortLocalStorage<RepostRecord?>(
        () => localStorage.getRepostRecord(addressableId),
        description: 'reading the repost record',
        site: RepostsRepositoryReportableSites.unrepostVideoReadRecord,
      );
    }

    // A swallowed read failure is indistinguishable from "no such record"
    // here, so a degraded store reports "not reposted" when the truth is
    // "cannot tell". Both answers end the same way — there is no repost
    // event id to reference in a Kind 5, so nothing can be published either
    // way — and widening the contract with a second exception would push a
    // distinction the UI has no recovery for onto every caller.
    if (record == null) {
      throw NotRepostedException(addressableId);
    }

    // Snapshot for rollback if the network publish fails
    final snapshotRecord = record;
    final previousCount = _localCountCache[addressableId];

    // 1. Optimistic-first: remove from memory + local storage and tick the
    // watchRepostedAddressableIds stream BEFORE any network I/O (mirror of
    // repostVideo).
    _repostRecords.remove(addressableId);
    await _bestEffortLocalStorage(
      () async => _localStorage?.deleteRepostRecord(addressableId),
      description: 'deleting the repost record',
      site: RepostsRepositoryReportableSites.unrepostVideoDeleteRecord,
    );
    if (previousCount != null) {
      _cacheRepostCount(addressableId, previousCount - 1);
    }
    _emitRepostedIds();

    // 2. Offline → leave the optimistic state in place; queue replays later
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(
        isRepost: false,
        addressableId: addressableId,
        originalAuthorPubkey: snapshotRecord.originalAuthorPubkey,
      );
      return;
    }

    // 3. Online → publish kind 5 (skipped for never-synced placeholders).
    // On failure, prefer queuing via [_queueOfflineAction] when wired so the
    // optimistic unrepost survives transient relay-pool problems (mirror of
    // [repostVideo]). Without a wired callback, fall back to rollback +
    // rethrow to preserve the original contract.
    if (snapshotRecord.repostEventId.startsWith('pending_')) {
      // Pending repost never reached the relay; nothing to delete on the wire.
      return;
    }

    try {
      final deletionEvent = await _nostrClient.deleteEvent(
        snapshotRecord.repostEventId,
      );
      if (deletionEvent == null) {
        throw const UnrepostFailedException(
          'Failed to publish unrepost deletion',
        );
      }
    } catch (e, stackTrace) {
      if (_queueOfflineAction != null) {
        Log.error(
          'Unrepost publish failed; queuing optimistic action for retry',
          name: 'RepostsRepository',
          category: LogCategory.relay,
          error: e,
          stackTrace: stackTrace,
        );
        await _queueOfflineAction(
          isRepost: false,
          addressableId: addressableId,
          originalAuthorPubkey: snapshotRecord.originalAuthorPubkey,
        );
        return;
      }
      _repostRecords[addressableId] = snapshotRecord;
      await _bestEffortLocalStorage(
        () async => _localStorage?.saveRepostRecord(snapshotRecord),
        description: 'restoring the repost record',
        site: RepostsRepositoryReportableSites.unrepostVideoRestoreRecord,
      );
      if (previousCount != null) {
        _cacheRepostCount(addressableId, previousCount);
      }
      _emitRepostedIds();
      if (e is SocialPublishException) {
        Log.error(
          'Unrepost deletion was not accepted',
          name: 'RepostsRepository',
          category: LogCategory.relay,
          error: e,
          stackTrace: stackTrace,
        );
        Error.throwWithStackTrace(
          const UnrepostFailedException(
            'Failed to publish unrepost deletion',
          ),
          stackTrace,
        );
      }
      rethrow;
    }
  }

  /// Execute an unrepost action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly publishes to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<void> executeUnrepostAction(String addressableId) async {
    // Try to get the record - it may not exist if the repost was also offline
    var record = _repostRecords[addressableId];
    if (record == null && _localStorage != null) {
      record = await _localStorage.getRepostRecord(addressableId);
    }

    // If no record exists, the repost was never synced either, so we're done
    if (record == null) {
      return;
    }

    // Skip publishing if this was a pending repost
    if (record.repostEventId.startsWith('pending_')) {
      // Just clean up local storage
      _repostRecords.remove(addressableId);
      await _localStorage?.deleteRepostRecord(addressableId);
      _emitRepostedIds();
      return;
    }

    // Publish Kind 5 deletion event via NostrClient
    final Event? deletionEvent;
    try {
      deletionEvent = await _nostrClient.deleteEvent(record.repostEventId);
    } on SocialPublishException catch (error, stackTrace) {
      Log.error(
        'Queued unrepost deletion was not accepted',
        name: 'RepostsRepository',
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(
        const UnrepostFailedException('Failed to publish unrepost deletion'),
        stackTrace,
      );
    }

    if (deletionEvent == null) {
      throw const UnrepostFailedException(
        'Failed to publish unrepost deletion',
      );
    }

    // Remove from cache and storage
    _repostRecords.remove(addressableId);
    await _localStorage?.deleteRepostRecord(addressableId);
    _emitRepostedIds();
  }

  /// Toggle repost status for a video.
  ///
  /// If the video is not reposted, reposts it and returns `true`.
  /// If the video is reposted, unreposts it and returns `false`.
  ///
  /// Parameters:
  /// - [addressableId]: The addressable ID of the video (kind:pubkey:d-tag)
  /// - [originalAuthorPubkey]: The pubkey of the video's author
  /// - [eventId]: Optional event ID for better relay compatibility
  ///
  /// This is a convenience method that combines [isReposted], [repostVideo],
  /// and [unrepostVideo]. Local count cache is maintained inside those
  /// methods, so the displayed count survives BLoC recreation without the
  /// caller needing to thread it through.
  Future<bool> toggleRepost({
    required String addressableId,
    required String originalAuthorPubkey,
    String? eventId,
  }) async {
    await _ensureInitialized();

    // Query the database directly as source of truth to avoid cache/db
    // inconsistency after app restart. Best-effort for the same reason
    // [repostVideo]'s writes are: this is the only entry point the repost
    // button uses, so an unreadable cache throwing here costs the Kind 16
    // outright. A swallowed read falls back to the in-memory cache, which is
    // exactly what the null-storage branch of the `??` already does.
    final isCurrentlyReposted =
        await _bestEffortLocalStorage<bool?>(
          () async => _localStorage?.isReposted(addressableId),
          description: 'checking the repost state',
          site: RepostsRepositoryReportableSites.toggleRepostReadState,
        ) ??
        _repostRecords.containsKey(addressableId);

    if (isCurrentlyReposted) {
      await unrepostVideo(addressableId);
      return false;
    } else {
      await repostVideo(
        addressableId: addressableId,
        originalAuthorPubkey: originalAuthorPubkey,
        eventId: eventId,
      );
      return true;
    }
  }

  /// Get a repost record by addressable ID.
  ///
  /// Returns the full [RepostRecord] including the repost event ID,
  /// or `null` if the video is not reposted.
  Future<RepostRecord?> getRepostRecord(String addressableId) async {
    await _ensureInitialized();
    return _repostRecords[addressableId];
  }

  /// Sync all user's reposts from relays.
  ///
  /// Fetches the user's Kind 16 events from relays and updates local storage.
  /// This should be called on startup to ensure local state matches relay
  /// state.
  ///
  /// Returns a [RepostsSyncResult] containing all synced data needed by UI.
  ///
  /// Throws `SyncFailedException` if syncing fails.
  Future<RepostsSyncResult> syncUserReposts() async {
    // First, load from local storage (fast). Best-effort and deliberately
    // outside the relay try/catch below: an unreadable cache must not skip
    // the authoritative relay fetch, which is the whole point of a sync.
    final localStorage = _localStorage;
    if (localStorage != null) {
      final records = await _bestEffortLocalStorage(
        localStorage.getAllRepostRecords,
        description: 'loading persisted reposts for sync',
        site: RepostsRepositoryReportableSites.syncUserRepostsLoadRecords,
      );
      if (records != null) {
        for (final record in records) {
          _repostRecords[record.addressableId] = record;
        }
        _emitRepostedIds();
      }
    }

    try {
      // Signed out: keep whatever local storage gave us rather than throwing —
      // there is nothing to reconcile against, which is not a sync failure.
      final pubkey = await _currentUserPubkey();
      if (pubkey == null) {
        Log.warning(
          'Skipping repost sync: signer has no public key',
          name: 'RepostsRepository',
        );
        _isInitialized = true;
        return _buildSyncResult();
      }

      // Then, fetch from relays (authoritative)
      final filter = Filter(
        kinds: const [EventKind.genericRepost],
        authors: [pubkey],
        limit: _defaultRepostFetchLimit,
      );

      final events = await _nostrClient.queryEvents([filter]);
      final newRecords = <RepostRecord>[];

      for (final event in events) {
        final addressableId = _extractAddressableId(event);
        final authorPubkey = _extractOriginalAuthorPubkey(event);

        if (addressableId != null && authorPubkey != null) {
          final record = RepostRecord(
            addressableId: addressableId,
            repostEventId: event.id,
            originalAuthorPubkey: authorPubkey,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
          );

          // Only update if we don't have this record or the new one is newer
          final existing = _repostRecords[addressableId];
          if (existing == null ||
              record.createdAt.isAfter(existing.createdAt)) {
            _repostRecords[addressableId] = record;
            newRecords.add(record);
          }
        }
      }

      // Batch save new records to storage
      if (newRecords.isNotEmpty && localStorage != null) {
        await _bestEffortLocalStorage(
          () => localStorage.saveRepostRecordsBatch(newRecords),
          description: 'persisting the synced reposts',
          site: RepostsRepositoryReportableSites.syncUserRepostsSaveBatch,
        );
      }

      _emitRepostedIds();
      _isInitialized = true;

      return _buildSyncResult();
    } catch (e) {
      // If relay sync fails but we have local data, don't throw
      if (_repostRecords.isNotEmpty) {
        _isInitialized = true;
        return _buildSyncResult();
      }
      throw SyncFailedException('Failed to sync user reposts: $e');
    }
  }

  /// Fetch reposted addressable IDs for any user from relays.
  ///
  /// Unlike [syncUserReposts], this method:
  /// - Does NOT cache results locally (since it's not the current user's data)
  /// - Does NOT require authentication
  /// - Is intended for viewing other users' reposted content
  ///
  /// Returns a list of addressable IDs that the specified user has reposted,
  /// ordered by recency (most recent first).
  ///
  /// Parameters:
  /// - [pubkey]: The public key (hex) of the user whose reposts to fetch
  ///
  /// Throws [FetchRepostsFailedException] if the fetch fails.
  Future<List<String>> fetchUserReposts(String pubkey) async {
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      authors: [pubkey],
      limit: _defaultRepostFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final repostedIds = <String>[];
      final seenIds = <String>{};

      // Sort events by createdAt descending (most recent first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final event in events) {
        final addressableId = _extractAddressableId(event);
        if (addressableId != null && !seenIds.contains(addressableId)) {
          seenIds.add(addressableId);
          repostedIds.add(addressableId);
        }
      }

      return repostedIds;
    } catch (e) {
      throw FetchRepostsFailedException(
        'Failed to fetch reposts for user $pubkey: $e',
      );
    }
  }

  /// Fetch repost records for any user from relays with full metadata.
  ///
  /// Similar to [fetchUserReposts] but returns full [RepostRecord] objects
  /// including repost event IDs and timestamps.
  ///
  /// Parameters:
  /// - [pubkey]: The public key (hex) of the user whose reposts to fetch
  ///
  /// Throws [FetchRepostsFailedException] if the fetch fails.
  Future<List<RepostRecord>> fetchUserRepostRecords(String pubkey) async {
    final filter = Filter(
      kinds: const [EventKind.genericRepost],
      authors: [pubkey],
      limit: _defaultRepostFetchLimit,
    );

    try {
      final events = await _nostrClient.queryEvents([filter]);
      final records = <RepostRecord>[];
      final seenIds = <String>{};

      // Sort events by createdAt descending (most recent first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final event in events) {
        final addressableId = _extractAddressableId(event);
        final authorPubkey = _extractOriginalAuthorPubkey(event);

        if (addressableId != null &&
            authorPubkey != null &&
            !seenIds.contains(addressableId)) {
          seenIds.add(addressableId);
          records.add(
            RepostRecord(
              addressableId: addressableId,
              repostEventId: event.id,
              originalAuthorPubkey: authorPubkey,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                event.createdAt * 1000,
              ),
            ),
          );
        }
      }

      return records;
    } catch (e) {
      throw FetchRepostsFailedException(
        'Failed to fetch reposts for user $pubkey: $e',
      );
    }
  }

  /// Fetch the list of pubkeys that reposted the given video event.
  ///
  /// Queries Nostr relays for NIP-18 repost events (kind 6 and kind 16)
  /// that reference the target event via the `e` tag and (when
  /// [addressableId] is provided) the `a` tag. Both filters are queried
  /// because clients may reference addressable Kind 30000+ events using
  /// either form, and querying only one would miss reposters tagged with
  /// the other.
  ///
  /// Filters out reposts deleted via Kind 5 deletion events from their
  /// author, and reposters hidden by the injected block filter
  /// (blocked/muted users). Pubkeys are deduplicated and ordered by
  /// repost recency, most recent first.
  ///
  /// Parameters:
  /// - [eventId]: Hex event ID of the target event (required).
  /// - [addressableId]: Optional `kind:pubkey:d-tag` for Kind 30000+
  ///   events.
  ///
  /// Throws [FetchRepostersFailedException] if relay queries fail.
  Future<List<String>> fetchEventReposters({
    required String eventId,
    String? addressableId,
  }) async {
    const repostKinds = [EventKind.repost, EventKind.genericRepost];

    try {
      final eventFilter = Filter(kinds: repostKinds, e: [eventId]);
      final results = <List<Event>>[];
      if (addressableId != null && addressableId.isNotEmpty) {
        final addressableFilter = Filter(
          kinds: repostKinds,
          a: [addressableId],
        );
        final fetched = await Future.wait([
          _nostrClient.queryEvents([eventFilter]),
          _nostrClient.queryEvents([addressableFilter]),
        ]);
        results.addAll(fetched);
      } else {
        results.add(await _nostrClient.queryEvents([eventFilter]));
      }

      final repostsById = <String, Event>{};
      for (final batch in results) {
        for (final event in batch) {
          repostsById[event.id] = event;
        }
      }

      if (repostsById.isEmpty) {
        return <String>[];
      }

      final reposterPubkeys = repostsById.values
          .map((event) => event.pubkey)
          .toSet()
          .toList();
      final deletionFilter = Filter(
        kinds: const [EventKind.eventDeletion],
        authors: reposterPubkeys,
      );
      final deletionEvents = await _nostrClient.queryEvents([deletionFilter]);

      final deletedRepostIds = <String>{};
      for (final deletion in deletionEvents) {
        for (final tag in deletion.tags) {
          if (tag.length > 1 && tag[0] == 'e') {
            final targetId = tag[1];
            final target = repostsById[targetId];
            if (target != null && target.pubkey == deletion.pubkey) {
              deletedRepostIds.add(targetId);
            }
          }
        }
      }

      final liveReposts =
          repostsById.values
              .where((event) => !deletedRepostIds.contains(event.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final orderedPubkeys = <String>[];
      final seen = <String>{};
      for (final event in liveReposts) {
        if (_blockFilter?.call(event.pubkey) ?? false) continue;
        if (seen.add(event.pubkey)) {
          orderedPubkeys.add(event.pubkey);
        }
      }
      return orderedPubkeys;
    } catch (e) {
      throw FetchRepostersFailedException(
        'Failed to fetch reposters for event $eventId: $e',
      );
    }
  }

  /// Builds a [RepostsSyncResult] from the current in-memory cache.
  RepostsSyncResult _buildSyncResult() {
    // Sort records by createdAt descending (most recent first)
    final sortedRecords = _repostRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final orderedAddressableIds = sortedRecords
        .map((r) => r.addressableId)
        .toList();
    final addressableIdToRepostId = <String, String>{};
    for (final record in sortedRecords) {
      addressableIdToRepostId[record.addressableId] = record.repostEventId;
    }

    return RepostsSyncResult(
      orderedAddressableIds: orderedAddressableIds,
      addressableIdToRepostId: addressableIdToRepostId,
    );
  }

  /// Initialize the repository — load from local cache, then subscribe for
  /// real-time cross-device sync.
  ///
  /// Follows the same pattern as `FollowRepository.initialize()`:
  /// 1. Load persisted records from local storage for immediate UI display.
  /// 2. Set up a persistent Kind 16 subscription for live updates.
  ///
  /// Safe to call multiple times (idempotent).
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load from local storage first for immediate UI display. Best-effort:
    // throwing here would skip _subscribeToReposts below, so an unreadable
    // cache would also cost the session its cross-device sync.
    final localStorage = _localStorage;
    if (localStorage != null) {
      final records = await _bestEffortLocalStorage(
        localStorage.getAllRepostRecords,
        description: 'loading persisted reposts at startup',
        site: RepostsRepositoryReportableSites.initializeLoadRecords,
      );
      if (records != null) {
        for (final record in records) {
          _repostRecords[record.addressableId] = record;
        }
        _emitRepostedIds();
      }
    }

    final pubkey = await _currentUserPubkey();
    if (pubkey != null) {
      _subscribeToReposts(pubkey);
    }

    _isInitialized = true;
  }

  /// Subscribe to reposts for real-time sync and cross-device updates.
  ///
  /// Creates a long-running subscription to the current user's Kind 16 events.
  /// When a newer repost arrives (from another device or this one),
  /// updates the local cache.
  void _subscribeToReposts(String currentUserPubkey) {
    // Use a deterministic subscription ID so we can unsubscribe later
    _repostSubscriptionId = 'reposts_repo_reposts_$currentUserPubkey';

    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [currentUserPubkey],
        kinds: const [EventKind.genericRepost],
        limit: 1,
      ),
    ], subscriptionId: _repostSubscriptionId);

    _repostSubscription = eventStream.listen(
      _processIncomingRepost,
      onError: (Object error) {
        // Subscription errors are non-fatal; log and continue
      },
    );
  }

  /// Process an incoming Kind 16 repost event from the subscription.
  ///
  /// Validates the event, deduplicates against existing records, and
  /// updates the in-memory cache + local storage.
  void _processIncomingRepost(Event event) {
    if (_isDisposed) return;

    // Only process Kind 16 generic reposts from the current user
    if (event.kind != EventKind.genericRepost) return;
    if (event.pubkey != _nostrClient.publicKey) return;

    final addressableId = _extractAddressableId(event);
    if (addressableId == null) return;

    final authorPubkey = _extractOriginalAuthorPubkey(event);
    if (authorPubkey == null) return;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      event.createdAt * 1000,
    );

    // Deduplicate: only update if newer than existing record
    final existing = _repostRecords[addressableId];
    if (existing != null && !createdAt.isAfter(existing.createdAt)) return;

    final record = RepostRecord(
      addressableId: addressableId,
      repostEventId: event.id,
      originalAuthorPubkey: authorPubkey,
      createdAt: createdAt,
    );

    _repostRecords[addressableId] = record;
    // Best-effort: `unawaited` attaches no error handler, so a raw rejection
    // here would surface as an uncaught async error in the app's zone guard
    // and reach Crashlytics as exactly the expected-IO noise the decision
    // matrix keeps out.
    unawaited(
      _bestEffortLocalStorage(
        () async => _localStorage?.saveRepostRecord(record),
        description: 'saving a repost from the live subscription',
        site: RepostsRepositoryReportableSites.processIncomingRepostSaveRecord,
      ),
    );
    _emitRepostedIds();
  }

  /// Clear all local repost data. Does not affect data on relays.
  ///
  /// Clears the durable store first, so the clear is all-or-nothing: if
  /// [RepostsLocalStorage.clearAll] throws, the in-memory caches are left
  /// intact, nothing is emitted, and the failure reaches the caller. A clear
  /// that did not happen is therefore never reported as one.
  ///
  /// This is deliberately not routed through `_bestEffortLocalStorage`. That
  /// helper exists so a dead cache cannot block a relay publish; clearing
  /// publishes nothing, and the thing at risk here is the deletion itself.
  /// Erasing a signed-out account's rows is handled by the cleanup in
  /// `social_providers.dart`, which is likewise required to surface failures
  /// rather than swallow them.
  ///
  /// Safe to call after [dispose] -- a successful clear still clears the
  /// cache, but no stream emission is attempted.
  Future<void> clearCache() async {
    await _localStorage?.clearAll();
    _repostRecords.clear();
    _localCountCache.clear();
    _emitRepostedIds();
    _isInitialized = false;
  }

  /// Dispose of resources.
  ///
  /// Cancels the repost subscription and closes the stream controller.
  /// Should be called when the repository is no longer needed.
  void dispose() {
    _isDisposed = true;
    unawaited(_repostSubscription?.cancel());
    if (_repostSubscriptionId != null) {
      unawaited(_nostrClient.unsubscribe(_repostSubscriptionId!));
      _repostSubscriptionId = null;
    }
    unawaited(_repostedIdsController.close());
  }

  /// The signed-in user's pubkey, or `null` when the signer has no key.
  ///
  /// Resolves through [NostrClient.resolvePublicKey] rather than reading
  /// `publicKey` directly, so a signer that acquired its key after the client
  /// initialized is picked up here instead of leaving the author-scoped sync
  /// query filtering on an empty author (#6813).
  Future<String?> _currentUserPubkey() => _nostrClient.resolvePublicKey();

  /// Ensures the repository is initialized with data from storage.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    // Degrade to an in-memory-only cache rather than failing the caller.
    // Callers are publish paths: an unreadable cache costs a stale
    // already-reposted check, while throwing here costs the Kind 16.
    final localStorage = _localStorage;
    if (localStorage != null) {
      final records = await _bestEffortLocalStorage(
        localStorage.getAllRepostRecords,
        description: 'loading persisted reposts',
        site: RepostsRepositoryReportableSites.ensureInitializedLoadRecords,
      );
      if (records != null) {
        for (final record in records) {
          _repostRecords[record.addressableId] = record;
        }
        _emitRepostedIds();
      }
    }
    // Latched on both paths: an unreadable database stays unreadable for the
    // session, so retrying would re-throw on every call instead of degrading.
    _isInitialized = true;
  }

  /// Runs a local-storage side effect that must never block a relay publish.
  ///
  /// The local database is a cache. A repost that reached relays survives
  /// without its cache row; a repost blocked by an unwritable cache is lost
  /// outright. Storage failures are therefore logged and swallowed.
  ///
  /// Expected IO/corruption failures are not Crashlytics-reportable (see the
  /// decision matrix in `.claude/rules/error_handling.md`); the unified log is
  /// where a degraded cache surfaces. Programming-invariant violations are
  /// routed to [_errorReporter] instead of vanishing — see
  /// [_markStorageDegraded].
  ///
  /// [site] is the stable `RepostsRepositoryReportableSites` identifier for
  /// this call site; [description] is the human phrasing used in the log.
  Future<T?> _bestEffortLocalStorage<T>(
    Future<T> Function() operation, {
    required String description,
    required String site,
  }) async {
    try {
      return await operation();
    } on Object catch (e, stackTrace) {
      _markStorageDegraded(e, stackTrace, site: site);
      Log.warning(
        'Local repost storage unavailable ($description); '
        'continuing without it: $e',
        name: 'RepostsRepository',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Latches [_storageDegraded] and reports [error] when it is a
  /// programming-invariant violation.
  ///
  /// Storage IO and corruption failures arrive as `Exception`s
  /// (`SqliteException`, `IOException`) and are expected on a broken device,
  /// so per the decision matrix in `.claude/rules/error_handling.md` they
  /// stay out of Crashlytics. `Error` subtypes — `StateError`, `TypeError`,
  /// `RangeError` — mean the storage layer itself is buggy; swallowing those
  /// silently is how a real defect ships unnoticed behind a warning log.
  void _markStorageDegraded(
    Object error,
    StackTrace stackTrace, {
    required String site,
  }) {
    _storageDegraded = true;
    if (error is! Error) return;
    _errorReporter?.call(error, stackTrace, site: site);
  }

  /// Extracts the addressable ID from a repost event's 'a' tag.
  ///
  /// According to NIP-18, generic reposts use the 'a' tag to reference
  /// the addressable event being reposted.
  String? _extractAddressableId(Event event) {
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'a' && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }

  /// Extracts the original author pubkey from a repost event's 'p' tag.
  String? _extractOriginalAuthorPubkey(Event event) {
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }
}
