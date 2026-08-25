// ABOUTME: State for VideoFeedBloc - unified feed with mode switching
// ABOUTME: Tracks videos, loading state, pagination, and current feed mode

part of 'video_feed_bloc.dart';

/// Feed modes for the unified video feed.
enum FeedMode {
  /// Personalized recommended videos.
  forYou,

  /// Videos from users the current user follows.
  following,

  /// Legacy persisted restore value. Home no longer exposes this mode.
  latest,

  /// Popular classic Vine archive videos.
  classic,
}

/// Typed source for the home video feed.
enum VideoFeedSourceType {
  /// Personalized recommended videos.
  forYou,

  /// Videos from followed creators.
  following,

  /// Videos from one subscribed curated list.
  subscribedList,

  /// Most recently published videos (chronological).
  newVideos,

  /// Popular classic Vine archive videos.
  classic,
}

extension VideoFeedSourceTypeAnalytics on VideoFeedSourceType {
  /// Stable analytics tag for this source type.
  ///
  /// Published as the third element of the kind-22236 `source` tag, which
  /// funnelcake stores in `view_traffic_sources.source_detail`. The `source`
  /// itself stays `home` for every mode, because a single feed page renders
  /// all of them — without this detail every mode collapses into one `home`
  /// bucket and re-serve rates cannot be attributed to a specific feed.
  ///
  /// These values are persisted analytics data. Renaming one silently splits
  /// its history in two, so add new values rather than repurposing existing
  /// ones.
  ///
  /// [VideoFeedSourceType.subscribedList] deliberately reports the bare `list`
  /// rather than the list id, unlike the hashtag and search-query call sites
  /// that pass their discriminating value. A list id is unbounded in
  /// cardinality and closer to user data than a public hashtag is, and the
  /// question this field answers — which of the five home modes served the
  /// view — is answered without it.
  String get analyticsTag => switch (this) {
    VideoFeedSourceType.forYou => 'foryou',
    VideoFeedSourceType.following => 'following',
    VideoFeedSourceType.subscribedList => 'list',
    VideoFeedSourceType.newVideos => 'new',
    VideoFeedSourceType.classic => 'classic',
  };
}

/// Source selection for [VideoFeedBloc].
final class VideoFeedSource extends Equatable {
  /// Personalized recommended videos.
  const VideoFeedSource.forYou()
    : type = VideoFeedSourceType.forYou,
      listId = null,
      listName = null;

  /// Videos from followed creators.
  const VideoFeedSource.following()
    : type = VideoFeedSourceType.following,
      listId = null,
      listName = null;

  /// Videos from a subscribed curated list.
  const VideoFeedSource.subscribedList({
    required String this.listId,
    required String this.listName,
  }) : type = VideoFeedSourceType.subscribedList;

  /// Most recently published videos (chronological).
  const VideoFeedSource.newVideos()
    : type = VideoFeedSourceType.newVideos,
      listId = null,
      listName = null;

  /// Popular classic Vine archive videos.
  const VideoFeedSource.classic()
    : type = VideoFeedSourceType.classic,
      listId = null,
      listName = null;

  /// Compatibility conversion for legacy mode-based callers.
  factory VideoFeedSource.fromMode(FeedMode mode) => switch (mode) {
    FeedMode.following => const VideoFeedSource.following(),
    FeedMode.forYou => const VideoFeedSource.forYou(),
    FeedMode.latest => const VideoFeedSource.newVideos(),
    FeedMode.classic => const VideoFeedSource.classic(),
  };

  /// The source type.
  final VideoFeedSourceType type;

  /// Selected curated list ID when [type] is subscribedList.
  final String? listId;

  /// Selected curated list name when [type] is subscribedList.
  final String? listName;

  /// Legacy mode projection for compatibility.
  FeedMode get mode => switch (type) {
    VideoFeedSourceType.forYou => FeedMode.forYou,
    VideoFeedSourceType.newVideos => FeedMode.latest,
    VideoFeedSourceType.classic => FeedMode.classic,
    VideoFeedSourceType.following ||
    VideoFeedSourceType.subscribedList => FeedMode.following,
  };

