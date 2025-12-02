// ABOUTME: Tests for ProofMode manifest serialization in VineDraft
// ABOUTME: Validates that ProofManifest JSON is stored and retrieved correctly

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/proofmode_session_service.dart';

void main() {
  group('VineDraft ProofMode serialization', () {
    test('should serialize and deserialize proofManifestJson correctly', () {
      final now = DateTime.now();

      // Create a sample ProofManifest
      final manifest = ProofManifest(
        sessionId: 'test_recording_123',
        challengeNonce: 'challenge_abc',
        vineSessionStart: now,
        vineSessionEnd: now.add(const Duration(seconds: 5)),
        segments: [
          RecordingSegment(
            segmentId: 'seg_0',
            startTime: now,
            endTime: now.add(const Duration(seconds: 1)),
            frameHashes: ['abc123', 'def456'],
          ),
        ],
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'video_hash_xyz',
        deviceAttestation: null,
        pgpSignature: null,
      );

      final manifestJson = jsonEncode(manifest.toJson());

      // Create draft with proofManifestJson
      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Test Video',
        description: 'Test with ProofMode',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
        proofManifestJson: manifestJson,
      );

      // Verify hasProofMode returns true
      expect(draft.hasProofMode, true);

      // Verify proofManifest can be deserialized
      final deserializedManifest = draft.proofManifest;
      expect(deserializedManifest, isNotNull);
      expect(deserializedManifest!.sessionId, 'test_recording_123');
      expect(deserializedManifest.segments.length, 1);
      expect(deserializedManifest.segments[0].frameHashes[0], 'abc123');

      // Verify JSON serialization round-trip
      final json = draft.toJson();
      expect(json['proofManifestJson'], manifestJson);

      final deserialized = VineDraft.fromJson(json);
      expect(deserialized.hasProofMode, true);
      expect(deserialized.proofManifest, isNotNull);
      expect(deserialized.proofManifest!.sessionId, 'test_recording_123');
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
      expect(draft.proofManifest, null);

      // Verify JSON serialization handles null
      final json = draft.toJson();
      final deserialized = VineDraft.fromJson(json);
      expect(deserialized.hasProofMode, false);
      expect(deserialized.proofManifest, null);
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
      expect(draft.proofManifest, null);
    });

    test('should preserve proofManifestJson through copyWith', () {
      final now = DateTime.now();
      final manifest = ProofManifest(
        sessionId: 'test_123',
        challengeNonce: 'nonce_123',
        vineSessionStart: now,
        vineSessionEnd: now.add(const Duration(seconds: 5)),
        segments: [],
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'hash_123',
        deviceAttestation: null,
        pgpSignature: null,
      );

      final manifestJson = jsonEncode(manifest.toJson());

      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Original',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        proofManifestJson: manifestJson,
      );

      expect(draft.hasProofMode, true);

      // Update title via copyWith
      final updated = draft.copyWith(title: 'Updated Title');

      // ProofManifest should be preserved
      expect(updated.hasProofMode, true);
      expect(updated.proofManifest, isNotNull);
      expect(updated.proofManifest!.sessionId, 'test_123');
      expect(updated.title, 'Updated Title');
    });
  });
}
