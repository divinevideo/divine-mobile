import 'dart:convert';

import 'package:nostr_sdk/utils/relay_addr_util.dart';

import '../relay/relay_status.dart';

class NIP02 {
  static String relaysToContent(List<RelayStatus> relayStatuses) {
    Map<String, dynamic> relaysContentMap = {};
    for (var relayStatus in relayStatuses) {
      var readAccess = relayStatus.readAccess;
      var writeAccess = relayStatus.writeAccess;

      relaysContentMap[relayStatus.addr] = {
        "read": readAccess,
        "write": writeAccess,
      };
    }
    return jsonEncode(relaysContentMap);
  }

  static List<RelayStatus> parseContenToRelays(String content) {
    List<RelayStatus> relayStatuses = [];
    var jsonObj = jsonDecode(content);
    Map<dynamic, dynamic> jsonMap =
        jsonObj.map((key, value) => MapEntry(key, true));

    for (var entry in jsonMap.entries) {
      try {
        var key = entry.key.toString();
        var value = jsonObj[key];

        var readAcccess = value["read"] == true;
        var writeAcccess = value["write"] == true;

        key = RelayAddrUtil.handle(key);

        var relayStatus = RelayStatus(key);
        relayStatus.readAccess = readAcccess;
        relayStatus.writeAccess = writeAcccess;

        relayStatuses.add(relayStatus);
      } catch (e) {
        print("parse content to relay error");
        print(e);
      }
    }

    return relayStatuses;
  }
}
