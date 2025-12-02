import 'contact.dart';

class ContactList {
  late Map<String, Contact> _contacts;

  late Map<String, int> _followedTags;

  late Map<String, int> _followedCommunitys;

  late int createdAt;

  ContactList({
    Map<String, Contact>? contacts,
    Map<String, int>? followedTags,
    Map<String, int>? followedCommunitys,
    int? createdAt,
  }) {
    contacts ??= {};
    followedTags ??= {};
    followedCommunitys ??= {};

    _contacts = contacts;
    _followedTags = followedTags;
    _followedCommunitys = followedCommunitys;

    createdAt ??= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    this.createdAt = createdAt;
  }

  static void getContactInfoFromTags(
      List<dynamic> tags,
      Map<String, Contact> contacts,
      Map<String, int> followedTags,
      Map<String, int> followedCommunitys) {
    for (List<dynamic> tag in tags) {
      var length = tag.length;
      if (length == 0) {
        continue;
      }

      var t = tag[0];
      if (t == "p") {
        String url = "";
        String petname = "";
        if (length > 2) {
          url = tag[2];
        }
        if (length > 3) {
          petname = tag[3];
        }
        try {
          final contact =
              Contact(publicKey: tag[1], url: url, petname: petname);
          contacts[contact.publicKey] = contact;
        } catch (e) {}
      } else if (t == "t" && length > 1) {
        var tagName = tag[1];
        followedTags[tagName] = 1;
      } else if (t == "a" && length > 1) {
        var id = tag[1];
        followedCommunitys[id] = 1;
      }
    }
  }

  factory ContactList.fromJson(List<dynamic> tags, int createdAt) {
    Map<String, Contact> contacts = {};
    Map<String, int> followedTags = {};
    Map<String, int> followedCommunitys = {};
    getContactInfoFromTags(tags, contacts, followedTags, followedCommunitys);
    return ContactList._(contacts, followedTags, followedCommunitys, createdAt);
  }

  ContactList._(this._contacts, this._followedTags, this._followedCommunitys,
      this.createdAt);

  List<dynamic> toJson() {
    List<dynamic> result = [];
    for (Contact contact in _contacts.values) {
      result.add(["p", contact.publicKey, contact.url, contact.petname]);
    }
    for (var followedTag in _followedTags.keys) {
      result.add(["t", followedTag]);
    }
    for (var id in _followedCommunitys.keys) {
      result.add(["a", id]);
    }
    return result;
  }

  void add(Contact contact) {
    _contacts[contact.publicKey] = contact;
  }

  Contact? get(String publicKey) {
    return _contacts[publicKey];
  }

  Contact? remove(String publicKey) {
    return _contacts.remove(publicKey);
  }

  Iterable<Contact> list() {
    return _contacts.values;
  }

  bool isEmpty() {
    return _contacts.isEmpty;
  }

  int total() {
    return _contacts.length;
  }

  void clear() {
    if (_contacts.isNotEmpty) {
      _contacts.clear();
    }
  }

  bool containsTag(String tagName) {
    return _followedTags.containsKey(tagName);
  }

  void addTag(String tagName) {
    _followedTags[tagName] = 1;
  }

  void removeTag(String tagName) {
    _followedTags.remove(tagName);
  }

  int totalFollowedTags() {
    return _followedTags.length;
  }

  Iterable<String> tagList() {
    return _followedTags.keys;
  }

  bool containsCommunity(String id) {
    return _followedCommunitys.containsKey(id);
  }

  void addCommunity(String id) {
    _followedCommunitys[id] = 1;
  }

  void removeCommunity(String id) {
    _followedCommunitys.remove(id);
  }

  int totalFollowedCommunities() {
    return _followedCommunitys.length;
  }

  Iterable<String> followedCommunitiesList() {
    return _followedCommunitys.keys;
  }
}
