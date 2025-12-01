class GroupIdentifier {
  // This field in here is wss://domain not like NIP29 domain
  String host;

  String groupId;

  GroupIdentifier(this.host, this.groupId);

  static GroupIdentifier? parse(String idStr) {
    var strs = idStr.split("'");
    if (strs.isNotEmpty && strs.length > 1) {
      return GroupIdentifier(strs[0], strs[1]);
    }

    return null;
  }

  @override
  String toString() {
    return "$host'$groupId";
  }

  List<dynamic> toJson() {
    List<dynamic> list = [];
    list.add("group");
    list.add(groupId);
    list.add(host);
    return list;
  }
}
