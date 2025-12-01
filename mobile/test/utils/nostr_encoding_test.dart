// ABOUTME: Tests for Nostr key encoding/decoding using nostr_sdk's Nip19 implementation
// ABOUTME: Validates npub/nsec encoding, hex validation, and public key derivation from private keys

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('Nostr Key Operations via nostr_sdk', () {
    group('derivePublicKey', () {
      test('derives correct public key from valid private key', () {
        // Known test keypair (verified output from secp256k1 implementation)
        const privateKey =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        const expectedPublicKey =
            '7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e';

        final publicKey = getPublicKey(privateKey);

        expect(publicKey, expectedPublicKey);
        expect(publicKey.length, 64);
        expect(_isValidHexKey(publicKey), true);
      });

      test('derives consistent public key for same private key', () {
        const privateKey =
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

        final publicKey1 = getPublicKey(privateKey);
        final publicKey2 = getPublicKey(privateKey);

        expect(publicKey1, publicKey2);
      });

      test('throws exception for invalid private key format', () {
        expect(() => getPublicKey('invalid'), throwsA(anything));
      });

      test('throws exception for wrong length private key', () {
        expect(() => getPublicKey('1234567890abcdef'), throwsA(anything));
      });

      test('throws exception for non-hex private key', () {
        expect(
          () => getPublicKey(
            'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
          ),
          throwsA(anything),
        );
      });

      test('handles uppercase hex private keys', () {
        const privateKeyLower =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        const privateKeyUpper =
            '67DEA2ED018072D675F5415ECFAED7D2597555E202D85B3D65EA4E58D2D92FFA';

        final publicKey1 = getPublicKey(privateKeyLower);
        final publicKey2 = getPublicKey(privateKeyUpper);

        expect(publicKey1, publicKey2);
      });
    });

    group('Public/Private key encoding/decoding', () {
      test('encodes and decodes public key correctly', () {
        const hexPubkey =
            'd6c71059a1bd2c12514f7c31a8e5e5788b8e9e3c4f9b9c6e3c8f5a6e9b8c7d6e';

        final npub = Nip19.encodePubKey(hexPubkey);
        final decoded = Nip19.decode(npub);

        expect(decoded, hexPubkey);
        expect(npub.startsWith('npub1'), true);
      });

      test('encodes and decodes private key correctly', () {
        const hexPrivkey =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';

        final nsec = Nip19.encodePrivateKey(hexPrivkey);
        final decoded = Nip19.decode(nsec);

        expect(decoded, hexPrivkey);
        expect(nsec.startsWith('nsec1'), true);
      });
    });

    group('Key validation', () {
      test('validates valid hex keys', () {
        expect(
          _isValidHexKey(
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa',
          ),
          true,
        );
      });

      test('rejects invalid hex keys', () {
        expect(_isValidHexKey('invalid'), false);
        expect(_isValidHexKey('1234'), false);
        expect(
          _isValidHexKey(
            'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
          ),
          false,
        );
      });

      test('validates valid npub keys', () {
        const hexPubkey =
            'd6c71059a1bd2c12514f7c31a8e5e5788b8e9e3c4f9b9c6e3c8f5a6e9b8c7d6e';
        final npub = Nip19.encodePubKey(hexPubkey);

        expect(Nip19.isPubkey(npub), true);
      });

      test('validates valid nsec keys', () {
        const hexPrivkey =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        final nsec = Nip19.encodePrivateKey(hexPrivkey);

        expect(Nip19.isPrivateKey(nsec), true);
      });

      test('rejects invalid bech32 keys', () {
        expect(Nip19.isPubkey('invalid'), false);
        expect(Nip19.isPrivateKey('invalid'), false);
        expect(Nip19.isPubkey('nsec1abc'), false);
        expect(Nip19.isPrivateKey('npub1abc'), false);
      });
    });

    group('Key masking', () {
      test('masks long keys correctly', () {
        const key = 'npub1abcdefghijklmnopqrstuvwxyz1234567890';
        final masked = _maskKey(key);

        expect(masked, 'npub1abc...7890');
        expect(masked.length, 15);
      });

      test('does not mask short keys', () {
        const key = 'short';
        final masked = _maskKey(key);

        expect(masked, key);
      });

      test('masks hex pubkeys correctly', () {
        const hexKey =
            '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
        final masked = _maskKey(hexKey);

        expect(masked, '67dea2ed...2ffa');
      });
    });
  });
}

/// Validate if a string is a valid hex key (32 bytes = 64 hex chars)
bool _isValidHexKey(String hexKey) {
  if (hexKey.length != 64) return false;

  // Check if all characters are valid hex
  final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
  return hexRegex.hasMatch(hexKey);
}

/// Mask a key for display purposes (show first 8 and last 4 characters)
String _maskKey(String key) {
  if (key.length < 12) return key;

  final start = key.substring(0, 8);
  final end = key.substring(key.length - 4);
  return '$start...$end';
}
