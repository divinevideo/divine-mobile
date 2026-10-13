// ABOUTME: Stores the Messages section per account on this device.
// ABOUTME: Synchronous cached reads avoid restoring another account's selection.

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local navigation preference, isolated by the full account pubkey.
class MessagesPreferenceService {
  const MessagesPreferenceService(this._preferences);

  final SharedPreferences _preferences;

  bool roomsSelected(String account) =>
      _preferences.getBool('messages_rooms_$account') ?? false;

  Future<void> selectRooms(String account, {required bool selected}) async {
    final saved = await _preferences.setBool(
      'messages_rooms_$account',
      selected,
    );
    if (!saved) throw StateError('Messages preference could not be saved');
  }
}
