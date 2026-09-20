// ABOUTME: Events for VideoEngagementBloc.

part of 'video_engagement_bloc.dart';

/// Base class for events handled by [VideoEngagementBloc].
sealed class VideoEngagementEvent extends Equatable {
  const VideoEngagementEvent();

  @override
  List<Object?> get props => const [];
}

/// Request the engagement list to be (re)loaded from the start.
final class VideoEngagementLoadRequested extends VideoEngagementEvent {
  const VideoEngagementLoadRequested();
}

/// Request the next page of the engagement list.
///
/// Ignored unless [VideoEngagementState.hasMore] is true and no page request
/// is already in flight. After a failed page this only proceeds when [retry]
/// is set, so the view can trigger freely from its item builder without
/// re-firing on the rebuild a failure causes (#9358).
final class VideoEngagementLoadMoreRequested extends VideoEngagementEvent {
  const VideoEngagementLoadMoreRequested({this.retry = false});

  /// Whether this came from an explicit user retry rather than scrolling.
  final bool retry;

  @override
  List<Object?> get props => [retry];
}
