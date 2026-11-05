// ABOUTME: ProofMode helper utilities for converting video event data to verification levels
// ABOUTME: Maps raw Nostr event tags to UI-friendly verification badge levels

import 'package:models/models.dart';

/// Verification tier for "Human Made" badge display.
///
/// Tiers reflect the strength of evidence that a video is authentic:
/// - [platinum]: Device proof + AI scan confirms human
/// - [gold]: Device attestation + ProofMode + C2PA (hardware proof)
/// - [silver]: Web crypto proof, or AI scan confirms likely human
/// - [bronze]: Basic proof data present
/// - [unverified]: No proof data available
enum VerificationLevel {
  platinum,
  verifiedMobile,
  verifiedWeb,
  basicProof,
  unverified,
}

/// Extension to get verification level from VideoEvent
extension ProofModeHelpers on VideoEvent {
  /// Get the appropriate verification level for badge display
  VerificationLevel getVerificationLevel() {
    if (isVerifiedMobile) {
      return VerificationLevel.verifiedMobile;
    } else if (isVerifiedWeb) {
      return VerificationLevel.verifiedWeb;
    } else if (hasBasicProof) {
      return VerificationLevel.basicProof;
    } else {
      return VerificationLevel.unverified;
    }
  }

  /// Should show ProofMode badge.
  ///
  /// Archive Vines funnelcake verifies never show it. A self-applied
  /// `platform=vine` tag does not count as verification.
  bool get shouldShowProofModeBadge {
    return hasProofMode && !isVerifiedArchive;
  }
}
