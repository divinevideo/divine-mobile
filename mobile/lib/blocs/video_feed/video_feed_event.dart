// ABOUTME: Events for VideoFeedBloc - unified feed with mode switching
// ABOUTME: Supports For You, Following, and New (latest) feed modes

part of 'video_feed_bloc.dart';

/// Base class for all video feed events.
sealed class VideoFeedEvent extends Equatable {
  const VideoFeedEvent();
}

/// Start the video feed with a specific mode.
///
/// Dispatched when the feed screen initializes. Triggers initial
/// data loading for the specified [mode]. If a mode was previously persisted
/// to SharedPreferences, the bloc will restore that mode instead, unless
/// [forceMode] pins the start to [mode].
final class VideoFeedStarted extends VideoFeedEvent {
  const VideoFeedStarted({this.mode = FeedMode.forYou, this.forceMode = false});

  /// The feed mode to start with.
  final FeedMode mode;

  /// Whether [mode] must win over the persisted account-scoped source.
  ///
  /// The campaign landing route (`/following/new`) has to render the
  /// Following feed regardless of the account's saved home source, and it
  /// must not write the forced choice back: opening a campaign push cannot
  /// silently change the user's home feed. The normal restore-and-persist
  /// path runs only when this is false.
  final bool forceMode;

  @override
  List<Object?> get props => [mode, forceMode];
}

/// Switch to a different feed mode.
///
/// Triggers loading of videos for the new mode. Previous videos
/// are cleared and fresh data is fetched.
final class VideoFeedModeChanged extends VideoFeedEvent {
  const VideoFeedModeChanged(this.mode);

  /// The new feed mode to switch to.
  final FeedMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Switch to a different typed feed source.
///
/// Triggers loading of videos for the new source. Previous videos are cleared
/// and fresh data is fetched.
final class VideoFeedSourceChanged extends VideoFeedEvent {
  const VideoFeedSourceChanged(this.source);

  /// The new feed source to switch to.
  final VideoFeedSource source;

  @override
  List<Object?> get props => [source];
}

/// Request to load more videos (pagination).
///
/// Only effective when in [VideoFeedStatus.success] state and
/// [hasMore] is true. Uses cursor-based pagination via the
/// oldest video's createdAt timestamp.
final class VideoFeedLoadMoreRequested extends VideoFeedEvent {
  const VideoFeedLoadMoreRequested();

  @override
  List<Object?> get props => [];
}

/// Request to refresh the current feed.
///
/// Clears existing videos and fetches fresh data from the beginning.
/// Used for pull-to-refresh functionality.
final class VideoFeedRefreshRequested extends VideoFeedEvent {
  const VideoFeedRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// Request an auto-refresh of the home feed.
///
/// Dispatched by the UI on app resume (background → foreground).
/// The bloc will only perform the refresh if:
/// - The current feed source type is [VideoFeedSourceType.following] or
///   [VideoFeedSourceType.forYou]
/// - Enough time has passed since the last successful load
///
/// Refreshing For You on resume addresses the "feed stays the same after
/// reopening the app" report (issue #3861).
final class VideoFeedAutoRefreshRequested extends VideoFeedEvent {
  const VideoFeedAutoRefreshRequested();

  @override
  List<Object?> get props => [];
}

/// The following list changed.
///
/// Dispatched internally when the [FollowRepository.followingStream]
/// emits a new list. Triggers a refresh of the home feed so the user
/// sees videos from their updated following list.
final class VideoFeedFollowingListChanged extends VideoFeedEvent {
  const VideoFeedFollowingListChanged(this.followingPubkeys);

  /// The updated list of followed pubkeys.
  final List<String> followingPubkeys;

  @override
  List<Object?> get props => [followingPubkeys];
}

/// The subscribed curated lists changed.
///
/// Dispatched internally when the [CuratedListRepository.subscribedListsStream]
/// emits updated lists. Triggers a refresh of the home feed so list videos
/// are merged in.
final class VideoFeedCuratedListsChanged extends VideoFeedEvent {
  const VideoFeedCuratedListsChanged([this.subscribedLists = const []]);

  /// Updated subscribed curated lists.
  final List<CuratedList> subscribedLists;

  @override
  List<Object?> get props => [subscribedLists];
}

/// The active (visible) video changed as the user swipes the feed.
///
/// Dispatched by the UI on each page change. The bloc records the index in
/// state so it can splice fresh results in *after* the active video, and
/// persists it so the position can be restored on the next cold start.
final class VideoFeedActiveIndexChanged extends VideoFeedEvent {
  const VideoFeedActiveIndexChanged(this.index);

  /// The index of the now-active video in the feed.
  final int index;

  @override
  List<Object?> get props => [index];
}

/// Full Nostr tags arrived for REST-sourced feed videos.
final class VideoFeedEnrichmentReady extends VideoFeedEvent {
  const VideoFeedEnrichmentReady({
    required this.source,
    required this.enrichedVideos,
    required this.sourceIds,
  });

  /// Feed source that requested enrichment.
  final VideoFeedSource source;

  /// Enriched videos returned by the injected enrichment function.
  final List<VideoEvent> enrichedVideos;

  /// IDs present in the source snapshot that was enriched.
  final Set<String> sourceIds;

  @override
  List<Object?> get props => [source, enrichedVideos, sourceIds];
}

/// A user was blocked or the blocklist changed.
///
/// When [blockedPubkey] is provided, the handler removes that user's videos
/// from the current state without a network round-trip. When null, the handler
/// filters current videos against the full blocklist in-memory.
final class VideoFeedBlocklistChanged extends VideoFeedEvent {
  const VideoFeedBlocklistChanged({this.blockedPubkey});

  /// The pubkey that was just blocked, or null for a general blocklist change.
  final String? blockedPubkey;

  @override
  List<Object?> get props => [blockedPubkey];
}

/// Dispatched when the user commits a feed-tuning swipe on [videoId]
/// ("more"/"less like this").
final class VideoFeedTuningSwipeCommitted extends VideoFeedEvent {
  const VideoFeedTuningSwipeCommitted({
    required this.videoId,
    required this.direction,
  });

  /// Event ID of the swiped video.
  final String videoId;

  /// Swipe direction — more or less like this.
  final FeedTuningDirection direction;

  @override
  List<Object?> get props => [videoId, direction];
}

/// Dispatched when the user taps Undo on a just-published tuning signal.
final class VideoFeedTuningUndoRequested extends VideoFeedEvent {
  const VideoFeedTuningUndoRequested(this.feedTuningEventId);

  /// Event ID of the feed-tuning event to retract.
  final String feedTuningEventId;

  @override
  List<Object?> get props => [feedTuningEventId];
}
