// ABOUTME: Account-specific durable sound request checkpoints.
// ABOUTME: Keeps malformed state intact rather than silently resetting it.
import 'dart:convert';

import 'package:dm_repository/dm_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundRequestPreferencesStore implements SoundRequestStore {
  SoundRequestPreferencesStore(this._prefs);
  final SharedPreferences _prefs;
  Future<void> _writes = Future.value();
  String _key(String owner) => 'sound_requests_v1_$owner';

  @override
  Future<SoundRequestSnapshot> read(String ownerPubkey) async {
    final raw = _prefs.getString(_key(ownerPubkey));
    if (raw == null) return const SoundRequestSnapshot();
    try {
      return SoundRequestSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object catch (error) {
      throw FormatException('Invalid persisted sound request state', error);
    }
  }

  @override
  Future<void> write(String ownerPubkey, SoundRequestSnapshot snapshot) {
    final encoded = jsonEncode(snapshot.toJson());
    final write = _writes.then((_) async {
      if (!await _prefs.setString(_key(ownerPubkey), encoded)) {
        throw StateError('Sound request state could not be persisted');
      }
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
