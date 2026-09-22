// ABOUTME: SharedPreferences-backed record of the people lists each account
// ABOUTME: follows. Identities only, scoped per account, in follow order.

import 'dart:async';

import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which public people lists each viewer follows.
///
/// The same shape the video-list follow uses: a string list of identifiers in
/// preferences, with the lists themselves held in a cache. Preferences rather
/// than the people-lists box because that box is a relay mirror "Reset app
/// data" wipes, and a follow cannot be rebuilt from a relay.
///
/// One instance has to serve the whole app: [watch] only hears writes made
/// through the instance it was called on.
class PrefsFollowedPeopleListsStore implements FollowedPeopleListsStore {
  /// Creates a store over [prefs].
  PrefsFollowedPeopleListsStore(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<String> _changedViewers =
      StreamController<String>.broadcast();

  static const String _keyPrefix = 'followed_people_lists_';

  /// Separates the owner from the `d` tag in a stored entry. A hex pubkey
  /// cannot contain it, so the first one always ends the owner, whatever the
  /// `d` tag holds.
  static const String _entrySeparator = ':';

  /// The SharedPreferences key holding [viewerPubkey]'s follows.
  ///
  /// It carries the pubkey, so one account's follows can never be read as
  /// another's.
  static String _storageKey(String viewerPubkey) => '$_keyPrefix$viewerPubkey';

  @override
  Future<List<FollowedPeopleListRef>> read({
    required String viewerPubkey,
  }) async => _read(viewerPubkey);

  @override
  Stream<List<FollowedPeopleListRef>> watch({required String viewerPubkey}) {
    late StreamController<List<FollowedPeopleListRef>> controller;
    StreamSubscription<String>? subscription;
    controller = StreamController<List<FollowedPeopleListRef>>(
      onListen: () {
        // Subscribe before the first read so no change falls between them.
        subscription = _changedViewers.stream
            .where((viewer) => viewer == viewerPubkey)
            .listen((_) => controller.add(_read(viewerPubkey)));
        controller.add(_read(viewerPubkey));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> add({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  }) async {
    final refs = _read(viewerPubkey);
    if (refs.contains(ref)) return;
    await _write(viewerPubkey, [...refs, ref]);
  }

  @override
  Future<void> remove({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  }) async {
    final refs = _read(viewerPubkey);
    if (!refs.contains(ref)) return;
    await _write(viewerPubkey, [
      for (final existing in refs)
        if (existing != ref) existing,
    ]);
  }

  @override
  Future<void> clear({required String viewerPubkey}) async {
    final key = _storageKey(viewerPubkey);
    if (!_prefs.containsKey(key)) return;
    await _prefs.remove(key);
    _changedViewers.add(viewerPubkey);
  }

  /// Releases the change stream. The store must not be used afterwards.
  Future<void> dispose() => _changedViewers.close();

  /// An entry that does not split into an owner and a `d` tag is skipped on
  /// its own, so one damaged entry does not cost the account its other
  /// follows.
  List<FollowedPeopleListRef> _read(String viewerPubkey) {
    final entries = _prefs.getStringList(_storageKey(viewerPubkey));
    if (entries == null) return const [];
    final refs = <FollowedPeopleListRef>[];
    for (final entry in entries) {
      final split = entry.indexOf(_entrySeparator);
      if (split <= 0 || split == entry.length - 1) continue;
      final ref = FollowedPeopleListRef(
        ownerPubkey: entry.substring(0, split),
        listId: entry.substring(split + 1),
      );
      if (!refs.contains(ref)) refs.add(ref);
    }
    return List.unmodifiable(refs);
  }

  Future<void> _write(
    String viewerPubkey,
    List<FollowedPeopleListRef> refs,
  ) async {
    await _prefs.setStringList(_storageKey(viewerPubkey), [
      for (final ref in refs) '${ref.ownerPubkey}$_entrySeparator${ref.listId}',
    ]);
    _changedViewers.add(viewerPubkey);
  }
}
