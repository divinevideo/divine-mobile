// ABOUTME: Tests for derivePublicKey implementation using nostr_sdk
// ABOUTME: Verifies public key derivation from private key using secp256k1

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  group('NostrEncoding.derivePublicKey', () {
    test('should derive public key from valid private key', () {
      // Known test keypair from Nostr test vectors
      const privateKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const expectedPublicKey =
          '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

      final publicKey = NostrEncoding.derivePublicKey(privateKey);

      expect(publicKey, equals(expectedPublicKey));
      expect(publicKey.length, equals(64));
      expect(NostrEncoding.isValidHexKey(publicKey), isTrue);
    });

    test('should derive consistent public key for same private key', () {
      // Use a valid private key within secp256k1 curve order
      const privateKey =
          'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140';

      final publicKey1 = NostrEncoding.derivePublicKey(privateKey);
      final publicKey2 = NostrEncoding.derivePublicKey(privateKey);

      expect(publicKey1, equals(publicKey2));
    });

    test('should throw on invalid private key format', () {
      expect(
        () => NostrEncoding.derivePublicKey('invalid'),
        throwsA(isA<NostrEncodingException>()),
      );

      expect(
        () => NostrEncoding.derivePublicKey('123'), // too short
        throwsA(isA<NostrEncodingException>()),
      );

      expect(
        () => NostrEncoding.derivePublicKey('g' * 64), // invalid hex
        throwsA(isA<NostrEncodingException>()),
      );
    });

    test('should work with uppercase and lowercase hex', () {
      const privateKeyLower =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const privateKeyUpper =
          '0000000000000000000000000000000000000000000000000000000000000001';

      final publicKey1 = NostrEncoding.derivePublicKey(privateKeyLower);
      final publicKey2 = NostrEncoding.derivePublicKey(privateKeyUpper);

      expect(publicKey1, equals(publicKey2));
    });

    test('should return different public keys for different private keys', () {
      const privateKey1 =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const privateKey2 =
          '0000000000000000000000000000000000000000000000000000000000000002';

      final publicKey1 = NostrEncoding.derivePublicKey(privateKey1);
      final publicKey2 = NostrEncoding.derivePublicKey(privateKey2);

      expect(publicKey1, isNot(equals(publicKey2)));
    });
  });
}
