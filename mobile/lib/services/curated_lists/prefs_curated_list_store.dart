// ABOUTME: Adapts SharedPreferences to the shared curated cache write coordinator.
// ABOUTME: Also keeps the record of deleted lists and the default-list flag.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the curated lists, their subscriptions, the record of deleted lists
/// and the default-list flag in [SharedPreferences].
///
/// Saves merge through the shared [CuratedListCacheWriteCoordinator]. A
/// baseline advances only after the whole save lands, so the next save repeats
/// whatever a rejected write dropped.
class PrefsCuratedListStore {
  /// Creates a store over [prefs] that keeps the lists, the subscriptions and
  /// the default-list flag under the given keys.
  ///
  /// The caller names these keys because the account-switch sweep references
  /// them by the same constants.
  PrefsCuratedListStore({
    required SharedPreferences prefs,
    required CuratedListCacheWriteCoordinator writeCoordinator,
    required String listsStorageKey,
    required String subscriptionsStorageKey,
    required String defaultListDeletedStorageKey,
  }) : _prefs = prefs,
       _writes = writeCoordinator,
       _listsKey = listsStorageKey,
       _subscriptionsKey = subscriptionsStorageKey,
       _defaultListDeletedKey = defaultListDeletedStorageKey;

  /// Where this install records the lists it has deleted.
  ///
  /// The account-switch sweep does not clear it: each entry embeds its owner,
  /// so one account's record never hides another's list, and clearing it would
  /// let a relay that ignored the deletion bring the list back. Declared here
  /// rather than injected so `check_prefs_key_classification.sh` still sees it.
  static const String deletedCoordinatesStorageKey =
      'deleted_curated_list_coordinates';

  final SharedPreferences _prefs;
  final CuratedListCacheWriteCoordinator _writes;
  final String _listsKey;
  final String _subscriptionsKey;
  final String _defaultListDeletedKey;
  List<CuratedList> _savedLists = const [];
  Set<String> _savedSubscriptions = const {};

  /// Sets [lists], as just loaded from storage, as the baseline the next
  /// [saveLists] diffs against.
  void listsLoaded(List<CuratedList> lists) {
    _savedLists = List.unmodifiable(lists);
  }

  /// Sets [ids], as just loaded from storage, as the baseline the next
  /// [saveSubscriptions] diffs against.
  void subscriptionsLoaded(Set<String> ids) {
    _savedSubscriptions = Set.unmodifiable(ids);
  }

  /// Saves what changed in [lists] since the last load or successful save,
  /// keeping lists another writer stored in the meantime. Returns whether
  /// every change was stored.
  ///
  /// Throws if the stored lists cannot be decoded; nothing is written then.
  Future<bool> saveLists(List<CuratedList> lists) async {
    final snapshot = List<CuratedList>.unmodifiable(lists);
    final saved = await _writes.saveLists(
      baseline: _savedLists,
      current: snapshot,
      read: () {
        final json = _prefs.getString(_listsKey);
        if (json == null) return [];
        return (jsonDecode(json) as List<dynamic>)
            .map((row) => CuratedList.fromJson(row as Map<String, dynamic>))
            .toList(growable: false);
      },
      write: (merged) => _prefs.setString(
        _listsKey,
        jsonEncode(merged.map((list) => list.toJson()).toList(growable: false)),
      ),
    );
    if (saved) _savedLists = snapshot;
    return saved;
  }

  /// Saves what changed in [ids] since the last load or successful save,
  /// keeping subscriptions another writer stored in the meantime. Returns
  /// whether the change was stored.
  ///
  /// Throws if the stored subscriptions cannot be decoded; nothing is written
  /// then.
  Future<bool> saveSubscriptions(Set<String> ids) async {
    final snapshot = Set<String>.unmodifiable(ids);
    final saved = await _writes.saveSubscriptions(
      baseline: _savedSubscriptions,
      current: snapshot,
      read: () {
        final json = _prefs.getString(_subscriptionsKey);
        if (json == null) return {};
        return (jsonDecode(json) as List<dynamic>).cast<String>().toSet();
      },
      write: (merged) => _prefs.setString(
        _subscriptionsKey,
        jsonEncode(merged.toList(growable: false)),
      ),
    );
    if (saved) _savedSubscriptions = snapshot;
    return saved;
  }

  /// Whether the signed-in account deleted its default list.
  ///
  /// Unlike the deletion record, the account-switch sweep clears this flag.
  bool wasDefaultListDeleted() =>
      _prefs.getBool(_defaultListDeletedKey) ?? false;

  /// Remembers that the default list was deleted.
  Future<void> markDefaultListDeleted() async {
    await _prefs.setBool(_defaultListDeletedKey, true);
  }

  /// Whether this install has deleted the list [ownerPubkey] published as
  /// [listId].
  bool wasListDeleted(String ownerPubkey, String listId) =>
      _deletedCoordinates().contains(_coordinate(ownerPubkey, listId));

  /// Remembers that [ownerPubkey]'s list [listId] was deleted.
  Future<void> recordListDeletion(String ownerPubkey, String listId) async {
    final coordinates = _deletedCoordinates()
      ..add(_coordinate(ownerPubkey, listId));
    await _prefs.setStringList(
      deletedCoordinatesStorageKey,
      coordinates.toList(growable: false),
    );
  }

  /// Lifts the tombstone so a re-created list can sync again.
  Future<void> forgetListDeletion(String ownerPubkey, String listId) async {
    final coordinates = _deletedCoordinates();
    if (!coordinates.remove(_coordinate(ownerPubkey, listId))) return;
    await _prefs.setStringList(
      deletedCoordinatesStorageKey,
      coordinates.toList(growable: false),
    );
  }

  /// The `<pubkey>:<d-tag>` form of a kind 30005 coordinate.
  ///
  /// A `d` tag is only unique per author, so a deletion has to be remembered
  /// against its owner. Keying on the identifier alone would suppress a list
  /// that merely shares it — another account on this device, or someone
  /// else's list arriving from a relay.
  String _coordinate(String ownerPubkey, String listId) =>
      '$ownerPubkey:$listId';

  /// Coordinates this install has deleted.
  ///
  /// NIP-09 is advisory: a relay may never see the deletion request, or may
  /// decline it, and keep replaying the original event. Without a local record
  /// the next sync adds the list straight back. The set is not pruned — an
  /// entry is a few dozen bytes, deletions are rare, and there is no point at
  /// which every relay is known to have honoured the request.
  Set<String> _deletedCoordinates() =>
      (_prefs.getStringList(deletedCoordinatesStorageKey) ?? const []).toSet();
}
