// ABOUTME: Local-only dismissal persistence, scoped by the full account key.
// ABOUTME: Exposes its key family to account-data classification and erasure.

import 'package:shared_preferences/shared_preferences.dart';

class FindPeopleDismissalStore {
  const FindPeopleDismissalStore(this._preferences);
  final SharedPreferences _preferences;

  static const storagePrefix = 'find_people_dismissed_v1:';
  static String storageKey(String owner) => '$storagePrefix$owner';

  List<String> read(String owner) =>
      _preferences.getStringList(storageKey(owner)) ?? [];

  Future<void> write(String owner, List<String> pubkeys) async {
    final key = storageKey(owner);
    final previous = _preferences.getStringList(key);
    try {
      if (!await _preferences.setStringList(key, pubkeys)) {
        throw StateError('Unable to save dismissed suggestions');
      }
    } on Object {
      // SharedPreferences changes its process cache before the platform write.
      // Restore only this owner's key so a failed dismissal stays retryable,
      // including after account-container recreation, without reloading other
      // accounts' concurrent writes out of the shared cache.
      try {
        if (previous == null) {
          await _preferences.remove(key);
        } else {
          await _preferences.setStringList(key, previous);
        }
      } on Object {
        // The cache is restored before this compensating platform write too.
        // Preserve the original failure for the caller's retry state.
      }
      rethrow;
    }
  }
}
