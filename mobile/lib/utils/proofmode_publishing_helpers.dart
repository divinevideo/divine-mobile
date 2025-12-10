// ABOUTME: Helper functions for publishing ProofMode data to Nostr events
// ABOUTME: Extracts verification levels and creates Nostr tags from NativeProofData

import 'dart:convert';
import 'package:models/models.dart' show NativeProofData;

/// Extract proof-verification-level from NativeProofData
///
/// Returns one of:
/// - 'verified_mobile': has device attestation + signature
/// - 'verified_web': has signature (no hardware attestation)
/// - 'basic_proof': has some proof data but no signature
/// - 'unverified': no meaningful proof data
String getVerificationLevel(NativeProofData proofData) {
  return proofData.verificationLevel;
}

/// Create proof-manifest tag value (compact JSON)
///
/// Serializes the entire NativeProofData to JSON for inclusion in Nostr events
String createProofManifestTag(NativeProofData proofData) {
  return jsonEncode(proofData.toJson());
}

/// Create proof-device-attestation tag value
///
/// Returns the device attestation token if available, null otherwise
String? createDeviceAttestationTag(NativeProofData proofData) {
  return proofData.deviceAttestation;
}

/// Create proof-pgp-fingerprint tag value
///
/// Returns the PGP public key fingerprint if available, null otherwise
String? createPgpFingerprintTag(NativeProofData proofData) {
  return proofData.pgpFingerprint;
}
