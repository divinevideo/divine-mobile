part of '../challenge_protocol.dart';

({String pubkey, String identifier}) _parseCoordinate(String value) {
  final match = RegExp(
    r'^31923:([0-9a-f]{64}):(.+)$',
    dotAll: true,
  ).firstMatch(value);
  _require(
    match != null,
    'coordinate',
    'Expected a full challenge coordinate.',
  );
  return (pubkey: match!.group(1)!, identifier: match.group(2)!);
}

String? _definitionCoordinate(NostrEvent e) {
  if (e.kind != 31923) return null;
  for (final tag in e.tags) {
    if (tag.isNotEmpty && tag.first == 'd') {
      return tag.length > 1 && tag[1].isNotEmpty
          ? '31923:${e.pubkey}:${tag[1]}'
          : null;
    }
  }
  return null;
}

List<int> _convertBits(List<int> data, int from, int to, {required bool pad}) {
  var acc = 0;
  var bits = 0;
  final result = <int>[];
  final mask = (1 << to) - 1;
  for (final value in data) {
    if (value < 0 || value >> from != 0) {
      throw const FormatException('Invalid bits');
    }
    acc = ((acc << from) | value) & ((1 << (from + to - 1)) - 1);
    bits += from;
    while (bits >= to) {
      bits -= to;
      result.add((acc >> bits) & mask);
    }
  }
  if (pad) {
    if (bits > 0) result.add((acc << (to - bits)) & mask);
  } else if (bits >= from || ((acc << (to - bits)) & mask) != 0) {
    throw const FormatException('Invalid padding');
  }
  return result;
}

String _bytesHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
String _noteEncode(String id) => bech32.encode(
  Bech32(
    'note',
    _convertBits(
      [
        for (var i = 0; i < id.length; i += 2)
          int.parse(id.substring(i, i + 2), radix: 16),
      ],
      8,
      5,
      pad: true,
    ),
  ),
);

Set<String> _citedIds(String content) {
  final ids = <String>{};
  final matches = RegExp(
    'nostr:((?:note|nevent)1[023456789acdefghjklmnpqrstuvwxyz]+)',
    caseSensitive: false,
  ).allMatches(content);
  for (final match in matches) {
    try {
      final decoded = bech32.decode(match.group(1)!, 5000);
      final bytes = _convertBits(decoded.data, 5, 8, pad: false);
      if (decoded.hrp == 'note') ids.add(_bytesHex(bytes));
      if (decoded.hrp == 'nevent') {
        final fields = <int, List<List<int>>>{};
        for (var at = 0; at < bytes.length;) {
          if (at + 2 > bytes.length) throw const FormatException('Invalid TLV');
          final type = bytes[at++];
          final length = bytes[at++];
          if (at + length > bytes.length) {
            throw const FormatException('Invalid TLV');
          }
          fields
              .putIfAbsent(type, () => [])
              .add(bytes.sublist(at, at + length));
          at += length;
        }
        final id = fields[0]?.first;
        if (id == null ||
            id.length != 32 ||
            (fields[2] != null && fields[2]!.first.length != 32) ||
            (fields[3] != null && fields[3]!.first.length != 4)) {
          throw const FormatException('Invalid event pointer');
        }
        ids.add(_bytesHex(id));
      }
    } on Object {
      /* Invalid NIP-21 references do not provide a citation. */
    }
  }
  return ids;
}
