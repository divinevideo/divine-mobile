import '../event.dart';

class LongFormInfo {
  String? title;

  String? image;

  String? summary;

  int? publishedAt;

  List<String> topics = [];

  List<String> as = [];

  LongFormInfo.fromEvent(Event event) {
    var length = event.tags.length;
    for (var i = 0; i < length; i++) {
      var tag = event.tags[i];
      var tagLength = tag.length;
      if (tagLength > 1 && tag[1] is String) {
        var value = tag[1] as String;
        if (tag[0] == "title") {
          title = value;
        } else if (tag[0] == "summary") {
          summary = value;
        } else if (tag[0] == "published_at") {
          publishedAt = int.tryParse(value);
        } else if (tag[0] == "t") {
          topics.add(value);
        } else if (tag[0] == "image") {
          image = value;
        } else if (tag[0] == "a") {
          as.add(value);
        }
      }
    }
  }
}
