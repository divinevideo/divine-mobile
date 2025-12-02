// ABOUTME: Shared helper class for follow/unfollow actions with optimistic UI updates
// ABOUTME: Provides consistent follow/unfollow behavior across all screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Helper class for consistent follow/unfollow actions across the app
class FollowActionsHelper {
  /// Toggle follow state for a user with optimistic UI updates
  static Future<void> toggleFollow({
    required WidgetRef ref,
    required BuildContext context,
    required String pubkey,
    required bool isCurrentlyFollowing,
    String? contextName,
  }) async {
    final authService = ref.read(authServiceProvider);

    // Check authentication
    if (!authService.isAuthenticated) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing
                  ? 'Please login to unfollow users'
                  : 'Please login to follow users',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final optimisticMethods = ref.read(optimisticFollowMethodsProvider);

      if (isCurrentlyFollowing) {
        await _unfollowUser(
          optimisticMethods: optimisticMethods,
          pubkey: pubkey,
          context: context,
          contextName: contextName,
        );
      } else {
        await _followUser(
          optimisticMethods: optimisticMethods,
          pubkey: pubkey,
          context: context,
          contextName: contextName,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle follow state: $e',
        name: contextName ?? 'FollowActionsHelper',
        category: LogCategory.ui,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing
                  ? 'Failed to unfollow user: ${e.toString()}'
                  : 'Failed to follow user: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Follow a user with optimistic UI updates
  static Future<void> followUser({
    required WidgetRef ref,
    required BuildContext context,
    required String pubkey,
    String? contextName,
  }) async {
    final authService = ref.read(authServiceProvider);

    if (!authService.isAuthenticated) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to follow users'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final optimisticMethods = ref.read(optimisticFollowMethodsProvider);
      await _followUser(
        optimisticMethods: optimisticMethods,
        pubkey: pubkey,
        context: context,
        contextName: contextName,
      );
    } catch (e) {
      Log.error(
        'Failed to follow user: $e',
        name: contextName ?? 'FollowActionsHelper',
        category: LogCategory.ui,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Unfollow a user with optimistic UI updates
  static Future<void> unfollowUser({
    required WidgetRef ref,
    required BuildContext context,
    required String pubkey,
    String? contextName,
  }) async {
    final authService = ref.read(authServiceProvider);

    if (!authService.isAuthenticated) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to unfollow users'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final optimisticMethods = ref.read(optimisticFollowMethodsProvider);
      await _unfollowUser(
        optimisticMethods: optimisticMethods,
        pubkey: pubkey,
        context: context,
        contextName: contextName,
      );
    } catch (e) {
      Log.error(
        'Failed to unfollow user: $e',
        name: contextName ?? 'FollowActionsHelper',
        category: LogCategory.ui,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfollow user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Private helper methods
  static Future<void> _followUser({
    required OptimisticFollowMethods optimisticMethods,
    required String pubkey,
    required BuildContext context,
    String? contextName,
  }) async {
    await optimisticMethods.followUser(pubkey);

    Log.info(
      '👤 Followed user: ${pubkey}...',
      name: contextName ?? 'FollowActionsHelper',
      category: LogCategory.ui,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Text(
                'Successfully followed user',
                style: TextStyle(color: VineTheme.vineGreen),
              ),
            ],
          ),
          backgroundColor: Colors.white,
        ),
      );
    }
  }

  static Future<void> _unfollowUser({
    required OptimisticFollowMethods optimisticMethods,
    required String pubkey,
    required BuildContext context,
    String? contextName,
  }) async {
    await optimisticMethods.unfollowUser(pubkey);

    Log.info(
      '👤 Unfollowed user: ${pubkey}...',
      name: contextName ?? 'FollowActionsHelper',
      category: LogCategory.ui,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Text(
                'Successfully unfollowed user',
                style: TextStyle(color: VineTheme.vineGreen),
              ),
            ],
          ),
          backgroundColor: Colors.white,
        ),
      );
    }
  }
}
