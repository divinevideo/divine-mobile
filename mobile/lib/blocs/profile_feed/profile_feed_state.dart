part of 'profile_feed_cubit.dart';

/// Lifecycle status for the profile/author feed.
enum ProfileFeedStatus {
  /// No load has started yet.
  initial,

  /// The cold load is in flight and no videos are available to show.
  loading,

  /// Videos are available (possibly still refreshing in the background).
  ready,

  /// The cold load failed with no videos to fall back on.
  failure,
}

/// One-shot outcome of the last pin mutation, consumed by a listener that
/// shows the snackbar. Reset to [none] when the next mutation starts so two
/// identical outcomes in a row still read as two transitions.
enum ProfileFeedPinFeedback {
  none,
  pinned,
  unpinned,
  pinLimitReached,
  pinFailed,
  unpinFailed,
}

/// State for [ProfileFeedCubit].
///
/// [videos] is the **filtered** list the UI renders. Errors are NOT stored as
/// strings — failures surface via [status] / [hasLoadMoreError] + `addError`
/// per `error_handling.md`.
class ProfileFeedState extends Equatable {
  const ProfileFeedState({
    this.status = ProfileFeedStatus.initial,
    this.videos = const [],
    this.hasMoreContent = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isInitialLoad = false,
    this.hasLoadMoreError = false,
    this.isFetchingTotalCount = false,
    this.totalVideoCount,
    this.nextOffset,
    this.lastUpdated,
    this.pinnedCoordinates = const [],
    this.isPinMutationInFlight = false,
    this.pinFeedback = ProfileFeedPinFeedback.none,
  });

  /// Lifecycle status.
  final ProfileFeedStatus status;

  /// The filtered videos the UI renders.
  final List<VideoEvent> videos;

  /// Whether more pages can be loaded.
  final bool hasMoreContent;

  /// A pagination load is in flight.
  final bool isLoadingMore;

  /// A full refresh is in flight (videos still shown).
  final bool isRefreshing;

  /// Cold load in flight with no videos yet — UI shows a loading state instead
  /// of the empty state (#4164).
  final bool isInitialLoad;

  /// The last pagination request failed; videos are retained. Drives a
  /// transient banner/snackbar, then is cleared on the next attempt.
  final bool hasLoadMoreError;

  /// A REST call that will resolve [totalVideoCount] is in flight.
  final bool isFetchingTotalCount;

  /// Total videos for this author (from the `X-Total-Count` header).
  final int? totalVideoCount;

  /// REST pagination offset; non-null ⇒ REST is the active pagination source,
  /// null ⇒ Nostr-fallback mode (#3849).
  final int? nextOffset;

  /// Timestamp of the last successful update.
  final DateTime? lastUpdated;

  /// The author's pinned videos as kind-34236 coordinates, in stored order.
  /// [videos] already leads with the ones that resolved; this is what tells a
  /// tile to show the badge and the owner's sheet whether to offer Unpin.
  final List<String> pinnedCoordinates;

  /// A pin or unpin publish is in flight; the sheet disables the action.
  final bool isPinMutationInFlight;

  /// Outcome of the most recent pin mutation, for the feedback snackbar.
  final ProfileFeedPinFeedback pinFeedback;

  /// How many videos the owner may pin.
  static const int maxPinnedVideos = ProfilePinsRepository.maxPins;

  /// Whether the owner may pin one more video.
  bool get canPinMore => pinnedCoordinates.length < maxPinnedVideos;

  /// Whether [video] is on the author's pin list.
  bool isPinned(VideoEvent video) {
    final coordinate = video.addressableId;
    return coordinate != null && pinnedCoordinates.contains(coordinate);
  }

  static const Object _unset = Object();

  ProfileFeedState copyWith({
    ProfileFeedStatus? status,
    List<VideoEvent>? videos,
    bool? hasMoreContent,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isInitialLoad,
    bool? hasLoadMoreError,
    bool? isFetchingTotalCount,
    Object? totalVideoCount = _unset,
    Object? nextOffset = _unset,
    Object? lastUpdated = _unset,
    List<String>? pinnedCoordinates,
    bool? isPinMutationInFlight,
    ProfileFeedPinFeedback? pinFeedback,
  }) {
    return ProfileFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialLoad: isInitialLoad ?? this.isInitialLoad,
      hasLoadMoreError: hasLoadMoreError ?? this.hasLoadMoreError,
      isFetchingTotalCount: isFetchingTotalCount ?? this.isFetchingTotalCount,
      totalVideoCount: identical(totalVideoCount, _unset)
          ? this.totalVideoCount
          : totalVideoCount as int?,
      nextOffset: identical(nextOffset, _unset)
          ? this.nextOffset
          : nextOffset as int?,
      lastUpdated: identical(lastUpdated, _unset)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
      pinnedCoordinates: pinnedCoordinates ?? this.pinnedCoordinates,
      isPinMutationInFlight:
          isPinMutationInFlight ?? this.isPinMutationInFlight,
      pinFeedback: pinFeedback ?? this.pinFeedback,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    hasMoreContent,
    isLoadingMore,
    isRefreshing,
    isInitialLoad,
    hasLoadMoreError,
    isFetchingTotalCount,
    totalVideoCount,
    nextOffset,
    lastUpdated,
    pinnedCoordinates,
    isPinMutationInFlight,
    pinFeedback,
  ];
}
