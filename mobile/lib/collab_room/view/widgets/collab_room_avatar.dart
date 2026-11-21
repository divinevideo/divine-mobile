// ABOUTME: A room member's avatar, read from their profile by pubkey
// ABOUTME: Shared by the room screen, the Together tab and the invite card

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// The avatar of [pubkey], from their cached profile.
class CollabRoomAvatar extends ConsumerWidget {
  /// Creates an avatar of [size].
  const CollabRoomAvatar({required this.pubkey, this.size = 40, super.key});

  /// Whose avatar.
  final String pubkey;

  /// Diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    return UserAvatar(
      imageUrl: profile?.picture,
      name: profile?.bestDisplayName,
      placeholderSeed: pubkey,
      size: size,
    );
  }
}
