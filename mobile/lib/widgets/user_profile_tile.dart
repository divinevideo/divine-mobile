// ABOUTME: Reusable tile widget for displaying user profile information in lists
// ABOUTME: Shows avatar, name, and follow button with tap handling for navigation

import 'package:openvine/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';

class UserProfileTile extends ConsumerWidget {
  const UserProfileTile({
    super.key,
    required this.pubkey,
    this.onTap,
    this.showFollowButton = true,
  });

  final String pubkey;
  final VoidCallback? onTap;
  final bool showFollowButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;

    return FutureBuilder(
      future: userProfileService.fetchProfile(pubkey),
      builder: (context, snapshot) {
        final profile = userProfileService.getCachedProfile(pubkey);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: onTap,
                child: UserAvatar(
                  imageUrl: profile?.picture,
                  name: profile?.bestDisplayName,
                  size: 48,
                ),
              ),
              const SizedBox(width: 12),

              // Name and details
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.bestDisplayName ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profile?.about != null && profile!.about!.isNotEmpty)
                        Text(
                          profile.about!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),

              // Follow button
              if (showFollowButton && !isCurrentUser) ...[
                const SizedBox(width: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final isFollowing = ref.watch(isFollowingProvider(pubkey));

                    return SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () =>
                            _toggleFollow(context, ref, pubkey, isFollowing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.white
                              : VineTheme.vineGreen,
                          foregroundColor: isFollowing
                              ? VineTheme.vineGreen
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    String pubkey,
    bool isCurrentlyFollowing,
  ) async {
    await FollowActionsHelper.toggleFollow(
      ref: ref,
      context: context,
      pubkey: pubkey,
      isCurrentlyFollowing: isCurrentlyFollowing,
      contextName: 'UserProfileTile',
    );
  }
}
