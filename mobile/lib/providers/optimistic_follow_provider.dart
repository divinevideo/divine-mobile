// ABOUTME: Provider for managing optimistic follow state updates
// ABOUTME: Enables immediate UI feedback when following/unfollowing users

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';

/// Tracks optimistic follow states that haven't been confirmed yet
/// Maps pubkey to follow state (true = following, false = not following, null = no optimistic state)
final optimisticFollowStateProvider =
    NotifierProvider<OptimisticFollowNotifier, Map<String, bool>>(
      OptimisticFollowNotifier.new,
    );

class OptimisticFollowNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  /// Set optimistic follow state for a user
  void setOptimisticState(String pubkey, bool isFollowing) {
    state = {...state, pubkey: isFollowing};
  }

  /// Clear optimistic state after server confirmation
  void clearOptimisticState(String pubkey) {
    state = Map.from(state)..remove(pubkey);
  }

  /// Clear all optimistic states
  void clearAll() {
    state = {};
  }
}

/// Provider that combines real follow state with optimistic updates
final isFollowingProvider = Provider.family<bool, String>((ref, pubkey) {
  final socialService = ref.watch(socialServiceProvider);
  final optimisticStates = ref.watch(optimisticFollowStateProvider);

  // Check if we have an optimistic state for this user
  if (optimisticStates.containsKey(pubkey)) {
    return optimisticStates[pubkey]!;
  }

  // Otherwise use the real state from social service
  return socialService.isFollowing(pubkey);
});

/// Enhanced follow/unfollow methods with optimistic updates
final optimisticFollowMethodsProvider = Provider((ref) {
  return OptimisticFollowMethods(ref);
});

class OptimisticFollowMethods {
  OptimisticFollowMethods(this._ref);

  final Ref _ref;

  Future<void> followUser(String pubkey) async {
    final socialService = _ref.read(socialServiceProvider);
    final optimisticNotifier = _ref.read(
      optimisticFollowStateProvider.notifier,
    );

    // Set optimistic state immediately
    optimisticNotifier.setOptimisticState(pubkey, true);

    try {
      // Perform actual follow
      await socialService.followUser(pubkey);

      // Clear optimistic state on success (real state will take over)
      optimisticNotifier.clearOptimisticState(pubkey);
    } catch (e) {
      // Revert optimistic state on failure
      optimisticNotifier.setOptimisticState(pubkey, false);
      rethrow;
    }
  }

  Future<void> unfollowUser(String pubkey) async {
    final socialService = _ref.read(socialServiceProvider);
    final optimisticNotifier = _ref.read(
      optimisticFollowStateProvider.notifier,
    );

    // Set optimistic state immediately
    optimisticNotifier.setOptimisticState(pubkey, false);

    try {
      // Perform actual unfollow
      await socialService.unfollowUser(pubkey);

      // Clear optimistic state on success (real state will take over)
      optimisticNotifier.clearOptimisticState(pubkey);
    } catch (e) {
      // Revert optimistic state on failure
      optimisticNotifier.setOptimisticState(pubkey, true);
      rethrow;
    }
  }
}
