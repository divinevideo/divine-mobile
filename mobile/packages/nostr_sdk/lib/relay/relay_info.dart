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

  RelayInfo(this.name, this.description, this.pubkey, this.contact, this.nips,
      this.software, this.version);

  factory RelayInfo.fromJson(Map<dynamic, dynamic> json) {
    final String name = json["name"] ?? '';
    final String description = json["description"] ?? "";
    final String pubkey = json["pubkey"] ?? "";
    final String contact = json["contact"] ?? "";
    final List<dynamic> nips = json["supported_nips"] ?? [];
    final String software = json["software"] ?? "";
    final String version = json["version"] ?? "";
    return RelayInfo(
        name, description, pubkey, contact, nips, software, version);
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
    return data;
  }
}
