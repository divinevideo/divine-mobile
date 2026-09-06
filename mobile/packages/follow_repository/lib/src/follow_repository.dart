import 'dart:async';
import 'dart:math';

import 'package:cache_sync/cache_sync.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:follow_repository/src/follow_list_kind.dart';
import 'package:follow_repository/src/follow_relationship.dart';
import 'package:follow_repository/src/follower_stats.dart';
import 'package:follow_repository/src/followers_snapshot.dart';
import 'package:follow_repository/src/following_cache_record.dart';
import 'package:follow_repository/src/following_snapshot.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// One follower, as reported by a single source.
///
/// `followedAt` is the `created_at` of the follower's kind 3 contact-list
/// event, or `null` when the source answered with a bare pubkey — the REST
/// API does not expose event timestamps.
typedef _FollowerRef = ({String pubkey, int? followedAt});

typedef _FollowerSourceResult = ({
  List<_FollowerRef> refs,
  Object? error,
  StackTrace? stackTrace,
});

typedef _CachedFollowerStats = ({FollowerStats stats, DateTime cachedAt});

typedef _FollowerCountObservation = ({
  int count,
  bool isComplete,
  String source,
});

typedef _WebSocketFollowerStats = ({
  int following,
  List<_FollowerCountObservation> followerCounts,
});

/// Repository for managing follow relationships.
/// Single source of truth for follow data.
///
/// Responsibilities:
/// - In-memory cache of following pubkeys
/// - Local storage persistence (SharedPreferences)
/// - Network sync (Nostr Kind 3 events)
///
/// Exposes a stream for reactive updates to the following list.
class FollowRepository {
  FollowRepository({
    required NostrClient nostrClient,
    required List<String> indexerRelayUrls,
    IsCacheInitializedCallback? isCacheInitialized,
    GetCachedEventsByKindCallback? getCachedEventsByKind,
    CacheUserEventCallback? cacheUserEvent,
    FunnelcakeApiClient? funnelcakeApiClient,
    ProfileStatsDao? profileStatsDao,
    IsOnlineCallback? isOnline,
    QueueOfflineFollowCallback? queueOfflineAction,
    QueryContactListCallback? queryContactList,
    RelayFactory? relayFactory,
    BlockedPubkeysCallback? blockedPubkeys,
    DateTime Function()? now,
    Duration indexerQueryTimeout = const Duration(seconds: 8),
    Duration indexerOperationTimeout = const Duration(seconds: 12),
  }) : _nostrClient = nostrClient,
       _blockedPubkeys = blockedPubkeys,
       _isCacheInitialized = isCacheInitialized,
       _getCachedEventsByKind = getCachedEventsByKind,
       _cacheUserEvent = cacheUserEvent,
       _funnelcakeApiClient = funnelcakeApiClient,
       _profileStatsDao = profileStatsDao,
       _isOnline = isOnline,
       _queueOfflineAction = queueOfflineAction,
       _indexerRelayUrls = indexerRelayUrls,
       _queryContactList = queryContactList ?? _defaultQueryContactList,
       _relayFactory = relayFactory ?? _defaultRelayFactory,
       _now = now ?? DateTime.now,
       _indexerQueryTimeout = indexerQueryTimeout,
       _indexerOperationTimeout = indexerOperationTimeout;

  final NostrClient _nostrClient;
  final IsCacheInitializedCallback? _isCacheInitialized;
  final GetCachedEventsByKindCallback? _getCachedEventsByKind;
  final CacheUserEventCallback? _cacheUserEvent;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// Callback to check if the device is online
  final IsOnlineCallback? _isOnline;

  /// Callback to queue actions for offline sync
  final QueueOfflineFollowCallback? _queueOfflineAction;

  /// Drift DAO for persisting follower stats across sessions.
  final ProfileStatsDao? _profileStatsDao;

  /// Indexer relay URLs for direct WebSocket queries.
  /// Pass empty list in tests to prevent real network connections.
  final List<String> _indexerRelayUrls;

  /// Callback to query a contact list from a relay event stream.
  final QueryContactListCallback _queryContactList;

  /// Factory for creating relay instances (injectable for testing).
  final RelayFactory _relayFactory;

  /// Callback supplying the accounts the signing user has blocked.
  ///
  /// Null leaves the published contact list unfiltered.
  final BlockedPubkeysCallback? _blockedPubkeys;

  /// Clock used by expiring caches and persisted-stat stabilization.
  final DateTime Function() _now;

  /// Maximum time to wait for an indexer relay to finish a count query.
  final Duration _indexerQueryTimeout;

  /// Maximum time for connect, response collection, and cleanup combined.
  final Duration _indexerOperationTimeout;

