// ABOUTME: Unit tests for ProofMode integration with PendingUpload model
// ABOUTME: Tests serialization, deserialization, and helper methods for ProofManifest storage

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';

void main() {
  group('PendingUpload ProofMode Integration', () {
    late ProofManifest testManifest;
    late String testManifestJson;

    setUp(() {
      // Create a test ProofManifest
      testManifest = ProofManifest(
        sessionId: 'test_session_123',
        challengeNonce: 'test_nonce_abc',
        vineSessionStart: DateTime(2025, 1, 1, 10, 0, 0),
        vineSessionEnd: DateTime(2025, 1, 1, 10, 0, 6),
        segments: [
          RecordingSegment(
            segmentId: 'segment_1',
            startTime: DateTime(2025, 1, 1, 10, 0, 0),
            endTime: DateTime(2025, 1, 1, 10, 0, 3),
            frameHashes: ['hash1', 'hash2'],
          ),
          RecordingSegment(
            segmentId: 'segment_2',
            startTime: DateTime(2025, 1, 1, 10, 0, 3),
            endTime: DateTime(2025, 1, 1, 10, 0, 6),
            frameHashes: ['hash3', 'hash4'],
          ),
        ],
        pauseProofs: [
          PauseProof(
            startTime: DateTime(2025, 1, 1, 10, 0, 3),
            endTime: DateTime(2025, 1, 1, 10, 0, 3, 500),
            sensorData: {
              'accelerometer': {'x': 0.1, 'y': 0.2, 'z': 9.8},
            },
          ),
        ],
        interactions: [
          UserInteractionProof(
            timestamp: DateTime(2025, 1, 1, 10, 0, 0),
            interactionType: 'start',
            coordinates: {'x': 100.0, 'y': 200.0},
          ),
        ],
        finalVideoHash: 'abc123def456',
        deviceAttestation: DeviceAttestation(
          token: 'attestation_token_xyz',
          platform: 'iOS',
          deviceId: 'device_123',
          isHardwareBacked: true,
          createdAt: DateTime(2025, 1, 1, 10, 0, 0),
          challenge: 'test_nonce_abc',
        ),
        pgpSignature: ProofSignature(
          signature: 'pgp_signature_content',
          publicKeyFingerprint: 'ABCD1234EFGH5678',
          signedAt: DateTime(2025, 1, 1, 10, 0, 6),
        ),
      );

      testManifestJson = jsonEncode(testManifest.toJson());
    });

    test('PendingUpload stores ProofManifest JSON', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testManifestJson,
      );

      expect(upload.proofManifestJson, equals(testManifestJson));
    });

    test('hasProofMode returns true when manifestJson is present', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testManifestJson,
      );

      expect(upload.hasProofMode, isTrue);
    });

    test('hasProofMode returns false when manifestJson is null', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      );

      expect(upload.hasProofMode, isFalse);
    });

    test('proofManifest getter deserializes JSON correctly', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testManifestJson,
      );

      final manifest = upload.proofManifest;

      expect(manifest, isNotNull);
      expect(manifest!.sessionId, equals('test_session_123'));
      expect(manifest.challengeNonce, equals('test_nonce_abc'));
      expect(manifest.segments.length, equals(2));
      expect(manifest.pauseProofs.length, equals(1));
      expect(manifest.interactions.length, equals(1));
      expect(manifest.finalVideoHash, equals('abc123def456'));
      expect(manifest.deviceAttestation, isNotNull);
      expect(
        manifest.deviceAttestation!.token,
        equals('attestation_token_xyz'),
      );
      expect(manifest.pgpSignature, isNotNull);
      expect(
        manifest.pgpSignature!.publicKeyFingerprint,
        equals('ABCD1234EFGH5678'),
      );
    });

    test('proofManifest getter returns null for invalid JSON', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: 'invalid json {',
      );

      final manifest = upload.proofManifest;

      expect(manifest, isNull);
    });

    test('proofManifest getter returns null when manifestJson is null', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      );

      final manifest = upload.proofManifest;

      expect(manifest, isNull);
    });

    test('copyWith preserves ProofManifest', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testManifestJson,
      );

      final copied = upload.copyWith(title: 'New Title');

      expect(copied.proofManifestJson, equals(testManifestJson));
      expect(copied.hasProofMode, isTrue);
      expect(copied.proofManifest, isNotNull);
      expect(copied.proofManifest!.sessionId, equals('test_session_123'));
    });

    test('copyWith can update ProofManifest', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      );

      final copied = upload.copyWith(proofManifestJson: testManifestJson);

      expect(copied.proofManifestJson, equals(testManifestJson));
      expect(copied.hasProofMode, isTrue);
    });

    test('roundtrip serialization preserves ProofManifest data', () {
      final original = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: testManifestJson,
      );

      // Serialize and deserialize the manifest
      final manifest = original.proofManifest;
      expect(manifest, isNotNull);

      final reserializedJson = jsonEncode(manifest!.toJson());
      final roundtripped = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
        proofManifestJson: reserializedJson,
      );

      final roundtrippedManifest = roundtripped.proofManifest;
      expect(roundtrippedManifest, isNotNull);
      expect(roundtrippedManifest!.sessionId, equals(manifest.sessionId));
      expect(
        roundtrippedManifest.challengeNonce,
        equals(manifest.challengeNonce),
      );
      expect(
        roundtrippedManifest.finalVideoHash,
        equals(manifest.finalVideoHash),
      );
      expect(
        roundtrippedManifest.segments.length,
        equals(manifest.segments.length),
      );
    });
  });
}
