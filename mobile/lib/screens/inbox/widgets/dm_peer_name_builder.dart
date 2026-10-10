// ABOUTME: Names any DM participant through the shared peer naming chain.
// ABOUTME: A group thread's title names the room, so a message or a preview
// ABOUTME: that needs its author resolves that pubkey on its own.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';

/// How a DM participant is named right now.
class DmPeerNameResolution {
  const DmPeerNameResolution({required this.name, required this.visualName});

  /// The name every DM surface agrees on, empty while the identity resolves.
  ///
  /// Empty rather than a generated "Adjective Animal N" so a placeholder is
  /// never presented, or read aloud, as the person's real identity.
  final String name;

  /// [name], or a generated stand-in while the identity resolves.
  ///
  /// Only for sizing a skeleton; it must not be shown as the person's name.
  final String visualName;

  bool get isResolving => name.isEmpty;
}

/// Names [pubkey] the way the thread header, the inbox row and the reactors
/// sheet do: vanished, moderation, profile, then the generated fallback.
///
/// Call it from a build method — it watches the providers behind the chain, so
/// the caller rebuilds when a profile arrives or an account vanishes.
DmPeerNameResolution watchDmPeerName(
  BuildContext context,
  WidgetRef ref,
  String pubkey,
) {
  final profile = ref.watch(fetchUserProfileProvider(pubkey)).asData?.value;
  final isResolving = ref.watch(profileIdentityResolvingProvider(pubkey));
  final isVanished = ref.watch(profileVanishedProvider(pubkey));
  final moderation = ref.watch(moderationPresentationProvider(pubkey));

  final name = dmPeerDisplayName(
    context,
    pubkeyHex: pubkey,
    isVanished: isVanished,
    moderation: moderation,
    profile: profile,
    isResolving: isResolving,
  );
  return DmPeerNameResolution(
    name: name,
    visualName: name.isEmpty ? UserProfile.defaultDisplayNameFor(pubkey) : name,
  );
}

/// Hands [builder] the name of [pubkey], resolved by [watchDmPeerName].
class DmPeerNameBuilder extends ConsumerWidget {
  const DmPeerNameBuilder({
    required this.pubkey,
    required this.builder,
    super.key,
  });

  final String pubkey;
  final Widget Function(BuildContext context, DmPeerNameResolution name)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      builder(context, watchDmPeerName(context, ref, pubkey));
}
