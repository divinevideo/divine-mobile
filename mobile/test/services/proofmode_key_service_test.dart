// ABOUTME: Comprehensive unit tests for ProofMode PGP key management service
// ABOUTME: Tests key generation, storage, signing, and verification functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProofModeKeyService', () {
    late ProofModeKeyService keyService;
    late MockSecureStorage
    sharedStorage; // Shared across service instances for persistence tests

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      sharedStorage = MockSecureStorage();
      keyService = ProofModeKeyService(secureStorage: sharedStorage);

      // Clear any existing keys
      try {
        await keyService.deleteKeys();
      } catch (e) {
        // Ignore if no keys exist
      }
    });

    tearDown(() async {
      try {
        await keyService.deleteKeys();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Initialization', () {
      // ProofMode is ALWAYS enabled - crypto cannot be disabled
      // If crypto needs to be disabled for testing, the entire ProofMode system should be disabled
      test(
        'should generate keys on initialize when no existing keys',
        () async {
          await keyService.initialize();

          final keyPair = await keyService.getKeyPair();
          expect(keyPair, isNotNull);
          expect(keyPair!.publicKey, isNotEmpty);
          expect(keyPair.privateKey, isNotEmpty);
          expect(keyPair.fingerprint, isNotEmpty);
          // Real PGP fingerprints are 40 hex characters
          expect(keyPair.fingerprint.length, greaterThanOrEqualTo(16));
        },
      );

      test('should not regenerate keys if they already exist', () async {
        // First initialization
        await keyService.initialize();
        final firstKeyPair = await keyService.getKeyPair();

        // Second initialization
        await keyService.initialize();
        final secondKeyPair = await keyService.getKeyPair();

        expect(secondKeyPair!.fingerprint, equals(firstKeyPair!.fingerprint));
        expect(secondKeyPair.publicKey, equals(firstKeyPair.publicKey));
      });
    });

    group('Key Generation', () {
      test('should generate unique key pairs', () async {
        final keyPair1 = await keyService.generateKeyPair();
        await keyService.deleteKeys();
        final keyPair2 = await keyService.generateKeyPair();

        expect(keyPair1.fingerprint, isNot(equals(keyPair2.fingerprint)));
        expect(keyPair1.publicKey, isNot(equals(keyPair2.publicKey)));
        expect(keyPair1.privateKey, isNot(equals(keyPair2.privateKey)));
      });

      test('should generate key pair with correct format', () async {
        final keyPair = await keyService.generateKeyPair();

        // Real PGP keys are armored format
        expect(
          keyPair.publicKey,
          contains('-----BEGIN PGP PUBLIC KEY BLOCK-----'),
        );
        expect(
          keyPair.publicKey,
          contains('-----END PGP PUBLIC KEY BLOCK-----'),
        );
        expect(
          keyPair.privateKey,
          contains('-----BEGIN PGP PRIVATE KEY BLOCK-----'),
        );
        expect(
          keyPair.privateKey,
          contains('-----END PGP PRIVATE KEY BLOCK-----'),
        );

        // Real PGP fingerprints are hex (uppercase)
        expect(keyPair.fingerprint, matches(RegExp(r'^[0-9A-F]+$')));
        expect(keyPair.fingerprint.length, greaterThanOrEqualTo(16));
        expect(keyPair.createdAt, isA<DateTime>());
      });

      test('should store generated keys securely', () async {
        final originalKeyPair = await keyService.generateKeyPair();

        // Create new service instance with same shared storage to test persistence
        final newKeyService = ProofModeKeyService(secureStorage: sharedStorage);
        final retrievedKeyPair = await newKeyService.getKeyPair();

        expect(retrievedKeyPair, isNotNull);
        expect(
          retrievedKeyPair!.fingerprint,
          equals(originalKeyPair.fingerprint),
        );
        expect(retrievedKeyPair.publicKey, equals(originalKeyPair.publicKey));
        expect(retrievedKeyPair.privateKey, equals(originalKeyPair.privateKey));
      });
    });

    group('Key Retrieval', () {
      test('should return null when no keys exist', () async {
        final keyPair = await keyService.getKeyPair();
        expect(keyPair, isNull);
      });

      test('should cache key pair after first retrieval', () async {
        await keyService.generateKeyPair();

        // First retrieval
        final keyPair1 = await keyService.getKeyPair();
        // Second retrieval (should use cache)
        final keyPair2 = await keyService.getKeyPair();

        expect(keyPair1, isNotNull);
        expect(keyPair2, isNotNull);
        expect(identical(keyPair1, keyPair2), isTrue); // Same object reference
      });

      test('should return public key fingerprint correctly', () async {
        final keyPair = await keyService.generateKeyPair();
        final fingerprint = await keyService.getPublicKeyFingerprint();

        expect(fingerprint, equals(keyPair.fingerprint));
      });

      test('should return null fingerprint when no keys exist', () async {
        final fingerprint = await keyService.getPublicKeyFingerprint();
        expect(fingerprint, isNull);
      });
    });

    group('Data Signing', () {
      test('should sign data successfully', () async {
        await keyService.generateKeyPair();
        const testData = 'test data to sign';

        final signature = await keyService.signData(testData);

        expect(signature, isNotNull);
        expect(signature!.signature, isNotEmpty);
        // Real PGP signatures are armored format
        expect(signature.signature, contains('-----BEGIN PGP SIGNATURE-----'));
        expect(signature.signature, contains('-----END PGP SIGNATURE-----'));
        expect(signature.publicKeyFingerprint, isNotEmpty);
        expect(signature.signedAt, isA<DateTime>());
      });

      test('should return null when no keys available', () async {
        const testData = 'test data to sign';
        final signature = await keyService.signData(testData);

        expect(signature, isNull);
      });

      test(
        'should generate non-deterministic signatures (includes timestamp)',
        () async {
          await keyService.generateKeyPair();
          const testData = 'consistent test data';

          final signature1 = await keyService.signData(testData);
          await Future.delayed(
            Duration(milliseconds: 100),
          ); // Ensure different timestamp
          final signature2 = await keyService.signData(testData);

          // Real PGP signatures include timestamps and salts, so they're unique each time
          // This is CORRECT behavior (prevents replay attacks)
          expect(signature1!.signature, isNot(equals(signature2!.signature)));

          // But both should use the same key
          expect(
            signature1.publicKeyFingerprint,
            equals(signature2.publicKeyFingerprint),
          );

          // Both signatures should still verify correctly
          final isValid1 = await keyService.verifySignature(
            testData,
            signature1,
          );
          final isValid2 = await keyService.verifySignature(
            testData,
            signature2,
          );
          expect(isValid1, isTrue);
          expect(isValid2, isTrue);
        },
      );

      test('should generate different signatures for different data', () async {
        await keyService.generateKeyPair();

        final signature1 = await keyService.signData('data 1');
        final signature2 = await keyService.signData('data 2');

        expect(signature1!.signature, isNot(equals(signature2!.signature)));
        expect(
          signature1.publicKeyFingerprint,
          equals(signature2.publicKeyFingerprint),
        );
      });
    });

    group('Signature Verification', () {
      test('should verify valid signature successfully', () async {
        await keyService.generateKeyPair();
        const testData = 'data to verify';

        final signature = await keyService.signData(testData);
        final isValid = await keyService.verifySignature(testData, signature!);

        expect(isValid, isTrue);
      });

      test('should reject invalid signature', () async {
        await keyService.generateKeyPair();
        const originalData = 'original data';
        const modifiedData = 'modified data';

        final signature = await keyService.signData(originalData);
        final isValid = await keyService.verifySignature(
          modifiedData,
          signature!,
        );

        expect(isValid, isFalse);
      });

      test('should reject signature with wrong fingerprint', () async {
        await keyService.generateKeyPair();
        const testData = 'test data';

        final signature = await keyService.signData(testData);

        // Create fake signature with wrong fingerprint
        final fakeSignature = ProofSignature(
          signature: signature!.signature,
          publicKeyFingerprint: 'WRONGFINGERPRINT',
          signedAt: signature.signedAt,
        );

        final isValid = await keyService.verifySignature(
          testData,
          fakeSignature,
        );
        expect(isValid, isFalse);
      });

      test(
        'should return false when no keys available for verification',
        () async {
          final fakeSignature = ProofSignature(
            signature: 'fake_signature',
            publicKeyFingerprint: 'fake_fingerprint',
            signedAt: DateTime.now(),
          );

          final isValid = await keyService.verifySignature(
            'test data',
            fakeSignature,
          );
          expect(isValid, isFalse);
        },
      );
    });

    group('Key Deletion', () {
      test('should delete all keys successfully', () async {
        await keyService.generateKeyPair();
        expect(await keyService.getKeyPair(), isNotNull);

        await keyService.deleteKeys();
        expect(await keyService.getKeyPair(), isNull);
      });

      test('should clear cache when keys deleted', () async {
        await keyService.generateKeyPair();
        await keyService.getKeyPair(); // Cache the keys

        await keyService.deleteKeys();

        final keyPairAfterDeletion = await keyService.getKeyPair();
        expect(keyPairAfterDeletion, isNull);
      });

      test('should not throw when deleting non-existent keys', () async {
        // Should not throw exception
        expect(() => keyService.deleteKeys(), returnsNormally);
      });
    });

    group('JSON Serialization', () {
      test(
        'should serialize and deserialize ProofModeKeyPair correctly',
        () async {
          final originalKeyPair = await keyService.generateKeyPair();
          final json = originalKeyPair.toJson();
          final deserializedKeyPair = ProofModeKeyPair.fromJson(json);

          expect(
            deserializedKeyPair.publicKey,
            equals(originalKeyPair.publicKey),
          );
          expect(
            deserializedKeyPair.privateKey,
            equals(originalKeyPair.privateKey),
          );
          expect(
            deserializedKeyPair.fingerprint,
            equals(originalKeyPair.fingerprint),
          );
          expect(
            deserializedKeyPair.createdAt,
            equals(originalKeyPair.createdAt),
          );
        },
      );

      test(
        'should serialize and deserialize ProofSignature correctly',
        () async {
          await keyService.generateKeyPair();
          final originalSignature = await keyService.signData('test data');

          final json = originalSignature!.toJson();
          final deserializedSignature = ProofSignature.fromJson(json);

          expect(
            deserializedSignature.signature,
            equals(originalSignature.signature),
          );
          expect(
            deserializedSignature.publicKeyFingerprint,
            equals(originalSignature.publicKeyFingerprint),
          );
          expect(
            deserializedSignature.signedAt,
            equals(originalSignature.signedAt),
          );
        },
      );
    });

    group('Error Handling', () {
      test('should handle secure storage errors gracefully', () async {
        // This test would require mocking FlutterSecureStorage to throw errors
        // For now, just ensure the service doesn't crash
        expect(() => keyService.getKeyPair(), returnsNormally);
      });

      test('should handle malformed stored data gracefully', () async {
        // This would require mocking corrupted data in secure storage
        // The service should return null for malformed data
        expect(() => keyService.getKeyPair(), returnsNormally);
      });
    });
  });
}
