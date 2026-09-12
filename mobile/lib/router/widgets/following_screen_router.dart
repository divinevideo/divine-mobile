// ABOUTME: Router widget for following screen
// ABOUTME: Decides between MyFollowingScreen and OthersFollowingScreen

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/following/my_following_screen.dart';
import 'package:openvine/screens/following/others_following_screen.dart';

/// Router widget that decides between MyFollowingScreen and OthersFollowingScreen
/// based on whether the pubkey matches the current user.
class FollowingScreenRouter extends ConsumerWidget {
  const FollowingScreenRouter({
    required this.pubkey,
    this.displayName,
    super.key,
  });

  /// Route name for following screen.
  static const routeName = 'following';

  /// Base path for following routes.
  static const String basePath = RoutePaths.followingBase;

  /// Path pattern for following route.
  static const path = '/following/:pubkey';

  /// Build path for a specific user's following list.
  static String pathForPubkey(String pubkey) =>
      RoutePaths.followingForPubkey(pubkey);

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return MyFollowingScreen(displayName: displayName);
    } else {
      return OthersFollowingScreen(pubkey: pubkey, displayName: displayName);
    }
  }
}
