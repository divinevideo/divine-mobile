import 'package:nostr_sdk/nostr.dart';

import '../event.dart';
import '../event_kind.dart';
import '../relay/relay_status.dart';

class NIP65 {
  static void save(Nostr nostr, List<RelayStatus> relayStatuses) {
    List tags = [];
    for (var relayStatus in relayStatuses) {
      var readAccess = relayStatus.readAccess;
      var writeAccess = relayStatus.writeAccess;

      List<String> tag = ["r", relayStatus.addr];
      if (readAccess != true || writeAccess != true) {
        if (readAccess) {
          tag.add("read");
        }
        if (writeAccess) {
          tag.add("write");
        }
      }
      tags.add(tag);
    }

    var e = Event(nostr.publicKey, EventKind.relayListMetadata, tags, "");
    nostr.sendEvent(e);
  }
}
