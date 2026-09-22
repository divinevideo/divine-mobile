import 'package:nostr_sdk/event.dart';

/// filter is a JSON object that determines what events will be sent in that subscription
class Filter {
  /// a list of event ids, each an exact 64-character lowercase hex value
  List<String>? ids;

  /// a list of pubkeys, each an exact 64-character lowercase hex value; the
  /// pubkey of an event must be one of these
  List<String>? authors;

  /// a list of a kind numbers
  List<int>? kinds;

  /// a list of event ids that are referenced in an "e" tag
  List<String>? e;

  /// a list of pubkeys that are referenced in a "p" tag
  List<String>? p;

  /// a list of hashtags that are referenced in a "t" tag
  List<String>? t;

  /// a list of values that are referenced in a "h" tag (vine.hol.is relay requirement)
  List<String>? h;

  /// a list of values that are referenced in a "d" tag (NIP-33 addressable events)
  List<String>? d;

  /// a list of addressable IDs referenced in an "a" tag (NIP-33 addressable events)
  /// Format: `kind:pubkey:d-tag`
  List<String>? a;

  /// a list of event ids that are referenced in an uppercase "E" tag (NIP-22 root scope)
  List<String>? uppercaseE;

  /// a list of addressable IDs referenced in an uppercase "A" tag (NIP-22 root scope for addressable events)
  /// Format: `kind:pubkey:d-tag`
  List<String>? uppercaseA;

  /// a list of kind values that are referenced in an uppercase "K" tag (NIP-22 root kind)
  List<String>? uppercaseK;

  /// a list of MIME types that are referenced in an "m" tag (NIP-94 file metadata)
  List<String>? m;

  /// a timestamp, events must be newer than this to pass
  int? since;

  /// a timestamp, events must be older than this to pass
  int? until;

  /// maximum number of events to be returned in the initial query
  int? limit;

  /// NIP-50 search query string for full-text search in content field
  String? search;

  /// Default constructor
  Filter({
    this.ids,
    this.authors,
    this.kinds,
    this.e,
    this.p,
    this.t,
    this.h,
    this.d,
    this.a,
    this.uppercaseE,
    this.uppercaseA,
    this.uppercaseK,
    this.m,
    this.since,
    this.until,
    this.limit,
    this.search,
  });

  /// Deserialize a filter from a JSON
  Filter.fromJson(Map<String, dynamic> json) {
    ids = json['ids'] == null ? null : List<String>.from(json['ids']);
    authors = json['authors'] == null
        ? null
        : List<String>.from(json['authors']);
    kinds = json['kinds'] == null ? null : List<int>.from(json['kinds']);
    e = json['#e'] == null ? null : List<String>.from(json['#e']);
    p = json['#p'] == null ? null : List<String>.from(json['#p']);
    t = json['#t'] == null ? null : List<String>.from(json['#t']);
    h = json['#h'] == null ? null : List<String>.from(json['#h']);
    d = json['#d'] == null ? null : List<String>.from(json['#d']);
    a = json['#a'] == null ? null : List<String>.from(json['#a']);
    uppercaseE = json['#E'] == null ? null : List<String>.from(json['#E']);
    uppercaseA = json['#A'] == null ? null : List<String>.from(json['#A']);
    uppercaseK = json['#K'] == null ? null : List<String>.from(json['#K']);
    m = json['#m'] == null ? null : List<String>.from(json['#m']);
    since = json['since'];
    until = json['until'];
    limit = json['limit'];
    search = json['search'];
  }

