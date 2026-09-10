/// A relay information document
class RelayInfo {
  /// Relay name
  final String name;

  /// Relay description
  final String description;

  /// Nostr public key of the relay admin
  final String pubkey;

  /// Alternative contact of the relay admin
  final String contact;

  /// Nostr Implementation Possibilities supported by the relay
  final List<dynamic> nips;

  /// Relay software description
  final String software;

  /// Relay software version identifier
  final String version;

  /// Maximum number of events the relay returns for a single query, from
  /// NIP-11 `limitation.max_limit`. `null` when the relay's NIP-11 document
  /// does not advertise one, or advertises a malformed value or one below 1.
  final int? maxLimit;

  RelayInfo(
    this.name,
    this.description,
    this.pubkey,
    this.contact,
    this.nips,
    this.software,
    this.version, {
    this.maxLimit,
  });

  factory RelayInfo.fromJson(Map<dynamic, dynamic> json) {
    final String name = json["name"] ?? '';
    final String description = json["description"] ?? "";
    final String pubkey = json["pubkey"] ?? "";
    final String contact = json["contact"] ?? "";
    final List<dynamic> nips = json["supported_nips"] ?? [];
    final String software = json["software"] ?? "";
    final String version = json["version"] ?? "";
    return RelayInfo(
      name,
      description,
      pubkey,
      contact,
      nips,
      software,
      version,
      maxLimit: _parseMaxLimit(json['limitation']),
    );
  }

  /// Parses NIP-11 `limitation.max_limit`, tolerating an absent or
  /// malformed `limitation` object rather than throwing.
  ///
  /// A limit below 1 caps nothing, and taken at its word it would make every
  /// query to the relay look capped, so it counts as none.
  static int? _parseMaxLimit(dynamic limitation) {
    if (limitation is! Map) return null;
    final maxLimit = limitation['max_limit'];
    if (maxLimit is! num) return null;
    final limit = maxLimit.toInt();
    return limit > 0 ? limit : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['description'] = description;
    data['pubkey'] = pubkey;
    data['contact'] = contact;
    data['nips'] = nips;
    data['software'] = software;
    data['version'] = version;
    final maxLimit = this.maxLimit;
    if (maxLimit != null) {
      data['limitation'] = {'max_limit': maxLimit};
    }
    return data;
  }
}
