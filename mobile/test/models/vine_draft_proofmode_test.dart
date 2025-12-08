// ABOUTME: Tests for NativeProofData serialization in VineDraft
// ABOUTME: Validates that native proof JSON is stored and retrieved correctly

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/native_proof_data.dart';

void main() {
  group('VineDraft NativeProof serialization', () {
    test('should serialize and deserialize proofManifestJson correctly', () {
      // Create a sample NativeProofData
      final proofData = NativeProofData(
        videoHash: 'abc123def456',
        sensorDataCsv: 'timestamp,lat,lng\n2025-01-01,0.0,0.0',
        pgpSignature: 'pgp_signature_data',
        publicKey: 'pgp_public_key_data',
        deviceAttestation: 'attestation_token',
        timestamp: '2025-01-01T00:00:00Z',
      );

      final proofJson = jsonEncode(proofData.toJson());

      // Create draft with proofManifestJson
      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Test Video',
        description: 'Test with ProofMode',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      // Verify hasProofMode returns true
      expect(draft.hasProofMode, true);

      // Verify nativeProof can be deserialized
      final deserializedProof = draft.nativeProof;
      expect(deserializedProof, isNotNull);
      expect(deserializedProof!.videoHash, 'abc123def456');
      expect(deserializedProof.pgpSignature, 'pgp_signature_data');

      // Verify JSON serialization round-trip
      final json = draft.toJson();
      expect(json['proofManifestJson'], proofJson);

      final deserialized = VineDraft.fromJson(json);
      expect(deserialized.hasProofMode, true);
      expect(deserialized.nativeProof, isNotNull);
      expect(deserialized.nativeProof!.videoHash, 'abc123def456');
    });

    test('should handle drafts without proofManifestJson', () {
      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Test Video',
        description: 'No ProofMode',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
        // proofManifestJson: null (not provided)
      );

      expect(draft.hasProofMode, false);
      expect(draft.nativeProof, null);

      // Verify JSON serialization handles null
      final json = draft.toJson();
      final deserialized = VineDraft.fromJson(json);
      expect(deserialized.hasProofMode, false);
      expect(deserialized.nativeProof, null);
    });

    test('should migrate old drafts without proofManifestJson gracefully', () {
      final json = {
        'id': 'old_draft',
        'videoFilePath': '/path/to/video.mp4',
        'title': 'Old Draft',
        'description': 'From before ProofMode',
        'hashtags': ['old'],
        'frameCount': 30,
        'selectedApproach': 'native',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'lastModified': '2025-01-01T00:00:00.000Z',
        'publishStatus': 'draft',
        'publishAttempts': 0,
        // proofManifestJson missing
      };

      final draft = VineDraft.fromJson(json);

      expect(draft.hasProofMode, false);
      expect(draft.nativeProof, null);
    });

    test('should preserve proofManifestJson through copyWith', () {
      final proofData = NativeProofData(
        videoHash: 'hash_123',
        pgpSignature: 'sig_123',
        publicKey: 'key_123',
      );

      final proofJson = jsonEncode(proofData.toJson());

      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Original',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      expect(draft.hasProofMode, true);

      // Update title via copyWith
      final updated = draft.copyWith(title: 'Updated Title');

      // NativeProof should be preserved
      expect(updated.hasProofMode, true);
      expect(updated.nativeProof, isNotNull);
      expect(updated.nativeProof!.videoHash, 'hash_123');
      expect(updated.title, 'Updated Title');
    });

    test('NativeProofData verification level should work correctly', () {
      // Full verification with mobile attestation
      final fullProof = NativeProofData(
        videoHash: 'hash',
        pgpSignature: 'sig',
        publicKey: 'key',
        deviceAttestation: 'attestation',
        sensorDataCsv: 'csv',
      );
      expect(fullProof.verificationLevel, 'verified_mobile');
      expect(fullProof.isComplete, true);
      expect(fullProof.hasMobileAttestation, true);

      // Web verification (no attestation)
      final webProof = NativeProofData(
        videoHash: 'hash',
        pgpSignature: 'sig',
        publicKey: 'key',
        sensorDataCsv: 'csv',
      );
      expect(webProof.verificationLevel, 'verified_web');
      expect(webProof.isComplete, true);
      expect(webProof.hasMobileAttestation, false);

      // Basic proof (sensor data only)
      final basicProof = NativeProofData(
        videoHash: 'hash',
        sensorDataCsv: 'csv',
      );
      expect(basicProof.verificationLevel, 'basic_proof');
      expect(basicProof.isComplete, false);

      // Unverified (hash only)
      const unverifiedProof = NativeProofData(videoHash: 'hash');
      expect(unverifiedProof.verificationLevel, 'unverified');
      expect(unverifiedProof.isComplete, false);
    });
  });
}
