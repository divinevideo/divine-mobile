// ABOUTME: ProofMode helper utilities for converting video event data to verification levels
// ABOUTME: Maps raw Nostr event tags to UI-friendly verification badge levels

import 'package:models/models.dart';
import 'package:openvine/widgets/proofmode_badge.dart';

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

  /// Should show ProofMode badge
  bool get shouldShowProofModeBadge {
    return hasProofMode;
  }

  /// Should show original Vine badge
  /// Only show for vintage vines WITHOUT ProofMode (those show ProofMode badge instead)
  bool get shouldShowVineBadge {
    return isOriginalVine && !hasProofMode;
  }
}
