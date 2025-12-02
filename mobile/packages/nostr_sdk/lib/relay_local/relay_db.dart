/// The interface for the relay database.
/// It uesd for relays.
abstract class RelayDB {
  final String appName;

  RelayDB(this.appName);

  Future<void> deleteEventByKind(String pubkey, int eventKind);

  Future<void> deleteEvent(String pubkey, String id);

  Future<int> addEvent(Map<String, dynamic> event);

  Future<List<Map<String, Object?>>> doQueryEvent(Map<String, dynamic> filter);

  Future<int?> doQueryCount(Map<String, dynamic> filter);
}
