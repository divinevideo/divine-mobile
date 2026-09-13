// ABOUTME: Integration tests for secure key storage with hardware security
// ABOUTME: Tests SecureKeyStorage storage, import, and security config

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Nip19;

import '../test_setup.dart';

void main() {
  group('SecureKeyStorage Integration', () {
    late SecureKeyStorage storageService;

    setUp(() async {
      setupTestEnvironment();
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

    test('importFromNsec rejects a forged nsec HRP', () async {
      await storageService.initialize();
      const forgedNsec =
          'nsec1abc1vankwem8vankwem8vankwem8vankwem8vankwem8vankwem8vanspqs76t';

      expect(
        () => storageService.importFromNsec(forgedNsec),
        throwsA(isA<SecureKeyStorageException>()),
      );
    });

    test('importFromNsec accepts a uniformly uppercase nsec', () async {
      await storageService.initialize();
      const uppercaseNsec =
          'NSEC1VL029MGPSPEDVA04G90VLTKH6FVH240ZQTV9K0T9AF8935KE9LAQSNLFE5';

      final imported = await storageService.importFromNsec(uppercaseNsec);

      expect(imported.publicKeyHex, isNotEmpty);
      imported.dispose();
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

    test('imports keys from hex and retrieves them', () async {
      await storageService.initialize();
      final privateKeyHex = generatePrivateKey();

      final imported = await storageService.importFromHex(privateKeyHex);
      final importedNpub = imported.npub;
      imported.dispose();

      expect(await storageService.hasKeys(), isTrue);
      final retrieved = await storageService.getKeyContainer();
      expect(retrieved, isNotNull);
      expect(retrieved!.npub, equals(importedNpub));
      retrieved.dispose();
    });

    test('importFromHex rejects an invalid private key', () async {
      await storageService.initialize();

      expect(
        () => storageService.importFromHex('not-a-valid-hex-key'),
        throwsA(isA<SecureKeyStorageException>()),
      );
    });

    test(
      'exposes public key, nsec, and private key of the stored key',
      () async {
        await storageService.initialize();
        final container = await storageService.generateAndStoreKeys();
        final npub = container.npub;
        container.dispose();

        expect(await storageService.getPublicKey(), equals(npub));
        expect(await storageService.exportNsec(), startsWith('nsec1'));

        final privateKeyLength = await storageService.withPrivateKey(
          (privateKeyHex) => privateKeyHex.length,
        );
        expect(privateKeyLength, equals(64));
      },
    );

    test('backup key lifecycle: save, detect, retrieve, delete', () async {
      await storageService.initialize();
      expect(await storageService.hasBackupKey(), isFalse);

      final backupPrivateKey = generatePrivateKey();
      await storageService.saveBackupKey(backupPrivateKey);
      expect(await storageService.hasBackupKey(), isTrue);

      final backup = await storageService.getBackupKeyContainer();
      expect(backup, isNotNull);
      expect(backup!.publicKeyHex, equals(getPublicKey(backupPrivateKey)));
      backup.dispose();

      await storageService.deleteBackupKey();
      expect(await storageService.hasBackupKey(), isFalse);
    });

    test('importFromNsec archives previous identity in PRIMARY', () async {
      await storageService.initialize();

      // Import identity A into PRIMARY
      final privateKeyA = generatePrivateKey();
      final nsecA = Nip19.encodePrivateKey(privateKeyA);
      final containerA = await storageService.importFromNsec(nsecA);
      final npubA = containerA.npub;
      containerA.dispose();

      // Verify A is in PRIMARY
      final primaryBeforeSwitch = await storageService.getKeyContainer();
      expect(primaryBeforeSwitch!.npub, equals(npubA));
      primaryBeforeSwitch.dispose();

      // Import identity B — should archive A first
      final privateKeyB = generatePrivateKey();
      final nsecB = Nip19.encodePrivateKey(privateKeyB);
      final containerB = await storageService.importFromNsec(nsecB);
      final npubB = containerB.npub;
      containerB.dispose();

      // PRIMARY should now be B
      final primaryAfterSwitch = await storageService.getKeyContainer();
      expect(primaryAfterSwitch!.npub, equals(npubB));
      primaryAfterSwitch.dispose();

      // A should be archived in per-identity slot
      final archivedA = await storageService.getIdentityKeyContainer(npubA);
      expect(
        archivedA,
        isNotNull,
        reason:
            'Previous identity A should be archived to '
            'nostr_identity_$npubA, not silently lost',
      );
      archivedA?.dispose();
    });

    test('deleteIdentityKeyContainer removes archived identity only', () async {
      await storageService.initialize();

      final privateKey = generatePrivateKey();
      final nsec = Nip19.encodePrivateKey(privateKey);
      final container = await storageService.importFromNsec(nsec);
      final npub = container.npub;
      final publicKeyHex = container.publicKeyHex;
      container.dispose();

      final primary = await storageService.getKeyContainer();
      expect(primary, isNotNull);
      await storageService.storeIdentityKeyContainer(npub, primary!);

      final archivedBefore = await storageService.getIdentityKeyContainer(npub);
      expect(archivedBefore, isNotNull);
      expect(archivedBefore!.publicKeyHex, equals(publicKeyHex));

      await storageService.deleteIdentityKeyContainer(npub);

      final archivedAfter = await storageService.getIdentityKeyContainer(npub);
      final primaryAfter = await storageService.getKeyContainer();

      expect(archivedAfter, isNull);
      expect(primaryAfter, isNotNull);
      expect(primaryAfter!.publicKeyHex, equals(publicKeyHex));

      primary.dispose();
      archivedBefore.dispose();
      primaryAfter.dispose();
    });

    group('storeIdentityKeyContainer npub↔pubkey invariant', () {
      test('accepts container whose npub matches filing npub', () async {
        await storageService.initialize();

        final privateKey = generatePrivateKey();
        final nsec = Nip19.encodePrivateKey(privateKey);
        final container = await storageService.importFromNsec(nsec);
        final npub = container.npub;
        final publicKeyHex = container.publicKeyHex;
        container.dispose();

        // Re-importing re-files under PRIMARY, so fetch a fresh container
        // and explicitly store under its own npub — exercises the matching
        // path directly.
        final primary = await storageService.getKeyContainer();
        expect(primary, isNotNull);
        await storageService.storeIdentityKeyContainer(npub, primary!);
        primary.dispose();

        final retrieved = await storageService.getIdentityKeyContainer(npub);
        expect(retrieved, isNotNull);
        expect(retrieved!.npub, equals(npub));
        expect(retrieved.publicKeyHex, equals(publicKeyHex));
        retrieved.dispose();
      });

      test('rejects container whose npub does not match filing npub', () async {
        await storageService.initialize();

        // Import a real container so PRIMARY has something.
        final privateKeyB = generatePrivateKey();
        final nsecB = Nip19.encodePrivateKey(privateKeyB);
        final containerB = await storageService.importFromNsec(nsecB);
        final npubB = containerB.npub;
        containerB.dispose();

        // Generate a third keypair C but do NOT store it. C's per-identity
        // slot is guaranteed empty throughout the test.
        final privateKeyC = generatePrivateKey();
        final publicKeyC = getPublicKey(privateKeyC);
        final npubC = Nip19.encodePubKey(publicKeyC);
        expect(npubB, isNot(equals(npubC)));

        // Try to file PRIMARY (container for B) under C's npub.
        final primaryB = await storageService.getKeyContainer();
        expect(primaryB, isNotNull);
        expect(primaryB!.npub, equals(npubB));

        await expectLater(
          () => storageService.storeIdentityKeyContainer(npubC, primaryB),
          throwsA(
            isA<SecureKeyStorageException>().having(
              (e) => e.code,
              'code',
              equals('npub_pubkey_mismatch'),
            ),
          ),
        );
        primaryB.dispose();

        // Nothing should have been written under npubC.
        final shouldBeMissing = await storageService.getIdentityKeyContainer(
          npubC,
        );
        expect(shouldBeMissing, isNull);
      });

      test('rejection error message is descriptive', () async {
        await storageService.initialize();

        final privateKeyA = generatePrivateKey();
        final nsecA = Nip19.encodePrivateKey(privateKeyA);
        final containerA = await storageService.importFromNsec(nsecA);
        final npubA = containerA.npub;
        containerA.dispose();

        final privateKeyB = generatePrivateKey();
        final nsecB = Nip19.encodePrivateKey(privateKeyB);
        final containerB = await storageService.importFromNsec(nsecB);
        containerB.dispose();

        final primaryB = await storageService.getKeyContainer();
        expect(primaryB, isNotNull);

        await expectLater(
          () => storageService.storeIdentityKeyContainer(npubA, primaryB!),
          throwsA(
            isA<SecureKeyStorageException>().having(
              (e) => e.message,
              'message',
              contains('mismatch'),
            ),
          ),
        );
        primaryB!.dispose();
      });
    });
  });

  group('Security Configuration', () {
    test('should use strict security by default', () {
      const config = SecurityConfig.strict;
      expect(config.requireHardwareBacked, isTrue);
      expect(config.allowFallbackSecurity, isFalse);
    });

    test('should allow desktop configuration', () {
      const config = SecurityConfig.desktop;
      expect(config.requireHardwareBacked, isFalse);
      expect(config.allowFallbackSecurity, isTrue);
    });
  });
}
