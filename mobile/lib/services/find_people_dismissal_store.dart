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
    if (!await _preferences.setStringList(storageKey(owner), pubkeys)) {
      throw StateError('Unable to save dismissed suggestions');
    }
  }
}
