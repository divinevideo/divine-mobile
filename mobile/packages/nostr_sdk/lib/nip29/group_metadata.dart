import '../event.dart';
import '../utils/string_util.dart';
import 'group_object.dart';

class GroupMetadata extends GroupObject {
  String? name;

  String? picture;

  String? about;

  bool? public;

  bool? open;

  GroupMetadata(
    super.groupId,
    super.createdAt, {
    this.name,
    this.picture,
    this.about,
    this.public,
    this.open,
  });

  static GroupMetadata? loadFromEvent(Event event) {
    String? groupId;
    String? name;
    String? picture;
    String? about;
    bool? public;
    bool? open;
    int createdAt = event.createdAt;
    for (var tag in event.tags) {
      if (tag is List && tag.isNotEmpty) {
        var key = tag[0];

        if (key == "public") {
          public = true;
        } else if (key == "private") {
          public = false;
        } else if (key == "open") {
          open = true;
        } else if (key == "closed") {
          open = false;
        } else if (tag.length > 1) {
          var value = tag[1];

          if (key == "d") {
            groupId = value;
          } else if (key == "name") {
            name = value;
          } else if (key == "picture") {
            picture = value;
          } else if (key == "about") {
            about = value;
          } else if (key == "h") {
            groupId = value;
          }
        }
      }
    }

    if (StringUtil.isBlank(groupId)) {
      return null;
    }

    return GroupMetadata(
      groupId!,
      createdAt,
      name: name,
      picture: picture,
      about: about,
      public: public,
      open: open,
    );
  }
}
