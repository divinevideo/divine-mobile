// ABOUTME: Resolves the link a profile's Share button sends, shared by the
// ABOUTME: own-profile and other-profile screens so both apply one rule.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// The URL a profile is shared under.
///
/// A Divine username becomes its subdomain URL only once that exact claim
/// verifies. Anything else, including an external NIP-05, falls back to the
/// npub profile URL without a verification lookup.
Future<String> resolveProfileShareUrl(
  WidgetRef ref, {
  required String pubkey,
  required UserProfile? profile,
}) async {
  final npub = NostrKeyUtils.encodePubKey(pubkey);
  final claim = profile?.divineUsername == null ? null : profile?.nip05;
  if (claim == null) return buildProfileUrl(null, npub);

  final status = await ref.read(
    nip05ClaimVerificationProvider(
      Nip05Claim(pubkey: pubkey, nip05: claim),
    ).future,
  );
  return buildProfileUrl(
    status == Nip05VerificationStatus.verified ? profile?.displayNip05 : null,
    npub,
  );
}
