import '../event.dart';

class ZapGoalsInfo {
  int? amount;

  List<String>? relays;

  int? closedAt;

  String? r;

  String? a;

  String? goal;

  String? goalRelay;

  ZapGoalsInfo.fromEvent(Event event) {
    var length = event.tags.length;
    for (var i = 0; i < length; i++) {
      var tag = event.tags[i];
      var tagLength = tag.length;
      if (tagLength > 1 && tag[1] is String) {
        var key = tag[0];
        var value = tag[1] as String;
        if (key == "amount") {
          amount = int.tryParse(value);
          if (amount != null) {
            amount = (amount! / 1000).toInt();
          }
        } else if (key == "zapraiser") {
          amount = int.tryParse(value);
        } else if (key == "closed_at") {
          closedAt = int.tryParse(value);
        } else if (key == "relays" && tag is List<String>) {
          relays = tag.sublist(1);
        } else if (key == "r") {
          r = value;
        } else if (key == "a") {
          a = value;
        } else if (key == "goal") {
          goal = value;
          if (tag.length > 1 && tag[2] is String) {
            goalRelay = tag[2];
          }
        }
      }
    }
  }
}
