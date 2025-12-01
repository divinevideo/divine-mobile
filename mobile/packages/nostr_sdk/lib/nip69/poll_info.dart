import '../event.dart';

class PollInfo {
  List<List<String>> pollOptions = [];

  int? valueMaximum;

  int? valueMinimum;

  String? consensusThreshold;

  int? closedAt;

  PollInfo.fromEvent(Event event) {
    var length = event.tags.length;
    for (var i = 0; i < length; i++) {
      var tag = event.tags[i];
      var tagLength = tag.length;
      if (tagLength > 1 && tag[1] is String) {
        if (tag[0] == "poll_option") {
          if (tag[1] is String && tag[2] is String) {
            pollOptions.add([tag[1] as String, tag[2] as String]);
          }
        } else if (tag[0] == "value_maximum") {
          valueMaximum = int.tryParse(tag[1]);
        } else if (tag[0] == "value_minimum") {
          valueMinimum = int.tryParse(tag[1]);
        } else if (tag[0] == "consensus_threshold") {
          consensusThreshold = tag[1];
        } else if (tag[0] == "closed_at") {
          closedAt = int.tryParse(tag[1]);
        }
      }
    }
  }
}
