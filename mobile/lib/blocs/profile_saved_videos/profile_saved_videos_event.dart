// ABOUTME: Events for the ProfileSavedVideosBloc
// ABOUTME: Defines actions for syncing and paginating saved (bookmarked) videos

part of 'profile_saved_videos_bloc.dart';

/// Base class for all profile saved videos events.
sealed class ProfileSavedVideosEvent {
  const ProfileSavedVideosEvent();
}

/// Request to load saved bookmark IDs from [BookmarksRepository] and fetch the
/// first page of videos.
final class ProfileSavedVideosSyncRequested extends ProfileSavedVideosEvent {
  const ProfileSavedVideosSyncRequested({this.completer});

  /// Optional completion signal for UI refresh affordances, completed once the
  /// handler is fully done — snapshot write included. See
  /// [completeProfileTabSync].
  final Completer<void>? completer;
}

/// Request to load more saved videos (pagination).
///
/// Fetches the next batch of videos from the existing [savedEventIds] list.
/// Only effective after initial sync has completed.
final class ProfileSavedVideosLoadMoreRequested
    extends ProfileSavedVideosEvent {
  const ProfileSavedVideosLoadMoreRequested();
}

/// Internal: the bookmark list changed while the grid was showing.
///
/// Dispatched from the bloc's own subscription to the bookmarks repository;
/// [savedEventIds] is the new list in reverse repository order.
final class ProfileSavedVideosReconcileRequested
    extends ProfileSavedVideosEvent {
  const ProfileSavedVideosReconcileRequested(this.savedEventIds);

  final List<String> savedEventIds;
}

/// Internal: drop a video after the deletion bus reports it removed.
final class ProfileSavedVideosVideoRemoved extends ProfileSavedVideosEvent {
  const ProfileSavedVideosVideoRemoved(this.videoId);

  final String videoId;
}
