import '../event_relation.dart';

class Bookmarks {
  List<BookmarkItem> privateItems = [];
  List<BookmarkItem> publicItems = [];
}

class BookmarkItem {
  String key;

  String value;

  BookmarkItem({
    required this.key,
    required this.value,
  });

  List<dynamic> toJson() {
    List<dynamic> list = [];
    list.add(key);
    list.add(value);
    return list;
  }

  static BookmarkItem getFromEventReactions(EventRelation eventRelation) {
    var key = "e";
    var value = eventRelation.id;
    var aId = eventRelation.aId;
    if (aId != null) {
      key = "a";
      value = aId.toAString();
    }
    return BookmarkItem(key: key, value: value);
  }
}