  /// Label fallback for UI surfaces that do not have localized copy.
  String get labelFallback => switch (type) {
    VideoFeedSourceType.forYou => FeedMode.forYou.name,
    VideoFeedSourceType.newVideos => FeedMode.latest.name,
    VideoFeedSourceType.following => FeedMode.following.name,
    VideoFeedSourceType.classic => FeedMode.classic.name,
    VideoFeedSourceType.subscribedList => listName ?? '',
  };

  /// SharedPreferences value for this source.
  String get persistenceValue => switch (type) {
    VideoFeedSourceType.forYou => FeedMode.forYou.name,
    VideoFeedSourceType.newVideos => FeedMode.latest.name,
    VideoFeedSourceType.following => FeedMode.following.name,
    VideoFeedSourceType.classic => FeedMode.classic.name,
    VideoFeedSourceType.subscribedList => 'list:$listId',
  };

  @override
  List<Object?> get props => [type, listId, listName];
}

/// Status of the video feed.
enum VideoFeedStatus {
  /// Currently loading videos.
  loading,

  /// Videos loaded successfully.
  success,

  /// An error occurred while loading videos.
  failure,
}

/// Error types for l10n-friendly error handling.
enum VideoFeedError {
  /// Failed to load videos from network.
  loadFailed,

  /// No followed users (home feed is empty by design).
  noFollowedUsers,
}

/// A just-committed home-feed tuning swipe, surfaced for the UI's Undo
/// snackbar.
final class VideoFeedTuningAction extends Equatable {
  const VideoFeedTuningAction({
    required this.videoId,
    required this.direction,
    required this.sequence,
    this.publishedEventId,
  });

  /// Event ID of the swiped video.
  final String videoId;

  /// The direction that was published.
  final FeedTuningDirection direction;

  /// Monotonic action id so identical consecutive swipes still notify
  /// listeners.
  final int sequence;

  /// Published feed-tuning event id, or `null` when nothing was published.
  final String? publishedEventId;

  @override
  List<Object?> get props => [videoId, direction, sequence, publishedEventId];
}

/// State for the VideoFeedBloc.
///
/// Contains:
/// - [videos]: The list of video events for the current mode
/// - [status]: The current loading status
/// - [mode]: The active feed mode (forYou, following, latest)
/// - [hasMore]: Whether more videos can be loaded
/// - [isLoadingMore]: Whether pagination is in progress
/// - [error]: Any error that occurred
final class VideoFeedBlocState extends Equatable {
  const VideoFeedBlocState({
    this.status = VideoFeedStatus.loading,
    this.videos = const [],
    FeedMode mode = FeedMode.forYou,
    VideoFeedSource? source,
    this.subscribedLists = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    this.videoListSources = const {},
    this.listOnlyVideoIds = const {},
    this.creatorProfiles = const {},
    this.paginationCursor,
    this.currentIndex = 0,
    this.enrichmentRevision = 0,
    this.feedSessionRevision = 0,
    this.tuningActionSequence = 0,
    this.lastTuningAction,
  }) : source =
           source ??
           (mode == FeedMode.following
               ? const VideoFeedSource.following()
               : mode == FeedMode.latest
               ? const VideoFeedSource.newVideos()
               : mode == FeedMode.classic
               ? const VideoFeedSource.classic()
               : const VideoFeedSource.forYou());

  /// The current loading status.
  final VideoFeedStatus status;

  /// The list of videos for the current feed mode.
  final List<VideoEvent> videos;

  /// The active feed source.
  final VideoFeedSource source;

  /// Subscribed curated lists available to Home.
  final List<CuratedList> subscribedLists;

  /// Whether more videos can be loaded via pagination.
  final bool hasMore;

  /// Opaque cursor for cursor-backed feeds.
  final String? paginationCursor;

  /// Whether a load-more operation is in progress.
  final bool isLoadingMore;

  /// Index of the currently active video in [videos].
  ///
  /// Tracked here (not just in the widget) so the BLoC can splice fresh
  /// results in *after* the active video and persist the resume position
  /// across app restarts.
  final int currentIndex;

  /// Error that occurred during loading, if any.
  final VideoFeedError? error;

  /// Maps videoId to the set of curated list IDs that reference it.
  ///
  /// Populated when the home feed includes videos from subscribed lists.
  /// Empty for non-home modes and when no lists are subscribed.
  final Map<String, Set<String>> videoListSources;

