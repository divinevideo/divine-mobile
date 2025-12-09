// ABOUTME: Unit tests for ProofMode integration with PendingUpload model
// ABOUTME: Tests serialization, deserialization, and helper methods for NativeProofData storage

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/native_proof_data.dart';

void main() {
  group('PendingUpload ProofMode Integration', () {
    late NativeProofData testProofData;
    late String testProofJson;

    setUp(() {
      // Create a test NativeProofData
      testProofData = const NativeProofData(
        videoHash:
            'abc123def456789012345678901234567890123456789012345678901234',
        sensorDataCsv:
            'timestamp,lat,lon\n2025-01-01T10:00:00,37.7749,-122.4194',
        pgpSignature:
            '-----BEGIN PGP SIGNATURE-----\ntest_signature_content\n-----END PGP SIGNATURE-----',
        publicKey:
            '-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest_public_key\n-----END PGP PUBLIC KEY BLOCK-----',
        deviceAttestation: 'attestation_token_xyz',
        timestamp: '2025-01-01T10:00:06Z',
      );

      testProofJson = jsonEncode(testProofData.toJson());
    });

    test('PendingUpload stores NativeProofData JSON', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testProofJson,
      );

      expect(upload.proofManifestJson, equals(testProofJson));
    });

    test('hasProofMode returns true when proofManifestJson is present', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testProofJson,
      );

      expect(upload.hasProofMode, isTrue);
    });

    test('hasProofMode returns false when proofManifestJson is null', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      );

      expect(upload.hasProofMode, isFalse);
    });

    test('nativeProof getter deserializes JSON correctly', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testProofJson,
      );

      final proof = upload.nativeProof;

      expect(proof, isNotNull);
      expect(
        proof!.videoHash,
        equals('abc123def456789012345678901234567890123456789012345678901234'),
      );
      expect(proof.sensorDataCsv, isNotNull);
      expect(proof.pgpSignature, isNotNull);
      expect(proof.publicKey, isNotNull);
      expect(proof.deviceAttestation, equals('attestation_token_xyz'));
      expect(proof.timestamp, equals('2025-01-01T10:00:06Z'));
    });

    test('nativeProof getter returns null for invalid JSON', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: 'invalid json {',
      );

      final proof = upload.nativeProof;

      expect(proof, isNull);
    });

    test('nativeProof getter returns null when proofManifestJson is null', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      );

      final proof = upload.nativeProof;

      expect(proof, isNull);
    });

    test('nativeProof getter returns null for non-native proof JSON', () {
      // JSON without 'videoHash' field should return null
      final nonNativeJson = jsonEncode({'someOtherField': 'value'});
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: nonNativeJson,
      );

      final proof = upload.nativeProof;

      expect(proof, isNull);
    });

    test('copyWith preserves NativeProofData', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testProofJson,
      );

      final copied = upload.copyWith(title: 'New Title');

      expect(copied.proofManifestJson, equals(testProofJson));
      expect(copied.hasProofMode, isTrue);
      expect(copied.nativeProof, isNotNull);
      expect(
        copied.nativeProof!.videoHash,
        equals('abc123def456789012345678901234567890123456789012345678901234'),
      );
    });

    test('copyWith can update proofManifestJson', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      );

      final copied = upload.copyWith(proofManifestJson: testProofJson);

      expect(copied.proofManifestJson, equals(testProofJson));
      expect(copied.hasProofMode, isTrue);
    });

    test('roundtrip serialization preserves NativeProofData', () {
      final original = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testProofJson,
      );

      // Serialize and deserialize the proof data
      final proof = original.nativeProof;
      expect(proof, isNotNull);

      final reserializedJson = jsonEncode(proof!.toJson());
      final roundtripped = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: reserializedJson,
      );

      final roundtrippedProof = roundtripped.nativeProof;
      expect(roundtrippedProof, isNotNull);
      expect(roundtrippedProof!.videoHash, equals(proof.videoHash));
      expect(roundtrippedProof.pgpSignature, equals(proof.pgpSignature));
      expect(roundtrippedProof.publicKey, equals(proof.publicKey));
      expect(
        roundtrippedProof.deviceAttestation,
        equals(proof.deviceAttestation),
      );
    });

    test('NativeProofData isComplete returns true when all fields present', () {
      final completeProof = const NativeProofData(
        videoHash: 'abc123',
        sensorDataCsv: 'data',
        pgpSignature: 'sig',
        publicKey: 'key',
      );

      expect(completeProof.isComplete, isTrue);
    });

    test('NativeProofData isComplete returns false when fields missing', () {
      final incompleteProof = const NativeProofData(videoHash: 'abc123');

      expect(incompleteProof.isComplete, isFalse);
    });

    test('NativeProofData hasMobileAttestation checks deviceAttestation', () {
      expect(testProofData.hasMobileAttestation, isTrue);

      final noAttestation = const NativeProofData(videoHash: 'abc123');
      expect(noAttestation.hasMobileAttestation, isFalse);
    });

    test('NativeProofData verificationLevel returns correct levels', () {
      // Full mobile verification
      expect(testProofData.verificationLevel, equals('verified_mobile'));

      // Web verification (signature but no attestation)
      final webProof = const NativeProofData(
        videoHash: 'abc123',
        pgpSignature: 'sig',
      );
      expect(webProof.verificationLevel, equals('verified_web'));

      // Basic proof (sensor data only)
      final basicProof = const NativeProofData(
        videoHash: 'abc123',
        sensorDataCsv: 'data',
      );
      expect(basicProof.verificationLevel, equals('basic_proof'));

      // Unverified (hash only)
      final unverifiedProof = const NativeProofData(videoHash: 'abc123');
      expect(unverifiedProof.verificationLevel, equals('unverified'));
    });
  });
}
