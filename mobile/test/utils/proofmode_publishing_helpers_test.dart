// ABOUTME: Unit tests for ProofMode publishing helper functions
// ABOUTME: Tests verification level detection and Nostr tag creation from ProofManifest

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/utils/proofmode_publishing_helpers.dart';

void main() {
  group('ProofMode Publishing Helpers', () {
    late ProofManifest verifiedMobileManifest;
    late ProofManifest verifiedWebManifest;
    late ProofManifest basicProofManifest;
    late ProofManifest unverifiedManifest;

    setUp(() {
      // verified_mobile: has attestation + manifest + signature
      verifiedMobileManifest = ProofManifest(
        sessionId: 'session_1',
        challengeNonce: 'nonce_1',
        vineSessionStart: DateTime(2025, 1, 1, 10, 0, 0),
        vineSessionEnd: DateTime(2025, 1, 1, 10, 0, 6),
        segments: [
          RecordingSegment(
            segmentId: 'segment_1',
            startTime: DateTime(2025, 1, 1, 10, 0, 0),
            endTime: DateTime(2025, 1, 1, 10, 0, 6),
            frameHashes: ['hash1', 'hash2'],
          ),
        ],
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'video_hash_123',
        deviceAttestation: DeviceAttestation(
          token: 'attestation_token',
          platform: 'iOS',
          deviceId: 'device_123',
          isHardwareBacked: true,
          createdAt: DateTime(2025, 1, 1, 10, 0, 0),
        ),
        pgpSignature: ProofSignature(
          signature: 'pgp_signature',
          publicKeyFingerprint: 'ABCD1234',
          signedAt: DateTime(2025, 1, 1, 10, 0, 6),
        ),
      );

      // verified_web: has manifest + signature (no hardware attestation)
      verifiedWebManifest = ProofManifest(
        sessionId: 'session_2',
        challengeNonce: 'nonce_2',
        vineSessionStart: DateTime(2025, 1, 1, 10, 0, 0),
        vineSessionEnd: DateTime(2025, 1, 1, 10, 0, 6),
        segments: [
          RecordingSegment(
            segmentId: 'segment_1',
            startTime: DateTime(2025, 1, 1, 10, 0, 0),
            endTime: DateTime(2025, 1, 1, 10, 0, 6),
            frameHashes: ['hash1', 'hash2'],
          ),
        ],
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'video_hash_456',
        deviceAttestation: null, // No hardware attestation
        pgpSignature: ProofSignature(
          signature: 'pgp_signature',
          publicKeyFingerprint: 'EFGH5678',
          signedAt: DateTime(2025, 1, 1, 10, 0, 6),
        ),
      );

      // basic_proof: has some proof data but no signature
      basicProofManifest = ProofManifest(
        sessionId: 'session_3',
        challengeNonce: 'nonce_3',
        vineSessionStart: DateTime(2025, 1, 1, 10, 0, 0),
        vineSessionEnd: DateTime(2025, 1, 1, 10, 0, 6),
        segments: [
          RecordingSegment(
            segmentId: 'segment_1',
            startTime: DateTime(2025, 1, 1, 10, 0, 0),
            endTime: DateTime(2025, 1, 1, 10, 0, 6),
            frameHashes: ['hash1', 'hash2'],
          ),
        ],
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'video_hash_789',
        deviceAttestation: null,
        pgpSignature: null, // No signature
      );

      // unverified: empty segments (no real proof data)
      unverifiedManifest = ProofManifest(
        sessionId: 'session_4',
        challengeNonce: 'nonce_4',
        vineSessionStart: DateTime(2025, 1, 1, 10, 0, 0),
        vineSessionEnd: DateTime(2025, 1, 1, 10, 0, 6),
        segments: [], // Empty segments
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'video_hash_000',
        deviceAttestation: null,
        pgpSignature: null,
      );
    });

    group('getVerificationLevel', () {
      test('returns verified_mobile for attestation + signature', () {
        final level = getVerificationLevel(verifiedMobileManifest);
        expect(level, equals('verified_mobile'));
      });

      test('returns verified_web for signature without attestation', () {
        final level = getVerificationLevel(verifiedWebManifest);
        expect(level, equals('verified_web'));
      });

      test('returns basic_proof for segments without signature', () {
        final level = getVerificationLevel(basicProofManifest);
        expect(level, equals('basic_proof'));
      });

      test('returns unverified for empty segments', () {
        final level = getVerificationLevel(unverifiedManifest);
        expect(level, equals('unverified'));
      });
    });

    group('createProofManifestTag', () {
      test('returns compact JSON string', () {
        final tag = createProofManifestTag(verifiedMobileManifest);

        expect(tag, isA<String>());
        expect(tag.isNotEmpty, isTrue);

        // Verify it's valid JSON
        final decoded = jsonDecode(tag);
        expect(decoded, isA<Map<String, dynamic>>());
        expect(decoded['sessionId'], equals('session_1'));
        expect(decoded['finalVideoHash'], equals('video_hash_123'));
      });

      test('includes all manifest fields', () {
        final tag = createProofManifestTag(verifiedMobileManifest);
        final decoded = jsonDecode(tag) as Map<String, dynamic>;

        expect(decoded.containsKey('sessionId'), isTrue);
        expect(decoded.containsKey('challengeNonce'), isTrue);
        expect(decoded.containsKey('vineSessionStart'), isTrue);
        expect(decoded.containsKey('vineSessionEnd'), isTrue);
        expect(decoded.containsKey('segments'), isTrue);
        expect(decoded.containsKey('pauseProofs'), isTrue);
        expect(decoded.containsKey('interactions'), isTrue);
        expect(decoded.containsKey('finalVideoHash'), isTrue);
        expect(decoded.containsKey('deviceAttestation'), isTrue);
        expect(decoded.containsKey('pgpSignature'), isTrue);
      });
    });

    group('createDeviceAttestationTag', () {
      test('returns attestation token when present', () {
        final tag = createDeviceAttestationTag(verifiedMobileManifest);

        expect(tag, isNotNull);
        expect(tag, equals('attestation_token'));
      });

      test('returns null when attestation is absent', () {
        final tag = createDeviceAttestationTag(verifiedWebManifest);

        expect(tag, isNull);
      });

      test('returns null for basic proof manifest', () {
        final tag = createDeviceAttestationTag(basicProofManifest);

        expect(tag, isNull);
      });
    });

    group('createPgpFingerprintTag', () {
      test('returns fingerprint when signature present', () {
        final tag = createPgpFingerprintTag(verifiedMobileManifest);

        expect(tag, isNotNull);
        expect(tag, equals('ABCD1234'));
      });

      test('returns different fingerprint for web manifest', () {
        final tag = createPgpFingerprintTag(verifiedWebManifest);

        expect(tag, isNotNull);
        expect(tag, equals('EFGH5678'));
      });

      test('returns null when signature is absent', () {
        final tag = createPgpFingerprintTag(basicProofManifest);

        expect(tag, isNull);
      });

      test('returns null for unverified manifest', () {
        final tag = createPgpFingerprintTag(unverifiedManifest);

        expect(tag, isNull);
      });
    });

    group('integration tests', () {
      test('verified_mobile manifest produces all 4 tags', () {
        final verificationLevel = getVerificationLevel(verifiedMobileManifest);
        final manifestTag = createProofManifestTag(verifiedMobileManifest);
        final attestationTag = createDeviceAttestationTag(
          verifiedMobileManifest,
        );
        final fingerprintTag = createPgpFingerprintTag(verifiedMobileManifest);

        expect(verificationLevel, equals('verified_mobile'));
        expect(manifestTag, isNotEmpty);
        expect(attestationTag, isNotNull);
        expect(fingerprintTag, isNotNull);
      });

      test('verified_web manifest produces 3 tags (no attestation)', () {
        final verificationLevel = getVerificationLevel(verifiedWebManifest);
        final manifestTag = createProofManifestTag(verifiedWebManifest);
        final attestationTag = createDeviceAttestationTag(verifiedWebManifest);
        final fingerprintTag = createPgpFingerprintTag(verifiedWebManifest);

        expect(verificationLevel, equals('verified_web'));
        expect(manifestTag, isNotEmpty);
        expect(attestationTag, isNull);
        expect(fingerprintTag, isNotNull);
      });

      test(
        'basic_proof manifest produces 2 tags (no attestation or fingerprint)',
        () {
          final verificationLevel = getVerificationLevel(basicProofManifest);
          final manifestTag = createProofManifestTag(basicProofManifest);
          final attestationTag = createDeviceAttestationTag(basicProofManifest);
          final fingerprintTag = createPgpFingerprintTag(basicProofManifest);

          expect(verificationLevel, equals('basic_proof'));
          expect(manifestTag, isNotEmpty);
          expect(attestationTag, isNull);
          expect(fingerprintTag, isNull);
        },
      );

      test('unverified manifest only produces verification level tag', () {
        final verificationLevel = getVerificationLevel(unverifiedManifest);
        final manifestTag = createProofManifestTag(unverifiedManifest);
        final attestationTag = createDeviceAttestationTag(unverifiedManifest);
        final fingerprintTag = createPgpFingerprintTag(unverifiedManifest);

        expect(verificationLevel, equals('unverified'));
        expect(
          manifestTag,
          isNotEmpty,
        ); // Still produces JSON, but with empty segments
        expect(attestationTag, isNull);
        expect(fingerprintTag, isNull);
      });
    });
  });
}
