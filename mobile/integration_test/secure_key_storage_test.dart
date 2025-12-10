// ABOUTME: Integration test for secure key storage that runs on actual device/simulator
// ABOUTME: Tests the full NostrKeyManager and SecureKeyStorage implementation

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NostrKeyManager Integration Tests on Device', () {
    late NostrKeyManager keyManager;

    setUp(() async {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      keyManager = NostrKeyManager();
    });

    tearDown(() async {
      await keyManager.clearKeys();
    });

    testWidgets('should initialize and generate keys on device', (
      tester,
    ) async {
      // Initialize
      await keyManager.initialize();
      expect(keyManager.isInitialized, isTrue);
      expect(keyManager.hasKeys, isFalse);

      // Generate keys
      final keyPair = await keyManager.generateKeys();
      expect(keyPair, isNotNull);
      expect(keyPair.private.length, equals(64));
      expect(keyPair.public.length, equals(64));
      expect(keyManager.hasKeys, isTrue);

      // Verify persistence by creating new instance
      final newKeyManager = NostrKeyManager();
      await newKeyManager.initialize();
      expect(newKeyManager.hasKeys, isTrue);
      expect(newKeyManager.privateKey, equals(keyPair.private));
      expect(newKeyManager.publicKey, equals(keyPair.public));
    });

    testWidgets('should migrate legacy keys from SharedPreferences', (
      tester,
    ) async {
      // Set up legacy keys
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nostr_keypair', jsonEncode(legacyKeyData));
      await prefs.setInt('nostr_key_version', 1);

      // Initialize and verify migration
      await keyManager.initialize();
      expect(keyManager.hasKeys, isTrue);
      expect(keyManager.privateKey, equals(privateKey));

      // Verify legacy keys are removed
      expect(prefs.getString('nostr_keypair'), isNull);
    });

    testWidgets('should import and export keys', (tester) async {
      await keyManager.initialize();

      // Import key
      const testPrivateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';
      final imported = await keyManager.importPrivateKey(testPrivateKey);
      expect(imported.private, equals(testPrivateKey));
      expect(keyManager.hasKeys, isTrue);

      // Export key
      final exported = keyManager.exportPrivateKey();
      expect(exported, equals(testPrivateKey));
    });

    testWidgets('should clear keys properly', (tester) async {
      await keyManager.initialize();
      await keyManager.generateKeys();
      expect(keyManager.hasKeys, isTrue);

      await keyManager.clearKeys();
      expect(keyManager.hasKeys, isFalse);
      expect(keyManager.privateKey, isNull);
    });
  });

  group('SecureKeyStorage Integration Tests on Device', () {
    late SecureKeyStorage storageService;

    setUp(() async {
      storageService = SecureKeyStorage();
      await storageService.initialize();
    });

    tearDown(() {
      storageService.dispose();
    });

    testWidgets('should generate and store keys with platform security', (
      tester,
    ) async {
      // Generate keys
      final keyContainer = await storageService.generateAndStoreKeys();
      expect(keyContainer, isNotNull);
      expect(keyContainer.npub, isNotEmpty);
      expect(keyContainer.publicKeyHex.length, equals(64));
      keyContainer.dispose();

      // Verify persistence
      expect(await storageService.hasKeys(), isTrue);

      // Retrieve keys
      final retrieved = await storageService.getKeyContainer();
      expect(retrieved, isNotNull);
      expect(retrieved!.npub, isNotEmpty);
      retrieved.dispose();
    });

    testWidgets('should delete keys securely', (tester) async {
      // Generate and store keys
      final keyContainer = await storageService.generateAndStoreKeys();
      keyContainer.dispose();
      expect(await storageService.hasKeys(), isTrue);

      // Delete keys
      await storageService.deleteKeys();
      expect(await storageService.hasKeys(), isFalse);
    });
  });
}
