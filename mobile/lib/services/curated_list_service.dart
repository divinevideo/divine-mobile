// ABOUTME: Service for managing NIP-51 curated lists (kind 30005) for video collections
// ABOUTME: Handles creation, updates, and management of user's video lists

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/models/curated_list_callbacks.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/services/curated_lists/curated_list_relay_snapshot_reader.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/curated_lists/curated_list_subscription_metadata.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:openvine/utils/curated_list_privacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/curated_list_callbacks.dart';

part 'curated_lists/curated_list_playlist.dart';

/// A fresh list session cannot prove cache absence across unfinished cleanup.
class CuratedListAccountBoundaryException implements Exception {
  const CuratedListAccountBoundaryException();

  @override
  String toString() =>
      'Account cleanup must finish before lists can initialize';
}

/// A metadata update's bounded rejection reason.
enum CuratedListUpdateRejection { failed, privateListFull }

/// Outcome without changing the legacy boolean update contract.
class CuratedListUpdateResult {
  const CuratedListUpdateResult.saved() : succeeded = true, rejection = null;
  const CuratedListUpdateResult.failed()
    : succeeded = false,
      rejection = CuratedListUpdateRejection.failed;
  const CuratedListUpdateResult.privateListFull()
    : succeeded = false,
      rejection = CuratedListUpdateRejection.privateListFull;

  final bool succeeded;
  final CuratedListUpdateRejection? rejection;
}

/// Service for managing NIP-51 curated lists.
///
/// Sanctioned ChangeNotifier per the "Sanctioned Riverpod (STAYS)" list in
/// `docs/BLOC_UI_MIGRATION_PRD.md` — this is a Nostr-list cache + sync service,
/// not feature UI state, and is baselined by `check_changenotifier_boundary.sh`.
class CuratedListService extends ChangeNotifier {
  CuratedListService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
    CuratedListCacheWriteCoordinator? cacheWriteCoordinator,
    CuratedListSessionCoordinator? sessionCoordinator,
    OnListSubscribedCallback? onListSubscribed,
    OnListUnsubscribedCallback? onListUnsubscribed,
    Duration relaySyncTimeout = const Duration(seconds: 10),
    Duration maxPublishClockDrift = const Duration(seconds: 60),
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs,
       _sessions =
           sessionCoordinator ??
           CuratedListSessionCoordinator.forPreferences(
             prefs,
             writes: cacheWriteCoordinator,
           ),
       _onListSubscribed = onListSubscribed,
       _onListUnsubscribed = onListUnsubscribed,
       _relaySyncTimeout = relaySyncTimeout,
       _publishClock = CuratedListPublishClock(
         maxFutureDrift: maxPublishClockDrift,
       ) {
    _sessionLease = _sessions.acquire();
    // A lease created across unfinished cleanup has no trusted local baseline.
    // Existing continuing leases keep their already-accepted live deferral.
    _accountCleanupPendingAtCreation = _hasPendingAccountCleanup;
    if (_accountCleanupPendingAtCreation) {
      _initializationError = const CuratedListAccountBoundaryException();
    }
    _relayGateway = CuratedListRelayGateway(
      nostrService: nostrService,
      authService: authService,
    );
    _cacheStore = PrefsCuratedListStore(
      prefs: prefs,
      writeCoordinator: _sessions.writes,
      listsStorageKey: listsStorageKey,
      subscriptionsStorageKey: subscribedListsStorageKey,
      defaultListDeletedStorageKey: defaultListDeletedStorageKey,
      isCurrentSession: () => isCurrentSession,
    );
    if (isCurrentSession) {
      _loadLists();
      _loadSubscribedListIds();
    }
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;
  late final PrefsCuratedListStore _cacheStore;
  final CuratedListSessionCoordinator _sessions;
  late final CuratedListSessionLease _sessionLease;
  late final bool _accountCleanupPendingAtCreation;

  // The shared boundary is unresolved even when its owner cannot be read.
  // Do not parse or clear evidence to turn an unknown intent into absence.
  bool get _hasPendingAccountCleanup =>
      PendingAccountCleanup.readbackUnknown(_prefs) ||
      _prefs.containsKey(PendingAccountCleanup.storageKey);
  final Duration _relaySyncTimeout;
  late final CuratedListRelayGateway _relayGateway;
  final CuratedListPublishClock _publishClock;

  /// Callback invoked when a list is subscribed (for video cache sync)
  OnListSubscribedCallback? _onListSubscribed;

  /// Callback invoked when a list is unsubscribed (for video cache cleanup)
  OnListUnsubscribedCallback? _onListUnsubscribed;

  /// Sets the callback for list subscription events
  /// Used by the provider layer to wire up SubscribedListVideoCache
  void setOnListSubscribed(OnListSubscribedCallback? callback) {
    _onListSubscribed = callback;
  }

  /// Sets the callback for list unsubscription events
  /// Used by the provider layer to wire up SubscribedListVideoCache
  void setOnListUnsubscribed(OnListUnsubscribedCallback? callback) {
    _onListUnsubscribed = callback;
  }

  static const String listsStorageKey = 'curated_lists';
  static const String subscribedListsStorageKey = 'subscribed_list_ids';
  static const String defaultListDeletedStorageKey =
      'curated_lists_default_deleted';
  static const String defaultListId = 'my_vine_list';
  static const String _createListOperationId = '__create_curated_list__';

  final List<CuratedList> _lists = [];
  final Set<String> _subscribedListIds = {};
  bool _isInitialized = false;
  bool _hasLoadedSubscriptionIds = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  bool _isCurrent(String? owner) =>
      !_isDisposed && _relayGateway.currentAuthenticatedPubkey() == owner;

  /// A failed or pending recovery cannot authorize writes or relay sync.
  bool get isReadyForMutations =>
      isCurrentSession && !_isInitializing && _initializationError == null;

  /// Public relay reads write nothing, so only a failed recovery blocks them;
  /// one still in progress must not leave discovery empty.
  bool get _canReadPublicLists =>
      isCurrentSession && _initializationError == null;

  /// The last startup recovery failure, cleared only after a successful retry.
  Object? get initializationError => _initializationError;

  StackTrace? get initializationStackTrace => _initializationStackTrace;

  // Track relay sync status
  bool _hasSyncedWithRelays = false;

  final CuratedListMutationQueue _mutations = CuratedListMutationQueue();

  Future<T> _serializeListOperation<T>(
    String listId,
    Future<T> Function() operation, {
    T? cancelled,
  }) => _mutations.run(
    listId,
    operation,
    currentOwner: () => _authService.currentPublicKeyHex,
    cancelled: cancelled,
  );

  List<CuratedList> get lists => List.unmodifiable(_lists);
  bool get isInitialized => _isInitialized;

  /// Whether the persisted subscription metadata was decoded successfully.
  ///
  /// An absent record is a valid empty snapshot. A malformed record must not
  /// authorize Home to discard or migrate an unresolved saved list selection.
  bool get hasLoadedSubscriptionIds => _hasLoadedSubscriptionIds;

  /// Get all subscribed list IDs
  Set<String> get subscribedListIds => Set.unmodifiable(_subscribedListIds);

  List<CuratedList> get subscribedLists {
    return _lists
        .where((list) => isSubscribedToList(list.authorScopedId))
        .toList();
  }

  /// Lists owned by this account, including unpublished local copies.
  List<CuratedList> get myLists => _cacheIndex.unpublishedOrOwnedBy(
    _relayGateway.currentAuthenticatedPubkey(),
  );

  /// Initialize the service and create default list if needed.
  /// Relay sync follows local loading in the background.
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot initialize curated lists - user not authenticated',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      if (_accountCleanupPendingAtCreation && _hasPendingAccountCleanup) {
        throw const CuratedListAccountBoundaryException();
      }

