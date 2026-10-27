import 'dart:convert';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

/// An address is a lookup hint, never evidence of a challenge marker.
/// The page must fetch and authenticate the current definition before showing it.
class ChallengeLink {
  const ChallengeLink._(this.naddr, this.coordinate, this.relays);
  final String naddr;
  final String coordinate;
  final List<String> relays;

  static ChallengeLink? parse(String value) {
    try {
      if (value.length > 4096) return null;
      final decoded = bech32.decode(value, 4096);
      if (decoded.hrp != 'naddr') return null;
      final bytes = Nip19.convertBits(decoded.data, 5, 8, false);
      final fields = <int, List<List<int>>>{};
      for (var at = 0; at < bytes.length;) {
        if (at + 2 > bytes.length) return null;
        final type = bytes[at++];
        final length = bytes[at++];
        if (at + length > bytes.length) return null;
        fields.putIfAbsent(type, () => []).add(bytes.sublist(at, at + length));
        at += length;
      }
      if ([0, 2, 3].any((key) => fields[key]?.length != 1)) return null;
      final identifier = utf8.decode(fields[0]!.single);
      final author = fields[2]!.single;
      final kind = fields[3]!.single;
      if (identifier.isEmpty ||
          author.length != 32 ||
          kind.length != 4 ||
          ByteData.sublistView(Uint8List.fromList(kind)).getUint32(0) !=
              31923) {
        return null;
      }
      final pubkey = author
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final relays = <String>{};
      for (final raw in fields[1] ?? <List<int>>[]) {
        final relay = normalizeRelayUrl(utf8.decode(raw));
        if (relay != null) relays.add(relay);
      }
      return ChallengeLink._(
        value,
        '31923:$pubkey:$identifier',
        List.unmodifiable(relays.take(16)),
      );
    } on Object {
      return null;
    }
  }
}