  /// Serialize a filter in JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (ids != null) {
      data['ids'] = ids;
    }
    if (authors != null) {
      data['authors'] = authors;
    }
    if (kinds != null) {
      data['kinds'] = kinds;
    }
    if (e != null) {
      data['#e'] = e;
    }
    if (p != null) {
      data['#p'] = p;
    }
    if (t != null) {
      data['#t'] = t;
    }
    if (h != null) {
      data['#h'] = h;
    }
    if (d != null) {
      data['#d'] = d;
    }
    if (a != null) {
      data['#a'] = a;
    }
    if (uppercaseE != null) {
      data['#E'] = uppercaseE;
    }
    if (uppercaseA != null) {
      data['#A'] = uppercaseA;
    }
    if (uppercaseK != null) {
      data['#K'] = uppercaseK;
    }
    if (m != null) {
      data['#m'] = m;
    }
    if (since != null) {
      data['since'] = since;
    }
    if (until != null) {
      data['until'] = until;
    }
    if (limit != null) {
      data['limit'] = limit;
    }
    if (search != null) {
      data['search'] = search;
    }
    return data;
  }

  bool checkEvent(Event event) {
    // Exact, not prefix. NIP-01: "The `ids`, `authors`, `#e` and `#p` filter
    // lists MUST contain exact 64-character lowercase hex values." A prefix
    // compare would also make a single `''` entry match every event, turning
    // the admission gates built on checkEvent into pass-throughs.
    if (ids != null && (!ids!.contains(event.id))) {
      return false;
    }
    if (authors != null && (!authors!.contains(event.pubkey))) {
      return false;
    }
    if (kinds != null && (!kinds!.contains(event.kind))) {
      return false;
    }
    if (since != null && since! > event.createdAt) {
      return false;
    }
    if (until != null && until! < event.createdAt) {
      return false;
    }

    List<String> es = [];
    List<String> ps = [];
    List<String> ts = [];
    List<String> hs = [];
    List<String> ds = [];
    List<String> as_ = [];
    List<String> uppercaseEs = [];
    List<String> uppercaseAs = [];
    List<String> uppercaseKs = [];
    List<String> ms = [];
    for (var tag in event.tags) {
      if (tag.length > 1) {
        var k = tag[0];
        var v = tag[1];

        if (k == "e") {
          es.add(v);
        } else if (k == "p") {
          ps.add(v);
        } else if (k == "t") {
          ts.add(v);
        } else if (k == "h") {
          hs.add(v);
        } else if (k == "d") {
          ds.add(v);
        } else if (k == "a") {
          as_.add(v);
        } else if (k == "E") {
          uppercaseEs.add(v);
        } else if (k == "A") {
          uppercaseAs.add(v);
        } else if (k == "K") {
          uppercaseKs.add(v);
        } else if (k == "m") {
          ms.add(v);
        }
      }
    }
    if (e != null &&
        (!(es.any((v) {
          return e!.contains(v);
        })))) {
      // filter query e but es don't contains e.
      return false;
    }
    if (p != null &&
        (!(ps.any((v) {
          return p!.contains(v);
        })))) {
      // filter query p but ps don't contains p.
      return false;
    }
    if (t != null &&
        (!(ts.any((v) {
          return t!.contains(v);
        })))) {
      // filter query t but ts don't contains t.
      return false;
    }
    if (h != null &&
        (!(hs.any((v) {
          return h!.contains(v);
        })))) {
      // filter query h but hs don't contains h.
      return false;
    }
    if (d != null &&
        (!(ds.any((v) {
          return d!.contains(v);
        })))) {
      // filter query d but ds don't contains d.
      return false;
    }
    if (a != null &&
        (!(as_.any((v) {
          return a!.contains(v);
        })))) {
      // filter query a but as don't contains a.
      return false;
    }
    if (uppercaseE != null &&
        (!(uppercaseEs.any((v) {
          return uppercaseE!.contains(v);
        })))) {
      // filter query E but Es don't contains E.
      return false;
    }
    if (uppercaseA != null &&
        (!(uppercaseAs.any((v) {
          return uppercaseA!.contains(v);
        })))) {
      // filter query A but As don't contains A.
      return false;
    }
    if (uppercaseK != null &&
        (!(uppercaseKs.any((v) {
          return uppercaseK!.contains(v);
        })))) {
      // filter query K but Ks don't contains K.
      return false;
    }
    if (m != null &&
        (!(ms.any((v) {
          return m!.contains(v);
        })))) {
      // filter query m but ms don't contains m.
      return false;
    }

    return true;
  }
}
