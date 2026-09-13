// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws typed ProfileRepositoryException subclasses on publish
// ABOUTME: failure.

import 'dart:async';
import 'dart:convert';

// Hide Drift table class to avoid collision with ProfileStats domain model.
import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter, Nip19;
import 'package:profile_repository/profile_repository.dart';
import 'package:profile_repository/src/identity_event_selection.dart';
import 'package:unified_logger/unified_logger.dart';

// TODO(e2e): Add divine-name-server to local_stack Docker dependencies
// so username check/claim flows can be tested against it in E2E tests.
// Tracked by #7692.

// How long a Divine-identity determination is trusted before re-querying.
//
// Kept equal to ModerationLabelService._resolvedPubkeyTtl (24h) so the app
// has one consistent "how long a NIP-05-derived identity is trusted" window.
//
// Trust posture note (#4948): this reverse lookup rides the same unpinned
// name-server HTTPS surface as the moderation-identity NIP-05 resolution.
// That issue owns the pin-vs-NIP-05 decision for that surface; this feature
// aligns to whatever #4948 lands on rather than making an independent call.
// Stakes here are lower (a compromise inflates community vote counts /
// surfaces a false content warning, mitigated by "View Anyway"), not the
// redirection of report DMs #4948 is primarily concerned with.
const _divineIdentityCacheTtl = Duration(hours: 24);

// Caps name-server HTTP calls so a slow or unreachable endpoint surfaces a
// fast UsernameClaimError / UsernameCheckError instead of waiting on the
// platform's TCP timeout (~20s on Android).
const _nameServerHttpTimeout = Duration(seconds: 10);

// Caps the relay seed fetch in saveProfileEvent so a slow relay does not
// stall Save indefinitely. On timeout we fall back to currentProfile,
// which still carries the typed REST fields after #4175.
const _publishSeedRelayTimeout = Duration(seconds: 4);

// Caps NIP-50 user search. The relay query has a slightly shorter inner
// budget and returns partial results on SDK timeout; the outer guard is a
// repository safety net for stalls before the SDK budget starts.
const _nip50SearchTimeout = Duration(seconds: 5);
const _nip50RelayQueryTimeout = Duration(milliseconds: 4500);

/// Sort key for profile searches ordered by follower count.
const String profileSearchSortFollowers =
    FunnelcakeApiClient.profileSortFollowers;

// TODO(search): Move ProfileSearchFilter to a shared package
// (e.g., search_utils) when we need to reuse search logic across
// multiple repositories.
/// Callback to filter and sort profiles by search relevance.
/// Takes a query and list of profiles, returns filtered/sorted profiles.
typedef ProfileSearchFilter =
    List<UserProfile> Function(String query, List<UserProfile> profiles);

bool _isSearchCancelled(SearchCancellationToken? token) =>
    token?.isCancelled ?? false;

/// Bounded local identity lookup used by interactive people discovery.
typedef LocalProfileSearch =
    Future<List<UserProfile>> Function(String query, int limit);

/// Default indexer relays for kind 0 profile lookups.
///
/// Production wiring overrides this via
/// `EnvironmentConfig.indexerRelays`. Keep this fallback
/// in sync with the environment defaults so non-app
/// construction paths behave the same way.
const defaultProfileIndexerRelays = [
  'wss://purplepag.es',
  'wss://user.kindpag.es',
  'wss://relay.nos.social',
];

/// Origin of the divine-name-server that owns `@divine.video` usernames.
///
/// Production wiring overrides this via
/// `EnvironmentConfig.nameServerBaseUrl`. There is no staging deployment of
/// divine-name-server today, so every environment resolves to this host; the
/// parameter exists so tests can substitute a fake.
const defaultNameServerBaseUrl = 'https://names.divine.video';

/// Keycast NIP-05 document consulted as a second username-availability
/// source.
///
/// Production wiring overrides this via `OAuthConfig.nip05Url`, which follows
/// the environment's Keycast origin. Keycast keys its username namespace on
/// the request Host, so this must name the same tenant the app signs in
/// against or availability answers describe a different registry.
const defaultKeycastNip05Url =
    'https://login.divine.video/.well-known/nostr.json';

/// Canonicalizes an injected endpoint, then strips a trailing separator.
///
/// Both steps are load-bearing, and the order matters.
///
/// `Uri.parse` normalizes exactly the way the wire URL and the name server
/// do — it lowercases the host, drops a default port, and resolves dot
/// segments. Without it, a non-canonical injected base makes the NIP-98 `u`
/// tag (signed from this string verbatim) differ from the request URL
/// (built via `Uri.parse`), and the server compares them as raw strings, so
/// every claim and release 401s while the unauthenticated `/check` keeps
/// working.
///
/// Stripping runs afterwards because canonicalization can reintroduce a
/// trailing slash (`https://x/.` becomes `https://x/`), and `'$base/name'`
/// on a base ending in `/` yields `//name`, which the origin routes to a
/// 404 rather than the intended handler.
String _normalizeEndpoint(String url) {
  final canonical = Uri.parse(url).toString();
  return canonical.endsWith('/')
      ? canonical.substring(0, canonical.length - 1)
      : canonical;
}

/// Repository for fetching and publishing user profiles (Kind 0 metadata).
class ProfileRepository implements ProfileReader {
  /// Creates a new profile repository.
  ProfileRepository({
    required NostrClient nostrClient,
    required UserProfilesDao userProfilesDao,
    required Client httpClient,
    ProfileStatsDao? profileStatsDao,
    FunnelcakeApiClient? funnelcakeApiClient,
    ProfileSearchFilter? profileSearchFilter,
    LocalProfileSearch? localProfileSearch,
    BlockedProfileFilter? blockFilter,
    PendingProfileSavesDao? pendingProfileSavesDao,
    IdentityEventsDao? identityEventsDao,
    VanishedProfilesDao? vanishedProfilesDao,
    List<String> indexerRelays = defaultProfileIndexerRelays,
    String nameServerBaseUrl = defaultNameServerBaseUrl,
    String keycastNip05Url = defaultKeycastNip05Url,
  }) : _nameServerBaseUrl = _normalizeEndpoint(nameServerBaseUrl),
       _keycastNip05Url = _normalizeEndpoint(keycastNip05Url),
       _nostrClient = nostrClient,
       _userProfilesDao = userProfilesDao,
       _httpClient = httpClient,
       _profileStatsDao = profileStatsDao,
       _funnelcakeApiClient = funnelcakeApiClient,
       _profileSearchFilter = profileSearchFilter,
       _localProfileSearch = localProfileSearch,
       _blockFilter = blockFilter,
       _pendingProfileSavesDao = pendingProfileSavesDao,
       _identityEventsDao = identityEventsDao,
       _vanishedProfilesDao = vanishedProfilesDao,
       _indexerRelays = indexerRelays;

  /// Event kind carrying NIP-39 identity claims since the 2026-02 spec
  /// revision (nostr-protocol/nips#2216). Kind-0 `i` tags are the legacy
  /// fallback for pre-migration profiles.
  static const int identityEventKind = 10011;

  final NostrClient _nostrClient;
  final UserProfilesDao _userProfilesDao;
  final Client _httpClient;
  final ProfileStatsDao? _profileStatsDao;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final ProfileSearchFilter? _profileSearchFilter;
  final LocalProfileSearch? _localProfileSearch;
  final BlockedProfileFilter? _blockFilter;

  /// Durable single-row-per-user slot for a save whose kind-0 publish is not
  /// yet relay-confirmed (#3161). Null when the caller does not wire the
  /// offline-tolerant save path (e.g. legacy tests) — the queue methods
  /// no-op in that case.
  final PendingProfileSavesDao? _pendingProfileSavesDao;

  /// Cache of the NIP-39 identity-claims source (`i` tags) per profile
  /// (#3936). Null when the caller does not wire the identity cache — the
  /// identity-tag methods then skip persistence and fall through to the
  /// kind-0 tags.
  final IdentityEventsDao? _identityEventsDao;

  /// Durable record of accounts that requested NIP-62 deletion. Null when the
  /// caller does not wire it — the vanish handling then degrades to
  /// session-scoped, which still evicts but does not survive a restart.
  final VanishedProfilesDao? _vanishedProfilesDao;

  final List<String> _indexerRelays;

  final String _nameServerBaseUrl;
  final String _keycastNip05Url;

  /// NIP-98 signs the absolute request URL and the server compares it by
  /// exact string equality, so these getters are the single source for both
  /// the signed string and the requested string. Never rebuild either at a
  /// call site.
  String get _usernameClaimUrl => '$_nameServerBaseUrl/api/username/claim';

  String get _usernameCheckUrl => '$_nameServerBaseUrl/api/username/check';

  String get _usernameByPubkeyUrl =>
      '$_nameServerBaseUrl/api/username/by-pubkey';

  /// In-flight relay fetches keyed by pubkey. Concurrent callers for the
  /// same pubkey share the same future instead of firing duplicate requests.
  final _inFlightFetches = <String, Future<UserProfile?>>{};

  /// Pubkeys confirmed to have no Kind 0 profile by an authoritative source.
  /// Session-scoped — cleared on app restart.
  final _confirmedMissing = <String>{};

  /// Pubkeys whose raw relay/indexer Kind 0 was not found after an explicit
  /// raw-Kind-0 fetch. This is narrower than [_confirmedMissing]: Funnelcake
  /// may still have a REST projection for the user, but there is no raw Kind 0
  /// to recover fields that REST strips.
  final _rawKind0ConfirmedMissing = <String>{};

  /// In-memory set of pubkeys known to have cached profiles.
  /// Enables synchronous [hasProfile] checks for subscription
  /// manager filtering.
  final _knownCached = <String>{};

  /// Pubkeys with a NIP-62 request to vanish, mirroring the durable
  /// `vanished_profiles` table. Kept in memory so [isVanished] can answer
  /// synchronously and so the write paths can reject a resurrected profile
  /// without an await.
  final _vanished = <String>{};

  /// Pubkeys already re-checked for a vanish this session. Bounds
  /// [revalidateVanishOnce] to one request per pubkey per session.
  final _vanishRevalidated = <String>{};

  /// Cache of Divine-identity determinations keyed by lowercase pubkey,
  /// with the timestamp of the lookup. Entries expire after
  /// [_divineIdentityCacheTtl]. Bounded to [_divineIdentityCacheMax] entries
  /// (oldest-inserted evicted first) so a long session can't grow it without
  /// limit.
  final _divineIdentityCache = <String, ({bool value, DateTime at})>{};

  /// Maximum number of cached Divine-identity determinations.
  static const _divineIdentityCacheMax = 500;

