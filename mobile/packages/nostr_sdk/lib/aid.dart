/// the base aid class.
class AId {
  int kind = 0;

  String pubkey = "";

  String title = "";

  AId({
    required this.kind,
    required this.pubkey,
    required this.title,
  });

  static AId? fromString(String text) {
    var strs = text.split(":");
    if (strs.length == 3) {
      var kind = int.tryParse(strs[0]);
      var pubkey = strs[1];
      var title = strs[2];

      if (kind != null) {
        return AId(kind: kind, pubkey: pubkey, title: title);
      }
    }

    return null;
  }

  String toAString() {
    return "$kind:$pubkey:$title";
  }
}
