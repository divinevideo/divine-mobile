// ABOUTME: Tests for KeyUtils - nsec parsing and public key derivation
// ABOUTME: Verifies bech32 decoding, hex key handling, and pubkey generation

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/src/crypto/key_utils.dart';

void main() {
  group('KeyUtils', () {
    group('parseNsec', () {
      test('decodes valid nsec to hex private key', () {
        const nsec =
            'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
        final hex = KeyUtils.parseNsec(nsec);
        expect(hex, isNotNull);
        expect(hex!.length, 64);
        expect(hex, matches(RegExp(r'^[0-9a-f]+$')));
      });

      test('returns null for invalid nsec', () {
        expect(KeyUtils.parseNsec('invalid'), isNull);
        expect(KeyUtils.parseNsec('npub1abc'), isNull);
        expect(KeyUtils.parseNsec(''), isNull);
      });

      test('returns null for npub (wrong prefix)', () {
        const npub =
            'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
        expect(KeyUtils.parseNsec(npub), isNull);
      });

      test('returns null for a forged nsec HRP', () {
        const forgedNsec =
            'nsec1abc1vankwem8vankwem8vankwem8vankwem8vankwem8vankwem8vanspqs76t';

        expect(KeyUtils.parseNsec(forgedNsec), isNull);
      });

      test('decodes a uniformly uppercase nsec', () {
        const uppercaseNsec =
            'NSEC1VL029MGPSPEDVA04G90VLTKH6FVH240ZQTV9K0T9AF8935KE9LAQSNLFE5';

        expect(KeyUtils.parseNsec(uppercaseNsec), isNotNull);
      });
    });

    group('derivePublicKey', () {
      test('derives hex pubkey from hex private key', () {
        const privateKeyHex =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        final pubkey = KeyUtils.derivePublicKey(privateKeyHex);
        expect(pubkey, isNotNull);
        expect(pubkey!.length, 64);
        expect(pubkey, matches(RegExp(r'^[0-9a-f]+$')));
      });

      test('returns null for invalid private key', () {
        expect(KeyUtils.derivePublicKey('invalid'), isNull);
        expect(KeyUtils.derivePublicKey('1234'), isNull);
        expect(KeyUtils.derivePublicKey(''), isNull);
      });

      test('same private key produces same public key', () {
        const privateKeyHex =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        final pubkey1 = KeyUtils.derivePublicKey(privateKeyHex);
        final pubkey2 = KeyUtils.derivePublicKey(privateKeyHex);
        expect(pubkey1, equals(pubkey2));
      });
    });

    group('derivePublicKeyFromNsec', () {
      test('derives hex pubkey directly from nsec', () {
        const nsec =
            'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
        final pubkey = KeyUtils.derivePublicKeyFromNsec(nsec);
        expect(pubkey, isNotNull);
        expect(pubkey!.length, 64);
      });

      test('returns null for invalid nsec', () {
        expect(KeyUtils.derivePublicKeyFromNsec('invalid'), isNull);
      });
    });

    group('isValidHexKey', () {
      test('returns true for valid 64-char hex string', () {
        const validKey =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        expect(KeyUtils.isValidHexKey(validKey), isTrue);
      });

      test('returns false for wrong length', () {
        expect(KeyUtils.isValidHexKey('1234'), isFalse);
        expect(KeyUtils.isValidHexKey(''), isFalse);
      });

      test('returns false for non-hex characters', () {
        const invalidKey =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92fgx';
        expect(KeyUtils.isValidHexKey(invalidKey), isFalse);
      });
    });

    group('encodeToPubkey', () {
      test('encodes hex pubkey to npub format', () {
        const hexPubkey =
            '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
        final npub = KeyUtils.encodeToPubkey(hexPubkey);
        expect(npub, isNotNull);
        expect(npub, startsWith('npub1'));
      });

      test('returns null for invalid hex', () {
        expect(KeyUtils.encodeToPubkey('invalid'), isNull);
      });
    });
  });
}
