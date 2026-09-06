// ABOUTME: Content blocklist service for filtering unwanted content from feeds
// ABOUTME: Tracks our blocks, our kind-10000 mutes, and mutual block/mute state
// ABOUTME: Persists to SharedPreferences and publishes the kind 10000 mute list

import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/src/blocklist_change.dart';
import 'package:content_policy/content_policy.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// SharedPreferences key for persisted block list
const _blockedUsersPrefsKey = 'blocked_users_list';

/// SharedPreferences key for our own kind-10000 muted authors
const _mutedUsersPrefsKey = 'muted_users_list';

/// SharedPreferences key for severed followers (follow broken by block)
const _severedFollowersPrefsKey = 'severed_followers_list';

/// SharedPreferences key for unblocks whose kind 10000 publish has not been
/// confirmed, as `pubkey -> unblocked-at` in Unix seconds.
///
/// A block that never reached the relay is derivable after a restart -- it is
/// in `_blockedUsersPrefsKey` and absent from the list the relay serves back.
/// An unblock is not: once the pubkey leaves the block set, "the user
/// unblocked them" and "another client muted them" are the same state. The
/// timestamp is what separates the two, against the list's `created_at`
/// (#8263).
const _pendingUnblocksPrefsKey = 'pending_unblocks';

/// SharedPreferences key recording which account's per-account state the
/// persisted sets belong to. Written on identity adoption so the next
/// construction hydrates the right account before auth resolves.
const _activePubkeyPrefsKey = 'blocklist_active_pubkey';

/// SharedPreferences key prefix recording that the one-time migration of a
/// legacy kind 30000 (d=block) block list into the standard kind 10000 mute
/// list has completed for an account. Scoped per account as `base.pubkey`.
const _blockListMigratedPrefsKeyBase = 'block_list_migrated_to_mute_list';

/// SharedPreferences key prefix recording that an account's legacy kind 30000
/// (d=block) list has been replaced with an empty one, so this app never has
/// to touch that kind again. Scoped per account as `base.pubkey`.
const _blockListRetiredPrefsKeyBase = 'block_list_retired';

class _MuteListPublishShape {
  const _MuteListPublishShape({required this.tags, required this.content});

  final List<List<String>> tags;
  final String content;
}

/// Service for managing content blocklist
///
/// This service maintains an internal blocklist of npubs whose content
/// should be filtered from all general feeds (home, explore, hashtag feeds).
/// Users can still explicitly visit blocked profiles if they choose to
/// follow them.
///
/// Blocks are persisted to SharedPreferences for survival across restarts,
/// and published to Nostr as the standard NIP-51 kind 10000 mute list so
/// they interoperate with other clients (Amethyst, Damus, etc.) and the
/// Divine backend (#4037). Kind 10000 is the only list this app authors for
/// blocks; the non-standard kind 30000 (d=block) list it used to dual-write
/// is retired once per account by [_retireLegacyBlockList] (#5462).
///
/// Kind 30000 is still *read* for other authors, because clients that have
/// not upgraded yet keep publishing their blocks there and [hasBlockedUs]
/// drives blockee-side gating.
class ContentBlocklistRepository {
  /// Creates a [ContentBlocklistRepository].
  ///
  /// [prefs] is used to persist blocks across app restarts. Pass `null` for
  /// in-memory-only operation (e.g. in tests).
  /// [onChanged] is invoked whenever the blocklist changes so listeners
  /// can refresh dependent state.
  ContentBlocklistRepository({
    SharedPreferences? prefs,
    void Function()? onChanged,
  }) : _prefs = prefs,
       _onChanged = onChanged {
    // Initialize with the specific npub requested
    _addInitialBlockedContent();
    _activeAccountPubkey = _prefs?.getString(_activePubkeyPrefsKey);
    final seededAccount = _activeAccountPubkey;
    _scopedBasesPresentAtConstruction = seededAccount == null
        ? const <String>{}
        : <String>{
            for (final base in {
              ..._legacySetsByBase.keys,
              _pendingUnblocksPrefsKey,
            })
              if (_prefs?.getString('$base.$seededAccount') != null) base,
          };
    _loadBlockedUsers();
    _loadMutedUsers();
    _loadSeveredFollowers();
    _loadPendingUnblocks();
    Log.info(
      'ContentBlocklistRepository initialized with '
      '$totalBlockedCount blocked accounts',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );
  }

  final SharedPreferences? _prefs;
  final void Function()? _onChanged;
  // Internal blocklist of public keys (hex format) - kept empty for now
  static const Set<String> _internalBlocklist = {
    // Add blocked public keys here in hex format if needed
  };

  // Runtime blocklist (can be modified)
  final Set<String> _runtimeBlocklist = <String>{};

  // Mutual mute blocklist (populated from kind 10000 events)
  final Set<String> _mutualMuteBlocklist = <String>{};

  // Authors muted on our own kind 10000 mute list from *other* clients.
  // Our own in-app blocks live in [_runtimeBlocklist] and are deliberately
  // excluded from this set (see [_handleOwnMuteListEvent]) so republishing
  // the merged mute list stays idempotent and unblocking actually removes
  // the entry. The newest own kind 10000 event replaces this set wholesale.
  // Only public 'p' tags are interpreted as authored mutes. Other NIP-51
  // public mute tags and encrypted private entries are preserved verbatim
  // from [_latestOwnMuteListEvent] when we republish.
  final Set<String> _mutedPubkeys = <String>{};

  // Full latest own kind-10000 event, retained so republishing Divine blocks
  // preserves other clients' public t/word/e mutes and encrypted content.
  Event? _latestOwnMuteListEvent;

  // A mute-list publish that was withheld because the read that precedes it
  // came back inconclusive. Flushed by [retryPendingMuteListPublish] and by
  // the next block or unblock, which republishes the whole list anyway.
  bool _muteListPublishPending = false;

  // Unblocks whose removal from the published kind 10000 is not yet
  // confirmed, as pubkey -> unblocked-at in Unix seconds. Persisted, because
  // the whole point is to survive the restart that loses
  // [_muteListPublishPending].
  final Map<String, int> _pendingUnblocks = <String, int>{};

  // Latest replaceable kind-10000 mute-list event timestamp per author.
  // Prevent stale relay delivery order from resurrecting old mute state.
  final Map<String, int> _latestMuteListEventCreatedAtByAuthor =
      <String, int>{};

  // Users who have blocked us (populated from kind 30000 events with d=block)
  final Set<String> _blockedByOthers = <String>{};

  // Direct by-author watches on the lists of everyone who blocks or mutes
  // us. The `#p = us` discovery filters cannot observe a block/mute being
  // *lifted*; see [_AuthorListWatch] for why.
  final _AuthorListWatch _blockAuthorWatch = _AuthorListWatch(
    kind: 30000,
    label: 'block-list',
  );
  final _AuthorListWatch _muteAuthorWatch = _AuthorListWatch(
    kind: 10000,
    label: 'mute-list',
  );

  // Latest replaceable kind-30000 block-list event timestamp per author.
  // Prevent stale relay delivery order from resurrecting old block state.
  final Map<String, int> _latestBlockListEventCreatedAtByAuthor =
      <String, int>{};

  // Followers whose follow relationship was severed by a block.
  // Persists across unblocking so these users remain hidden from our
  // followers list until they explicitly re-follow.
  final Set<String> _severedFollowers = <String>{};

  // Persisted sets that migrate from legacy un-namespaced keys, by key.
  late final Map<String, Set<String>> _legacySetsByBase = {
    _blockedUsersPrefsKey: _runtimeBlocklist,
    _mutedUsersPrefsKey: _mutedPubkeys,
    _severedFollowersPrefsKey: _severedFollowers,
  };

  // Scoped keys of the seeded account that already held data when this
  // instance hydrated. _migrateLegacyKeys treats those as authoritative
  // over the legacy snapshot; a scoped key that appears later in the
  // session was written by a save racing the migration and must be
  // merged with the legacy data, not preferred over it.
  late final Set<String> _scopedBasesPresentAtConstruction;

  final _stateController = StreamController<ContentPolicyState>.broadcast();

  // Granular per-pubkey change events. Subscribers (e.g. VideoEventService)
  // react per-author rather than diffing snapshots from [stateStream].
  // See [changes] for the public getter.
  final _changesController = StreamController<BlocklistChange>.broadcast();

  // Subscription tracking for mutual mutes
  String? _mutualMuteSubscriptionId;
  bool _mutualMuteSyncStarted = false;
  String? _ourPubkey;

  // Account whose persisted sets are currently loaded. Seeded from prefs at
  // construction so hydration covers the window before auth resolves;
  // corrected by [_adoptIdentity] once the session identity is known.
  String? _activeAccountPubkey;

  // Subscription tracking for block list sync
  bool _blockListSyncStarted = false;

  // Services for Nostr publishing (injected via sync methods)
  BlockListSigner? _signer;
  NostrClient? _nostrClient;

