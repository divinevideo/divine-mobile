// ABOUTME: Privacy-preserving lookup for server-computed OG Diviner eligibility.
// ABOUTME: Reuses the profile repository's server-owned eligibility answers.

import 'package:profile_repository/profile_repository.dart';

class OgDivinerEligibilityService {
  OgDivinerEligibilityService({required ProfileReader profiles})
    : _profiles = profiles;

  final ProfileReader _profiles;

  Future<bool> isEligible(String pubkey) {
    final normalized = pubkey.trim().toLowerCase();
    if (normalized.isEmpty) return Future.value(false);

    return _profiles.isOgDiviner(normalized);
  }
}
