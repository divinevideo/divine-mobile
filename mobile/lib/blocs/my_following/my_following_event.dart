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

/// A follow or unfollow the user chose.
///
/// Sealed so [MyFollowingBloc] handles both in one droppable bucket: a Follow
/// and an Unfollow never publish the contact list at the same time.
sealed class MyFollowingEditRequested extends MyFollowingEvent {
  const MyFollowingEditRequested(this.pubkey);

  /// The account to follow or unfollow.
  final String pubkey;
}

/// The user tapped Follow on [pubkey]. Always follows; a no-op if the account
/// is already followed.
final class MyFollowingFollowRequested extends MyFollowingEditRequested {
  const MyFollowingFollowRequested(super.pubkey);
}

/// The user confirmed Unfollow on [pubkey]. Always unfollows; a no-op if the
/// account is no longer followed.
final class MyFollowingUnfollowRequested extends MyFollowingEditRequested {
  const MyFollowingUnfollowRequested(super.pubkey);
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