  // The client each background sync actually subscribed on. Tracked per
  // sync path, not off the shared _nostrClient: the app starts both syncs
  // in one turn (moderation_providers.dart), and neither body awaits, so
  // whichever runs first would otherwise overwrite _nostrClient and hide
  // the client swap from the other.
  NostrClient? _mutualMuteSyncClient;
  NostrClient? _blockListSyncClient;

  /// A synchronous snapshot of the current policy state.
  ContentPolicyState get currentState => _buildCurrentState();

  /// Emits a new [ContentPolicyState] snapshot whenever the policy changes.
  Stream<ContentPolicyState> get stateStream => _stateController.stream;

  /// Emits per-pubkey [BlocklistChange] events the moment the
  /// composition mutates (block, unblock, mute, unmute, externally-applied
  /// changes).
  ///
  /// Subscribers should use this stream when they need to react to a
  /// specific pubkey transitioning into or out of a hide-bucket — e.g.
  /// dropping that author's videos from open feed surfaces. Diffing the
  /// snapshots from [stateStream] would also work but is brittle and
  /// allocation-heavy.
  ///
  /// Broadcast semantics: late subscribers do not receive past emissions;
  /// the canonical truth is [currentState] / the contains-checks.
  Stream<BlocklistChange> get changes => _changesController.stream;

  ContentPolicyState _buildCurrentState() => ContentPolicyState(
    currentUserPubkey: _ourPubkey,
    mutedPubkeys: Set.unmodifiable(_mutedPubkeys),
    blockedPubkeys: Set.unmodifiable({
      ..._internalBlocklist,
      ..._runtimeBlocklist,
    }),
    pubkeysBlockingUs: Set.unmodifiable(_blockedByOthers),
    pubkeysMutingUs: Set.unmodifiable(_mutualMuteBlocklist),
  );

  void _notifyChanged() {
    _onChanged?.call();
    if (!_stateController.isClosed) {
      _stateController.add(_buildCurrentState());
    }
  }

  /// Emit a granular change on [changes]. Call sites pair this with
  /// [_notifyChanged] so the broad-state listeners and the per-pubkey
  /// listeners stay in sync.
  void _emitChange(BlocklistChange change) {
    if (!_changesController.isClosed) {
      _changesController.add(change);
    }
  }

  void _addInitialBlockedContent() {
    // No hardcoded blocks - moderation should happen at relay level
    // Users can still block individuals via the app UI
  }

  /// Storage key for [base] scoped to the active account.
  ///
  /// Falls back to the legacy un-namespaced key while no account has been
  /// adopted yet (pre-auth or pre-migration installs).
  String _scopedKey(String base) {
    final account = _activeAccountPubkey;
    return account == null ? base : '$base.$account';
  }

