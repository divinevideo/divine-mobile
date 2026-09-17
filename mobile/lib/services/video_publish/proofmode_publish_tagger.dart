// ABOUTME: Adds ProofMode / C2PA provenance tags to a video event before signing
// ABOUTME: Mints the publish-time device attestation and strips it on an account switch

import 'dart:convert';

import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/ios_device_attestation_service.dart';
import 'package:openvine/utils/proofmode_publishing_helpers.dart';
import 'package:unified_logger/unified_logger.dart';

/// What [ProofModePublishTagger.addTags] left in the tag list.
///
/// [proof] is the proof the tags were rendered from — carrying the freshly
/// minted device attestation, if any — and [attestedPubkeyHex] the account
/// that attestation was bound to. Both are `null` when tagging failed before
/// a proof was chosen. The signing step compares [attestedPubkeyHex] with the
/// account that is about to sign and calls
/// [ProofModePublishTagger.clearDeviceAttestationTags] when they differ.
class ProofModeTagResult {
  const ProofModeTagResult({this.proof, this.attestedPubkeyHex});

  static const ProofModeTagResult none = ProofModeTagResult();

  final NativeProofData? proof;
  final String? attestedPubkeyHex;
}

typedef _PublishDeviceAttestation = ({
  NativeProofData proof,
  String? attestedPubkeyHex,
});

/// Renders a [NativeProofData] into the NIP-145 provenance tags of a video
/// event: `c2pa_manifest_id`, `verification`, `proofmode`,
/// `device_attestation`, `pgp_fingerprint`, and the identity-discovery tags
/// a CAWG or creator-binding assertion earns.
///
/// Tag generation is best-effort: a failure is logged and the video still
/// publishes without provenance tags.
class ProofModePublishTagger {
  ProofModePublishTagger({
    required IosDeviceAttestationService iosDeviceAttestation,
    required String? Function() currentPubkeyHex,
    C2paSigningService Function()? c2paSigningServiceFactory,
  }) : _iosDeviceAttestation = iosDeviceAttestation,
       _currentPubkeyHex = currentPubkeyHex,
       _c2paSigningServiceFactory =
           c2paSigningServiceFactory ?? C2paSigningService.new;

  static const String _logName = 'ProofModePublishTagger';

  final IosDeviceAttestationService _iosDeviceAttestation;

  /// Reads the pubkey of the account that will sign the event. Sampled at
  /// call time rather than captured, because the attestation must bind to
  /// the account that actually signs.
  final String? Function() _currentPubkeyHex;
  final C2paSigningService Function() _c2paSigningServiceFactory;

  /// Appends the provenance tags for [proof] to [tags].
  ///
  /// [localVideoPath] is read for an embedded C2PA manifest. Returns the
  /// proof the tags were rendered from so a later account switch can strip
  /// the attestation again; see [ProofModeTagResult].
  Future<ProofModeTagResult> addTags(
    List<List<String>> tags, {
    required NativeProofData proof,
    required String localVideoPath,
  }) async {
    NativeProofData? proofUsedForTags;
    String? attestedPubkeyHex;
    try {
      Log.info(
        '📜 Adding ProofMode verification tags to Nostr event',
        name: _logName,
        category: LogCategory.video,
      );

      final attestationResult = await _withPublishDeviceAttestation(proof);
      final nativeProof = attestationResult.proof;
      proofUsedForTags = nativeProof;
      attestedPubkeyHex = attestationResult.attestedPubkeyHex;

      final manifestInfo = await _c2paSigningServiceFactory().readManifest(
        localVideoPath,
      );
      if (manifestInfo?.validationStatus != null) {
        tags.add(['c2pa_manifest_id', ?manifestInfo?.activeManifest]);
        Log.verbose(
          'Added c2pa_manifest_id tag: ${manifestInfo?.activeManifest}',
          name: _logName,
          category: LogCategory.video,
        );
      }

      // Add verification level tag (NIP-145)
      final verificationLevel = getVerificationLevel(nativeProof);
      tags.add(['verification', verificationLevel]);
      Log.verbose(
        'Added verification tag: $verificationLevel',
        name: _logName,
        category: LogCategory.video,
      );

      // Add ProofMode native proof tag (complete JSON proof data)
      final proofTag = createProofManifestTag(nativeProof);
      tags.add(['proofmode', proofTag]);
      Log.verbose(
        'Added proofmode proof tag (${proofTag.length} chars)',
        name: _logName,
        category: LogCategory.video,
      );

      // Add device attestation tag if available (NIP-145)
      final deviceTag = createDeviceAttestationTag(nativeProof);
      if (deviceTag != null) {
        tags.add(['device_attestation', deviceTag]);
        Log.verbose(
          'Added device_attestation tag',
          name: _logName,
          category: LogCategory.video,
        );
      }

      // Add PGP fingerprint tag if available (NIP-145)
      final pgpTag = createPgpFingerprintTag(nativeProof);
      if (pgpTag != null) {
        tags.add(['pgp_fingerprint', pgpTag]);
        Log.verbose(
          'Added pgp_fingerprint tag: $pgpTag',
          name: _logName,
          category: LogCategory.video,
        );
      }

      _addIdentityDiscoveryTags(tags, nativeProof);

      Log.info(
        '✅ ProofMode verification tags added successfully',
        name: _logName,
        category: LogCategory.video,
      );
    } catch (e) {
      // Continue publishing even if ProofMode tag generation fails
      Log.error(
        'Failed to add ProofMode tags: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return ProofModeTagResult(
      proof: proofUsedForTags,
      attestedPubkeyHex: attestedPubkeyHex,
    );
  }

  /// Re-renders the `proofmode` and `verification` tags from [proof] with
  /// its device attestation removed, and drops the `device_attestation` tag.
  ///
  /// Called when the signing account changed after [addTags] minted an
  /// attestation for a different one.
  void clearDeviceAttestationTags(
    List<List<String>> tags, {
    required NativeProofData proof,
  }) {
    final clearedProof = proof.withDeviceAttestation(null);

    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i];
      if (tag.isEmpty) continue;

      switch (tag[0]) {
        case 'proofmode':
          tags[i] = ['proofmode', createProofManifestTag(clearedProof)];
        case 'verification':
          tags[i] = ['verification', getVerificationLevel(clearedProof)];
      }
    }

