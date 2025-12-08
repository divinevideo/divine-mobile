// ABOUTME: Unit tests for ProofMode publishing helper functions
// ABOUTME: Tests verification level detection and Nostr tag creation from NativeProofData

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/native_proof_data.dart';
import 'package:openvine/utils/proofmode_publishing_helpers.dart';

void main() {
  group('ProofMode Publishing Helpers', () {
    late NativeProofData verifiedMobileData;
    late NativeProofData verifiedWebData;
    late NativeProofData basicProofData;
    late NativeProofData unverifiedData;

    setUp(() {
      // verified_mobile: has device attestation + signature
      verifiedMobileData = const NativeProofData(
        videoHash: 'video_hash_123',
        sensorDataCsv: 'location,network,device\n1,2,3',
        pgpSignature: 'pgp_signature_abc',
        publicKey: 'ABCD1234567890ABCD1234567890ABCD1234567890',
        deviceAttestation: 'attestation_token',
        timestamp: '2025-01-01T10:00:00Z',
      );

      // verified_web: has signature (no hardware attestation)
      verifiedWebData = const NativeProofData(
        videoHash: 'video_hash_456',
        sensorDataCsv: 'location,network,device\n1,2,3',
        pgpSignature: 'pgp_signature_def',
        publicKey: 'EFGH5678901234EFGH5678901234EFGH5678901234',
        deviceAttestation: null, // No hardware attestation
        timestamp: '2025-01-01T10:00:00Z',
      );

      // basic_proof: has some proof data but no signature
      basicProofData = const NativeProofData(
        videoHash: 'video_hash_789',
        sensorDataCsv: 'location,network,device\n1,2,3',
        pgpSignature: null, // No signature
        publicKey: null,
        deviceAttestation: null,
        timestamp: '2025-01-01T10:00:00Z',
      );

      // unverified: minimal data (no sensor data or signature)
      unverifiedData = const NativeProofData(
        videoHash: 'video_hash_000',
        sensorDataCsv: null, // No sensor data
        pgpSignature: null,
        publicKey: null,
        deviceAttestation: null,
        timestamp: null,
      );
    });

    group('getVerificationLevel', () {
      test('returns verified_mobile for attestation + signature', () {
        final level = getVerificationLevel(verifiedMobileData);
        expect(level, equals('verified_mobile'));
      });

      test('returns verified_web for signature without attestation', () {
        final level = getVerificationLevel(verifiedWebData);
        expect(level, equals('verified_web'));
      });

      test('returns basic_proof for sensor data without signature', () {
        final level = getVerificationLevel(basicProofData);
        expect(level, equals('basic_proof'));
      });

      test('returns unverified for minimal data', () {
        final level = getVerificationLevel(unverifiedData);
        expect(level, equals('unverified'));
      });
    });

    group('createProofManifestTag', () {
      test('returns compact JSON string', () {
        final tag = createProofManifestTag(verifiedMobileData);

        expect(tag, isA<String>());
        expect(tag.isNotEmpty, isTrue);

        // Verify it's valid JSON
        final decoded = jsonDecode(tag);
        expect(decoded, isA<Map<String, dynamic>>());
        expect(decoded['videoHash'], equals('video_hash_123'));
      });

      test('includes all manifest fields for complete data', () {
        final tag = createProofManifestTag(verifiedMobileData);
        final decoded = jsonDecode(tag) as Map<String, dynamic>;

        expect(decoded.containsKey('videoHash'), isTrue);
        expect(decoded.containsKey('sensorDataCsv'), isTrue);
        expect(decoded.containsKey('pgpSignature'), isTrue);
        expect(decoded.containsKey('publicKey'), isTrue);
        expect(decoded.containsKey('deviceAttestation'), isTrue);
        expect(decoded.containsKey('timestamp'), isTrue);
      });

      test('omits null fields in JSON output', () {
        final tag = createProofManifestTag(unverifiedData);
        final decoded = jsonDecode(tag) as Map<String, dynamic>;

        expect(decoded.containsKey('videoHash'), isTrue);
        expect(decoded.containsKey('sensorDataCsv'), isFalse);
        expect(decoded.containsKey('pgpSignature'), isFalse);
        expect(decoded.containsKey('publicKey'), isFalse);
        expect(decoded.containsKey('deviceAttestation'), isFalse);
        expect(decoded.containsKey('timestamp'), isFalse);
      });
    });

    group('createDeviceAttestationTag', () {
      test('returns attestation token when present', () {
        final tag = createDeviceAttestationTag(verifiedMobileData);

        expect(tag, isNotNull);
        expect(tag, equals('attestation_token'));
      });

      test('returns null when attestation is absent', () {
        final tag = createDeviceAttestationTag(verifiedWebData);

        expect(tag, isNull);
      });

      test('returns null for basic proof data', () {
        final tag = createDeviceAttestationTag(basicProofData);

        expect(tag, isNull);
      });
    });

    group('createPgpFingerprintTag', () {
      test('returns fingerprint when public key present', () {
        final tag = createPgpFingerprintTag(verifiedMobileData);

        expect(tag, isNotNull);
        // Implementation returns first 40 chars of public key as fingerprint
        expect(tag, equals('ABCD1234567890ABCD1234567890ABCD12345678'));
      });

      test('returns different fingerprint for web data', () {
        final tag = createPgpFingerprintTag(verifiedWebData);

        expect(tag, isNotNull);
        // Implementation returns first 40 chars of public key as fingerprint
        expect(tag, equals('EFGH5678901234EFGH5678901234EFGH56789012'));
      });

      test('returns null when public key is absent', () {
        final tag = createPgpFingerprintTag(basicProofData);

        expect(tag, isNull);
      });

      test('returns null for unverified data', () {
        final tag = createPgpFingerprintTag(unverifiedData);

        expect(tag, isNull);
      });
    });

    group('integration tests', () {
      test('verified_mobile data produces all 4 tags', () {
        final verificationLevel = getVerificationLevel(verifiedMobileData);
        final manifestTag = createProofManifestTag(verifiedMobileData);
        final attestationTag = createDeviceAttestationTag(verifiedMobileData);
        final fingerprintTag = createPgpFingerprintTag(verifiedMobileData);

        expect(verificationLevel, equals('verified_mobile'));
        expect(manifestTag, isNotEmpty);
        expect(attestationTag, isNotNull);
        expect(fingerprintTag, isNotNull);
      });

      test('verified_web data produces 3 tags (no attestation)', () {
        final verificationLevel = getVerificationLevel(verifiedWebData);
        final manifestTag = createProofManifestTag(verifiedWebData);
        final attestationTag = createDeviceAttestationTag(verifiedWebData);
        final fingerprintTag = createPgpFingerprintTag(verifiedWebData);

        expect(verificationLevel, equals('verified_web'));
        expect(manifestTag, isNotEmpty);
        expect(attestationTag, isNull);
        expect(fingerprintTag, isNotNull);
      });

      test(
        'basic_proof data produces 2 tags (no attestation or fingerprint)',
        () {
          final verificationLevel = getVerificationLevel(basicProofData);
          final manifestTag = createProofManifestTag(basicProofData);
          final attestationTag = createDeviceAttestationTag(basicProofData);
          final fingerprintTag = createPgpFingerprintTag(basicProofData);

          expect(verificationLevel, equals('basic_proof'));
          expect(manifestTag, isNotEmpty);
          expect(attestationTag, isNull);
          expect(fingerprintTag, isNull);
        },
      );

      test('unverified data only produces verification level tag', () {
        final verificationLevel = getVerificationLevel(unverifiedData);
        final manifestTag = createProofManifestTag(unverifiedData);
        final attestationTag = createDeviceAttestationTag(unverifiedData);
        final fingerprintTag = createPgpFingerprintTag(unverifiedData);

        expect(verificationLevel, equals('unverified'));
        expect(manifestTag, isNotEmpty); // Still produces JSON, just minimal
        expect(attestationTag, isNull);
        expect(fingerprintTag, isNull);
      });
    });
  });
}