  /// Adopts [pubkey] as the session identity, resetting state that
  /// belongs to a different account.
  ///
  /// All in-memory sets are keyed to one identity: `_blockedByOthers` /
  /// `_mutualMuteBlocklist` hold who blocks/mutes *us*, and the persisted
  /// sets are stored per account. Before this existed, the keepAlive
  /// repository carried account A's state into account B after a switch,
  /// filtering the wrong authors and showing false "account not
  /// available" gates (#4969).
  void _adoptIdentity(String pubkey) {
    if (_ourPubkey == pubkey) return;
    final isSwitch = _ourPubkey != null;
    final storedAccountDiffers =
        _activeAccountPubkey != null && _activeAccountPubkey != pubkey;

    _ourPubkey = pubkey;

    if (isSwitch || storedAccountDiffers) {
      _runtimeBlocklist.clear();
      _mutedPubkeys.clear();
      _mutualMuteBlocklist.clear();
      _blockedByOthers.clear();
      _latestOwnMuteListEvent = null;
      _muteListPublishPending = false;
      _pendingUnblocks.clear();
      _latestMuteListEventCreatedAtByAuthor.clear();
      _latestBlockListEventCreatedAtByAuthor.clear();
      _severedFollowers.clear();
      // "Who blocks/mutes us" is meaningless for the incoming account.
      _blockAuthorWatch.clear();
      _muteAuthorWatch.clear();
      // Force fresh subscriptions filtered on the new pubkey. On a
      // same-client switch the old subscription's listener is
      // intentionally left in place (no handle is retained to cancel
      // it); its deliveries stay harmless because every handler
      // re-checks the live _ourPubkey at delivery time.
      _mutualMuteSyncStarted = false;
      _blockListSyncStarted = false;
    }

    // Legacy un-namespaced data predates per-account keys and follows
    // the first identity that signed in; the move no-ops for any other
    // account. Must run before _activeAccountPubkey is reassigned.
    unawaited(_migrateLegacyKeys(pubkey));

    _activeAccountPubkey = pubkey;
    unawaited(_saveActiveAccountPubkey(pubkey));

    if (isSwitch || storedAccountDiffers) {
      _loadBlockedUsers();
      _loadMutedUsers();
      _loadSeveredFollowers();
      _loadPendingUnblocks();
      _notifyChanged();
      Log.info(
        'Adopted new identity; blocklist state reset and reloaded '
        '(${_runtimeBlocklist.length} persisted blocks)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Persists which account the per-account sets belong to.
  ///
  /// Failures are logged and swallowed — persistence must never break
  /// the in-memory blocklist, matching the other save methods.
  Future<void> _saveActiveAccountPubkey(String pubkey) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_activePubkeyPrefsKey, pubkey);
    } on Object catch (e) {
      Log.error(
        'Failed to persist active blocklist account: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Moves legacy un-namespaced persisted sets to [pubkey]'s scoped keys.
  ///
  /// Runs while no account was ever adopted on this install, or while
  /// [pubkey] is the recorded account — so a move that failed on a
  /// previous launch is retried instead of orphaning the legacy data.
  /// Legacy values merge into the in-memory sets synchronously (a no-op
  /// when construction already hydrated them) and persist via full-set
  /// writes; a legacy key is removed only once its data is confirmed
  /// under the scoped key, so a partial failure never destroys data.
  Future<void> _migrateLegacyKeys(String pubkey) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (_activeAccountPubkey != null && _activeAccountPubkey != pubkey) {
      return;
    }

    // Decide and merge synchronously so no concurrent write can land
    // between reading a legacy value and folding it into memory.
    final pendingMoves = <String, Set<String>>{};
    final staleBases = <String>[];
    var recovered = false;
    for (final entry in _legacySetsByBase.entries) {
      final base = entry.key;
      final legacy = prefs.getString(base);
      if (legacy == null || legacy.isEmpty) continue;
      final scopedExists = prefs.getString('$base.$pubkey') != null;
      if (scopedExists &&
          (_scopedBasesPresentAtConstruction.contains(base) ||
              _activeAccountPubkey == null)) {
        // A scoped value that predates this adoption is authoritative:
        // merging the stale legacy snapshot could resurrect entries
        // deleted since the original copy. (Before first adoption,
        // saves write the legacy key itself, so a scoped value can
        // only be a leftover from an earlier partially-failed
        // migration — while for the recorded account, one that was
        // absent at construction was written by a save racing this
        // migration and is merged below instead.)
        staleBases.add(base);
        continue;
      }
      try {
        final decoded = (jsonDecode(legacy) as List<dynamic>).cast<String>();
        final target = entry.value;
        final sizeBefore = target.length;
        target.addAll(decoded);
        recovered = recovered || target.length != sizeBefore;
        pendingMoves[base] = target;
      } on Object catch (e) {
        Log.error(
          'Skipping corrupt legacy blocklist key $base: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }
    if (recovered) {
      // A retried move recovered data that construction could not see;
      // notify so watchers re-filter with it this session.
      _notifyChanged();
    }

    final pendingUnblocksMigration = _migrateLegacyPendingUnblocks(pubkey);

    for (final base in staleBases) {
      try {
        await prefs.remove(base);
      } on Object catch (e) {
        Log.error(
          'Failed to drop stale legacy blocklist key $base: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }

    for (final entry in pendingMoves.entries) {
      // Re-checked before every write: after a mid-flight account
      // switch the live sets belong to the new identity and must not
      // be serialized under [pubkey]'s keys.
      if (_activeAccountPubkey != null && _activeAccountPubkey != pubkey) {
        return;
      }
      try {
        final written = await prefs.setString(
          '${entry.key}.$pubkey',
          jsonEncode(entry.value.toList()),
        );
        if (!written) continue;
        await prefs.remove(entry.key);
      } on Object catch (e) {
        Log.error(
          'Failed to migrate legacy blocklist key ${entry.key}: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }

    await pendingUnblocksMigration;
  }

  Future<void> _migrateLegacyPendingUnblocks(String pubkey) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final legacy = prefs.getString(_pendingUnblocksPrefsKey);
    if (legacy == null || legacy.isEmpty) return;

    final scopedKey = '$_pendingUnblocksPrefsKey.$pubkey';
    final scoped = prefs.getString(scopedKey);
    if (scoped != null &&
        (_scopedBasesPresentAtConstruction.contains(
              _pendingUnblocksPrefsKey,
            ) ||
            _activeAccountPubkey == null)) {
      try {
        final decoded = jsonDecode(scoped) as Map<String, dynamic>;
        _pendingUnblocks
          ..clear()
          ..addEntries(
            decoded.entries
                .where((entry) => entry.value is int)
                .map((entry) => MapEntry(entry.key, entry.value as int)),
          );
        if (_pendingUnblocks.isNotEmpty) _muteListPublishPending = true;
        await prefs.remove(_pendingUnblocksPrefsKey);
        return;
      } on Object catch (e) {
        Log.error(
          'Failed to adopt scoped blocklist key $scopedKey: $e',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }

    try {
      final decoded = jsonDecode(legacy) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final unblockedAt = entry.value;
        if (unblockedAt is! int) continue;
        final current = _pendingUnblocks[entry.key];
        if (current == null || unblockedAt > current) {
          _pendingUnblocks[entry.key] = unblockedAt;
        }
      }
      if (_pendingUnblocks.isNotEmpty) _muteListPublishPending = true;
      final written = await prefs.setString(
        scopedKey,
        jsonEncode(_pendingUnblocks),
      );
      if (written) await prefs.remove(_pendingUnblocksPrefsKey);
    } on Object catch (e) {
      Log.error(
        'Failed to migrate legacy blocklist key '
        '$_pendingUnblocksPrefsKey: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load persisted blocked users from SharedPreferences
  void _loadBlockedUsers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_blockedUsersPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _runtimeBlocklist.addAll(list);
      Log.info(
        'Loaded ${list.length} blocked users from persistence',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted blocked users: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Save blocked users to SharedPreferences
  ///
  /// Awaits the platform write so the block survives an immediate app kill.
  Future<void> _saveBlockedUsers() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_runtimeBlocklist.toList());
      await prefs.setString(_scopedKey(_blockedUsersPrefsKey), json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist blocked users: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load unblocks whose kind 10000 publish was never confirmed.
  ///
  /// The counterpart to [_loadBlockedUsers]: a block that did not reach the
  /// relay is derivable from the two sets, an unblock is not, so the intent
  /// has to survive the restart on its own (#8263).
  void _loadPendingUnblocks() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_pendingUnblocksPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final unblockedAt = entry.value;
        if (unblockedAt is int) _pendingUnblocks[entry.key] = unblockedAt;
      }
      if (_pendingUnblocks.isNotEmpty) _muteListPublishPending = true;
    } on Object catch (e) {
      Log.error(
        'Failed to load pending unblocks: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _savePendingUnblocks() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      await prefs.setString(
        _scopedKey(_pendingUnblocksPrefsKey),
        jsonEncode(_pendingUnblocks),
      );
    } on Object catch (e) {
      Log.error(
        'Failed to persist pending unblocks: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load persisted muted authors from SharedPreferences.
  ///
  /// This is the hydration cache that covers the window between app start
  /// and relay delivery of our own kind 10000 event.
  void _loadMutedUsers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_mutedUsersPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _mutedPubkeys.addAll(list);
      Log.info(
        'Loaded ${list.length} muted authors from persistence',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted muted authors: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Save muted authors to SharedPreferences
  ///
  /// Awaits the platform write so the data survives an immediate app kill.
  Future<void> _saveMutedUsers() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_mutedPubkeys.toList());
      await prefs.setString(_scopedKey(_mutedUsersPrefsKey), json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist muted authors: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Load persisted severed followers from SharedPreferences
  void _loadSeveredFollowers() {
    final prefs = _prefs;
    if (prefs == null) return;

    final stored = prefs.getString(_scopedKey(_severedFollowersPrefsKey));
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      _severedFollowers.addAll(list);
      Log.info(
        'Loaded ${list.length} severed followers from persistence',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to load persisted severed followers: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Save severed followers to SharedPreferences
  ///
  /// Awaits the platform write so the data survives an immediate app kill.
  Future<void> _saveSeveredFollowers() async {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final json = jsonEncode(_severedFollowers.toList());
      await prefs.setString(_scopedKey(_severedFollowersPrefsKey), json);
    } on Object catch (e) {
      Log.error(
        'Failed to persist severed followers: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Check if a follower's relationship was severed by a block
  ///
  /// Returns true if the pubkey was added to severed followers when blocked.
  /// This persists across unblocking so the user stays hidden from our
  /// followers list until they explicitly re-follow.
  bool isFollowSevered(String pubkey) => _severedFollowers.contains(pubkey);

  /// Remove a pubkey from the severed followers set
  ///
  /// Call this when the user explicitly re-follows to restore them
  /// in the followers list.
  void removeSeveredFollower(String pubkey) {
    if (_severedFollowers.remove(pubkey)) {
      unawaited(_saveSeveredFollowers());
      Log.debug(
        'Removed severed follower: ${pubkeyForLogs(pubkey)}',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Publish our mute list to Nostr as a NIP-51 kind 10000 event.
  ///
  /// Blocking a user adds them to the user's standard Nostr mute list so
  /// the block interoperates with other clients (Amethyst, Damus, etc.)
  /// and the Divine backend, all of which key off kind 10000 (#4037).
  ///
  /// Kind 10000 is replaceable, so the event must carry the *entire* list.
  /// We publish the union of our blocks ([_runtimeBlocklist]) and the mutes
  /// authored from other clients ([_mutedPubkeys]) while carrying forward
  /// other public NIP-51 mute tags and encrypted private list content from
  /// the latest own kind 10000 event.
  ///
  /// Returns `true` when the event was accepted by at least one relay.
  Future<bool> _publishMuteListToNostr({
    Set<String> protectedUnblocks = const <String>{},
  }) async {
    // Keep every unsuccessful attempt retryable. This is set before the
    // dependency guards too, because block/unblock actions can race startup.
    _muteListPublishPending = true;
    final signer = _signer;
    final nostrClient = _nostrClient;

    if (signer == null || nostrClient == null) {
      Log.debug(
        'Cannot publish mute list - Nostr services not yet injected',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    }

    if (!signer.isAuthenticated) {
      Log.warning(
        'Cannot publish mute list - user not authenticated',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      if (!await _refreshLatestOwnMuteList(
        nostrClient,
        protectedUnblocks: protectedUnblocks,
      )) {
        // Kind 10000 is replaceable: publishing now would replace a list we
        // could not read. Everything only the unread event holds would go
        // with it -- the encrypted private section, every t/word/e mute, and
        // any p mute authored on another client (#6750). The block is already
        // persisted locally, so withholding costs propagation, not safety.
        Log.warning(
          'Withholding mute list publish - could not confirm the current '
          'kind 10000. Blocks stay local until a read succeeds.',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return false;
      }
      var pendingTimestampChanged = false;
      final latestOwnCreatedAt = _latestOwnMuteListEvent?.createdAt;
      if (latestOwnCreatedAt != null) {
        for (final pubkey in protectedUnblocks) {
          final pendingAt = _pendingUnblocks[pubkey];
          if (pendingAt != null && pendingAt < latestOwnCreatedAt) {
            _pendingUnblocks[pubkey] = latestOwnCreatedAt;
            pendingTimestampChanged = true;
          }
        }
      }
      if (pendingTimestampChanged) await _savePendingUnblocks();
      final publishShape = _buildMuteListPublishShape();

      final event = await signer.createAndSignEvent(
        kind: 10000,
        content: publishShape.content,
        tags: publishShape.tags,
      );

      if (event == null) return false;

      final sentEvent = await nostrClient.publishEvent(event);

      if (sentEvent is PublishSuccess) {
        // Record our own write as the newest seen event so a stale relay
        // echo of an older own mute list cannot race back and drop the
        // mutes we just merged in.
        _applyOwnMuteListEvent(sentEvent.event);
        _muteListPublishPending = false;
        Log.info(
          'Published mute list to Nostr with '
          '${_runtimeBlocklist.length + _mutedPubkeys.length} pubkey entries',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return true;
      }

      Log.warning(
        'Failed to publish mute list event to relays',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    } on Object catch (e) {
      Log.error(
        'Error publishing mute list to Nostr: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Re-read our own latest kind 10000, and report whether the answer was
  /// conclusive.
  ///
  /// Returns `false` when no relay settled the query -- a timeout, or a
  /// fan-out no relay took. That is not the same as "this account has no mute
  /// list", and the difference is load-bearing: kind 10000 is replaceable, so
  /// a caller that publishes on an unread answer deletes whatever only the
  /// unread event held. A *settled* answer of zero events is conclusive and
  /// returns `true`, so a first-ever block still publishes.
  ///
  /// [NostrClient.queryEvents] cannot express this -- it drops `timedOut` and
  /// `noRelays` -- which is why the detailed form is used here, with
  /// `requireAllRelaysSettled` so a relay abandoned by the settle window
  /// arrives as a timeout rather than as an empty answer.
  Future<bool> _refreshLatestOwnMuteList(
    NostrClient nostrClient, {
    Set<String> protectedUnblocks = const <String>{},
  }) async {
    final ourPubkey = _ourPubkey;
    if (ourPubkey == null) return false;

    final result = await nostrClient.queryEventsDetailed(
      [
        Filter(authors: [ourPubkey], kinds: const [10000]),
      ],
      requireAllRelaysSettled: true,
    );

    var newest = _latestOwnMuteListEvent;
    for (final event in result.events) {
      if (event.pubkey != ourPubkey) continue;
      if (newest == null || event.createdAt > newest.createdAt) {
        newest = event;
      }
    }

    if (newest != null && newest != _latestOwnMuteListEvent) {
      _applyOwnMuteListEvent(
        newest,
        protectedUnblocks: protectedUnblocks,
      );
    }

    return !result.timedOut && !result.noRelays;
  }

  /// Republish a mute list whose publish was withheld by an inconclusive read.
  ///
  /// A no-op unless something is pending, so callers can fire it on any
  /// "we might be healthy again" signal. Returns whether a publish reached a
  /// relay. Blocks and unblocks republish the whole list themselves, so this
  /// only matters for a user who blocked once while relays were unhealthy and
  /// has not blocked since.
  Future<bool> retryPendingMuteListPublish() async {
    if (!_muteListPublishPending) return false;
    return _publishMuteListToNostr();
  }

  _MuteListPublishShape _buildMuteListPublishShape() {
    final source = _latestOwnMuteListEvent;
    final tags = <List<String>>[];
    final includedPubkeys = <String>{};
    // A NIP-51 `p` tag can carry a third element -- a relay hint -- that is
    // ours to preserve, not to invent. Keyed by pubkey so an entry we re-emit
    // below keeps whatever the source published. Without this, a pubkey that
    // is both muted on the relay and blocked in-app loses its hint on every
    // republish: `_applyOwnMuteListEvent` keeps our own blocks out of
    // `_mutedPubkeys`, so the preservation loop skips it and the
    // `_runtimeBlocklist` loop rewrites it as a bare ['p', pubkey].
    final sourcePubkeyTags = <String, List<String>>{};

    if (source != null) {
      for (final tag in source.tags) {
        if (tag.isEmpty || tag[0] != 'p') {
          tags.add(List<String>.of(tag));
          continue;
        }

        if (tag.length < 2) continue;
        final pubkey = tag[1];
        sourcePubkeyTags.putIfAbsent(pubkey, () => List<String>.of(tag));
        if (_mutedPubkeys.contains(pubkey) && includedPubkeys.add(pubkey)) {
          tags.add(List<String>.of(tag));
        }
      }
    }

    void addPubkey(String pubkey) {
      if (!includedPubkeys.add(pubkey)) return;
      final sourceTag = sourcePubkeyTags[pubkey];
      tags.add(sourceTag == null ? ['p', pubkey] : List<String>.of(sourceTag));
    }

    _mutedPubkeys.forEach(addPubkey);
    _runtimeBlocklist.forEach(addPubkey);

    return _MuteListPublishShape(tags: tags, content: source?.content ?? '');
  }

  bool _latestOwnMuteListCarries(String pubkey) {
    final source = _latestOwnMuteListEvent;
    if (source == null) return false;
    return source.tags.any(
      (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey,
    );
  }

  /// Whether [pubkey] is still the session identity.
  ///
  /// The startup migration and retirement run fire-and-forget across several
  /// awaits while mutating instance state and publishing through `_signer`.
  /// An account switch mid-sequence would otherwise splice one account's
  /// blocks into the next account's mute list, or erase the incoming
  /// account's legacy list before it has been migrated.
  bool _isStillActiveAccount(String pubkey) => _ourPubkey == pubkey;

  /// Read the pubkeys on our own legacy kind 30000 (d=block) list.
  ///
  /// Returns `null` when no such list was seen at all, which is not the same
  /// as an empty one: a cold relay miss must not be read as "this account has
  /// nothing left to migrate or retire".
  ///
  /// The `d=block` check happens here rather than in the filter because not
  /// all relays support `#d` filtering, and kind 30000 is shared with
  /// unrelated people lists (divine-space publishes `d=top8` follow sets on
  /// it) that must never be ingested as blocks.
  Future<Set<String>?> _readOwnLegacyBlockPubkeys(
    NostrClient nostrClient,
    String ourPubkey,
  ) async {
    final events = await nostrClient.queryEvents([
      Filter(authors: [ourPubkey], kinds: const [30000]),
    ]);
    Set<String>? blocked;
    for (final event in events) {
      if (event.pubkey != ourPubkey) continue;
      final hasBlockDTag = event.tags.any(
        (tag) => tag.length >= 2 && tag[0] == 'd' && tag[1] == 'block',
      );
      if (!hasBlockDTag) continue;
      blocked ??= <String>{};
      for (final tag in event.tags) {
        if (tag.length >= 2 && tag[0] == 'p' && tag[1] != ourPubkey) {
          blocked.add(tag[1]);
        }
      }
    }
    return blocked;
  }

  /// Retire this account's legacy kind 30000 (d=block) list (#5462).
  ///
  /// Blocks are authored on the standard kind 10000 mute list only. Leaving
  /// the legacy list populated but frozen would be worse than removing it:
  /// clients that still read it (divine-web, pre-1.0.16 Divine) would keep
  /// enforcing a block this app can no longer lift. So the list is replaced
  /// once with an empty one and never written again.
  ///
  /// The empty replacement is published rather than an NIP-09 deletion:
  /// tombstoning a replaceable event by id resurrects the version before it.
  ///
  /// Nothing is erased before it reaches the mute list. The gate is the
  /// migration's own per-account flag, which is set only once a relay
  /// accepted the merged mute list — in-memory membership is not evidence
  /// the entries ever left the device, and treating it as such would erase
  /// blocks whose migrate publish had failed.
  ///
  /// A legacy pubkey missing from the runtime blocklist is likewise *not*
  /// treated as a straggler to carry back over. After a confirmed migration
  /// it means the user deliberately unblocked them, and re-publishing it
  /// would resurrect a lifted block — the exact failure #7027 describes.
  ///
  /// The retired flag is set once a relay accepts the empty replacement, or
  /// immediately when the legacy list is already empty and there is nothing
  /// to replace. Any failure retries on the next launch.
  Future<void> _retireLegacyBlockList(
    NostrClient nostrClient,
    BlockListSigner signer,
    String ourPubkey,
  ) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final retiredKey = '$_blockListRetiredPrefsKeyBase.$ourPubkey';
    if (prefs.getBool(retiredKey) ?? false) return;
    if (!signer.isAuthenticated) return;

    await _migrateLegacyBlockListToMuteList(nostrClient, signer, ourPubkey);
    if (!_isStillActiveAccount(ourPubkey)) return;

    try {
      final legacyBlocks = await _readOwnLegacyBlockPubkeys(
        nostrClient,
        ourPubkey,
      );
      if (!_isStillActiveAccount(ourPubkey)) return;

      // No legacy list was seen. Either this account never had one or the
      // relays did not answer; both mean there is nothing to replace, and
      // publishing an empty list anyway would author the very kind this
      // change retires.
      if (legacyBlocks == null) return;
      if (legacyBlocks.isEmpty) {
        await prefs.setBool(retiredKey, true);
        return;
      }

      // The list still carries entries, so erasing it is only safe once the
      // migration has been confirmed accepted by a relay.
      if (!(prefs.getBool('$_blockListMigratedPrefsKeyBase.$ourPubkey') ??
          false)) {
        Log.warning(
          'Legacy block-list retirement deferred: migration onto the mute '
          'list is not yet confirmed',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return;
      }

      final event = await signer.createAndSignEvent(
        kind: 30000,
        content: '',
        tags: const [
          ['d', 'block'],
        ],
      );
      if (event == null) return;
      if (!_isStillActiveAccount(ourPubkey)) return;

      final sentEvent = await nostrClient.publishEvent(event);
      if (sentEvent is! PublishSuccess) {
        Log.warning(
          'Failed to publish the empty legacy block list; retrying next '
          'launch',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return;
      }

      await prefs.setBool(retiredKey, true);

      Log.info(
        'Retired the legacy kind 30000 block list',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to retire the legacy block list: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Check if a public key is blocked
  bool isBlocked(String pubkey) {
    // Check both internal and runtime blocklists
    return _internalBlocklist.contains(pubkey) ||
        _runtimeBlocklist.contains(pubkey);
  }

  /// The buckets recording a hide **this account chose**: the operator list,
  /// our own blocks, and the mutes we authored on our own kind 10000 list
  /// (possibly from another client).
  ///
  /// DM surfaces filter on these alone. A direct message already received is
  /// the viewer's own copy, and a third party must not be able to remove it
  /// by publishing a list — see [_hideBuckets] and #7345.
  late final List<Set<String>> _viewerHideBuckets = [
    _internalBlocklist,
    _runtimeBlocklist,
    _mutedPubkeys,
  ];

  /// The buckets whose union is hidden from feeds, held as live references
  /// to the underlying sets. Every instance is stable for the repository's
  /// lifetime — the `const` internal list plus four `final` sets that are
  /// only ever mutated in place — so both [feedHiddenPubkeys] and
  /// [shouldFilterFromFeeds] derive from this one list and cannot drift.
  ///
  /// This is a strict superset of [_viewerHideBuckets]: it adds the two
  /// buckets fed by *other people's* lists, which suppress our content in
  /// feeds but must never reach a DM surface. A new bucket is added in
  /// exactly one place — [_viewerHideBuckets] when the viewer chose the hide
  /// and it should apply everywhere, here when it is feeds-only.
  late final List<Set<String>> _hideBuckets = [
    ..._viewerHideBuckets,
    _mutualMuteBlocklist,
    _blockedByOthers,
  ];

  /// The union of every pubkey hidden from feeds:
  /// - Users we blocked (internal + runtime blocklist)
  /// - Users we muted via our own kind 10000 mute list
  /// - Users who mutually muted us (kind 10000)
  /// - Users who blocked us (kind 30000, d=block) — hides our content
  ///   from their feeds and their content from ours
  ///
  /// This is the canonical feed-hide set. Feed surfaces that need the
  /// materialized set read this rather than re-deriving the union by hand,
  /// so they stay in lockstep with [shouldFilterFromFeeds]. DM surfaces read
  /// [dmHiddenPubkeys] instead.
  Set<String> get feedHiddenPubkeys => {
    for (final bucket in _hideBuckets) ...bucket,
  };

  /// Whether [pubkey] is in [feedHiddenPubkeys] and so should be filtered
  /// from feeds.
  ///
  /// Implemented as a short-circuiting, allocation-free membership scan
  /// rather than `feedHiddenPubkeys.contains(...)` because this is a hot
  /// path — called per item across ~15 feed surfaces — and materializing
  /// the union on every call would be wasteful.
  bool shouldFilterFromFeeds(String pubkey) {
    for (var i = 0; i < _hideBuckets.length; i++) {
      if (_hideBuckets[i].contains(pubkey)) return true;
    }
    return false;
  }

  /// The union of every pubkey hidden from **DM surfaces**:
  /// - Users we blocked (internal + runtime blocklist)
  /// - Users we muted on our own kind 10000 mute list
  ///
  /// Deliberately excludes the two buckets fed by other people's lists
  /// (`_mutualMuteBlocklist`, `_blockedByOthers`). Publishing a kind 10000
  /// mute or a kind 30000 `d=block` naming the viewer used to remove the
  /// viewer's own copy of a thread from every DM surface at once, including
  /// messages already received and stored on the device (#7345).
  ///
  /// Counterpart to [feedHiddenPubkeys]; both derive from [_hideBuckets] /
  /// [_viewerHideBuckets] so the DM set stays a strict subset of the feed set.
  Set<String> get dmHiddenPubkeys => {
    for (final bucket in _viewerHideBuckets) ...bucket,
  };

  /// Whether [pubkey] is in [dmHiddenPubkeys] and so should be filtered from
  /// DM surfaces.
  ///
  /// Same short-circuiting scan as [shouldFilterFromFeeds], over the narrower
  /// bucket list.
  bool shouldFilterFromDms(String pubkey) {
    for (var i = 0; i < _viewerHideBuckets.length; i++) {
      if (_viewerHideBuckets[i].contains(pubkey)) return true;
    }
    return false;
  }

  /// Check if we muted another user via our own kind 10000 mute list.
  ///
  /// Mutes are authored from other Nostr clients (this app has no mute
  /// action); this reflects the latest own kind 10000 event seen on relays.
  bool isMutedByUs(String pubkey) => _mutedPubkeys.contains(pubkey);

  /// Check if another user has muted us (mutual mute blocking)
  ///
  /// This is different from [isBlocked] which checks users WE blocked.
  /// Use this for profile viewing - users can view profiles they blocked,
  /// but cannot view profiles of users who muted them.
  bool hasMutedUs(String pubkey) => _mutualMuteBlocklist.contains(pubkey);

  /// Check if another user has blocked us via kind 30000 (d=block)
  ///
  /// Use this for blockee-side enforcement - prevent viewing profiles of
  /// users who have blocked us, and prevent following them.
  bool hasBlockedUs(String pubkey) => _blockedByOthers.contains(pubkey);

  /// Add a public key to the runtime blocklist
  ///
  /// Persists to SharedPreferences and publishes the user's kind 10000 mute
  /// list. Awaits the local write so the block survives an immediate app kill.
  /// If [ourPubkey] is provided, it will be used to prevent self-blocking.
  /// Otherwise falls back to [_ourPubkey] set during
  /// [syncMuteListsInBackground].
  Future<void> blockUser(String pubkey, {String? ourPubkey}) {
    return blockUsers([pubkey], ourPubkey: ourPubkey);
  }

  /// Add public keys to the runtime blocklist in one persisted write.
  ///
  /// Persists to SharedPreferences and publishes the user's kind 10000 mute
  /// list once no matter how many new pubkeys are added. Emits one
  /// [BlocklistChange] per newly-blocked pubkey because downstream feed
  /// cleanup reacts per author. An idempotent re-block also flushes a pending
  /// mute-list publish without producing another local change event.
  Future<void> blockUsers(Iterable<String> pubkeys, {String? ourPubkey}) async {
    final selfPubkey = ourPubkey ?? _ourPubkey;
    var skippedSelf = false;
    var hasEligibleTarget = false;
    final newlyBlocked = <String>[];
    final newlySeveredFollowers = <String>[];
    var retiredPendingUnblock = false;

    for (final pubkey in pubkeys) {
      if (pubkey.isEmpty) continue;
      if (selfPubkey != null && pubkey == selfPubkey) {
        skippedSelf = true;
        continue;
      }
      hasEligibleTarget = true;
      if (_runtimeBlocklist.add(pubkey)) {
        newlyBlocked.add(pubkey);
      }
      retiredPendingUnblock =
          _pendingUnblocks.remove(pubkey) != null || retiredPendingUnblock;
      if (!_severedFollowers.contains(pubkey) &&
          !newlySeveredFollowers.contains(pubkey)) {
        newlySeveredFollowers.add(pubkey);
      }
    }

    if (skippedSelf) {
      Log.warning(
        'Attempted to block self - ignoring',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }

    if (retiredPendingUnblock) await _savePendingUnblocks();
    if (newlyBlocked.isNotEmpty) {
      await _saveBlockedUsers();
      for (final pubkey in newlyBlocked) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.blocked));
      }
      _notifyChanged();
      await _publishMuteListToNostr();

      Log.debug(
        'Added ${newlyBlocked.length} users to blocklist',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
    if (newlyBlocked.isEmpty && hasEligibleTarget) {
      await retryPendingMuteListPublish();
    }

    // Track as severed follower so they stay hidden from our followers
    // list even after unblocking (until they explicitly re-follow).
    if (newlySeveredFollowers.isNotEmpty) {
      _severedFollowers.addAll(newlySeveredFollowers);
      await _saveSeveredFollowers();
    }
  }

  /// Stop hiding a public key through this account's own mute list.
  ///
  /// Removes both Divine-authored blocks and mutes imported from another
  /// client, then republishes the updated kind 10000 mute list to Nostr.
  /// Awaits the local write so the change survives an immediate app kill.
  /// Note: Cannot remove users from internal blocklist.
  Future<void> unblockUser(String pubkey) async {
    // coverage:ignore-start
    if (_internalBlocklist.contains(pubkey)) {
      // Internal blocklist is intentionally empty; this branch is
      // unreachable in production. Retained as a guard in case hardcoded
      // moderation blocks are re-introduced.
      Log.warning(
        'Cannot unblock user from internal blocklist: ${pubkeyForLogs(pubkey)}',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }
    // coverage:ignore-end

    final removedBlock = _runtimeBlocklist.remove(pubkey);
    final removedMute = _mutedPubkeys.remove(pubkey);
    final hadPendingUnblock = _pendingUnblocks.containsKey(pubkey);
    final publishedListCarries = _latestOwnMuteListCarries(pubkey);
    final hasExplicitUnblock =
        removedBlock ||
        removedMute ||
        hadPendingUnblock ||
        publishedListCarries;

    if (removedBlock) {
      await _saveBlockedUsers();
      _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.unblocked));
    }
    if (removedMute) {
      await _saveMutedUsers();
      _emitChange(
        BlocklistChange(pubkey: pubkey, op: BlocklistOp.unmutedByUs),
      );
    }
    if (removedBlock || removedMute) {
      _notifyChanged();
    }

    if (!hasExplicitUnblock) {
      await retryPendingMuteListPublish();
      return;
    }

    // Recorded BEFORE the publish, so a withheld or failed publish still
    // leaves the intent behind for the next launch to act on (#8263).
    _pendingUnblocks[pubkey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _savePendingUnblocks();
    // Protect this explicit action from a clock-skewed source event fetched
    // during the mandatory pre-publish refresh. Ordinary later reconciliation
    // still honours a genuinely newer mute authored by another client.
    await _publishMuteListToNostr(protectedUnblocks: {pubkey});

    Log.info(
      'Stopped hiding user: ${pubkeyForLogs(pubkey)}',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );
  }

  /// Get all blocked public keys (for debugging)
  Set<String> get blockedPubkeys => {
    ..._internalBlocklist,
    ..._runtimeBlocklist,
  };

  /// The accounts [accountPubkey] has explicitly blocked, for callers that
  /// **write** a Nostr event on that account's behalf.
  ///
  /// Returns an empty set unless the persisted sets currently loaded belong
  /// to [accountPubkey]. A keepAlive repository can still hold account A's
  /// blocks while a session signs as account B — after a switch, until
  /// [_adoptIdentity] runs — and filtering B's published data against A's
  /// blocks would silently rewrite B's follow graph.
  ///
  /// Write paths must use this rather than [feedHiddenPubkeys] or
  /// [shouldFilterFromFeeds]: those unions also carry `_blockedByOthers`, so
  /// a third party could mutate the current user's published data simply by
  /// blocking them.
  Set<String> blockedPubkeysForAccount(String accountPubkey) =>
      accountPubkey.isNotEmpty && _activeAccountPubkey == accountPubkey
      ? blockedPubkeys
      : const <String>{};

  /// Get count of blocked accounts
  int get totalBlockedCount =>
      _internalBlocklist.length + _runtimeBlocklist.length;

  /// Filter a list of content by removing blocked authors
  List<T> filterContent<T>(List<T> content, String Function(T) getPubkey) =>
      content.where((item) => !shouldFilterFromFeeds(getPubkey(item))).toList();

  /// Filter DM conversations where the other participant is blocked.
  ///
  /// [userPubkey] is the current user's pubkey, used to identify which
  /// participant is "the other one" in each conversation.
  ///
  /// Filters on [shouldFilterFromDms], not [shouldFilterFromFeeds]: a thread
  /// the viewer already received stays reachable even when the counterparty
  /// mutes or blocks them (#7345).
  List<DmConversation> filterBlockedConversations(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    return conversations.where((conv) {
      final otherPubkey = conv.participantPubkeys.firstWhere(
        (pk) => pk != userPubkey,
        orElse: () => '',
      );
      // Exclude self-conversations (no "other" participant found).
      if (otherPubkey.isEmpty) return false;
      return !shouldFilterFromDms(otherPubkey);
    }).toList();
  }

  /// Check if user is in internal (permanent) blocklist
  bool isInternallyBlocked(String pubkey) =>
      _internalBlocklist.contains(pubkey);

  /// Get runtime blocked users (can be modified)
  Set<String> get runtimeBlockedUsers => Set.unmodifiable(_runtimeBlocklist);

  /// Clear all runtime blocks (keeps internal blocks)
  void clearRuntimeBlocks() {
    if (_runtimeBlocklist.isNotEmpty) {
      _runtimeBlocklist.clear();
      unawaited(_saveBlockedUsers());

      Log.debug(
        'Cleared all runtime blocks',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Get stats about blocking
  Map<String, dynamic> get blockingStats => {
    'internal_blocks': _internalBlocklist.length,
    'runtime_blocks': _runtimeBlocklist.length,
    'total_blocks': totalBlockedCount,
  };

  /// Start background sync of mute lists (NIP-51 kind 10000).
  ///
  /// Subscribes to two filter sets in a single subscription:
  /// 1. Kind 10000 events WHERE our pubkey appears in 'p' tags — detects
  ///    when other users mute us (mutual mute).
  /// 2. Our own kind 10000 event — mutes the user authored from other
  ///    Nostr clients (this app has no mute action), and relay-based
  ///    restoration after reinstall. Since #5462 this is the only list
  ///    that carries our own entries back from relays.
  Future<void> syncMuteListsInBackground(
    NostrClient nostrService,
    String ourPubkey,
  ) async {
    // Reset per-account state (and the started flags) if the identity
    // changed, so the subscription below filters on the new pubkey (#4969).
    _adoptIdentity(ourPubkey);

    // If the NostrClient changed (e.g., account switch), the old subscription
    // was on a disposed client. Reset so we create a fresh subscription.
    if (_mutualMuteSyncStarted && _mutualMuteSyncClient != nostrService) {
      _mutualMuteSyncStarted = false;
    }

    if (_mutualMuteSyncStarted) {
      Log.debug(
        'Mutual mute sync already started, skipping',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    // Store references for Nostr publishing
    _nostrClient = nostrService;

    // Any existing by-author watch was opened on the previous client.
    _muteAuthorWatch.rebind(
      client: nostrService,
      onEvent: _handleMuteListEvent,
    );

    Log.info(
      'Starting mutual mute list sync for pubkey: ${pubkeyForLogs(ourPubkey)}',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );

    try {
      // Filter 1: others' mute lists that include our pubkey (mutual mute)
      final mutualFilter = Filter(kinds: const [10000])..p = [ourPubkey];

      // Filter 2: our own mute list (mutes authored from other clients +
      // relay-based restoration after reinstall)
      final ownFilter = Filter(authors: [ourPubkey], kinds: const [10000]);

      final subscription = nostrService.subscribe([mutualFilter, ownFilter]);

      _mutualMuteSyncStarted = true;
      _mutualMuteSyncClient = nostrService;
      _mutualMuteSubscriptionId =
          'mutual-mute-${DateTime.now().millisecondsSinceEpoch}';

      // Listen to the stream. A relay that refuses the REQ surfaces a stream
      // error; without onError it would escape to the zone as an uncaught
      // async error, because the try/catch here only covers the setup.
      subscription.listen(
        _handleMuteListEvent,
        onError: (Object error) {
          Log.warning(
            'Mutual mute subscription ended: $error',
            name: 'ContentBlocklistRepository',
            category: LogCategory.system,
          );
        },
      );

      Log.info(
        'Mutual mute subscription created: $_mutualMuteSubscriptionId',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to start mutual mute sync: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Start background sync of other users' block lists (kind 30000, d=block).
  ///
  /// Subscribes to kind 30000 events where our pubkey is in 'p' tags, which
  /// detects when other users block us. Clients that have not upgraded to
  /// kind 10000 blocks yet still publish here, so this read stays.
  ///
  /// Our *own* kind 30000 list is deliberately not subscribed to. It is no
  /// longer authored (#5462) and [_retireLegacyBlockList] empties it, so a
  /// superseded copy re-served by a relay could only resurrect blocks the
  /// user has since lifted. Our blocks now round-trip through the kind 10000
  /// mute list handled by [syncMuteListsInBackground].
  ///
  /// Using `subscribe` (persistent stream) instead of `queryEvents`
  /// (one-shot) ensures events arrive even if relays connect after this
  /// method is called.
  Future<void> syncBlockListsInBackground(
    NostrClient nostrService,
    BlockListSigner signer,
    String ourPubkey,
  ) async {
    // Reset per-account state (and the started flags) if the identity
    // changed, so the subscription below filters on the new pubkey (#4969).
    _adoptIdentity(ourPubkey);

    // If the NostrClient changed (e.g., account switch), the old subscription
    // was on a disposed client. Reset so we create a fresh subscription.
    if (_blockListSyncStarted && _blockListSyncClient != nostrService) {
      _blockListSyncStarted = false;
    }

    if (_blockListSyncStarted) {
      Log.debug(
        'Block list sync already started, skipping',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _signer = signer;
    _nostrClient = nostrService;

    // Any existing by-author watch was opened on the previous client.
    _blockAuthorWatch.rebind(
      client: nostrService,
      onEvent: _handleBlockListEvent,
    );

    Log.info(
      'Starting block list sync for pubkey: ${pubkeyForLogs(ourPubkey)}',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );

    try {
      // Others' block lists that include our pubkey.
      final othersFilter = Filter(kinds: const [30000])..p = [ourPubkey];

      nostrService
          .subscribe([othersFilter])
          .listen(
            _handleBlockListEvent,
            onError: (Object error) {
              Log.warning(
                'Block list subscription ended: $error',
                name: 'ContentBlocklistRepository',
                category: LogCategory.system,
              );
            },
          );

      _blockListSyncStarted = true;
      _blockListSyncClient = nostrService;

      // One-time cutover (#4037, #5462): fold any legacy kind 30000 block
      // list into the standard kind 10000 mute list, then replace the legacy
      // list with an empty one. Fire-and-forget so it never blocks startup;
      // guarded by per-account persisted flags.
      unawaited(_retireLegacyBlockList(nostrService, signer, ourPubkey));

      Log.info(
        'Block list subscription created (blocked-by detection)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to start block list sync: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// One-time migration of a legacy kind 30000 (d=block) block list into the
  /// standard NIP-51 kind 10000 mute list (#4037).
  ///
  /// Older app versions only published blocks to a non-standard kind 30000
  /// list that no other client honoured. This appends those entries to the
  /// user's existing kind 10000 mute list and republishes it once, so
  /// pre-existing blocks finally propagate — without dropping any mutes set
  /// on other clients (the existing list is fetched and merged, never
  /// replaced blindly).
  ///
  /// Guarded by a per-account SharedPreferences flag so it runs at most once
  /// per account. The flag is only set after the republish is accepted, so a
  /// failed publish retries on the next launch. Requires persistence; it is a
  /// no-op without prefs (the one-time guarantee can't be tracked otherwise).
  Future<void> _migrateLegacyBlockListToMuteList(
    NostrClient nostrClient,
    BlockListSigner signer,
    String ourPubkey,
  ) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final flagKey = '$_blockListMigratedPrefsKeyBase.$ourPubkey';
    if (prefs.getBool(flagKey) ?? false) return;
    if (!signer.isAuthenticated) return;

    try {
      // 1. Read the legacy kind 30000 d=block list from cache + relays.
      final relayBlocks =
          await _readOwnLegacyBlockPubkeys(nostrClient, ourPubkey) ??
          const <String>{};

      // Nothing to migrate. Leave the flag unset because an empty one-shot
      // query can also mean a cold relay miss; retrying on a later launch is
      // safer than permanently skipping a legacy-list migration.
      if (relayBlocks.isEmpty && _runtimeBlocklist.isEmpty) {
        return;
      }

      if (!_isStillActiveAccount(ourPubkey)) return;

      // 2. Read the existing kind 10000 mute list (newest replaceable wins)
      //    so the merge never drops mutes authored on other clients. An
      //    inconclusive read aborts the migration rather than merging into a
      //    list we could not see -- step 4 republishes the whole event, and
      //    the completion flag below stays unset so the next launch retries
      //    (#6750).
      final muteRead = await nostrClient.queryEventsDetailed(
        [
          Filter(authors: [ourPubkey], kinds: const [10000]),
        ],
        requireAllRelaysSettled: true,
      );
      if (muteRead.timedOut || muteRead.noRelays) {
        Log.warning(
          'Deferring legacy block-list migration - could not confirm the '
          'current kind 10000 mute list; retrying next launch',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return;
      }
      Event? newestMuteList;
      for (final event in muteRead.events) {
        if (event.pubkey != ourPubkey) continue;
        if (newestMuteList == null ||
            event.createdAt > newestMuteList.createdAt) {
          newestMuteList = event;
        }
      }

      if (!_isStillActiveAccount(ourPubkey)) return;

      // 3. Fold both lists into our in-memory state without removing
      //    anything. Legacy entries are our blocks; the rest of the relay's
      //    mute list is preserved as mutes (our own blocks are kept out of
      //    the mute set, matching [_handleOwnMuteListEvent]).
      final newlyBlocked = relayBlocks.difference(_runtimeBlocklist);
      _runtimeBlocklist.addAll(relayBlocks);
      final mutedBeforeMerge = <String>{..._mutedPubkeys};
      if (newestMuteList != null) {
        _applyOwnMuteListEvent(newestMuteList, notify: false, persist: false);
      }
      final newlyMuted = _mutedPubkeys.difference(mutedBeforeMerge);
      await _saveBlockedUsers();
      await _saveMutedUsers();
      if (!_isStillActiveAccount(ourPubkey)) return;

      // 4. Republish the unified kind 10000 mute list. Only record the
      //    migration as done once the relay accepts it, so a failure retries.
      final published = await _publishMuteListToNostr();
      if (!published) {
        Log.warning(
          'Legacy block-list migration publish failed; retrying next launch',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        return;
      }

      await prefs.setBool(flagKey, true);

      for (final pubkey in newlyBlocked) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.blocked));
      }
      for (final pubkey in newlyMuted) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.mutedByUs));
      }
      if (newlyBlocked.isNotEmpty || newlyMuted.isNotEmpty) {
        _notifyChanged();
      }

      Log.info(
        'Migrated legacy block list into the kind 10000 mute list '
        '(${_runtimeBlocklist.length} blocks, ${_mutedPubkeys.length} mutes)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to migrate legacy block list to mute list: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Handle incoming kind 10000 mute list events.
  ///
  /// Routes our own mute list to [_handleOwnMuteListEvent]; for other
  /// authors, adds/removes the muter based on whether our pubkey is in
  /// their 'p' tags (mutual mute).
  void _handleMuteListEvent(Event event) {
    if (event.kind != 10000) {
      Log.warning(
        'Received non-10000 event in mute list handler: ${event.kind}',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    if (event.pubkey == _ourPubkey) {
      _handleOwnMuteListEvent(event);
      return;
    }

    final muterPubkey = event.pubkey;
    final createdAt = event.createdAt;
    final latestSeen = _latestMuteListEventCreatedAtByAuthor[muterPubkey];

    if (latestSeen != null && createdAt < latestSeen) {
      Log.debug(
        'Ignoring stale mute list event from ${pubkeyForLogs(muterPubkey)} '
        '(createdAt=$createdAt < latestSeen=$latestSeen)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _latestMuteListEventCreatedAtByAuthor[muterPubkey] = createdAt;

    // Check if our pubkey is in this user's mute list
    final stillMuted = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] == _ourPubkey,
    );

    if (stillMuted) {
      // They muted us - add to blocklist
      if (!_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.add(muterPubkey);
        // Watch this author directly; the #p filter that just delivered
        // this event can never deliver the unmute that follows it.
        _muteAuthorWatch.add(
          muterPubkey,
          client: _nostrClient,
          onEvent: _handleMuteListEvent,
        );
        _emitChange(
          BlocklistChange(pubkey: muterPubkey, op: BlocklistOp.muted),
        );
        _notifyChanged();
        Log.info(
          'Added mutual mute: ${pubkeyForLogs(muterPubkey)}',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    } else {
      // They removed us from mute list - remove from blocklist
      if (_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.remove(muterPubkey);
        _emitChange(
          BlocklistChange(pubkey: muterPubkey, op: BlocklistOp.unmuted),
        );
        _notifyChanged();
        Log.info(
          'Removed mutual mute (unmuted): ${pubkeyForLogs(muterPubkey)}',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Replace our muted-authors set from our latest kind 10000 event.
  ///
  /// Kind 10000 is replaceable, so the newest own event is the complete
  /// list and replaces [_mutedPubkeys] wholesale, guarded by `created_at`
  /// so a superseded copy re-served by a relay cannot win.
  ///
  /// Our own in-app blocks ([_runtimeBlocklist]) are excluded: this app now
  /// publishes them onto the same kind 10000 list, so an entry that we
  /// blocked must be tracked as a block (not duplicated into the mute set),
  /// otherwise unblocking could never drop it from the republished list.
  /// Our own pubkey is excluded so a malformed self-referential mute list
  /// can never filter the user's own content (#2192).
  void _handleOwnMuteListEvent(Event event) {
    _applyOwnMuteListEvent(event, reconcile: true);
  }

  void _applyOwnMuteListEvent(
    Event event, {
    bool notify = true,
    bool persist = true,
    bool reconcile = false,
    Set<String> protectedUnblocks = const <String>{},
  }) {
    final ourPubkey = event.pubkey;
    final createdAt = event.createdAt;
    final latestSeen = _latestMuteListEventCreatedAtByAuthor[ourPubkey];

    if (latestSeen != null && createdAt < latestSeen) {
      Log.debug(
        'Ignoring stale own mute list event '
        '(createdAt=$createdAt < latestSeen=$latestSeen)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _latestMuteListEventCreatedAtByAuthor[ourPubkey] = createdAt;
    _latestOwnMuteListEvent = event;

    final relayMuted = <String>{};
    for (final tag in event.tags) {
      if (tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] != ourPubkey) {
        relayMuted.add(tag[1]);
      }
    }
    var needsRepublish = false;
    // An unblock this list predates never reached the relay, so its `p` tag
    // is stale and must not be re-adopted as a mute from another client
    // (#8263). A tag on a list NEWER than the unblock is the opposite case --
    // someone muted them again after we unblocked -- so it is honoured and
    // the intent retired. `created_at` is what separates the two; without it
    // a legitimate later re-mute would be suppressed forever.
    if (_pendingUnblocks.isNotEmpty) {
      final retired = <String>[];
      for (final entry in _pendingUnblocks.entries) {
        if (protectedUnblocks.contains(entry.key)) {
          relayMuted.remove(entry.key);
          continue;
        }
        if (!relayMuted.contains(entry.key) || entry.value < createdAt) {
          // Either the tag is gone, so the unblock landed, or this list is
          // newer than the unblock and the tag is a fresh mute from another
          // client. Both retire the intent; the second also lets the mute
          // through, which is the point of comparing against `created_at`.
          retired.add(entry.key);
        } else {
          relayMuted.remove(entry.key);
        }
      }
      if (retired.isNotEmpty) {
        retired.forEach(_pendingUnblocks.remove);
        unawaited(_savePendingUnblocks());
      }
      if (reconcile && _pendingUnblocks.isNotEmpty) {
        Log.info(
          'Own mute list still carries an account we unblocked; republishing',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
        needsRepublish = true;
      }
    }

    // The relay's newest list is authoritative for what it holds, so blocks
    // we still hold locally that are absent from it are a publish that never
    // landed -- withheld by an inconclusive read (#6750), or lost with
    // `_muteListPublishPending` when the app was killed. Derive that from the
    // two sets that DO survive a restart rather than persisting a flag; it is
    // a no-op in steady state, because our own publishes put every block on
    // the list we read back. Only the subscription reconciles: a read taken
    // inside `_publishMuteListToNostr` is about to republish anyway.
    if (reconcile && _runtimeBlocklist.difference(relayMuted).isNotEmpty) {
      Log.info(
        'Own mute list is missing blocks we hold locally; republishing',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      needsRepublish = true;
    }
    if (needsRepublish) {
      _muteListPublishPending = true;
      unawaited(retryPendingMuteListPublish());
    }

    // Entries we blocked in-app are republished onto this same list; keep
    // them out of the mute set so they stay tracked as blocks only.
    relayMuted.removeAll(_runtimeBlocklist);

    final added = relayMuted.difference(_mutedPubkeys);
    final removed = _mutedPubkeys.difference(relayMuted);
    if (added.isEmpty && removed.isEmpty) return;

    _mutedPubkeys
      ..removeAll(removed)
      ..addAll(added);
    if (persist) {
      unawaited(_saveMutedUsers());
    }
    if (notify) {
      for (final pubkey in added) {
        _emitChange(BlocklistChange(pubkey: pubkey, op: BlocklistOp.mutedByUs));
      }
      for (final pubkey in removed) {
        _emitChange(
          BlocklistChange(pubkey: pubkey, op: BlocklistOp.unmutedByUs),
        );
      }
      _notifyChanged();
    }

    Log.info(
      'Synced own mute list: +${added.length} -${removed.length} '
      '(total: ${_mutedPubkeys.length})',
      name: 'ContentBlocklistRepository',
      category: LogCategory.system,
    );
  }

  /// Handle incoming kind 30000 block list events (d=block).
  ///
  /// Only other authors' lists are interpreted, to answer [hasBlockedUs].
  /// Our own legacy list stopped being a source of truth for our blocks in
  /// #5462: it is no longer authored, [_retireLegacyBlockList] empties it,
  /// and merging a superseded copy back in used to resurrect blocks the user
  /// had already lifted (#7027).
  void _handleBlockListEvent(Event event) {
    if (event.kind != 30000) return;
    if (event.pubkey == _ourPubkey) return;

    // Only process events with d=block tag. Kind 30000 is shared with
    // unrelated people lists (e.g. divine-space's d=top8 follow set).
    final hasBlockDTag = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'd' &&
          tag.length >= 2 &&
          tag[1] == 'block',
    );
    if (!hasBlockDTag) return;

    _handleOthersBlockListEvent(event);
  }

  /// Handle another user's block list event.
  ///
  /// Checks if our pubkey is in their 'p' tags, then adds/removes
  /// the blocker from [_blockedByOthers].
  void _handleOthersBlockListEvent(Event event) {
    final blockerPubkey = event.pubkey;
    final createdAt = event.createdAt;
    final latestSeen = _latestBlockListEventCreatedAtByAuthor[blockerPubkey];

    if (latestSeen != null && createdAt < latestSeen) {
      Log.debug(
        'Ignoring stale block list event from ${pubkeyForLogs(blockerPubkey)} '
        '(createdAt=$createdAt < latestSeen=$latestSeen)',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
      return;
    }

    _latestBlockListEventCreatedAtByAuthor[blockerPubkey] = createdAt;

    // Check if our pubkey is in this user's block list
    final stillBlocked = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] == _ourPubkey,
    );

    if (stillBlocked) {
      if (!_blockedByOthers.contains(blockerPubkey)) {
        _blockedByOthers.add(blockerPubkey);
        // Watch this author directly; the #p filter that just delivered
        // this event can never deliver the unblock that follows it.
        _blockAuthorWatch.add(
          blockerPubkey,
          client: _nostrClient,
          onEvent: _handleBlockListEvent,
        );
        _emitChange(
          BlocklistChange(pubkey: blockerPubkey, op: BlocklistOp.blockedUs),
        );
        _notifyChanged();
        Log.info(
          'Detected block from user: ${pubkeyForLogs(blockerPubkey)}',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    } else {
      if (_blockedByOthers.contains(blockerPubkey)) {
        _blockedByOthers.remove(blockerPubkey);
        _emitChange(
          BlocklistChange(pubkey: blockerPubkey, op: BlocklistOp.unblockedUs),
        );
        _notifyChanged();
        Log.info(
          'Detected unblock from user: ${pubkeyForLogs(blockerPubkey)}',
          name: 'ContentBlocklistRepository',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Dispose resources (cancel subscriptions)
  void dispose() {
    // Subscription cleanup would go here if NostrService had unsubscribe method
    _mutualMuteSyncStarted = false;
    _mutualMuteSubscriptionId = null;
    _blockListSyncStarted = false;
    _blockAuthorWatch.clear();
    _muteAuthorWatch.clear();
    unawaited(_stateController.close());
    unawaited(_changesController.close());
  }
}

/// Watches specific authors' replaceable list events *by author id*.
///
/// The repository discovers that someone blocked or muted us with a
/// `#p = <us>` filter. That filter can only ever match a list that still
/// tags us, so it sees the entry being added but never the replacement that
/// removes it — a lifted block simply stops matching, and no event is
/// delivered. The "they unblocked us" branches in
/// [ContentBlocklistRepository._handleOthersBlockListEvent] and
/// [ContentBlocklistRepository._handleMuteListEvent] were therefore
/// unreachable in production: the blockee kept hiding the other party's DM
/// conversation and profile forever.
///
/// Once an author is known to block or mute us we additionally watch their
/// list by author, which is the only filter their removal event can still
/// match. Authors are kept watched after a lift so later list changes from a
/// known author do not require tearing down and rebuilding the watch again.
class _AuthorListWatch {
  _AuthorListWatch({required int kind, required String label})
    : _kind = kind,
      _label = label;

  final int _kind;
  final String _label;
  final Set<String> _authors = <String>{};

  NostrClient? _boundClient;
  StreamSubscription<Event>? _subscription;
  String? _subscriptionId;
  int _generation = 0;
  bool _openScheduled = false;

  /// Starts watching [author]'s list. A no-op when already watched.
  void add(
    String author, {
    required NostrClient? client,
    required void Function(Event) onEvent,
  }) {
    if (!_authors.add(author)) return;
    _scheduleOpen(client: client, onEvent: onEvent);
  }

  /// Re-opens the watch against [client].
  ///
  /// Needed when the [NostrClient] is recreated (the old subscription lives
  /// on a disposed client), and when the client only became available after
  /// the first author was already watched.
  void rebind({
    required NostrClient? client,
    required void Function(Event) onEvent,
  }) {
    if (_authors.isEmpty) return;
    _open(client: client, onEvent: onEvent);
  }

  /// Drops every watched author — e.g. on identity change, where "who
  /// blocks us" is meaningless for the new account.
  void clear() {
    _authors.clear();
    _close();
  }

  /// Coalesces a burst of [add] calls into a single subscription.
  ///
  /// The initial relay replay hands us every author who blocks us in quick
  /// succession; opening per author would cost a REQ/CLOSE pair each and
  /// re-deliver the already-watched authors every time. Deferred by a full
  /// event-loop turn rather than a microtask because stream events reach us
  /// one microtask apart, which is exactly what needs collapsing.
  void _scheduleOpen({
    required NostrClient? client,
    required void Function(Event) onEvent,
  }) {
    if (client == null || _openScheduled) return;
    _openScheduled = true;
    Timer.run(() {
      // Cleared by a rebind or clear() that ran before this fired.
      if (!_openScheduled) return;
      _open(client: client, onEvent: onEvent);
    });
  }

  void _open({
    required NostrClient? client,
    required void Function(Event) onEvent,
  }) {
    if (client == null) return;
    _close();

    final id = '$_label-author-watch-${++_generation}';
    try {
      _boundClient = client;
      _subscriptionId = id;
      _subscription = client
          .subscribe([
            Filter(authors: _authors.toList(), kinds: [_kind]),
          ], subscriptionId: id)
          .listen(
            onEvent,
            // A relay that refuses this REQ surfaces a stream error, and the
            // try/catch here only covers the setup. Without onError it would
            // escape to the zone as an uncaught async error.
            onError: (Object error) {
              Log.warning(
                '$_label author watch ended: $error',
                name: 'ContentBlocklistRepository',
                category: LogCategory.system,
              );
            },
          );

      Log.info(
        'Watching ${_authors.length} $_label author(s) by author id',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    } on Object catch (e) {
      _boundClient = null;
      _subscriptionId = null;
      Log.error(
        'Failed to open $_label author watch: $e',
        name: 'ContentBlocklistRepository',
        category: LogCategory.system,
      );
    }
  }

  void _close() {
    _openScheduled = false;
    unawaited(_subscription?.cancel());
    _subscription = null;

    final id = _subscriptionId;
    final client = _boundClient;
    _subscriptionId = null;
    _boundClient = null;

    if (id != null && client != null) {
      unawaited(client.unsubscribe(id));
    }
  }
}
