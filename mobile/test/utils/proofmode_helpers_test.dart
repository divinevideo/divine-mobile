// ABOUTME: Tests for ProofMode helper utilities
// ABOUTME: Validates VideoEvent extension methods for extracting verification levels from Nostr tags

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/utils/proofmode_helpers.dart';

void main() {
  group('ProofMode VideoEvent Extensions', () {
    test('detects verified_mobile level correctly', () {
      final video = VideoEvent(
        id: 'test1',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {
          'verification': 'verified_mobile',
          'proofmode': '{"test": "data"}',
          'pgp_fingerprint': 'ABC123',
        },
      );

      expect(video.getVerificationLevel(), VerificationLevel.verifiedMobile);
      expect(video.isVerifiedMobile, isTrue);
      expect(video.isVerifiedWeb, isFalse);
      expect(video.hasBasicProof, isFalse);
      expect(video.hasProofMode, isTrue);
      expect(video.shouldShowProofModeBadge, isTrue);
    });

    test('detects verified_web level correctly', () {
      final video = VideoEvent(
        id: 'test2',
        pubkey: 'pubkey2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {
          'verification': 'verified_web',
          'proofmode': '{"test": "data"}',
        },
      );

      expect(video.getVerificationLevel(), VerificationLevel.verifiedWeb);
      expect(video.isVerifiedMobile, isFalse);
      expect(video.isVerifiedWeb, isTrue);
      expect(video.hasBasicProof, isFalse);
      expect(video.hasProofMode, isTrue);
      expect(video.shouldShowProofModeBadge, isTrue);
    });

    test('detects basic_proof level correctly', () {
      final video = VideoEvent(
        id: 'test3',
        pubkey: 'pubkey3',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {'verification': 'basic_proof', 'pgp_fingerprint': 'ABC123'},
      );

      expect(video.getVerificationLevel(), VerificationLevel.basicProof);
      expect(video.isVerifiedMobile, isFalse);
      expect(video.isVerifiedWeb, isFalse);
      expect(video.hasBasicProof, isTrue);
      expect(video.hasProofMode, isTrue);
      expect(video.shouldShowProofModeBadge, isTrue);
    });

    test('detects unverified when no proof tags present', () {
      final video = VideoEvent(
        id: 'test4',
        pubkey: 'pubkey4',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {},
      );

      expect(video.getVerificationLevel(), VerificationLevel.unverified);
      expect(video.isVerifiedMobile, isFalse);
      expect(video.isVerifiedWeb, isFalse);
      expect(video.hasBasicProof, isFalse);
      expect(video.hasProofMode, isFalse);
      expect(video.shouldShowProofModeBadge, isFalse);
    });

    test('hasProofMode returns true with any proof tag', () {
      // Test with manifest only
      var video = VideoEvent(
        id: 'test5',
        pubkey: 'pubkey5',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {'proofmode': '{"test": "data"}'},
      );

      expect(video.hasProofMode, isTrue);

      // Test with fingerprint only
      video = VideoEvent(
        id: 'test6',
        pubkey: 'pubkey6',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {'pgp_fingerprint': 'ABC123'},
      );

      expect(video.hasProofMode, isTrue);
    });

    test('extracts proof manifest correctly', () {
      final manifestJson = '{"sessionId": "test", "frameHashes": []}';
      final video = VideoEvent(
        id: 'test7',
        pubkey: 'pubkey7',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {'proofmode': manifestJson},
      );

      expect(video.proofModeManifest, manifestJson);
    });

    test('extracts device attestation correctly', () {
      final attestation = 'ATTESTATION_TOKEN_123';
      final video = VideoEvent(
        id: 'test8',
        pubkey: 'pubkey8',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {'device_attestation': attestation},
      );

      expect(video.proofModeDeviceAttestation, attestation);
    });

    test('extracts PGP fingerprint correctly', () {
      final fingerprint = 'ABCD1234EFGH5678';
      final video = VideoEvent(
        id: 'test9',
        pubkey: 'pubkey9',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {'pgp_fingerprint': fingerprint},
      );

      expect(video.proofModePgpFingerprint, fingerprint);
    });
  });

  group('Original Vine Detection', () {
    test('detects original vine with loop count', () {
      final video = VideoEvent(
        id: 'vine1',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'classic vine',
        timestamp: DateTime.now(),
        originalLoops: 1000000,
      );

      expect(video.isOriginalVine, isTrue);
      expect(video.shouldShowVineBadge, isTrue);
    });

    test('does not detect as original vine without loop count', () {
      final video = VideoEvent(
        id: 'vine2',
        pubkey: 'pubkey2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'new vine',
        timestamp: DateTime.now(),
      );

      expect(video.isOriginalVine, isFalse);
      expect(video.shouldShowVineBadge, isFalse);
    });

    test('does not detect as original vine with zero loops', () {
      final video = VideoEvent(
        id: 'vine3',
        pubkey: 'pubkey3',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'vine with zero loops',
        timestamp: DateTime.now(),
        originalLoops: 0,
      );

      expect(video.isOriginalVine, isFalse);
      expect(video.shouldShowVineBadge, isFalse);
    });

    test('detects original vine with minimal loops', () {
      final video = VideoEvent(
        id: 'vine4',
        pubkey: 'pubkey4',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'vine with one loop',
        timestamp: DateTime.now(),
        originalLoops: 1,
      );

      expect(video.isOriginalVine, isTrue);
      expect(video.shouldShowVineBadge, isTrue);
    });
  });

  group('Combined Badge Display Logic', () {
    test('shows only ProofMode badge for vintage vines with verification', () {
      final video = VideoEvent(
        id: 'combo1',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'verified original vine',
        timestamp: DateTime.now(),
        rawTags: {'verification': 'verified_mobile'},
        originalLoops: 500000,
      );

      expect(video.shouldShowProofModeBadge, isTrue);
      expect(
        video.shouldShowVineBadge,
        isFalse,
      ); // ProofMode takes precedence over Vine badge
      expect(video.getVerificationLevel(), VerificationLevel.verifiedMobile);
      expect(video.isOriginalVine, isTrue);
    });

    test('shows only ProofMode badge for new verified videos', () {
      final video = VideoEvent(
        id: 'combo2',
        pubkey: 'pubkey2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'new verified vine',
        timestamp: DateTime.now(),
        rawTags: {'verification': 'verified_web'},
      );

      expect(video.shouldShowProofModeBadge, isTrue);
      expect(video.shouldShowVineBadge, isFalse);
    });

    test('shows only Vine badge for unverified original vines', () {
      final video = VideoEvent(
        id: 'combo3',
        pubkey: 'pubkey3',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'classic unverified vine',
        timestamp: DateTime.now(),
        originalLoops: 1000000,
      );

      expect(video.shouldShowProofModeBadge, isFalse);
      expect(video.shouldShowVineBadge, isTrue);
    });

    test('shows no badges for unverified new videos', () {
      final video = VideoEvent(
        id: 'combo4',
        pubkey: 'pubkey4',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'plain new vine',
        timestamp: DateTime.now(),
      );

      expect(video.shouldShowProofModeBadge, isFalse);
      expect(video.shouldShowVineBadge, isFalse);
    });
  });
}
