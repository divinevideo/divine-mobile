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

  static String encrypt(
      String message, ECDHBasicAgreement agreement, String pk) {
    var pubkey = getPubkey(pk);
    var agreementD0 = agreement.calculateAgreement(pubkey);
    var enctyptKey = agreementD0.toRadixString(16).padLeft(64, "0");

    final random = Random.secure();
    var ivData =
        Uint8List.fromList(List<int>.generate(16, (i) => random.nextInt(256)));
    // var iv = "UeAMaJl5Hj6IZcot7zLfmQ==";
    // var ivData = base64.decode(iv);

    final cipherCbc =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    final paramsCbc = PaddedBlockCipherParameters(
        ParametersWithIV(
            KeyParameter(Uint8List.fromList(hex.decode(enctyptKey))), ivData),
        null);
    cipherCbc.init(true, paramsCbc);

    // print(cipherCbc.algorithmName);

    var result = cipherCbc.process(Uint8List.fromList(utf8.encode(message)));

    return "${base64.encode(result)}?iv=${base64.encode(ivData)}";
  }

  static String decrypt(
      String message, ECDHBasicAgreement agreement, String pk) {
    var strs = message.split("?iv=");
    if (strs.length != 2) {
      return "";
    }
    message = strs[0];
    var iv = strs[1];
    var ivData = base64.decode(iv);

    var pubkey = getPubkey(pk);
    var agreementD0 = agreement.calculateAgreement(pubkey);
    var encryptKey = agreementD0.toRadixString(16).padLeft(64, "0");

    // var encrypter = Encrypter(AES(
    //     Key(Uint8List.fromList(hex.decode(encryptKey))),
    //     mode: AESMode.cbc));
    // return encrypter.decrypt(Encrypted.from64(message), iv: IV.fromBase64(iv));

    final cipherCbc =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    final paramsCbc = PaddedBlockCipherParameters(
        ParametersWithIV(
            KeyParameter(Uint8List.fromList(hex.decode(encryptKey))), ivData),
        null);
    cipherCbc.init(false, paramsCbc);

    var result = cipherCbc.process(base64.decode(message));

    return utf8.decode(result);
  }

  static ECPublicKey getPubkey(String pk) {
    // BigInt x = BigInt.parse(pk, radix: 16);
    BigInt x =
        BigInt.parse(hex.encode(hex.decode(pk.padLeft(64, '0'))), radix: 16);
    BigInt? y;
    try {
      y = liftX(x);
    } on Error {
      print("error in handle pubkey");
    }
    ECPoint endPoint = secp256k1.curve.createPoint(x, y!);
    return ECPublicKey(endPoint, secp256k1);
  }

  static var curveP = BigInt.parse(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
      radix: 16);

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
}