    tags.removeWhere((tag) => tag.isNotEmpty && tag[0] == 'device_attestation');
    Log.warning(
      'Signing account changed before event signing - publishing without '
      'device attestation',
      name: _logName,
      category: LogCategory.video,
    );
  }

  /// Returns [proof] carrying the device attestation this publish should
  /// broadcast.
  ///
  /// On iOS the payload is minted here rather than at proof generation, because
  /// only now is the publishing account fixed — the challenge binds it, and the
  /// App Attest key is scoped to it. That makes the value computed here
  /// authoritative: it replaces whatever the stored proof carried, so a token
  /// left behind for a different account cannot ride along. Platforms that
  /// attest during generation keep what they produced.
  Future<_PublishDeviceAttestation> _withPublishDeviceAttestation(
    NativeProofData proof,
  ) async {
    if (!IosDeviceAttestationService.handlesPublishTimeAttestation) {
      return (proof: proof, attestedPubkeyHex: null);
    }

    final pubkeyHex = _currentPubkeyHex();
    if (pubkeyHex == null) {
      Log.warning(
        'No signing pubkey available - publishing without device attestation',
        name: _logName,
        category: LogCategory.video,
      );
      return (
        proof: proof.withDeviceAttestation(null),
        attestedPubkeyHex: null,
      );
    }

    final attestation = await _iosDeviceAttestation.attestationFor(
      proofHash: proof.videoHash,
      pubkeyHex: pubkeyHex,
    );

    if (attestation == null) {
      return (
        proof: proof.withDeviceAttestation(null),
        attestedPubkeyHex: null,
      );
    }

    if (_currentPubkeyHex() != pubkeyHex) {
      Log.warning(
        'Signing account changed while minting device attestation - '
        'publishing without device attestation',
        name: _logName,
        category: LogCategory.video,
      );
      return (
        proof: proof.withDeviceAttestation(null),
        attestedPubkeyHex: null,
      );
    }

    return (
      proof: proof.withDeviceAttestation(attestation),
      attestedPubkeyHex: pubkeyHex,
    );
  }

  void _addIdentityDiscoveryTags(
    List<List<String>> tags,
    NativeProofData nativeProof,
  ) {
    if (_hasCreatorBinding(nativeProof)) {
      tags.add(['identity_binding', 'nostr_creator']);
    }

    if (_hasPortableIdentity(nativeProof)) {
      tags.add(['identity_portable', 'cawg']);
    }

    final verifier = _extractIdentityVerifier(
      nativeProof.verifiedIdentityBundleJson,
    );
    if (verifier != null && verifier.isNotEmpty) {
      tags.add(['identity_verifier', verifier]);
    }
  }

  static bool _hasCreatorBinding(NativeProofData nativeProof) =>
      (nativeProof.creatorBindingAssertionLabel?.isNotEmpty ?? false) ||
      (nativeProof.creatorBindingPayloadJson?.isNotEmpty ?? false);

  static bool _hasPortableIdentity(NativeProofData nativeProof) =>
      nativeProof.cawgIdentityAssertionLabel == 'cawg.identity' ||
      (nativeProof.verifiedIdentityBundleJson?.isNotEmpty ?? false);

  static String? _extractIdentityVerifier(String? verifiedIdentityBundleJson) {
    if (verifiedIdentityBundleJson == null ||
        verifiedIdentityBundleJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(verifiedIdentityBundleJson);
      if (decoded is Map) {
        return decoded['issuer']?.toString();
      }
    } catch (error) {
      Log.warning(
        'Failed to parse verifier identity bundle: $error',
        name: _logName,
        category: LogCategory.video,
      );
    }

    return null;
  }
}
