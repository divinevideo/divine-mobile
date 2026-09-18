// ABOUTME: Tests for ProofModePublishTagger: the NIP-145 tags rendered from a
// ABOUTME: native proof, publish-time attestation binding, and account-switch cleanup

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/services/ios_device_attestation_service.dart';
import 'package:openvine/services/video_publish/proofmode_publish_tagger.dart';

class _RecordingAttestationService extends IosDeviceAttestationService {
  _RecordingAttestationService({this.payload, this.onAfterAttestation});

  final String? payload;
  final VoidCallback? onAfterAttestation;
  String? proofHash;
  String? pubkeyHex;

  @override
  Future<String?> attestationFor({
    required String proofHash,
    required String pubkeyHex,
  }) async {
    this.proofHash = proofHash;
    this.pubkeyHex = pubkeyHex;
    onAfterAttestation?.call();
    return payload;
  }
}

class _ThrowingAttestationService extends IosDeviceAttestationService {
  @override
  Future<String?> attestationFor({
    required String proofHash,
    required String pubkeyHex,
  }) => throw StateError('attestation exploded');
}

const _proof = NativeProofData(
  videoHash: 'abc123def456',
  pgpSignature: 'signature',
  publicKey: 'public_key',
  deviceAttestation: 'attestation-from-generation',
);

List<String> _tag(List<List<String>> tags, String name) =>
    tags.singleWhere((tag) => tag.isNotEmpty && tag.first == name);

bool _hasTag(List<List<String>> tags, String name) =>
    tags.any((tag) => tag.isNotEmpty && tag.first == name);

void main() {
  group(ProofModePublishTagger, () {
    group('addTags', () {
      test(
        'renders the proof into NIP-145 tags on a generating platform',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final attestation = _RecordingAttestationService(payload: 'unused');
          final tagger = ProofModePublishTagger(
            iosDeviceAttestation: attestation,
            currentPubkeyHex: () => 'signer-pubkey',
          );
          final tags = <List<String>>[];

          final result = await tagger.addTags(
            tags,
            proof: _proof,
            localVideoPath: '/tmp/test.mp4',
          );

          expect(
            attestation.proofHash,
            isNull,
            reason: 'Android attests at generation; publishing leaves it alone',
          );
          expect(_tag(tags, 'verification'), [
            'verification',
            'verified_mobile',
          ]);
          expect(
            jsonDecode(_tag(tags, 'proofmode')[1]),
            equals(_proof.toJson()),
          );
          expect(
            _tag(tags, 'device_attestation'),
            ['device_attestation', 'attestation-from-generation'],
          );
          expect(_hasTag(tags, 'identity_binding'), isFalse);
          expect(result.proof, equals(_proof));
          expect(result.attestedPubkeyHex, isNull);
        },
      );

      test(
        'mints and binds the attestation to the signing account on iOS',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final attestation = _RecordingAttestationService(
            payload: 'attestation-for-signer',
          );
          final tagger = ProofModePublishTagger(
            iosDeviceAttestation: attestation,
            currentPubkeyHex: () => 'signer-pubkey',
          );
          final tags = <List<String>>[];

          final result = await tagger.addTags(
            tags,
            proof: _proof,
            localVideoPath: '/tmp/test.mp4',
          );

          expect(attestation.proofHash, 'abc123def456');
          expect(attestation.pubkeyHex, 'signer-pubkey');
          expect(
            _tag(tags, 'device_attestation'),
            ['device_attestation', 'attestation-for-signer'],
          );
          expect(
            jsonDecode(_tag(tags, 'proofmode')[1])['deviceAttestation'],
            'attestation-for-signer',
          );
          expect(result.attestedPubkeyHex, 'signer-pubkey');
        },
      );

      test('drops a stale attestation when the mint fails on iOS', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tagger = ProofModePublishTagger(
          iosDeviceAttestation: _RecordingAttestationService(),
          currentPubkeyHex: () => 'signer-pubkey',
        );
        final tags = <List<String>>[];

        final result = await tagger.addTags(
          tags,
          proof: _proof,
          localVideoPath: '/tmp/test.mp4',
        );

        expect(_hasTag(tags, 'device_attestation'), isFalse);
        expect(
          jsonDecode(_tag(tags, 'proofmode')[1])['deviceAttestation'],
          isNull,
        );
        expect(result.attestedPubkeyHex, isNull);
      });

      test(
        'drops the attestation when the account switches mid-mint',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          var pubkey = 'account-a';
          final tagger = ProofModePublishTagger(
            iosDeviceAttestation: _RecordingAttestationService(
              payload: 'attestation-for-account-a',
              onAfterAttestation: () => pubkey = 'account-b',
            ),
            currentPubkeyHex: () => pubkey,
          );
          final tags = <List<String>>[];

          final result = await tagger.addTags(
            tags,
            proof: _proof,
            localVideoPath: '/tmp/test.mp4',
          );

          expect(_hasTag(tags, 'device_attestation'), isFalse);
          expect(result.attestedPubkeyHex, isNull);
        },
      );

      test('publishes no provenance tags when tagging throws', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tagger = ProofModePublishTagger(
          iosDeviceAttestation: _ThrowingAttestationService(),
          currentPubkeyHex: () => 'signer-pubkey',
        );
        final tags = <List<String>>[
          ['d', 'video'],
        ];

        final result = await tagger.addTags(
          tags,
          proof: _proof,
          localVideoPath: '/tmp/test.mp4',
        );

        expect(tags, [
          ['d', 'video'],
        ]);
        expect(result.proof, isNull);
      });

      test('adds identity-discovery tags for a CAWG-bound proof', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tagger = ProofModePublishTagger(
          iosDeviceAttestation: _RecordingAttestationService(),
          currentPubkeyHex: () => 'signer-pubkey',
        );
        final tags = <List<String>>[];

        await tagger.addTags(
          tags,
          proof: const NativeProofData(
            videoHash: 'abc123def456',
            creatorBindingAssertionLabel: 'divine.creator_binding',
            cawgIdentityAssertionLabel: 'cawg.identity',
            verifiedIdentityBundleJson: '{"issuer":"https://verifier.example"}',
          ),
          localVideoPath: '/tmp/test.mp4',
        );

        expect(
          tags.where((tag) => tag.first.startsWith('identity_')),
          equals([
            ['identity_binding', 'nostr_creator'],
            ['identity_portable', 'cawg'],
            ['identity_verifier', 'https://verifier.example'],
          ]),
        );
      });
    });

    group('clearDeviceAttestationTags', () {
      test('re-renders proof tags without the attestation', () {
        final tagger = ProofModePublishTagger(
          iosDeviceAttestation: _RecordingAttestationService(),
          currentPubkeyHex: () => null,
        );
        final tags = <List<String>>[
          ['d', 'video'],
          ['verification', 'verified_mobile'],
          ['proofmode', jsonEncode(_proof.toJson())],
          ['device_attestation', 'attestation-from-generation'],
          ['pgp_fingerprint', 'fingerprint'],
        ];

        tagger.clearDeviceAttestationTags(tags, proof: _proof);

        expect(_hasTag(tags, 'device_attestation'), isFalse);
        expect(
          jsonDecode(_tag(tags, 'proofmode')[1])['deviceAttestation'],
          isNull,
        );
        expect(_tag(tags, 'verification'), ['verification', 'verified_web']);
        expect(_tag(tags, 'pgp_fingerprint'), [
          'pgp_fingerprint',
          'fingerprint',
        ]);
        expect(_tag(tags, 'd'), ['d', 'video']);
      });
    });
  });
}
