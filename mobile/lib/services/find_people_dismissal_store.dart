// ABOUTME: Local-only dismissal persistence, scoped by the full account key.
// ABOUTME: Exposes its key family to account-data classification and erasure.

import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped local dismissal preference store backed by
/// [SharedPreferences].
///
/// Retention policy: capped at [maxEntries] pubkeys per account, keeping the
/// most recently dismissed entries (evicting oldest entries first in
/// [FindPeopleDismissalStore.write]). Account keys are also deleted on account
/// removal/erasure via `UserDataCleanupService` using [storagePrefix].
class FindPeopleDismissalStore {
  const FindPeopleDismissalStore(this._preferences);
  final SharedPreferences _preferences;

  /// Maximum dismissed pubkeys retained per account (~12.8 KB worst case).
  static const maxEntries = 200;

  static const storagePrefix = 'find_people_dismissed_v1:';
  static String storageKey(String owner) => '$storagePrefix$owner';

  List<String> read(String owner) =>
      _preferences.getStringList(storageKey(owner)) ?? [];

  Future<void> write(String owner, List<String> pubkeys) async {
    final key = storageKey(owner);
    final previous = _preferences.getStringList(key);
    final capped = _applyRetentionCap(pubkeys);
    try {
      if (!await _preferences.setStringList(key, capped)) {
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

  /// Deduplicates while keeping the most recent [maxEntries] entries.
  static List<String> _applyRetentionCap(List<String> pubkeys) {
    final ordered = <String>{};
    for (final key in pubkeys) {
      ordered
        ..remove(key)
        ..add(key);
    }
    if (ordered.length <= maxEntries) return ordered.toList();
    return ordered.skip(ordered.length - maxEntries).toList();
  }
}
