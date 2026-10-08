// ABOUTME: Durable account-boundary cleanup intent retained across retries.
// ABOUTME: Preserves the original owner's required scope until disk cleanup ends.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A required sweep must remain discoverable after its cache keys disappear.
/// Otherwise a database failure followed by a restart can resemble a fresh
/// installation and let the next account skip cleanup entirely.
class PendingAccountCleanup {
  const PendingAccountCleanup({
    required this.userPubkey,
    required this.isIdentityChange,
    required this.deleteUserData,
  });

  static const storageKey = 'pending_account_data_cleanup';

  static final _unknownReadbacks = Expando<bool>();

  /// Callers must not release shared storage holds while readback is unknown.
  static bool readbackUnknown(SharedPreferences preferences) =>
      _unknownReadbacks[preferences] ?? false;

  /// Device-wide security coordination, removed only after successful cleanup.
  /// Clearing this as ordinary account data would erase the retry obligation.
  static const List<String> deviceScopedPrefsKeys = [storageKey];

  final String? userPubkey;
  final bool isIdentityChange;
  final bool deleteUserData;

  static PendingAccountCleanup? read(SharedPreferences preferences) {
    if (!preferences.containsKey(storageKey)) return null;
    final raw = preferences.getString(storageKey);
    if (raw == null) throw StateError('Account cleanup intent is unreadable');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        !decoded.containsKey('userPubkey') ||
        decoded['userPubkey'] is! String? ||
        decoded['isIdentityChange'] is! bool ||
        decoded['deleteUserData'] is! bool ||
        (decoded['isIdentityChange'] != true &&
            decoded['deleteUserData'] != true)) {
      throw StateError('Account cleanup intent is invalid');
    }
    return PendingAccountCleanup(
      userPubkey: decoded['userPubkey'] as String?,
      isIdentityChange: decoded['isIdentityChange'] as bool,
      deleteUserData: decoded['deleteUserData'] as bool,
    );
  }

  bool covers({
    required String? userPubkey,
    required bool isIdentityChange,
    required bool deleteUserData,
  }) =>
      this.userPubkey == userPubkey &&
      (!isIdentityChange || this.isIdentityChange) &&
      (!deleteUserData || this.deleteUserData);

  Future<void> record(SharedPreferences preferences) async {
    final encoded = _encoded;
    var saved = false;
    try {
      saved = await preferences.setString(storageKey, encoded);
    } on Object {
      // A platform throw can still leave an optimistic value in the cache.
      try {
        await _reload(preferences);
      } on Object {
        // No destructive work is authorized without verified readback.
      }
      throw StateError('Could not record required account cleanup');
    }
    await _reload(preferences);
    if (!saved || preferences.get(storageKey) != encoded) {
      throw StateError('Could not record required account cleanup');
    }
  }

  Future<void> complete(SharedPreferences preferences) async {
    var removed = false;
    try {
      removed = await preferences.remove(storageKey);
    } on Object {
      // Even a throw can occur after removal; retain the original obligation.
    }
    try {
      await _reload(preferences);
    } on Object {
      // Restore before reporting failure; a restart must not infer completion
      // from an unavailable readback of the marker's optimistic removal.
      try {
        await record(preferences);
      } on Object {
        // The caller remains failed closed when restoration is unverified.
      }
      throw StateError('Could not verify completed account cleanup');
    }
    if (!removed || preferences.containsKey(storageKey)) {
      if (!preferences.containsKey(storageKey)) await record(preferences);
      throw StateError('Could not finish required account cleanup');
    }
  }

  static Future<void> _reload(SharedPreferences preferences) async {
    try {
      await preferences.reload();
      _unknownReadbacks[preferences] = false;
    } on Object {
      _unknownReadbacks[preferences] = true;
      throw StateError('Could not verify required account cleanup');
    }
  }

  String get _encoded => jsonEncode({
    'version': 1,
    'userPubkey': userPubkey,
    'isIdentityChange': isIdentityChange,
    'deleteUserData': deleteUserData,
  });
}
