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
    if (!await preferences.setString(storageKey, _encoded)) {
      throw StateError('Could not record required account cleanup');
    }
  }

  Future<void> complete(SharedPreferences preferences) async {
    if (!await preferences.remove(storageKey)) {
      // SharedPreferences removes its in-memory entry before the backend
      // acknowledges removal. Restore the retry obligation in memory too.
      await record(preferences);
      throw StateError('Could not finish required account cleanup');
    }
  }

  String get _encoded => jsonEncode({
    'version': 1,
    'userPubkey': userPubkey,
    'isIdentityChange': isIdentityChange,
    'deleteUserData': deleteUserData,
  });
}
