import '../event.dart';
import '../event_kind.dart';

class RelayListMetadata {
  late String pubkey;

  late int createdAt;

  // late List<RelayListMetadataItem> relays;

  late List<String> readAbleRelays;

  late List<String> writeAbleRelays;

  RelayListMetadata.fromEvent(Event event) {
    pubkey = event.pubkey;
    createdAt = event.createdAt;
    // relays = [];
    readAbleRelays = [];
    writeAbleRelays = [];
    if (event.kind == EventKind.relayListMetadata) {
      for (var tag in event.tags) {
        if (tag is List && tag.length > 1) {
          var k = tag[0];
          if (k != "r") {
            continue;
          }

          var addr = tag[1];
          bool writeAble = true;
          bool readAble = true;

          if (tag.length > 2) {
            var rw = tag[2];
            if (rw == "write") {
              readAble = false;
            } else if (rw == "read") {
              writeAble = false;
            }
          }

          // var item = RelayListMetadataItem(addr,
          //     writeAble: writeAble, readAble: readAble);
          // relays.add(item);
          if (readAble) {
            readAbleRelays.add(addr);
          }
          if (writeAble) {
            writeAbleRelays.add(addr);
          }
        }
      }
    }
  }
}

// class RelayListMetadataItem {
//   String addr;

//   bool writeAble = true;

//   bool readAble = true;

//   RelayListMetadataItem(
//     this.addr, {
//     this.writeAble = true,
//     this.readAble = true,
//   });
// }