      await _recoverDeletedSubscriptions();
      if (!isCurrentSession) return;

      // Create default list if it doesn't exist and the user has not explicitly
      // withdrawn its relay coordinate.
      if (!hasDefaultList() && !_cacheStore.wasDefaultListDeleted()) {
        await _createDefaultList();
      }

      _isInitialized = true;
      notifyListeners();
      Log.info(
        'Curated list service initialized with ${_lists.length} lists (local cache ready)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      unawaited(_syncWithRelaysInBackground());
    } catch (e) {
      Log.error(
        'Failed to initialize curated list service: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Sync with relays in background without blocking.
  /// Merges relay data with local cache when complete.
  Future<void> _syncWithRelaysInBackground() async {
    try {
      await fetchUserListsFromRelays();
      Log.info(
        'Background relay sync complete, now have ${_lists.length} lists',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Background relay sync failed: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Check if default list exists
  bool hasDefaultList() => getDefaultList() != null;

  /// Get the default "My List" for quick adding
  CuratedList? getDefaultList() => _cacheIndex.findOwned(defaultListId);

  /// Create a new curated list with enhanced playlist features
  Future<CuratedList?> createList({
    required String name,
    String? description,
    String? imageUrl,
    bool isPublic = true,
    List<String> tags = const [],
    bool isCollaborative = false,
    List<String> allowedCollaborators = const [],
    String? thumbnailEventId,
    PlayOrder playOrder = PlayOrder.chronological,
  }) async {
    return _serializeListOperation(
      _createListOperationId,
      () => _createList(
        name: name,
        description: description,
        imageUrl: imageUrl,
        isPublic: isPublic,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
      ),
    );
  }

  /// Generates a list ID that is unique within the cached lists.
  ///
  /// The suffix prevents creates in the same millisecond sharing a coordinate.
  String _generateListId(DateTime now) => _cacheIndex.nextLocalId(now);

  Future<CuratedList?> _createList({
    required String name,
    String? id,
    String? description,
    String? imageUrl,
    bool isPublic = true,
    List<String> tags = const [],
    bool isCollaborative = false,
    List<String> allowedCollaborators = const [],
    String? thumbnailEventId,
    PlayOrder playOrder = PlayOrder.chronological,
  }) async {
    try {
      if (!hasValidCuratedListVisibility(isPublic, isCollaborative)) {
        Log.warning(
          'Cannot create a private collaborative list - private items are '
          'encrypted to the owner only',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return null;
      }

      final now = clock.now();
      final listId = id ?? _generateListId(now);
      final ownerPubkey = _relayGateway.currentAuthenticatedPubkey();

      final newList = CuratedList(
        id: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        videoEventIds: const [],
        pubkey: ownerPubkey,
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
      );

      if (ownerPubkey != null) {
        await _cacheStore.forgetListDeletion(ownerPubkey, listId);
      }

      _lists.add(newList);
      if (!await _saveLists()) {
        _lists.remove(newList);
        notifyListeners();
        return null;
      }

      if (_authService.isAuthenticated) {
        await _serializeListOperation(listId, () async {
          final current = getListById(listId);
          if (current == null || current.nostrEventId != null) return;
          await _publishListToNostr(current, confirmed: true);
        });
      }

      Log.info(
        'Created new curated list: $name ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return getListById(listId) ?? newList;
    } catch (e) {
      Log.error(
        'Failed to create curated list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Lists whose current owner evidence permits editing in this session.
  List<CuratedList> get editableLists =>
      List.unmodifiable(_lists.where(_canMutateCachedList));

  void _restoreList(CuratedList list) {
    final index = _lists.indexWhere(
      (item) => item.authorScopedId == list.authorScopedId,
    );
    if (index == -1) {
      _lists.add(list);
    } else {
      _lists[index] = list;
    }
    notifyListeners();
  }

  /// Only an explicitly owned row or an unpublished local draft can change.
  /// Remembered owners may edit offline; relay signing still requires auth.
  bool _canMutateCachedList(CuratedList list) {
    if (!isReadyForMutations ||
        !_cacheStore.hasUnambiguousOwnerEvidence(list)) {
      return false;
    }
    if (list.pubkey != null) {
      final owner = _authService.currentPublicKeyHex;
      return owner != null && owner.isNotEmpty && list.pubkey == owner;
    }
    return _isUnpublishedLocalList(list) &&
        (!_authService.isAuthenticated ||
            _relayGateway.currentAuthenticatedPubkey() != null);
  }

  /// Missing follow metadata is known empty; unreadable metadata is not proof
  /// that an ownerless row belongs to this account. Check both legacy aliases.
  bool _isUnpublishedLocalList(CuratedList list) {
    if (list.pubkey != null ||
        list.nostrEventId != null ||
        !_hasLoadedSubscriptionIds ||
        !_cacheStore.hasUnambiguousOwnerEvidence(list)) {
      return false;
    }
    // A local draft keeps its null coordinate for guests. Claiming it on
    // sign-in must not alias an already owned row, nor a duplicate local row.
    final owner = _relayGateway.currentAuthenticatedPubkey();
    final candidates = _lists.where(
      (cached) =>
          cached.id == list.id &&
          (cached.pubkey == null || cached.pubkey == owner),
    );
    if (candidates.length != 1) return false;
    final snapshot = readCuratedListSubscriptionSnapshot(
      preferences: _prefs,
      storageKey: subscribedListsStorageKey,
      fallback: _subscribedListIds,
    );
    return snapshot.isReadable &&
        !snapshot.ids.contains(list.id) &&
        !snapshot.ids.contains(list.authorScopedId) &&
        !_subscribedListIds.contains(list.id) &&
        !_subscribedListIds.contains(list.authorScopedId) &&
        (owner == null ||
            _cacheStore.canClaimLocalList(list, '$owner:${list.id}'));
  }

  Future<bool> _commitListMutation(CuratedList updatedList) async {
    final listIndex = _lists.indexWhere(
      (list) => list.authorScopedId == updatedList.authorScopedId,
    );
    if (listIndex == -1) return false;

    final previous = _lists[listIndex];
    if (!_canMutateCachedList(previous)) return false;
    if (!updatedList.isPublic &&
        !_relayGateway.privateItemPayloadFits(updatedList)) {
      return false;
    }
    final ownedUpdate = updatedList.copyWith(
      pubkey: updatedList.pubkey ?? _relayGateway.currentAuthenticatedPubkey(),
    );
    _publishClock.observe(previous);
    _lists[listIndex] = ownedUpdate;
    if (!await _saveLists(
      ownershipClaims: previous.pubkey == null && ownedUpdate.pubkey != null
          ? {ownedUpdate.authorScopedId: previous}
          : const {},
    )) {
      _restoreList(previous);
      return false;
    }

    if (_authService.isAuthenticated &&
        !await _publishListToNostr(ownedUpdate)) {
      final currentIndex = _lists.indexWhere(
        (list) => list.authorScopedId == ownedUpdate.authorScopedId,
      );
      if (currentIndex != -1) {
        _lists[currentIndex] = _lists[currentIndex].copyWith(
          pendingRepublish: true,
        );
        await _saveLists();
      }
      return false;
    }
    return true;
  }

  /// Add video to a list
  Future<bool> addVideoToList(String listId, String videoEventId) {
    return _serializeListOperation(
      listId,
      () => _addVideoToList(listId, videoEventId),
      cancelled: false,
    );
  }

  Future<bool> _addVideoToList(String listId, String videoEventId) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];
      if (!_canMutateCachedList(list)) return false;

      // Check if video is already in the list
      if (list.videoEventIds.contains(videoEventId)) {
        Log.warning(
          'Video already in list: $videoEventId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true; // Return true since it's already there
      }

      // Add video to list
      final updatedVideoIds = [...list.videoEventIds, videoEventId];
      final updatedList = list.copyWith(
        videoEventIds: updatedVideoIds,
        updatedAt: clock.now(),
      );

      if (!await _commitListMutation(updatedList)) return false;

      Log.debug(
        '➕ Added video to list "${list.name}": $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add video to list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove video from a list
  Future<bool> removeVideoFromList(String listId, String videoEventId) {
    return _serializeListOperation(
      listId,
      () => _removeVideoFromList(listId, videoEventId),
      cancelled: false,
    );
  }

  Future<bool> _removeVideoFromList(String listId, String videoEventId) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];
      final updatedVideoIds = list.videoEventIds
          .where((id) => id != videoEventId)
          .toList();

      final updatedList = list.copyWith(
        videoEventIds: updatedVideoIds,
        updatedAt: clock.now(),
      );

      if (!await _commitListMutation(updatedList)) return false;

      Log.debug(
        '➖ Removed video from list "${list.name}": $videoEventId',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove video from list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Retries this list's pending publication without changing its members.
  Future<bool> retryListSync(String listId) => _serializeListOperation(
    listId,
    () async {
      final list = getListById(listId);
      if (list == null || !isOwnedList(listId)) return false;
      return _publishListToNostr(list, confirmed: true);
    },
    cancelled: false,
  );

  /// Check if video is in a specific list
  bool isVideoInList(String listId, String videoEventId) {
    final list = getListById(listId);
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Check if video is in default list
  bool isVideoInDefaultList(String videoEventId) =>
      isVideoInList(defaultListId, videoEventId);

  CuratedListCacheIndex get _cacheIndex => CuratedListCacheIndex(
    _lists,
    ownerPubkey: _authService.currentPublicKeyHex,
  );

  /// Gets a local list by its legacy ID or its author-scoped ID.
  ///
  /// Public list routes use the author-scoped ID when a d-tag collides with
  /// another account's list. Never fall back to a bare d-tag for that lookup.
  CuratedList? getListById(String listId) => _cacheIndex.find(listId);

  int _listIndex(String listId) => _cacheIndex.indexOf(listId);

  /// Update list metadata with enhanced playlist features.
  ///
  /// A null field is left unchanged. Passing an empty [description] clears it
  /// back to unset, which is how the edit dialog expresses "I emptied this
  /// field": stored as `''` it would render an empty description block on the
  /// list card and publish empty event content.
  Future<bool> updateList({
    required String listId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    PlayOrder? playOrder,
    void Function()? onLocalSaved,
  }) => updateListWithResult(
    listId: listId,
    name: name,
    description: description,
    imageUrl: imageUrl,
    isPublic: isPublic,
    tags: tags,
    isCollaborative: isCollaborative,
    allowedCollaborators: allowedCollaborators,
    thumbnailEventId: thumbnailEventId,
    playOrder: playOrder,
    onLocalSaved: onLocalSaved,
  ).then((result) => result.succeeded);

  /// Updates metadata while identifying an impossible new private target.
  /// Other updates preserve the existing local-save and relay-ACK milestones.
  Future<CuratedListUpdateResult> updateListWithResult({
    required String listId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    PlayOrder? playOrder,
    void Function()? onLocalSaved,
  }) {
    if (isReadyForMutations) {
      final cached = getListById(listId);
      // Reject a known impossible privacy flip before queueing or changing any
      // metadata. The queued turn checks its current row again before storage.
      if (cached != null &&
          cached.isPublic &&
          isPublic == false &&
          _authService.isAuthenticated &&
          _canMutateCachedList(cached) &&
          hasValidCuratedListVisibility(
            false,
            isCollaborative ?? cached.isCollaborative,
          ) &&
          !_relayGateway.privateItemPayloadFits(cached)) {
        return Future.value(const CuratedListUpdateResult.privateListFull());
      }
    }
    return _serializeListOperation(
      listId,
      () => _updateList(
        listId: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        isPublic: isPublic,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
        onLocalSaved: onLocalSaved,
      ),
      cancelled: const CuratedListUpdateResult.failed(),
    );
  }

  Future<CuratedListUpdateResult> _updateList({
    required String listId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    PlayOrder? playOrder,
    void Function()? onLocalSaved,
  }) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        return const CuratedListUpdateResult.failed();
      }

      final list = _lists[listIndex];
      if (!_canMutateCachedList(list)) {
        return const CuratedListUpdateResult.failed();
      }
      _publishClock.observe(list);
      final visibilityChanged = isPublic != null && isPublic != list.isPublic;
      if (visibilityChanged && !_authService.isAuthenticated) {
        Log.warning(
          'Cannot change list visibility while signed out: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return const CuratedListUpdateResult.failed();
      }

      final updatedList = list.copyWith(
        pubkey: list.pubkey ?? _relayGateway.currentAuthenticatedPubkey(),
        name: name ?? list.name,
        description: description ?? list.description,
        clearDescription: description != null && description.isEmpty,
        imageUrl: imageUrl ?? list.imageUrl,
        isPublic: isPublic ?? list.isPublic,
        clearPendingVisibility: isPublic != null,
        tags: tags ?? list.tags,
        isCollaborative: isCollaborative ?? list.isCollaborative,
        allowedCollaborators: allowedCollaborators ?? list.allowedCollaborators,
        thumbnailEventId: thumbnailEventId ?? list.thumbnailEventId,
        playOrder: playOrder ?? list.playOrder,
        updatedAt: clock.now(),
      );
      if (!hasValidCuratedListVisibility(
        updatedList.isPublic,
        updatedList.isCollaborative,
      )) {
        Log.warning(
          'Cannot make a collaborative list private - private items are '
          'encrypted to the owner only',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return const CuratedListUpdateResult.failed();
      }

      if (visibilityChanged &&
          !updatedList.isPublic &&
          !_relayGateway.privateItemPayloadFits(updatedList)) {
        return const CuratedListUpdateResult.privateListFull();
      }

      // Metadata saves locally; visibility and permissions await acceptance.
      _lists[listIndex] = updatedList.stageVisibilityFrom(list);
      if (!await _saveLists(
        ownershipClaims: list.pubkey == null && updatedList.pubkey != null
            ? {updatedList.authorScopedId: list}
            : const {},
      )) {
        _restoreList(list);
        return const CuratedListUpdateResult.failed();
      }
      onLocalSaved?.call();

      final becamePrivate =
          list.isPublic && !updatedList.publicationTarget.isPublic;
      final plaintextEventId = becamePrivate ? list.nostrEventId : null;

      if (_authService.isAuthenticated &&
          !await _publishListToNostr(updatedList, confirmed: true)) {
        if (!visibilityChanged) {
          final currentIndex = _listIndex(listId);
          if (currentIndex != -1) {
            _lists[currentIndex] = _lists[currentIndex].copyWith(
              pendingRepublish: true,
            );
            await _saveLists();
          }
        }
        return const CuratedListUpdateResult.failed();
      }

      if (plaintextEventId != null &&
          _authService.currentPublicKeyHex == list.pubkey) {
        try {
          await _relayGateway.redactPlaintextListEvent(
            plaintextEventId,
            ownerPubkey: list.pubkey,
            createdAt: _publishClock.next(
              ownerPubkey: list.pubkey!,
              listId: list.id,
            ),
          );
        } on CuratedListClockException catch (error) {
          Log.warning(
            'Privacy replacement accepted; redaction deferred: $error',
            category: LogCategory.system,
          );
        }
      }

      return const CuratedListUpdateResult.saved();
    } catch (e) {
      Log.error(
        'Failed to update list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return const CuratedListUpdateResult.failed();
    }
  }

  /// Deletes the captured owned coordinate after confirming any relay deletion.
  Future<bool> deleteOwnedList(String listId) {
    final list = getListById(listId);
    if (list == null || !isOwnedList(list.authorScopedId)) {
      return Future.value(false);
    }
    return _serializeListOperation(
      list.id,
      () => _deleteOwnedList(list.authorScopedId),
      cancelled: false,
    );
  }

  Future<bool> _deleteOwnedList(String listId) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      if (!isOwnedList(listId) ||
          !_cacheStore.hasUnambiguousOwnerEvidence(list)) {
        Log.warning(
          'Cannot delete list not owned by current user: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      if (list.nostrEventId != null || list.pendingRepublish) {
        if (!await _relayGateway.publishListDeletion(
          list.id,
          ownerPubkey: list.pubkey!,
          createdAt: _publishClock.next(
            ownerPubkey: list.pubkey!,
            listId: list.id,
          ),
        )) {
          return false;
        }
      }

      // Recorded whatever the local event id says. A null id does not mean no
      // relay holds this coordinate — another device can have published the
      // same stable d-tag independently, which is the case the unpublished
      // merge in [_processListEvent] exists to handle. Record before removing
      // the local list so relay sync never sees an unprotected absence.
      if (!await _cacheStore.recordListDeletion(list.pubkey!, list.id) ||
          !await _removeListAndSubscription(list)) {
        return false;
      }
      if (list.id == defaultListId) {
        await _cacheStore.markDefaultListDeleted();
      }

      Log.info(
        'Deleted owned curated list: ${list.name} ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to delete owned curated list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Removes the captured coordinate after the deletion publish completes.
  Future<bool> _removeListAndSubscription(CuratedList list) async {
    _lists.removeWhere((item) => item.authorScopedId == list.authorScopedId);
    // Keep the follow until the list removal is durably saved.
    if (!await _saveLists()) {
      _restoreList(list);
      return false;
    }
    _subscribedListIds.remove(list.authorScopedId);
    if (!_lists.any((item) => item.id == list.id)) {
      _subscribedListIds.remove(list.id);
    }
    if (!await _saveSubscribedListIds()) return false;
    _onListUnsubscribed?.call(list.authorScopedId);
    return true;
  }

  // === ENHANCED PLAYLIST FEATURES ===

  /// Reorder videos in a playlist (manual play order)
  Future<bool> reorderVideos(String listId, List<String> newOrder) {
    return _serializeListOperation(
      listId,
      () => _reorderVideos(listId, newOrder),
      cancelled: false,
    );
  }

  /// Get ordered video list based on play order setting
  List<String> getOrderedVideoIds(String listId) => _getOrderedVideoIds(listId);

  /// Add collaborator to a list
  Future<bool> addCollaborator(String listId, String pubkey) {
    return _serializeListOperation(
      listId,
      () => _addCollaborator(listId, pubkey),
      cancelled: false,
    );
  }

  Future<bool> _addCollaborator(String listId, String pubkey) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      if (!_canMutateCachedList(list)) return false;
      if (!list.isCollaborative) {
        Log.warning(
          'Cannot add collaborator - list is not collaborative',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      if (list.allowedCollaborators.contains(pubkey)) {
        Log.debug(
          'User already a collaborator: ${pubkeyForLogs(pubkey)}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true;
      }

      final updatedCollaborators = [...list.allowedCollaborators, pubkey];
      final updatedList = list.copyWith(
        allowedCollaborators: updatedCollaborators,
        updatedAt: clock.now(),
      );

      if (!await _commitListMutation(updatedList)) return false;

      Log.debug(
        '✅ Added collaborator to list "${list.name}": ${pubkeyForLogs(pubkey)}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to add collaborator: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove collaborator from a list
  Future<bool> removeCollaborator(String listId, String pubkey) {
    return _serializeListOperation(
      listId,
      () => _removeCollaborator(listId, pubkey),
      cancelled: false,
    );
  }

  Future<bool> _removeCollaborator(String listId, String pubkey) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      final updatedCollaborators = list.allowedCollaborators
          .where((collaborator) => collaborator != pubkey)
          .toList();

      final updatedList = list.copyWith(
        allowedCollaborators: updatedCollaborators,
        updatedAt: clock.now(),
      );

      if (!await _commitListMutation(updatedList)) return false;

      Log.debug(
        '➖ Removed collaborator from list "${list.name}": ${pubkeyForLogs(pubkey)}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to remove collaborator: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if a user can collaborate on a list
  bool canCollaborate(String listId, String pubkey) =>
      _cacheIndex.canCollaborate(listId, pubkey);

  /// Get lists by tag for discovery
  List<CuratedList> getListsByTag(String tag) =>
      _cacheIndex.publicListsByTag(tag);

  /// Get all unique tags across all lists
  List<String> getAllTags() => _cacheIndex.publicTags;

  /// Search lists by name or description
  List<CuratedList> searchLists(String query) =>
      _cacheIndex.searchPublic(query);

  /// Get all lists that contain a specific video
  List<CuratedList> getListsContainingVideo(String videoEventId) =>
      _cacheIndex.containingVideo(videoEventId);

  // === SUBSCRIPTION MANAGEMENT ===

  /// Subscribe to a curated list (saves list data for offline access)
  Future<bool> subscribeToList(String listId, [CuratedList? listData]) async {
    try {
      // Check if list exists in our cache
      var list = getListById(listId);

      // If list not in cache but listData provided, add it
      if (list == null && listData != null) {
        _lists.add(listData);
        await _saveLists();
        list = listData;
        Log.debug(
          'Added discovered list to cache: ${listData.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }

      if (list == null) {
        Log.warning(
          'Cannot subscribe - list not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      // Check if already subscribed
      if (isSubscribedToList(listId)) {
        Log.debug(
          'Already subscribed to list: ${list.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true;
      }

      // Add to subscribed lists
      _subscribedListIds.add(listId);
      await _saveSubscribedListIds();

      Log.info(
        'Subscribed to list: ${list.name} ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Trigger video cache sync for this list
      if (_onListSubscribed != null && list.videoEventIds.isNotEmpty) {
        Log.debug(
          'Triggering video cache sync for list: ${list.name} '
          '(${list.videoEventIds.length} videos)',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        await _onListSubscribed!(listId, list.videoEventIds);
      }

      return true;
    } catch (e) {
      Log.error(
        'Failed to subscribe to list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Unsubscribe from a curated list
  Future<bool> unsubscribeFromList(String listId) async {
    try {
      // Check if subscribed
      final subscriptionId = _subscriptionId(listId);
      if (!_subscribedListIds.contains(subscriptionId)) {
        Log.debug(
          'Not subscribed to list: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return true;
      }

      final list = getListById(listId);
      final listName = list?.name ?? listId;

      // Remove from subscribed lists
      _subscribedListIds.remove(subscriptionId);
      await _saveSubscribedListIds();

      Log.info(
        'Unsubscribed from list: $listName ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Remove list from video cache
      _onListUnsubscribed?.call(subscriptionId);

      return true;
    } catch (e) {
      Log.error(
        'Failed to unsubscribe from list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Check if user is subscribed to a list
  bool isSubscribedToList(String listId) {
    return _subscribedListIds.contains(_subscriptionId(listId));
  }

  /// Accept legacy subscription IDs only when they resolve to this author.
  String _subscriptionId(String listId) =>
      _cacheIndex.subscriptionId(listId, _subscribedListIds);

  /// Check whether the current user owns a locally cached curated list.
  bool isOwnedList(String listId) =>
      _cacheIndex.isOwnedBy(listId, _relayGateway.currentAuthenticatedPubkey());

  /// Get readable summary of lists containing a video
  String getVideoListSummary(String videoEventId) {
    final listsContaining = getListsContainingVideo(videoEventId);

    if (listsContaining.isEmpty) {
      return 'Not in any lists';
    }

    if (listsContaining.length == 1) {
      return 'In "${listsContaining.first.name}"';
    }

    if (listsContaining.length <= 3) {
      final names = listsContaining.map((list) => '"${list.name}"').join(', ');
      return 'In $names';
    }

    return 'In ${listsContaining.length} lists';
  }

  /// Create the default "My List" for quick access
  /// Default list is PRIVATE - users can make it public if they want
  Future<void> _createDefaultList() async {
    await _createList(
      id: defaultListId,
      name: 'My List',
      description: 'My favorite vines and videos',
      isPublic: false,
    );
  }

  /// Confirmed writes await acceptance; queued item changes stay local for retry.
  Future<bool> _publishListToNostr(
    CuratedList sourceList, {
    bool confirmed = false,
  }) async {
    try {
      final list = sourceList.publicationTarget;
      final ownerPubkey = _relayGateway.currentAuthenticatedPubkey();
      if (ownerPubkey == null || list.pubkey != ownerPubkey) {
        Log.warning(
          'Cannot publish list - authenticated owner does not match',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final event = await _relayGateway.signList(
        list,
        ownerPubkey: ownerPubkey,
        createdAt: () => _publishClock.next(
          ownerPubkey: ownerPubkey,
          listId: list.id,
        ),
      );

      if (event == null ||
          event.pubkey != ownerPubkey ||
          _relayGateway.currentAuthenticatedPubkey() != ownerPubkey) {
        Log.warning(
          'Failed to sign curated list event: ${list.name} (${list.id})',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final sendingIndex = _lists.indexWhere(
        (l) => l.authorScopedId == list.authorScopedId,
      );
      if (sendingIndex != -1) {
        final current = _lists[sendingIndex];
        final signedAt = event.createdAtDateTime;
        _lists[sendingIndex] = list
            .stageVisibilityFrom(current, stageProposal: true)
            .copyWith(
              updatedAt: signedAt.isAfter(current.updatedAt)
                  ? signedAt
                  : current.updatedAt,
              pendingRepublish: true,
            );
        if (!await _saveLists()) return false;
      }
      if (confirmed) {
        final outcome = await _nostrService.publishEventAwaitOk(event);
        // A privacy transition commits once any relay accepts it.
        if (!outcome.acceptedByAny) {
          final rejected = getListById(list.authorScopedId);
          if (outcome.rejectedBy.isNotEmpty &&
              outcome.noResponseFrom.isEmpty &&
              rejected != null) {
            _restoreList(rejected.copyWith(clearPendingVisibility: true));
            await _saveLists();
          }
          if (outcome.rejectedBy.values.any(
            (reason) => reason.toLowerCase().contains('future'),
          )) {
            _publishClock.rejectedFuture(
              ownerPubkey: ownerPubkey,
              listId: list.id,
              createdAt: event.createdAt,
            );
          }
          Log.warning(
            'Failed to publish curated list: ${list.name} (${list.id}): '
            '${outcome.summary}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          return false;
        }
      } else {
        final publishResult = await _nostrService.publishEvent(event);
        final failureReason = publishResult.failureReason;
        if (failureReason != null) {
          Log.warning(
            'Failed to publish curated list: ${list.name} (${list.id}): '
            '$failureReason',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          return false;
        }
      }

      final listIndex = _lists.indexWhere(
        (l) => l.authorScopedId == list.authorScopedId,
      );
      if (listIndex != -1) {
        final current = _lists[listIndex];
        final commitsVisibility = current.isPublic != list.isPublic;
        final signedAt = event.createdAtDateTime;
        _lists[listIndex] = _lists[listIndex].copyWith(
          nostrEventId: event.id,
          updatedAt: signedAt.isAfter(current.updatedAt)
              ? signedAt
              : current.updatedAt,
          isPublic: list.isPublic,
          isCollaborative: commitsVisibility ? list.isCollaborative : null,
          allowedCollaborators: commitsVisibility
              ? list.allowedCollaborators
              : null,
          pendingRepublish: false,
          clearPendingVisibility: true,
        );
        if (!await _saveLists()) {
          _restoreList(current);
          return false;
        }
      }
      return true;
    } catch (e) {
      Log.error(
        'Failed to publish list to Nostr: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  void _loadLists() {
    final listsJson = _prefs.getString(listsStorageKey);
    if (listsJson != null) {
      try {
        final listsData = jsonDecode(listsJson) as List<dynamic>;
        _lists.clear();
        _lists.addAll(
          listsData.map(
            (json) => CuratedList.fromJson(json as Map<String, dynamic>),
          ),
        );
        _lists.forEach(_publishClock.observe);
        Log.debug(
          '📱 Loaded ${_lists.length} curated lists from storage',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      } catch (e, stackTrace) {
        Log.error(
          'Failed to load curated lists (${e.runtimeType})',
          name: 'CuratedListService',
          category: LogCategory.system,
          stackTrace: stackTrace,
        );
      }
    }
    _cacheStore.listsLoaded(_lists);
  }

  void _loadSubscribedListIds() {
    final snapshot = readCuratedListSubscriptionSnapshot(
      preferences: _prefs,
      storageKey: subscribedListsStorageKey,
      fallback: _subscribedListIds,
    );
    _subscribedListIds
      ..clear()
      ..addAll(snapshot.ids);
    _hasLoadedSubscriptionIds = snapshot.isReadable;
    _cacheStore.subscriptionsLoaded(snapshot.ids);
  }

  /// Persist local lists before reporting success or publishing their delta.
  Future<bool> _saveLists({
    Map<String, CuratedList> ownershipClaims = const {},
  }) async {
    if (!isCurrentSession) return false;
    final owner = _relayGateway.currentAuthenticatedPubkey();
    notifyListeners();
    try {
      await _cacheStore.saveListsOrThrow(
        _lists,
        isCurrent: () => _isCurrent(owner),
        ownershipClaims: ownershipClaims,
      );
      return true;
    } on Exception catch (error, stackTrace) {
      Log.error(
        'Curated list storage failed (${error.runtimeType})',
        name: 'CuratedListService',
        category: LogCategory.system,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (_isCurrent(owner)) notifyListeners();
    }
  }

  /// Persist follows before notifying video-cache subscription callbacks.
  Future<bool> _saveSubscribedListIds() async {
    if (_isDisposed) return false;
    final owner = _relayGateway.currentAuthenticatedPubkey();
    notifyListeners();
    try {
      await _cacheStore.saveSubscriptionsOrThrow(
        _subscribedListIds,
        isCurrent: () => _isCurrent(owner),
      );
      return true;
    } on Exception catch (error, stackTrace) {
      Log.error(
        'List subscription storage failed (${error.runtimeType})',
        name: 'CuratedListService',
        category: LogCategory.system,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (_isCurrent(owner)) notifyListeners();
    }
  }

  /// Fetch the user's curated lists from Nostr relays.
  ///
  /// Runs at most once per session unless [force] is set, which is what
  /// pull-to-refresh passes: without it a list created on another device only
  /// appears after the app restarts.
  Future<void> fetchUserListsFromRelays({bool force = false}) async {
    if (!_authService.isAuthenticated) {
      Log.warning(
        'Cannot fetch lists from relays - user not authenticated',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }

    if (_hasSyncedWithRelays && !force) {
      Log.debug(
        'Already synced with relays this session',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }

    final userPubkey = _authService.currentPublicKeyHex;
    if (userPubkey == null) return;

    Log.info(
      "📋 Fetching user's curated lists from relays for pubkey: ${pubkeyForLogs(userPubkey)}",
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    try {
      final snapshot = await CuratedListRelaySnapshotReader(
        nostrClient: _nostrService,
      ).read(ownerPubkey: userPubkey, timeout: _relaySyncTimeout);
      final receivedEvents = snapshot.events;
      // Process received events
      if (receivedEvents.isNotEmpty) {
        await _processReceivedListEvents(receivedEvents);
      }

      if (!snapshot.completedNormally) {
        Log.warning(
          'Relay sync was incomplete; partial events were merged but local '
          'lists will not be backfilled until a complete sync',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      _hasSyncedWithRelays = true;
      Log.info(
        '✅ Relay sync complete. Found ${receivedEvents.length} list events',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // After the merge, so a list the relay already holds is not republished
      // from a stale local copy.
      await _backfillUnpublishedLists();
    } catch (e) {
      Log.error(
        'Failed to fetch lists from relays: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Process list events received from relays
  Future<void> _processReceivedListEvents(List<Event> events) async {
    final latest = CuratedListConverter.latestRevisions(events);

    Log.debug(
      'Processing ${latest.length} unique lists from relays',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    // Process each unique list
    for (final event in latest) {
      await _processListEvent(event);
    }

    // Save updated lists to local storage
    await _saveLists();
  }

  /// Publishes owned lists that have never reached a relay or need retry.
  ///
  /// Before private lists were published, they existed only in
  /// SharedPreferences and died with the device; the same is true of any list
  /// created while the app could not reach a relay. Failed edits keep
  /// [CuratedList.nostrEventId] as the marker that a relay may still hold this
  /// coordinate, and set [CuratedList.pendingRepublish] for the retry.
  Future<void> _backfillUnpublishedLists() async {
    if (!_authService.isAuthenticated) return;

    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null) return;

    final stranded = _lists
        .where(
          (list) =>
              (list.nostrEventId == null || list.pendingRepublish) &&
              (list.pubkey == owner || _isUnpublishedLocalList(list)),
        )
        .toList(growable: false);
    if (stranded.isEmpty) return;

    Log.info(
      'Backing up ${stranded.length} list(s) that never reached a relay',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    for (final list in stranded) {
      await _serializeListOperation(list.id, () async {
        final currentOwner = _relayGateway.currentAuthenticatedPubkey();
        if (!_isCurrent(owner)) return;
        var current = getListById(list.authorScopedId);
        if (current == null) return;
        if (!_cacheStore.hasUnambiguousOwnerEvidence(current)) return;
        if (current.nostrEventId != null && !current.pendingRepublish) return;
        if (_isUnpublishedLocalList(current)) {
          final currentId = current.id;
          final currentIndex = _listIndex(currentId);
          if (currentIndex == -1) return;
          final source = current;
          current = current.copyWith(pubkey: currentOwner);
          _lists[currentIndex] = current;
          if (!await _saveLists(
            ownershipClaims: {current.authorScopedId: source},
          ))
            return;
        }
        if (current.pubkey != currentOwner) return;
        await _publishListToNostr(current, confirmed: true);
      });
    }
  }

  /// Process a single list event from Nostr
  Future<void> _processListEvent(Event event) async {
    try {
      final unsealedItemTags = await _relayGateway.unsealItemTags(event);
      if (unsealedItemTags.status == UnsealItemTagsStatus.failed) {
        Log.warning(
          'Skipping list event ${event.id} because its private items '
          'could not be unsealed',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      final curatedList = CuratedListConverter.fromEvent(
        event,
        privateTags: unsealedItemTags.tags,
        isPrivateEvent:
            unsealedItemTags.status == UnsealItemTagsStatus.unsealed,
      );
      if (curatedList == null) {
        Log.warning(
          'Failed to parse list event: ${event.id}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }
      _publishClock.observe(curatedList);
      final dTag = curatedList.id;
      if (dTag == defaultListId && _cacheStore.wasDefaultListDeleted()) {
        Log.debug(
          'Skipping deleted default list event from relay: ${event.id}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      // Check if we already have this list locally
      final ownerPubkey = _relayGateway.currentAuthenticatedPubkey();
      final existingListIndex = _lists.indexWhere(
        (list) =>
            list.id == dTag &&
            (list.pubkey == event.pubkey ||
                (list.pubkey == null &&
                    event.pubkey == ownerPubkey &&
                    !isSubscribedToList(list.id))),
      );

      if (existingListIndex != -1) {
        // Update existing list if relay version is newer
        final existingList = _lists[existingListIndex];
        final isSameOwner =
            existingList.pubkey == event.pubkey ||
            (existingList.pubkey == null &&
                event.pubkey == ownerPubkey &&
                !_subscribedListIds.contains(existingList.id));
        if (existingList.nostrEventId == null &&
            !existingList.pendingRepublish &&
            isSameOwner) {
          // A null event id may be a legacy device-only private list or a
          // local edit that could not reach a relay. Another device can have
          // independently published the same stable d-tag. Preserve both
          // item sets and backfill their union after the full sync instead of
          // letting whichever device wrote last silently erase the other.
          final relayIsNewer =
              event.createdAt >
              existingList.updatedAt.millisecondsSinceEpoch ~/ 1000;
          final preferred = relayIsNewer ? curatedList : existingList;
          final other = relayIsNewer ? existingList : curatedList;
          final mergedVideoIds = <String>[];
          final seenVideoIds = <String>{};
          for (final id in [
            ...preferred.videoEventIds,
            ...other.videoEventIds,
          ]) {
            if (seenVideoIds.add(id)) mergedVideoIds.add(id);
          }
          final isCollaborative =
              existingList.isCollaborative || curatedList.isCollaborative;
          final collaborators = <String>{
            ...existingList.allowedCollaborators,
            ...curatedList.allowedCollaborators,
          }.toList(growable: false);
          final isPublic = existingList.isPublic && curatedList.isPublic;
          final hasPrivacyConflict = !hasValidCuratedListVisibility(
            isPublic,
            isCollaborative,
          );
          if (hasPrivacyConflict) {
            Log.warning(
              'Keeping list $dTag private and dropping collaboration during '
              'relay merge',
              name: 'CuratedListService',
              category: LogCategory.system,
            );
          }

          _lists[existingListIndex] = preferred.copyWith(
            pubkey: event.pubkey,
            videoEventIds: mergedVideoIds,
            createdAt: existingList.createdAt,
            updatedAt: clock.now(),
            isCollaborative: isCollaborative && !hasPrivacyConflict,
            allowedCollaborators: hasPrivacyConflict ? const [] : collaborators,
            isPublic: isPublic,
            clearNostrEventId: true,
            pendingRepublish: false,
          );
          Log.info(
            'Merged unpublished local and relay copies of list $dTag',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          return;
        }

        if (event.createdAt >
            existingList.updatedAt.millisecondsSinceEpoch ~/ 1000) {
          Log.debug(
            'Updating existing list from relay: ${curatedList.name}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );

          _lists[existingListIndex] = curatedList.copyWith(
            createdAt: existingList.createdAt,
          );
        } else {
          Log.debug(
            'Skipping older relay version of list: ${curatedList.name}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        }
      } else {
        // Checked here rather than earlier so the tombstone only ever blocks a
        // resurrection. A list still present locally keeps syncing normally,
        // which is what should happen if a delete failed after recording it.
        if (_cacheStore.wasListDeleted(event.pubkey, dTag)) {
          Log.debug(
            'Skipping deleted list event from relay: $dTag',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          return;
        }

        // Add new list from relay
        Log.debug(
          'Adding new list from relay: ${curatedList.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );

        _lists.add(curatedList);
      }
    } catch (e) {
      Log.error(
        'Failed to process list event ${event.id}: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// See [CuratedListRelayGateway.streamPublicListsFromRelays].
  Stream<List<CuratedList>> streamPublicListsFromRelays({
    DateTime? until,
    int limit = kPublicListsRelayWindow,
    Set<String>? excludeIds,
    Duration timeout = kPublicCuratedListsRelayReadTimeout,
  }) => _canReadPublicLists
      ? _relayGateway.streamPublicListsFromRelays(
          until: until,
          limit: limit,
          excludeIds: excludeIds,
          timeout: timeout,
        )
      : const Stream.empty();

  /// See [CuratedListRelayGateway.fetchPublicList].
  Future<CuratedList?> fetchPublicList({
    required String authorPubkey,
    required String listId,
  }) => _canReadPublicLists
      ? _relayGateway.fetchPublicList(
          authorPubkey: authorPubkey,
          listId: listId,
        )
      : Future.value();

  /// See [CuratedListRelayGateway.fetchPublicListsContainingVideo].
  Future<List<CuratedList>> fetchPublicListsContainingVideo(
    String videoEventId,
  ) => _canReadPublicLists
      ? _relayGateway.fetchPublicListsContainingVideo(videoEventId)
      : Future.value(const []);

  /// See [CuratedListRelayGateway.streamPublicListsContainingVideo].
  Stream<CuratedList> streamPublicListsContainingVideo(String videoEventId) =>
      _canReadPublicLists
      ? _relayGateway.streamPublicListsContainingVideo(videoEventId)
      : const Stream.empty();
}
