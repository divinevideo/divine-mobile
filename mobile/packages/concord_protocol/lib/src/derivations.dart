// MPL-2.0
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:crypto/crypto.dart';

Uint8List hexToBytes(String hex) {
  if (hex.length.isOdd || !RegExp(r'^[0-9a-f]*$').hasMatch(hex)) {
    throw ArgumentError('concord: bad hex');
  }
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String bytesToHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List concatBytes(List<Uint8List> parts) {
  final out = Uint8List(parts.fold<int>(0, (n, p) => n + p.length));
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

Uint8List u64be(int n) {
  final out = ByteData(8)..setUint64(0, n);
  return out.buffer.asUint8List();
}

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

Uint8List sha256Bytes(List<int> input) =>
    Uint8List.fromList(sha256.convert(input).bytes);

Uint8List hmacSha256(List<int> key, List<int> msg) =>
    Uint8List.fromList(Hmac(sha256, key).convert(msg).bytes);

/// HKDF-SHA256 per CORD-02 A.1: salt empty, info=utf8(label)||0x00||id||epoch?
Uint8List hkdfSeed(
  List<int> secret,
  String label,
  List<int> id, {
  int? epoch,
  int? counter,
}) {
  if (id.length != 32) throw ArgumentError('concord: hkdf id must be 32 bytes');
  var info = concatBytes([
    utf8Bytes(label),
    Uint8List.fromList([0]),
    Uint8List.fromList(id),
  ]);
  if (epoch != null) {
    info = concatBytes([info, u64be(epoch)]);
  }
  if (counter != null) {
    info = concatBytes([
      info,
      Uint8List.fromList([counter]),
    ]);
  }
  final prk = hmacSha256(Uint8List(0), secret);
  return hmacSha256(
    prk,
    concatBytes([
      info,
      Uint8List.fromList([1]),
    ]),
  ).sublist(0, 32);
}

final BigInt _secpOrder = BigInt.parse(
  'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
  radix: 16,
);

bool isValidScalar(List<int> seed) {
  if (seed.length != 32) return false;
  final v = BigInt.parse(bytesToHex(seed), radix: 16);
  return v > BigInt.zero && v < _secpOrder;
}

class GroupKey {
  GroupKey(this.seedHex, this.pubkey);
  final String seedHex;
  final String pubkey;
}

GroupKey groupKey(String label, String secretHex, String idHex, {int? epoch}) {
  int? counter;
  while (true) {
    final seed = hkdfSeed(
      hexToBytes(secretHex),
      label,
      hexToBytes(idHex),
      epoch: epoch,
      counter: counter,
    );
    if (isValidScalar(seed)) {
      final seedHex = bytesToHex(seed);
      return GroupKey(seedHex, schnorr.getPublicKey(seedHex));
    }
    counter = (counter ?? -1) + 1;
    if (counter > 255) throw StateError('concord: scalar_normalize exhausted');
  }
}

String deriveCommunityId(String ownerXonlyHex, String ownerSaltHex) =>
    bytesToHex(
      sha256Bytes(
        concatBytes([
          utf8Bytes('concord/community'),
          hexToBytes(ownerXonlyHex),
          hexToBytes(ownerSaltHex),
        ]),
      ),
    );

String epochKeyCommitment(int prevEpoch, String prevKeyHex) => bytesToHex(
  sha256Bytes(
    concatBytes([
      utf8Bytes('concord/epoch-key-commitment'),
      u64be(prevEpoch),
      hexToBytes(prevKeyHex),
    ]),
  ),
);

String dissolvedPubkey(String communityIdHex) =>
    groupKey('concord/dissolved', communityIdHex, '00' * 32).pubkey;

String grantLocator(String communityIdHex, String memberXonlyHex) => bytesToHex(
  hkdfSeed(
    hexToBytes(communityIdHex),
    'concord/grant',
    hexToBytes(memberXonlyHex),
  ),
);

String banlistLocator(String communityIdHex) => bytesToHex(
  hkdfSeed(hexToBytes(communityIdHex), 'concord/banlist', Uint8List(32)),
);

GroupKey controlSignerKey(
  String controlRootHex,
  String communityIdHex,
  int epoch,
) => groupKey(
  'concord/control-signer',
  controlRootHex,
  communityIdHex,
  epoch: epoch,
);

GroupKey controlReadKey(
  String communityRootHex,
  String communityIdHex,
  int epoch,
) =>
    groupKey('concord/control', communityRootHex, communityIdHex, epoch: epoch);

GroupKey guestbookKey(
  String communityRootHex,
  String communityIdHex,
  int epoch,
) => groupKey(
  'concord/guestbook',
  communityRootHex,
  communityIdHex,
  epoch: epoch,
);

GroupKey publicChannelKey(
  String communityRootHex,
  String channelIdHex,
  int epoch,
) => groupKey('concord/channel', communityRootHex, channelIdHex, epoch: epoch);

GroupKey privateChannelKey(
  String channelKeyHex,
  String channelIdHex,
  int epoch,
) => groupKey('concord/channel', channelKeyHex, channelIdHex, epoch: epoch);

String editionHash(
  String entityIdHex,
  int version,
  String? prevHex,
  String content,
) {
  const label = 'vector-community/v1/edition';
  Uint8List len64(List<int> b) =>
      concatBytes([u64be(b.length), Uint8List.fromList(b)]);
  final prevPart = prevHex != null
      ? concatBytes([
          Uint8List.fromList([1]),
          hexToBytes(prevHex),
        ])
      : concatBytes([
          Uint8List.fromList([0]),
          Uint8List(32),
        ]);
  return bytesToHex(
    sha256Bytes(
      concatBytes([
        len64(utf8Bytes(label)),
        hexToBytes(entityIdHex),
        u64be(version),
        prevPart,
        len64(utf8Bytes(content)),
      ]),
    ),
  );
}

String computeEventId({
  required String pubkey,
  required int createdAt,
  required int kind,
  required List<List<String>> tags,
  required String content,
}) => sha256Hex(jsonEncode([0, pubkey, createdAt, kind, tags, content]));

String bytesToB64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');

String hexToB64url(String hex) => bytesToB64url(hexToBytes(hex));

bool isB64url32(String s) =>
    s.length == 43 && RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(s);

String b64urlToHex(String s) {
  final padded = s.padRight((s.length + 3) ~/ 4 * 4, '=');
  return bytesToHex(base64Url.decode(padded));
}

/// Resolves the live stream key for a channel from kind-33302-held
/// material (base64url-43 fields). A held channel `key` means private
/// (per-channel epoch); otherwise derive from community_root.
GroupKey? streamKeyFromListEntry(
  Map<String, dynamic> entry,
  String channelIdB64,
) {
  final current = entry['current'] as Map<String, dynamic>?;
  if (current == null) return null;
  final channels = (current['channels'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  Map<String, dynamic>? channel;
  for (final c in channels) {
    if (c['id'] == channelIdB64) channel = c;
  }
  if (channel == null) return null;
  final channelIdHex = b64urlToHex(channel['id'] as String);
  final key = channel['key'] as String?;
  if (key != null) {
    return groupKey(
      'concord/channel',
      b64urlToHex(key),
      channelIdHex,
      epoch: (channel['epoch'] as num).toInt(),
    );
  }
  return groupKey(
    'concord/channel',
    b64urlToHex(current['community_root'] as String),
    channelIdHex,
    epoch: (current['root_epoch'] as num).toInt(),
  );
}

/// Legacy POC stream id retained only for old fixture readability; spec
/// channels are addressed by derived channel pubkeys, not this hash.
String deriveStreamId(String communityId, String channelId) => sha256
    .convert(utf8.encode('concord/stream/v1:$communityId:$channelId'))
    .toString();

String deriveMessageId(
  String streamId,
  String author,
  int createdAt,
  String body,
) => sha256
    .convert(utf8.encode('concord/msg/v1:$streamId:$author:$createdAt:$body'))
    .toString();
