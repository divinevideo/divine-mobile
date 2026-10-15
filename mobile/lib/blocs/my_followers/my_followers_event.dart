// ABOUTME: Events for MyFollowersBloc
// ABOUTME: Defines actions for loading and follow-back operations

part of 'my_followers_bloc.dart';

/// Base class for all my followers list events
sealed class MyFollowersEvent {
  const MyFollowersEvent();
}

/// Request to load current user's followers list.
final class MyFollowersListLoadRequested extends MyFollowersEvent {
  const MyFollowersListLoadRequested();
}

/// Notification that the blocklist has changed, requiring re-filtering.
final class MyFollowersBlocklistChanged extends MyFollowersEvent {
  const MyFollowersBlocklistChanged();
}

/// Request to present the loaded followers in [sortOrder].
///
/// Re-orders what is already in state; it does not refetch.
final class MyFollowersSortOrderChanged extends MyFollowersEvent {
  const MyFollowersSortOrderChanged(this.sortOrder);

  /// The order the user picked.
  final FollowListSort sortOrder;
}