  Duration _remainingIndexerTime(DateTime deadline, {Duration? cap}) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) return Duration.zero;
    if (cap != null && cap < remaining) return cap;
    return remaining;
  }

  Future<T> _awaitIndexerOperation<T>(
    Future<T> future,
    DateTime deadline, {
    required FutureOr<T> Function() onTimeout,
    Duration? cap,
  }) => future.timeout(
    _remainingIndexerTime(deadline, cap: cap),
    onTimeout: onTimeout,
  );

  Future<void> _disconnectIndexer(
    RelayBase relay,
    String indexerUrl,
    DateTime deadline,
  ) async {
    try {
      await _awaitIndexerOperation<void>(
        relay.disconnect(),
        deadline,
        onTimeout: () {},
      );
    } catch (e) {
      Log.warning(
        'Error disconnecting from $indexerUrl: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Default relay factory — creates a real [RelayBase].
  static RelayBase _defaultRelayFactory(String url, RelayStatus status) =>
      RelayBase(url, status);

  /// Default implementation: listen for the first matching contact list
  /// event, with a timeout fallback.
  static Future<Event?> _defaultQueryContactList({
    required Stream<Event> eventStream,
    required String pubkey,
    int fallbackTimeoutSeconds = 10,
  }) async {
    final completer = Completer<Event?>();
    StreamSubscription<Event>? subscription;
    Timer? timeoutTimer;
    try {
      timeoutTimer = Timer(Duration(seconds: fallbackTimeoutSeconds), () {
        if (!completer.isCompleted) {
          final activeSubscription = subscription;
          subscription = null;
          unawaited(activeSubscription?.cancel());
          completer.complete(null);
        }
      });

      subscription = eventStream.listen(
        (event) {
          if (event.kind == EventKind.contactList && event.pubkey == pubkey) {
            if (!completer.isCompleted) {
              completer.complete(event);
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      return await completer.future;
    } finally {
      timeoutTimer?.cancel();
      await subscription?.cancel();
    }
  }

  // BehaviorSubject replays last value to late subscribers, fixing race condition
  // where BLoC subscribes AFTER initial emission.
  // Seeded with null to distinguish "not yet initialized" from "empty following list".
  final _followingSubject = BehaviorSubject<List<String>?>.seeded(null);
  Stream<List<String>> get followingStream =>
      _followingSubject.stream.whereType<List<String>>();

  // In-memory cache — following
  List<String> _followingPubkeys = [];
  Event? _currentUserContactListEvent;

  // ── Contact-list freshness (NIP-01) ──────────────────────────────────
  //
  // Kind 3 is replaceable, so NIP-01 already fixes which of two copies is
  // authoritative: the higher `created_at`, and on an exact tie the lower
  // event id. Nothing about the number of `p` tags enters that rule, and it
  // cannot: a shorter list is what a legitimate unfollow produces, so
  // "whichever has more follows wins" resurrects every removal made on
  // another device (#8266).
  //
  // Two of this repository's five sources cannot state a `created_at` at all
  // — the legacy bare-array cache written before this record existed, and the
  // funnelcake REST index, which is derived and lags. Their freshness is
  // unknowable rather than old, so they seed an empty state and lose to any
  // source that can name a timestamp.

  /// Where the list currently in [_followingPubkeys] came from, for ordering.
  ///
  /// `null` means nothing has been adopted yet. A non-null record with a
  /// `createdAt` of `null` means the source carried no timestamp.
  ({int? createdAt, String? id})? _followingProvenance;

  /// The list exactly as adopted, before any local follow/unfollow was
  /// applied on top. [_broadcastContactList] diffs [_followingPubkeys]
  /// against this to know what the pending local change actually is.
  List<String> _adoptedFollows = const [];

  /// Adopt [pubkeys] when [createdAt] makes its source the newest one seen.
  ///
  /// Returns whether the list was adopted. [createdAt] `null` means the source
  /// carries no timestamp; such a source can seed an empty state but never
  /// displace one that has a timestamp.
  bool _adoptContactList(
    List<String> pubkeys, {
    required int? createdAt,
    required String source,
    String? eventId,
  }) {
    final incumbent = _followingProvenance;

    if (incumbent != null && !_isNewer(createdAt, eventId, incumbent)) {
      Log.debug(
        'Keeping the contact list already loaded '
        '(created_at ${incumbent.createdAt ?? 'unknown'}) over $source '
        '(created_at ${createdAt ?? 'unknown'})',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return false;
    }

    _followingPubkeys = pubkeys;
    _adoptedFollows = List<String>.from(pubkeys);
    _followingProvenance = (createdAt: createdAt, id: eventId);
    _emitFollowingList();

    Log.info(
      'Adopted contact list from $source: ${pubkeys.length} following '
      '(created_at ${createdAt ?? 'unknown'})',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
    return true;
  }

  /// NIP-01's ordering for replaceable events, with "no timestamp" ranked
  /// below every real one.
  static bool _isNewer(
    int? createdAt,
    String? eventId,
    ({int? createdAt, String? id}) incumbent,
  ) {
    if (createdAt == null) return false;
    final incumbentCreatedAt = incumbent.createdAt;
    if (incumbentCreatedAt == null) return true;
    if (createdAt != incumbentCreatedAt) return createdAt > incumbentCreatedAt;

    // Same second. NIP-01: "the event with the lowest id (first in lexical
    // order) should be retained". Only decidable when both ids are known;
    // otherwise the incumbent stands.
    final incumbentId = incumbent.id;
    if (eventId == null || incumbentId == null) return false;
    return eventId.compareTo(incumbentId) < 0;
  }

  /// Remember [event] when it is the newest kind 3 seen so far.
  ///
  /// Deliberately independent of whether its *list* was adopted. Those are
  /// two questions: which copy is authoritative, and where `content` comes
  /// from. When a source already names the event the relay returns there is
  /// no list to adopt, but `content` must still come from it — NIP-02 puts
  /// the user's relay list there, and publishing `''` over it is #8265.
  void _rememberContactListEvent(Event event) {
    _currentUserContactListEvent = _pickBestContactList(
      _currentUserContactListEvent,
      event,
    );
  }

  /// Extract the `p`-tagged pubkeys of a kind 3 event.
  List<String> _followsOf(Event event, {required String source}) =>
      _sanitizePubkeys(
        event.tags
            .where((tag) => tag.length > 1 && tag[0] == 'p')
            .map((tag) => tag[1])
            .toList(),
        source: source,
      );

  // A contact-list broadcast withheld because the read that precedes it came
  // back inconclusive. Flushed by [retryPendingContactListBroadcast] and by
  // the next follow or unfollow, which rebroadcasts the whole list anyway.
  bool _contactListBroadcastPending = false;
  bool _isInitialized = false;
  final Completer<void> _initializedCompleter = Completer<void>();

  // In-memory cache — my followers (populated after first fetch)
  List<String> _cachedMyFollowersPubkeys = [];
  List<String>? _myFollowersLookupSource;
  Set<String> _myFollowersLookupCache = const {};
  int _cachedMyFollowersDatedCount = 0;
  int _cachedMyFollowerCount = 0;
  bool _hasMyFollowersCache = false;
  static const _profileListCacheTtl = Duration(seconds: 30);

  // Real-time sync subscription for cross-device synchronization
  StreamSubscription<Event>? _contactListSubscription;
  String? _contactListSubscriptionId;

  // Getters
  List<String> get followingPubkeys => List.unmodifiable(_followingPubkeys);
  bool get isInitialized => _isInitialized;
  int get followingCount => _followingPubkeys.length;

  /// Completes once [initialize] has finished, including the authoritative
  /// relay query.
  ///
  /// Anything that publishes a contact list on its own schedule — rather
  /// than in response to the user following someone — must wait for this.
  /// [initialize] emits the LocalStorage snapshot on [followingStream]
  /// seconds before the relay answers, and every derived source can lag or
  /// truncate (#6109); publishing from one destroys the follows it is
  /// missing. Never completes while the user has no keys, since
  /// [initialize] returns early and stays retryable.
  Future<void> get initialized => _initializedCompleter.future;

  /// Drops entries that are not 32-byte hex pubkeys.
  ///
  /// Every source of the following list is untrusted: Kind 3 events are
  /// written by any Nostr client, and both the REST API and our caches are
  /// derived from those events. A single non-hex entry makes
  /// [_broadcastContactList] throw in `Contact`'s constructor, which aborts
  /// the publish and permanently blocks every follow and unfollow — a real
  /// contact list on `wss://relay.divine.video` carries a `["p","nos"]` entry.
  /// Its origin was never identified: `"nos"` matches `tag[1]` of the
  /// `["client","nos",...]` tag the Nos app writes, but no parser reading that
  /// value without filtering on `p` exists in this repo or its history.
  List<String> _sanitizePubkeys(
    List<String> pubkeys, {
    required String source,
  }) {
    final valid = pubkeys.where(keyIsValid).toList();

    final droppedCount = pubkeys.length - valid.length;
    if (droppedCount > 0) {
      final dropped = pubkeys.where((pubkey) => !keyIsValid(pubkey));
      Log.warning(
        'Dropped $droppedCount invalid pubkey(s) from $source: '
        '${dropped.join(', ')}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    return valid;
  }

  /// Emit current state to stream (only if the list actually changed)
  void _emitFollowingList() {
    if (!_followingSubject.isClosed) {
      final newList = List<String>.unmodifiable(_followingPubkeys);
      final currentList = _followingSubject.valueOrNull;
      if (currentList == null ||
          newList.length != currentList.length ||
          !_listsEqual(newList, currentList)) {
        _followingSubject.add(newList);
      }
    }
  }

  /// Compare two lists for equality by value
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Dispose resources (idempotent — safe to call multiple times).
  Future<void> dispose() async {
    unawaited(_contactListSubscription?.cancel());
    if (_contactListSubscriptionId != null) {
      await _nostrClient.unsubscribe(_contactListSubscriptionId!);
      _contactListSubscriptionId = null;
    }
    if (!_followingSubject.isClosed) {
      unawaited(_followingSubject.close());
    }
  }

  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) => _followingPubkeys.contains(pubkey);

  /// The current user's follow relationship with [pubkey].
  ///
  /// Reads only the in-memory following and follower caches, so it is cheap
  /// enough to call per row while a list scrolls and never issues a network
  /// request. Returns [FollowRelationship.none] for the current user's own
  /// pubkey and for an empty [pubkey].
  ///
  /// Before [getMyFollowers] has populated the follower cache, "follows you"
  /// is unknowable, so a mutual reads as [FollowRelationship.youFollow] and a
  /// one-way follower reads as [FollowRelationship.none]. That cold-cache
  /// degradation only under-claims and upgrades as data arrives. It is not a
  /// guarantee against a stale contact list, though: the following and
  /// follower sets are unions across sources that are never pruned, so a
  /// superseded kind 3 from one relay can still read as
  /// [FollowRelationship.followsYou] or [FollowRelationship.mutual] after an
  /// unfollow.
  FollowRelationship relationshipTo(String pubkey) {
    if (pubkey.isEmpty || pubkey == _nostrClient.publicKey) {
      return FollowRelationship.none;
    }
    final youFollow = isFollowing(pubkey);
    final followsYou =
        _hasMyFollowersCache && _myFollowersLookup.contains(pubkey);
    return switch ((youFollow, followsYou)) {
      (true, true) => FollowRelationship.mutual,
      (true, false) => FollowRelationship.youFollow,
      (false, true) => FollowRelationship.followsYou,
      (false, false) => FollowRelationship.none,
    };
  }

  /// [_cachedMyFollowersPubkeys] as a set, rebuilt only when that list is
  /// replaced, so per-row membership tests stay O(1) on accounts with many
  /// thousands of followers. Both writers assign a fresh list instance, which
  /// is what makes the identity check a sufficient invalidation signal.
  Set<String> get _myFollowersLookup {
    if (!identical(_myFollowersLookupSource, _cachedMyFollowersPubkeys)) {
      _myFollowersLookupSource = _cachedMyFollowersPubkeys;
      _myFollowersLookupCache = _cachedMyFollowersPubkeys.toSet();
    }
    return _myFollowersLookupCache;
  }

  /// Get the list of followers for the current user.
  ///
  /// Queries Nostr relays for Kind 3 (contact list) events that mention
  /// the current user's pubkey in their 'p' tags.
  ///
  /// Returns a list of unique pubkeys of users who follow the current user,
  /// newest follower first — see [_newestFirst] for what "newest" means and
  /// where it is approximate.
  Future<List<String>> getMyFollowers() async =>
      (await _fetchMyFollowers()).pubkeys;

  /// [getMyFollowers] plus the size of the datable prefix.
  Future<({List<String> pubkeys, int datedCount})> _fetchMyFollowers() async {
    final pubkey = _nostrClient.publicKey;
    if (pubkey.isEmpty) return (pubkeys: <String>[], datedCount: 0);

    final result = await _fetchOrderedFollowers(pubkey);
    _cachedMyFollowersPubkeys = result.pubkeys;
    _cachedMyFollowersDatedCount = result.datedCount;
    _hasMyFollowersCache = true;
    return result;
  }

  /// Get the list of followers for another user.
  ///
  /// Queries Nostr relays for Kind 3 (contact list) events that mention
  /// the target pubkey in their 'p' tags.
  ///
  /// Returns a list of unique pubkeys of users who follow the target, newest
  /// follower first — see [_newestFirst].
  Future<List<String>> getFollowers(String pubkey) async {
    return _fetchFollowers(pubkey);
  }

  /// Fetches another user's followers and their authoritative count.
  ///
  /// The seam behind [watchOthersFollowersCached], for the same reason
  /// [fetchMyFollowersSnapshot] is one.
  @visibleForOverriding
  Future<FollowersSnapshot> fetchFollowersSnapshot(String pubkey) async {
    final followersFuture = _fetchOrderedFollowers(pubkey);
    final countFuture = getFollowerCount(pubkey);
    final followers = await followersFuture;
    final countFromService = await countFuture;

    // The service count is the displayed number, full stop. Substituting the
    // relay list length when it is 0 would put a relay-derived number back on
    // screen — the exact inflation #8197 removes — and it would swap the
    // rendered value a second time once the list resolved (#8259 review).
    // getFollowerCount already falls back to the persisted baseline when
    // neither REST nor the relays can answer.
    return FollowersSnapshot(
      pubkeys: followers.pubkeys,
      count: countFromService,
      datedCount: followers.datedCount,
    );
  }

  /// Get an accurate follower count for the current user.
  ///
  /// REST-authoritative, with relay fallback (see [getFollowerStats]).
  Future<int> getMyFollowerCount() async {
    final count = await getFollowerCount(_nostrClient.publicKey);
    _cachedMyFollowerCount = count;
    return count;
  }

  /// Progressively streams the current user's followers.
  ///
  /// Yields cached data immediately when available (from a previous fetch),
  /// then fetches fresh data from all sources and yields the updated result.
  /// Each emission contains the full follower list and an accurate count.
  ///
  /// Follows the same progressive-yield pattern as
  /// `VideosRepository.searchVideos`.
  Stream<FollowersSnapshot> watchMyFollowers() async* {
    // Phase 1: Yield cached data immediately (if available)
    if (_hasMyFollowersCache) {
      yield FollowersSnapshot(
        pubkeys: List<String>.unmodifiable(_cachedMyFollowersPubkeys),
        count: _cachedMyFollowerCount,
        datedCount: _cachedMyFollowersDatedCount,
      );
    }

    // Phase 2: Fetch fresh data from all sources in parallel
    yield await fetchMyFollowersSnapshot();
  }

  /// Fetches the current user's followers and their authoritative count.
  ///
  /// Shared by [watchMyFollowers] and [watchMyFollowersCached] so both build
  /// the snapshot — including its dated-prefix boundary — the same way.
  ///
  /// This, rather than [getMyFollowers], is the seam to override in a test
  /// double: a plain pubkey list cannot carry [FollowersSnapshot.datedCount].
  @visibleForOverriding
  Future<FollowersSnapshot> fetchMyFollowersSnapshot() async {
    final followersFuture = _fetchMyFollowers();
    final countFuture = getMyFollowerCount();
    final followers = await followersFuture;
    final countFromService = await countFuture;
    // Same rule as fetchFollowersSnapshot: the service count is displayed
    // verbatim, never substituted with the relay list length (#8259 review).
    final count = countFromService;

    // The list caches are updated by _fetchMyFollowers/getMyFollowerCount;
    // store the selected count so the next watchMyFollowers call yields it.
    _cachedMyFollowerCount = count;

    return FollowersSnapshot(
      pubkeys: followers.pubkeys,
      count: count,
      datedCount: followers.datedCount,
    );
  }

  /// Maps the current user's following stream to [FollowingSnapshot] objects.
  ///
  /// Used by [CacheSync.watchStream] in MyFollowingBloc to provide
  /// stale-while-revalidate behaviour backed by the Drift cache.
  Stream<FollowingSnapshot> watchMyFollowing() {
    return followingStream.map(
      (pubkeys) => FollowingSnapshot(pubkeys: pubkeys, count: pubkeys.length),
    );
  }

  /// Fetches the following list for any user by querying their Kind 3
  /// contact list event from Nostr relays.
  ///
  /// Returns a [FollowingSnapshot] with the deduplicated list of followed
  /// pubkeys. Returns an empty snapshot if no event is found.
  Future<FollowingSnapshot> getOthersFollowing(String pubkey) async {
    final events = await _nostrClient
        .queryEvents([
          Filter(authors: [pubkey], kinds: const [3], limit: 1),
        ])
        .timeout(_fetchFollowersTimeout);

    final following = <String>[];
    if (events.isNotEmpty) {
      for (final tag in events.first.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          final followedPubkey = tag[1];
          if (!following.contains(followedPubkey)) {
            following.add(followedPubkey);
          }
        }
      }
    }

    // Backs watchMyFollowingCached() for the current user too, so an invalid
    // entry would surface as a ghost row on the own-Following screen and be
    // persisted to Drift by CacheSync. Count follows the sanitized list so the
    // header cannot disagree with the rows.
    final sanitized = _sanitizePubkeys(
      following,
      source: 'Kind 3 event from $pubkey',
    );

    return FollowingSnapshot(pubkeys: sanitized, count: sanitized.length);
  }

  // ---- CacheSync-backed stale-while-revalidate watchers --------------------
  //
  // These wrap [watchMyFollowers], [watchMyFollowing], [getFollowers], and
  // [getOthersFollowing] with [CacheSync] so consumers (BLoCs) get
  // cache-first emissions followed by live data without knowing about
  // [CacheSync] or cache-key conventions. Cache keys are private to this
  // repository — changing them invalidates every cached entry on every user's
  // device.

  // Cache keys follow the `${pubkey}:${operation}` convention (RFC #4244) so
  // `CacheSync.invalidatePrefix(pubkey)` at sign-out clears every entry for
  // that account without touching other accounts on the same device.
  static String _myFollowersCacheKey(String pubkey) => '$pubkey:my_followers';
  static String _myFollowingCacheKey(String pubkey) => '$pubkey:my_following';
  static String _othersFollowersCacheKey(String pubkey) =>
      '$pubkey:others_followers';
  static String _othersFollowingCacheKey(String pubkey) =>
      '$pubkey:others_following';

  /// Best-effort invalidation of the cached following-list snapshot.
  ///
  /// `follow`/`unfollow` and the offline-sync/merge paths mutate the in-memory
  /// list and SharedPreferences but never the CacheSync disk entry. Without
  /// this, the next [watchMyFollowingCached] read serves a pre-mutation
  /// snapshot and the follow-button state reverts (#5144). Invalidation is
  /// non-fatal: a cache failure must not fail an otherwise-successful follow.
  Future<void> _invalidateMyFollowingCache() async {
    final pubkey = _nostrClient.publicKey;
    if (pubkey.isEmpty) return;
    try {
      await CacheSync.invalidate(_myFollowingCacheKey(pubkey));
    } on Exception catch (e) {
      Log.warning(
        'Failed to invalidate my_following cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Cache-backed stream of the current user's followers.
  ///
  /// Emits a [CacheResult.cached] if disk-cached data exists, then a single
  /// [CacheResult.live] once the network fetch resolves.
  ///
  /// Uses [CacheSync.watchOne] rather than [CacheSync.watchStream] so that
  /// [CacheSync] is the single owner of the stale/live boundary. Wrapping
  /// [watchMyFollowers] with [CacheSync.watchStream] created two cache layers:
  /// CacheSync emitted the disk entry as [CacheResult.cached], but
  /// [watchMyFollowers]'s own in-memory phase then emitted an additional
  /// snapshot that CacheSync incorrectly tagged as [CacheResult.live] before
  /// the real network fetch had completed, breaking [CacheResult.isLive]
  /// semantics.
  Stream<CacheResult<FollowersSnapshot>> watchMyFollowersCached() {
    return CacheSync.watchOne<FollowersSnapshot>(
      key: _myFollowersCacheKey(_nostrClient.publicKey),
      fetch: fetchMyFollowersSnapshot,
      fromJson: FollowersSnapshot.fromJson,
      toJson: (s) => s.toJson(),
      ttl: _profileListCacheTtl,
    );
  }

  /// Cache-backed stream of the current user's following list.
  ///
  /// Emits a [CacheResult.cached] if disk-cached data exists, then a single
  /// [CacheResult.live] once the network fetch resolves.
  ///
  /// Uses [CacheSync.watchOne] rather than [CacheSync.watchStream] for the
  /// same reason as [watchMyFollowersCached]: [watchMyFollowing] emits from
  /// a [BehaviorSubject] seeded by `initialize()`'s LocalStorage /
  /// PersonalEventCache reads. Subscribing via [CacheSync.watchStream]
  /// would replay that pre-network in-memory snapshot and CacheSync would
  /// incorrectly tag it as [CacheResult.live] before the network refresh
  /// has actually run, breaking the new `isRefreshing` / [CacheResult.isLive]
  /// contract.
  ///
  /// Ongoing follow/unfollow reactivity is handled by [followingStream]
  /// (the in-memory single source of truth). Local toggles and cross-device
  /// kind 3 updates invalidate the [_myFollowingCacheKey] entry via
  /// [_invalidateMyFollowingCache], so the next [watchMyFollowingCached] read
  /// (on a later mount) never serves a pre-mutation snapshot (#5144).
  Stream<CacheResult<FollowingSnapshot>> watchMyFollowingCached() {
    return CacheSync.watchOne<FollowingSnapshot>(
      key: _myFollowingCacheKey(_nostrClient.publicKey),
      fetch: () => getOthersFollowing(_nostrClient.publicKey),
      fromJson: FollowingSnapshot.fromJson,
      toJson: (s) => s.toJson(),
      ttl: _profileListCacheTtl,
    );
  }

  /// Cache-backed stream of another user's followers.
  ///
  /// Wraps [getFollowers] in a one-shot fetch under [CacheSync.watchOne].
  /// When [forceRefresh] is true, bypasses the cache and fetches live.
  Stream<CacheResult<FollowersSnapshot>> watchOthersFollowersCached(
    String pubkey, {
    bool forceRefresh = false,
  }) {
    return CacheSync.watchOne<FollowersSnapshot>(
      key: _othersFollowersCacheKey(pubkey),
      fetch: () => fetchFollowersSnapshot(pubkey),
      fromJson: FollowersSnapshot.fromJson,
      toJson: (s) => s.toJson(),
      ttl: _profileListCacheTtl,
      policy: forceRefresh
          ? CacheFetchPolicy.networkOnly
          : CacheFetchPolicy.cacheFirst,
    );
  }

  /// Cache-backed stream of another user's following list.
  ///
  /// Wraps [getOthersFollowing] in a one-shot fetch under [CacheSync.watchOne].
  /// When [forceRefresh] is true, bypasses the cache and fetches live.
  Stream<CacheResult<FollowingSnapshot>> watchOthersFollowingCached(
    String pubkey, {
    bool forceRefresh = false,
  }) {
    return CacheSync.watchOne<FollowingSnapshot>(
      key: _othersFollowingCacheKey(pubkey),
      fetch: () => getOthersFollowing(pubkey),
      fromJson: FollowingSnapshot.fromJson,
      toJson: (s) => s.toJson(),
      ttl: _profileListCacheTtl,
      policy: forceRefresh
          ? CacheFetchPolicy.networkOnly
          : CacheFetchPolicy.cacheFirst,
    );
  }

  /// Get an accurate follower count for any user.
  ///
  /// Fetches from multiple sources (REST + WebSocket + indexer relays),
  /// applies hysteresis stabilization, and persists via Drift.
  Future<int> getFollowerCount(String pubkey) async {
    try {
      final stats = await getFollowerStats(pubkey);
      return stats.followers;
    } catch (e) {
      Log.warning(
        'Error fetching follower count for ${pubkeyForLogs(pubkey)}: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return 0;
    }
  }

  /// Fetches follower/following counts from the Funnelcake REST API.
  ///
  /// Returns [SocialCounts] or null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<SocialCounts?> getSocialCounts(String pubkey) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getSocialCounts(pubkey);
  }

  /// Fetches paginated followers from the Funnelcake REST API.
  ///
  /// Unlike [getFollowers] which merges multiple sources,
  /// this returns paginated results from the API only.
  /// Returns null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<PaginatedPubkeys?> getFollowersFromApi({
    required String pubkey,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getFollowers(
      pubkey: pubkey,
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches paginated following list from the Funnelcake REST API.
  ///
  /// Returns null if the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<PaginatedPubkeys?> getFollowingFromApi({
    required String pubkey,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getFollowing(
      pubkey: pubkey,
      limit: limit,
      offset: offset,
    );
  }

  /// Server-side name search within [pubkey]'s follower or following list.
  ///
  /// Returns the subset of that list whose profile name, display name, or
  /// NIP-05 matches [query] — the work a client would otherwise do by pulling
  /// every profile down to the device.
  ///
  /// Returns an **empty set** when the search cannot be answered: no
  /// Funnelcake client, a blank query, an API error, or a deployment whose
  /// follow endpoints do not understand `q` yet. Callers must read that as
  /// "no remote matches", never as "no matches" — the API only indexes kind-3
  /// events seen on the Divine relay, so its answer is a supplement to local
  /// matching, not a replacement for it.
  ///
  /// The unsupported-deployment case is the dangerous one and is why the
  /// response's echoed filter is checked rather than assumed: an older server
  /// ignores the unknown `q` key and answers with the plain first page, which
  /// would otherwise be read as "these hundred people all match".
  ///
  /// Capped at one page: a filter UI does not page its own results, and the
  /// server clamps `limit` to 100 regardless.
  Future<Set<String>> searchFollowList({
    required String pubkey,
    required String query,
    required FollowListKind kind,
  }) async {
    final trimmed = query.trim();
    if (pubkey.isEmpty || trimmed.isEmpty) return const {};
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return const {};
    }

    try {
      final page = switch (kind) {
        FollowListKind.followers => await _funnelcakeApiClient.getFollowers(
          pubkey: pubkey,
          query: trimmed,
        ),
        FollowListKind.following => await _funnelcakeApiClient.getFollowing(
          pubkey: pubkey,
          query: trimmed,
        ),
      };
      // Only trust the page when the server says which filter produced it.
      if (page.appliedQuery?.trim().toLowerCase() != trimmed.toLowerCase()) {
        Log.warning(
          'Follow-list search ignored by the API; falling back to local '
          'matching',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return const {};
      }
      return page.pubkeys.toSet();
    } on FunnelcakeException catch (e) {
      // Expected while the `q` parameter is rolling out, and on any network
      // blip. The caller still has its local filter.
      Log.warning(
        'Follow-list search unavailable: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return const {};
    }
  }

  // === FOLLOWER STATS ===
  //
  // Positive REST counts are authoritative per field (#8197). Funnelcake's
  // follower and following counts come from independent inputs, so a positive
  // value in one cannot make an ambiguous zero in the other authoritative.
  // Hysteresis applies only to fields resolved through relay fallback.

  /// Counts older than this are considered stale and will be replaced
  /// even if the new value is lower.
  ///
  /// This has to outlast the gap between closing the app at night and opening
  /// it the next day, because that gap is the failure in #6902: a count that
  /// dropped overnight and stayed wrong. A one-hour window expired during every
  /// such gap, so the persisted baseline was always considered stale by morning
  /// and the low fresh count was accepted outright — the stabilization never
  /// ran in the one case it exists for.
  ///
  /// A genuine drop larger than [_hysteresisThreshold] still shows up
  /// immediately; only drops small enough to look like relay variance wait for
  /// this window.
  static const _staleDuration = Duration(hours: 24);

  /// A new count must drop below this fraction of the persisted count
  /// before being treated as a genuine decrease (when not stale).
  /// Drops within this threshold are assumed to be relay query variance.
  static const _hysteresisThreshold = 0.8;

  /// Small accounts should reflect one-person changes immediately; percentage
  /// hysteresis is only useful once counts are large enough for relay variance
  /// to dominate individual follow/unfollow events.
  static const _hysteresisMinimumCount = 20;

  /// Short-lived in-memory cache for follower/following counts.
  final Map<String, _CachedFollowerStats> _followerStatsCache = {};

  /// Load persisted follower stats from the Drift database.
  ///
  /// Returns null if no persisted data exists for this pubkey.
  Future<({int followers, int following, DateTime timestamp})?>
  _loadPersistedStats(String pubkey) async {
    final dao = _profileStatsDao;
    if (dao == null) return null;

    final row = await dao.getStatsRaw(pubkey);
    if (row == null) return null;

    return (
      followers: row.followerCount ?? 0,
      following: row.followingCount ?? 0,
      timestamp: row.followerCountsUpdatedAt ?? row.cachedAt,
    );
  }

  /// Persist follower stats to the Drift database.
  ///
  /// This refreshes the row's count-freshness stamp, which is correct for both
  /// of its readers: retention keeps the row, and the relay hysteresis treats
  /// the baseline as recently confirmed. Each ambiguous REST zero is withheld
  /// upstream, so a stamp means at least one count came from a trusted source
  /// or an established fallback baseline.
  Future<void> _persistFollowerStats(String pubkey, FollowerStats stats) async {
    await _profileStatsDao?.upsertStats(
      pubkey: pubkey,
      followerCount: stats.followers,
      followingCount: stats.following,
    );
  }

  /// Apply hysteresis: keep the persisted (higher) count when the fresh
  /// count is lower but within the threshold, unless the persisted value
  /// is stale.
  ///
  /// Returns the stabilized count.
  int _applyHysteresis({
    required int freshCount,
    required int persistedCount,
    required DateTime persistedTimestamp,
  }) {
    // Fresh count is higher → always accept
    if (freshCount >= persistedCount) return freshCount;

    // One-person changes are meaningful for small accounts.
    if (persistedCount < _hysteresisMinimumCount) return freshCount;

    // Persisted count is stale → accept the fresh count
    if (_now().difference(persistedTimestamp) > _staleDuration) {
      return freshCount;
    }

    // Fresh count is lower — if the drop is within the threshold, keep
    // the persisted count (assumed relay variance). If it dropped below
    // the threshold, accept the new count as a genuine change.
    final threshold = (persistedCount * _hysteresisThreshold).ceil();
    if (freshCount >= threshold) {
      return persistedCount;
    }

    return freshCount;
  }

  /// Compare fresh network counts against the persistent cache and apply
  /// hysteresis to each counter independently.
  FollowerStats _stabilizeStats(
    String pubkey,
    FollowerStats freshStats, {
    required ({int followers, int following, DateTime timestamp})? persisted,
    required bool followersAuthoritative,
    required bool followingAuthoritative,
  }) {
    if (persisted == null) return freshStats;

    final stableFollowers = followersAuthoritative
        ? freshStats.followers
        : _applyHysteresis(
            freshCount: freshStats.followers,
            persistedCount: persisted.followers,
            persistedTimestamp: persisted.timestamp,
          );
    final stableFollowing = followingAuthoritative
        ? freshStats.following
        : _applyHysteresis(
            freshCount: freshStats.following,
            persistedCount: persisted.following,
            persistedTimestamp: persisted.timestamp,
          );

    if (stableFollowers != freshStats.followers ||
        stableFollowing != freshStats.following) {
      Log.info(
        'Hysteresis stabilized stats for ${pubkeyForLogs(pubkey)}: '
        'fresh=${freshStats.followers}/${freshStats.following} '
        '-> stable=$stableFollowers/$stableFollowing '
        '(persisted=${persisted.followers}/'
        '${persisted.following})',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    return FollowerStats(
      followers: stableFollowers,
      following: stableFollowing,
    );
  }

  /// Get follower and following counts for a specific pubkey.
  ///
  /// Returns in-memory cached data when available. Otherwise each positive
  /// REST field is authoritative (#8197), while an ambiguous zero field falls
  /// back to relays and the persisted baseline with hysteresis.
  Future<FollowerStats> getFollowerStats(String pubkey) async {
    Log.debug(
      'Fetching follower stats for: ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    try {
      // Check in-memory cache first
      final cachedStats = _followerStatsCache[pubkey];
      if (cachedStats != null &&
          _now().difference(cachedStats.cachedAt) < _profileListCacheTtl) {
        Log.debug(
          'Using cached follower stats: ${cachedStats.stats}',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return cachedStats.stats;
      }
      _followerStatsCache.remove(pubkey);

      // Fetch from network
      final fetch = await _fetchFollowerStats(pubkey);
      final freshStats = fetch.stats;

      if (fetch.followersAuthoritative && fetch.followingAuthoritative) {
        // Both REST fields carry signal, so they are definitive (#8197): a
        // drop is a real drop and no relay hysteresis applies.
        _cacheFollowerStats(pubkey, freshStats);
        final persisted = await _loadPersistedStats(pubkey);
        if (persisted == null ||
            freshStats.followers != persisted.followers ||
            freshStats.following != persisted.following) {
          await _persistFollowerStats(pubkey, freshStats);
        }
        return freshStats;
      }

      final persisted = await _loadPersistedStats(pubkey);

      // Relay fallback below: counts are partial observations, so guard
      // zeros and stabilize drops before display.
      // When all sources returned zero, treat it as a network failure
      // and fall back to persisted data rather than showing 0.
      if (freshStats.followers == 0 && freshStats.following == 0) {
        if (persisted != null &&
            (persisted.followers > 0 || persisted.following > 0)) {
          final fallback = FollowerStats(
            followers: persisted.followers,
            following: persisted.following,
          );
          _cacheFollowerStats(pubkey, fallback);
          return fallback;
        }
        return freshStats;
      }

      // A zero with no authoritative REST signal and no relay observation is
      // absence, not a measured drop. Preserve that field's known baseline;
      // otherwise the large-drop branch in hysteresis would accept it as real.
      final fallbackStats = FollowerStats(
        followers:
            !fetch.followersAuthoritative &&
                freshStats.followers == 0 &&
                (persisted?.followers ?? 0) > 0
            ? persisted!.followers
            : freshStats.followers,
        following:
            !fetch.followingAuthoritative &&
                freshStats.following == 0 &&
                (persisted?.following ?? 0) > 0
            ? persisted!.following
            : freshStats.following,
      );

      // Apply hysteresis against the persistent cache so relay observations
      // don't visibly fluctuate across app restarts.
      final stats = _stabilizeStats(
        pubkey,
        fallbackStats,
        persisted: persisted,
        followersAuthoritative: fetch.followersAuthoritative,
        followingAuthoritative: fetch.followingAuthoritative,
      );

      // Cache in memory.
      _cacheFollowerStats(pubkey, stats);

      // Only re-persist when the value actually changed. When hysteresis
      // keeps the old persisted count, skipping the write preserves the
      // original timestamp so the stale check can eventually trigger.
      if (persisted == null ||
          stats.followers != persisted.followers ||
          stats.following != persisted.following) {
        await _persistFollowerStats(pubkey, stats);
      }

      Log.debug(
        'Follower stats fetched: $stats',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return stats;
    } catch (e) {
      Log.error(
        'Error fetching follower stats: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      // On network failure, try returning persisted data so the UI
      // shows the last known count instead of zero.
      final persisted = await _loadPersistedStats(pubkey);
      if (persisted != null) {
        final fallback = FollowerStats(
          followers: persisted.followers,
          following: persisted.following,
        );
        _cacheFollowerStats(pubkey, fallback);
        return fallback;
      }

      return FollowerStats.zero;
    }
  }

  void _cacheFollowerStats(String pubkey, FollowerStats stats) {
    _followerStatsCache[pubkey] = (stats: stats, cachedAt: _now());
  }

  /// Fetch follower stats from the network.
  ///
  /// The Funnelcake REST API is queried first. Each positive field is used
  /// verbatim as authoritative (#8197); an ambiguous zero field is resolved
  /// through relays and the persisted baseline instead. Relay observations
  /// are partial and vary per query, so only fallback fields feed hysteresis.
  Future<
    ({
      FollowerStats stats,
      bool followersAuthoritative,
      bool followingAuthoritative,
    })
  >
  _fetchFollowerStats(String pubkey) async {
    final restResult = await _fetchFollowerStatsViaRest(pubkey);
    // Authority is per field. The two counts come from independent inputs, so
    // a positive value in one is no evidence that zero in the other means
    // "genuinely zero" rather than "not indexed" (#8259 review).
    // `/api/users/{pubkey}/social` answers 200 for every pubkey — there is no
    // 404 for an account funnelcake has never ingested — and `get_social_stats`
    // collapses any ClickHouse failure into `{0, 0}` rather than an error. Four
    // different server states therefore arrive byte-identical: never indexed,
    // genuinely zero, vanished, and the summary table being down. Treating them
    // as authoritative would display zeros and, worse, persist them over a good
    // baseline; the last of those states was observed returning zeros for every
    // pubkey in production during review of this change.
    final followersAuthoritative = (restResult?.followers ?? 0) > 0;
    final followingAuthoritative = (restResult?.following ?? 0) > 0;
    if (followersAuthoritative && followingAuthoritative) {
      final authoritativeRestResult = restResult!;
      Log.info(
        'Follower counts from REST (authoritative): '
        '${authoritativeRestResult.followers} followers, '
        '${authoritativeRestResult.following} following '
        'for ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return (
        stats: authoritativeRestResult,
        followersAuthoritative: true,
        followingAuthoritative: true,
      );
    }
    if (restResult != null) {
      Log.info(
        'REST follower stats need per-field fallback for '
        '${pubkeyForLogs(pubkey)}: '
        '${restResult.followers} followers, ${restResult.following} following',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    final wsResult = await _fetchFollowerStatsViaWebSocket(pubkey);
    final relayFollowers = _selectFollowerCount(wsResult.followerCounts);
    final followers = followersAuthoritative
        ? restResult!.followers
        : relayFollowers;
    final following = followingAuthoritative
        ? restResult!.following
        : wsResult.following;
    final observationSummary = wsResult.followerCounts.isEmpty
        ? 'none'
        : wsResult.followerCounts
              .map(
                (result) =>
                    '${result.source}=${result.count}'
                    '${result.isComplete ? '(complete)' : '(partial)'}',
              )
              .join(', ');

    Log.info(
      'Follower count fallback observations: $observationSummary, '
      'using $followers for ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return (
      stats: FollowerStats(followers: followers, following: following),
      followersAuthoritative: followersAuthoritative,
      followingAuthoritative: followingAuthoritative,
    );
  }

  /// Selects the best-covered follower count across relay observations.
  ///
  /// Only used on the relay-fallback path, where aggregate counts cannot
  /// distinguish a stale over-count from a source with broader relay
  /// coverage. Completion only means that source finished answering; it
  /// does not make its holdings globally authoritative, so a lower
  /// observation must not discard a potentially better-covered source.
  static int _selectFollowerCount(
    List<_FollowerCountObservation> observations,
  ) {
    if (observations.isEmpty) return 0;
    return observations.map((result) => result.count).reduce(max);
  }

  /// Try fetching follower stats via the Funnelcake REST API.
  ///
  /// Returns null if the REST API is unavailable or the request fails.
  Future<FollowerStats?> _fetchFollowerStatsViaRest(String pubkey) async {
    final client = _funnelcakeApiClient;
    if (client == null || !client.isAvailable) {
      return null;
    }

    try {
      final counts = await client.getSocialCounts(pubkey);
      if (counts != null) {
        Log.debug(
          'REST API follower stats: '
          '${counts.followerCount} followers, '
          '${counts.followingCount} following '
          'for ${pubkeyForLogs(pubkey)}',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        return FollowerStats(
          followers: counts.followerCount,
          following: counts.followingCount,
        );
      }
    } catch (e) {
      Log.warning(
        'REST API follower stats failed, '
        'falling back to WebSocket: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    return null;
  }

  /// Fetch follower stats via WebSocket queries (parallel).
  Future<_WebSocketFollowerStats> _fetchFollowerStatsViaWebSocket(
    String pubkey,
  ) async {
    try {
      final (following, followerCounts) = await (
        _fetchFollowingCountViaWebSocket(pubkey),
        _fetchFollowersCountViaIndexers(pubkey),
      ).wait;

      return (following: following, followerCounts: followerCounts);
    } catch (e) {
      Log.error(
        'Error fetching follower stats via WebSocket: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return (
        following: 0,
        followerCounts: const <_FollowerCountObservation>[],
      );
    }
  }

  /// Get following count via WebSocket (Kind 3 contact list).
  Future<int> _fetchFollowingCountViaWebSocket(String pubkey) async {
    final eventStream = _nostrClient.subscribe([
      Filter(authors: [pubkey], kinds: [EventKind.contactList], limit: 1),
    ]);

    final event = await _queryContactList(
      eventStream: eventStream,
      pubkey: pubkey,
      fallbackTimeoutSeconds: 3,
    );

    if (event != null) {
      final count = event.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'p')
          .length;
      Log.debug(
        'WebSocket following count: $count for ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return count;
    }
    return 0;
  }

  /// Get follower-count observations by querying indexer relays directly.
  Future<List<_FollowerCountObservation>> _fetchFollowersCountViaIndexers(
    String pubkey,
  ) async {
    final results = await Future.wait(
      _indexerRelayUrls.map(
        (url) =>
            _queryIndexerForFollowerCount(url, pubkey).catchError((Object e) {
              Log.warning(
                'Indexer $url follower count query '
                'failed: $e',
                name: 'FollowRepository',
                category: LogCategory.system,
              );
              return null;
            }),
      ),
    );

    return results.whereType<_FollowerCountObservation>().toList();
  }

  /// Query a single indexer relay for kind 3 events mentioning pubkey.
  Future<_FollowerCountObservation?> _queryIndexerForFollowerCount(
    String indexerUrl,
    String pubkey,
  ) async {
    final deadline = DateTime.now().add(_indexerOperationTimeout);
    final relayStatus = RelayStatus(indexerUrl);
    final relay = _relayFactory(indexerUrl, relayStatus);
    final completer = Completer<int>();
    final followerPubkeys = <String>{};
    final subscriptionId = 'fc_${DateTime.now().millisecondsSinceEpoch}';
    var isComplete = false;

    relay.onMessage = (relay, jsonMsg) async {
      if (jsonMsg.isEmpty) return;

      final messageType = jsonMsg[0] as String;

      if (messageType == 'EVENT' && jsonMsg.length >= 3) {
        final eventJson = jsonMsg[2] as Map<String, dynamic>;
        final eventPubkey = eventJson['pubkey'] as String?;
        if (eventPubkey != null) {
          followerPubkeys.add(eventPubkey);
        }
      } else if (messageType == 'EOSE') {
        if (!completer.isCompleted) {
          isComplete = true;
          completer.complete(followerPubkeys.length);
        }
      }
    };

    try {
      final filter = <String, dynamic>{
        'kinds': <int>[EventKind.contactList],
        '#p': <String>[pubkey],
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await _awaitIndexerOperation<bool>(
        relay.connect(),
        deadline,
        onTimeout: () => false,
      );
      if (!connected) {
        return null;
      }

      final result = await _awaitIndexerOperation<int>(
        completer.future,
        deadline,
        cap: _indexerQueryTimeout,
        onTimeout: () => followerPubkeys.length,
      );

      await _awaitIndexerOperation<bool>(
        relay.send(<dynamic>['CLOSE', subscriptionId]),
        deadline,
        onTimeout: () => false,
      );
      Log.debug(
        'Indexer $indexerUrl returned $result '
        'followers for ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return (count: result, isComplete: isComplete, source: indexerUrl);
    } catch (e) {
      Log.warning(
        'Error querying $indexerUrl for followers: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return followerPubkeys.isEmpty
          ? null
          : (
              count: followerPubkeys.length,
              isComplete: isComplete,
              source: indexerUrl,
            );
    } finally {
      await _disconnectIndexer(relay, indexerUrl, deadline);
    }
  }

  /// Timeout for fetching followers from relays
  static const _fetchFollowersTimeout = Duration(seconds: 8);

  /// Fetch followers for a given pubkey, newest follower first.
  ///
  /// Runs REST API, connected relay, and indexer relay queries in parallel
  /// and merges results (union of pubkeys). The REST API (Funnelcake) only
  /// indexes kind 3 events seen on the Divine relay, so follower lists are
  /// often incomplete. Connected relays may timeout. Indexer relays
  /// (relay.damus.io, purplepag.es) maintain broad kind 3 indexes and
  /// provide the most complete follower lists.
  ///
  /// Ordering comes from [_newestFirst].
  ///
  /// Returns an empty list when every successful source reports no followers.
  /// Propagates a source error when no source returns a usable follower, since
  /// callers cannot distinguish that result from a genuinely empty list.
  Future<List<String>> _fetchFollowers(String pubkey) async =>
      (await _fetchOrderedFollowers(pubkey)).pubkeys;

  /// [_fetchFollowers] plus the size of the datable prefix.
  ///
  /// Snapshot builders need the boundary so `FollowersSnapshot.orderedBy` can
  /// flip the list without dragging the undated followers to the top.
  Future<({List<String> pubkeys, int datedCount})> _fetchOrderedFollowers(
    String pubkey,
  ) async {
    if (pubkey.isEmpty) {
      return (pubkeys: <String>[], datedCount: 0);
    }

    // One unavailable source must not discard usable observations from the
    // others, but total failure is not evidence that the user has no followers.
    final results = await Future.wait<_FollowerSourceResult>(
      _followerSources(pubkey).map(_guardFollowerSource),
    );
    final apiFollowers = results[0].refs;
    final relayFollowers = results[1].refs;
    final indexerFollowers = results[2].refs;

    // Merge all sources (union of pubkeys)
    final merged = _newestFirst([
      ...apiFollowers,
      ...relayFollowers,
      ...indexerFollowers,
    ]);

    _FollowerSourceResult? failed;
    for (final result in results) {
      if (result.error != null) failed = result;
    }
    if (merged.pubkeys.isEmpty && failed != null) {
      Error.throwWithStackTrace(
        failed.error!,
        failed.stackTrace ?? StackTrace.empty,
      );
    }

    // Unique per source, not raw events: the relay and indexer paths hand
    // back one ref per kind 3 they saw, so a follower whose superseded event
    // is still being served would otherwise inflate them against `merged`.
    int uniqueCount(List<_FollowerRef> refs) =>
        refs.map((ref) => ref.pubkey).toSet().length;

    Log.info(
      'Followers for ${pubkeyForLogs(pubkey)}: '
      'API=${uniqueCount(apiFollowers)}, '
      'relays=${uniqueCount(relayFollowers)}, '
      'indexers=${uniqueCount(indexerFollowers)}, '
      'merged=${merged.pubkeys.length}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return merged;
  }

  /// How far ahead of now a contact list's `created_at` may sit and still be
  /// trusted as a sort key.
  ///
  /// Honest clock skew is measured in minutes. `created_at` is author-signed
  /// and nothing on the read path bounds it, so without this an event dated
  /// 2100 would pin its author to the top of every follower list it appears
  /// in, permanently. The indexers are third-party relays, so their skew
  /// policy is not ours to lean on.
  ///
  /// Stricter than `DmSyncState.maxFutureSkewSeconds` (one day) because the
  /// costs differ: a DM must be kept and can only have its ordering clamped,
  /// while a follower demoted here still appears — just in the undated tail.
  static const _maxFutureFollowSkewSeconds = 300;

  /// The `created_at` to sort a follower by, or `null` when it cannot be
  /// trusted as one.
  ///
  /// A future-dated contact list is demoted to the undated tail rather than
  /// clamped to now, because clamping would still leave it at the very top —
  /// which is the thing worth preventing.
  static int? _datableFollowedAt(int? createdAt) {
    if (createdAt == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return createdAt > now + _maxFutureFollowSkewSeconds ? null : createdAt;
  }

  /// Orders follower references newest first and drops duplicates.
  ///
  /// `followedAt` is the `created_at` of the follower's kind 3 event. Kind 3
  /// is replaceable, so that is when they last edited their contact list, not
  /// the moment they followed — but for someone who *just* followed, the two
  /// are the same, which is what makes a new follower reachable at the top of
  /// the list. The REST source answers with bare pubkeys and no timestamp;
  /// those keep their arrival order behind every timestamped follower rather
  /// than being guessed at.
  ///
  /// When several sources report the same follower, the freshest timestamp
  /// wins.
  ///
  /// `datedCount` counts the timestamped followers. Because every one of them
  /// sorts ahead of every undated one, it doubles as the index where the
  /// undated tail begins.
  static ({List<String> pubkeys, int datedCount}) _newestFirst(
    Iterable<_FollowerRef> refs,
  ) {
    final followedAt = <String, int?>{};
    final arrival = <String, int>{};

    for (final ref in refs) {
      if (!arrival.containsKey(ref.pubkey)) {
        arrival[ref.pubkey] = arrival.length;
        followedAt[ref.pubkey] = ref.followedAt;
        continue;
      }
      final known = followedAt[ref.pubkey];
      final incoming = ref.followedAt;
      if (incoming != null && (known == null || incoming > known)) {
        followedAt[ref.pubkey] = incoming;
      }
    }

    // List.sort is not stable, and arrival order is the only ordering the
    // untimestamped REST followers have — tie-break on it explicitly.
    final ordered = arrival.keys.toList()
      ..sort((a, b) {
        final left = followedAt[a];
        final right = followedAt[b];
        if (left != right) {
          if (left == null) return 1;
          if (right == null) return -1;
          return right.compareTo(left);
        }
        return arrival[a]!.compareTo(arrival[b]!);
      });

    return (
      pubkeys: ordered,
      datedCount: followedAt.values.where((at) => at != null).length,
    );
  }

  /// The three follower sources, started in parallel.
  ///
  /// Order is fixed — `[REST API, connected relays, indexer relays]` — because
  /// [_fetchFollowers] indexes into the results to log per-source counts, and
  /// because [_newestFirst] falls back to arrival order for the REST source,
  /// which carries no timestamp.
  /// Failures are *not* swallowed here; each caller applies its own policy.
  List<Future<List<_FollowerRef>>> _followerSources(String pubkey) {
    final apiFuture = (_funnelcakeApiClient?.isAvailable ?? false)
        ? _funnelcakeApiClient!
              .getFollowers(pubkey: pubkey, limit: 5000)
              .then<List<_FollowerRef>>(
                (r) => [
                  for (final follower in r.pubkeys)
                    (pubkey: follower, followedAt: null),
                ],
              )
        : Future<List<_FollowerRef>>.value(const []);

    return [
      apiFuture,
      _fetchFollowersFromRelays(pubkey),
      _fetchFollowerRefsFromIndexers(pubkey),
    ];
  }

  Future<_FollowerSourceResult> _guardFollowerSource(
    Future<List<_FollowerRef>> source,
  ) => source.then<_FollowerSourceResult>(
    (refs) => (refs: refs, error: null, stackTrace: null),
    onError: (Object error, StackTrace stackTrace) =>
        (refs: const <_FollowerRef>[], error: error, stackTrace: stackTrace),
  );

  /// Streams the current user's followers as each source resolves.
  ///
  /// Every emission is the union of all sources that have answered so far, so
  /// the list only ever grows and a pubkey that has been emitted is always
  /// backed by a live source. Consumers that must not show a stale follower
  /// (the mutual-follow user picker) can therefore render the first emission
  /// immediately instead of waiting for the slowest relay.
  ///
  /// The REST API typically answers in ~150ms while indexer relays take up to
  /// ~2s, so the first emission carries the large majority of the final list.
  /// Each emission is ordered newest follower first, so a late relay can move
  /// an already-emitted follower up once it supplies a timestamp the REST
  /// source lacked.
  ///
  /// A failing source is skipped — a working one still yields a usable list,
  /// and a strict consumer keeps filtering rather than falling back. The
  /// stream only emits an error when it ends up with *no* followers at all
  /// and at least one source failed, which is the case where the caller
  /// genuinely cannot tell "you have no followers" from "the lookup broke".
  Stream<List<String>> streamMyFollowers() =>
      _streamFollowers(_nostrClient.publicKey);

  Stream<List<String>> _streamFollowers(String pubkey) async* {
    if (pubkey.isEmpty) {
      yield const [];
      return;
    }

    final merged = <_FollowerRef>[];
    var lastOrdered = (pubkeys: const <String>[], datedCount: 0);
    Object? lastError;
    StackTrace? lastStackTrace;

    final guarded = _followerSources(pubkey).map(_guardFollowerSource);

    await for (final result in Stream<_FollowerSourceResult>.fromFutures(
      guarded,
    )) {
      final (:refs, :error, :stackTrace) = result;
      if (error != null) {
        lastError = error;
        lastStackTrace = stackTrace;
        Log.warning(
          'Follower source failed: $error',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
        continue;
      }
      merged.addAll(refs);
      final ordered = _newestFirst(merged);
      // The union only grows, but a later source can still reorder it by
      // supplying a timestamp for a follower the REST source reported bare.
      // Comparing the ordered list keeps the "nobody new, nothing moved"
      // emission from churning the consumer's UI.
      final reordered = !_sameOrder(ordered.pubkeys, lastOrdered.pubkeys);
      // Tracked even when the order held: a late timestamp for a follower
      // already in place moves the dated boundary without moving anybody.
      lastOrdered = ordered;
      if (reordered) {
        yield List<String>.unmodifiable(ordered.pubkeys);
      }
    }

    if (merged.isEmpty && lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace ?? StackTrace.empty);
    }

    if (pubkey == _nostrClient.publicKey) {
      _cachedMyFollowersPubkeys = List<String>.of(lastOrdered.pubkeys);
      _cachedMyFollowersDatedCount = lastOrdered.datedCount;
      _hasMyFollowersCache = true;
    }
  }

  /// Whether both lists hold the same pubkeys in the same positions.
  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Query connected relays for kind 3 events mentioning a pubkey.
  ///
  /// Carries each event's `created_at` through so [_newestFirst] can order
  /// the merged list; duplicates are collapsed there.
  Future<List<_FollowerRef>> _fetchFollowersFromRelays(String pubkey) async {
    try {
      final events = await _nostrClient
          .queryEvents([
            Filter(kinds: const [EventKind.contactList], p: [pubkey]),
          ])
          .timeout(
            _fetchFollowersTimeout,
            onTimeout: () {
              Log.warning(
                'Followers relay query timed out '
                'for ${pubkeyForLogs(pubkey)}',
                name: 'FollowRepository',
                category: LogCategory.system,
              );
              return <Event>[];
            },
          );

      return [
        for (final event in events)
          (
            pubkey: event.pubkey,
            followedAt: _datableFollowedAt(event.createdAt),
          ),
      ];
    } on TimeoutException {
      Log.warning(
        'Followers relay query timed out for ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Query indexer relays for kind 3 events mentioning a pubkey.
  ///
  /// Returns actual pubkeys (not just a count) so results can be merged
  /// with API and connected relay results.
  Future<List<_FollowerRef>> _fetchFollowerRefsFromIndexers(
    String pubkey,
  ) async {
    final results = await Future.wait(
      _indexerRelayUrls.map(
        (url) => _queryIndexerForFollowerRefs(
          url,
          pubkey,
        ).catchError((_) => <_FollowerRef>[]),
      ),
    );

    final refs = results.expand((indexerRefs) => indexerRefs).toList();

    Log.debug(
      'Indexer follower pubkeys: '
      '${refs.map((ref) => ref.pubkey).toSet().length} for ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    return refs;
  }

  /// Query a single indexer relay for kind 3 events mentioning pubkey.
  ///
  /// Returns each follower with the event's `created_at`, so [_newestFirst]
  /// can order them.
  Future<List<_FollowerRef>> _queryIndexerForFollowerRefs(
    String indexerUrl,
    String pubkey,
  ) async {
    final deadline = DateTime.now().add(_indexerOperationTimeout);
    final relayStatus = RelayStatus(indexerUrl);
    final relay = _relayFactory(indexerUrl, relayStatus);
    final completer = Completer<List<_FollowerRef>>();
    final followers = <_FollowerRef>[];
    final subscriptionId = 'fr_${DateTime.now().millisecondsSinceEpoch}';

    relay.onMessage = (relay, jsonMsg) async {
      if (jsonMsg.isEmpty) return;

      final messageType = jsonMsg[0] as String;

      if (messageType == 'EVENT' && jsonMsg.length >= 3) {
        final eventJson = jsonMsg[2] as Map<String, dynamic>;
        final eventPubkey = eventJson['pubkey'] as String?;
        if (eventPubkey != null) {
          followers.add((
            pubkey: eventPubkey,
            followedAt: _datableFollowedAt(
              (eventJson['created_at'] as num?)?.toInt(),
            ),
          ));
        }
      } else if (messageType == 'EOSE') {
        if (!completer.isCompleted) {
          completer.complete(List<_FollowerRef>.of(followers));
        }
      }
    };

    try {
      final filter = <String, dynamic>{
        'kinds': <int>[EventKind.contactList],
        '#p': <String>[pubkey],
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await _awaitIndexerOperation<bool>(
        relay.connect(),
        deadline,
        onTimeout: () => false,
      );
      if (!connected) {
        return [];
      }

      final result = await _awaitIndexerOperation<List<_FollowerRef>>(
        completer.future,
        deadline,
        cap: _fetchFollowersTimeout,
        onTimeout: () => List<_FollowerRef>.of(followers),
      );

      await _awaitIndexerOperation<bool>(
        relay.send(<dynamic>['CLOSE', subscriptionId]),
        deadline,
        onTimeout: () => false,
      );
      return result;
    } catch (e) {
      Log.warning(
        'Error querying $indexerUrl for followers: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return List<_FollowerRef>.of(followers);
    } finally {
      await _disconnectIndexer(relay, indexerUrl, deadline);
    }
  }

  /// Check if the current user and another user mutually follow each other.
  ///
  /// Returns true only if:
  /// 1. The current user is following [pubkey] (local cache check, instant)
  /// 2. [pubkey] is following the current user (relay query for their Kind 3)
  ///
  /// Returns false if either direction is not a follow, or on timeout/error.
  Future<bool> isMutualFollow(String pubkey) async {
    // Step 1: Check if we follow them (instant, from local cache)
    if (!isFollowing(pubkey)) return false;

    // Step 2: Check if they follow us (requires relay query)
    try {
      final theirFollowers = await _fetchFollowers(_nostrClient.publicKey);
      return theirFollowers.contains(pubkey) ||
          // They follow us means their contact list mentions our pubkey.
          // _fetchFollowers returns authors of events mentioning us in p-tags,
          // so we check if the target pubkey is among those authors.
          await _checkIfTheyFollowUs(pubkey);
    } catch (e) {
      Log.warning(
        'Failed to check mutual follow for ${pubkeyForLogs(pubkey)}: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if [pubkey] follows the current user by querying their Kind 3 event.
  Future<bool> _checkIfTheyFollowUs(String pubkey) async {
    if (pubkey.isEmpty || _nostrClient.publicKey.isEmpty) {
      return false;
    }

    try {
      final events = await _nostrClient
          .queryEvents([
            Filter(
              authors: [pubkey],
              kinds: const [EventKind.contactList],
              limit: 1,
            ),
          ])
          .timeout(_fetchFollowersTimeout, onTimeout: () => <Event>[]);

      if (events.isEmpty) return false;

      // Check if our pubkey is in their contact list p-tags
      final contactList = events.first;
      for (final tag in contactList.tags) {
        if (tag.isNotEmpty &&
            tag[0] == 'p' &&
            tag.length > 1 &&
            tag[1] == _nostrClient.publicKey) {
          return true;
        }
      }
      return false;
    } catch (e) {
      Log.warning(
        'Failed to check if ${pubkeyForLogs(pubkey)} follows us: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Toggle follow status for a user.
  Future<void> toggleFollow(String pubkey) async {
    if (isFollowing(pubkey)) {
      await unfollow(pubkey);
    } else {
      await follow(pubkey);
    }
  }

  /// Initialize the repository - load from local cache, then sync with network
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Guard: Skip initialization if user is not authenticated.
    // Don't set _isInitialized = true so we can retry when keys are available.
    if (!_nostrClient.hasKeys) {
      Log.debug(
        'FollowRepository.initialize() skipped '
        '- no keys yet',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // 1. Load from local storage first for immediate UI display
      await _loadFromLocalStorage();

      // 2. Load from PersonalEventCache if available
      await _loadFromPersonalEventCache();

      // 3. If still empty, try REST API (funnelcake) for fast bootstrap
      if (_followingPubkeys.isEmpty &&
          (_funnelcakeApiClient?.isAvailable ?? false)) {
        await _loadFromRestApi();
      }

      // 4. Always query relays for the authoritative kind 3 event, even when
      // a derived source already answered. LocalStorage, PersonalEventCache
      // and the REST index are all derived from this event and can lag or
      // truncate; because the next follow rebuilds and republishes the whole
      // list, accepting an incomplete one destroys every follow it is
      // missing (#6109).
      if (_nostrClient.hasKeys) {
        await _loadFromRelay();
      }

      // 5. Subscribe to contact list for real-time sync and cross-device
      // updates (fires on future changes, not initial load)
      if (_nostrClient.hasKeys) {
        _subscribeToContactList();
      }

      _isInitialized = true;
      if (!_initializedCompleter.isCompleted) {
        _initializedCompleter.complete();
      }

      // Guarantee at least one post-seed emission for "no follows" users.
      // When the user follows nobody, _emitFollowingList() never fires
      // because the list stays [] which equals the previous value.
      // With null seed, this force-emit of [] will always be distinct.
      if (_followingPubkeys.isEmpty && !_followingSubject.isClosed) {
        _followingSubject.add(const []);
      }
    } catch (e) {
      Log.error(
        'FollowRepository initialization error: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Follow a user.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if [pubkey] is not a 32-byte hex pubkey.
  /// * [Exception] if the user is not authenticated.
  /// * Anything the Kind 3 publish or the local-storage write threw, after
  ///   rolling the optimistic update back.
  Future<void> follow(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      Log.error(
        'Cannot follow - user not authenticated',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    // Guard: keep invalid keys out of the list rather than letting them fail
    // the Kind 3 publish later, which would block every subsequent follow.
    if (!keyIsValid(pubkey)) {
      Log.error(
        'Cannot follow - invalid pubkey: ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw ArgumentError.value(pubkey, 'pubkey', 'Invalid key');
    }

    // Guard: Prevent following self
    if (pubkey == _nostrClient.publicKey) {
      Log.warning(
        'Attempted to follow self - ignoring',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (_followingPubkeys.contains(pubkey)) {
      Log.debug(
        'Already following user: ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(
      'Following user: ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // 1. Update in-memory cache immediately
    _followingPubkeys = [..._followingPubkeys, pubkey];
    _emitFollowingList();
    await _invalidateMyFollowingCache();

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(isFollow: true, pubkey: pubkey);

      // Save to local storage for persistence
      await _saveToLocalStorage();

      Log.info(
        'Queued follow action for offline sync: '
        '${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // 2. Broadcast to network
      await _broadcastContactList();

      // 3. Save to local storage
      await _saveToLocalStorage();

      Log.info(
        'Successfully followed user: ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    } catch (e) {
      // Roll back this follow only. Restoring a whole pre-follow snapshot
      // would also throw away a newer contact list the pre-publish read
      // adopted, putting the stale list back (#8266).
      _followingPubkeys = _followingPubkeys.where((p) => p != pubkey).toList();
      _emitFollowingList();

      Log.error(
        'Error following user: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Execute a follow action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly broadcasts to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<void> executeFollowAction(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      throw Exception('User not authenticated');
    }

    // Ensure pubkey is in the list (it should be from optimistic update)
    if (!_followingPubkeys.contains(pubkey)) {
      _followingPubkeys = [..._followingPubkeys, pubkey];
      _emitFollowingList();
    }
    await _invalidateMyFollowingCache();

    // Broadcast to network
    await _broadcastContactList();

    // Save to local storage
    await _saveToLocalStorage();

    Log.info(
      'Executed follow action for: ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Unfollow a user
  Future<void> unfollow(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      Log.error(
        'Cannot unfollow - user not authenticated',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      throw Exception('User not authenticated');
    }

    // Guard: Prevent unfollowing self
    if (pubkey == _nostrClient.publicKey) {
      Log.warning(
        'Attempted to unfollow self - ignoring',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (!_followingPubkeys.contains(pubkey)) {
      Log.debug(
        'Not following user: ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(
      'Unfollowing user: ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // 1. Update in-memory cache immediately
    _followingPubkeys = _followingPubkeys.where((p) => p != pubkey).toList();
    _emitFollowingList();
    await _invalidateMyFollowingCache();

    // Check if offline and queue if needed
    if (_isOnline != null && !_isOnline() && _queueOfflineAction != null) {
      await _queueOfflineAction(isFollow: false, pubkey: pubkey);

      // Save to local storage for persistence
      await _saveToLocalStorage();

      Log.info(
        'Queued unfollow action for offline sync: '
        '${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // 2. Broadcast to network
      await _broadcastContactList();

      // 3. Save to local storage
      await _saveToLocalStorage();

      Log.info(
        'Successfully unfollowed user: ${pubkeyForLogs(pubkey)}',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    } catch (e) {
      // Roll back this unfollow only, for the same reason as [follow].
      if (!_followingPubkeys.contains(pubkey)) {
        _followingPubkeys = [..._followingPubkeys, pubkey];
      }
      _emitFollowingList();

      Log.error(
        'Error unfollowing user: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Execute an unfollow action directly (for use by sync service).
  ///
  /// This method bypasses offline queuing and directly broadcasts to relays.
  /// Used by PendingActionService to execute queued actions.
  Future<void> executeUnfollowAction(String pubkey) async {
    if (!_nostrClient.hasKeys) {
      throw Exception('User not authenticated');
    }

    // Ensure pubkey is removed from the list (it should be from optimistic update)
    if (_followingPubkeys.contains(pubkey)) {
      _followingPubkeys = _followingPubkeys.where((p) => p != pubkey).toList();
      _emitFollowingList();
    }
    await _invalidateMyFollowingCache();

    // Broadcast to network
    await _broadcastContactList();

    // Save to local storage
    await _saveToLocalStorage();

    Log.info(
      'Executed unfollow action for: ${pubkeyForLogs(pubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Load following list from local storage (SharedPreferences).
  ///
  /// Reads both schema versions: a bare JSON array is the pre-#8266 v1 record
  /// and yields no timestamp, so it seeds the list but loses to the first
  /// source that can name one.
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;

      final cached = prefs.getString(
        FollowingCacheRecord.storageKey(currentUserPubkey),
      );
      if (cached == null) return;

      final record = FollowingCacheRecord.decode(cached);
      final cachedPubkeys = record.pubkeys;
      final sanitizedPubkeys = _sanitizePubkeys(
        cachedPubkeys,
        source: 'LocalStorage',
      );

      _adoptContactList(
        sanitizedPubkeys,
        createdAt: record.createdAt,
        eventId: record.eventId,
        source: record.needsMigration
            ? 'LocalStorage (legacy)'
            : 'LocalStorage',
      );

      // Rewrite when entries were dropped, and to migrate a v1 record onto the
      // versioned envelope so the next launch can order it.
      if (record.needsMigration ||
          sanitizedPubkeys.length != cachedPubkeys.length) {
        await _saveToLocalStorage();
      }
    } catch (e) {
      Log.error(
        'Failed to load following list from cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load from PersonalEventCache (Kind 3 events)
  Future<void> _loadFromPersonalEventCache() async {
    if (_isCacheInitialized?.call() != true) {
      return;
    }

    try {
      final cachedContactLists = _getCachedEventsByKind!(EventKind.contactList);
      if (cachedContactLists.isEmpty) return;

      // PersonalEventCache orders by `created_at` alone, so two kind 3s
      // written in the same second come back in an arbitrary order. Apply
      // NIP-01's full rule here rather than trusting `.first`.
      final latestContactList = cachedContactLists
          .where((event) => event.kind == EventKind.contactList)
          .fold<Event?>(null, _pickBestContactList);
      if (latestContactList == null) return;

      _rememberContactListEvent(latestContactList);
      _adoptContactList(
        _followsOf(latestContactList, source: 'PersonalEventCache'),
        createdAt: latestContactList.createdAt,
        eventId: latestContactList.id,
        source: 'PersonalEventCache',
      );
    } catch (e) {
      Log.error(
        'Failed to load from PersonalEventCache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Upper bound on REST bootstrap paging, mirroring the ceiling the old
  /// single `limit: 5000` request implied.
  static const _restFollowingMaxPubkeys = 5000;

  /// Load following list from REST API (funnelcake) for fast bootstrap.
  ///
  /// Called only when local cache and PersonalEventCache are both empty
  /// (e.g., first login or after identity change cleanup). This provides
  /// the following list before the WebSocket subscription can deliver it.
  ///
  /// The result is a fast first paint, never the last word: it comes from a
  /// derived index that lags, so [initialize] always follows it with the
  /// authoritative Kind 3 from the relay.
  Future<void> _loadFromRestApi() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;
      if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
        return;
      }

      Log.info(
        'Loading following list from REST API '
        '(cache was empty)',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      // The server clamps `limit` to 100 however much we ask for, so page on
      // `offset` instead of requesting one large batch. Asking for 5000 and
      // silently receiving 100 is what let a truncated list become the base
      // for the next publish (#6109).
      final collected = <String>[];
      while (collected.length < _restFollowingMaxPubkeys) {
        final page = await _funnelcakeApiClient.getFollowing(
          pubkey: currentUserPubkey,
          offset: collected.length,
        );

        if (page.pubkeys.isEmpty) break;
        collected.addAll(page.pubkeys);

        if (!page.hasMore && collected.length >= page.total) break;
      }

      final pubkeys = _sanitizePubkeys(collected, source: 'REST API');

      if (pubkeys.isNotEmpty) {
        // The REST index is derived from the kind 3 and carries no
        // `created_at` of its own, so it seeds an empty state and loses to
        // any real event (#8266).
        if (_adoptContactList(pubkeys, createdAt: null, source: 'REST API')) {
          // Persist to SharedPreferences so redirect logic can use it
          await _saveToLocalStorage();
        }
      } else {
        Log.debug(
          'REST API returned empty following list',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.warning(
        'Failed to load following from REST API '
        '(will rely on relay): $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Save following list to local storage
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _nostrClient.publicKey;

      if (currentUserPubkey.isNotEmpty) {
        final provenance = _followingProvenance;
        await prefs.setString(
          FollowingCacheRecord.storageKey(currentUserPubkey),
          FollowingCacheRecord(
            pubkeys: _followingPubkeys,
            createdAt: provenance?.createdAt,
            eventId: provenance?.id,
          ).encode(),
        );

        Log.debug(
          'Saved following list to cache: '
          '${_followingPubkeys.length} users '
          '(created_at ${provenance?.createdAt ?? 'unknown'})',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
      // coverage:ignore-start
    } catch (e) {
      Log.error(
        'Failed to save following list to cache: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    // coverage:ignore-end
  }

  /// Query relays for the user's kind 3 contact list.
  ///
  /// Uses [_queryContactList] to do a one-shot query with proper EOSE
  /// handling.
  /// Called on every authenticated initialization so the relay's
  /// authoritative event can supersede stale derived caches.
  Future<void> _loadFromRelay() async {
    try {
      final currentUserPubkey = _nostrClient.publicKey;
      if (currentUserPubkey.isEmpty) return;

      Log.info(
        'Querying relay for authoritative kind 3 contact list',
        name: 'FollowRepository',
        category: LogCategory.system,
      );

      // Query connected relays and indexer relays in parallel.
      // Connected relays may not have the contact list yet (relay discovery
      // runs in background and may not have completed), so also query indexer
      // relays directly as a fallback.
      final results = await Future.wait([
        _loadContactListFromConnectedRelays(currentUserPubkey),
        _loadContactListFromIndexer(currentUserPubkey),
      ]);

      // Use whichever returned a result, newest first (NIP-01).
      final connectedResult = results[0];
      final indexerResult = results[1];

      final event = _pickBestContactList(connectedResult, indexerResult);

      if (event != null) {
        _processContactListEvent(event);

        Log.info(
          'Loaded following from relay kind 3: '
          '${_followingPubkeys.length} users',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      } else {
        Log.debug(
          'No kind 3 contact list found on relay '
          '(user may genuinely follow nobody)',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
      // coverage:ignore-start
    } catch (e) {
      Log.warning(
        'Failed to load following from relay: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }
    // coverage:ignore-end
  }

  /// Query connected relays for kind 3 contact list.
  Future<Event?> _loadContactListFromConnectedRelays(String pubkey) async {
    try {
      final eventStream = _nostrClient.subscribe([
        Filter(
          authors: [pubkey],
          kinds: const [EventKind.contactList],
          limit: 1,
        ),
      ]);

      final event = await _queryContactList(
        eventStream: eventStream,
        pubkey: pubkey,
        fallbackTimeoutSeconds: 5,
      );
      return event;
    } catch (e) {
      Log.warning(
        'Connected relay contact list query '
        'failed: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Query indexer relays directly for the user's kind 3 contact list.
  ///
  /// Connected relays may not be ready yet (relay discovery runs in
  /// background), so this provides a reliable fallback via direct WebSocket.
  Future<Event?> _loadContactListFromIndexer(String pubkey) async {
    for (final indexerUrl in _indexerRelayUrls) {
      try {
        final event = await _queryIndexerForContactList(indexerUrl, pubkey);
        if (event != null) {
          Log.info(
            'Got contact list from indexer '
            '$indexerUrl',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
          return event;
        }
      } catch (e) {
        Log.warning(
          'Indexer $indexerUrl contact list query '
          'failed: $e',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      }
    }
    return null;
  }

  /// Query a single indexer relay for kind 3 via direct WebSocket.
  Future<Event?> _queryIndexerForContactList(
    String indexerUrl,
    String pubkey,
  ) async {
    final deadline = DateTime.now().add(_indexerOperationTimeout);
    final relayStatus = RelayStatus(indexerUrl);
    final relay = _relayFactory(indexerUrl, relayStatus);
    final completer = Completer<Event?>();
    final subscriptionId = 'cl_${DateTime.now().millisecondsSinceEpoch}';
    Event? bestEvent;

    relay.onMessage = (relay, jsonMsg) async {
      if (jsonMsg.isEmpty) return;

      final messageType = jsonMsg[0] as String;

      if (messageType == 'EVENT' && jsonMsg.length >= 3) {
        final eventJson = jsonMsg[2] as Map<String, dynamic>;
        try {
          final event = Event.fromJson(eventJson);
          if (bestEvent == null || event.createdAt > bestEvent!.createdAt) {
            bestEvent = event;
          }
        } catch (e) {
          Log.warning(
            'Failed to parse kind 3 event from '
            '$indexerUrl: $e',
            name: 'FollowRepository',
            category: LogCategory.system,
          );
        }
      } else if (messageType == 'EOSE') {
        if (!completer.isCompleted) {
          completer.complete(bestEvent);
        }
      }
    };

    try {
      final filter = <String, dynamic>{
        'kinds': <int>[EventKind.contactList],
        'authors': <String>[pubkey],
        'limit': 1,
      };
      relay.pendingMessages.add(<dynamic>['REQ', subscriptionId, filter]);

      final connected = await _awaitIndexerOperation<bool>(
        relay.connect(),
        deadline,
        onTimeout: () => false,
      );
      if (!connected) return null;

      final result = await _awaitIndexerOperation<Event?>(
        completer.future,
        deadline,
        cap: const Duration(seconds: 5),
        onTimeout: () => bestEvent,
      );

      await _awaitIndexerOperation<bool>(
        relay.send(<dynamic>['CLOSE', subscriptionId]),
        deadline,
        onTimeout: () => false,
      );
      return result;
    } catch (e) {
      Log.warning(
        'Error querying $indexerUrl for '
        'contact list: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return bestEvent;
    } finally {
      await _disconnectIndexer(relay, indexerUrl, deadline);
    }
  }

  /// Pick the authoritative contact list of two, per NIP-01's rule for
  /// replaceable events: newest `created_at`, lowest event id on a tie.
  Event? _pickBestContactList(Event? a, Event? b) {
    if (a == null) return b;
    if (b == null) return a;
    return _isNewer(b.createdAt, b.id, (createdAt: a.createdAt, id: a.id))
        ? b
        : a;
  }

  /// Subscribe to contact list for real-time sync and cross-device updates.
  ///
  /// Creates a long-running subscription to the current user's Kind 3 events.
  /// When a newer contact list arrives (from another device or this one),
  /// updates the local list.
  void _subscribeToContactList() {
    final currentUserPubkey = _nostrClient.publicKey;
    if (currentUserPubkey.isEmpty) return;

    Log.debug(
      'Subscribing to contact list for: '
      '${pubkeyForLogs(currentUserPubkey)}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );

    // Use a deterministic subscription ID so we can unsubscribe later
    _contactListSubscriptionId = 'follow_repo_contact_list_$currentUserPubkey';

    final eventStream = _nostrClient.subscribe([
      Filter(
        authors: [currentUserPubkey],
        kinds: const [EventKind.contactList],
        limit: 1,
      ),
    ], subscriptionId: _contactListSubscriptionId);

    _contactListSubscription = eventStream.listen(
      (event) {
        // Only process Kind 3 events from the current user
        if (event.kind == EventKind.contactList &&
            event.pubkey == currentUserPubkey) {
          _processContactListEvent(event);
        }
      },
      onError: (Object error) {
        Log.error(
          'Real-time contact list subscription '
          'error: $error',
          name: 'FollowRepository',
          category: LogCategory.system,
        );
      },
    );
  }

  /// Republish the contact list without changing who is followed.
  ///
  /// Blocking never runs through follow/unfollow, and nothing republishes
  /// kind 3 on a schedule, so a block that contradicts the follow list would
  /// otherwise sit on relays until the user's next unrelated follow — which
  /// may never come. The app layer calls this to settle that contradiction
  /// (#6903); the omission itself happens in [_publishableFollows].
  ///
  /// Throws if the user is not authenticated.
  Future<void> republishContactList() async {
    if (!_nostrClient.hasKeys) {
      throw Exception('User not authenticated');
    }
    await _broadcastContactList();
  }

  /// The follows to publish: [_followingPubkeys] minus the accounts the
  /// signing user has blocked.
  ///
  /// Blocking hides an account throughout the app, but leaving it in the
  /// published kind 3 tells every other client — and Divine's own public,
  /// unauthenticated follower APIs — that the user still follows them
  /// (#6903).
  ///
  /// The local list is deliberately **not** mutated here, so a block never
  /// costs the follow synchronously and unblocking re-includes it on the
  /// next publish.
  ///
  /// That is a publish-boundary property, not a durable one. The filtered
  /// event is what relays hold from then on, so the next [initialize] reads
  /// it back and [_processContactListEvent] replaces the local list with it
  /// — the newest event is adopted wholesale, so the filtered list stands.
  /// In practice the follow survives locally for the rest of the session
  /// that blocked, and is gone after the next launch. Whether it should be
  /// restorable at all is open with T&S (#6903).
  List<String> _publishableFollows() {
    final blocked = _blockedPubkeys?.call(_nostrClient.publicKey);
    if (blocked == null || blocked.isEmpty) return _followingPubkeys;

    final publishable = _followingPubkeys
        .where((pubkey) => !blocked.contains(pubkey))
        .toList();

    final omittedCount = _followingPubkeys.length - publishable.length;
    if (omittedCount > 0) {
      Log.info(
        'Omitting $omittedCount blocked pubkey(s) from the published '
        'contact list',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
    }

    return publishable;
  }

  /// How long the pre-broadcast read waits for every relay to settle.
  ///
  /// Deliberately shorter than the 5s default: an expiry reports `timedOut`,
  /// which withholds the broadcast, so erring short errs toward not
  /// overwriting. It also bounds what a follow tap costs.
  static const _contactListReadTimeout = Duration(seconds: 3);

  /// Re-read our own kind 3 and report whether the answer was conclusive.
  ///
  /// Returns `false` when no relay settled the query — a timeout, or a
  /// fan-out no relay took. That is not the same as "this account follows
  /// nobody", and the difference decides whether it is safe to replace the
  /// event: kind 3 is replaceable, so a broadcast built on an unread answer
  /// deletes whatever only the unread event held. A *settled* answer of zero
  /// events is conclusive and returns `true`, so a first-ever follow still
  /// publishes.
  ///
  /// [NostrClient.queryEvents] cannot express this — it drops `timedOut` and
  /// `noRelays` — which is why the detailed form is used, with
  /// `requireAllRelaysSettled` so a relay abandoned by the settle window
  /// arrives as a timeout rather than as an empty answer.
  Future<bool> _refreshCurrentUserContactList() async {
    final pubkey = _nostrClient.publicKey;
    if (pubkey.isEmpty) return false;

    final result = await _nostrClient.queryEventsDetailed(
      [
        Filter(authors: [pubkey], kinds: const [EventKind.contactList]),
      ],
      requireAllRelaysSettled: true,
      timeout: _contactListReadTimeout,
    );

    Event? newest;
    for (final event in result.events) {
      if (event.pubkey != pubkey) continue;
      if (event.kind != EventKind.contactList) continue;
      newest = _pickBestContactList(newest, event);
    }

    if (newest != null) {
      _rememberContactListEvent(newest);

      // Adopt what the relay holds as the base to publish from, then put the
      // pending local change back on top. Reading the authoritative event and
      // using it only for `content` is what let a stale hydration republish
      // follows the newest event had already dropped (#8266): the `p` tags
      // come from [_publishableFollows], not from this event.
      final pending = _pendingLocalChange();
      if (_adoptContactList(
        _followsOf(newest, source: 'pre-publish read'),
        createdAt: newest.createdAt,
        eventId: newest.id,
        source: 'pre-publish read',
      )) {
        _applyPendingLocalChange(pending);
      }
    }

    return !result.timedOut && !result.noRelays;
  }

  /// The local follow/unfollow not yet reflected in the adopted base.
  ({List<String> added, Set<String> removed}) _pendingLocalChange() {
    final adopted = _adoptedFollows.toSet();
    final current = _followingPubkeys.toSet();
    return (
      added: _followingPubkeys.where((p) => !adopted.contains(p)).toList(),
      removed: adopted.where((p) => !current.contains(p)).toSet(),
    );
  }

  /// Re-apply [pending] on top of a freshly adopted base.
  ///
  /// New follows go on the end, which is where NIP-02 asks clients to append
  /// them so the list stays in chronological order.
  void _applyPendingLocalChange(
    ({List<String> added, Set<String> removed}) pending,
  ) {
    if (pending.added.isEmpty && pending.removed.isEmpty) return;

    final rebased = [
      ..._followingPubkeys.where((p) => !pending.removed.contains(p)),
      ...pending.added.where((p) => !_followingPubkeys.contains(p)),
    ];
    if (rebased.length == _followingPubkeys.length &&
        rebased.indexed.every((e) => e.$2 == _followingPubkeys[e.$1])) {
      return;
    }

    _followingPubkeys = rebased;
    _emitFollowingList();

    Log.info(
      'Re-applied the pending local change over the newest contact list: '
      '${pending.added.length} added, ${pending.removed.length} removed, '
      'now ${rebased.length} following',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Rebroadcast a contact list whose publish was withheld by an inconclusive
  /// read.
  ///
  /// A no-op unless something is pending, so callers can fire it on any "we
  /// might be healthy again" signal. Follows and unfollows rebroadcast the
  /// whole list themselves, so this only matters for a user who followed once
  /// while relays were unhealthy and has not followed since.
  ///
  /// Returns whether the broadcast reached a relay. [_broadcastContactList]
  /// throws when the publish itself fails; this is a background retry with no
  /// caller to surface that to, so it is logged and reported as `false` rather
  /// than propagated. The pending flag stays set, so the next signal retries.
  Future<bool> retryPendingContactListBroadcast() async {
    if (!_contactListBroadcastPending) return false;
    try {
      await _broadcastContactList();
      return !_contactListBroadcastPending;
    } on Object catch (e) {
      Log.warning(
        'Retry of a withheld contact list broadcast failed: $e',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Broadcast updated contact list to network (Kind 3 event)
  Future<void> _broadcastContactList() async {
    // Last line of defence: [executeFollowAction] appends without validating,
    // and an invalid pubkey here makes Contact's constructor throw and abort
    // the publish, blocking every follow and unfollow until the entry is gone.
    // Emit so observers do not keep a dropped entry the getter no longer has.
    _followingPubkeys = _sanitizePubkeys(
      _followingPubkeys,
      source: 'in-memory following list',
    );
    _emitFollowingList();

    // Establish what the relay currently holds before replacing it. Without
    // this, a cold start publishes `content: ''` over whatever was there —
    // `_currentUserContactListEvent` is memory-only, and NIP-02 puts the
    // user's relay list in that field (#8265). The follow is already applied
    // locally and persisted, so withholding costs propagation, not the follow.
    if (!await _refreshCurrentUserContactList()) {
      _contactListBroadcastPending = true;
      Log.warning(
        'Withholding contact list broadcast - could not confirm the current '
        'kind 3. Follows stay local until a read succeeds.',
        name: 'FollowRepository',
        category: LogCategory.system,
      );
      return;
    }

    final contactList = ContactList();
    for (final pubkey in _publishableFollows()) {
      contactList.add(Contact(publicKey: pubkey));
    }

    // Preserve existing content from previous contact list event if available
    final content = _currentUserContactListEvent?.content ?? '';

    // Send the contact list via NostrClient (creates, signs, and broadcasts)
    final event = await _nostrClient.sendContactList(contactList, content);

    if (event == null) {
      throw Exception('Failed to broadcast contact list');
    }

    // Cache the contact list event
    _cacheUserEvent?.call(event);

    _currentUserContactListEvent = event;
    // The event we just published is now the newest one we know of, and its
    // tags are the new base for the next pending-change diff.
    _followingProvenance = (createdAt: event.createdAt, id: event.id);
    _adoptedFollows = List<String>.from(_followingPubkeys);
    _contactListBroadcastPending = false;

    Log.debug(
      'Broadcasted contact list: ${event.id}',
      name: 'FollowRepository',
      category: LogCategory.system,
    );
  }

  /// Process a NIP-02 contact list event (Kind 3).
  ///
  /// Kind 3 is replaceable, so the newest event is the whole truth: whatever
  /// it omits, the user removed. There is deliberately no size check here.
  /// The union-merge that used to guard against a "drastically smaller" remote
  /// list could not tell a buggy client apart from a real cross-device edit —
  /// unfollowing several people and following one produces exactly the
  /// fingerprint it looked for — and it re-broadcast the union, publishing the
  /// resurrected follows back to the relay (#8266).
  void _processContactListEvent(Event event) {
    final adopted = _adoptContactList(
      _followsOf(event, source: 'network Kind 3 event ${event.id}'),
      createdAt: event.createdAt,
      eventId: event.id,
      source: 'network Kind 3 event ${event.id}',
    );
    _rememberContactListEvent(event);
    if (!adopted) return;

    unawaited(_saveToLocalStorage());
    unawaited(_invalidateMyFollowingCache());
  }
}
