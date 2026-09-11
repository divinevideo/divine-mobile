import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:crypto/crypto.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:meta/meta.dart';
import 'package:nostr_client/src/models/models.dart';
import 'package:nostr_client/src/nip89_client_tag.dart';
import 'package:nostr_client/src/publish_result.dart';
import 'package:nostr_client/src/relay_diagnostics_adapter.dart';
import 'package:nostr_client/src/relay_manager.dart';
import 'package:nostr_client/src/relay_rejection_classifier.dart';
import 'package:nostr_client/src/social_publish_result.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/utils/hash_util.dart';
import 'package:pool/pool.dart';

/// The relay ended a live subscription before the client unsubscribed.
class RelaySubscriptionRefusedException implements Exception {
  /// Creates an exception preserving the relay-provided [reason].
  const RelaySubscriptionRefusedException(this.reason);

  /// The reason supplied by the relay's `CLOSED` frame.
  final String reason;

  @override
  String toString() => 'RelaySubscriptionRefusedException: $reason';
}

/// Observer for NostrClient activity statistics.
///
/// Implement this interface and set it via [NostrClient.statisticsObserver]
/// to receive callbacks for subscription and event activity.
abstract class NostrClientStatisticsObserver {
  /// Called when a new subscription is created
  void onSubscriptionStarted(String subscriptionId);

  /// Called when a subscription is closed
  void onSubscriptionClosed(String subscriptionId);

  /// Called when an event is received from a relay
  void onEventReceived();

  /// Called when an event is sent to relays
  void onEventSent();
}

/// A blocking stage within [NostrClient.initialize].
///
/// Callers can record these transitions so a startup timeout identifies the
/// operation that was still pending instead of reporting one opaque failure.
enum NostrClientInitializationStage {
  /// Refreshing the cached public key from the active signer.
  refreshingPublicKey,

  /// Loading persisted, previously verified event identifiers.
  loadingVerifiedEvents,

  /// Starting the background signature-verification worker.
  startingVerificationWorker,

  /// Loading relay configuration and establishing relay connections.
  connectingRelays,
}

/// Receives initialization stage transitions before their asynchronous work
/// begins. Implementations are diagnostic only; exceptions are logged and do
/// not fail client initialization.
typedef NostrClientInitializationObserver =
    void Function(NostrClientInitializationStage stage);

/// {@template nostr_client}
/// Abstraction layer for Nostr communication
///
/// This client wraps nostr_sdk and provides:
/// - Subscription lifecycle (relay REQ closed when the last listener cancels)
/// - Local database caching for faster queries
/// - Clean API for repositories to use
/// - Proper resource management
/// - Relay management via RelayManager
/// {@endtemplate}
class NostrClient {
  /// {@macro nostr_client}
  ///
  /// Creates a new NostrClient instance with the given configuration.
  /// The RelayManager is created internally using the Nostr instance's
  /// RelayPool to ensure they share the same connection pool.
  ///
  /// Optional [dbClient] enables local caching of events for faster
  /// queries and auto-caching of subscription events.
  factory NostrClient({
    required NostrClientConfig config,
    required RelayManagerConfig relayManagerConfig,
    AppDbClient? dbClient,
  }) {
    final relayDiagnostics = RelayDiagnosticsAdapter();
    final nostr = _createNostr(config, relayDiagnostics.call);
    final relayManager = RelayManager(
      config: relayManagerConfig,
      relayPool: nostr.relayPool,
      diagnosticsSink: relayDiagnostics.call,
    );
    return NostrClient._internal(
      nostr: nostr,
      relayManager: relayManager,
      dbClient: dbClient,
      eventVerifyWorkerSpawner: config.eventVerifyWorkerSpawner,
    );
  }

  /// Internal constructor used by factory and testing constructors
  NostrClient._internal({
    required Nostr nostr,
    required RelayManager relayManager,
    AppDbClient? dbClient,
    EventVerifyWorkerSpawner? eventVerifyWorkerSpawner,
  }) : _nostr = nostr,
       _relayManager = relayManager,
       _dbClient = dbClient,
       _eventVerifyWorkerSpawner = eventVerifyWorkerSpawner;

  /// Creates a NostrClient with injected dependencies for testing
  @visibleForTesting
  NostrClient.forTesting({
    required Nostr nostr,
    required RelayManager relayManager,
    AppDbClient? dbClient,
    EventVerifyWorkerSpawner? eventVerifyWorkerSpawner,
  }) : _nostr = nostr,
       _relayManager = relayManager,
       _dbClient = dbClient,
       _eventVerifyWorkerSpawner = eventVerifyWorkerSpawner;

  static Nostr _createNostr(
    NostrClientConfig config,
    RelayDiagnosticsSink diagnosticsSink,
  ) {
    RelayBase tempRelayGenerator(String url) => RelayBase(
      url,
      RelayStatus(url),
      channelFactory: config.webSocketChannelFactory,
      diagnosticsSink: diagnosticsSink,
    );
    return Nostr(
      config.signer,
      config.eventFilters,
      tempRelayGenerator,
      onNotice: config.onNotice,
      diagnosticsSink: diagnosticsSink,
      channelFactory: config.webSocketChannelFactory,
      signatureVerificationPolicy: config.signatureVerificationPolicy,
    );
  }

  final Nostr _nostr;
  final RelayManager _relayManager;
  final AppDbClient? _dbClient;

  /// Spawns the off-main event-verify isolate (#5863). Null in tests / on web,
  /// where verify falls back to the main isolate.
  final EventVerifyWorkerSpawner? _eventVerifyWorkerSpawner;

  /// The spawned verify worker, if any. Closed on [dispose].
  EventVerifyWorker? _verifyWorker;

  /// Maximum number of concurrent one-shot relay queries ([queryEvents]).
  ///
  /// Caps the per-item fan-out (like counts, badges, profiles, repost-source
  /// fetches) a high-volume screen triggers, so the app can't trip a relay's
  /// "too many concurrent REQs" limit. Override in tests before the first
  /// query. Backed by a [Pool] from `package:pool`.
  @visibleForTesting
  static int maxConcurrentQueries = 6;

  /// How long [queryEventsDetailed] lets a websocket leg run past the caller's
  /// deadline before abandoning it, and every event it holds.
  ///
  /// The deadline is handed to the SDK, which ends the read there and hands
  /// back what arrived, so this only catches a leg that does not end itself.
  /// It must exceed timer latency, or an honest leg would lose the race —
  /// racing it against the same instant is what made a timed-out read return
  /// an empty list (#6238).
  static const Duration _websocketLegOverrunGrace = Duration(
    milliseconds: 250,
  );

  late final Pool _queryPool = Pool(maxConcurrentQueries);

  /// The signer used by this client for event signing and NIP-44 encryption.
  ///
  /// Exposes the same `NostrSigner` instance that the client was created with.
  /// Other components that need NIP-44 operations (e.g. DM decryption) should
  /// reuse this signer rather than creating their own, to ensure consistent
  /// key material.
  NostrSigner get signer => _nostr.nostrSigner;

  /// Policy for expensive inbound relay EVENT signature verification.
  SignatureVerificationPolicy get signatureVerificationPolicy =>
      _nostr.relayPool.signatureVerificationPolicy;

  set signatureVerificationPolicy(SignatureVerificationPolicy policy) {
    _nostr.relayPool.signatureVerificationPolicy = policy;
  }

  /// Convenience getter for the NostrEventsDao
  NostrEventsDao? get _nostrEventsDao => _dbClient?.database.nostrEventsDao;

  /// Upper bound on remembered NIP-09 tombstones, per set.
  static const int _maxTrackedTombstones = 2000;

  /// `pubkey:event-id` pairs removed by an observed or published Kind 5.
  ///
  /// Keyed by the *deletion author* so a forged `e` tag cannot suppress
  /// another author's event: NIP-09 requires a client to check that the
  /// referenced event's pubkey matches the deletion request's, and the
  /// referenced event is often not in the store to check against, so the
  /// pubkey is carried in the key and compared when the event arrives.
  final Set<String> _tombstonedEventKeys = <String>{};

  /// `kind:pubkey:d-tag` coordinate to the `created_at` of the deletion that
  /// removed it. NIP-09 scopes an `a` deletion to versions up to that
  /// timestamp, so a coordinate republished afterwards must cache again.
  ///
  /// Insertion-ordered (`LinkedHashMap`) so eviction drops the oldest.
  final Map<String, int> _tombstonedCoordinates = <String, int>{};

  /// `"id:sig"` keys of events already persisted — and therefore already
  /// signature-verified — in a previous session. Seeded once at
  /// [initialize] so the relay pool can skip re-verifying events that relays
  /// re-send on cold start. The signature is part of the key because a Nostr
  /// event id does not commit to `sig`; trusting an id alone would let a
  /// replayed id carrying a forged signature bypass verification.
  final Set<String> _knownVerifiedEventKeys = <String>{};

