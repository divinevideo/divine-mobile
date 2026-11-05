// ABOUTME: Tests for ProofMode helper utilities
// ABOUTME: Validates VideoEvent extension methods for extracting verification levels from Nostr tags

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
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
        rawTags: const {
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
        rawTags: const {
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
        rawTags: const {
          'verification': 'basic_proof',
          'pgp_fingerprint': 'ABC123',
        },
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
      );

      expect(video.getVerificationLevel(), VerificationLevel.unverified);
      expect(video.isVerifiedMobile, isFalse);
      expect(video.isVerifiedWeb, isFalse);
      expect(video.hasBasicProof, isFalse);
      expect(video.hasProofMode, isFalse);
      expect(video.shouldShowProofModeBadge, isFalse);
    });

    test('hasProofMode reflects manifest proof content', () {
      // A proofmode manifest with no proof-signal field is an unverified
      // shell, not proof — tag presence alone is not enough.
      var video = VideoEvent(
        id: 'test5',
        pubkey: 'pubkey5',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: const {'proofmode': '{"test": "data"}'},
      );

      expect(video.hasProofMode, isFalse);

      // A manifest carrying a real proof signal (PGP signature) is proof.
      video = VideoEvent(
        id: 'test6',
        pubkey: 'pubkey6',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: {
          'proofmode': jsonEncode({'pgpSignature': 'SIG-DATA'}),
        },
      );

      expect(video.hasProofMode, isTrue);
    });

    test('extracts proof manifest correctly', () {
      const manifestJson = '{"sessionId": "test", "frameHashes": []}';
      final video = VideoEvent(
        id: 'test7',
        pubkey: 'pubkey7',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: const {'proofmode': manifestJson},
      );

      expect(video.proofModeManifest, manifestJson);
    });

    test('extracts device attestation correctly', () {
      const attestation = 'ATTESTATION_TOKEN_123';
      final video = VideoEvent(
        id: 'test8',
        pubkey: 'pubkey8',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: const {'device_attestation': attestation},
      );

      expect(video.proofModeDeviceAttestation, attestation);
    });

    test(
      'extracts PGP signature from proofmode manifest pgpSignature field',
      () {
        const signature = '-----BEGIN PGP SIGNATURE-----\n...\n-----END-----';
        final video = VideoEvent(
          id: 'test9',
          pubkey: 'pubkey9',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'test video',
          timestamp: DateTime.now(),
          rawTags: {
            'proofmode': jsonEncode({'pgpSignature': signature}),
          },
        );

        expect(video.proofModePgpFingerprint, signature);
      },
    );

    test(
      'returns null when proofmode manifest is missing pgpSignature field',
      () {
        final video = VideoEvent(
          id: 'test10',
          pubkey: 'pubkey10',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'test video',
          timestamp: DateTime.now(),
          rawTags: const {
            'proofmode': '{"publicKey":"abc"}',
          },
        );

        expect(video.proofModePgpFingerprint, isNull);
      },
    );

    test('returns null when proofmode tag is absent', () {
      final video = VideoEvent(
        id: 'test11',
        pubkey: 'pubkey11',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
      );

      expect(video.proofModePgpFingerprint, isNull);
    });

    test('returns null when proofmode manifest is malformed JSON', () {
      final video = VideoEvent(
        id: 'test12',
        pubkey: 'pubkey12',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'test video',
        timestamp: DateTime.now(),
        rawTags: const {'proofmode': 'not-json'},
      );

      expect(video.proofModePgpFingerprint, isNull);
      expect(video.proofModeManifestJson, isNull);
    });
  });

  group('Original Vine Detection', () {
    test('detects original vine via platform field from Funnelcake', () {
      final video = VideoEvent(
        id: 'vine1',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'classic vine',
        timestamp: DateTime.now(),
        rawTags: const {'platform': 'vine'},
        originalLoops: 1000000,
      );

      expect(video.isOriginalVine, isTrue);
    });

    test('does not detect as original vine without platform tag', () {
      final video = VideoEvent(
        id: 'vine2',
        pubkey: 'pubkey2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'new vine',
        timestamp: DateTime.now(),
      );

      expect(video.isOriginalVine, isFalse);
    });

    test('does not detect as original vine with engagement loops only', () {
      // New video with engagement loops from Funnelcake but no
      // platform: vine — must NOT be classified as archive vine
      final video = VideoEvent(
        id: 'vine3',
        pubkey: 'pubkey3',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'new office',
        timestamp: DateTime.now(),
        rawTags: const {'client': 'diVine'},
        originalLoops: 10,
      );

      expect(video.isOriginalVine, isFalse);
    });

    test('does not detect non-vine platform as original vine', () {
      final video = VideoEvent(
        id: 'vine4',
        pubkey: 'pubkey4',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'some video',
        timestamp: DateTime.now(),
        rawTags: const {'platform': 'youtube'},
      );

      expect(video.isOriginalVine, isFalse);
    });

    test('cannot be spoofed with loops tag alone', () {
      // Someone publishes a Nostr event with a loops tag but no
      // server-controlled platform field — must NOT be classified
      final video = VideoEvent(
        id: 'vine5',
        pubkey: 'pubkey5',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'fake vine attempt',
        timestamp: DateTime.now(),
        rawTags: const {'loops': '999999'},
        originalLoops: 999999,
      );

      expect(video.isOriginalVine, isFalse);
    });
  });

  group('Combined Badge Display Logic', () {
    test('hides the ProofMode badge on verified archive Vines', () {
      final video = VideoEvent(
        id: 'combo1',
        pubkey: 'pubkey1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'verified original vine',
        timestamp: DateTime.now(),
        rawTags: const {'verification': 'verified_mobile', 'platform': 'vine'},
        originalLoops: 500000,
        isVerifiedArchive: true,
      );

      expect(video.shouldShowProofModeBadge, isFalse);
      expect(video.isOriginalVine, isTrue);
      expect(video.hasProofMode, isTrue);
    });

    test(
      'a self-applied platform=vine tag does not hide the ProofMode badge',
      () {
        final video = VideoEvent(
          id: 'combo1b',
          pubkey: 'pubkey1',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'self-tagged upload with proof',
          timestamp: DateTime.now(),
          rawTags: const {
            'verification': 'verified_mobile',
            'platform': 'vine',
          },
        );

        expect(video.shouldShowProofModeBadge, isTrue);
      },
    );

    test(
      'a platform=vine tag hides the ProofMode badge while funnelcake '
      'cannot check the archive',
      () {
        final video = VideoEvent(
          id: 'combo1c',
          pubkey: 'pubkey1',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'tagged Vine the archive could not check',
          timestamp: DateTime.now(),
          rawTags: const {
            'verification': 'verified_mobile',
            'platform': 'vine',
          },
          isArchiveVerificationUnknown: true,
        );

        expect(video.shouldShowProofModeBadge, isFalse);
      },
    );

    test('shows only ProofMode badge for new verified videos', () {
      final video = VideoEvent(
        id: 'combo2',
        pubkey: 'pubkey2',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        content: 'new verified vine',
        timestamp: DateTime.now(),
        rawTags: const {'verification': 'verified_web'},
      );

      expect(video.shouldShowProofModeBadge, isTrue);
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
    });

    test(
      'verified archive Vines never show ProofMode, even with proof tags',
      () {
        final video = VideoEvent(
          id: 'combo5',
          pubkey: 'pubkey5',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'vine with all proof tags',
          timestamp: DateTime.now(),
          rawTags: const {
            'verification': 'verified_mobile',
            'proofmode': '{"test": "data"}',
            'pgp_fingerprint': 'ABC123',
            'device_attestation': 'ATTEST',
            'platform': 'vine',
          },
          originalLoops: 42000,
          isVerifiedArchive: true,
        );

        expect(video.shouldShowProofModeBadge, isFalse);
        expect(video.hasProofMode, isTrue);
        expect(video.isOriginalVine, isTrue);
      },
    );
  });
}
