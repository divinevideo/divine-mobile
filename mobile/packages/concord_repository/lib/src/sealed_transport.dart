// MPL-2.0
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

Uint8List _hmac(Uint8List key, Uint8List msg) {
  final h = pc.HMac(pc.SHA256Digest(), 64)..init(pc.KeyParameter(key));
  return h.process(msg);
}

Uint8List _hkdfExtract(Uint8List salt, Uint8List ikm) => _hmac(salt, ikm);

Uint8List _hkdfExpand(Uint8List prk, Uint8List info, int len) {
  final out = <int>[];
  var prev = Uint8List(0);
  var round = 1;
  while (out.length < len) {
    prev = _hmac(prk, Uint8List.fromList([...prev, ...info, round]));
    out.addAll(prev);
    round++;
  }
  return Uint8List.fromList(out.sublist(0, len));
}

pc.ECPoint _pointFromX(String xHex) {
  final curve = pc.ECCurve_secp256k1();
  final bytes = Uint8List.fromList([2, ...hexToBytes(xHex)]);
  return curve.curve.decodePoint(bytes)!;
}

Uint8List _ecdhX(String privHex, String pubXHex) {
  final point = _pointFromX(pubXHex) * BigInt.parse(privHex, radix: 16);
  final x = point!.x!.toBigInteger()!;
  final hex = x.toRadixString(16).padLeft(64, '0');
  return hexToBytes(hex);
}

/// NIP-44 conversation key for a keypair (self-conversation for streams).
Uint8List conversationKey(String privHex, String pubHex) =>
    _hkdfExtract(utf8Bytes('nip44-v2'), _ecdhX(privHex, pubHex));

Map<String, Uint8List> _messageKeys(Uint8List convKey, Uint8List nonce) {
  final keys = _hkdfExpand(convKey, nonce, 76);
  return {
    'chacha': keys.sublist(0, 32),
    'nonce': keys.sublist(32, 44),
    'hmac': keys.sublist(44, 76),
  };
}

int _paddedLen(int len) {
  if (len <= 32) return 32;
  var nextPower = 1;
  while (nextPower < len) {
    nextPower <<= 1;
  }
  final chunk = nextPower <= 256 ? 32 : nextPower ~/ 8;
  return chunk * ((len - 1) ~/ chunk + 1);
}

Future<String> nip44Encrypt(String plaintext, Uint8List convKey) async {
  final plainBytes = utf8.encode(plaintext);
  if (plainBytes.isEmpty || plainBytes.length > 65535) {
    throw ArgumentError('nip44: plaintext must contain 1..65535 UTF-8 bytes');
  }
  final nonce = Uint8List(32);
  final rnd = Random.secure();
  for (var i = 0; i < 32; i++) {
    nonce[i] = rnd.nextInt(256);
  }
  final keys = _messageKeys(convKey, nonce);
  final padded = Uint8List(2 + _paddedLen(plainBytes.length));
  ByteData.sublistView(padded).setUint16(0, plainBytes.length);
  padded.setRange(2, 2 + plainBytes.length, plainBytes);
  final algo = crypto.Chacha20(macAlgorithm: crypto.MacAlgorithm.empty);
  final box = await algo.encrypt(
    padded,
    secretKey: crypto.SecretKey(keys['chacha']!),
    nonce: keys['nonce'],
  );
  final cipher = Uint8List.fromList(box.cipherText);
  final mac = _hmac(keys['hmac']!, Uint8List.fromList([...nonce, ...cipher]));
  return base64Encode(Uint8List.fromList([2, ...nonce, ...cipher, ...mac]));
}

Future<String> nip44Decrypt(String payload, Uint8List convKey) async {
  if (payload.length < 132 || payload.length > 87472) {
    throw const FormatException('nip44: bad payload size');
  }
  final raw = base64Decode(payload);
  if (raw.length < 99 || raw.length > 65603 || raw[0] != 2) {
    throw const FormatException('nip44: bad payload');
  }
  final nonce = Uint8List.fromList(raw.sublist(1, 33));
  final mac = raw.sublist(raw.length - 32);
  final cipher = Uint8List.fromList(raw.sublist(33, raw.length - 32));
  final keys = _messageKeys(convKey, nonce);
  final expectMac = _hmac(
    keys['hmac']!,
    Uint8List.fromList([...nonce, ...cipher]),
  );
  var diff = 0;
  for (var i = 0; i < 32; i++) {
    diff |= expectMac[i] ^ mac[i];
  }
  if (diff != 0) throw const FormatException('nip44: bad mac');
  final algo = crypto.Chacha20(macAlgorithm: crypto.MacAlgorithm.empty);
  final box = crypto.SecretBox(
    cipher,
    nonce: keys['nonce']!,
    mac: crypto.Mac.empty,
  );
  final plain = await algo.decrypt(
    box,
    secretKey: crypto.SecretKey(keys['chacha']!),
  );
  final len = ByteData.sublistView(Uint8List.fromList(plain)).getUint16(0);
  // NIP-44 unpad: the length prefix must be nonzero and the padded size
  // must be exactly what that length pads to.
  if (len == 0 || plain.length != 2 + _paddedLen(len)) {
    throw const FormatException('nip44: bad padding');
  }
  return utf8.decode(plain.sublist(2, 2 + len));
}

