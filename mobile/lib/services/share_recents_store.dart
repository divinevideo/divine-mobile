// ABOUTME: Stores each account's six most recent durable share recipients.
// ABOUTME: Resolves display identities from the local profile cache.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:openvine/models/shareable_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareRecentsStore {
  ShareRecentsStore(this._prefs, {required this.loadProfiles});

  final SharedPreferences _prefs;
  final Future<List<UserProfile>> Function(List<String>) loadProfiles;
  static const _prefix = 'share_recents_v1_';
  static final _hexKey = RegExp(r'^[0-9a-f]{64}$');
  static String storageKey(String pubkey) => '$_prefix$pubkey';

  final _cache = <String, List<ShareableUser>>{};
  final _pending = <String, Future<void>>{};
  final _warming = <String, Future<void>>{};
  final _generation = <String, int>{};

  List<ShareableUser> snapshot(String owner) => _cache[owner] ?? const [];

  Future<void> _serialize(String owner, Future<void> Function() operation) {
    final previous = _pending[owner];
    final next = previous == null
        ? Future.microtask(operation)
        : previous.then((_) => operation(), onError: (Object _) => operation());
    _pending[owner] = next;
    return next.whenComplete(() {
      if (identical(_pending[owner], next)) {
        final _ = _pending.remove(owner);
      }
    });
  }

  List<String> _read(String owner) {
    final raw = _prefs.get(storageKey(owner));
    if (raw is! String) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<String>()
          .where(_hexKey.hasMatch)
          .toSet()
          .take(6)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _resolve(String owner, List<String> keys, int generation) async {
    if (generation != (_generation[owner] ?? 0)) return;
    final profiles = keys.isEmpty
        ? const <UserProfile>[]
        : await loadProfiles(keys);
    if (generation != (_generation[owner] ?? 0)) return;
    final byKey = {for (final profile in profiles) profile.pubkey: profile};
    _cache[owner] = List.unmodifiable(
      keys
          .map((key) => ShareableUser.fromProfile(key, byKey[key]))
          .where((user) => user.hasVisibleIdentity),
    );
  }

  Future<void> warm(String owner) {
    if (!_hexKey.hasMatch(owner) || _cache.containsKey(owner)) {
      return Future.value();
    }
    final generation = _generation[owner] ?? 0;
    return _warming[owner] ??=
        _serialize(
          owner,
          () => _resolve(owner, _read(owner), generation),
        ).whenComplete(() {
          if (generation == (_generation[owner] ?? 0)) {
            final _ = _warming.remove(owner);
          }
        });
  }

  Future<void> recordQueued(String owner, Iterable<String> recipients) {
    final newest = recipients
        .map((key) => key.toLowerCase())
        .where(_hexKey.hasMatch)
        .toSet();
    if (!_hexKey.hasMatch(owner) || newest.isEmpty) return Future.value();
    final generation = _generation[owner] ?? 0;
    return _serialize(owner, () async {
      if (generation != (_generation[owner] ?? 0)) return;
      final keys = {...newest, ..._read(owner)}.take(6).toList();
      if (!await _prefs.setString(storageKey(owner), jsonEncode(keys))) {
        throw StateError('Could not persist share recents');
      }
      await _resolve(owner, keys, generation);
    });
  }

  Future<void> clearFor(String owner) {
    _generation[owner] = (_generation[owner] ?? 0) + 1;
    final _ = _warming.remove(owner);
    _cache.remove(owner);
    return _serialize(owner, () async {
      if (_prefs.containsKey(storageKey(owner)) &&
          !await _prefs.remove(storageKey(owner))) {
        throw StateError('Could not remove share recents');
      }
    });
  }

  Future<int> sweepUnknown(Set<String> keep) async {
    final owners = {
      ..._cache.keys,
      ..._pending.keys,
      for (final key in _prefs.getKeys())
        if (key.startsWith(_prefix)) key.substring(_prefix.length),
    }..removeAll(keep);
    for (final owner in owners) {
      await clearFor(owner);
    }
    return owners.length;
  }
}
