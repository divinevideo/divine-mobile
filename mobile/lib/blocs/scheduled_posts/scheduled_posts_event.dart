// ABOUTME: Events for ScheduledPostsBloc: the Scheduled section's lifecycle and
// ABOUTME: the actions a user can take on a scheduled post.

part of 'scheduled_posts_bloc.dart';

sealed class ScheduledPostsEvent extends Equatable {
  const ScheduledPostsEvent();

  @override
  List<Object?> get props => [];
}

/// Subscribes to the outbox and asks the relay for its view of the queue.
final class ScheduledPostsStarted extends ScheduledPostsEvent {
  const ScheduledPostsStarted();
}

/// The outbox changed; rebuild the list. Internal.
final class _ScheduledPostsOutboxChanged extends ScheduledPostsEvent {
  const _ScheduledPostsOutboxChanged(this.posts);

  final List<ScheduledPost> posts;

  @override
  List<Object?> get props => [posts];
}

/// Actions on one post. They share a `sequential()` queue so two taps
/// cannot interleave against the same row.
sealed class ScheduledPostsActionEvent extends ScheduledPostsEvent {
  const ScheduledPostsActionEvent(this.eventId);

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

final class ScheduledPostsCancelRequested extends ScheduledPostsActionEvent {
  const ScheduledPostsCancelRequested(super.eventId);
}

final class ScheduledPostsRescheduleRequested
    extends ScheduledPostsActionEvent {
  const ScheduledPostsRescheduleRequested(super.eventId, this.publishAt);

  /// The new publish time (any zone; stored as UTC).
  final DateTime publishAt;

  @override
  List<Object?> get props => [eventId, publishAt];
}

final class ScheduledPostsPublishNowRequested
    extends ScheduledPostsActionEvent {
  const ScheduledPostsPublishNowRequested(super.eventId);
}

final class ScheduledPostsRetryRequested extends ScheduledPostsActionEvent {
  const ScheduledPostsRetryRequested(super.eventId);
}

/// Withdraws a post that was scheduled from another device.
final class ScheduledPostsCancelRemoteRequested
    extends ScheduledPostsActionEvent {
  const ScheduledPostsCancelRemoteRequested(super.eventId);
}
