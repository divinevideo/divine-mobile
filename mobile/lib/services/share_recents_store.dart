// ABOUTME: Stores each account's six most recent durable share recipients.
// ABOUTME: Resolves display identities from the local profile cache.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:openvine/models/shareable_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences refused to write or remove an owner's share recents.
///
/// A storage failure rather than a programming error, so it is not reported
/// as a crash.
class ShareRecentsStorageException implements Exception {
  /// Creates the exception for the refused [operation].
  const ShareRecentsStorageException(this.operation);

  /// What was refused, such as `persist` or `remove`.
  final String operation;

  @override
  String toString() =>
      'ShareRecentsStorageException: could not $operation share recents';
}

/// The six most recent share recipients of each account, in SharedPreferences.
///
/// Keys are stored per owner; display identities come from [loadProfiles] and
/// are held in memory for [snapshot]. Writes for one owner run one at a time.
class ShareRecentsStore {
  /// Creates a store over [_prefs] that resolves identities with
  /// [loadProfiles].
  ShareRecentsStore(this._prefs, {required this.loadProfiles});

  final SharedPreferences _prefs;

  /// Resolves the cached profiles of the given recipient keys.
  final Future<List<UserProfile>> Function(List<String>) loadProfiles;
  static const _prefix = 'share_recents_v1_';
  static final _hexKey = RegExp(r'^[0-9a-f]{64}$');

  /// The preference key holding [pubkey]'s recent recipients.
  static String storageKey(String pubkey) => '$_prefix$pubkey';

  final _cache = <String, List<ShareableUser>>{};
  final _pending = <String, Future<void>>{};
  final _warming = <String, Future<void>>{};
  final _generation = <String, int>{};

  /// [owner]'s resolved recent recipients, newest first, or empty until
  /// [warm] or [recordQueued] has loaded them.
  ///
  /// Recipients without a visible identity are left out.
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

  /// Loads [owner]'s stored recipients and resolves their identities, once.
  ///
  /// Completes immediately for an invalid owner or one already loaded.
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

  /// Moves [recipients] to the front of [owner]'s recents, keeping six.
  ///
  /// Invalid keys are ignored, and a [clearFor] issued before the write runs
  /// cancels it.
  ///
  /// Throws [ShareRecentsStorageException] when the write is refused.
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
        throw const ShareRecentsStorageException('persist');
      }
      await _resolve(owner, keys, generation);
    });
  }

  /// Forgets [owner]'s recents, in memory and on disk, and cancels any warm or
  /// write still pending for them.
  ///
  /// Throws [ShareRecentsStorageException] when the removal is refused.
  Future<void> clearFor(String owner) {
    _generation[owner] = (_generation[owner] ?? 0) + 1;
    final _ = _warming.remove(owner);
    _cache.remove(owner);
    return _serialize(owner, () async {
      if (_prefs.containsKey(storageKey(owner)) &&
          !await _prefs.remove(storageKey(owner))) {
        throw const ShareRecentsStorageException('remove');
      }
    });
  }

  /// Clears the recents of every owner not in [keep] and returns how many
  /// owners were cleared.
  ///
  /// Throws [ShareRecentsStorageException] when a removal is refused.
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