  /// Video IDs present only because of list subscriptions.
  ///
  /// These videos are not from followed authors — the UI shows
  /// list attribution for them (Phase 4).
  final Set<String> listOnlyVideoIds;

  /// Creator profiles keyed by pubkey.
  ///
  /// Populated by batch-fetching profiles for video creators after
  /// videos load. Warms the repository's Drift cache so individual
  /// profile lookups are instant hits.
  final Map<String, UserProfile> creatorProfiles;

  /// Monotonic revision bumped when background Nostr enrichment replaces
  /// videos with the same IDs but richer tag data.
  ///
  /// [VideoEvent] equality is ID-based, so without a separate revision the
  /// BLoC can suppress an otherwise valid state emission.
  final int enrichmentRevision;

  /// Monotonic boundary for unique-video feed-depth analytics.
  ///
  /// Full source loads and collection refreshes increment this value. Pagination
  /// and in-place enrichment keep it stable so depth continues within a session.
  final int feedSessionRevision;

  /// The most recently committed feed-tuning swipe, for the UI's Undo
  /// snackbar. `null` until the user tunes a video.
  final VideoFeedTuningAction? lastTuningAction;

  /// Monotonic counter for feed-tuning actions.
  ///
  /// Kept in state so every BLoC mutation remains observable through the state
  /// stream while still letting identical consecutive swipes notify listeners.
  final int tuningActionSequence;

  /// Whether data has been successfully loaded.
  bool get isLoaded => status == VideoFeedStatus.success;

  /// Whether the state is currently loading initial data.
  bool get isLoading => status == VideoFeedStatus.loading;

  /// Whether the feed is empty after successful load.
  bool get isEmpty => status == VideoFeedStatus.success && videos.isEmpty;

  /// Legacy mode projection for compatibility with existing callers.
  FeedMode get mode => source.mode;

  /// Human-readable title for the active feed context.
  String get feedContextTitle => source.labelFallback;

  /// Whether a subscribed curated list is currently selected.
  bool get isSubscribedListSelected =>
      source.type == VideoFeedSourceType.subscribedList;

  /// Create a copy with updated values.
  VideoFeedBlocState copyWith({
    VideoFeedStatus? status,
    List<VideoEvent>? videos,
    FeedMode? mode,
    VideoFeedSource? source,
    List<CuratedList>? subscribedLists,
    bool? hasMore,
    bool? isLoadingMore,
    VideoFeedError? error,
    bool clearError = false,
    Map<String, Set<String>>? videoListSources,
    Set<String>? listOnlyVideoIds,
    Map<String, UserProfile>? creatorProfiles,
    String? paginationCursor,
    bool clearPaginationCursor = false,
    int? currentIndex,
    int? enrichmentRevision,
    int? feedSessionRevision,
    int? tuningActionSequence,
    VideoFeedTuningAction? lastTuningAction,
  }) {
    return VideoFeedBlocState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      source:
          source ??
          (mode != null ? VideoFeedSource.fromMode(mode) : this.source),
      subscribedLists: subscribedLists ?? this.subscribedLists,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      videoListSources: videoListSources ?? this.videoListSources,
      listOnlyVideoIds: listOnlyVideoIds ?? this.listOnlyVideoIds,
      creatorProfiles: creatorProfiles ?? this.creatorProfiles,
      paginationCursor: clearPaginationCursor
          ? null
          : (paginationCursor ?? this.paginationCursor),
      currentIndex: currentIndex ?? this.currentIndex,
      enrichmentRevision: enrichmentRevision ?? this.enrichmentRevision,
      feedSessionRevision: feedSessionRevision ?? this.feedSessionRevision,
      tuningActionSequence: tuningActionSequence ?? this.tuningActionSequence,
      lastTuningAction: lastTuningAction ?? this.lastTuningAction,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    source,
    subscribedLists,
    hasMore,
    isLoadingMore,
    error,
    videoListSources,
    listOnlyVideoIds,
    creatorProfiles,
    paginationCursor,
    currentIndex,
    enrichmentRevision,
    feedSessionRevision,
    tuningActionSequence,
    lastTuningAction,
  ];
}
