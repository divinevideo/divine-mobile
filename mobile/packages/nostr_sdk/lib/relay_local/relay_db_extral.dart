import 'package:nostr_sdk/relay_local/relay_db.dart';

/// More methods for some Client used.
abstract class RelayDBExtral extends RelayDB {
  RelayDBExtral(super.appName);

  Future<List<Map<String, Object?>>> queryEventByPubkey(String pubkey,
      {List<int>? eventKinds});

  Future<int?> allDataCount();

  Future<void> deleteData({String? pubkey});

  Future<int> getDBFileSize();
}
