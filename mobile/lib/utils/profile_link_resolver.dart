// ABOUTME: Adapts existing ownership providers to the shared link resolver.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:profile_repository/profile_repository.dart';

ProfileLinkResolver profileLinkResolverFor(WidgetRef ref) {
  final repository = ref.read(profileReadRepositoryProvider);
  return ProfileLinkResolver(
    verifyClaim: (pubkey, claim) async =>
        await ref.read(
          nip05ClaimVerificationProvider(
            Nip05Claim(pubkey: pubkey, nip05: claim),
          ).future,
        ) ==
        Nip05VerificationStatus.verified,
    lookupUsername: (pubkey) async =>
        await repository?.lookupUsernameByPubkey(pubkeyHex: pubkey) ??
        const DivineUsernameUnknown(),
  );
}