Map<String, dynamic> _signEvent({
  required String secretHex,
  required int kind,
  required int createdAt,
  required List<List<String>> tags,
  required String content,
}) {
  final pub = schnorr.getPublicKey(secretHex);
  final id = computeEventId(
    pubkey: pub,
    createdAt: createdAt,
    kind: kind,
    tags: tags,
    content: content,
  );
  final aux = bytesToHex(
    Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256))),
  );
  return {
    'id': id,
    'kind': kind,
    'pubkey': pub,
    'created_at': createdAt,
    'tags': tags,
    'content': content,
    'sig': schnorr.sign(secretHex, id, aux),
  };
}

Future<Map<String, dynamic>> sealRumor({
  required Map<String, dynamic> rumor,
  required int sealKind,
  required String streamSeedHex,
  required String streamPubkey,
  required String authorSecretHex,
}) async {
  final conv = conversationKey(streamSeedHex, streamPubkey);
  final rumorJson = jsonEncode(rumor);
  final content = sealKind == 20013
      ? await nip44Encrypt(rumorJson, conv)
      : rumorJson;
  return _signEvent(
    secretHex: authorSecretHex,
    kind: sealKind,
    createdAt: rumor['created_at'] as int,
    tags: const [],
    content: content,
  );
}

Future<Map<String, dynamic>> wrapSeal({
  required Map<String, dynamic> seal,
  required String streamSeedHex,
  required String streamPubkey,
  int? expiresAt,
}) async {
  final conv = conversationKey(streamSeedHex, streamPubkey);
  final ephemeralSecret = bytesToHex(
    Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256))),
  );
  final content = await nip44Encrypt(jsonEncode(seal), conv);
  return _signEvent(
    secretHex: streamSeedHex,
    kind: 1059,
    createdAt: seal['created_at'] as int,
    tags: [
      ['p', schnorr.getPublicKey(ephemeralSecret)],
      if (expiresAt != null) ['expiration', '$expiresAt'],
    ],
    content: content,
  );
}

final _hex32 = RegExp(r'^[0-9a-f]{64}$');
final _hex64 = RegExp(r'^[0-9a-f]{128}$');
final _decimal = RegExp(r'^(0|[1-9][0-9]*)$');

// The last second a DateTime can hold; a later created_at cannot be shown.
const _maxCreatedAt = 8640000000000;

Map<String, dynamic> _decodeEvent(String encoded) {
  final value = jsonDecode(encoded);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('concord: event must be an object');
  }
  return value;
}

List<List<String>> _validateEvent(
  Map<String, dynamic> event, {
  required bool signed,
}) {
  final pubkey = event['pubkey'];
  final id = event['id'];
  final kind = event['kind'];
  final createdAt = event['created_at'];
  final sig = event['sig'];
  final tags = event['tags'];
  if (pubkey is! String ||
      !_hex32.hasMatch(pubkey) ||
      id is! String ||
      !_hex32.hasMatch(id) ||
      kind is! int ||
      kind < 0 ||
      kind > 65535 ||
      createdAt is! int ||
      createdAt < 0 ||
      createdAt > _maxCreatedAt ||
      event['content'] is! String ||
      tags is! List ||
      (signed && (sig is! String || !_hex64.hasMatch(sig))) ||
      (!signed && event.containsKey('sig'))) {
    throw const FormatException('concord: malformed event');
  }
  final result = <List<String>>[];
  for (final tag in tags) {
    if (tag is! List || tag.isEmpty || tag.any((value) => value is! String)) {
      throw const FormatException('concord: malformed tag');
    }
    result.add(tag.cast<String>());
  }
  return result;
}

void _verifyEvent(
  Map<String, dynamic> event,
  List<List<String>> tags,
  String layer,
) {
  final id = computeEventId(
    pubkey: event['pubkey'] as String,
    createdAt: event['created_at'] as int,
    kind: event['kind'] as int,
    tags: tags,
    content: event['content'] as String,
  );
  if (id != event['id'] ||
      !schnorr.verify(
        event['pubkey'] as String,
        id,
        event['sig'] as String,
      )) {
    throw FormatException('concord: bad-$layer-signature');
  }
}

