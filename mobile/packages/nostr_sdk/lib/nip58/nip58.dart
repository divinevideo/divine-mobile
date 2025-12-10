import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nostr.dart';

import '../event_kind.dart';

class NIP58 {
  static Future<Event?> ware(
    Nostr nostr,
    String badgeId,
    String eventId, {
    Event? badgeEvent,
    String? relayAddr,
  }) async {
    String content = "";
    List<dynamic> tags = [];

    if (badgeEvent != null) {
      content = badgeEvent.content;
      tags = badgeEvent.tags;
    } else {
      tags = [
        ["d", "profile_badges"],
      ];
    }

    tags.add(["a", badgeId]);
    var eList = ["e", eventId];
    if (relayAddr != null) {
      eList.add(relayAddr);
    }
    tags.add(eList);

    var newEvent = Event(nostr.publicKey, EventKind.badgeAccept, tags, content);

    return await nostr.sendEvent(newEvent);
  }

  static List<String> parseProfileBadge(Event event) {
    List<String> badgeIds = [];

    for (var tag in event.tags) {
      if (tag[0] == "a") {
        var badgeId = tag[1];

        badgeIds.add(badgeId);
      }
    }

    return badgeIds;
  }
}
