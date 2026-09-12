// ABOUTME: Router widget for followers screen
// ABOUTME: Decides between MyFollowersScreen and OthersFollowersScreen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/followers/my_followers_screen.dart';
import 'package:openvine/screens/followers/others_followers_screen.dart';

/// Router widget that decides between MyFollowersScreen and OthersFollowersScreen
/// based on whether the pubkey matches the current user.
class FollowersScreenRouter extends ConsumerWidget {
  const FollowersScreenRouter({
    required this.pubkey,
    this.displayName,
    super.key,
  });

  /// Route name for followers screen.
  static const routeName = 'followers';

  /// Base path for followers routes.
  static const String basePath = RoutePaths.followersBase;

  /// Path pattern for followers route.
  static const path = '/followers/:pubkey';

  /// Build path for a specific user's followers.
  static String pathForPubkey(String pubkey) =>
      RoutePaths.followersForPubkey(pubkey);

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return MyFollowersScreen(displayName: displayName);
    } else {
      return OthersFollowersScreen(pubkey: pubkey, displayName: displayName);
    }
  }
}