  /// Searches cached profiles from local storage only.
  ///
  /// This avoids remote work and is suitable for lightweight tab counts
  /// or instant local-first suggestions.
  Future<List<UserProfile>> searchUsersLocally({
    required String query,
    int? limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cachedProfiles = await _userProfilesDao.getAllProfiles();

    final filtered = _profileSearchFilter != null
        ? _profileSearchFilter(trimmed, cachedProfiles)
        : cachedProfiles.where((profile) {
            final queryLower = trimmed.toLowerCase();
            return profile.bestDisplayName.toLowerCase().contains(queryLower) ||
                (profile.about?.toLowerCase().contains(queryLower) ?? false);
          }).toList();

    final blockFilter = _blockFilter;
    final unblocked = blockFilter == null
        ? filtered
        : filtered.where((p) => !blockFilter(p.pubkey)).toList();

    if (limit != null && unblocked.length > limit) {
      return unblocked.sublist(0, limit);
    }

    return unblocked;
  }

  /// Counts cached profiles matching [query] without performing remote search.
  Future<int> countUsersLocally({required String query}) async {
    final matches = await searchUsersLocally(query: query);
    return matches.length;
  }

  Future<List<UserProfile>> _searchUsersForDiscovery({
    required String query,
    required int limit,
  }) async {
    final localSearch = _localProfileSearch;
    if (localSearch == null) {
      return searchUsersLocally(query: query, limit: limit);
    }
    final candidates = await localSearch(_localSearchTerm(query), limit);
    return _profileSearchFilter?.call(query, candidates) ?? candidates;
  }

  /// Translates a full `npub` query into the hex form the bounded local
  /// identity search matches on.
  ///
  /// The DAO search matches the stored `pubkey` column on hex only, so an
  /// `npub` query would otherwise return no local candidates even when the
  /// account is cached. A partial `npub` prefix cannot be decoded and is
  /// left for the raw-query path.
  static String _localSearchTerm(String query) =>
      _npubQueryToHex(query) ?? query;

  /// Whether the given pubkey is known to have no Kind 0 profile.
  ///
  /// Empty relay results are indeterminate because timeout and participation
  /// details are not preserved by the current relay query API.
  @override
  bool isConfirmedMissing(String pubkey) => _confirmedMissing.contains(pubkey);

  /// Synchronous check for whether a profile is cached.
  ///
  /// Returns `true` if the pubkey was previously fetched and cached in
  /// this session. Used by the subscription manager to skip redundant
  /// Kind 0 relay requests.
  ///
  /// Call [loadKnownCachedPubkeys] once at startup to pre-populate.
  bool hasProfile(String pubkey) => _knownCached.contains(pubkey);

  /// Pre-loads the in-memory [_knownCached] set from all profiles
  /// currently in the Drift cache. Call once after construction.
  Future<void> loadKnownCachedPubkeys() async {
    final all = await _userProfilesDao.getAllProfiles();
    _knownCached.addAll(all.map((p) => p.pubkey));
  }

  /// Whether the account behind [pubkey] has requested NIP-62 deletion.
  ///
  /// Synchronous so callers can gate a render without an await. Backed by the
  /// durable `vanished_profiles` table via [loadVanishedPubkeys], so a cold
  /// start on a deleted account resolves without a network round trip.
  bool isVanished(String pubkey) => _vanished.contains(pubkey);

  /// Pre-loads the in-memory vanished set from the durable table.
  ///
  /// Call once after construction, unconditionally — the write-path guards in
  /// [cacheProfile] depend on it, and a cache warm-up is not the only thing
  /// that can resurrect a profile.
  Future<void> loadVanishedPubkeys() async {
    final dao = _vanishedProfilesDao;
    if (dao == null) return;
    _vanished.addAll(await dao.getAllPubkeys());
  }

  /// Live view of the durable `vanished_profiles` table.
  ///
  /// The same source the inbox row reads through `profileVanishedProvider`,
  /// and deliberately not [isVanished]: that mirror is seeded by an unawaited
  /// [loadVanishedPubkeys], so until it resolves it is a strict subset of the
  /// table and a consumer sampling it names an account the row contradicts.
  ///
  /// Emits an empty set when no [VanishedProfilesDao] is wired, matching
  /// [isVanished]'s behaviour in the same configuration.
  Stream<Set<String>> watchVanishedPubkeys() {
    final dao = _vanishedProfilesDao;
    if (dao == null) return Stream.value(const <String>{});
    return dao.watchAllPubkeys().map(Set<String>.from);
  }

  /// Evicts the local profile, stats, identity-claims and Divine-identity
  /// entries for an account that requested deletion, and records the pubkey
  /// durably so the eviction survives a restart.
  ///
  /// Deliberately routed through [deleteCachedProfile] rather than folding a
  /// flag into it: that method's contract is "a local eviction does not prove
  /// remote absence", which is the opposite of what a vanish means.
  ///
  /// The raw kind 0 stays in `nostr_events`. Nothing renders a profile from
  /// there — every read path goes through `user_profiles` — so it is not a
  /// surface the account can reappear on.
  Future<void> _applyVanish(String pubkey) async {
    _vanished.add(pubkey);
    _confirmedMissing.add(pubkey);
    // This response *is* this session's re-check. Without it the next
    // [fetchFreshProfile] would immediately spend a second request to be told
    // the same thing; recovery from a wrong `has_vanish_request: true` +
    // null-profile classification rides on the next session instead, which
    // every session performs exactly once.
    _vanishRevalidated.add(pubkey);
    // Load-bearing: stops the raw-Kind-0 retry ladder from re-querying relays
    // for a profile that is never coming back.
    _rawKind0ConfirmedMissing.add(pubkey);
    _divineIdentityCache.remove(pubkey.trim().toLowerCase());

    await _vanishedProfilesDao?.markVanished(pubkey);
    await deleteCachedProfile(pubkey: pubkey);
    await _profileStatsDao?.deleteStats(pubkey);
    await _identityEventsDao?.deleteEvent(pubkey);
  }

  /// Forgets a previously recorded vanish.
  ///
  /// Called whenever the server reports the account as live again, so a wrong
  /// `has_vanish_request: true` classification is recoverable instead of
  /// erasing the account from this device permanently.
  ///
  /// Deliberately **not** gated on [_vanished]. That set is one mirror per
  /// repository instance, hydrated asynchronously, of a table every instance
  /// shares, so a miss does not prove the row is absent. Trusting one would
  /// strand the tombstone, and [UserProfilesDao] would then drop every re-cache
  /// while [cacheProfile] had already claimed the pubkey in [_knownCached] —
  /// leaving [hasProfile] asserting a row that does not exist. A delete
  /// matching nothing dirties no page; that disagreement is costlier.
  Future<void> _clearVanish(String pubkey) async {
    _vanished.remove(pubkey);
    _rawKind0ConfirmedMissing.remove(pubkey);
    await _vanishedProfilesDao?.clearVanished(pubkey);
  }

  /// Fires at most one background profile re-check per pubkey per session, for
  /// the read path that never otherwise reaches the network: an
  /// already-vanished pubkey, which [fetchFreshProfile] and
  /// [fetchBatchProfiles] both answer from the durable marker. This is
  /// therefore the only channel that can clear a wrong
  /// `has_vanish_request: true` + null-profile classification, and it runs
  /// once in *every* session. That includes after a restart, so recovery is
  /// not limited to the session that recorded the vanish.
  ///
  /// Deliberately calls the unguarded fetch: the guarded entry point would
  /// bounce straight back here for a vanished pubkey.
  ///
  /// The session set is load-bearing rather than an optimisation. The callers
  /// sit behind `autoDispose` providers, so they re-run every time a row
  /// scrolls back into view; without the set an inbox scroll would fire one
  /// request per row per scroll. `UserProfile` carries no fetch timestamp, so
  /// once-per-session is the tightest bound available without widening the
  /// model.
  void revalidateVanishOnce(String pubkey) {
    if (!_vanishRevalidated.add(pubkey)) return;
    unawaited(
      _fetchFreshProfileUnguarded(
        pubkey: pubkey,
      ).catchError((Object _, StackTrace _) => null),
    );
  }

  /// Returns the cached profile from local storage (SQLite) only.
  ///
  /// Does NOT fetch from Nostr relays. Use this for immediate UI display
  /// while [fetchFreshProfile] runs in parallel.
  ///
  /// Returns `null` if no cached profile exists for the given pubkey.
  @override
  Future<UserProfile?> getCachedProfile({required String pubkey}) async {
    return _userProfilesDao.getProfile(pubkey);
  }

  /// Returns the cached profiles for [pubkeys] in a single query.
  ///
  /// The batch counterpart to [getCachedProfile]: same local-storage-only
  /// semantics, but one `WHERE pubkey IN (...)` round trip instead of one per
  /// pubkey. Callers resolving a whole list (follow lists, pickers) should use
  /// this — the per-pubkey variant costs a Drift round trip each.
  ///
  /// Pubkeys without a cached profile, or profiles filtered by this
  /// repository's block policy, are absent from the result. The returned list
  /// may be shorter than [pubkeys] and is not order-aligned with it.
  @override
  Future<List<UserProfile>> getCachedProfiles({
    required List<String> pubkeys,
  }) async {
    if (pubkeys.isEmpty) return const [];
    final profiles = await _userProfilesDao.getProfilesByPubkeys(pubkeys);
    final blockFilter = _blockFilter;
    if (blockFilter == null) return profiles;
    return profiles.where((p) => !blockFilter(p.pubkey)).toList();
  }

  /// Persists a profile to local storage (SQLite).
  ///
  /// Use this to cache profiles obtained from relay events or REST APIs.
  /// If a profile with the same pubkey already exists, it is updated.
  /// Also clears the pubkey from the confirmed-missing set and adds
  /// it to the known-cached set.
  ///
  /// No-ops for an account that requested deletion. This is the fast path
  /// only — relay ingestion (`EventRouter`) and the classic-viner seed import
  /// write straight to the DAO, so the authoritative guard is the tombstone
  /// check in [UserProfilesDao.upsertProfile]. Short-circuiting here also keeps
  /// a vanished pubkey out of [_knownCached], which the DAO cannot do.
  Future<void> cacheProfile(UserProfile profile) {
    if (_vanished.contains(profile.pubkey)) return Future.value();
    _confirmedMissing.remove(profile.pubkey);
    if (!profile.isRestProjection) {
      _rawKind0ConfirmedMissing.remove(profile.pubkey);
    }
    _knownCached.add(profile.pubkey);
    return _userProfilesDao.upsertProfile(profile);
  }

  /// Deletes a cached profile from local storage.
  ///
  /// Returns the number of rows deleted (0 or 1). On a successful delete
  /// (rows > 0), also removes the pubkey from the in-memory known-cached
  /// set so [hasProfile] returns `false` for the rest of the session.
  /// Does not add the pubkey to the confirmed-missing set — a local
  /// eviction does not prove remote absence.
  Future<int> deleteCachedProfile({required String pubkey}) async {
    final rowsAffected = await _userProfilesDao.deleteProfile(pubkey);
    if (rowsAffected > 0) {
      _knownCached.remove(pubkey);
    }
    return rowsAffected;
  }

  /// Returns all cached profiles from local storage.
  ///
  /// Used for bulk-loading profiles into memory on startup.
  Future<List<UserProfile>> getAllCachedProfiles() {
    return _userProfilesDao.getAllProfiles();
  }

  /// Watches a profile by pubkey, emitting updates from local storage.
  ///
  /// Returns a stream that emits the current [UserProfile] whenever the
  /// cached profile changes (insert, update, or delete). Emits `null` if
  /// no cached profile exists for the given pubkey.
  ///
  /// Use this for reactive UI updates (e.g., BlocBuilder subscriptions).
  /// Pair with [fetchFreshProfile] to trigger relay fetches that write
  /// back to the cache and automatically flow through this stream.
  @override
  Stream<UserProfile?> watchProfile({required String pubkey}) {
    return _userProfilesDao.watchProfile(pubkey);
  }

  /// Returns the cached NIP-39 `i` tag list for [pubkey] from local storage.
  ///
  /// Does NOT hit the network. Returns `null` when no identity source has
  /// been cached yet, when the cached row is corrupt, or when no
  /// [IdentityEventsDao] is wired. Use for instant chip rendering while
  /// [freshIdentityTags] runs (#3936).
  @override
  Future<List<List<String>>?> cachedIdentityTags(String pubkey) async {
    final dao = _identityEventsDao;
    if (dao == null) return null;
    final row = await dao.getEvent(pubkey);
    if (row == null) return null;
    return _decodeIdentityTags(row.tagsJson);
  }

  /// Fetches the freshest NIP-39 identity-claims source for [pubkey] and
  /// returns its `i` tags, updating the local cache.
  ///
  /// Consult order mirrors the verifier web UI
  /// (divine-identify-verification-service): a live kind-10011 relay query
  /// wins; when none is found, a previously cached kind-10011 row wins over
  /// the kind-0 fallback so a transient relay miss never downgrades the
  /// source; otherwise the caller-provided kind-0 [kind0Tags] are used and
  /// cached so cold starts can render claims for pre-migration profiles.
  ///
  /// A live event that is an older revision than the cached row loses to it:
  /// kind 10011 is replaceable, so a relay serving a superseded event is
  /// behind rather than authoritative. Letting it overwrite the row would
  /// both flip the rendered chips back and erase what the write path checks
  /// a publish base against (#7081).
  ///
  /// Never throws — relay failures fall through the consult order, and
  /// cache reads/writes are best-effort so a local persistence failure
  /// never discards tags already in hand.
  @override
  Future<List<List<String>>> freshIdentityTags({
    required String pubkey,
    required List<List<String>> kind0Tags,
  }) async {
    final dao = _identityEventsDao;
    final live = await _fetchIdentityEvent(pubkey);
    if (live != null) {
      final superseding = await _cachedTagsSuperseding(pubkey, live);
      if (superseding != null) return superseding;
      final iTags = identityTagsOf(live.tags);
      await _cacheIdentityTags(
        pubkey,
        iTags,
        identityEventKind,
        sourceCreatedAt: live.createdAt,
        sourceEventId: live.id,
      );
      return iTags;
    }

    var cacheReadFailed = false;
    if (dao != null) {
      try {
        final cachedRow = await dao.getEvent(pubkey);
        if (cachedRow != null && cachedRow.sourceKind == identityEventKind) {
          final cachedTags = _decodeIdentityTags(cachedRow.tagsJson);
          if (cachedTags != null) return cachedTags;
        }
      } on Exception catch (e) {
        cacheReadFailed = true;
        Log.warning(
          'Identity-tags cache read failed for ${pubkeyForLogs(pubkey)}: $e',
          name: 'ProfileRepository',
        );
      }
    }

    final kind0ITags = identityTagsOf(kind0Tags);
    // When the cached row could not be read, skip the fallback write — a
    // blind upsert here could downgrade a valid but unreadable-this-tick
    // kind-10011 row to a kind-0 source.
    if (!cacheReadFailed) {
      await _cacheIdentityTags(pubkey, kind0ITags, 0);
    }
    return kind0ITags;
  }

  /// The cached `i` tags when the row mirrors an identity event that
  /// supersedes [live], or null when [live] is the one to keep.
  ///
  /// Null is also the answer when the row carries no source event — a kind-0
  /// fallback row, or one written before those columns existed. There is
  /// nothing to compare against there, and a live kind-10011 event is the
  /// better source in both cases.
  Future<List<List<String>>?> _cachedTagsSuperseding(
    String pubkey,
    Event live,
  ) async {
    final dao = _identityEventsDao;
    if (dao == null) return null;
    try {
      final row = await dao.getEvent(pubkey);
      final cachedCreatedAt = row?.sourceCreatedAt;
      final cachedId = row?.sourceEventId;
      if (row == null || cachedCreatedAt == null || cachedId == null) {
        return null;
      }
      if (compareIdentityEvents(
            createdAt: live.createdAt,
            id: live.id,
            otherCreatedAt: cachedCreatedAt,
            otherId: cachedId,
          ) >=
          0) {
        return null;
      }
      final cachedTags = _decodeIdentityTags(row.tagsJson);
      if (cachedTags == null) return null;
      Log.warning(
        'Kind-$identityEventKind read for ${pubkeyForLogs(pubkey)} (created_at '
        '${live.createdAt}) is superseded by the cached event (created_at '
        '$cachedCreatedAt); keeping the cached claims',
        name: 'ProfileRepository',
      );
      return cachedTags;
    } on Exception catch (e) {
      Log.warning(
        'Identity-tags cache read failed for ${pubkeyForLogs(pubkey)}: $e',
        name: 'ProfileRepository',
      );
      return null;
    }
  }

  /// Best-effort persistence of the identity-claims source cache — a
  /// failed write is logged and swallowed so [freshIdentityTags] can
  /// still return the tags it already fetched.
  ///
  /// [sourceCreatedAt] and [sourceEventId] identify the kind-10011 event
  /// [iTags] came from; the kind-0 fallback passes neither, which clears any
  /// coordinates left on the row so they cannot outlive the tags they
  /// described.
  Future<void> _cacheIdentityTags(
    String pubkey,
    List<List<String>> iTags,
    int sourceKind, {
    int? sourceCreatedAt,
    String? sourceEventId,
  }) async {
    try {
      await _identityEventsDao?.upsertEvent(
        pubkey: pubkey,
        tagsJson: jsonEncode(iTags),
        sourceKind: sourceKind,
        sourceCreatedAt: sourceCreatedAt,
        sourceEventId: sourceEventId,
      );
    } on Exception catch (e) {
      Log.warning(
        'Identity-tags cache write failed for ${pubkeyForLogs(pubkey)}: $e',
        name: 'ProfileRepository',
      );
    }
  }

  /// Queries relays for the newest kind-10011 identity event of [pubkey].
  ///
  /// Returns `null` when no event is found or the query fails.
  Future<Event?> _fetchIdentityEvent(String pubkey) async {
    try {
      final events = await _nostrClient.queryEvents([
        Filter(kinds: const [identityEventKind], authors: [pubkey], limit: 5),
      ], useCache: false);
      return newestIdentityEvent(
        events.where((e) => e.kind == identityEventKind).toList(),
      );
    } on Exception catch (e) {
      Log.warning(
        'Kind-$identityEventKind fetch failed for ${pubkeyForLogs(pubkey)}: $e',
        name: 'ProfileRepository',
      );
      return null;
    }
  }

  /// Decodes a stored `i` tag list; `null` when the JSON is malformed or
  /// wrong-shaped.
  ///
  /// Catches [Object] (not just [Exception]): a valid-JSON-but-wrong-shape
  /// row throws a [TypeError] (an [Error]) on the casts, which must still
  /// uphold the null-when-malformed contract rather than escaping to a
  /// reportable crash.
  static List<List<String>>? _decodeIdentityTags(String tagsJson) {
    try {
      final decoded = jsonDecode(tagsJson) as List<dynamic>;
      return [
        for (final tag in decoded)
          (tag as List<dynamic>).map((v) => v as String).toList(),
      ];
    } on Object {
      return null;
    }
  }

  /// Watches profile stats by pubkey, emitting updates from local storage.
  ///
  /// Returns a stream that maps [ProfileStatRow] from the database to
  /// [ProfileStats] domain models. Emits `null` if no stats exist.
  ///
  /// Returns an empty stream if [ProfileStatsDao] was not injected.
  @override
  Stream<ProfileStats?> watchProfileStats({required String pubkey}) {
    final dao = _profileStatsDao;
    if (dao == null) return const Stream.empty();
    return dao.watchStats(pubkey).map((row) {
      if (row == null) return null;
      return ProfileStats(
        pubkey: row.pubkey,
        videoCount: row.videoCount ?? 0,
        totalLikes: row.totalLikes ?? 0,
        followers: row.followerCount,
        following: row.followingCount,
        totalViews: row.totalViews ?? 0,
        lastUpdated: row.cachedAt,
      );
    });
  }

  /// Caches profile stats — social counts, video stats and engagement data —
  /// from a [UserProfileResult] into the local [ProfileStatsDao].
  ///
  /// The REST `social` counts are cached here because they are the
  /// authoritative follower/following numbers (#8197) and the only ones
  /// available before any relay work finishes, so the profile header can
  /// render immediately. FollowRepository still owns the relay-fallback path
  /// and its hysteresis stabilization for the case where REST cannot answer.
  Future<void> _cacheProfileStatsFromResult(
    String pubkey,
    UserProfileResult result,
  ) async {
    final dao = _profileStatsDao;
    if (dao == null) return;

    // Both variants expose social/stats/engagement on the sealed base class,
    // so no switch is needed here.
    final stats = result.stats;
    final engagement = result.engagement;
    final social = result.social;

    if (stats == null && engagement == null && social == null) return;

    int? publicViewCount;
    if (engagement != null) {
      publicViewCount = engagement.totalViews > 0
          ? engagement.totalViews
          : engagement.totalLoops.round();
    }

    // A zero field is not data. `/api/users/{pubkey}/social` answers 200 for
    // every pubkey, and funnelcake collapses ClickHouse failures into
    // `{0, 0}`, so "never indexed", "genuinely zero", "vanished" and "the
    // summary table is down" are indistinguishable here. Writing it would
    // overwrite a good baseline with zeros (#8259 review), so this writer
    // withholds each ambiguous field independently. The two counts come from
    // different inputs, so a positive value in one cannot legitimize a zero in
    // the other (#8259 review).

    await dao.upsertStats(
      pubkey: pubkey,
      // The REST social counts are the authoritative follower/following
      // numbers (#8197) and the only ones available before any relay work
      // finishes, so the profile header can render them immediately.
      followerCount: (social?.followerCount ?? 0) > 0
          ? social!.followerCount
          : null,
      followingCount: (social?.followingCount ?? 0) > 0
          ? social!.followingCount
          : null,
      // Same reasoning as the two counts above, and the same collapse:
      // `get_user_stats` maps both a miss and a ClickHouse failure to a
      // default, so funnelcake answers 200 with `video_count: 0` when the
      // summary table is down. Withholding it lets `upsertStats` keep the
      // previous real count instead of overwriting it with an ambiguous zero
      // (#8403).
      videoCount: (stats?.videoCount ?? 0) > 0 ? stats!.videoCount : null,
      totalLikes: engagement?.totalReactions,
      totalViews: publicViewCount,
    );
  }

  /// Fetches a fresh profile and updates the local cache.
  ///
  /// Strategy:
  /// 1. Funnelcake REST API (fast, broad coverage)
  /// 2. Connected relays and indexer relays —
  ///    both fired **in parallel**, first valid result returns immediately
  ///    and slower sources may upgrade the cache if they are newer
  ///
  /// Skips all fetches if the pubkey is confirmed missing.
  /// Deduplicates concurrent calls for the same pubkey —
  /// only one fetch pipeline runs, and all callers share
  /// the result.
  ///
  /// Answers `null` without any network call for an account known to have
  /// requested deletion. Eviction leaves no cached row, so every cache-miss
  /// caller — three `autoDispose` profile providers, each re-instantiated per
  /// widget — would otherwise take the network branch on every rebuild and
  /// re-run the eviction. [revalidateVanishOnce] carries the self-heal instead,
  /// bounded to one request per pubkey per session.
  ///
  /// Returns `null` if no profile exists across all sources.
  /// On success, the profile is automatically cached locally.
  @override
  Future<UserProfile?> fetchFreshProfile({
    required String pubkey,
    bool requireRawKind0 = false,
    List<Duration> rawKind0RetryDelays = const [],
  }) {
    if (_vanished.contains(pubkey)) {
      revalidateVanishOnce(pubkey);
      return Future<UserProfile?>.value();
    }

    return _fetchFreshProfileUnguarded(
      pubkey: pubkey,
      requireRawKind0: requireRawKind0,
      rawKind0RetryDelays: rawKind0RetryDelays,
    );
  }

  /// [fetchFreshProfile] without the vanish short-circuit.
  ///
  /// Only [revalidateVanishOnce] calls this directly, so a vanished pubkey has
  /// exactly one way back to the network per session.
  Future<UserProfile?> _fetchFreshProfileUnguarded({
    required String pubkey,
    bool requireRawKind0 = false,
    List<Duration> rawKind0RetryDelays = const [],
  }) {
    if (requireRawKind0 && _rawKind0ConfirmedMissing.contains(pubkey)) {
      return Future<UserProfile?>.value();
    }

    // Clear stale _confirmedMissing so we always re-check the REST API.
    // The sentinel may have been set by a batch fetch when the user had
    // no Kind 0 profile, but they may have published one since then.
    _confirmedMissing.remove(pubkey);

    // Deduplicate: return existing in-flight future if present.
    final fetchKey = requireRawKind0
        ? '$pubkey#raw-kind0#retry-${rawKind0RetryDelays.length}'
        : pubkey;
    final existing = _inFlightFetches[fetchKey];
    if (existing != null) return existing;

    final future = _doFetchFreshProfileWithRetries(
      pubkey,
      requireRawKind0: requireRawKind0,
      rawKind0RetryDelays: rawKind0RetryDelays,
    );
    _inFlightFetches[fetchKey] = future;

    return future.whenComplete(() => _inFlightFetches.remove(fetchKey));
  }

  Future<UserProfile?> _doFetchFreshProfileWithRetries(
    String pubkey, {
    required bool requireRawKind0,
    required List<Duration> rawKind0RetryDelays,
  }) async {
    final first = await _doFetchFreshProfile(
      pubkey,
      requireRawKind0: requireRawKind0,
    );
    if (!requireRawKind0 || first != null) return first;

    for (final delay in rawKind0RetryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final retry = await _doFetchFreshProfile(pubkey, requireRawKind0: true);
      if (retry != null) return retry;
    }

    _rawKind0ConfirmedMissing.add(pubkey);
    return null;
  }

  Future<UserProfile?> _doFetchFreshProfile(
    String pubkey, {
    required bool requireRawKind0,
  }) async {
    if (_blockFilter?.call(pubkey) ?? false) return null;

    // Step 1: Try Funnelcake REST API (fast, broad coverage).
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final result = await _funnelcakeApiClient!.getUserProfile(pubkey);
        switch (result) {
          case UserProfileVanished():
            // The account asked to be erased. Drop every local trace and stop
            // — unconditionally, even under requireRawKind0, so the relay
            // fallback cannot resurrect what we just deleted.
            await _applyVanish(pubkey);
            return null;
          case UserProfileFound():
            // Self-heal: the server says this account is live, so forget any
            // vanish we recorded earlier. Without this a single wrong
            // `has_vanish_request: true` + null profile would erase the account
            // from this device forever.
            await _clearVanish(pubkey);
            final funnelcakeProfile = UserProfile.fromUserProfileFound(result);
            await _cacheProfileStatsFromResult(pubkey, result);

            if (result.profile.createdAt != null && !requireRawKind0) {
              // Funnelcake exposes the original Nostr Kind 0 `created_at`
              // (the `profile.profile_updated` field), so a newest-wins
              // merge against the local cache is safe — a stale Funnelcake
              // copy can no longer clobber a freshly-saved bio, and a
              // genuinely newer Funnelcake profile can upgrade an older
              // local one (#3141).
              final existing = await _userProfilesDao.getProfile(pubkey);
              final funnelcakeWon = await _cacheProfileIfNewer(
                funnelcakeProfile,
                cached: existing,
                cachedResolved: true,
              );
              // Mirror the cache decision exactly: when the Funnelcake copy
              // did not win (older-or-equal, so the cache kept `existing`),
              // return `existing` too. Returning the Funnelcake copy here
              // would hand the caller a profile that disagrees with the
              // cache and may be missing fields the local one carries
              // (lud06, eventId, custom rawData).
              return funnelcakeWon ? funnelcakeProfile : existing;
            }

            // Defensive fallback: a found profile without a parseable
            // timestamp. Keep the conservative behavior — only write to
            // cache when no local profile exists yet, otherwise fall
            // through to the relay/indexer path so a newer Kind 0 on
            // relays can still upgrade the cache.
            final existing = await _userProfilesDao.getProfile(pubkey);
            if (existing == null && !requireRawKind0) {
              _knownCached.add(pubkey);
              await _userProfilesDao.upsertProfile(funnelcakeProfile);
              return funnelcakeProfile;
            }
          // Local profile exists — let the relay/indexer path below run
          // so a newer Kind 0 can still win.
          case UserProfileNotPublished():
            // User exists but has no Kind 0. Cache stats and skip relay
            // fallback — the profile genuinely does not exist yet.
            await _clearVanish(pubkey);
            await _cacheProfileStatsFromResult(pubkey, result);
            if (requireRawKind0) {
              break;
            }
            _confirmedMissing.add(pubkey);
            return null;
          case null:
            // 404 — user not found at all; fall through to relay.
            break;
        }
      } on Exception catch (e) {
        Log.warning(
          'REST API fetch failed (falling back to relay): $e',
          name: 'ProfileRepository.fetchFreshProfile',
          category: LogCategory.api,
        );
      }
    }

