// ABOUTME: Events for MyFollowingBloc
// ABOUTME: Defines actions for loading and follow/unfollow operations

part of 'my_following_bloc.dart';

/// Base class for all my following list events
sealed class MyFollowingEvent {
  const MyFollowingEvent();
}

/// Request to start listening to following list updates.
final class MyFollowingListLoadRequested extends MyFollowingEvent {
  const MyFollowingListLoadRequested();
}

/// Request to toggle follow status for a user.
/// The bloc will determine whether to follow or unfollow based on current state.
final class MyFollowingToggleRequested extends MyFollowingEvent {
  const MyFollowingToggleRequested(this.pubkey, {this.targetVideoId});

  /// The public key of the user to follow/unfollow
  final String pubkey;

  /// Video that supplied the follow affordance, when applicable.
  final String? targetVideoId;
}

/// Notification that the blocklist has changed, requiring re-filtering.
final class MyFollowingBlocklistChanged extends MyFollowingEvent {
  const MyFollowingBlocklistChanged();
}

/// Request to present the loaded following list in [sortOrder].
///
/// Re-orders what is already in state; it does not refetch.
final class MyFollowingSortOrderChanged extends MyFollowingEvent {
  const MyFollowingSortOrderChanged(this.sortOrder);

  /// The order the user picked.
  final FollowSortOrder sortOrder;
}

final class _MyFollowingRepositoryUpdated extends MyFollowingEvent {
  const _MyFollowingRepositoryUpdated(this.pubkeys);

  final List<String> pubkeys;
}
