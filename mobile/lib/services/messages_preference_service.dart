// ABOUTME: Stores the Messages section per account on this device.
// ABOUTME: Synchronous cached reads avoid restoring another account's selection.

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local navigation preference, isolated by the full account pubkey.
class MessagesPreferenceService {
  const MessagesPreferenceService(this._preferences);

  final SharedPreferences _preferences;

  /// Preference key for [account]; account deletion removes it.
  static String storageKey(String account) => 'messages_rooms_$account';

  bool roomsSelected(String account) =>
      _preferences.getBool(storageKey(account)) ?? false;

  Future<void> selectRooms(String account, {required bool selected}) async {
    final saved = await _preferences.setBool(storageKey(account), selected);
    if (!saved) throw StateError('Messages preference could not be saved');
  }
}
