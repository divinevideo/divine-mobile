import '../event.dart';
import '../event_kind.dart';
import '../utils/string_util.dart';
import 'group_object.dart';

class GroupMembers extends GroupObject {
  List<String>? members;

  GroupMembers(String groupId, this.members, int createdAt)
    : super(groupId, createdAt);

  static GroupMembers? loadFromEvent(Event e) {
    if (e.kind != EventKind.groupMembers) {
      return null;
    }

    String? groupId;
    List<String> members = [];
    for (var tag in e.tags) {
      if (tag is List) {
        var length = tag.length;
        if (length > 1) {
          var key = tag[0];
          var value = tag[1];

          if (key == "p") {
            members.add(value);
          } else if (key == "d") {
            groupId = value;
          }
        }
      }
    }

    if (StringUtil.isBlank(groupId)) {
      return null;
    }

    return GroupMembers(groupId!, members, e.createdAt);
  }

  bool contains(String pubkey) {
    if (members != null) {
      if (members!.contains(pubkey)) {
        return true;
      }
    }

    return false;
  }

  void remove(String pubkey) {
    if (members != null) {
      members!.remove(pubkey);
    }
  }

  void add(String pubkey) {
    if (members != null) {
      members!.add(pubkey);
    }
  }

  bool isMember(String pubkey) {
    return members != null && members!.contains(pubkey);
  }
}
