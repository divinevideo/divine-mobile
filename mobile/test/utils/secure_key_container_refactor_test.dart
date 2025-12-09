// ABOUTME: Tests for SecureKeyContainer refactoring to use NostrEncoding.derivePublicKey
// ABOUTME: Ensures refactoring maintains existing behavior while eliminating duplication

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  group('SecureKeyContainer - Refactored Implementation', () {
    test('should derive correct public key from private key', () {
      // Known test keypair
      const privateKeyHex =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const expectedPublicKeyHex =
          '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);

      expect(container.publicKeyHex, equals(expectedPublicKeyHex));

      container.dispose();
    });

    test('should generate valid keys with generate()', () {
      final container = SecureKeyContainer.generate();

      // Verify the generated keys are valid
      expect(NostrEncoding.isValidHexKey(container.publicKeyHex), isTrue);
      expect(NostrEncoding.isValidNpub(container.npub), isTrue);

      // Verify we can use the private key
      container.withPrivateKey((privateKey) {
        expect(NostrEncoding.isValidHexKey(privateKey), isTrue);
        return null;
      });

      container.dispose();
    });

    test('should create container from nsec', () {
      const privateKeyHex =
          '0000000000000000000000000000000000000000000000000000000000000002';
      final nsec = NostrEncoding.encodePrivateKey(privateKeyHex);

      final container = SecureKeyContainer.fromNsec(nsec);

      expect(container.publicKeyHex, isNotEmpty);
      expect(container.publicKeyHex.length, equals(64));

      container.dispose();
    });

    test('should maintain consistency between hex and npub public keys', () {
      const privateKeyHex =
          '0000000000000000000000000000000000000000000000000000000000000003';

      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);

      // Decode npub and verify it matches publicKeyHex
      final decodedHex = NostrEncoding.decodePublicKey(container.npub);
      expect(decodedHex, equals(container.publicKeyHex));

      container.dispose();
    });

    test('should derive same public key as NostrEncoding.derivePublicKey', () {
      const privateKeyHex =
          '0000000000000000000000000000000000000000000000000000000000000004';

      // Derive using NostrEncoding directly
      final expectedPublicKey = NostrEncoding.derivePublicKey(privateKeyHex);

      // Derive using SecureKeyContainer
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final containerPublicKey = container.publicKeyHex;

      // Should be identical
      expect(containerPublicKey, equals(expectedPublicKey));

      container.dispose();
    });
  });
}
