// ABOUTME: TDD tests for real PGP implementation in ProofMode key service
// ABOUTME: Tests real dart_pg integration replacing mock crypto implementation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProofModeKeyService - Real PGP Implementation', () {
    late ProofModeKeyService keyService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      keyService = ProofModeKeyService(secureStorage: MockSecureStorage());

      // Enable crypto for all tests

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

    group('Real PGP Key Generation', () {
      test('generates real PGP key pair with armored format', () async {
        final keyPair = await keyService.generateKeyPair();

        // Real PGP keys must NOT start with MOCK_
        expect(keyPair.publicKey, isNot(startsWith('MOCK_')));
        expect(keyPair.privateKey, isNot(startsWith('MOCK_')));

        // Should be armored PGP format
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

        // Fingerprint should be valid hex (uppercase)
        expect(keyPair.fingerprint, matches(RegExp(r'^[0-9A-F]+$')));
        expect(keyPair.fingerprint.length, greaterThanOrEqualTo(16));

        // Should have valid timestamp
        expect(keyPair.createdAt, isA<DateTime>());
        expect(
          keyPair.createdAt.isBefore(DateTime.now().add(Duration(seconds: 1))),
          isTrue,
        );
      });

      test('generates unique key pairs on each generation', () async {
        final keyPair1 = await keyService.generateKeyPair();
        await keyService.deleteKeys();
        final keyPair2 = await keyService.generateKeyPair();

        // Each generation should produce unique keys
        expect(keyPair1.publicKey, isNot(equals(keyPair2.publicKey)));
        expect(keyPair1.privateKey, isNot(equals(keyPair2.privateKey)));
        expect(keyPair1.fingerprint, isNot(equals(keyPair2.fingerprint)));
      });

      test('generates keys with proper PGP metadata', () async {
        final keyPair = await keyService.generateKeyPair();

        // Note: User ID is embedded in binary packet data, not visible in armored text
        // Just verify it's proper PGP armored format with substantial length
        expect(
          keyPair.publicKey,
          contains('-----BEGIN PGP PUBLIC KEY BLOCK-----'),
        );
        expect(
          keyPair.publicKey,
          contains('-----END PGP PUBLIC KEY BLOCK-----'),
        );

        // Keys should be substantial length (armored PGP is verbose)
        expect(keyPair.publicKey.length, greaterThan(500));
        expect(keyPair.privateKey.length, greaterThan(1000));
      });
    });

    group('Real PGP Signing', () {
      test('signs data with real PGP signature', () async {
        await keyService.generateKeyPair();
        const testData = 'authentic video proof data';

        final signature = await keyService.signData(testData);

        expect(signature, isNotNull);
        // Real PGP signature should NOT start with MOCK_SIG_
        expect(signature!.signature, isNot(startsWith('MOCK_SIG_')));

        // Should be armored PGP signature format
        expect(signature.signature, contains('-----BEGIN PGP SIGNATURE-----'));
        expect(signature.signature, contains('-----END PGP SIGNATURE-----'));

        // Should have valid metadata
        expect(signature.publicKeyFingerprint, isNotEmpty);
        expect(signature.publicKeyFingerprint, matches(RegExp(r'^[0-9A-F]+$')));
        expect(signature.signedAt, isA<DateTime>());
      });

      test(
        'generates unique signatures each time (includes timestamp)',
        () async {
          await keyService.generateKeyPair();
          const testData = 'consistent test data';

          final signature1 = await keyService.signData(testData);
          await Future.delayed(
            Duration(milliseconds: 100),
          ); // Ensure different timestamp
          final signature2 = await keyService.signData(testData);

          // Real PGP signatures include timestamps, so they're unique each time
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

      test('generates different signatures for different data', () async {
        await keyService.generateKeyPair();

        final signature1 = await keyService.signData('data one');
        final signature2 = await keyService.signData('data two');

        // Different data should produce different signatures
        expect(signature1!.signature, isNot(equals(signature2!.signature)));

        // But same key fingerprint
        expect(
          signature1.publicKeyFingerprint,
          equals(signature2.publicKeyFingerprint),
        );
      });

      test('signature is substantial length', () async {
        await keyService.generateKeyPair();
        const testData = 'test';

        final signature = await keyService.signData(testData);

        // Real PGP signatures are verbose (armored format)
        expect(signature!.signature.length, greaterThan(200));
      });
    });

    group('Real PGP Verification', () {
      test('verifies valid PGP signature successfully', () async {
        await keyService.generateKeyPair();
        const testData = 'proof manifest data';

        final signature = await keyService.signData(testData);
        final isValid = await keyService.verifySignature(testData, signature!);

        expect(isValid, isTrue);
      });

      test('rejects signature for modified data', () async {
        await keyService.generateKeyPair();
        const originalData = 'original proof data';
        const tamperedData = 'tampered proof data';

        final signature = await keyService.signData(originalData);
        final isValid = await keyService.verifySignature(
          tamperedData,
          signature!,
        );

        // Tampering should be detected
        expect(isValid, isFalse);
      });

      test('rejects signature with wrong public key', () async {
        // Generate first key and sign
        await keyService.generateKeyPair();
        const testData = 'test data';
        final signature = await keyService.signData(testData);

        // Generate different key
        await keyService.deleteKeys();
        await keyService.generateKeyPair();

        // Verification should fail with different key
        final isValid = await keyService.verifySignature(testData, signature!);
        expect(isValid, isFalse);
      });

      test('rejects malformed signature', () async {
        await keyService.generateKeyPair();
        const testData = 'test data';

        // Create fake signature
        final fakeSignature = ProofSignature(
          signature: 'not a real signature',
          publicKeyFingerprint: 'FAKEFINGERPRINT',
          signedAt: DateTime.now(),
        );

        final isValid = await keyService.verifySignature(
          testData,
          fakeSignature,
        );
        expect(isValid, isFalse);
      });
    });

    group('Real PGP Storage Integration', () {
      test('real PGP keys serialize and deserialize correctly', () async {
        final originalKeyPair = await keyService.generateKeyPair();

        // Test JSON serialization roundtrip
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

        // Verify keys contain armored PGP format
        expect(
          deserializedKeyPair.publicKey,
          contains('-----BEGIN PGP PUBLIC KEY BLOCK-----'),
        );
        expect(
          deserializedKeyPair.privateKey,
          contains('-----BEGIN PGP PRIVATE KEY BLOCK-----'),
        );
      });
    });

    group('Real PGP Performance', () {
      test('generates keys in reasonable time', () async {
        final stopwatch = Stopwatch()..start();
        await keyService.generateKeyPair();
        stopwatch.stop();

        // Key generation should complete within 5 seconds
        // (Real RSA-4096 key gen can take 1-3 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('signs data in reasonable time', () async {
        await keyService.generateKeyPair();
        const testData = 'performance test data';

        final stopwatch = Stopwatch()..start();
        await keyService.signData(testData);
        stopwatch.stop();

        // Signing should be fast (< 500ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });

      test('verifies signature in reasonable time', () async {
        await keyService.generateKeyPair();
        const testData = 'verification performance test';
        final signature = await keyService.signData(testData);

        final stopwatch = Stopwatch()..start();
        await keyService.verifySignature(testData, signature!);
        stopwatch.stop();

        // Verification should be fast (< 500ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });
  });
}