  /// Loads recently-persisted `(id, sig)` pairs into
  /// [_knownVerifiedEventKeys] and wires the relay pool to consult it. No-op
  /// when there is no local store.
  ///
  /// Called before relays connect so the lookup is in place before the
  /// cold-start event flood arrives.
  Future<void> _seedVerifiedEventIds() async {
    final dao = _nostrEventsDao;
    if (dao == null) return;
    try {
      final pairs = await dao.getRecentEventIdSigs();
      _knownVerifiedEventKeys
        ..clear()
        ..addAll(pairs.map((pair) => '${pair.id}:${pair.sig}'));
      _nostr.relayPool.isKnownVerifiedEvent = (id, sig) =>
          _knownVerifiedEventKeys.contains('$id:$sig');
      log(
        '🔏 Seeded ${_knownVerifiedEventKeys.length} known-verified events',
        name: 'NostrClient',
      );
    } on Object catch (e, st) {
      // Non-fatal: without the seed the pool simply verifies every event.
      log(
        'Failed to seed known-verified event ids',
        name: 'NostrClient',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Spawns the off-main relay-event verify isolate (if a spawner was
  /// configured) and wires it into the relay pool. A spawn failure is
  /// non-fatal: the relay pool falls back to inline main-isolate verification.
  Future<void> _maybeStartEventVerifyWorker() async {
    final spawner = _eventVerifyWorkerSpawner;
    if (spawner == null || _verifyWorker != null) return;
    try {
      final worker = await spawner();
      _verifyWorker = worker;
      _nostr.relayPool.eventVerifyWorker = worker;
    } on Object catch (_) {
      // Non-fatal: without a worker the relay pool verifies inline as before.
    }
  }

  /// Helper to cache an event with default expiry.
  ///
  /// Fire-and-forget pattern - errors are silently ignored since caching
  /// failures should not affect the send operation's success.
  void _cacheEvent(Event event) {
    try {
      unawaited(_nostrEventsDao?.upsertEvent(event));
    } on Object {
      // Ignore cache errors
    }
  }

  /// Checks if an event kind supports safe optimistic caching.
  ///
  /// Returns `false` for:
  /// - Deletion events (Kind 5): They remove data, not add
  /// - Replaceable events (Kind 0, 3, 10000-19999): Upsert deletes old event
  /// - Parameterized replaceable (Kind 30000-39999): Same issue
  ///
  /// For these kinds, caching on success is safer to avoid data loss on
  /// rollback.
  bool _canOptimisticallyCache(int kind) {
    if (kind == EventKind.eventDeletion) return false;
    if (EventKind.isReplaceable(kind)) return false;
    if (EventKind.isParameterizedReplaceable(kind)) return false;
    return true;
  }

  /// Removes an optimistically cached event on send failure.
  ///
  /// Fire-and-forget pattern - errors are silently ignored since rollback
  /// failures should not affect the operation's result.
  void _rollbackCachedEvent(String eventId) {
    try {
      unawaited(_nostrEventsDao?.deleteEventsByIds([eventId]));
    } on Object {
      // Ignore rollback errors
    }
  }

  /// Handles a NIP-09 deletion event (Kind 5) by removing target events
  /// from the local database.
  ///
  /// Extracts event IDs from `e` tags and addressable coordinates from `a`
  /// tags, then deletes matching cached events.
  ///
  Future<void> _handleDeletionEvent(Event deletionEvent) async {
    if (deletionEvent.kind != EventKind.eventDeletion) return;

    final targetEventIds = <String>[];
    final targetAddressableIds = <AId>[];
    for (final dynamic tag in deletionEvent.tags) {
      if (tag is List && tag.length > 1) {
        final tagName = tag[0];
        final tagValue = tag[1];
        if (tagName == 'e' && tagValue is String) {
          targetEventIds.add(tagValue);
        } else if (tagName == 'a' && tagValue is String) {
          final addressableId = AId.fromString(tagValue);
          if (addressableId != null) {
            targetAddressableIds.add(addressableId);
          }
        }
      }
    }

    if (targetEventIds.isEmpty && targetAddressableIds.isEmpty) return;

    _rememberTombstones(
      eventIds: targetEventIds,
      addressableIds: targetAddressableIds,
      deletionPubkey: deletionEvent.pubkey,
      deletionCreatedAt: deletionEvent.createdAt,
    );

    await _deleteCachedEventsForDeletion(
      eventIds: targetEventIds,
      addressableIds: targetAddressableIds,
      deletionPubkey: deletionEvent.pubkey,
      deletionCreatedAt: deletionEvent.createdAt,
    );
  }

  /// Records what a Kind 5 tombstoned so [_shouldSkipAutoCache] can keep the
  /// auto-cache from writing the row back when a relay redelivers it.
  ///
  /// Bounded: the oldest entries are evicted past [_maxTrackedTombstones], so
  /// a long session cannot grow these sets without limit. Losing an old entry
  /// only costs a redundant row that the next deletion purges again.
  void _rememberTombstones({
    required List<String> eventIds,
    required List<AId> addressableIds,
    required String deletionPubkey,
    required int deletionCreatedAt,
  }) {
    for (final eventId in eventIds) {
      final key = _tombstoneEventKey(pubkey: deletionPubkey, eventId: eventId);
      _tombstonedEventKeys
        ..remove(key)
        ..add(key);
    }
    for (final addressableId in addressableIds) {
      if (addressableId.pubkey != deletionPubkey) continue;
      final key = _tombstoneCoordinateKey(
        kind: addressableId.kind,
        pubkey: addressableId.pubkey,
        dTag: addressableId.dTag,
      );
      // Keep the newest deletion for a coordinate, and re-insert so eviction
      // still drops the least recently tombstoned.
      final known = _tombstonedCoordinates.remove(key);
      _tombstonedCoordinates[key] = known == null
          ? deletionCreatedAt
          : (known > deletionCreatedAt ? known : deletionCreatedAt);
    }
    while (_tombstonedEventKeys.length > _maxTrackedTombstones) {
      _tombstonedEventKeys.remove(_tombstonedEventKeys.first);
    }
    while (_tombstonedCoordinates.length > _maxTrackedTombstones) {
      _tombstonedCoordinates.remove(_tombstonedCoordinates.keys.first);
    }
  }

  static String _tombstoneEventKey({
    required String pubkey,
    required String eventId,
  }) => '${pubkey.toLowerCase()}:${eventId.toLowerCase()}';

  static String _tombstoneCoordinateKey({
    required int kind,
    required String pubkey,
    required String dTag,
  }) => '$kind:${pubkey.toLowerCase()}:$dTag';

  /// Whether the auto-cache must skip [event] because a Kind 5 already
  /// removed it.
  ///
  /// Without this the subscription callback re-inserts a deleted event the
  /// moment any relay redelivers it, undoing the purge and re-serving the
  /// clip from the local store on the next launch.
  bool _shouldSkipAutoCache(Event event) {
    // The key carries the deletion author, so this only matches when the
    // event's own pubkey signed the deletion that named it.
    if (_tombstonedEventKeys.contains(
      _tombstoneEventKey(pubkey: event.pubkey, eventId: event.id),
    )) {
      return true;
    }
    if (!EventKind.isParameterizedReplaceable(event.kind)) return false;

    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'd' || tag[1].isEmpty) continue;
      final deletedUpTo =
          _tombstonedCoordinates[_tombstoneCoordinateKey(
            kind: event.kind,
            pubkey: event.pubkey,
            dTag: tag[1],
          )];
      // A version published after the deletion request is not covered by it.
      return deletedUpTo != null && event.createdAt <= deletedUpTo;
    }
    return false;
  }

  Future<void> _deleteCachedEventsForDeletion({
    required List<String> eventIds,
    required List<AId> addressableIds,
    required String deletionPubkey,
    required int deletionCreatedAt,
  }) async {
    final dao = _nostrEventsDao;
    if (dao == null) return;

    final idsToDelete = eventIds.toSet();
    for (final addressableId in addressableIds) {
      if (addressableId.pubkey != deletionPubkey) continue;

      final matches = await dao.getEventsByFilter(
        Filter(
          kinds: [addressableId.kind],
          authors: [addressableId.pubkey],
          d: [addressableId.dTag],
          until: deletionCreatedAt,
        ),
      );
      idsToDelete.addAll(matches.map((event) => event.id));
    }

    if (idsToDelete.isEmpty) return;
    await dao.deleteEventsByIds(idsToDelete.toList());
  }

  Future<void> _handleDeletionEventAfterPublish(Event deletionEvent) async {
    try {
      await _handleDeletionEvent(deletionEvent);
    } on Object {
      // Cache cleanup is best effort after a relay accepted the deletion.
      // Local DAO failures must not change the publish outcome.
    }
  }

  /// Tracks whether dispose() has been called
  bool _isDisposed = false;

  /// Adds Divine's NIP-89 `client` tag before publishing, unless [event]
  /// already carries a signature.
  ///
  /// Appending the tag rebuilds the event, which changes its id and so
  /// invalidates any signature already on it. `nostr_sdk` signs whenever `sig`
  /// is blank, so clobbering it here silently buys a second signature — with a
  /// remote signer, a whole extra network round trip per publish (#8166).
  ///
  /// Events signed through `SignerFactory.createAndSignEvent` already carry the
  /// tag, so the only events skipped here are the ones a call site signed
  /// itself with a raw signer. Those forfeit attribution rather than a round
  /// trip; NIP-89 makes the tag optional.
  Future<void> _prepareEventForPublish(Event event) async {
    if (event.sig.isNotEmpty) {
      return;
    }

    await Nip89ClientTag.applyToEvent(event);
  }

  /// Completes the first time [initialize] finishes, so consumers can await
  /// readiness without polling `hasKeys`. `NostrClient` is one-shot — after
  /// `dispose()` a fresh instance is constructed for the next session, so
  /// this completer is final.
  final Completer<void> _readyCompleter = Completer<void>();

  /// Resolves the first time [initialize] completes. Returns the same
  /// resolved future on subsequent reads.
  ///
  /// Use this from Riverpod providers or services that need to react to
  /// "signer is ready" without busy-polling `hasKeys` — see #3352.
  Future<void> get ready => _readyCompleter.future;

  /// Synchronous companion to [ready]: whether [initialize] has settled
  /// (successfully or with an error).
  ///
  /// Consumers that attach `.then(...)` to [ready] on every rebuild must
  /// check this first — once the completer is settled, every fresh
  /// `.then(...)` fires on the next microtask, so re-arming without a
  /// gate produces a tight invalidate loop on the "ready resolved but
  /// `hasKeys` still false" path (signer started empty during cold
  /// boot, then `refreshPublicKey()` returned `''`).
  bool get isReadyResolved => _readyCompleter.isCompleted;

  /// Public key of the client
  String get publicKey => _nostr.publicKey;

  /// The signed-in user's public key, or `null` when the signer has none.
  ///
  /// [publicKey] is a plain cache read, and the cache stays empty when the
  /// signer had no key at [initialize] time but acquired one afterwards —
  /// nothing re-runs the refresh on its own. Resolving through here retries
  /// the signer on a cache miss, so a late signer is picked up on the next
  /// call instead of leaving author-scoped queries filtering on an empty
  /// author for the rest of the session (#6813).
  ///
  /// Returns `null` rather than throwing, for callers that should skip their
  /// query when signed out. Use [Nostr.ensurePublicKey] when the absence of a
  /// key is a programming error instead.
  ///
  /// Concurrent callers share one refresh. A cache miss reaches the signer,
  /// and for NIP-55 that is an Amber intent — a user-visible prompt — so the
  /// several repositories that resolve the key at startup must not each raise
  /// their own.
  Future<String?> resolvePublicKey() async {
    final cached = _nostr.publicKey;
    if (cached.isNotEmpty) return cached;

    try {
      await _refreshPublicKeyFromSigner();
    } on Object catch (e, st) {
      // Non-fatal: the caller skips its author-scoped query. Logged so a
      // failed signer stays distinguishable from a signed-out session —
      // callers report both as "no public key".
      log(
        'Signer refresh failed while resolving the public key',
        name: 'NostrClient',
        error: e,
        stackTrace: st,
      );
      return null;
    }

    final key = _nostr.publicKey;
    return key.isEmpty ? null : key;
  }

  /// In-flight signer refresh, shared by initialize and resolving callers.
  Future<void>? _pendingPublicKeyRefresh;

  Future<void> _refreshPublicKeyFromSigner() {
    return _pendingPublicKeyRefresh ??= _nostr.refreshPublicKey().whenComplete(
      () => _pendingPublicKeyRefresh = null,
    );
  }

  /// Whether the client has been initialized
  ///
  /// Returns true if the relay manager is initialized
  bool get isInitialized => _relayManager.isInitialized;

  /// Ensure the user-removal intent ledger has been loaded from storage.
  ///
  /// Delegates to [RelayManager.ensureUserRemovedRelaysLoaded]. See that
  /// method for when a caller needs this: [addRelay], [addRelays] and
  /// [initialize] already load the ledger themselves.
  Future<void> ensureUserRemovedRelaysLoaded() =>
      _relayManager.ensureUserRemovedRelaysLoaded();

  /// Whether the client has been disposed
  ///
  /// After disposal, the client should not be used
  bool get isDisposed => _isDisposed;

  /// Whether the client has keys configured
  ///
  /// Returns true if the public key is not empty
  bool get hasKeys => publicKey.isNotEmpty;

  /// Initializes the client by connecting to configured relays
  ///
  /// This must be called before using the client to ensure relay connections
  /// are established. Also refreshes the public key from the signer to ensure
  /// the client has the correct key. Can be called multiple times safely.
  ///
  /// On failure, [ready] resolves with the same error so consumers awaiting
  /// readiness fail fast instead of hanging until a wall-clock timeout.
  Future<void> initialize() async {
    try {
      // Signer is the single source of truth for the public key.
      _reportInitializationStage(
        NostrClientInitializationStage.refreshingPublicKey,
      );
      await _refreshPublicKeyFromSigner();
      // Seed the already-verified set before relays connect, so re-sent
      // events skip re-verification during the cold-start flood.
      _reportInitializationStage(
        NostrClientInitializationStage.loadingVerifiedEvents,
      );
      await _seedVerifiedEventIds();
      // Wire the off-main verify isolate before relays connect, so the fresh
      // verifies during the cold-start flood run off the main isolate (#5863).
      _reportInitializationStage(
        NostrClientInitializationStage.startingVerificationWorker,
      );
      await _maybeStartEventVerifyWorker();
      _reportInitializationStage(
        NostrClientInitializationStage.connectingRelays,
      );
      await _relayManager.initialize();
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    } catch (e, st) {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(e, st);
      }
      rethrow;
    }
  }

  /// Optional diagnostic observer for blocking initialization stages.
  ///
  /// The owner may clear this while initialization is still pending (for
  /// example, after applying its own timeout), so asynchronous work does not
  /// retain a per-attempt callback for the lifetime of the client.
  NostrClientInitializationObserver? initializationObserver;

  void _reportInitializationStage(NostrClientInitializationStage stage) {
    try {
      initializationObserver?.call(stage);
    } on Object catch (e, st) {
      log(
        'Initialization stage observer failed',
        name: 'NostrClient',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Optional observer for tracking statistics (subscriptions, events)
  NostrClientStatisticsObserver? statisticsObserver;

  /// Number of active subscriptions
  int get activeSubscriptionCount => _subscriptionStreams.length;

  /// Map of active subscriptions
  final Map<String, StreamController<Event>> _subscriptionStreams = {};

  int _anonymousSubscriptionCounter = 0;

  /// Publishes an event to relays
  ///
  /// Delegates to nostr_sdk for relay management and broadcasting.
  ///
  /// **Caching strategy:**
  /// - Regular events: Optimistic cache before send, rollback on failure
  /// - Replaceable events (0, 3, 10000-39999): Cache on success only
  ///   (upsert deletes old record, so rollback would lose data)
  /// - Deletion events (Kind 5): Removes target events from cache on success
  ///
  /// Returns a [PublishResult] describing the outcome:
  /// - [PublishSuccess] — the event was broadcast to at least one relay.
  /// - [PublishNoRelays] — no relays were connected even after retry.
  /// - [PublishFailed] — the relay pool was reachable but the SDK send
  ///   returned null (e.g. a serialisation error).
  Future<PublishResult> publishEvent(
    Event event, {
    List<String>? targetRelays,
  }) async {
    final effectiveTargets = _allowedRelays(targetRelays);
    await _prepareEventForPublish(event);
    final useOptimisticCache = _canOptimisticallyCache(event.kind);

    // Optimistic cache for regular events only
    if (useOptimisticCache) {
      _cacheEvent(event);
    }

    final hasExplicitTargets =
        effectiveTargets != null && effectiveTargets.isNotEmpty;

    // Checks health of relays, attempts reconnection if none connected,
    // and exits if reconnect is unsuccessful. Explicit target relays use
    // temporary SDK connections, so they do not require the configured pool
    // to already have a connected relay.
    if (_relayManager.connectedRelays.isEmpty && !hasExplicitTargets) {
      await retryDisconnectedRelays();
      if (_relayManager.connectedRelays.isEmpty) {
        // Rollback optimistic cache on failure
        if (useOptimisticCache) {
          _rollbackCachedEvent(event.id);
        }
        return const PublishNoRelays();
      }
    }

    final sentEvent = await _nostr.sendEvent(
      event,
      targetRelays: effectiveTargets,
      // Also pass as tempRelays so the SDK creates temporary connections
      // to target relays not already in the connected pool. Without this,
      // targetRelays only filters the existing pool and the event could
      // be sent to zero relays.
      tempRelays: effectiveTargets,
    );

    if (sentEvent == null) {
      // Rollback optimistic cache on failure
      if (useOptimisticCache) {
        _rollbackCachedEvent(event.id);
      }
      return const PublishFailed();
    }

    // Handle successful send
    if (sentEvent.kind == EventKind.eventDeletion) {
      // NIP-09: Remove target events from cache
      await _handleDeletionEventAfterPublish(sentEvent);
    } else if (!useOptimisticCache) {
      // Cache replaceable events on success (not optimistically)
      _cacheEvent(sentEvent);
    }

    statisticsObserver?.onEventSent();

    return PublishSuccess(event: sentEvent);
  }

  /// Publishes an event and waits for the targeted relays to answer with
  /// NIP-01 `OK` frames.
  ///
  /// Unlike [publishEvent], this does NOT treat the publish as successful
  /// just because the WebSocket accepted the frame.
  ///
  /// ## When the future completes
  ///
  /// Whichever of these happens first:
  ///  * every relay the fan-out reached has answered, or
  ///  * a short settle window elapses after the first answer, or
  ///  * [timeout] elapses.
  ///
  /// It does **not** complete on the first acceptance. A publish that one
  /// relay accepts and another rejects reports both, and relays that were
  /// targeted but never reached are reported in
  /// [PublishOutcome.unreachableTargets].
  ///
  /// ## What acceptance means
  ///
  /// `OK true` means a relay accepted the event for writing — NIP-01 defines
  /// the flag as "accepted by the relay", and Divine's relay acknowledges
  /// from an in-memory queue and commits to storage afterwards. Even
  /// [PublishOutcome.acceptedByAll] is therefore a statement about breadth of
  /// acceptance, never a durability guarantee. Do not surface it to a user as
  /// "saved".
  ///
  /// Nothing in this client republishes to relays that did not accept, so a
  /// partial publish stays partial. That makes
  /// [PublishOutcome.acceptedByAll] a poor gate for anything the user is
  /// waiting on: one pool member that is down, wedged, or refusing blocks it
  /// on every attempt, and the pool keeps relays it never managed to connect
  /// to. Gate progress on [PublishOutcome.acceptedByAny] and report
  /// [PublishOutcome.acceptedByAll] as breadth — which is what it measures.
  ///
  /// Cache writes follow the same rules as [publishEvent], except that the
  /// optimistic cache is rolled back when no relay accepted, and
  /// deletion-event cache cleanup only runs once something accepted.
  ///
  /// Ephemeral events (20000–29999) should use [publishEvent] because relays
  /// are not required to answer them with `OK`.
  Future<PublishOutcome> publishEventAwaitOk(
    Event event, {
    List<String>? targetRelays,
    Duration timeout = const Duration(seconds: 15),
    String? diagnosticTag,
  }) async {
    final effectiveTargets = _allowedRelays(targetRelays);
    await _prepareEventForPublish(event);
    final useOptimisticCache = _canOptimisticallyCache(event.kind);

    if (useOptimisticCache) {
      _cacheEvent(event);
    }

    PublishOutcome rollbackOnFailure(PublishOutcome outcome) {
      if (outcome.failed && useOptimisticCache) {
        _rollbackCachedEvent(event.id);
      }
      return outcome;
    }

    final hasExplicitTargets =
        effectiveTargets != null && effectiveTargets.isNotEmpty;

    if (_relayManager.connectedRelays.isEmpty && !hasExplicitTargets) {
      await retryDisconnectedRelays();
      if (_relayManager.connectedRelays.isEmpty) {
        return rollbackOnFailure(
          PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
      }
    }

    PublishOutcome outcome;
    try {
      outcome =
          await _nostr.sendEventAwaitOk(
            event,
            targetRelays: effectiveTargets,
            tempRelays: effectiveTargets,
            timeout: timeout,
          ) ??
          PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
    } on Object {
      if (useOptimisticCache) {
        _rollbackCachedEvent(event.id);
      }
      rethrow;
    }

    if (outcome.failed) {
      return rollbackOnFailure(outcome);
    }

    // Relay confirmed acceptance — apply post-publish cache effects.
    if (event.kind == EventKind.eventDeletion) {
      await _handleDeletionEventAfterPublish(event);
    } else if (!useOptimisticCache) {
      _cacheEvent(event);
    }

    statisticsObserver?.onEventSent();

    return outcome;
  }

  /// Queries events with health details for callers that must distinguish an
  /// empty result from an unreachable relay query.
  ///
  /// Query flow: **Cache + WebSocket**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// Then queries via WebSocket and merges results.
  ///
  /// Results from websocket are cached for future queries.
  ///
  /// Calling this on a disposed client is a no-op that returns an empty
  /// list. If the client is disposed while a call is in flight, the
  /// network query is skipped and only cached results are returned.
  ///
  /// [timeout] is an end-to-end deadline for the cache read, reconnect sweep,
  /// query-pool acquisition, and WebSocket query together. Exhausting it
  /// returns `timedOut: true` alongside whatever the relays that did answer
  /// had delivered by then. A WebSocket query that does not honor its own
  /// budget may run for up to 250 ms beyond that deadline before its partial
  /// events are abandoned. A pool waiter that expires remains in the package's
  /// FIFO only until a resource reaches it; it releases that resource without
  /// dispatching network work.
  ///
  /// `timedOut: false` with an empty `events` normally means "the relays
  /// answered and there is nothing", but only for a caller that is content to
  /// be told about the relays that answered *first*: a relay that stays
  /// connected and never sends a terminal frame is skipped past after
  /// `RelayPool.querySettleWindow` and the result still reports
  /// `timedOut: false`. Set [requireAllRelaysSettled] when that distinction
  /// is load-bearing — a caller about to replace what it read cannot act on a
  /// partial answer — and an incomplete answer arrives as `timedOut: true`
  /// instead. That covers the answers nobody gave as well as the partial ones:
  /// a fan-out no relay accepted, and a query skipped because the client is
  /// being disposed, both report `timedOut: true` rather than an empty answer.
  /// Note this only bounds the WebSocket leg; cached rows are merged in either
  /// way.
  ///
  /// `noRelays` says nothing was asked, whatever the flag. It covers a client
  /// with no connected relay and no temp relay, a client already disposed when
  /// the call arrived, and a fan-out no relay took — the last of which a
  /// connected-relay snapshot cannot see, since a write-only relay and one
  /// whose socket died since its last status update both still count as
  /// connected. A relay that answers only out of the local event cache counts
  /// as participation, so this is "nothing took the REQ", not "no network
  /// relay took it".
  ///
  /// A client disposed *mid-call* is deliberately not in that list: the relays
  /// were reachable and only this one query was dropped, so it arrives as
  /// `timedOut` for a full-settlement caller instead.
  ///
  /// `timedOut: true` is never an empty answer by itself: a read that spends
  /// its whole budget still returns the events that arrived before it ran
  /// out, merged with the cached rows. Use [readEvents] to see *how* the read
  /// ended rather than only whether it ran out of time.
  Future<({List<Event> events, bool timedOut, bool noRelays})>
  queryEventsDetailed(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useCache = true,
    bool useQueryPool = true,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
  }) async {
    final read = await _read(
      filters,
      subscriptionId: subscriptionId,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      useCache: useCache,
      useQueryPool: useQueryPool,
      timeout: timeout,
      requireAllRelaysSettled: requireAllRelaysSettled,
    );
    return (
      events: read.result.events,
      timedOut: read.timedOut,
      noRelays: read.result.endedBy == QueryEnd.noRelay,
    );
  }

  /// Reads the events [filters] match and reports how the read ended.
  ///
  /// Runs the same read as [queryEventsDetailed] and [queryEvents] — cache
  /// and WebSocket, merged — but keeps the outcome instead of reducing it to
  /// two flags. [QueryResult.endedBy] says how the read ended, and
  /// [QueryResult.possiblyCapped] / [QueryResult.confirmedExhaustive] how
  /// complete the relays' answer was.
  ///
  /// All three describe the **network leg only**. A cached row merged into
  /// [QueryResult.events] can never make a read the relays did not finish
  /// look finished.
  ///
  /// Ends the relays were never asked about are reported as the nearest thing
  /// they could have said: a disposed client, and a call with no connected
  /// relay, as [QueryEnd.noRelay]; a query pool that closed mid-call, or a
  /// pool slot that never arrived, as [QueryEnd.deadline].
  Future<QueryResult> readEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useCache = true,
    bool useQueryPool = true,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
  }) async {
    final read = await _read(
      filters,
      subscriptionId: subscriptionId,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      useCache: useCache,
      useQueryPool: useQueryPool,
      timeout: timeout,
      requireAllRelaysSettled: requireAllRelaysSettled,
    );
    return read.result;
  }

  /// Runs the one read behind [readEvents], [queryEventsDetailed] and
  /// [queryEvents].
  ///
  /// `timedOut` is [QueryResult.endedBy] plus the one case it cannot express:
  /// a read that ends [QueryEnd.noRelay] at or after the deadline had a relay
  /// still holding the REQ when the deadline fired, so it timed out too. A
  /// read skipped because the query pool closed keeps the flag it has always
  /// reported instead — see that branch.
  Future<({QueryResult result, bool timedOut})> _read(
    List<Filter> filters, {
    required String? subscriptionId,
    required List<String>? tempRelays,
    required List<int> relayTypes,
    required bool sendAfterAuth,
    required bool useCache,
    required bool useQueryPool,
    required Duration timeout,
    required bool requireAllRelaysSettled,
  }) async {
    final startedAt = DateTime.now();
    // A disposed client's query pool is closed; querying it is a no-op
    // rather than an error. This is the common case (checked upfront to
    // skip pointless cache/reconnect work below) — the narrower re-check
    // right before `withResource` (see below) closes the residual race
    // where dispose() runs during the awaits in between. See #5952.
    if (_isDisposed) {
      const skipped = QueryResult(events: [], endedBy: QueryEnd.noRelay);
      _reportQueryCompletion(
        filters: filters,
        endedBy: skipped.endedBy,
        reason: 'the client was disposed before the read started',
        events: 0,
        startedAt: startedAt,
      );
      return (result: skipped, timedOut: false);
    }

    // One deadline for the whole call, spent by every awaited step below.
    // Without it `timeout` bounds only the websocket leg while the cache read,
    // the reconnect and the pool wait run unbounded beside it — so a caller
    // that asked for 5s could wait 48s (#7091). This mirrors the same
    // discipline `Nostr.queryEventsDetailed` already applies one layer down.
    final deadline = startedAt.add(timeout);
    Duration remainingTimeout() {
      final remaining = deadline.difference(DateTime.now());
      return remaining.isNegative ? Duration.zero : remaining;
    }

    final effectiveTempRelays = _allowedRelays(tempRelays);
    final cacheResults = <Event>[];

    // 1. Get cache results (don't return early - we'll merge with network)
    //
    // Held to the same filter as the network leg. The local store is not an
    // admission oracle: its rows are remote-sourced, several writers put them
    // there without ever seeing this filter, and rows written by a build that
    // predates the gate are still inside the cache TTL. The DAO's SQL narrows
    // on most dimensions but not all — an empty-but-non-null list emits no
    // condition at all, where `checkEvent` matches nothing — so relying on
    // SQL/`checkEvent` parity would rest a boundary on a cross-package
    // coincidence neither side declares.
    final dao = _nostrEventsDao;
    if (useCache && dao != null && filters.length == 1) {
      try {
        cacheResults.addAll(
          _eventsMatchingAnyFilter(
            await dao
                .getEventsByFilter(filters.first)
                .timeout(
                  remainingTimeout(),
                ),
            filters,
          ),
        );
      } on TimeoutException {
        // The local read outlived the caller's budget. Cache is an
        // accelerator, never the answer, so proceed without it.
      }
    }

    // 2. Query via WebSocket.
    // A cold query — e.g. the DM history drain firing before the relay
    // pool has finished connecting — would otherwise short-circuit to an
    // empty result (RelayPool completes immediately when no relay accepts
    // the REQ). Reconnect first, mirroring publish()/subscribe(). See #5202.
    //
    // A temp relay outside the pool answers on its own socket, so a lookup
    // that names one keeps its no-wait path. A temp relay that IS a pool
    // member does not: RelayPool resolves it to the pooled relay object, and
    // with the pool idled out (the SDK drops every socket after 90s of
    // silence and nothing reconnects it unasked) nobody takes the REQ. The DM
    // history drain dials the account's own kind-10050 inbox this way, and
    // for a divine account that list is the pool itself — so every page it
    // issued into an idle pool failed within milliseconds as "no relay
    // answered", and the Retry that re-issued the same page could never
    // recover. See #8550.
    final canAnswerWithoutPool =
        _relayManager.connectedRelays.isEmpty &&
        _hasRelayOutsidePool(effectiveTempRelays);
    if (_relayManager.connectedRelays.isEmpty && !canAnswerWithoutPool) {
      try {
        await retryDisconnectedRelays().timeout(remainingTimeout());
      } on TimeoutException {
        // Reconnecting is best-effort: query whatever came up in the budget
        // rather than spending the caller's whole timeout dialling hosts that
        // are not answering.
      }
    }
    // A pre-flight snapshot, so it can only catch the relayless case it can
    // see from here; the fan-out's own account of who took the REQ is folded
    // in below.
    final noConnectedRelays =
        _relayManager.connectedRelays.isEmpty && !canAnswerWithoutPool;
    final filtersJson = filters.map((f) => f.toJson()).toList();
    // The caller's own deadline, not a second budget beside it. Handing the
    // SDK the full `timeout` again let the outer one always win, and its
    // catch replaced a read that had already received hundreds of events with
    // an empty list — 594 delivered, 0 returned, on device (#6238). An
    // absolute deadline subsumes #9030's spend-what-is-left fix: it cannot
    // drift between being computed and being spent.
    Future<QueryResult> runWebSocketQuery() => _nostr.readEvents(
      filtersJson,
      id: subscriptionId,
      tempRelays: effectiveTempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      deadline: deadline,
      requireAllRelaysSettled: requireAllRelaysSettled,
    );

    // Always at least the grace from now: a read whose budget is already
    // spent still needs a moment to hand back what it holds.
    Duration overrunBackstop() =>
        remainingTimeout() + _websocketLegOverrunGrace;

    Future<QueryResult> runPooledWebSocketQuery() async {
      final acquisition = _queryPool.request();
      PoolResource resource;
      try {
        resource = await acquisition.timeout(remainingTimeout());
      } on TimeoutException {
        // package:pool cannot remove a waiter from its FIFO. Drain it when a
        // slot eventually reaches it, but never run the abandoned callback.
        unawaited(acquisition.then((resource) => resource.release()));
        throw const _QueryPoolWaitExpired();
      }
      try {
        return await runWebSocketQuery().timeout(overrunBackstop());
      } finally {
        resource.release();
      }
    }

    // Throttle concurrent one-shot REQs so high fan-out (a profile with many
    // videos → per-item like-count/badge/profile/repost fetches) can't trip a
    // relay's "too many concurrent REQs" limit. `withResource` releases the
    // slot when the (time-bounded) query completes, so it can't leak.
    //
    // Re-check the pool's own closed state immediately before the query,
    // independent of `useQueryPool`: dispose() can run during the awaits
    // above, and `_queryPool.close()` flips `isClosed` before `_isDisposed`
    // is set (dispose() closes the pool first), so it's a reliable
    // dispose-in-progress sentinel for both paths. The non-pooled path
    // (`queryUsers`, `useQueryPool: false`) matters here too: a query that
    // fell through after `_nostr.close()` would re-open fresh WebSockets to
    // the NIP-50 search relays and leak temp relays nothing would clean up.
    // This check-then-call has no await before the query, so it closes the
    // race rather than narrowing it. See #5952.
    // What a read the relay pool never finished hands back, overwritten by
    // the pool's own answer whenever there was one.
    var network = const QueryResult(events: [], endedBy: QueryEnd.deadline);
    // Set only while the relay pool never saw this read, which is what
    // decides who owes the read its one `queryCompletion` line.
    String? skippedReason;
    bool? timedOutOverride;
    if (_queryPool.isClosed) {
      // Nothing was asked of the relays here, which is a different thing from
      // their having nothing. A display read is content to fall back on cache;
      // a full-settlement caller is about to replace what it read, so it gets
      // the same inconclusive answer a relay that never settled would give.
      // That split is what `timedOut` has always carried here, and it is the
      // one place it and `endedBy` disagree on purpose: the read itself never
      // ran, whoever was asking.
      skippedReason = 'the query pool closed mid-call';
      timedOutOverride = requireAllRelaysSettled;
    } else {
      try {
        network = useQueryPool
            ? await runPooledWebSocketQuery()
            : await runWebSocketQuery().timeout(overrunBackstop());
      } on _QueryPoolWaitExpired {
        // `Pool`'s own `timeout:` cannot express the acquisition half: it is
        // an inactivity timer reset on every acquire and release, so a busy
        // pool resets it forever while one waiter starves.
        skippedReason = 'the query pool did not hand over a slot in time';
      } on TimeoutException {
        // The read outlived its own deadline by the whole grace period. The
        // relay pool saw it and files its own line when it concludes, so the
        // inconclusive default above is the whole answer here.
      }
    }
    final websocketEvents = _eventsMatchingAnyFilter(network.events, filters);

    // Cache websocket results (fire-and-forget)
    if (websocketEvents.isNotEmpty) {
      try {
        unawaited(_nostrEventsDao?.upsertEventsBatch(websocketEvents));
      } on Object {
        // Ignore cache errors
      }
    }

    // Merge cache + websocket and return (respecting original limit)
    // Only apply limit when using a single filter - with multiple filters,
    // each filter has its own limit and we shouldn't restrict the combined
    // result set (e.g., getVideosByAddressableIds sends N filters with limit=1
    // each, expecting N results total).
    final limit = filters.length == 1 ? filters.first.limit : null;
    final events = _mergeEvents(cacheResults, websocketEvents, limit: limit);

    // A pre-flight snapshot that saw nothing connected proves nothing was
    // asked, which outranks however the read itself ended — the same
    // precedence the relay pool applies to `noRelay`. The completeness flags
    // stay the network leg's own: a cached row is not an answer from a relay.
    final endedBy = noConnectedRelays ? QueryEnd.noRelay : network.endedBy;
    final result = QueryResult(
      events: events,
      endedBy: endedBy,
      possiblyCapped: network.possiblyCapped,
      confirmedExhaustive: network.confirmedExhaustive,
    );

    // The relay pool files a line for every read it saw that ended worth one,
    // so the client owes one only for a read the pool never saw, or one the
    // client's own view of the relays turned into an end worth reporting.
    final filedByPool =
        skippedReason == null && _worthAQueryCompletion(network);
    if (!filedByPool && _worthAQueryCompletion(result)) {
      _reportQueryCompletion(
        filters: filters,
        endedBy: endedBy,
        reason: skippedReason ?? 'no relay was connected',
        events: events.length,
        startedAt: startedAt,
      );
    }

    return (
      result: result,
      timedOut:
          timedOutOverride ??
          (endedBy == QueryEnd.deadline ||
              // A read no relay took, ending at or after the deadline, had a
              // relay still holding the REQ when the deadline fired.
              (endedBy == QueryEnd.noRelay &&
                  (requireAllRelaysSettled ||
                      !DateTime.now().isBefore(deadline)))),
    );
  }

  /// Queries events with given filters
  ///
  /// Query flow: **Cache + WebSocket**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// Then queries via WebSocket and merges results.
  ///
  /// Results from websocket are cached for future queries.
  ///
  /// Calling this on a disposed client is a no-op that returns an empty
  /// list. If the client is disposed while a call is in flight, the
  /// network query is skipped and only cached results are returned.
  Future<List<Event>> queryEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useCache = true,
    bool useQueryPool = true,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await queryEventsDetailed(
      filters,
      subscriptionId: subscriptionId,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      useCache: useCache,
      useQueryPool: useQueryPool,
      timeout: timeout,
    );
    return result.events;
  }

  /// Whether a read that ended this way owes a `queryCompletion` line — the
  /// same rule the relay pool applies to the reads it saw.
  static bool _worthAQueryCompletion(QueryResult result) =>
      !result.isComplete || result.possiblyCapped;

  /// Files the one [RelayDiagnosticSite.queryCompletion] line a read owes when
  /// the relay pool never saw it, or never judged it worth a line of its own.
  ///
  /// Carries the end reason, why the relays were not asked, the event count,
  /// the elapsed time and each filter's kinds and limit — never a pubkey, an
  /// event id, or a filter's `ids`, `authors` or tag values.
  void _reportQueryCompletion({
    required List<Filter> filters,
    required QueryEnd endedBy,
    required String reason,
    required int events,
    required DateTime startedAt,
  }) {
    final sink = _relayManager.diagnosticsSink;
    if (sink == null) return;
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    emitRelayDiagnostic(
      sink,
      RelayDiagnostic(
        site: RelayDiagnosticSite.queryCompletion,
        // Every end the client files for itself is one the relays were never
        // asked about, which is the level the pool gives those too.
        level: RelayDiagnosticLevel.warning,
        relayUrl: 'nostr-client',
        message:
            'Query ended ${endedBy.name} after ${elapsedMs}ms '
            '(events=$events); the relays were not asked: $reason; '
            'filters: ${filters.map(_describeFilter).join(', ')}',
      ),
    );
  }

  static String _describeFilter(Filter filter) {
    final kinds = filter.kinds;
    return '{kinds: ${kinds == null ? 'any' : '[${kinds.join(', ')}]'}, '
        'limit: ${filter.limit ?? 'none'}}';
  }

  /// Counts events matching the given filters using NIP-45 COUNT.
  ///
  /// This is more efficient than [queryEvents] when you only need the count,
  /// not the actual events.
  ///
  /// [timeout] bounds the whole call. When no relay took the COUNT, because
  /// the pool went idle or every relay dropped, the relays are redialled once
  /// and the COUNT is asked again within what is left of it.
  ///
  /// Throws [CountUnavailableException] when no relay answered. The count is
  /// then unknown, and no number is substituted for it.
  ///
  /// Example - Count followers:
  /// ```dart
  /// final result = await client.countEvents([
  ///   Filter(kinds: [3], p: [pubkey]),
  /// ]);
  /// print('Follower count: ${result.count}');
  /// ```
  ///
  /// Example - Count reactions on an event:
  /// ```dart
  /// final result = await client.countEvents([
  ///   Filter(kinds: [7], e: [eventId]),
  /// ]);
  /// print('Reaction count: ${result.count}');
  /// ```
  Future<CountResult> countEvents(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Duration remainingTimeout() {
      final remaining = deadline.difference(DateTime.now());
      return remaining.isNegative ? Duration.zero : remaining;
    }

    final effectiveTempRelays = _allowedRelays(tempRelays);
    final filtersJson = filters.map((f) => f.toJson()).toList();
    Future<CountResponse> askRelays(Duration budget) => _nostr.countEvents(
      filtersJson,
      id: subscriptionId,
      tempRelays: effectiveTempRelays,
      relayTypes: relayTypes,
      timeout: budget,
    );

    try {
      CountResponse response;
      try {
        response = await askRelays(timeout);
      } on CountNotSentException catch (e) {
        // No relay took the COUNT, so the pool is idle or down. Redial once,
        // as queries do, and ask again within what is left of the budget.
        try {
          await retryDisconnectedRelays().timeout(remainingTimeout());
        } on TimeoutException {
          // The redial outlived the budget; nothing is left to ask with.
        }
        if (remainingTimeout() == Duration.zero) {
          throw CountUnavailableException(e.reason);
        }
        response = await askRelays(remainingTimeout());
      }

      return CountResult(
        count: _normalizeRelayCount(response.count),
        approximate: response.approximate,
      );
    } on CountNotSupportedException catch (e) {
      throw CountUnavailableException(e.reason);
    }
  }

  /// Fetches a single event by ID
  ///
  /// Query flow: **Cache → WebSocket**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// Falls back to WebSocket query if cache miss.
  ///
  /// Results from websocket are cached for future queries.
  Future<Event?> fetchEventById(
    String eventId, {
    String? relayUrl,
    bool useCache = true,
  }) async {
    // 1. Check cache first
    final dao = _nostrEventsDao;
    if (useCache && dao != null) {
      final cached = await dao.getEventById(eventId);
      if (cached != null) {
        return cached;
      }
    }

    // 2. Query via WebSocket
    final targetRelays = relayUrl != null ? [relayUrl] : null;
    final filters = [
      Filter(ids: [eventId], limit: 1),
    ];
    final events = await queryEvents(
      filters,
      useCache: false, // Already checked cache above
      tempRelays: targetRelays,
    );
    if (events.isNotEmpty) {
      // Cache websocket result (fire-and-forget)
      try {
        unawaited(_nostrEventsDao?.upsertEvent(events.first));
      } on Object {
        // Ignore cache errors
      }

      return events.first;
    }
    return null;
  }

  /// Fetches a profile (kind 0) by pubkey
  ///
  /// Query flow: **Cache → WebSocket**
  ///
  /// If [useCache] is `true` and cache is available, checks local cache first.
  /// Falls back to WebSocket query if cache miss.
  ///
  /// Results from websocket are cached for future queries.
  Future<Event?> fetchProfile(String pubkey, {bool useCache = true}) async {
    // 1. Check cache first
    final dao = _nostrEventsDao;
    if (useCache && dao != null) {
      final cached = await dao.getProfileByPubkey(pubkey);
      if (cached != null) {
        return cached;
      }
    }

    // 2. Query via WebSocket
    final filters = [
      Filter(authors: [pubkey], kinds: [EventKind.metadata], limit: 1),
    ];
    final events = await queryEvents(
      filters,
      useCache: false, // Already checked cache above
    );
    if (events.isNotEmpty) {
      // Cache websocket result (fire-and-forget)
      try {
        unawaited(_nostrEventsDao?.upsertEvent(events.first));
      } on Object {
        // Ignore cache errors
      }
      return events.first;
    }
    return null;
  }

  /// Subscribes to events matching the given filters.
  ///
  /// Returns a broadcast stream of events. Anonymous subscriptions receive a
  /// fresh relay subscription every call so bounded query screens can
  /// re-enter safely after a previous listener was canceled. The returned
  /// stream is closed when its last listener cancels; call [subscribe] again
  /// instead of retaining and re-listening to the old stream.
  ///
  /// Set [closeOnEose] for bounded reads. Their stream closes after every
  /// serving relay reports EOSE, and the relay subscription is released.
  ///
  /// The stream emits a [RelaySubscriptionRefusedException] if every serving
  /// relay ends the REQ with `CLOSED`.
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    void Function()? onEose,
    bool closeOnEose = false,
  }) {
    final effectiveTempRelays = _allowedRelays(tempRelays);
    final effectiveTargetRelays = _allowedRelays(targetRelays);
    final filterHash = _generateFilterHash(filters);
    final id =
        subscriptionId ??
        'sub_${filterHash}_${_anonymousSubscriptionCounter++}';

    // Explicit subscription IDs are caller-owned. Preserve their sharing
    // semantics so manual unsubscribe call sites keep working as before.
    if (subscriptionId != null &&
        _subscriptionStreams.containsKey(id) &&
        !_subscriptionStreams[id]!.isClosed) {
      return _subscriptionStreams[id]!.stream;
    }

    // Ensure relays are connected before subscribing
    if (_relayManager.connectedRelays.isEmpty) {
      unawaited(retryDisconnectedRelays());
    }

    late final StreamController<Event> controller;
    var effectiveId = id;

    void cleanupSubscription() {
      if (!_subscriptionStreams.containsKey(effectiveId)) return;
      _nostr.unsubscribe(effectiveId);
      _subscriptionStreams.remove(effectiveId);
      statisticsObserver?.onSubscriptionClosed(effectiveId);
      if (!controller.isClosed) {
        unawaited(controller.close());
      }
    }

    // Create new stream controller
    controller = StreamController<Event>.broadcast(
      onCancel: cleanupSubscription,
    );
    _subscriptionStreams[id] = controller;

    // Convert filters to JSON format expected by nostr_sdk
    final filtersJson = filters.map((f) => f.toJson()).toList();

    // Subscribe using nostr_sdk
    final actualId = _nostr.subscribe(
      filtersJson,
      (event) {
        // Handle NIP-09 deletion events by removing target events from DB
        if (event.kind == EventKind.eventDeletion) {
          unawaited(_handleDeletionEvent(event).catchError((Object _) {}));
        } else if (!_shouldSkipAutoCache(event)) {
          // Auto-cache non-deletion events (fire-and-forget)
          try {
            unawaited(_nostrEventsDao?.upsertEvent(event));
          } on Object {
            // Ignore sync cache errors
          }
        }

        if (!controller.isClosed) {
          controller.add(event);
        }

        statisticsObserver?.onEventReceived();
      },
      id: id,
      tempRelays: effectiveTempRelays,
      targetRelays: effectiveTargetRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      onEose: () {
        onEose?.call();
        if (closeOnEose) cleanupSubscription();
      },
      onClosed: (reason) {
        if (!controller.isClosed) {
          controller.addError(RelaySubscriptionRefusedException(reason));
        }
        cleanupSubscription();
      },
    );

    // If nostr_sdk generated a different ID, update our mapping
    effectiveId = (actualId != id && actualId.isNotEmpty) ? actualId : id;
    if (effectiveId != id) {
      _subscriptionStreams.remove(id);
      _subscriptionStreams[effectiveId] = controller;
    }

    statisticsObserver?.onSubscriptionStarted(effectiveId);

    return controller.stream;
  }

  /// Unsubscribes from a subscription
  Future<void> unsubscribe(String subscriptionId) async {
    _nostr.unsubscribe(subscriptionId);
    final controller = _subscriptionStreams.remove(subscriptionId);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    statisticsObserver?.onSubscriptionClosed(subscriptionId);
  }

  /// Closes all subscriptions
  ///
  /// Properly awaits each subscription's stream controller closure to ensure
  /// all resources are cleaned up before returning.
  Future<void> closeAllSubscriptions() async {
    final subscriptionIds = _subscriptionStreams.keys.toList();
    for (final id in subscriptionIds) {
      await unsubscribe(id);
    }
  }

  /// Adds a relay connection
  ///
  /// Delegates to RelayManager for persistence and status tracking.
  Future<bool> addRelay(
    String relayUrl, {
    RelayAddSource source = RelayAddSource.automatic,
  }) async {
    return _relayManager.addRelay(relayUrl, source: source);
  }

  /// Adds multiple relay connections
  ///
  /// This should be called and awaited BEFORE calling initialize() to ensure
  /// all relays are connected before the client starts making requests.
  ///
  /// Returns the number of relays successfully added.
  Future<int> addRelays(
    List<String> relayUrls, {
    RelayAddSource source = RelayAddSource.automatic,
  }) async {
    var addedCount = 0;
    for (final relayUrl in relayUrls) {
      final added = await addRelay(relayUrl, source: source);
      if (added) {
        addedCount++;
      }
    }
    return addedCount;
  }

  /// Filters one-off [relays] (e.g. `targetRelays` / `tempRelays`) to those
  /// admissible in the current environment, using the same rule as
  /// [RelayManager.isRelayAllowed].
  ///
  /// Returns null when [relays] is null or nothing survives the filter, so the
  /// caller falls back to the already-env-locked connected pool rather than an
  /// ambiguous empty target list.
  List<String>? _allowedRelays(List<String>? relays) {
    if (relays == null) return null;
    final allowed = relays.where(_relayManager.isRelayAllowed).toList();
    return allowed.isEmpty ? null : allowed;
  }

  /// Whether [tempRelays] names at least one relay the pool does not own.
  ///
  /// Only such a relay can answer a fan-out while every pooled relay is
  /// disconnected: `RelayPool` hands a temp address that matches a pool
  /// member to the pooled relay object rather than opening a socket of its
  /// own. Compared on normalized URLs, since the pool stores them that way
  /// and a trailing slash must not make a pool member look like an outsider.
  bool _hasRelayOutsidePool(List<String>? tempRelays) {
    if (tempRelays == null || tempRelays.isEmpty) return false;
    final pooled = _relayManager.configuredRelays.toSet();
    return tempRelays.any(
      (url) => !pooled.contains(normalizeRelayUrl(url) ?? url),
    );
  }

  /// Removes a relay connection.
  ///
  /// User removals are remembered so automatic discovery does not re-add the
  /// relay. Automatic removals are only reconciliation cleanup.
  Future<bool> removeRelay(
    String relayUrl, {
    required RelayRemoveSource source,
  }) async {
    return _relayManager.removeRelay(relayUrl, source: source);
  }

  /// Whether [url] is admissible under the configured environment lock.
  ///
  /// Delegates to [RelayManager.isRelayAllowed] — the single source of truth
  /// for the rule. Non-production builds lock to their own relay host.
  bool isRelayAllowed(String url) => _relayManager.isRelayAllowed(url);

  /// Whether [url] is currently suppressed by user-removal intent.
  Future<bool> isUserRemovedRelay(String url) {
    return _relayManager.isUserRemovedRelay(url);
  }

  /// The environment default relay URL.
  ///
  /// Resolves per environment (e.g. the staging relay on staging). Users can
  /// remove it from Settings, but doing so may degrade the app experience until
  /// it is restored.
  String get defaultRelayUrl => _relayManager.defaultRelayUrl;

  /// Gets list of configured relay URLs
  List<String> get configuredRelays => _relayManager.configuredRelays;

  /// Gets list of connected relay URLs
  List<String> get connectedRelays => _relayManager.connectedRelays;

  /// Gets count of connected relays
  int get connectedRelayCount => _relayManager.connectedRelayCount;

  /// Gets count of configured relays
  int get configuredRelayCount => _relayManager.configuredRelayCount;

  /// Gets relay statuses
  Map<String, RelayConnectionStatus> get relayStatuses =>
      _relayManager.currentStatuses;

  /// Stream of relay status updates
  Stream<Map<String, RelayConnectionStatus>> get relayStatusStream =>
      _relayManager.statusStream;

  /// Primary relay for client operations
  ///
  /// Returns the first connected relay, or first configured relay,
  /// or the environment default relay URL if none are configured.
  String get primaryRelay {
    if (connectedRelays.isNotEmpty) {
      return connectedRelays.first;
    }
    if (configuredRelays.isNotEmpty) {
      return configuredRelays.first;
    }
    return _relayManager.defaultRelayUrl;
  }

  /// Returns per-relay counters from the SDK's [RelayStatus].
  ///
  /// These are the actual per-relay statistics tracked by the SDK
  /// (events received, queries sent, errors) — not app-level aggregates.
  Map<String, ({int eventsReceived, int queriesSent, int errors})>
  getRelayPoolCounters() {
    return _relayManager.getRelayPoolCounters();
  }

  /// Gets relay statistics for diagnostics
  ///
  /// Returns a map containing relay connection stats.
  Future<Map<String, dynamic>?> getRelayStats() async {
    return {
      'connectedRelays': connectedRelayCount,
      'configuredRelays': configuredRelayCount,
      'relays': configuredRelays,
    };
  }

  /// Retry connecting to all disconnected relays
  Future<void> retryDisconnectedRelays() async {
    await _relayManager.retryDisconnectedRelays();
  }

  /// Force reconnect all relays (disconnect first, then reconnect)
  ///
  /// Use this when WebSocket connections may have been silently dropped
  /// (e.g., after app backgrounding).
  Future<void> forceReconnectAll() async {
    await _relayManager.forceReconnectAll();
  }

  /// Gets relay connection status as a simple map.
  ///
  /// Returns `Map<String, bool>` where the value indicates if
  /// the relay is connected.
  Map<String, bool> getRelayStatus() {
    final statuses = relayStatuses;
    final result = <String, bool>{};
    for (final entry in statuses.entries) {
      result[entry.key] =
          entry.value.state == RelayState.connected ||
          entry.value.state == RelayState.authenticated;
    }
    return result;
  }

  /// Sends a like reaction to an event
  ///
  /// Parameters:
  /// - [eventId]: The event ID being liked (required)
  /// - [content]: Reaction content, defaults to '+' for likes
  /// - [addressableId]: Optional addressable ID for Kind 30000+ events
  ///   (format: "kind:pubkey:d-tag"). When provided, adds an 'a' tag for
  ///   better discoverability of likes on addressable events.
  /// - [targetAuthorPubkey]: Optional pubkey of the liked event's author
  /// - [targetKind]: Optional kind of the event being liked (e.g., 34236)
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendLike(
    String eventId, {
    String? content,
    String? addressableId,
    String? targetAuthorPubkey,
    int? targetKind,
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final tags = <List<String>>[
      ['e', eventId],
      if (addressableId != null && addressableId.isNotEmpty)
        ['a', addressableId],
      if (targetAuthorPubkey != null && targetAuthorPubkey.isNotEmpty)
        ['p', targetAuthorPubkey],
      if (targetKind != null) ['k', targetKind.toString()],
    ];

    final likeEvent = Event(
      publicKey,
      EventKind.reaction,
      tags,
      content ?? '+',
    );

    final result = await publishSocialEventAwaitOk(
      likeEvent,
      targetRelays: targetRelays ?? tempRelays,
    );
    if (!result.accepted) throw SocialPublishException(result);
    return likeEvent;
  }

  /// Sends a user profile (Kind 0 metadata event), waiting for relay
  /// confirmation before reporting success.
  ///
  /// Routes through [publishEventAwaitOk] and only reports [PublishSuccess]
  /// once at least one relay has returned `OK true` (NIP-20). A Kind 0 that is
  /// accepted at the socket layer but then rejected by every relay (rate limit,
  /// PoW, auth required) is reported as [PublishFailed]. Kind 0 is replaceable,
  /// so [publishEventAwaitOk] caches it only after confirmation.
  ///
  /// The underlying [PublishOutcome] is mapped onto [PublishResult]:
  /// - [PublishSuccess] — at least one relay confirmed the event.
  /// - [PublishNoRelays] — no relay was connected even after retry, so the
  ///   publish never left the device. Preserves the dedicated no-relays
  ///   signal callers branch on.
  /// - [PublishFailed] — relays were connected but the event was not confirmed:
  ///   every relay rejected it, none responded before the confirmation
  ///   timeout, or the send failed before reaching them (e.g. the signer
  ///   returned null).
  Future<PublishResult> sendProfileAwaitOk({
    required Map<String, dynamic> profileContent,
    List<List<String>> tags = const [],
  }) async {
    // Resolve the no-relays case up front. [publishEventAwaitOk] returns an
    // all-empty [PublishOutcome] both when no relay was ever connected AND
    // when the relay pool was connected but the send failed before any `OK`
    // could arrive (e.g. the signer returned null) — the two are
    // indistinguishable from its result. Only the former is [PublishNoRelays],
    // so detect it here, mirroring [publishEvent]'s connectivity check. Any
    // non-confirmed outcome afterwards means relays were reached but did not
    // persist the event, which is [PublishFailed].
    if (_relayManager.connectedRelays.isEmpty) {
      await retryDisconnectedRelays();
      if (_relayManager.connectedRelays.isEmpty) {
        return const PublishNoRelays();
      }
    }

    final event = Event(
      publicKey,
      EventKind.metadata,
      tags.map(List<String>.from).toList(growable: false),
      jsonEncode(profileContent),
    );

    final outcome = await publishEventAwaitOk(event);

    if (outcome.confirmed) {
      return PublishSuccess(event: event);
    }

    return const PublishFailed();
  }

  /// Sends a repost
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendRepost(
    String eventId, {
    String? relayAddr,
    String content = '',
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final tags = <List<String>>[
      if (relayAddr != null && relayAddr.isNotEmpty)
        ['e', eventId, relayAddr]
      else
        ['e', eventId],
    ];

    final repostEvent = Event(publicKey, EventKind.repost, tags, content);

    final result = await publishEvent(
      repostEvent,
      targetRelays: targetRelays ?? tempRelays,
    );
    if (result case PublishSuccess(:final event)) {
      return event;
    }
    return null;
  }

  /// Sends a generic repost (Kind 16) for addressable events.
  ///
  /// Generic reposts (NIP-18) are used for reposting addressable events
  /// like videos (Kind 34236) using the 'a' tag instead of 'e' tag.
  ///
  /// Parameters:
  /// - [addressableId]: The addressable event identifier
  ///   (e.g., "34236:pubkey:d-tag")
  /// - [targetKind]: The kind of the event being reposted
  ///   (e.g., 34236 for videos)
  /// - [authorPubkey]: The public key of the original event author
  /// - [content]: Optional content for the repost (usually empty)
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  ///
  /// Note: Including [eventId] is recommended for better relay compatibility.
  /// Some relays don't properly index `#a` tags, but `#e` tags are universally
  /// supported.
  Future<Event?> sendGenericRepost({
    required String addressableId,
    required int targetKind,
    required String authorPubkey,
    String? eventId,
    String content = '',
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final tags = <List<String>>[
      ['k', '$targetKind'],
      ['a', addressableId],
      ['p', authorPubkey],
    ];

    // Include e tag for better relay compatibility (NIP-18 recommends this)
    if (eventId != null) {
      tags.add(['e', eventId]);
    }

    final event = Event(publicKey, EventKind.genericRepost, tags, content);

    final result = await publishEvent(
      event,
      targetRelays: targetRelays ?? tempRelays,
    );
    if (result case PublishSuccess(:final event)) {
      return event;
    }
    return null;
  }

  /// Deletes an event
  ///
  /// Sends a NIP-09 deletion event (Kind 5) and removes the target event
  /// from the local database cache.
  Future<Event?> deleteEvent(
    String eventId, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final deletionEvent = Event(publicKey, EventKind.eventDeletion, [
      ['e', eventId],
    ], 'delete');

    final result = await publishSocialEventAwaitOk(
      deletionEvent,
      targetRelays: targetRelays ?? tempRelays,
    );
    if (!result.accepted) throw SocialPublishException(result);
    return deletionEvent;
  }

  /// Publishes a social event and classifies its relay acknowledgement.
  ///
  /// Any relay acceptance wins. Account restrictions are only classified
  /// from the trusted default relay when no relay accepted the event.
  Future<SocialPublishResult> publishSocialEventAwaitOk(
    Event event, {
    List<String>? targetRelays,
  }) async {
    final hasExplicitTargets = targetRelays != null && targetRelays.isNotEmpty;
    if (_relayManager.connectedRelays.isEmpty && !hasExplicitTargets) {
      await retryDisconnectedRelays();
      if (_relayManager.connectedRelays.isEmpty) {
        return SocialPublishResult(
          status: SocialPublishStatus.noRelays,
          event: event,
        );
      }
    }

    final PublishOutcome outcome;
    try {
      outcome = await publishEventAwaitOk(
        event,
        targetRelays: targetRelays,
      );
    } on Object catch (error, stackTrace) {
      log(
        'Social event dispatch failed before relay acknowledgement',
        name: 'NostrClient',
        error: error,
        stackTrace: stackTrace,
      );
      return SocialPublishResult(
        status: SocialPublishStatus.sendFailed,
        event: event,
      );
    }
    final status = switch (outcome) {
      PublishOutcome(:final acceptedBy) when acceptedBy.isNotEmpty =>
        SocialPublishStatus.accepted,
      _
          when isAccountRestrictedOutcome(
            outcome,
            trustedRelayUrl: defaultRelayUrl,
          ) =>
        SocialPublishStatus.accountRestricted,
      _ when isRateLimitedOutcome(outcome) => SocialPublishStatus.rateLimited,
      PublishOutcome(:final rejectedBy) when rejectedBy.isNotEmpty =>
        SocialPublishStatus.rejected,
      PublishOutcome(:final noResponseFrom) when noResponseFrom.isNotEmpty =>
        SocialPublishStatus.noResponse,
      PublishOutcome(:final unreachableTargets)
          when unreachableTargets.isNotEmpty =>
        SocialPublishStatus.noRelays,
      _ => SocialPublishStatus.sendFailed,
    };
    return SocialPublishResult(status: status, event: event, outcome: outcome);
  }

  /// Deletes multiple events
  ///
  /// Sends a NIP-09 deletion event (Kind 5) and removes the target events
  /// from the local database cache.
  Future<Event?> deleteEvents(
    List<String> eventIds, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final deletionEvent = Event(
      publicKey,
      EventKind.eventDeletion,
      eventIds.map((eventId) => ['e', eventId]).toList(),
      'delete',
    );

    final result = await publishEvent(
      deletionEvent,
      targetRelays: targetRelays ?? tempRelays,
    );
    if (result case PublishSuccess(:final event)) {
      return event;
    }
    return null;
  }

  /// Sends a contact list
  ///
  /// Successfully sent events are cached locally with 1-day expiry.
  Future<Event?> sendContactList(
    ContactList contacts,
    String content, {
    List<String>? tempRelays,
    List<String>? targetRelays,
  }) async {
    final contactListEvent = Event(
      publicKey,
      EventKind.contactList,
      contacts.toJson(),
      content,
    );

    final result = await publishEvent(
      contactListEvent,
      targetRelays: targetRelays ?? tempRelays,
    );
    if (result case PublishSuccess(:final event)) {
      return event;
    }
    return null;
  }

  /// Known NIP-50 compatible search relays.
  static const List<String> _nip50SearchRelays = [
    'wss://relay.nostr.band',
    'wss://search.nos.today',
    'wss://nostr.wine',
  ];

  /// Searches for video events using NIP-50 search.
  ///
  /// Includes known NIP-50 relays for better coverage.
  Stream<Event> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) {
    final filter = Filter(
      kinds: const [34236],
      authors: authors,
      since: since != null ? since.millisecondsSinceEpoch ~/ 1000 : null,
      until: until != null ? until.millisecondsSinceEpoch ~/ 1000 : null,
      limit: limit ?? 100,
      search: query,
    );

    return subscribe([filter], tempRelays: _nip50SearchRelays);
  }

  /// Searches for user profiles using NIP-50 search.
  ///
  /// Includes known NIP-50 relays for better coverage.
  Stream<Event> searchUsers(String query, {int? limit}) {
    final filter = Filter(
      kinds: const [EventKind.metadata],
      limit: limit ?? 100,
      search: query,
    );

    return subscribe([filter], tempRelays: _nip50SearchRelays);
  }

  /// Queries for user profiles using NIP-50 search
  ///
  /// Returns a list of profile events (kind 0) matching the search query.
  /// Uses NIP-50 search parameter for full-text search on compatible relays.
  ///
  /// Unlike [searchUsers], this returns a Future that completes once,
  /// making it suitable for one-time search operations.
  Future<List<Event>> queryUsers(
    String query, {
    int? limit,
    Duration timeout = const Duration(seconds: 5),
  }) {
    final filter = Filter(
      kinds: const [EventKind.metadata],
      limit: limit ?? 100,
      search: query,
    );

    return queryEvents(
      [filter],
      tempRelays: _nip50SearchRelays,
      useQueryPool: false,
      timeout: timeout,
    );
  }

  /// Creates a NIP-98 HTTP authentication header.
  ///
  /// Generates a signed kind 27235 event containing the [url] and [method],
  /// plus an optional SHA256 hash of the [payload]. Returns the header value
  /// in the format `Nostr <base64-encoded-event>`.
  Future<String?> createNip98AuthHeader({
    required String url,
    required String method,
    String? payload,
  }) async {
    final tags = [
      ['u', url],
      ['method', method],
      if (payload != null)
        ['payload', HashUtil.sha256Bytes(utf8.encode(payload))],
    ];
    final nip98Event = Event(_nostr.publicKey, EventKind.httpAuth, tags, '');
    await _nostr.signEvent(nip98Event);

    if (nip98Event.id.isEmpty || nip98Event.sig.isEmpty) return null;

    final eventJson = jsonEncode(nip98Event.toJson());
    final base64Event = base64Encode(utf8.encode(eventJson));
    return 'Nostr $base64Event';
  }

  /// Disposes the client and cleans up resources
  ///
  /// Closes all subscriptions, disconnects from relays, and cleans up
  /// internal state. After calling this, the client should not be used.
  ///
  /// If [initialize] never completed, [ready] is left pending forever — the
  /// provider/service tree that holds this client should rebuild against a
  /// new instance after dispose, so a stale awaiter on [ready] would be
  /// reading against the wrong identity anyway. Callers that await [ready]
  /// must check [isDisposed] (or their own ownership signal) before using
  /// the client.
  Future<void> dispose() async {
    // Before the first await: every await below is a window in which an armed
    // relay repair can fire and open a socket that the teardown at the end has
    // already walked past, leaving a live WebSocket and heartbeat timer nothing
    // can reach (#7367).
    _nostr.beginClose();
    await closeAllSubscriptions();
    await _relayManager.dispose();
    await _queryPool.close();
    _nostr.close();
    _verifyWorker?.close();
    _verifyWorker = null;
    _isDisposed = true;
  }

  /// Generates a deterministic hash for filters
  /// to prevent duplicate subscriptions
  String _generateFilterHash(List<Filter> filters) {
    final json = filters.map((f) => f.toJson()).toList();
    final jsonString = jsonEncode(json);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  List<Event> _eventsMatchingAnyFilter(
    List<Event> events,
    List<Filter> filters,
  ) {
    return [
      for (final event in events)
        if (filters.any((filter) => filter.checkEvent(event))) event,
    ];
  }

  /// Merges cached and network events, deduplicating by event ID.
  /// Network events take precedence (considered fresher).
  ///
  /// If [limit] is provided, returns at most [limit] events sorted by
  /// `created_at` descending (most recent first). This ensures the original
  /// filter's limit is respected even when combining multiple sources.
  List<Event> _mergeEvents(
    List<Event> cached,
    List<Event> network, {
    int? limit,
  }) {
    if (cached.isEmpty && network.isEmpty) return [];
    if (cached.isEmpty) {
      final result = List<Event>.of(network);
      if (limit != null && result.length > limit) {
        result.sort((a, b) => b.createdAt - a.createdAt);
        return result.take(limit).toList();
      }
      return result;
    }
    if (network.isEmpty) {
      final result = List<Event>.of(cached);
      if (limit != null && result.length > limit) {
        result.sort((a, b) => b.createdAt - a.createdAt);
        return result.take(limit).toList();
      }
      return result;
    }

    final eventMap = <String, Event>{};
    // Add cached events first
    for (final event in cached) {
      eventMap[event.id] = event;
    }
    // Network events overwrite cached (fresher data)
    for (final event in network) {
      eventMap[event.id] = event;
    }

    final merged = eventMap.values.toList();

    // Apply limit if specified, returning the most recent events
    if (limit != null && merged.length > limit) {
      merged.sort((a, b) => b.createdAt - a.createdAt);
      return merged.take(limit).toList();
    }

    return merged;
  }
}

/// The query pool never handed a slot over inside the read's budget, so the
/// relay pool never saw the read and owes no line for it.
class _QueryPoolWaitExpired implements Exception {
  const _QueryPoolWaitExpired();
}

const _invalidRelayCountSentinels = {
  '2147483647',
  '4294967295',
  '9223372036854775807',
};

int _normalizeRelayCount(int count) {
  if (count < 0 || _invalidRelayCountSentinels.contains(count.toString())) {
    return 0;
  }
  return count;
}
