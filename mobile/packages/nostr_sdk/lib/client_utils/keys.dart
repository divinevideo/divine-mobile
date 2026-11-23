import 'dart:math';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:hex/hex.dart';
import 'package:string_validator/string_validator.dart';

import '../relay/native_schnorr_sign.dart';

bool _nativePublicKeyDeriverFailed = false;

/// Generates a random new secret key which is a 32-byte hexadecimal string.
String generatePrivateKey() => getRandomHexString();

/// Returns the BIP340 public key derived from [privateKey].
///
/// Throws an [ArgumentError] when [privateKey] is not 64 hex characters.
/// The error never carries [privateKey], so it is safe to log.
String getPublicKey(String privateKey) {
  if (!keyIsValid(privateKey)) {
    throw ArgumentError(
      'Invalid key (expected 64 hex characters)',
      'privateKey',
    );
  }
  if (!_nativePublicKeyDeriverFailed) {
    final nativeDerive = resolveNativePublicKeyDeriver();
    if (nativeDerive != null) {
      try {
        return nativeDerive(privateKey: privateKey);
      } on Object catch (_) {
        _nativePublicKeyDeriverFailed = true;
      }
    }
  }
  return schnorr.getPublicKey(privateKey);
}

/// Whether [key] is a a 32-byte hexadecimal string.
bool keyIsValid(String key) {
  return (isHexadecimal(key) && key.length == 64);
}

final BigInt _fieldPrime = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

/// Whether [publicKey] is the x coordinate of a point on secp256k1.
///
/// [keyIsValid] checks only shape, and about half of all 32-byte values have
/// no point on the curve, so no event can be signed by them and no NIP-44
/// conversation key derived for them. This is BIP-340 `lift_x` without
/// computing the point. Do not use it on private keys, which are scalars.
bool pubkeyIsOnCurve(String publicKey) {
  if (!keyIsValid(publicKey)) return false;
  final x = BigInt.parse(publicKey, radix: 16);
  if (x >= _fieldPrime) return false;
  final ySquared =
      (x.modPow(BigInt.from(3), _fieldPrime) + BigInt.from(7)) % _fieldPrime;
  final y = ySquared.modPow(
    (_fieldPrime + BigInt.one) ~/ BigInt.from(4),
    _fieldPrime,
  );
  return y.modPow(BigInt.two, _fieldPrime) == ySquared;
}

String getRandomHexString([int byteLength = 32]) {
  final Random random = Random.secure();
  var bytes = List<int>.generate(byteLength, (i) => random.nextInt(256));
  return HEX.encode(bytes);
}
