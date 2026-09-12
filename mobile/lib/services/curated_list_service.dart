// ABOUTME: Service for managing NIP-51 curated lists (kind 30005) for video collections
// ABOUTME: Handles creation, updates, and management of user's video lists
//
// Every owned list is published, whatever its visibility. A public list carries
// its video references in plain `e`/`a` tags. A private one publishes the same
// metadata tags but seals those references into the event content with NIP-44,
// encrypted to the owner, so relays and other users can see that the list
// exists and what it is called but not what is in it.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/models/curated_list_callbacks.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/utils/curated_list_privacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/curated_list_callbacks.dart';

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
    OnListSubscribedCallback? onListSubscribed,
    OnListUnsubscribedCallback? onListUnsubscribed,
    Duration relaySyncTimeout = const Duration(seconds: 10),
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs,
       _onListSubscribed = onListSubscribed,
       _onListUnsubscribed = onListUnsubscribed,
       _relaySyncTimeout = relaySyncTimeout,
       _relayGateway = CuratedListRelayGateway(
         nostrService: nostrService,
         authService: authService,
       ) {
    _loadLists();
    _loadSubscribedListIds();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;
  final Duration _relaySyncTimeout;
  final CuratedListRelayGateway _relayGateway;

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
  static const String deletedListCoordinatesStorageKey =
      'deleted_curated_list_coordinates';
  static const String defaultListDeletedStorageKey =
      'curated_lists_default_deleted';
  static const String defaultListId = 'my_vine_list';
  static const String _createListOperationId = '__create_curated_list__';

  final List<CuratedList> _lists = [];
  final Set<String> _subscribedListIds = {};
  bool _isInitialized = false;

  // Track relay sync status
  bool _hasSyncedWithRelays = false;

  // Mutations to one addressable list must publish in the same order they are
  // applied locally. In particular, an item add cannot overtake a public to
  // private transition and put the new item back into plaintext relay tags.
  final Map<String, Future<void>> _listOperationTails = {};

  Future<T> _serializeListOperation<T>(
    String listId,
    Future<T> Function() operation,
  ) async {
    final previous = _listOperationTails[listId] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _listOperationTails[listId] = tail;

    await previous;
    try {
      return await operation();
    } finally {
      completed.complete();
      if (identical(_listOperationTails[listId], tail)) {
        _listOperationTails.remove(listId);
      }
    }
  }

  // Getters
  List<CuratedList> get lists => List.unmodifiable(_lists);
  bool get isInitialized => _isInitialized;

  /// Get all subscribed list IDs
  Set<String> get subscribedListIds => Set.unmodifiable(_subscribedListIds);

  /// Get all subscribed lists
  List<CuratedList> get subscribedLists {
    return _lists
        .where((list) => _subscribedListIds.contains(list.id))
        .toList();
  }

  /// Lists belonging to the current user: lists they own (by pubkey) plus
  /// local-only lists that have not been published to Nostr yet.
  ///
  /// Owned lists keep showing here after a successful publish — filtering
  /// only on a null [CuratedList.nostrEventId] made lists vanish from the
  /// "My Lists" UI the moment they reached the relay.
  List<CuratedList> get myLists {
    final currentPubkey = _relayGateway.currentAuthenticatedPubkey();
    return _lists
        .where(
          (list) =>
              list.nostrEventId == null ||
              (currentPubkey != null && list.pubkey == currentPubkey),
        )
        .toList();
  }

  /// Initialize the service and create default list if needed.
  ///
  /// This method returns quickly after loading local cache.
  /// Relay sync happens in background and does not block initialization.
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

      // Create default list if it doesn't exist and the user has not explicitly
      // withdrawn its relay coordinate.
      if (!hasDefaultList() && !_wasDefaultListDeleted()) {
        await _createDefaultList();
      }

      // Mark initialized IMMEDIATELY after local cache is ready
      // This allows downstream consumers to access cached lists without waiting
      _isInitialized = true;
      notifyListeners();
      Log.info(
        'Curated list service initialized with ${_lists.length} lists (local cache ready)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Sync with relays in BACKGROUND - does not block initialization
      // When relay sync completes, it will merge new lists and notify listeners
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
  bool hasDefaultList() => _lists.any((list) => list.id == defaultListId);

  bool _wasDefaultListDeleted() {
    return _prefs.getBool(defaultListDeletedStorageKey) ?? false;
  }

  /// The `<pubkey>:<d-tag>` form of a kind 30005 coordinate.
  ///
  /// A `d` tag is only unique per author, so a deletion has to be remembered
  /// against its owner. Keying on the identifier alone would suppress a list
  /// that merely shares it — another account on this device, or someone
  /// else's list arriving from a relay.
  String _listCoordinate(String ownerPubkey, String listId) =>
      '$ownerPubkey:$listId';

  /// Coordinates this install has deleted.
  ///
  /// NIP-09 is advisory: a relay may never see the deletion request, or may
  /// decline it, and keep replaying the original event. Without a local record
  /// the next sync adds the list straight back. The set is not pruned — an
  /// entry is a few dozen bytes, deletions are rare, and there is no point at
  /// which every relay is known to have honoured the request.
  Set<String> _deletedListCoordinates() =>
      (_prefs.getStringList(deletedListCoordinatesStorageKey) ?? const [])
          .toSet();

  Future<void> _recordListDeletion(String ownerPubkey, String listId) async {
    final coordinates = _deletedListCoordinates()
      ..add(_listCoordinate(ownerPubkey, listId));
    await _prefs.setStringList(
      deletedListCoordinatesStorageKey,
      coordinates.toList(growable: false),
    );
  }

  /// Lifts the tombstone so a re-created list can sync again.
  Future<void> _forgetListDeletion(String ownerPubkey, String listId) async {
    final coordinates = _deletedListCoordinates();
    if (!coordinates.remove(_listCoordinate(ownerPubkey, listId))) return;
    await _prefs.setStringList(
      deletedListCoordinatesStorageKey,
      coordinates.toList(growable: false),
    );
  }

  /// Get the default "My List" for quick adding
  CuratedList? getDefaultList() {
    try {
      return _lists.firstWhere((list) => list.id == defaultListId);
    } catch (e) {
      return null;
    }
  }

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
  /// Two lists created within the same millisecond would otherwise share an
  /// ID, and ID-based lookups (e.g. the post-publish copyWith) would then
  /// overwrite the wrong list.
  String _generateListId(DateTime now) {
    final base = 'list_${now.millisecondsSinceEpoch}';
    var listId = base;
    var suffix = 1;
    while (_lists.any((list) => list.id == listId)) {
      listId = '${base}_$suffix';
      suffix++;
    }
    return listId;
  }

  /// Internal method to create a list with optional explicit ID
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

      final now = DateTime.now();
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

      // Re-using a deleted identifier has to lift its tombstone, or the new
      // list's own relay events would be discarded for the life of the install
      // and it would never reach another device.
      if (ownerPubkey != null) {
        await _forgetListDeletion(ownerPubkey, listId);
      }

      _lists.add(newList);
      await _saveLists();

      // Private lists publish too, with their items sealed. A list that only
      // ever lived in SharedPreferences died with the device.
      if (_authService.isAuthenticated) {
        // Publish under the list's own operation lane, re-checking that it is
        // still unpublished. A concurrent relay-sync backfill runs on the same
        // lane, so it cannot publish a second event for this coordinate while
        // the create is in flight. Keep the local list when no relay is
        // reachable — its null event id makes the next complete sync back it up.
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

  Future<bool> _commitListMutation(CuratedList updatedList) async {
    if (!updatedList.isPublic &&
        !_relayGateway.privateItemPayloadFits(updatedList)) {
      return false;
    }

    final listIndex = _lists.indexWhere((list) => list.id == updatedList.id);
    if (listIndex == -1) return false;

    _lists[listIndex] = updatedList;
    await _saveLists();

    if (_authService.isAuthenticated &&
        !await _publishListToNostr(updatedList)) {
      final currentIndex = _lists.indexWhere(
        (list) => list.id == updatedList.id,
      );
      if (currentIndex != -1) {
        // Unconfirmed publishing queues network failures for reconnect. Keep
        // the local edit so a queued event cannot later disagree with local
        // state, and mark it for backfill without losing the event id that says
        // a relay may still hold this coordinate.
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
    );
  }

  Future<bool> _addVideoToList(String listId, String videoEventId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];

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
        updatedAt: DateTime.now(),
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
    );
  }

  Future<bool> _removeVideoFromList(String listId, String videoEventId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
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
        updatedAt: DateTime.now(),
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

  /// Check if video is in a specific list
  bool isVideoInList(String listId, String videoEventId) {
    final list = _lists.where((l) => l.id == listId).firstOrNull;
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Check if video is in default list
  bool isVideoInDefaultList(String videoEventId) =>
      isVideoInList(defaultListId, videoEventId);

  /// Get list by ID
  CuratedList? getListById(String listId) {
    try {
      return _lists.firstWhere((list) => list.id == listId);
    } catch (e) {
      return null;
    }
  }

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
  }) {
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
      ),
    );
  }

  Future<bool> _updateList({
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
  }) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      final visibilityChanged = isPublic != null && isPublic != list.isPublic;
      if (visibilityChanged && !_authService.isAuthenticated) {
        Log.warning(
          'Cannot change list visibility while signed out: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final updatedList = list.copyWith(
        name: name ?? list.name,
        description: description ?? list.description,
        clearDescription: description != null && description.isEmpty,
        imageUrl: imageUrl ?? list.imageUrl,
        isPublic: isPublic ?? list.isPublic,
        tags: tags ?? list.tags,
        isCollaborative: isCollaborative ?? list.isCollaborative,
        allowedCollaborators: allowedCollaborators ?? list.allowedCollaborators,
        thumbnailEventId: thumbnailEventId ?? list.thumbnailEventId,
        playOrder: playOrder ?? list.playOrder,
        updatedAt: DateTime.now(),
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
        return false;
      }

      // Name, description and the rest of the edit are local-first: they are
      // stored on this device and the relay copy is a projection of them, so
      // an unreachable relay must not cost the user a rename. Visibility is
      // the exception — it is a statement about what the relays hold — so it
      // alone stays at its old value until the relay confirms the change.
      // Written before any publish await, so [listIndex] is still valid.
      _lists[listIndex] = updatedList.copyWith(isPublic: list.isPublic);
      await _saveLists();

      // Kind 30005 is addressable, so publishing under the same d-tag
      // replaces whatever the relays hold — including a public copy whose
      // items were in plain tags. That is what makes a list private; the
      // plaintext event that preceded it is then redacted by id below.
      final becamePrivate = list.isPublic && !updatedList.isPublic;
      final plaintextEventId = becamePrivate ? list.nostrEventId : null;

      if (_authService.isAuthenticated &&
          !await _publishListToNostr(updatedList, confirmed: true)) {
        // A failed metadata edit (rename, description, tags, order) is retried
        // by backfill like a failed item edit: flag it without clearing the
        // event id that later privacy redaction and deletion use to know a
        // relay may still hold this coordinate. A failed visibility flip is
        // left alone: no relay accepted the sealed replacement, so the
        // plaintext copy is still what every relay serves and the list must
        // keep saying public until the user retries.
        if (!visibilityChanged) {
          final currentIndex = _lists.indexWhere((l) => l.id == listId);
          if (currentIndex != -1) {
            _lists[currentIndex] = _lists[currentIndex].copyWith(
              pendingRepublish: true,
            );
            await _saveLists();
          }
        }
        return false;
      }

      if (plaintextEventId != null) {
        await _relayGateway.redactPlaintextListEvent(plaintextEventId);
      }

      // A successful publish already persisted the edit: _publishListToNostr
      // writes the updated list plus its accepted event ID back by ID and
      // saves, so writing [updatedList] over it here would drop that ID. Only
      // the signed-out case still owes a write, and it must re-resolve the
      // index — [listIndex] was captured before the publish awaits above.
      if (!_authService.isAuthenticated) {
        final currentIndex = _lists.indexWhere((list) => list.id == listId);
        if (currentIndex == -1) {
          return false;
        }
        _lists[currentIndex] = updatedList;
        await _saveLists();
      }

      Log.debug(
        '✏️ Updated list: ${updatedList.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to update list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Delete a list owned by the current user.
  ///
  /// Published lists send a NIP-09 deletion event for the kind 30005 coordinate
  /// before local state is removed. A list that never reached a relay has no
  /// event to delete and can be removed locally.
  Future<bool> deleteOwnedList(String listId) {
    return _serializeListOperation(listId, () => _deleteOwnedList(listId));
  }

  Future<bool> _deleteOwnedList(String listId) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      if (!isOwnedList(listId)) {
        Log.warning(
          'Cannot delete list not owned by current user: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      // Private lists are on relays too, sealed rather than absent, so both
      // kinds need the NIP-09 request. [nostrEventId] means a relay may still
      // hold this coordinate even when [pendingRepublish] says the latest local
      // edit has not reached it.
      if (list.nostrEventId != null) {
        if (!await _relayGateway.publishListDeletion(listId)) {
          return false;
        }
      }

      // Recorded whatever the local event id says. A null id does not mean no
      // relay holds this coordinate — another device can have published the
      // same stable d-tag independently, which is the case the unpublished
      // merge in [_processListEvent] exists to handle. Record before removing
      // the local list so relay sync never sees an unprotected absence.
      await _recordListDeletion(list.pubkey!, listId);
      await _removeListAndSubscription(listId);
      if (listId == defaultListId) {
        await _prefs.setBool(defaultListDeletedStorageKey, true);
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

  /// Removes [listId] locally, re-resolving its position by ID.
  ///
  /// The caller captures its index before the deletion publish awaits, and
  /// under `publishEventAwaitOk` that wait runs to a 15s deadline. Anything
  /// removing an earlier list in the meantime shifts the index, so a
  /// positional remove would drop the wrong one.
  Future<void> _removeListAndSubscription(String listId) async {
    _lists.removeWhere((list) => list.id == listId);
    _subscribedListIds.remove(listId);
    await _saveLists();
    await _saveSubscribedListIds();
    _onListUnsubscribed?.call(listId);
  }

  // === ENHANCED PLAYLIST FEATURES ===

  /// Reorder videos in a playlist (manual play order)
  Future<bool> reorderVideos(String listId, List<String> newOrder) {
    return _serializeListOperation(
      listId,
      () => _reorderVideos(listId, newOrder),
    );
  }

  Future<bool> _reorderVideos(String listId, List<String> newOrder) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];

      // Validate that all current videos are included in the new order
      final currentVideos = Set<String>.from(list.videoEventIds);
      final newOrderSet = Set<String>.from(newOrder);

      if (currentVideos.difference(newOrderSet).isNotEmpty ||
          newOrderSet.difference(currentVideos).isNotEmpty) {
        Log.warning(
          'Invalid reorder: video lists do not match',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final updatedList = list.copyWith(
        videoEventIds: newOrder,
        playOrder: PlayOrder.manual, // Set to manual when reordering
        updatedAt: DateTime.now(),
      );

      if (!await _commitListMutation(updatedList)) return false;

      Log.debug(
        '📱 Reordered videos in list "${list.name}"',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to reorder videos: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Get ordered video list based on play order setting
  List<String> getOrderedVideoIds(String listId) {
    final list = getListById(listId);
    if (list == null) return [];

    switch (list.playOrder) {
      case PlayOrder.chronological:
        return list.videoEventIds; // Already in chronological order
      case PlayOrder.reverse:
        return list.videoEventIds.reversed.toList();
      case PlayOrder.manual:
        return list.videoEventIds; // Manual order as stored
      case PlayOrder.shuffle:
        final shuffled = List<String>.from(list.videoEventIds);
        shuffled.shuffle();
        return shuffled;
    }
  }

  /// Add collaborator to a list
  Future<bool> addCollaborator(String listId, String pubkey) {
    return _serializeListOperation(
      listId,
      () => _addCollaborator(listId, pubkey),
    );
  }

  Future<bool> _addCollaborator(String listId, String pubkey) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
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
        updatedAt: DateTime.now(),
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
    );
  }

  Future<bool> _removeCollaborator(String listId, String pubkey) async {
    try {
      final listIndex = _lists.indexWhere((list) => list.id == listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      final updatedCollaborators = list.allowedCollaborators
          .where((collaborator) => collaborator != pubkey)
          .toList();

      final updatedList = list.copyWith(
        allowedCollaborators: updatedCollaborators,
        updatedAt: DateTime.now(),
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
  bool canCollaborate(String listId, String pubkey) {
    final list = getListById(listId);
    if (list == null) return false;

    // List owner can always collaborate
    if (_authService.currentPublicKeyHex == pubkey) return true;

    // Check if collaborative and user is allowed
    return list.isCollaborative && list.allowedCollaborators.contains(pubkey);
  }

  /// Get lists by tag for discovery
  List<CuratedList> getListsByTag(String tag) {
    return _lists
        .where((list) => list.isPublic && list.tags.contains(tag.toLowerCase()))
        .toList();
  }

  /// Get all unique tags across all lists
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final list in _lists) {
      if (list.isPublic) {
        allTags.addAll(list.tags);
      }
    }
    return allTags.toList()..sort();
  }

  /// Search lists by name or description
  List<CuratedList> searchLists(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _lists
        .where(
          (list) =>
              list.isPublic &&
              (list.name.toLowerCase().contains(lowerQuery) ||
                  (list.description?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  list.tags.any(
                    (tag) => tag.toLowerCase().contains(lowerQuery),
                  )),
        )
        .toList();
  }

  /// Get all lists that contain a specific video
  List<CuratedList> getListsContainingVideo(String videoEventId) {
    return _lists
        .where((list) => list.videoEventIds.contains(videoEventId))
        .toList();
  }

  // === SUBSCRIPTION MANAGEMENT ===

  /// Subscribe to a curated list to follow its updates
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
      if (_subscribedListIds.contains(listId)) {
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
      if (!_subscribedListIds.contains(listId)) {
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
      _subscribedListIds.remove(listId);
      await _saveSubscribedListIds();

      Log.info(
        'Unsubscribed from list: $listName ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Remove list from video cache
      _onListUnsubscribed?.call(listId);

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
    return _subscribedListIds.contains(listId);
  }

  /// Check whether the current user owns a locally cached curated list.
  bool isOwnedList(String listId) {
    final currentPubkey = _relayGateway.currentAuthenticatedPubkey();
    if (currentPubkey == null || currentPubkey.isEmpty) {
      return false;
    }

    final list = getListById(listId);
    if (list == null) {
      return false;
    }

    final ownerPubkey = list.pubkey;
    if (ownerPubkey == null) {
      return false;
    }

    return ownerPubkey == currentPubkey;
  }

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

  /// Publishes [list] as a NIP-51 kind 30005 event.
  ///
  /// Empty lists are published too — a freshly created public list must
  /// reach the relay immediately or it exists only on this device.
  ///
  /// [confirmed] picks the failure semantics. Set, the publish waits for relay
  /// `OK` frames and a `false` return means no relay took the event. Unset,
  /// the SDK queues a failed send and replays it on reconnect (`RelayPool`
  /// sends with `queueIfFailed: deadline == null`), so `false` means "not
  /// yet" rather than "never".
  ///
  /// A caller that rolls local state back on failure must pass `true`, or it
  /// undoes a list the relays still receive when the socket comes back. A
  /// caller that ignores the result should leave it unset: an add-to-list made
  /// offline is meant to reach the relay eventually.
  Future<bool> _publishListToNostr(
    CuratedList list, {
    bool confirmed = false,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish list - user not authenticated',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      // NIP-51 splits a list across the two halves of the event: what the
      // list is goes in public tags, what is in it can go in encrypted
      // content. A public list puts everything in tags and keeps using
      // content for its description, which is where this client has always
      // written it.
      final String content;
      final List<List<String>> tags;
      if (list.isPublic) {
        content = list.description ?? 'Curated video list: ${list.name}';
        tags = CuratedListConverter.toEventTags(list);
      } else {
        final sealed = await _relayGateway.sealItemTags(list);
        if (sealed == null) return false;
        content = sealed;
        tags = CuratedListConverter.toPrivateMetadataTags(list);
      }

      final event = await _authService.createAndSignEvent(
        kind: 30005, // NIP-51 curated list
        content: content,
        tags: tags,
      );

      if (event == null) {
        Log.warning(
          'Failed to sign curated list event: ${list.name} (${list.id})',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      if (confirmed) {
        final outcome = await _nostrService.publishEventAwaitOk(event);
        // Accepted-by-any, including the public-to-private replacement. Once
        // one relay holds the sealed copy the list has to read private
        // locally, or the next edit would republish plain item tags over it.
        // Breadth is not the bar and cannot be: nothing here republishes to
        // relays that did not accept, so a partial publish stays partial, and
        // one wedged pool member would block every flip forever. The relays
        // that missed the replacement are covered by the plaintext redaction
        // in [_redactPlaintextListEvent] instead.
        if (!outcome.acceptedByAny) {
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

      // Record the event ID against the list's current entry, not the copy
      // captured before the publish: under `confirmed` the await above runs to
      // a 15s OK deadline, and a mutation landing inside that window would be
      // discarded by writing the snapshot back.
      //
      // [isPublic] is the exception, carried from [list]. The rest of the list
      // is local-first, but visibility is a statement about what the relays
      // hold, so [updateList] leaves it at its old value and this write is
      // what commits the change once a relay has accepted it.
      final listIndex = _lists.indexWhere((l) => l.id == list.id);
      if (listIndex != -1) {
        _lists[listIndex] = _lists[listIndex].copyWith(
          nostrEventId: event.id,
          isPublic: list.isPublic,
          pendingRepublish: false,
        );
        await _saveLists();
      }
      Log.debug(
        'Published list to Nostr: ${list.name} (${event.id})',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
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

  /// Load lists from local storage
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
        Log.debug(
          '📱 Loaded ${_lists.length} curated lists from storage',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load curated lists: $e',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Load subscribed list IDs from local storage
  void _loadSubscribedListIds() {
    final subscribedJson = _prefs.getString(subscribedListsStorageKey);
    if (subscribedJson != null) {
      try {
        final subscribedData = jsonDecode(subscribedJson) as List<dynamic>;
        _subscribedListIds.clear();
        _subscribedListIds.addAll(subscribedData.cast<String>());
        Log.debug(
          '📱 Loaded ${_subscribedListIds.length} subscribed lists from storage',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load subscribed list IDs: $e',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save lists to local storage
  Future<void> _saveLists() async {
    try {
      notifyListeners();
      final listsJson = _lists.map((list) => list.toJson()).toList();
      await _prefs.setString(listsStorageKey, jsonEncode(listsJson));
    } catch (e) {
      Log.error(
        'Failed to save curated lists: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    }
  }

  /// Save subscribed list IDs to local storage
  Future<void> _saveSubscribedListIds() async {
    try {
      notifyListeners();
      final subscribedJson = _subscribedListIds.toList();
      await _prefs.setString(
        subscribedListsStorageKey,
        jsonEncode(subscribedJson),
      );
      Log.debug(
        '💾 Saved ${_subscribedListIds.length} subscribed list IDs to storage',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to save subscribed list IDs: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
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

    StreamSubscription<Event>? relaySubscription;
    Timer? timeoutTimer;
    try {
      final completer = Completer<bool>();
      final receivedEvents = <Event>[];

      // Subscribe to user's own Kind 30005 events (NIP-51 curated lists)
      final filter = Filter(
        authors: [userPubkey],
        kinds: [30005], // NIP-51 curated lists
      );
      Log.debug(
        '📋 Subscribing with filter: authors=[${pubkeyForLogs(userPubkey)}], kinds=[30005]',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      final subscription = _nostrService.subscribe([filter]);

      // Set a timeout for the subscription
      timeoutTimer = Timer(_relaySyncTimeout, () {
        Log.debug(
          'Relay sync timeout reached, processing received events',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        if (!completer.isCompleted) {
          final activeSubscription = relaySubscription;
          relaySubscription = null;
          unawaited(activeSubscription?.cancel());
          completer.complete(false);
        }
      });

      relaySubscription = subscription.listen(
        (event) {
          receivedEvents.add(event);
          Log.debug(
            'Received list event from relay: ${event.id}',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        },
        onDone: () {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching lists from relay: $error',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        cancelOnError: true,
      );

      final completedNormally = await completer.future;
      timeoutTimer.cancel();
      final activeSubscription = relaySubscription;
      relaySubscription = null;
      await activeSubscription?.cancel();

      Log.info(
        '📋 Received ${receivedEvents.length} raw list events from relays',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      // Process received events
      if (receivedEvents.isNotEmpty) {
        await _processReceivedListEvents(receivedEvents);
      }

      if (!completedNormally) {
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
    } finally {
      timeoutTimer?.cancel();
      await relaySubscription?.cancel();
    }
  }

  /// Process list events received from relays
  Future<void> _processReceivedListEvents(List<Event> events) async {
    // Group events by 'd' tag to handle replaceable events
    final eventsByDTag = <String, Event>{};

    for (final event in events) {
      final dTag = CuratedListConverter.extractDTag(event);
      if (dTag != null) {
        // Keep only the latest event for each 'd' tag
        final existingEvent = eventsByDTag[dTag];
        if (existingEvent == null ||
            event.createdAt > existingEvent.createdAt) {
          eventsByDTag[dTag] = event;
        }
      }
    }

    Log.debug(
      'Processing ${eventsByDTag.length} unique lists from relays',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    // Process each unique list
    for (final event in eventsByDTag.values) {
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
              (list.pubkey == owner ||
                  (list.pubkey == null &&
                      !_subscribedListIds.contains(list.id))),
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
        if (currentOwner == null || currentOwner != owner) return;
        var current = getListById(list.id);
        if (current == null) return;
        if (current.nostrEventId != null && !current.pendingRepublish) return;
        if (current.pubkey == null &&
            !_subscribedListIds.contains(current.id)) {
          final currentId = current.id;
          final currentIndex = _lists.indexWhere((l) => l.id == currentId);
          if (currentIndex == -1) return;
          current = current.copyWith(pubkey: currentOwner);
          _lists[currentIndex] = current;
          await _saveLists();
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
      final dTag = curatedList.id;
      if (dTag == defaultListId && _wasDefaultListDeleted()) {
        Log.debug(
          'Skipping deleted default list event from relay: ${event.id}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      // Check if we already have this list locally
      final existingListIndex = _lists.indexWhere((list) => list.id == dTag);

      if (existingListIndex != -1) {
        // Update existing list if relay version is newer
        final existingList = _lists[existingListIndex];
        final ownerPubkey = _relayGateway.currentAuthenticatedPubkey();
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
            updatedAt: DateTime.now(),
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
        if (_deletedListCoordinates().contains(
          _listCoordinate(event.pubkey, dTag),
        )) {
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
    int limit = 500,
    Set<String>? excludeIds,
    Duration timeout = kPublicCuratedListsRelayReadTimeout,
  }) => _relayGateway.streamPublicListsFromRelays(
    until: until,
    limit: limit,
    excludeIds: excludeIds,
    timeout: timeout,
  );

  /// See [CuratedListRelayGateway.fetchPublicList].
  Future<CuratedList?> fetchPublicList({
    required String authorPubkey,
    required String listId,
  }) =>
      _relayGateway.fetchPublicList(authorPubkey: authorPubkey, listId: listId);

  /// See [CuratedListRelayGateway.fetchPublicListsContainingVideo].
  Future<List<CuratedList>> fetchPublicListsContainingVideo(
    String videoEventId,
  ) => _relayGateway.fetchPublicListsContainingVideo(videoEventId);

  /// See [CuratedListRelayGateway.streamPublicListsContainingVideo].
  Stream<CuratedList> streamPublicListsContainingVideo(String videoEventId) =>
      _relayGateway.streamPublicListsContainingVideo(videoEventId);
}