    // Step 2: Fire connected relays and indexer relays concurrently.
    // Return the first valid profile immediately, then let slower
    // sources upgrade the cache if they have a newer kind 0 event.
    final relayProfile = await _fetchFromRelaysParallel(
      pubkey,
      requireRawKind0: requireRawKind0,
    );
    if (relayProfile != null) {
      await _cacheProfileIfNewer(relayProfile);
      return relayProfile;
    }

    if (requireRawKind0) {
      return null;
    }

    // Relay/indexer found nothing. If a local profile already exists
    // (e.g. Funnelcake had a hit but we skipped its upsert to protect
    // a freshly-saved bio), return it as a fallback rather than null.
    final fallback = await _userProfilesDao.getProfile(pubkey);
    if (fallback != null) return fallback;

    // Empty relay/indexer results are indeterminate: queryEvents discards
    // timeout and participation details, so only an explicit server sentinel
    // can establish that no Kind 0 has been published.
    Log.debug(
      'No profile resolved for ${pubkeyForLogs(pubkey)} across all sources',
      name: 'ProfileRepository.fetchFreshProfile',
      category: LogCategory.relay,
    );
    return null;
  }

  /// Upserts [profile] into the local cache only when it is strictly newer
  /// than the currently-cached profile for the same pubkey.
  ///
  /// Returns `true` when the cache was written ([profile] won), `false` when
  /// an existing, newer-or-equal cache entry was kept.
  ///
  /// Pass [cached] together with `cachedResolved: true` when the caller has
  /// already read the current cache entry, to skip a redundant DAO read. A
  /// `null` [cached] with [cachedResolved] true means "confirmed no local
  /// profile".
  Future<bool> _cacheProfileIfNewer(
    UserProfile profile, {
    UserProfile? cached,
    bool cachedResolved = false,
  }) async {
    // Same guard as cacheProfile: the relay path writes through here.
    if (_vanished.contains(profile.pubkey)) return false;

    final cachedProfile = cachedResolved
        ? cached
        : await _userProfilesDao.getProfile(profile.pubkey);
    if (cachedProfile != null &&
        !profile.createdAt.isAfter(cachedProfile.createdAt)) {
      return false;
    }

    _confirmedMissing.remove(profile.pubkey);
    if (!profile.isRestProjection) {
      _rawKind0ConfirmedMissing.remove(profile.pubkey);
    }
    _knownCached.add(profile.pubkey);
    await _userProfilesDao.upsertProfile(profile);
    return true;
  }

  /// Queries connected relays and indexer relays in parallel for a
  /// kind 0 profile event. Returns the first valid profile immediately,
  /// then upgrades the cache if a slower source yields a newer event.
  /// Falls back to null only when every source completes without a result.
  Future<UserProfile?> _fetchFromRelaysParallel(
    String pubkey, {
    required bool requireRawKind0,
  }) async {
    final completer = Completer<UserProfile?>();
    UserProfile? newestProfile;
    var remaining = 2;

    Future<void> handleSource(Future<UserProfile?> source) async {
      try {
        final profile = await source;
        if (profile != null) {
          final isNewer =
              newestProfile == null ||
              profile.createdAt.isAfter(newestProfile!.createdAt);
          if (isNewer) {
            newestProfile = profile;
            if (!completer.isCompleted) {
              completer.complete(profile);
            } else {
              await _cacheProfileIfNewer(profile);
            }
          }
        }
      } on Object {
        // Individual source failures should not abort the overall fetch.
      } finally {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(newestProfile);
        }
      }
    }

    unawaited(
      handleSource(
        _fetchFromConnectedRelays(
          pubkey,
          useCache: requireRawKind0 ? false : null,
        ),
      ),
    );
    unawaited(handleSource(_fetchFromIndexerRelays(pubkey)));

    return completer.future;
  }

  Future<UserProfile?> _fetchFromConnectedRelays(
    String pubkey, {
    required bool? useCache,
  }) async {
    try {
      final event = useCache == null
          ? await _nostrClient.fetchProfile(pubkey)
          : await _nostrClient.fetchProfile(pubkey, useCache: useCache);
      if (event != null) {
        final profile = UserProfile.fromNostrEvent(event);
        Log.debug(
          'Fetched profile from connected relay',
          name: 'ProfileRepository.fetchFreshProfile',
          category: LogCategory.relay,
        );
        return profile;
      }
    } on Exception catch (e) {
      Log.warning(
        'Connected relay fetch failed: $e',
        name: 'ProfileRepository.fetchFreshProfile',
        category: LogCategory.relay,
      );
    }
    return null;
  }

  Future<UserProfile?> _fetchFromIndexerRelays(String pubkey) async {
    try {
      final events = await _nostrClient
          .queryEvents(
            [
              Filter(kinds: [0], authors: [pubkey], limit: 5),
            ],
            tempRelays: _indexerRelays,
            useCache: false,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => <Event>[]);

      // Relays do not guarantee newest-first ordering, so pick the event
      // with the highest createdAt to avoid overwriting a freshly saved
      // profile with stale metadata.
      final kind0Events = events.where((e) => e.kind == 0).toList();
      if (kind0Events.isNotEmpty) {
        final newest = kind0Events.reduce(
          (a, b) => b.createdAt > a.createdAt ? b : a,
        );
        final profile = UserProfile.fromNostrEvent(newest);
        Log.debug(
          'Fetched profile from indexer relay',
          name: 'ProfileRepository.fetchFreshProfile',
          category: LogCategory.relay,
        );
        return profile;
      }
    } on Exception catch (e) {
      Log.warning(
        'Indexer relay fetch failed: $e',
        name: 'ProfileRepository.fetchFreshProfile',
        category: LogCategory.relay,
      );
    }
    return null;
  }

  /// Publishes profile metadata to Nostr relays and updates the local cache.
  ///
  /// Supports two NIP-05 modes:
  /// - **Divine.video username**: When [username] is provided, constructs the
  ///   NIP-05 identifier as `_@<username>.divine.video`.
  /// - **External NIP-05**: When [nip05] is provided, uses it directly as the
  ///   full NIP-05 identifier (e.g., `alice@example.com`).
  ///
  /// If both [nip05] and [username] are provided, [nip05] takes precedence.
  /// When neither is provided and a [currentProfile] is supplied, the existing
  /// NIP-05 value is preserved from `currentProfile.rawData`. Pass
  /// [clearNip05] as `true` to explicitly remove the NIP-05 from the profile
  /// (overriding any value in `currentProfile.rawData`).
  ///
  /// Publishes through [NostrClient.sendProfileAwaitOk], so success means at
  /// least one relay confirmed the Kind 0 with an `OK true` (NIP-20) — a save
  /// that is accepted at the socket layer but then rejected by every relay
  /// surfaces as a failure rather than a false success. After a confirmed
  /// publish, the profile is cached locally for immediate subsequent reads.
  ///
  /// Throws [NoRelaysConnectedException] when no relays are connected.
  /// Throws [ProfilePublishFailedException] when relays were reached but none
  /// confirmed the event (rejection, timeout, or a send failure such as the
  /// signer returning null).
  Future<UserProfile> saveProfileEvent({
    required String displayName,
    String? about,
    String? website,
    String? username,
    String? nip05,
    bool clearNip05 = false,
    String? picture,
    String? banner,
    Iterable<MonetizationLink>? monetizationLinks,
    UserProfile? currentProfile,
  }) async {
    // External NIP-05 takes precedence when provided.
    final resolvedNip05 =
        nip05 ??
        (username != null ? '_@${username.toLowerCase()}.divine.video' : null);

    // Re-seed from the freshest Kind 0 we can get from relays. This is the
    // only path that preserves arbitrary unknown fields (custom client keys,
    // NIP-39 `i` tags, `bot`, future NIP additions) — the REST API does not
    // expose them. On relay failure or timeout it falls back to the best local
    // seed: [currentProfile] when the caller supplied one (whose `rawData`
    // carries the typed REST fields per `UserProfile.fromUserProfileFound`),
    // otherwise the cached profile for the signing key.
    final seed = await _resolvePublishSeed(currentProfile);

    final newContent = Map<String, dynamic>.from(seed?.rawData ?? const {});

    // Editable fields — caller's value is authoritative. Empty / null means
    // "user cleared this field" → remove the key. The form pre-populates
    // these fields so the user sees what they're editing; an empty submit
    // is intentional.
    newContent['display_name'] = displayName;
    if (about != null && about.isNotEmpty) {
      newContent['about'] = about;
    } else {
      newContent.remove('about');
    }
    if (website != null && website.isNotEmpty) {
      newContent['website'] = website;
    } else if (website != null) {
      newContent.remove('website');
    }
    if (picture != null && picture.isNotEmpty) {
      newContent['picture'] = picture;
    } else {
      newContent.remove('picture');
    }
    if (banner != null && banner.isNotEmpty) {
      newContent['banner'] = banner;
    } else {
      newContent.remove('banner');
    }

    // nip05 keeps the race-protected clear semantics from #4022:
    // an empty/null `effectiveNip05` only REMOVES the key when the caller
    // sets `clearNip05: true`. Otherwise the seed's nip05 (if any) survives.
    final effectiveNip05 = resolvedNip05;
    if (effectiveNip05 != null && effectiveNip05.isNotEmpty) {
      newContent['nip05'] = effectiveNip05;
    } else if (clearNip05) {
      newContent.remove('nip05');
    }

    if (monetizationLinks != null) {
      final encoded = encodeMonetizationLinks(
        monetizationLinks.where((link) => link.enabled),
      );
      if (encoded.isEmpty) {
        newContent.remove(divineMonetizationLinksKey);
      } else {
        newContent[divineMonetizationLinksKey] = encoded;
      }
    }

    // Every other key — lud16, lud06, website, bot, NIP-39 `i` tags,
    // custom client fields, future NIPs — flows through from the seed
    // untouched. Adding new editable fields here MUST keep that invariant.

    final rawTags = (seed?.rawTags.isNotEmpty ?? false)
        ? seed!.rawTags
        : currentProfile?.rawTags ?? const <List<String>>[];
    final result = rawTags.isEmpty
        ? await _nostrClient.sendProfileAwaitOk(profileContent: newContent)
        : await _nostrClient.sendProfileAwaitOk(
            profileContent: newContent,
            tags: rawTags,
          );

    // Switch exhaustively over the typed result — no post-failure
    // connectedRelays snapshot needed.
    switch (result) {
      case PublishSuccess(:final event):
        final profile = UserProfile.fromNostrEvent(event);
        _rawKind0ConfirmedMissing.remove(profile.pubkey);
        // A relay confirmed the kind-0 (OK true). The local cache write is
        // non-fatal from here on: a Drift hiccup must never turn a landed
        // publish into a thrown failure, or a durable re-drive would re-publish
        // an already-confirmed save forever (#3161 G3 / review). Callers that
        // need the cache warm re-read through the normal fetch path.
        try {
          await _userProfilesDao.upsertProfile(profile);
        } on Object catch (e) {
          Log.warning(
            'profile cache upsert after a confirmed publish failed '
            '(non-fatal): $e',
            name: 'ProfileRepository.saveProfileEvent',
            category: LogCategory.storage,
          );
        }
        return profile;

      case PublishNoRelays():
        Log.error(
          'sendProfileAwaitOk: no connected relays after retry',
          name: 'ProfileRepository.saveProfileEvent',
          category: LogCategory.relay,
        );
        throw const NoRelaysConnectedException(
          'No relays connected. Check your connection and try again.',
        );

      case PublishFailed():
        Log.error(
          'sendProfileAwaitOk: relay rejected the event or no relay confirmed',
          name: 'ProfileRepository.saveProfileEvent',
          category: LogCategory.relay,
        );
        throw const ProfilePublishFailedException(
          'Failed to publish profile. Please try again.',
        );
    }
  }

  // -------------------------------------------------------------------------
  // Pending-save slot (#3161): durable, background-re-driven profile save.
  // -------------------------------------------------------------------------

  /// Persist [payload] to the durable pending-save slot so a failed kind-0
  /// publish is re-driven in the background when connectivity returns.
  ///
  /// Latest intent wins — a fresh save replaces any in-flight row (kind 0 is
  /// replaceable). Pass [claimConfirmed] true when the divine.video username
  /// claim already succeeded for this payload (or when no claim is needed), so
  /// the re-drive skips the idempotent HTTP claim round-trip.
  ///
  /// Returns the `generation` token stamped on the queued row so the caller
  /// can scope its own [drivePendingSave] to exactly this intent. Returns null
  /// when no [PendingProfileSavesDao] was injected (a no-op).
  Future<String?> enqueuePendingSave(
    PendingProfileSave payload, {
    required bool claimConfirmed,
  }) async {
    final dao = _pendingProfileSavesDao;
    if (dao == null) return null;
    return dao.upsert(
      PendingProfileSaveEntry(
        userPubkey: payload.pubkey,
        payloadJson: payload.encode(),
        claimConfirmed: claimConfirmed,
        queuedAt: DateTime.now(),
      ),
    );
  }

  /// Reactive view of the pending save for [pubkey], or null when none is
  /// queued (e.g. after a confirmed publish clears it). Emits nothing when no
  /// [PendingProfileSavesDao] was injected.
  Stream<PendingProfileSaveEntry?> watchPendingSave(String pubkey) {
    final dao = _pendingProfileSavesDao;
    if (dao == null) return const Stream.empty();
    return dao.watch(pubkey);
  }

  /// The current pending save for [pubkey], or null.
  Future<PendingProfileSaveEntry?> getPendingSave(String pubkey) async {
    return _pendingProfileSavesDao?.get(pubkey);
  }

  /// Delete the pending save for [pubkey] (e.g. on an explicit user discard).
  Future<void> clearPendingSave(String pubkey) async {
    await _pendingProfileSavesDao?.clear(pubkey);
  }

  /// Reset a `syncing` slot back to `pending` for [pubkey] — call once on cold
  /// start so a save interrupted mid-publish is retried.
  Future<void> resetInterruptedPendingSave(String pubkey) async {
    await _pendingProfileSavesDao?.resetSyncingToPending(pubkey);
  }

  /// Attempt to publish the queued save for [pubkey] once.
  ///
  /// Claim-first (only when not yet confirmed and a divine.video username is
  /// requested), then publish the kind-0 re-seeded from the freshest cached
  /// profile. On a relay-confirmed publish the slot is cleared (and the profile
  /// cached by [saveProfileEvent], non-fatally), returning
  /// [PendingSaveDriveOutcome.confirmed]. Slot bookkeeping on failure (retry
  /// count, mark-failed) is the caller's (retry service's) job — this method
  /// only reports the typed outcome and never increments retries.
  ///
  /// Every slot mutation here (claim-confirmed, clear) is guarded by the
  /// generation captured at read time, so a newer save that replaces the row
  /// while this drive awaits relay work is never cleared or reclassified — the
  /// newer intent is left queued to be driven on its own (#3161 review). Pass
  /// [expectedGeneration] (from [enqueuePendingSave] / the retry service) to
  /// additionally bail out with [PendingSaveDriveOutcome.noPendingSave] when
  /// the row was already superseded before this drive started; omit it to drive
  /// whatever intent is currently queued.
  ///
  /// Throws only unexpected (non-[ProfileRepositoryException]) errors, which
  /// the retry service treats as a retryable failure.
  Future<PendingSaveDriveOutcome> drivePendingSave(
    String pubkey, {
    String? expectedGeneration,
  }) async {
    final dao = _pendingProfileSavesDao;
    if (dao == null) return PendingSaveDriveOutcome.noPendingSave;

    final entry = await dao.get(pubkey);
    if (entry == null) return PendingSaveDriveOutcome.noPendingSave;

    // A newer save replaced the row after the caller captured the generation
    // it wanted driven — that newer intent owns delivery now; don't touch it.
    if (expectedGeneration != null && entry.generation != expectedGeneration) {
      return PendingSaveDriveOutcome.noPendingSave;
    }
    final generation = entry.generation;

    final payload = PendingProfileSave.decode(entry.payloadJson);

    if (!entry.claimConfirmed && payload.requiresClaim) {
      final result = await claimUsername(username: payload.username!);
      switch (result) {
        case UsernameClaimSuccess():
          await dao.markClaimConfirmed(pubkey, generation: generation);
        case UsernameClaimTaken():
        case UsernameClaimReserved():
          return PendingSaveDriveOutcome.permanentFailure;
        case UsernameClaimNetworkError():
        case UsernameClaimError():
          return PendingSaveDriveOutcome.retryableFailure;
        case UsernameClaimInvalidFormat():
          return PendingSaveDriveOutcome.permanentFailure;
      }
    }

    final currentProfile = await getCachedProfile(pubkey: pubkey);
    try {
      // saveProfileEvent only returns on a relay-confirmed OK true, and its
      // post-publish cache write is non-fatal, so reaching here means the
      // kind-0 landed. Clearing the slot is generation-guarded: if a newer
      // save replaced this row while we awaited the publish, the delete
      // affects zero rows and the newer intent survives to be driven on its
      // own — latest intent wins (#3161 review).
      await saveProfileEvent(
        displayName: payload.displayName,
        about: payload.about,
        website: payload.website,
        username: payload.username,
        nip05: payload.nip05,
        clearNip05: payload.clearNip05,
        picture: payload.picture,
        banner: payload.banner,
        monetizationLinks: payload.monetizationLinks,
        currentProfile: currentProfile,
      );
      await dao.clear(pubkey, generation: generation);
      return PendingSaveDriveOutcome.confirmed;
    } on NoRelaysConnectedException {
      return PendingSaveDriveOutcome.retryableFailure;
    } on ProfilePublishFailedException {
      return PendingSaveDriveOutcome.retryableFailure;
    }
  }

  /// Picks the freshest available [UserProfile] to seed a [saveProfileEvent]
  /// publish from. Prefers a relay-fetched Kind 0 (which carries the full
  /// raw event content as `rawData`) over [currentProfile] (which may have
  /// been hydrated from the Funnelcake REST API and is missing keys the
  /// REST schema does not expose).
  ///
  /// When [currentProfile] is null the subject is still known — this publish
  /// signs through [_nostrClient], so its public key *is* the event's pubkey.
  /// Seeding from it turns what was a destructive full replace into a
  /// read-modify-write: previously a null [currentProfile] returned before any
  /// fetch, so the published Kind 0 was composed from an empty map and every
  /// field outside the form (`name`, `nip05`, `lud16`, `lud06`, `bot`,
  /// monetization links, unknown client keys) plus every NIP-39 `i` tag was
  /// erased on relays.
  ///
  /// Returns the local seed (or null) when:
  /// - there is no pubkey at all — no [currentProfile] and no signer key,
  /// - the relay fetch returns null (its documented failure mode — internal
  ///   errors are swallowed by [fetchFreshProfile]),
  /// - the relay fetch exceeds [_publishSeedRelayTimeout],
  /// - the local seed is strictly newer, or carries the same timestamp and
  ///   strictly more meaningful keys.
  Future<UserProfile?> _resolvePublishSeed(UserProfile? currentProfile) async {
    // `??` short-circuits, so the signer is consulted only when the caller gave
    // us no profile to take a pubkey from.
    final pubkey = currentProfile?.pubkey ?? _signerPubkeyOrNull();
    if (pubkey == null) {
      return currentProfile;
    }

    // A caller that passed no profile may still have one cached locally; read
    // it before falling back to a bare relay fetch so an offline publish is
    // seeded rather than stripped.
    final localSeed = currentProfile ?? await getCachedProfile(pubkey: pubkey);

    final fresh = await fetchFreshProfile(
      pubkey: pubkey,
      requireRawKind0: true,
    ).timeout(_publishSeedRelayTimeout, onTimeout: () => null);
    if (fresh == null) {
      return localSeed;
    }
    if (localSeed == null) {
      return fresh;
    }

    // Recency decides first. A field the user removed on another client leaves
    // the newest Kind 0 both newer *and* sparser, so letting key count override
    // recency would re-publish the deletion away.
    if (fresh.createdAt.isAfter(localSeed.createdAt)) {
      return fresh;
    }
    if (localSeed.createdAt.isAfter(fresh.createdAt)) {
      return localSeed;
    }

    // Same timestamp — break the tie on richness, counted over *meaningful*
    // keys rather than `rawData.length`. A REST-derived profile used to
    // out-count the real Kind 0 on `''` placeholders alone (Funnelcake models
    // every metadata field as a non-nullable String, so an absent key arrives
    // as `''`), which handed the publish path a seed whose `isNotEmpty` guards
    // then deleted the very fields it was meant to preserve.
    //
    // On a genuine tie `fresh` wins: it is a raw Kind 0 (requireRawKind0), so
    // it carries unknown keys and NIP-39 tags the REST projection structurally
    // cannot express.
    return _meaningfulKeyCount(localSeed.rawData) >
            _meaningfulKeyCount(fresh.rawData)
        ? localSeed
        : fresh;
  }

  /// The signing key this repository publishes as, or `null` when the client
  /// has no key yet.
  String? _signerPubkeyOrNull() {
    final pubkey = _nostrClient.publicKey;
    return pubkey.isEmpty ? null : pubkey;
  }

  /// Counts entries in a Kind 0 `rawData` map that carry an actual value.
  ///
  /// Null and empty-string values are placeholders, not content, so they must
  /// not make one seed look richer than another.
  static int _meaningfulKeyCount(Map<String, dynamic> rawData) {
    var count = 0;
    for (final value in rawData.values) {
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      count++;
    }
    return count;
  }

  /// Claims a username via NIP-98 authenticated request.
  ///
  /// Makes a POST request to the name server's `/api/username/claim` with the
  /// username. The pubkey is extracted from the NIP-98 auth header by the
  /// server.
  ///
  /// Returns a [UsernameClaimResult] indicating success or the type of failure.
  Future<UsernameClaimResult> claimUsername({required String username}) async {
    final validation = validateDivineUsername(username);
    if (validation case DivineUsernameInvalid(:final failure)) {
      return UsernameClaimInvalidFormat(failure);
    }

    final normalizedUsername = (validation as DivineUsernameValid).normalized;
    final payload = jsonEncode({'name': normalizedUsername});

    final String authHeader;
    try {
      final header = await _nostrClient.createNip98AuthHeader(
        url: _usernameClaimUrl,
        method: 'POST',
        payload: payload,
      );

      if (header == null) {
        Log.error(
          'NIP-98 auth header generation returned null '
          '(username: $normalizedUsername)',
          name: 'ProfileRepository.claimUsername',
          category: LogCategory.auth,
        );
        return const UsernameClaimError('Nip98 authorization failed');
      }
      authHeader = header;
    } on Object catch (e, st) {
      // Signer threw (e.g. a Keycast RPC error or timeout). Neither
      // createNip98AuthHeader nor Nostr.signEvent catches, and the method's
      // own handler below is `on Exception`, so without this the throw left
      // claimUsername entirely — including for a fully keyed account. The
      // request never reached the server, so no name was claimed.
      Log.error(
        'NIP-98 auth header generation threw '
        '(username: $normalizedUsername): $e',
        name: 'ProfileRepository.claimUsername',
        category: LogCategory.auth,
        error: e,
        stackTrace: st,
      );
      return const UsernameClaimError('Signing failed');
    }

    final Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse(_usernameClaimUrl),
            headers: {
              'Authorization': authHeader,
              'Content-Type': 'application/json',
            },
            body: payload,
          )
          .timeout(_nameServerHttpTimeout);

      // Parse server error message if available
      String? serverError;
      if (response.statusCode != 200 && response.statusCode != 201) {
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          serverError = errorData['error'] as String?;
        } on Exception {
          // Ignore JSON parse failures
        }
        Log.warning(
          'claim returned ${response.statusCode}: '
          '${serverError ?? "(no server error)"} '
          '(username: $normalizedUsername)',
          name: 'ProfileRepository.claimUsername',
          category: LogCategory.api,
        );
      }

      final result = switch (response.statusCode) {
        200 || 201 => const UsernameClaimSuccess(),
        400 => UsernameClaimError(serverError ?? 'Invalid username format'),
        403 => const UsernameClaimReserved(),
        409 => const UsernameClaimTaken(),
        _ => UsernameClaimError(
          serverError ?? 'Unexpected response: ${response.statusCode}',
        ),
      };
      if (result is UsernameClaimSuccess) {
        Log.info(
          'claim succeeded for $normalizedUsername',
          name: 'ProfileRepository.claimUsername',
          category: LogCategory.auth,
        );
      }
      return result;
    } on Exception catch (e, st) {
      Log.error(
        'claim network error (username: $normalizedUsername)',
        name: 'ProfileRepository.claimUsername',
        category: LogCategory.api,
        error: e,
        stackTrace: st,
      );
      return const UsernameClaimNetworkError();
    }
  }

  /// Looks up the active `@divine.video` name owned by [pubkeyHex].
  ///
  /// Returns [DivineUsernameNotFound] only when divine-name-server returned a
  /// valid 200 response with `found:false`. Network, timeout, non-200, and
  /// wrong-shaped responses return [DivineUsernameUnknown] so callers do not
  /// confuse "could not check" with "no name exists."
  @override
  Future<DivineUsernameLookup> lookupUsernameByPubkey({
    required String pubkeyHex,
  }) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$_usernameByPubkeyUrl/$pubkeyHex'))
          .timeout(_nameServerHttpTimeout);
      if (response.statusCode != 200) return const DivineUsernameUnknown();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['found'] != true) return const DivineUsernameNotFound();
      final name = data['name'] as String?;
      final canonical = data['canonical'] as String?;
      if (name == null || canonical == null) {
        return const DivineUsernameUnknown();
      }
      return DivineUsernameFound(name: name, canonical: canonical);
    } on Object catch (e) {
      Log.warning(
        'by-pubkey lookup failed: $e',
        name: 'ProfileRepository.lookupUsernameByPubkey',
        category: LogCategory.api,
      );
      return const DivineUsernameUnknown();
    }
  }

  /// Resolves whether [pubkey] is a Divine identity, distinguishing a genuine
  /// verdict from an undetermined one.
  ///
  /// Used to bound "community" membership for viewer-suggested content
  /// warnings (#4771): only suggestions from pubkeys with a Divine identity
  /// count toward the display threshold. Anyone can still publish a label;
  /// this only decides which authors the app counts.
  ///
  /// Returns `true`/`false` on a genuine `200` verdict (cached for
  /// [_divineIdentityCacheTtl], 24h), and **`null`** when the lookup could
  /// not be determined — a network/timeout error, a non-200 response, or an
  /// unparseable/non-object body. `null` verdicts are never cached, so the
  /// next lookup retries. See the `_divineIdentityCacheTtl` note for the
  /// #4948 alignment.
  Future<bool?> resolveDivineIdentity(String pubkey) async {
    final normalized = pubkey.trim().toLowerCase();
    // An empty pubkey is genuinely not a Divine identity, not "undetermined".
    if (normalized.isEmpty) return false;

    final cached = _divineIdentityCache[normalized];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _divineIdentityCacheTtl) {
      return cached.value;
    }

    bool? verdict;
    try {
      final response = await _httpClient
          .get(Uri.parse('$_usernameByPubkeyUrl/$normalized'))
          .timeout(_nameServerHttpTimeout);
      if (response.statusCode == 200) {
        // Decode-then-check: a naive cast throws a TypeError (an Error, not
        // an Exception) for valid non-object JSON like `[]`, escaping the
        // catch below instead of resolving to the documented sentinel.
        final body = jsonDecode(response.body) as Object?;
        if (body is Map<String, dynamic>) {
          verdict = body['found'] == true;
        }
      }
    } on Exception catch (e) {
      Log.warning(
        'by-pubkey lookup failed: $e',
        name: 'ProfileRepository.resolveDivineIdentity',
        category: LogCategory.api,
      );
    }

    // Only a genuine 200 verdict is cached; undetermined lookups stay
    // uncached so the next lookup retries (same posture as the backend
    // identity cache).
    if (verdict != null) {
      if (_divineIdentityCache.length >= _divineIdentityCacheMax &&
          !_divineIdentityCache.containsKey(normalized)) {
        _divineIdentityCache.remove(_divineIdentityCache.keys.first);
      }
      _divineIdentityCache[normalized] = (value: verdict, at: DateTime.now());
    }
    return verdict;
  }

  /// Checks if a username is available for registration.
  ///
  /// Queries the NIP-05 endpoint to check if the username is already registered
  /// on the server.
  ///
  /// This method performs shared client-side validation before making network
  /// calls so editor and repository behavior stay in sync.
  ///
  /// Returns a [UsernameAvailabilityResult] indicating:
  /// - [UsernameAvailable] if the username is not registered on the server
  /// - [UsernameTaken] if the username is already registered
  /// - [UsernameCheckError] if a network error occurs or the server returns
  ///   an unexpected response
  Future<UsernameAvailabilityResult> checkUsernameAvailability({
    required String username,
    String? currentUserPubkey,
  }) async {
    final validation = validateDivineUsername(username);
    if (validation case DivineUsernameInvalid(:final failure)) {
      return UsernameInvalidFormat(failure);
    }
    final normalizedUsername = (validation as DivineUsernameValid).normalized;

    // Server-side check using the name-server API which validates format
    // and checks availability in one call.
    Log.debug(
      'checking availability for $normalizedUsername',
      name: 'ProfileRepository.checkUsernameAvailability',
      category: LogCategory.api,
    );
    try {
      final response = await _httpClient
          .get(Uri.parse('$_usernameCheckUrl/$normalizedUsername'))
          .timeout(_nameServerHttpTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final available = data['available'] as bool? ?? false;
        final reason = data['reason'] as String?;
        final code = data['code'] as String?;

        if (available) {
          // Also check keycast — username must be available on both the name
          // server and the login server.
          try {
            final keycastResponse = await _httpClient
                .get(Uri.parse('$_keycastNip05Url?name=$normalizedUsername'))
                .timeout(_nameServerHttpTimeout);
            if (keycastResponse.statusCode == 200) {
              final keycastData =
                  jsonDecode(keycastResponse.body) as Map<String, dynamic>;
              final names = keycastData['names'] as Map<String, dynamic>? ?? {};
              if (names.containsKey(normalizedUsername)) {
                return const UsernameTaken();
              }
            }
            // If keycast returns non-200 or no names entry, treat as available
          } on Exception catch (e) {
            // If keycast is unreachable, don't block — name-server said OK
            Log.warning(
              'Keycast availability check failed (non-blocking): $e',
              name: 'ProfileRepository.checkUsernameAvailability',
              category: LogCategory.api,
            );
          }
          return const UsernameAvailable();
        }

        // Name is taken, but check if it's assigned to the current user
        // (e.g. admin-reserved name assigned to this pubkey).
        if (currentUserPubkey != null) {
          final ownerPubkey = data['pubkey'] as String?;
          if (ownerPubkey != null && ownerPubkey == currentUserPubkey) {
            return const UsernameAvailable();
          }
        }

        if (code == null) {
          Log.error(
            'Name server response missing required code field '
            '(username: $normalizedUsername, reason: $reason)',
            name: 'ProfileRepository.checkUsernameAvailability',
            category: LogCategory.api,
          );
          return const UsernameTaken();
        }
        return switch (code) {
          'reserved' => const UsernameReserved(),
          'burned' => const UsernameBurned(),
          'invalid_format' => const UsernameInvalidFormat(),
          // taken, pending_confirmation, or any unknown code
          _ => const UsernameTaken(),
        };
      } else {
        Log.warning(
          'name server returned ${response.statusCode} '
          '(username: $normalizedUsername)',
          name: 'ProfileRepository.checkUsernameAvailability',
          category: LogCategory.api,
        );
        return UsernameCheckError(
          'Server returned status ${response.statusCode}',
        );
      }
    } on Exception catch (e, st) {
      Log.error(
        'name-server network error (username: $normalizedUsername)',
        name: 'ProfileRepository.checkUsernameAvailability',
        category: LogCategory.api,
        error: e,
        stackTrace: st,
      );
      return UsernameCheckError('Network error: $e');
    }
  }

  /// Searches for user profiles via the Funnelcake REST API only.
  ///
  /// This is for latency-sensitive typeahead surfaces that should not wait
  /// for NIP-50 relay search. Server-sorted results normally preserve server
  /// order, except for known no-op sorts that need client fallback ranking.
  ///
  /// [offset] skips results for pagination.
  /// [sortBy] requests server-side sorting (e.g.,
  /// [profileSearchSortFollowers]).
  /// [hasVideos] filters to only users who have published at least one video.
  /// Returns empty list if query is empty, Funnelcake is unavailable, or the
  /// REST request fails.
  Future<List<UserProfile>> searchUsersFromApi({
    required String query,
    int limit = 50,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];
    if (!(_funnelcakeApiClient?.isAvailable ?? false)) return [];

    try {
      final restResults = await _funnelcakeApiClient!.searchProfiles(
        query: trimmedQuery,
        limit: limit,
        offset: offset,
        sortBy: sortBy,
        hasVideos: hasVideos,
      );
      final profiles = restResults
          .map((result) => result.toUserProfile())
          .where((p) => !(_blockFilter?.call(p.pubkey) ?? false));
      final enriched = await _enrichFromCache(profiles.toList());
      return _rankServerSortedPage(enriched, sortBy);
    } on Exception catch (e) {
      Log.warning(
        'REST profile search failed: $e',
        name: 'ProfileRepository.searchUsersFromApi',
        category: LogCategory.api,
      );
      return [];
    }
  }

  /// Searches for user profiles matching the query.
  ///
  /// Uses a hybrid search approach:
  /// 1. First tries Funnelcake REST API (fast, if available)
  /// 2. Then fetches via NIP-50 WebSocket (comprehensive, first page only)
  /// 3. Merges results (REST results take priority by pubkey)
  ///
  /// [offset] skips results for pagination. When offset > 0, the NIP-50
  /// WebSocket fallback is skipped since it doesn't support offset.
  /// [sortBy] requests server-side sorting (e.g.,
  /// [profileSearchSortFollowers]).
  /// When set, most server order is preserved, with targeted fallback ranking
  /// for known no-op sorts.
  /// [hasVideos] filters to only users who have published at least one video.
  ///
  /// Filters using [ProfileSearchFilter] if provided (only when no server-side
  /// sort is active), otherwise falls back to simple bestDisplayName matching.
  /// Returns list of [UserProfile] matching the search query.
  /// Returns empty list if query is empty or no results found.
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 200,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
  }) async {
    if (query.trim().isEmpty) return [];

    final resultMap = <String, UserProfile>{};
    final useServerSort = sortBy != null;

    // Phase 1: Try Funnelcake REST API (fast)
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final restResults = await _funnelcakeApiClient!.searchProfiles(
          query: query,
          limit: limit,
          offset: offset,
          sortBy: sortBy,
          hasVideos: hasVideos,
        );
        for (final result in restResults) {
          resultMap[result.pubkey] = result.toUserProfile();
        }
        final withPic = restResults.where((r) => r.picture != null).length;
        Log.debug(
          'Phase 1 (REST): ${restResults.length} results, '
          '$withPic with picture',
          name: 'ProfileRepository.searchUsers',
          category: LogCategory.api,
        );
      } on Exception catch (e) {
        Log.warning(
          'Phase 1 (REST) failed: $e',
          name: 'ProfileRepository.searchUsers',
          category: LogCategory.api,
        );
      }
    }

    // Phase 2: NIP-50 WebSocket search (comprehensive, first page only)
    // Skip on paginated requests since NIP-50 doesn't support offset.
    if (offset == 0) {
      try {
        final events = await _nostrClient.queryUsers(query, limit: limit);
        for (final event in events) {
          final profile = UserProfile.fromNostrEvent(event);
          // Don't overwrite REST results - they may have more complete data
          resultMap.putIfAbsent(profile.pubkey, () => profile);
        }
        final wsProfiles = resultMap.values.toList();
        final wsWithPic = wsProfiles.where((p) => p.picture != null).length;
        Log.debug(
          'Phase 2 (WS): ${events.length} events, '
          'merged total: ${wsProfiles.length}, $wsWithPic with picture',
          name: 'ProfileRepository.searchUsers',
          category: LogCategory.relay,
        );
      } on Object catch (e) {
        Log.warning(
          'Phase 2 (WebSocket NIP-50) failed: $e',
          name: 'ProfileRepository.searchUsers',
          category: LogCategory.relay,
        );
      }
    }

    // Apply the injected block filter, consistent with searchUsersLocally
    // and searchUsersProgressive. Unblocking happens via the Safety
    // Settings blocked-users list, not via search findability.
    final blockFilter = _blockFilter;
    final profiles = blockFilter == null
        ? resultMap.values.toList()
        : resultMap.values.where((p) => !blockFilter(p.pubkey)).toList();

    // Enrich profiles from local SQLite cache (fill in missing pictures, etc.)
    final enrichedProfiles = await _enrichFromCache(profiles);

    // When server-side sorting is active, trust server order — unless the
    // requested sort had nothing to order by on this page.
    if (useServerSort) {
      return _rankServerSortedPage(enrichedProfiles, sortBy);
    }

    // Use custom search filter if provided, otherwise simple contains match
    if (_profileSearchFilter != null) {
      return _profileSearchFilter(query, enrichedProfiles);
    }

    final queryLower = query.toLowerCase();
    return enrichedProfiles.where((profile) {
      return profile.bestDisplayName.toLowerCase().contains(queryLower);
    }).toList();
  }

  /// Progressively streams user profile search results.
  ///
  /// Each yield carries a [ProgressiveSearchResult] envelope containing:
  /// - the accumulated, deduplicated, filter+boost-applied profile list
  /// - a per-source outcome map ([ProgressiveSearchResult.sources])
  /// - an [ProgressiveSearchResult.isComplete] flag on the terminal yield
  ///
  /// Consults three sources in order:
  /// 1. Local cached profiles (instant, first page only)
  /// 2. Funnelcake REST API (fast)
  /// 3. NIP-50 WebSocket (first page only, with [_nip50SearchTimeout])
  ///
  /// On [offset] > 0 the local and NIP-50 phases are recorded as
  /// [SearchSourceSkipped]. When Funnelcake is unconfigured it is also
  /// recorded as [SearchSourceSkipped]. Any phase that throws (REST as
  /// an [Exception], NIP-50 as an [Object] since WebSocket errors
  /// surface as [Error]) is recorded as [SearchSourceFailed]; the stream
  /// continues to consult later sources.
  ///
  /// When [boostPubkeys] is non-empty, profiles whose pubkey is in the set
  /// are promoted to the front of each emission while preserving the
  /// server-relative order within both the boosted and non-boosted groups.
  /// Typical use: pass the follow graph so followed users appear first on
  /// the initial search page. Callers should omit [boostPubkeys] on
  /// load-more requests so already-visible positions stay stable as the
  /// user scrolls.
  Stream<ProgressiveSearchResult> searchUsersProgressive({
    required String query,
    int limit = 200,
    int offset = 0,
    String? sortBy,
    bool hasVideos = false,
    Set<String>? boostPubkeys,
    SearchCancellationToken? cancellationToken,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (_isSearchCancelled(cancellationToken)) return;

    final resultMap = <String, UserProfile>{};
    final sources = <SearchSource, SearchSourceStatus>{
      for (final source in SearchSource.values)
        source: const SearchSourcePending(),
    };
    final useServerSort = sortBy != null;
    int? nextRestOffset;
    var restHasMore = false;

    ProgressiveSearchResult snapshot({
      required bool isComplete,
      List<UserProfile>? enriched,
    }) {
      final profiles =
          enriched ??
          _applyFilter(
            trimmed,
            resultMap.values.toList(),
            useServerSort,
            boostPubkeys,
            sortBy: sortBy,
          );
      return ProgressiveSearchResult(
        profiles: profiles,
        sources: Map.unmodifiable(sources),
        isComplete: isComplete,
        nextRestOffset: nextRestOffset,
        restHasMore: restHasMore,
      );
    }

    // Phase 1: Local cache (instant, first page only)
    if (offset == 0) {
      final phase1Watch = Stopwatch()..start();
      final preCount = resultMap.length;
      try {
        final local = await _searchUsersForDiscovery(
          query: trimmed,
          limit: limit,
        );
        if (_isSearchCancelled(cancellationToken)) return;
        for (final profile in local) {
          resultMap[profile.pubkey] = profile;
        }
        sources[SearchSource.localCache] = SearchSourceSuccess(
          resultCount: resultMap.length - preCount,
          latencyMs: phase1Watch.elapsedMilliseconds,
        );
      } on Object catch (e) {
        sources[SearchSource.localCache] = SearchSourceFailed(
          reason: SearchSourceFailureReason.other,
          latencyMs: phase1Watch.elapsedMilliseconds,
        );
        Log.warning(
          'Local cache search failed (${e.runtimeType})',
          name: 'ProfileRepository.searchUsersProgressive',
          category: LogCategory.api,
        );
      }
      if (resultMap.isNotEmpty) {
        yield snapshot(isComplete: false);
      }
    } else {
      sources[SearchSource.localCache] = const SearchSourceSkipped();
    }

    // Phase 2: Funnelcake REST API (fast)
    if (_isSearchCancelled(cancellationToken)) return;
    final prevCount = resultMap.length;
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      final phase2Watch = Stopwatch()..start();
      final preRestCount = resultMap.length;
      try {
        final restResults = await _funnelcakeApiClient!.searchProfiles(
          query: trimmed,
          limit: limit,
          offset: offset,
          sortBy: sortBy,
          hasVideos: hasVideos,
        );
        if (_isSearchCancelled(cancellationToken)) return;
        nextRestOffset = offset + restResults.length;
        restHasMore = restResults.length == limit;
        for (final result in restResults) {
          resultMap[result.pubkey] = result.toUserProfile();
        }
        sources[SearchSource.funnelcakeApi] = SearchSourceSuccess(
          resultCount: resultMap.length - preRestCount,
          latencyMs: phase2Watch.elapsedMilliseconds,
        );
      } on Exception catch (e) {
        sources[SearchSource.funnelcakeApi] = SearchSourceFailed(
          reason: SearchSourceFailureReason.network,
          latencyMs: phase2Watch.elapsedMilliseconds,
        );
        Log.warning(
          'REST search failed (${e.runtimeType})',
          name: 'ProfileRepository.searchUsersProgressive',
          category: LogCategory.api,
        );
      }
    } else {
      sources[SearchSource.funnelcakeApi] = const SearchSourceSkipped();
    }

    // Yield after Phase 2 if new results were added.
    // Skips enrichment for faster progressive display; the final Phase 3
    // yield enriches all results from cache.
    if (resultMap.length > prevCount) {
      yield snapshot(isComplete: false);
    }

    // Phase 3: NIP-50 WebSocket (first page only)
    if (_isSearchCancelled(cancellationToken)) return;
    if (offset == 0) {
      final preWsCount = resultMap.length;
      final phase3Watch = Stopwatch()..start();
      try {
        final events = await _nostrClient
            .queryUsers(trimmed, limit: limit, timeout: _nip50RelayQueryTimeout)
            .timeout(_nip50SearchTimeout);
        if (_isSearchCancelled(cancellationToken)) return;
        for (final event in events) {
          final profile = UserProfile.fromNostrEvent(event);
          resultMap.putIfAbsent(profile.pubkey, () => profile);
        }
        sources[SearchSource.nip50Relay] = SearchSourceSuccess(
          resultCount: resultMap.length - preWsCount,
          latencyMs: phase3Watch.elapsedMilliseconds,
        );
      } on TimeoutException {
        sources[SearchSource.nip50Relay] = SearchSourceFailed(
          reason: SearchSourceFailureReason.timeout,
          latencyMs: phase3Watch.elapsedMilliseconds,
        );
        Log.warning(
          'NIP-50 search timed out after ${_nip50SearchTimeout.inSeconds}s',
          name: 'ProfileRepository.searchUsersProgressive',
          category: LogCategory.relay,
        );
      } on Object catch (e) {
        // WebSocket failures surface as StateError (an Error, not
        // Exception), so we catch Object.
        sources[SearchSource.nip50Relay] = SearchSourceFailed(
          reason: SearchSourceFailureReason.other,
          latencyMs: phase3Watch.elapsedMilliseconds,
        );
        Log.warning(
          'NIP-50 search failed (${e.runtimeType})',
          name: 'ProfileRepository.searchUsersProgressive',
          category: LogCategory.relay,
        );
      }

      if (resultMap.length > preWsCount) {
        final enriched = await _enrichFromCache(
          resultMap.values.toList(),
          cancellationToken: cancellationToken,
        );
        if (_isSearchCancelled(cancellationToken)) return;
        final result = snapshot(
          isComplete: true,
          enriched: _applyFilter(
            trimmed,
            enriched,
            useServerSort,
            boostPubkeys,
            sortBy: sortBy,
          ),
        );
        _logSearchSummary(result);
        yield result;
        return;
      }
    } else {
      sources[SearchSource.nip50Relay] = const SearchSourceSkipped();
    }

    // Final yield: enriched + filtered (when WS didn't add anything or
    // was skipped due to offset > 0)
    if (_isSearchCancelled(cancellationToken)) return;
    final enriched = await _enrichFromCache(
      resultMap.values.toList(),
      cancellationToken: cancellationToken,
    );
    if (_isSearchCancelled(cancellationToken)) return;
    final result = snapshot(
      isComplete: true,
      enriched: _applyFilter(
        trimmed,
        enriched,
        useServerSort,
        boostPubkeys,
        sortBy: sortBy,
      ),
    );
    _logSearchSummary(result);
    yield result;
  }

  void _logSearchSummary(ProgressiveSearchResult result) {
    String describe(SearchSourceStatus status) => switch (status) {
      SearchSourcePending() => 'pending',
      SearchSourceSkipped() => 'skipped',
      SearchSourceSuccess(:final resultCount, :final latencyMs) =>
        'success(count=$resultCount,latencyMs=$latencyMs)',
      SearchSourceFailed(:final reason, :final latencyMs) =>
        'failed(reason=${reason.name},latencyMs=$latencyMs)',
    };

    Log.info(
      'Search summary: total=${result.profiles.length}, '
      'local=${describe(result.sources[SearchSource.localCache]!)}, '
      'api=${describe(result.sources[SearchSource.funnelcakeApi]!)}, '
      'relay=${describe(result.sources[SearchSource.nip50Relay]!)}',
      name: 'ProfileRepository.searchUsersProgressive',
      category: LogCategory.api,
    );
  }

  /// Applies the configured search filter or falls back to name matching,
  /// removes blocked/muted users, and optionally promotes [boostPubkeys]
  /// to the front while preserving relative order.
  List<UserProfile> _applyFilter(
    String query,
    List<UserProfile> profiles,
    bool useServerSort,
    Set<String>? boostPubkeys, {
    String? sortBy,
  }) {
    List<UserProfile> filtered;
    if (useServerSort) {
      filtered = _rankSearchResults(query, profiles, sortBy);
    } else if (_profileSearchFilter != null) {
      filtered = _profileSearchFilter(query, profiles);
    } else {
      final queryLower = query.toLowerCase();
      filtered = profiles.where((profile) {
        return profile.bestDisplayName.toLowerCase().contains(queryLower);
      }).toList();
    }

    final blockFilter = _blockFilter;
    if (blockFilter != null) {
      filtered = filtered.where((p) => !blockFilter(p.pubkey)).toList();
    }

    if (!useServerSort) return _boostProfiles(filtered, boostPubkeys);
    return _boostBehindExactMatches(query, filtered, boostPubkeys);
  }

  /// Applies the follow-graph boost without letting it bury an exact account
  /// match. Exact matches stay first, followed ones ahead of unfollowed, and
  /// the boost then orders everything else; otherwise three followed partial
  /// matches would push the exact account out of the three-row preview.
  List<UserProfile> _boostBehindExactMatches(
    String query,
    List<UserProfile> profiles,
    Set<String>? boostPubkeys,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    final queryHex = _npubQueryToHex(normalizedQuery);
    final exact = <UserProfile>[];
    final rest = <UserProfile>[];
    for (final profile in profiles) {
      final relevance = _searchRelevance(profile, normalizedQuery, queryHex);
      (relevance == _exactMatchRelevance ? exact : rest).add(profile);
    }
    return [
      ..._boostProfiles(exact, boostPubkeys),
      ..._boostProfiles(rest, boostPubkeys),
    ];
  }

  /// Orders people search by textual relevance before popularity.
  ///
  /// Funnelcake's follower sort remains a useful tie-breaker, but an exact
  /// account match must never be buried beneath popular substring matches.
  static List<UserProfile> _rankSearchResults(
    String query,
    List<UserProfile> profiles,
    String? sortBy,
  ) {
    final popularityRanked = _rankServerSortedPage(profiles, sortBy);
    final popularityIndex = {
      for (final (index, profile) in popularityRanked.indexed)
        profile.pubkey: index,
    };
    final normalizedQuery = query.trim().toLowerCase();
    final queryHex = _npubQueryToHex(normalizedQuery);
    final relevanceByPubkey = {
      for (final profile in profiles)
        profile.pubkey: _searchRelevance(profile, normalizedQuery, queryHex),
    };
    return [...profiles]..sort((a, b) {
      final relevance = relevanceByPubkey[b.pubkey]!.compareTo(
        relevanceByPubkey[a.pubkey]!,
      );
      if (relevance != 0) return relevance;
      return popularityIndex[a.pubkey]!.compareTo(popularityIndex[b.pubkey]!);
    });
  }

  /// Relevance tier of [profile] for an already lowercased, trimmed
  /// [normalizedQuery]. [queryHex] is the decoded form when the query is an
  /// npub, so an exact account match never depends on encoding every
  /// candidate's pubkey.
  static int _searchRelevance(
    UserProfile profile,
    String normalizedQuery,
    String? queryHex,
  ) {
    final pubkey = profile.pubkey.toLowerCase();
    final name = profile.name?.trim().toLowerCase() ?? '';
    final displayName = profile.displayName?.trim().toLowerCase() ?? '';
    final nip05 = profile.nip05?.trim().toLowerCase() ?? '';
    final nip05Name = nip05.split('@').first;

    if (pubkey == queryHex ||
        {pubkey, name, displayName, nip05, nip05Name}.contains(
          normalizedQuery,
        )) {
      return _exactMatchRelevance;
    }
    if (name.startsWith(normalizedQuery) ||
        displayName.startsWith(normalizedQuery) ||
        nip05Name.startsWith(normalizedQuery)) {
      return 3;
    }
    if (_hasWordPrefix(name, normalizedQuery) ||
        _hasWordPrefix(displayName, normalizedQuery)) {
      return 2;
    }
    if (name.contains(normalizedQuery) ||
        displayName.contains(normalizedQuery) ||
        nip05.contains(normalizedQuery)) {
      return 1;
    }
    return 0;
  }

  /// Relevance tier returned by [_searchRelevance] for an exact identifier,
  /// username, display name, or NIP-05 match.
  static const _exactMatchRelevance = 4;

  static bool _hasWordPrefix(String value, String query) =>
      value.split(RegExp(r'\s+')).any((word) => word.startsWith(query));

  /// Hex pubkey for a complete `npub1…` [query], `null` for anything else.
  ///
  /// The cache and the REST payload carry hex, so a pasted npub has to be
  /// decoded before it can match an account. Partial npubs cannot decode and
  /// are left to the textual tiers.
  static String? _npubQueryToHex(String query) {
    final normalized = query.trim().toLowerCase();
    if (!Nip19.isPubkey(normalized) || normalized.length != _npubLength) {
      return null;
    }
    final hex = Nip19.decode(normalized);
    return hex.isEmpty ? null : hex;
  }

  /// Length of a bech32 `npub1…` string: the prefix plus 52 data characters
  /// and a 6-character checksum.
  static const _npubLength = 63;

  /// Orders a server-sorted result page by the signals the REST payload
  /// actually carries.
  ///
  /// For a `followers` sort, ranks by REST `follower_count` descending, then
  /// REST `video_count` descending, then server index. The video tie-breaker
  /// is what orders archive-imported profiles, which all carry
  /// `follower_count: 0`, and it also separates equally followed profiles.
  /// Profiles the viewer follows are promoted ahead of this ordering by the
  /// outer `_boostProfiles` step. Kind 0 Vine archive metrics are
  /// intentionally not used here because they are different quantities.
  static List<UserProfile> _rankServerSortedPage(
    List<UserProfile> profiles,
    String? sortBy,
  ) {
    if (sortBy != profileSearchSortFollowers || profiles.isEmpty) {
      return profiles;
    }

    final indexed =
        <(int, UserProfile)>[
          for (var i = 0; i < profiles.length; i++) (i, profiles[i]),
        ]..sort((a, b) {
          final aFollowers = a.$2.restFollowerCount ?? 0;
          final bFollowers = b.$2.restFollowerCount ?? 0;
          final byFollowers = bFollowers.compareTo(aFollowers);
          if (byFollowers != 0) return byFollowers;

          final byVideos = (b.$2.restVideoCount ?? 0).compareTo(
            a.$2.restVideoCount ?? 0,
          );
          return byVideos != 0 ? byVideos : a.$1.compareTo(b.$1);
        });
    return [for (final entry in indexed) entry.$2];
  }

  /// Moves profiles whose pubkey is in [boostPubkeys] to the front of
  /// [profiles] while preserving the server-relative order within each
  /// group.
  List<UserProfile> _boostProfiles(
    List<UserProfile> profiles,
    Set<String>? boostPubkeys,
  ) {
    if (boostPubkeys == null || boostPubkeys.isEmpty) return profiles;
    final boosted = <UserProfile>[];
    final rest = <UserProfile>[];
    for (final profile in profiles) {
      if (boostPubkeys.contains(profile.pubkey)) {
        boosted.add(profile);
      } else {
        rest.add(profile);
      }
    }
    if (boosted.isEmpty) return profiles;
    return [...boosted, ...rest];
  }

  /// Fetches a user profile from the Funnelcake REST API.
  ///
  /// Returns a [UserProfileResult] if the user is known to Funnelcake, or
  /// `null` if the user was not found or the API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<UserProfileResult?> getUserProfileFromApi({
    required String pubkey,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getUserProfile(pubkey);
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

  /// Fetches multiple user profiles in bulk from the Funnelcake REST API.
  ///
  /// Returns a [BulkProfilesResponse] containing a map of pubkey to profile
  /// data.
  /// Returns null if Funnelcake API is not available.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<BulkProfilesResponse?> getBulkProfilesFromApi(
    List<String> pubkeys,
  ) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getBulkProfiles(pubkeys);
  }

  /// Fetches profiles for multiple pubkeys using a layered
  /// strategy.
  ///
  /// Pipeline:
  /// 1. Batch-read Drift for cached profiles
  /// 2. [FunnelcakeApiClient.getBulkProfiles] for uncached
  /// 3. Connected relays and indexer relays —
  ///    both fired **in parallel** for remaining pubkeys
  /// 4. Batch-write all freshly fetched profiles to Drift
  ///
  /// Errors from the API or relay layers are caught and
  /// logged — partial results are returned rather than
  /// throwing.
  @override
  Future<Map<String, UserProfile>> fetchBatchProfiles({
    required List<String> pubkeys,
    bool ignoreBlockFilter = false,
  }) async {
    if (pubkeys.isEmpty) return {};

    final results = <String, UserProfile>{};
    final remaining = Set<String>.of(pubkeys);

    Map<String, UserProfile> filteredResults() {
      final blockFilter = _blockFilter;
      if (!ignoreBlockFilter && blockFilter != null) {
        results.removeWhere((pubkey, _) => blockFilter(pubkey));
      }
      return results;
    }

    // Step 1: Batch-read Drift cache
    final cached = await _userProfilesDao.getProfilesByPubkeys(pubkeys);
    for (final profile in cached) {
      results[profile.pubkey] = profile;
      remaining.remove(profile.pubkey);
    }
    // Same rule as [fetchFreshProfile]: an evicted account leaves no cached
    // row, so it would otherwise ride in every bulk request and re-run the
    // eviction each time. [revalidateVanishOnce] carries the self-heal.
    remaining.removeWhere((pubkey) {
      if (!_vanished.contains(pubkey)) return false;
      revalidateVanishOnce(pubkey);
      return true;
    });
    if (remaining.isEmpty) return filteredResults();

    Log.debug(
      'Batch fetch: ${cached.length} cached, ${remaining.length} uncached',
      name: 'ProfileRepository.fetchBatchProfiles',
      category: LogCategory.api,
    );

    final toCache = <UserProfile>[];

    // Step 2: Funnelcake REST API for uncached
    if (_funnelcakeApiClient?.isAvailable ?? false) {
      try {
        final bulkResponse = await _funnelcakeApiClient!.getBulkProfiles(
          remaining.toList(),
        );
        for (final entry in bulkResponse.profiles.entries) {
          final pubkey = entry.key;
          final result = entry.value;

          switch (result) {
            case UserProfileVanished():
              // Erased account — evict rather than hydrate, and stop the relay
              // fallback from filling the gap back in.
              await _applyVanish(pubkey);
              remaining.remove(pubkey);
            case UserProfileNotPublished():
              // Funnelcake explicitly established that the user has no Kind 0.
              // Record that evidence and skip the unnecessary relay fallback.
              await _clearVanish(pubkey);
              _confirmedMissing.add(pubkey);
              remaining.remove(pubkey);
            case UserProfileFound():
              await _clearVanish(pubkey);
              final profile = UserProfile.fromUserProfileFound(
                result,
                eventIdPrefix: 'rest-bulk',
              );
              results[pubkey] = profile;
              toCache.add(profile);
              remaining.remove(pubkey);
          }
        }
      } on Exception catch (e) {
        Log.warning(
          'Batch REST fetch failed: $e',
          name: 'ProfileRepository.fetchBatchProfiles',
          category: LogCategory.api,
        );
      }
    }

    // Step 3: Connected relays and indexer relays in parallel
    if (remaining.isNotEmpty) {
      final remainingList = remaining.toList();

      // Connected relay fetches (one per pubkey, in parallel)
      final relayFuture = Future.wait(
        remainingList.map(
          (pubkey) => Future.sync(() => _nostrClient.fetchProfile(pubkey))
              .catchError((Object e) {
                Log.warning(
                  'Batch connected relay fetch failed for '
                  '${pubkeyForLogs(pubkey)}: $e',
                  name: 'ProfileRepository.fetchBatchProfiles',
                  category: LogCategory.relay,
                );
                return null;
              }, test: (_) => true),
        ),
      );

      // Indexer relay batch query
      final indexerFuture =
          Future.sync(
            () => _nostrClient.queryEvents(
              [
                Filter(
                  kinds: [0],
                  authors: remainingList,
                  limit: remainingList.length,
                ),
              ],
              tempRelays: _indexerRelays,
              useCache: false,
            ),
          ).timeout(const Duration(seconds: 5)).catchError((Object e) {
            Log.warning(
              'Batch indexer fetch failed: $e',
              name: 'ProfileRepository.fetchBatchProfiles',
              category: LogCategory.relay,
            );
            return <Event>[];
          }, test: (_) => true);

      final (relayEvents, indexerEvents) = await (
        relayFuture,
        indexerFuture,
      ).wait;

      // Collect all profiles per pubkey, pick newest by createdAt.
      final candidates = <String, List<UserProfile>>{};

      void collectEvent(Event? event) {
        if (event == null || event.kind != 0) return;
        final profile = UserProfile.fromNostrEvent(event);
        if (!remaining.contains(profile.pubkey)) return;
        (candidates[profile.pubkey] ??= []).add(profile);
      }

      relayEvents.forEach(collectEvent);
      indexerEvents.forEach(collectEvent);

      if (indexerEvents.isNotEmpty) {
        Log.debug(
          'Indexer fallback: found ${indexerEvents.length} profiles',
          name: 'ProfileRepository.fetchBatchProfiles',
          category: LogCategory.relay,
        );
      }

      // Pick the newest profile per pubkey.
      for (final entry in candidates.entries) {
        final newest = entry.value.reduce(
          (a, b) => b.createdAt.isAfter(a.createdAt) ? b : a,
        );
        results[entry.key] = newest;
        toCache.add(newest);
        remaining.remove(entry.key);
      }
    }

    // Step 4: Batch-write all freshly fetched to Drift.
    //
    // Writes to the DAO directly rather than through cacheProfile, so both of
    // that method's in-memory guards have to be applied here too. The vanish
    // check, or a relay copy of an erased account slips back into the cache
    // via the batch path. The confirmed-missing clear, or a pubkey an earlier
    // batch recorded as having no Kind 0 keeps that verdict after this batch
    // resolved a profile for it.
    toCache.removeWhere((profile) => _vanished.contains(profile.pubkey));
    if (toCache.isNotEmpty) {
      final resolved = toCache.map((profile) => profile.pubkey).toList();
      _knownCached.addAll(resolved);
      _confirmedMissing.removeAll(resolved);
      await _userProfilesDao.upsertProfiles(toCache);
    }

    // Still-remaining pubkeys are indeterminate: an empty result cannot
    // distinguish absence from a failed, timed-out, or incomplete source.
    // Only an explicit server sentinel establishes confirmed absence.

    filteredResults();

    Log.debug(
      'Batch complete: ${results.length}/${pubkeys.length} resolved, '
      '${remaining.length} still missing',
      name: 'ProfileRepository.fetchBatchProfiles',
      category: LogCategory.api,
    );

    return results;
  }

  /// Enriches search results from the local SQLite cache.
  ///
  /// For each profile, fills in null fields (picture, about, etc.) from
  /// the cached version without overwriting data from search results.
  Future<List<UserProfile>> _enrichFromCache(
    List<UserProfile> profiles, {
    SearchCancellationToken? cancellationToken,
  }) async {
    final enriched = <UserProfile>[];
    var cacheHits = 0;
    var pictureEnriched = 0;
    for (final profile in profiles) {
      if (_isSearchCancelled(cancellationToken)) break;
      final cached = await _userProfilesDao.getProfile(profile.pubkey);
      if (_isSearchCancelled(cancellationToken)) break;
      if (cached == null) {
        enriched.add(profile);
        continue;
      }
      cacheHits++;
      final hadPicture = profile.picture != null;
      final cachedHasPicture = cached.picture != null;
      final willEnrichPicture = !hadPicture && cachedHasPicture;
      if (willEnrichPicture) pictureEnriched++;
      enriched.add(
        profile.copyWith(
          name: profile.name ?? cached.name,
          displayName: profile.displayName ?? cached.displayName,
          about: profile.about ?? cached.about,
          picture: profile.picture ?? cached.picture,
          banner: profile.banner ?? cached.banner,
          website: profile.website ?? cached.website,
          nip05: profile.nip05 ?? cached.nip05,
          lud16: profile.lud16 ?? cached.lud16,
          lud06: profile.lud06 ?? cached.lud06,
        ),
      );
    }
    Log.debug(
      'Enrichment summary: ${profiles.length} profiles, '
      '$cacheHits cache hits, $pictureEnriched pictures enriched',
      name: 'ProfileRepository._enrichFromCache',
      category: LogCategory.storage,
    );
    return enriched;
  }
}
