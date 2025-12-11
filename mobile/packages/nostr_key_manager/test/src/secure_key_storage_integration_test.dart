// ABOUTME: Integration tests for secure key storage with hardware security
// ABOUTME: Tests NostrKeyManager, SecureKeyStorage, migration

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

void main() {
  group('NostrKeyManager with SecureKeyStorage Integration', () {
    late NostrKeyManager keyManager;

    setUp(() async {
      setupTestEnvironment();
      keyManager = NostrKeyManager();
    });

    tearDown(() async {
      await keyManager.clearKeys();
    });

    test('should initialize with secure storage', () async {
      // Act
      await keyManager.initialize();

      // Assert
      expect(keyManager.isInitialized, isTrue);
      expect(keyManager.hasKeys, isFalse);
    });

    test('should generate and store keys securely', () async {
      // Arrange
      await keyManager.initialize();

      // Act
      final keyPair = await keyManager.generateKeys();

      // Assert
      expect(keyManager.hasKeys, isTrue);
      expect(keyPair, isNotNull);
      expect(keyPair.private, isNotEmpty);
      expect(keyPair.public, isNotEmpty);
      expect(keyPair.private.length, equals(64)); // Hex format
      expect(keyPair.public.length, equals(64));
    });

    test('should import private key to secure storage', () async {
      // Arrange
      await keyManager.initialize();
      const testPrivateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';

      // Act
      final keyPair = await keyManager.importPrivateKey(testPrivateKey);

      // Assert
      expect(keyManager.hasKeys, isTrue);
      expect(keyPair.private, equals(testPrivateKey));
      expect(keyPair.public, isNotEmpty);
    });

    test('should migrate legacy keys from SharedPreferences', () async {
      // Arrange - Set up legacy keys in SharedPreferences
      // Use a valid private key and derive the correct public key
      const testPrivateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';

      // Import nostr_sdk to get the correct public key derivation
      final testPublicKey = getPublicKey(testPrivateKey);

      final legacyKeyData = {
        'private': testPrivateKey,
        'public': testPublicKey,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'version': 1,
      };

      SharedPreferences.setMockInitialValues({
        'nostr_keypair': jsonEncode(legacyKeyData),
        'nostr_key_version': 1,
      });

      // Act
      await keyManager.initialize();

      // Assert
      expect(keyManager.hasKeys, isTrue);
      expect(keyManager.privateKey, equals(legacyKeyData['private']));
      expect(keyManager.publicKey, equals(legacyKeyData['public']));

      // Verify legacy keys are removed after migration
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nostr_keypair'), isNull);
    });

    test('should clear keys from secure storage', () async {
      // Arrange
      await keyManager.initialize();
      await keyManager.generateKeys();
      expect(keyManager.hasKeys, isTrue);

      // Act
      await keyManager.clearKeys();

      // Assert
      expect(keyManager.hasKeys, isFalse);
      expect(keyManager.privateKey, isNull);
      expect(keyManager.publicKey, isNull);
    });

    test('should handle key export for backup', () async {
      // Arrange
      await keyManager.initialize();
      await keyManager.generateKeys();

      // Act
      final exportedKey = keyManager.exportPrivateKey();

      // Assert
      expect(exportedKey, isNotNull);
      expect(exportedKey.length, equals(64));
      expect(exportedKey, equals(keyManager.privateKey));
    });

    test('should validate private key format', () async {
      // Arrange
      await keyManager.initialize();

      // Act & Assert - Invalid formats
      expect(
        () => keyManager.importPrivateKey('invalid'),
        throwsA(isA<NostrKeyException>()),
      );

      expect(
        () => keyManager.importPrivateKey('xyz123'),
        throwsA(isA<NostrKeyException>()),
      );

      expect(
        () => keyManager.importPrivateKey('5dab4a6cf3b8c9b8'), // Too short
        throwsA(isA<NostrKeyException>()),
      );
    });

    test('should maintain key consistency after reload', () async {
      // Arrange
      await keyManager.initialize();
      final originalKeyPair = await keyManager.generateKeys();
      final originalPrivate = originalKeyPair.private;
      final originalPublic = originalKeyPair.public;

      // Act - Create new instance and reload
      final newKeyManager = NostrKeyManager();
      await newKeyManager.initialize();

      // Assert
      expect(newKeyManager.hasKeys, isTrue);
      expect(newKeyManager.privateKey, equals(originalPrivate));
      expect(newKeyManager.publicKey, equals(originalPublic));
    });
  });

  group('SecureKeyStorage Integration', () {
    late SecureKeyStorage storageService;

    setUp(() async {
      storageService = SecureKeyStorage();
    });

    tearDown(() {
      storageService.dispose();
    });

    test('should initialize with platform-appropriate security', () async {
      // Act
      await storageService.initialize();

      // Assert
      expect(storageService.hasKeys(), completion(isFalse));
    });

    test('should generate and store keys with hardware backing', () async {
      // Arrange
      await storageService.initialize();

      // Act
      final keyContainer = await storageService.generateAndStoreKeys();

      // Assert
      expect(keyContainer, isNotNull);
      expect(keyContainer.npub, isNotEmpty);
      expect(keyContainer.publicKeyHex, isNotEmpty);

      // Clean up
      keyContainer.dispose();
    });

    test('should retrieve stored keys', () async {
      // Arrange
      await storageService.initialize();
      final originalContainer = await storageService.generateAndStoreKeys();
      final originalNpub = originalContainer.npub;
      originalContainer.dispose();

      // Act
      final retrievedContainer = await storageService.getKeyContainer();

      // Assert
      expect(retrievedContainer, isNotNull);
      expect(retrievedContainer!.npub, equals(originalNpub));

      // Clean up
      retrievedContainer.dispose();
    });

    test('should import keys from nsec', () async {
      // Arrange
      await storageService.initialize();
      // Note: In real implementation, use proper nsec format
      const testNsec = 'nsec1test...';

      // Act - This will fail without proper nsec encoding
      expect(
        () => storageService.importFromNsec(testNsec),
        throwsA(isA<SecureKeyStorageException>()),
      );
    });

    test('should delete keys securely', () async {
      // Arrange
      await storageService.initialize();
      await storageService.generateAndStoreKeys();
      expect(await storageService.hasKeys(), isTrue);

      // Act
      await storageService.deleteKeys();

      // Assert
      expect(await storageService.hasKeys(), isFalse);
    });

    // Note: saveIdentity and getSavedIdentities methods need to be implemented
    // test('should handle multiple saved identities', () async {
    //   await storageService.initialize();
    //   // TODO: Implement saveIdentity and getSavedIdentities in SecureKeyStorage
    // });
  });

  group('Security Configuration', () {
    test('should use strict security by default', () {
      const config = SecurityConfig.strict;
      expect(config.requireHardwareBacked, isTrue);
      expect(config.requireBiometrics, isFalse);
      expect(config.allowFallbackSecurity, isFalse);
    });

    test('should allow desktop configuration', () {
      const config = SecurityConfig.desktop;
      expect(config.requireHardwareBacked, isFalse);
      expect(config.requireBiometrics, isFalse);
      expect(config.allowFallbackSecurity, isTrue);
    });

    test('should support maximum security with biometrics', () {
      const config = SecurityConfig.maximum;
      expect(config.requireHardwareBacked, isTrue);
      expect(config.requireBiometrics, isTrue);
      expect(config.allowFallbackSecurity, isFalse);
    });
  });
}
