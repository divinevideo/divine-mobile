// ABOUTME: Unit tests for NostrKeyManager with mocked secure storage
// ABOUTME: Tests key generation, storage, and migration without platform dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../test_setup.dart';

void main() {
  // Set up test environment with mocked platform channels
  setupTestEnvironment();

  group('NostrKeyManager Unit Tests', () {
    late NostrKeyManager keyManager;

    setUp(() async {
      // Clear any existing SharedPreferences
      SharedPreferences.setMockInitialValues({});
      keyManager = NostrKeyManager();
    });

    tearDown(() async {
      // Clean up
      await keyManager.clearKeys();
    });

    test('should initialize without keys', () async {
      // Act
      await keyManager.initialize();

      // Assert
      expect(keyManager.isInitialized, isTrue);
      expect(keyManager.hasKeys, isFalse);
      expect(keyManager.privateKey, isNull);
      expect(keyManager.publicKey, isNull);
    });

    test('should migrate legacy keys from SharedPreferences', () async {
      // Arrange - Set up legacy keys
      const privateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';
      const publicKey =
          '8c3d5cd6e977f6ad8e5e85029f3d3e00c7ae263849f2e44e9dd1dd66e4a45c13';

      final legacyKeyData = {
        'private': privateKey,
        'public': publicKey,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      };

      // Set up SharedPreferences with legacy data
      SharedPreferences.setMockInitialValues({
        'nostr_keypair': jsonEncode(legacyKeyData),
        'nostr_key_version': 1,
      });

      // Act
      await keyManager.initialize();

      // Assert
      expect(keyManager.hasKeys, isTrue);
      expect(keyManager.privateKey, equals(privateKey));

      // Verify legacy keys are cleaned up
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nostr_keypair'), isNull);
    });

    test('should validate private key format', () async {
      // Arrange
      await keyManager.initialize();

      // Act & Assert - Valid key
      const validKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';
      expect(() => keyManager.importPrivateKey(validKey), returnsNormally);

      // Invalid formats
      expect(
        () => keyManager.importPrivateKey('invalid'),
        throwsA(isA<NostrKeyException>()),
      );

      expect(
        () => keyManager.importPrivateKey('xyz123'),
        throwsA(isA<NostrKeyException>()),
      );

      expect(
        () => keyManager.importPrivateKey('5dab4a6c'), // Too short
        throwsA(isA<NostrKeyException>()),
      );
    });

    test('should export private key for backup', () async {
      // Arrange
      await keyManager.initialize();
      const testPrivateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';
      await keyManager.importPrivateKey(testPrivateKey);

      // Act
      final exportedKey = keyManager.exportPrivateKey();

      // Assert
      expect(exportedKey, equals(testPrivateKey));
    });

    test('should clear keys properly', () async {
      // Arrange
      await keyManager.initialize();
      const testPrivateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';
      await keyManager.importPrivateKey(testPrivateKey);
      expect(keyManager.hasKeys, isTrue);

      // Act
      await keyManager.clearKeys();

      // Assert
      expect(keyManager.hasKeys, isFalse);
      expect(keyManager.privateKey, isNull);
      expect(keyManager.publicKey, isNull);
    });

    test('should handle backup hash', () async {
      // Arrange
      await keyManager.initialize();

      // Act & Assert
      expect(keyManager.hasBackup, isFalse);

      // After creating backup, should have hash
      // Note: createMnemonicBackup needs a key first
      const testPrivateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';
      await keyManager.importPrivateKey(testPrivateKey);

      final mnemonic = await keyManager.createMnemonicBackup();
      expect(mnemonic, isNotEmpty);
      expect(keyManager.hasBackup, isTrue);
    });
  });

  group('Keychain', () {
    test('should generate valid key pair', () {
      // Act
      final keychain = Keychain.generate();

      // Assert
      expect(keychain.private, isNotEmpty);
      expect(keychain.public, isNotEmpty);
      expect(keychain.private.length, equals(64)); // Hex format
      expect(keychain.public.length, equals(64));

      // Should be different
      expect(keychain.private, isNot(equals(keychain.public)));
    });

    test('should derive public key from private key', () {
      // Arrange
      const privateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';

      // Act
      final keychain = Keychain(privateKey);

      // Assert
      expect(keychain.private, equals(privateKey));
      expect(keychain.public, isNotEmpty);
      expect(keychain.public.length, equals(64));
    });
  });

  group('NostrKeyException', () {
    test('should include message in toString', () {
      // Arrange
      const exception = NostrKeyException('Test error message');

      // Act & Assert
      expect(exception.toString(), contains('Test error message'));
    });
  });
}
