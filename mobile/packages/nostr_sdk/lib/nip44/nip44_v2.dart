import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:kepler/kepler.dart';
import 'package:pointycastle/export.dart';
import 'package:cryptography/cryptography.dart' as cryptography;

// Message encrypt and decrypt
// code from https://github.com/0xchat-app/nostr-dart
class NIP44V2 {
  static final _digest = SHA256Digest();
  static const _hmacBlockSize = 64;

  static Uint8List hkdfExtract(Uint8List salt, Uint8List ikm) {
    var hmac = HMac(_digest, _hmacBlockSize)..init(KeyParameter(salt));
    return hmac.process(ikm);
  }

  static Uint8List hkdfExpand(Uint8List prk, Uint8List info, int outputLength) {
    final hmac = HMac(_digest, _hmacBlockSize);
    hmac.init(KeyParameter(prk));

    var output = Uint8List(outputLength);
    var current = Uint8List(0);
    int generatedLength = 0;
    int round = 1;

    while (generatedLength < outputLength) {
      var roundInput = Uint8List(current.length + info.length + 1)
        ..setRange(0, current.length, current)
        ..setRange(current.length, current.length + info.length, info)
        ..[current.length + info.length] = round;

      current = hmac.process(roundInput);
      var partLength = min(outputLength - generatedLength, _digest.digestSize);
      output.setRange(generatedLength, generatedLength + partLength, current);
      generatedLength += partLength;
      round++;
    }

    return output;
  }

  static Map<String, Uint8List> getMessageKeys(
      Uint8List conversationKey, Uint8List nonce) {
    assert(conversationKey.length == 32);
    assert(nonce.length == 32);

    Uint8List keys = hkdfExpand(conversationKey, nonce, 76);

    return {
      'chacha_key': keys.sublist(0, 32),
      'chacha_nonce': keys.sublist(32, 44),
      'hmac_key': keys.sublist(44, 76),
    };
  }

  static int calcPaddedLen(int len) {
    if (len < 1) throw Exception('expected positive integer');
    if (len <= 32) return 32;
    int nextPower = 1 << ((len - 1).bitLength);
    int chunk = nextPower <= 256 ? 32 : nextPower ~/ 8;
    return chunk * ((len - 1) ~/ chunk + 1);
  }

  static Uint8List writeU16BE(int num) {
    if (num < 1 || num > 65535) {
      throw Exception(
          'Invalid plaintext size: must be between 1 and 65535 bytes');
    }
    var buffer = ByteData(2);
    buffer.setUint16(0, num, Endian.big);
    return buffer.buffer.asUint8List();
  }

  static Uint8List pad(String plaintext) {
    var unpadded = utf8.encode(plaintext);
    var unpaddedLen = unpadded.length;
    var prefix = writeU16BE(unpaddedLen);
    var suffix = Uint8List(calcPaddedLen(unpaddedLen) - unpaddedLen);
    return Uint8List.fromList(prefix + unpadded + suffix);
  }

  static String unpad(Uint8List padded) {
    var unpaddedLen =
        ByteData.sublistView(padded, 0, 2).getUint16(0, Endian.big);
    var unpadded = padded.sublist(2, 2 + unpaddedLen);
    if (unpaddedLen < 1 ||
        unpaddedLen > 65535 ||
        unpadded.length != unpaddedLen ||
        padded.length != 2 + calcPaddedLen(unpaddedLen)) {
      throw Exception('Invalid padding');
    }
    return utf8.decode(unpadded);
  }

  static Uint8List hmacAad(Uint8List key, Uint8List message, Uint8List aad) {
    if (aad.length != 32) {
      throw Exception('AAD associated data must be 32 bytes');
    }
    var combined = Uint8List.fromList(aad + message);
    var hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return hmac.process(combined);
  }

  static Map<String, Uint8List> decodePayload(String payload) {
    if (payload.length < 132 || payload.length > 87472) {
      throw Exception('Invalid payload length: ${payload.length}');
    }
    if (payload.startsWith('#')) {
      throw Exception('Unknown encryption version');
    }

    Uint8List data;
    try {
      data = base64Decode(payload);
    } catch (e) {
      throw Exception('Invalid base64: ${e.toString()}');
    }

    if (data.length < 99 || data.length > 65603) {
      throw Exception('Invalid data length: ${data.length}');
    }

    int version = data[0];
    if (version != 2) {
      throw Exception('Unknown encryption version $version');
    }

    return {
      'nonce': data.sublist(1, 33),
      'ciphertext': data.sublist(33, data.length - 32),
      'mac': data.sublist(data.length - 32),
    };
  }

  static Uint8List randomBytes(int length) {
    var rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static Future<Uint8List> chacha20Encrypt(
      Uint8List key, Uint8List nonce, Uint8List data) async {
    final algorithm =
        cryptography.Chacha20(macAlgorithm: cryptography.MacAlgorithm.empty);
    // Encrypt
    final secretBox = await algorithm.encrypt(
      data,
      secretKey: cryptography.SecretKey(key),
      nonce: nonce,
    );

    return Uint8List.fromList(secretBox.cipherText);
  }

  static Future<Uint8List> chacha20Decrypt(
      Uint8List key, Uint8List nonce, Uint8List ciphertext) async {
    final algorithm =
        cryptography.Chacha20(macAlgorithm: cryptography.MacAlgorithm.empty);
    cryptography.SecretBox secretBox = cryptography.SecretBox(ciphertext,
        nonce: nonce, mac: cryptography.Mac.empty);
    // Encrypt
    final result = await algorithm.decrypt(
      secretBox,
      secretKey: cryptography.SecretKey(key),
    );

    return Uint8List.fromList(result);
  }

  static bool listEquals<T>(List<T>? list1, List<T>? list2) {
    if (list1 == null || list2 == null) return list1 == list2;
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  static Future<String> encrypt(String plaintext, Uint8List conversationKey,
      [Uint8List? nonce]) async {
    nonce ??= randomBytes(32);
    var keys = getMessageKeys(conversationKey, nonce);
    var padded = pad(plaintext);
    var ciphertext = await chacha20Encrypt(
        keys['chacha_key']!, keys['chacha_nonce']!, padded);
    var mac = hmacAad(keys['hmac_key']!, ciphertext, nonce);
    return base64Encode(Uint8List.fromList([2] + nonce + ciphertext + mac));
  }

  static Future<String> decrypt(
      String payload, Uint8List conversationKey) async {
    var payloadData = decodePayload(payload);
    var keys = getMessageKeys(conversationKey, payloadData['nonce']!);
    var calculatedMac = hmacAad(
        keys['hmac_key']!, payloadData['ciphertext']!, payloadData['nonce']!);
    if (!listEquals(calculatedMac, payloadData['mac']!)) {
      throw Exception('Invalid MAC');
    }
    var padded = await chacha20Decrypt(
        keys['chacha_key']!, keys['chacha_nonce']!, payloadData['ciphertext']!);
    return unpad(padded);
  }

  static Uint8List shareSecret(String privateString, String publicString) {
    final secretIV = Kepler.byteSecret(privateString, '02$publicString');
    final key = Uint8List.fromList(secretIV[0]);
    final salt = Uint8List.fromList(utf8.encode('nip44-v2'));
    return hkdfExtract(salt, key);
  }
}
