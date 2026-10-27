import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

class NIP04 {
  static var secp256k1 = ECDomainParameters("secp256k1");

  static ECDHBasicAgreement getAgreement(String sk) {
    var skD0 = BigInt.parse(sk, radix: 16);
    var privateKey = ECPrivateKey(skD0, secp256k1);

    var agreement = ECDHBasicAgreement();
    agreement.init(privateKey);

    return agreement;
  }

  /// Encrypts [message] for [pk] as a NIP-04 `<ciphertext>?iv=<iv>` payload.
  ///
  /// Throws a [FormatException] when [pk] is not a public key.
  static String encrypt(
    String message,
    ECDHBasicAgreement agreement,
    String pk,
  ) {
    var pubkey = getPubkey(pk);
    var agreementD0 = agreement.calculateAgreement(pubkey);
    var enctyptKey = agreementD0.toRadixString(16).padLeft(64, "0");

    final random = Random.secure();
    var ivData = Uint8List.fromList(
      List<int>.generate(16, (i) => random.nextInt(256)),
    );
    // var iv = "UeAMaJl5Hj6IZcot7zLfmQ==";
    // var ivData = base64.decode(iv);

    final cipherCbc = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    final paramsCbc = PaddedBlockCipherParameters(
      ParametersWithIV(
        KeyParameter(Uint8List.fromList(hex.decode(enctyptKey))),
        ivData,
      ),
      null,
    );
    cipherCbc.init(true, paramsCbc);

    // print(cipherCbc.algorithmName);

    var result = cipherCbc.process(Uint8List.fromList(utf8.encode(message)));

    return "${base64.encode(result)}?iv=${base64.encode(ivData)}";
  }

  /// Decrypts [message], a NIP-04 `<ciphertext>?iv=<iv>` payload.
  ///
  /// Throws a [FormatException] when [message] is not a payload that can be
  /// decrypted, does not decrypt under this key, or [pk] is not a public key,
  /// so a failure is never mistaken for a message that decrypted to an empty
  /// string (#8712).
  static String decrypt(
    String message,
    ECDHBasicAgreement agreement,
    String pk,
  ) {
    var payload = _parsePayload(message);
    if (payload == null) {
      throw const FormatException(
        "Not a NIP-04 payload: expected <ciphertext>?iv=<iv>",
      );
    }
    var ivData = payload.iv;

    var pubkey = getPubkey(pk);
    var agreementD0 = agreement.calculateAgreement(pubkey);
    var encryptKey = agreementD0.toRadixString(16).padLeft(64, "0");

    // var encrypter = Encrypter(AES(
    //     Key(Uint8List.fromList(hex.decode(encryptKey))),
    //     mode: AESMode.cbc));
    // return encrypter.decrypt(Encrypted.from64(message), iv: IV.fromBase64(iv));

    final cipherCbc = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    final paramsCbc = PaddedBlockCipherParameters(
      ParametersWithIV(
        KeyParameter(Uint8List.fromList(hex.decode(encryptKey))),
        ivData,
      ),
      null,
    );
    cipherCbc.init(false, paramsCbc);

    Uint8List result;
    try {
      result = cipherCbc.process(payload.ciphertext);
    } on ArgumentError {
      // The payload's shape is already checked, so this is padding that does
      // not check out: it was encrypted to a different key.
      throw const FormatException(
        "NIP-04 payload does not decrypt under this key",
      );
    }

    return utf8.decode(result);
  }

  /// The ciphertext and IV of a NIP-04 payload, or `null` when [payload] has
  /// anything other than one `?iv=`, a 16-byte IV, and ciphertext made of
  /// whole AES blocks. The cipher reports those as raw [Error]s otherwise.
  static ({Uint8List ciphertext, Uint8List iv})? _parsePayload(String payload) {
    var parts = payload.split("?iv=");
    if (parts.length != 2) {
      return null;
    }
    var ciphertext = _decodeBase64(parts[0]);
    var iv = _decodeBase64(parts[1]);
    if (ciphertext == null ||
        iv == null ||
        iv.length != _aesBlockSize ||
        ciphertext.isEmpty ||
        ciphertext.length % _aesBlockSize != 0) {
      return null;
    }
    return (ciphertext: ciphertext, iv: iv);
  }

  /// [text] read as base64 the way lenient decoders read it: ASCII
  /// whitespace, such as the line breaks of wrapped output, is skipped and
  /// missing `=` padding is restored. `null` when it is not base64 even so.
  static Uint8List? _decodeBase64(String text) {
    var compact = text.replaceAll(_asciiWhitespace, "");
    try {
      return base64.decode(
        compact.padRight((compact.length + 3) ~/ 4 * 4, "="),
      );
    } on FormatException {
      return null;
    }
  }

  static final _asciiWhitespace = RegExp(r"[\t\n\v\f\r ]");

  static const _aesBlockSize = 16;

  /// The secp256k1 point for the x-only public key [pk].
  ///
  /// Throws a [FormatException] when [pk] is not a public key: not hex, or an
  /// x that no point on the curve has.
  static ECPublicKey getPubkey(String pk) {
    // BigInt x = BigInt.parse(pk, radix: 16);
    BigInt x = BigInt.parse(
      hex.encode(hex.decode(pk.padLeft(64, '0'))),
      radix: 16,
    );
    BigInt y;
    try {
      y = liftX(x);
    } on Error {
      throw const FormatException("Not a public key on secp256k1");
    }
    ECPoint endPoint = secp256k1.curve.createPoint(x, y);
    return ECPublicKey(endPoint, secp256k1);
  }

  static var curveP = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
    radix: 16,
  );

  // helper methods:
  // liftX returns Y for this X
  static BigInt liftX(BigInt x) {
    if (x >= curveP) {
      throw Error();
    }
    var ySq = (x.modPow(BigInt.from(3), curveP) + BigInt.from(7)) % curveP;
    var y = ySq.modPow((curveP + BigInt.one) ~/ BigInt.from(4), curveP);
    if (y.modPow(BigInt.two, curveP) != ySq) {
      throw Error();
    }
    return y % BigInt.two == BigInt.zero /* even */ ? y : curveP - y;
  }

  static String generate16RandomHexChars() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(16, (i) => random.nextInt(256));
    return hex.encode(randomBytes);
  }

  static bool isEncrypted(String text) {
    return text.indexOf("?iv=") > 0;
  }

  /// Whether [payload] has the shape [decrypt] can work on: one `?iv=`, a
  /// 16-byte IV, and ciphertext made of whole AES blocks.
  ///
  /// Stricter than [isEncrypted], which only spots the marker. A payload that
  /// fails this check is not one [decrypt] can read under any key.
  static bool isWellFormedPayload(String payload) =>
      _parsePayload(payload) != null;
}