void _validateChatTags(
  List<List<String>> tags,
  String expectedChannelId,
  int expectedEpoch,
) {
  final channels = tags.where((tag) => tag.first == 'channel').toList();
  final epochs = tags.where((tag) => tag.first == 'epoch').toList();
  if (channels.length != 1 ||
      channels.single.length != 2 ||
      channels.single[1] != expectedChannelId ||
      !_hex32.hasMatch(channels.single[1]) ||
      epochs.length != 1 ||
      epochs.single.length != 2 ||
      epochs.single[1] != '$expectedEpoch' ||
      expectedEpoch < 0) {
    throw const FormatException('concord: channel-epoch-binding');
  }
  for (final tag in tags) {
    // CORD-01 defines canonical decimal strings; CORD-02 bounds ms.
    if (const {
      'epoch',
      'ms',
      'k',
      'K',
      'expiration',
      'timer',
    }.contains(tag.first)) {
      if (tag.length != 2 ||
          !_decimal.hasMatch(tag[1]) ||
          (tag.first == 'ms' && (int.tryParse(tag[1]) ?? 1000) > 999)) {
        throw const FormatException('concord: malformed numeric tag');
      }
    }
    if (const {'e', 'E', 'p', 'P', 'q'}.contains(tag.first) &&
        (tag.length < 2 || !_hex32.hasMatch(tag[1]))) {
      throw const FormatException('concord: malformed reference tag');
    }
  }
}

/// Opens a Chat-plane wrap, authenticating every layer and its channel/epoch.
/// Control-plane plaintext seals use a different context and are not accepted.
Future<Map<String, dynamic>> openWrap({
  required Map<String, dynamic> wrap,
  required String streamSeedHex,
  required String streamPubkey,
  required String expectedChannelId,
  required int expectedEpoch,
}) async {
  final wrapTags = _validateEvent(wrap, signed: true);
  if (wrap['kind'] != 1059) {
    throw const FormatException('concord: bad-wrap-kind');
  }
  if (wrap['pubkey'] != streamPubkey) {
    throw const FormatException('concord: wrap author is not stream');
  }
  final recipients = wrapTags.where((tag) => tag.first == 'p').toList();
  if (recipients.length != 1 ||
      recipients.single.length != 2 ||
      !_hex32.hasMatch(recipients.single[1])) {
    throw const FormatException('concord: malformed wrap tags');
  }
  for (final tag in wrapTags) {
    if (tag.first != 'p' &&
        !(tag.first == 'expiration' &&
            tag.length == 2 &&
            _decimal.hasMatch(tag[1]))) {
      throw const FormatException('concord: malformed wrap tags');
    }
  }
  _verifyEvent(wrap, wrapTags, 'wrap');
  final conv = conversationKey(streamSeedHex, streamPubkey);
  final seal = _decodeEvent(
    await nip44Decrypt(wrap['content'] as String, conv),
  );
  final sealTags = _validateEvent(seal, signed: true);
  if (seal['kind'] != 20013) {
    throw const FormatException('concord: bad-seal-kind');
  }
  if (sealTags.isNotEmpty) {
    throw const FormatException('concord: malformed seal tags');
  }
  _verifyEvent(seal, sealTags, 'seal');
  final rumor = _decodeEvent(
    await nip44Decrypt(seal['content'] as String, conv),
  );
  final rumorTags = _validateEvent(rumor, signed: false);
  if (rumor['pubkey'] != seal['pubkey']) {
    throw const FormatException('concord: author-mismatch');
  }
  final expectId = computeEventId(
    pubkey: rumor['pubkey'] as String,
    createdAt: rumor['created_at'] as int,
    kind: rumor['kind'] as int,
    tags: rumorTags,
    content: rumor['content'] as String,
  );
  if (expectId != rumor['id']) {
    throw const FormatException('concord: bad-rumor-id');
  }
  _validateChatTags(rumorTags, expectedChannelId, expectedEpoch);
  return {
    'rumorId': rumor['id'],
    'author': seal['pubkey'],
    'kind': rumor['kind'],
    'content': rumor['content'],
    'tags': rumor['tags'],
    'createdAt': rumor['created_at'],
    'sealKind': seal['kind'],
    'rumor': rumor,
  };
}

/// Async author signer port: the app binds this to the active Divine
/// session identity (Keycast/local/external); packages never hold keys.
typedef SealSigner =
    Future<Map<String, dynamic>> Function(
      Map<String, dynamic> template,
    );

Future<Map<String, dynamic>> sealRumorWithSigner({
  required Map<String, dynamic> rumor,
  required int sealKind,
  required String streamSeedHex,
  required String streamPubkey,
  required SealSigner signer,
}) async {
  final conv = conversationKey(streamSeedHex, streamPubkey);
  final rumorJson = jsonEncode(rumor);
  final content = sealKind == 20013
      ? await nip44Encrypt(rumorJson, conv)
      : rumorJson;
  return signer({
    'kind': sealKind,
    'content': content,
    'tags': <List<String>>[],
    'created_at': rumor['created_at'],
  });
}
