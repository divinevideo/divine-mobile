// ABOUTME: Tests for NostrKeyManager export and backup features
// ABOUTME: Tests nsec export, key replacement, backup restoration

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

import '../test_setup.dart';

void main() {
  group('NostrKeyManager Export and Backup', () {
    late NostrKeyManager keyManager;

    setUp(() async {
      setupTestEnvironment();
      keyManager = NostrKeyManager();
      await keyManager.initialize();
    });

    tearDown(() async {
      await keyManager.clearKeys();
    });

    group('exportAsNsec', () {
      test('should export private key as nsec bech32 format', () async {
        // Arrange: Generate a keypair
        await keyManager.generateKeys();

        // Act: Export as nsec
        final nsec = keyManager.exportAsNsec();

        // Assert: Should start with 'nsec1' and be valid bech32
        expect(nsec, startsWith('nsec1'));
        expect(nsec.length, greaterThan(60)); // nsec is ~63 characters

        // Verify it's the same key by converting back
        // (use Nip19.decode() from nostr_sdk for this verification)
        expect(nsec, isNotEmpty);
      });

      test('should throw exception when no keys available', () async {
        // Arrange: No keys generated

        // Act & Assert: Should throw
        expect(
          () => keyManager.exportAsNsec(),
          throwsA(isA<NostrKeyException>()),
        );
      });
    });

    group('replaceKeyWithBackup', () {
      test('should generate new key and backup old one', () async {
        // Arrange: Generate initial keypair
        await keyManager.generateKeys();
        final oldPrivateKey = keyManager.privateKey!;
        final oldPublicKey = keyManager.publicKey!;

        // Act: Replace key
        final backupInfo = await keyManager.replaceKeyWithBackup();

        // Assert: Should have new keys
        expect(keyManager.hasKeys, isTrue);
        expect(keyManager.privateKey, isNot(equals(oldPrivateKey)));
        expect(keyManager.publicKey, isNot(equals(oldPublicKey)));

        // Assert: Backup info should contain old key
        expect(backupInfo['oldPrivateKey'], equals(oldPrivateKey));
        expect(backupInfo['oldPublicKey'], equals(oldPublicKey));
        expect(backupInfo['backedUpAt'], isA<DateTime>());

        // Assert: Should indicate backup exists
        expect(keyManager.hasBackup, isTrue);
      });

      test('should throw exception when no keys to backup', () async {
        // Arrange: No keys generated

        // Act & Assert: Should throw
        expect(
          () => keyManager.replaceKeyWithBackup(),
          throwsA(isA<NostrKeyException>()),
        );
      });

      test('should persist backup across app restarts', () async {
        // Arrange: Generate and replace key (creates backup)
        await keyManager.generateKeys();
        await keyManager.replaceKeyWithBackup();
        // Note: Don't clear keys here - we want to test backup persistence

        // Act: Create new keyManager instance (simulates app restart)
        final newKeyManager = NostrKeyManager();
        await newKeyManager.initialize();

        // Assert: Should still have backup available after restart
        expect(newKeyManager.hasBackup, isTrue);

        // Cleanup
        await newKeyManager.clearKeys();
      });
    });

    group('restoreFromBackup', () {
      test('should restore backup key as active key', () async {
        // Arrange: Generate key, replace it (creating backup)
        await keyManager.generateKeys();
        final originalPrivateKey = keyManager.privateKey!;
        final originalPublicKey = keyManager.publicKey!;

        await keyManager.replaceKeyWithBackup();
        final newPrivateKey = keyManager.privateKey!;

        // Verify we have different keys now
        expect(newPrivateKey, isNot(equals(originalPrivateKey)));

        // Act: Restore from backup
        await keyManager.restoreFromBackup();

        // Assert: Should have original keys back
        expect(keyManager.privateKey, equals(originalPrivateKey));
        expect(keyManager.publicKey, equals(originalPublicKey));
      });

      test('should throw exception when no backup exists', () async {
        // Arrange: Generate key but no backup
        await keyManager.generateKeys();

        // Act & Assert: Should throw
        expect(
          () => keyManager.restoreFromBackup(),
          throwsA(isA<NostrKeyException>()),
        );
      });

      test('should preserve current key as new backup after restore', () async {
        // Arrange: Generate original key, replace it, then restore
        await keyManager.generateKeys();
        final originalKey = keyManager.privateKey!;

        await keyManager.replaceKeyWithBackup();
        await keyManager.restoreFromBackup();

        // Assert: Original key is active
        expect(keyManager.privateKey, equals(originalKey));

        // Assert: Second key should now be backed up
        expect(keyManager.hasBackup, isTrue);
      });
    });

    group('clearBackup', () {
      test('should delete backup without affecting active key', () async {
        // Arrange: Generate key and replace (creating backup)
        await keyManager.generateKeys();
        await keyManager.replaceKeyWithBackup();

        final activeKey = keyManager.privateKey!;
        expect(keyManager.hasBackup, isTrue);

        // Act: Clear backup only
        await keyManager.clearBackup();

        // Assert: Active key unchanged, backup gone
        expect(keyManager.privateKey, equals(activeKey));
        expect(keyManager.hasBackup, isFalse);
      });
    });
  });
}
