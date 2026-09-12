import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:kepler/kepler.dart';
import 'package:pointycastle/export.dart';

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
    Uint8List conversationKey,
    Uint8List nonce,
  ) {
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

  /// NIP-44's `extended_prefix_threshold`. A plaintext of this length or more
  /// is prefixed with 6 bytes (two zero bytes + a u32) instead of a u16.
  static const int extendedPrefixThreshold = 65536;

  /// Largest plaintext accepted when DECRYPTING.
  ///
  /// NIP-44 permits 2^32 - 1 but asks implementations to enforce their own
  /// ceiling and reject oversized payloads before base64 decoding, since
  /// decryption needs several times the payload in working memory. 1 MiB is
  /// far above anything this app sends and stays safe on low-end devices.
  static const int maxDecryptPlaintextSize = 1024 * 1024;

  /// Largest plaintext expressible with the 2-byte u16 length prefix.
  ///
  /// A caller that never produces the extended form — anything encrypting
  /// once, rather than through NIP-17's two layers — can pass this to
  /// [decodePayload] to keep its cheap pre-decode rejection tight.
  static const int maxU16PlaintextSize = 65535;

  /// version(1) + nonce(32) + mac(32).
  static const int _payloadOverhead = 65;

  /// Raw payload size for [plaintextSize], using the prefix form that size
  /// actually takes.
  ///
  /// The prefix must be chosen by size, not fixed at 6: a bound derived for
  /// [maxU16PlaintextSize] with a 6-byte prefix is four bytes too generous and
  /// admits the smallest extended-prefix payload, which is exactly what a
  /// u16-only caller is trying to exclude.
  static int _payloadBytesFor(int plaintextSize) =>
      _payloadOverhead +
      (plaintextSize >= extendedPrefixThreshold ? 6 : 2) +
      calcPaddedLen(plaintextSize);

  static int _payloadCharsFor(int payloadBytes) =>
      ((payloadBytes + 2) ~/ 3) * 4;

  static Uint8List writeU16BE(int num) {
    if (num < 1 || num > 65535) {
      throw Exception(
        'NIP-44 plaintext of $num bytes does not fit the 2-byte u16 length '
        'prefix (1..65535); this implementation does not emit the 6-byte '
        'extended prefix',
      );
    }
    var buffer = ByteData(2);
    buffer.setUint16(0, num, Endian.big);
    return buffer.buffer.asUint8List();
  }

  /// Pads [plaintext] using the 2-byte u16 length prefix only.
  ///
  /// NIP-44 also defines a 6-byte extended prefix for plaintext at or above
  /// [extendedPrefixThreshold], and [unpad] reads it — but this side
  /// deliberately does not emit it. A payload written with the extended
  /// prefix is undecryptable by any u16-only peer, which today includes the
  /// Rust `nostr` crate that keycast's server-side NIP-17 wrap/unwrap uses.
  /// Emitting one would turn a visible send failure into a silent
  /// non-delivery, and NIP-44 offers no way to detect recipient support.
  static Uint8List pad(String plaintext) {
    var unpadded = utf8.encode(plaintext);
    var unpaddedLen = unpadded.length;
    var prefix = writeU16BE(unpaddedLen);
    var suffix = Uint8List(calcPaddedLen(unpaddedLen) - unpaddedLen);
    return Uint8List.fromList(prefix + unpadded + suffix);
  }

  /// Reads both NIP-44 length-prefix forms: the 2-byte u16, and the 6-byte
  /// extended prefix (two zero bytes + u32) for plaintext at or above
  /// [extendedPrefixThreshold].
  ///
  /// A leading u16 of zero signals the extended form; because valid plaintext
  /// is at least one byte, that value is otherwise invalid. The declared u32
  /// is then required to be at or above the threshold, so a small length
  /// written in the 6-byte form is rejected rather than silently accepted.
  static String unpad(Uint8List padded) {
    // Validate the declared length against the buffer BEFORE slicing.
    // A forged payload can declare an unpaddedLen larger than the buffer;
    // slicing first would throw an uncontrolled RangeError instead of a
    // clean rejection. NIP-44 requires invalid payloads to be rejected.
    if (padded.length < 2) {
      throw Exception('Invalid padding');
    }
    final firstTwo = ByteData.sublistView(
      padded,
      0,
      2,
    ).getUint16(0, Endian.big);

    final int unpaddedLen;
    final int prefixLen;
    if (firstTwo == 0) {
      if (padded.length < 6) {
        throw Exception('Invalid padding');
      }
      unpaddedLen = ByteData.sublistView(padded, 2, 6).getUint32(0, Endian.big);
      if (unpaddedLen < extendedPrefixThreshold) {
        throw Exception('Invalid padding');
      }
      prefixLen = 6;
    } else {
      unpaddedLen = firstTwo;
      prefixLen = 2;
    }

    if (prefixLen + unpaddedLen > padded.length ||
        padded.length != prefixLen + calcPaddedLen(unpaddedLen)) {
      throw Exception('Invalid padding');
    }
    var unpadded = padded.sublist(prefixLen, prefixLen + unpaddedLen);
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

  /// Decodes a NIP-44 v2 payload envelope.
  ///
  /// [maxPlaintextSize] bounds what this call will accept, defaulting to
  /// [maxDecryptPlaintextSize]. The oversize check runs BEFORE base64
  /// decoding, which NIP-44 asks for explicitly so an oversized payload costs
  /// a length comparison rather than a decode. A caller that only ever sees
  /// single-encryption payloads — or that is merely classifying a payload's
  /// shape rather than decrypting it — should pass [maxU16PlaintextSize] so it
  /// does not pay for a ceiling it cannot reach.
  static Map<String, Uint8List> decodePayload(
    String payload, {
    int? maxPlaintextSize,
  }) {
    final maxPayloadBytes = _payloadBytesFor(
      maxPlaintextSize ?? maxDecryptPlaintextSize,
    );
    final maxPayloadChars = _payloadCharsFor(maxPayloadBytes);
    if (payload.length < 132 || payload.length > maxPayloadChars) {
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

    if (data.length < 99 || data.length > maxPayloadBytes) {
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
    Uint8List key,
    Uint8List nonce,
    Uint8List data,
  ) async {
    final algorithm = cryptography.Chacha20(
      macAlgorithm: cryptography.MacAlgorithm.empty,
    );
    // Encrypt
    final secretBox = await algorithm.encrypt(
      data,
      secretKey: cryptography.SecretKey(key),
      nonce: nonce,
    );

    return Uint8List.fromList(secretBox.cipherText);
  }

  static Future<Uint8List> chacha20Decrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
  ) async {
    final algorithm = cryptography.Chacha20(
      macAlgorithm: cryptography.MacAlgorithm.empty,
    );
    cryptography.SecretBox secretBox = cryptography.SecretBox(
      ciphertext,
      nonce: nonce,
      mac: cryptography.Mac.empty,
    );
    // Encrypt
    final result = await algorithm.decrypt(
      secretBox,
      secretKey: cryptography.SecretKey(key),
    );

    return Uint8List.fromList(result);
  }

  /// Constant-time byte comparison, required by NIP-44 decrypt step 5
  /// ("Use constant-time comparison algorithm"). Unlike [listEquals], this
  /// does not early-return on the first mismatching byte, so it does not
  /// leak — via timing — how many leading bytes of a forged MAC matched.
  /// Both inputs are fixed-length (the MAC is always 32 bytes), so the
  /// length check is not secret-dependent.
  static bool constantTimeBytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Future<String> encrypt(
    String plaintext,
    Uint8List conversationKey, [
    Uint8List? nonce,
  ]) async {
    nonce ??= randomBytes(32);
    var keys = getMessageKeys(conversationKey, nonce);
    var padded = pad(plaintext);
    var ciphertext = await chacha20Encrypt(
      keys['chacha_key']!,
      keys['chacha_nonce']!,
      padded,
    );
    var mac = hmacAad(keys['hmac_key']!, ciphertext, nonce);
    return base64Encode(Uint8List.fromList([2] + nonce + ciphertext + mac));
  }

  static Future<String> decrypt(
    String payload,
    Uint8List conversationKey, {
    int? maxPlaintextSize,
  }) async {
    var payloadData = decodePayload(
      payload,
      maxPlaintextSize: maxPlaintextSize,
    );
    var keys = getMessageKeys(conversationKey, payloadData['nonce']!);
    var calculatedMac = hmacAad(
      keys['hmac_key']!,
      payloadData['ciphertext']!,
      payloadData['nonce']!,
    );
    if (!constantTimeBytesEqual(calculatedMac, payloadData['mac']!)) {
      throw Exception('Invalid MAC');
    }
    var padded = await chacha20Decrypt(
      keys['chacha_key']!,
      keys['chacha_nonce']!,
      payloadData['ciphertext']!,
    );
    return unpad(padded);
  }

  static Uint8List shareSecret(String privateString, String publicString) {
    final secretIV = Kepler.byteSecret(privateString, '02$publicString');
    final key = Uint8List.fromList(secretIV[0]);
    final salt = Uint8List.fromList(utf8.encode('nip44-v2'));
    return hkdfExtract(salt, key);
  }
}
