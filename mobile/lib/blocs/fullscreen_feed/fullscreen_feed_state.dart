// ABOUTME: State for FullscreenFeedBloc
// ABOUTME: Tracks videos, current index, and loading state

part of 'fullscreen_feed_bloc.dart';

/// Status of the fullscreen feed.
enum FullscreenFeedStatus {
  /// Waiting for initial data.
  initial,

  /// Videos loaded and ready.
  ready,

  /// The last visible video was just removed (deletion / block / mute).
  /// The screen reacts by popping the route — there is nothing to show.
  emptyAfterRemoval,

  /// The source re-emitted an empty list after having supplied videos, so
  /// the feed has nothing left to play and nothing further is expected.
  ///
  /// Distinct from an empty *first* emit, which is a legitimate loading
  /// state that later resolves (see the `preserves initial index through
  /// empty-first source emissions` test). Without this status the screen
  /// cannot tell the two apart and shows a permanent loading spinner —
  /// which is what unliking the only liked video used to do (#6949).
  ///
  /// Unlike [emptyAfterRemoval] this does not pop the route: the source may
  /// legitimately refill (pagination, a re-like, a blocklist change), and a
  /// live feed transiently emptying must not yank the user out of it.
  empty,

  /// An error occurred.
  failure,
}

/// A just-committed feed-tuning swipe, surfaced for the UI's Undo snackbar.
final class FullscreenFeedTuningAction extends Equatable {
  const FullscreenFeedTuningAction({
    required this.videoId,
    required this.direction,
    required this.sequence,
    this.publishedEventId,
  });

  /// Event ID of the swiped video.
  final String videoId;

  /// The direction that was published.
  final FeedTuningDirection direction;

  /// Monotonic action id so identical consecutive swipes still notify listeners.
  final int sequence;

  /// Published feed-tuning event id, or `null` when nothing was published
  /// (no signer). Undo is only possible when this is non-null.
  final String? publishedEventId;

  @override
  List<Object?> get props => [videoId, direction, sequence, publishedEventId];
}

/// State for the FullscreenFeedBloc.
final class FullscreenFeedState extends Equatable {
  FullscreenFeedState({
    this.status = FullscreenFeedStatus.initial,
    this.videos = const [],
    this.currentIndex = 0,
    this.isLoadingMore = false,
    this.canLoadMore = false,
    this.removedVideoIds = const <String>{},
    this.pendingSkipTarget,
    this.initialTargetResolved = false,
    this.userChangedIndex = false,
    this.lastTuningAction,
  });

  /// The current status.
  final FullscreenFeedStatus status;

  /// The list of videos from the source.
  final List<VideoEvent> videos;

  /// The currently displayed video index.
  final int currentIndex;

  /// Whether a load more operation is in progress.
  final bool isLoadingMore;

  /// Whether this feed supports pagination.
  final bool canLoadMore;

  /// Event IDs confirmed missing for this session. Owned by the BLoC — the
  /// UI must never mutate this set directly. Once an ID is added it stays
  /// removed for the lifetime of this BLoC so repeated player errors for
  /// the same asset don't trigger duplicate HEAD checks or skip animations.
  final Set<String> removedVideoIds;

  /// When non-null, signals the UI to animate the feed to this index after
  /// a confirmed removal. The UI must dispatch
  /// [FullscreenFeedSkipAcknowledged] once it has consumed the signal so a
  /// subsequent removal can produce a new skip.
  final int? pendingSkipTarget;

  /// Whether the launch target has been reconciled against a non-empty source
  /// list. Kept in state so stream replays and user index changes can be
  /// coordinated without mutable BLoC fields.
  final bool initialTargetResolved;

  /// Whether the user has manually moved the feed cursor since launch.
  final bool userChangedIndex;

  /// The most recently committed feed-tuning swipe, for the UI's Undo
  /// snackbar. `null` until the user tunes a video. A `BlocListener` reacts to
  /// changes here. [FullscreenFeedTuningAction.sequence] makes each committed
  /// swipe distinct even when the same video/direction/event id repeats.
  final FullscreenFeedTuningAction? lastTuningAction;

  /// The current video, if available.
  VideoEvent? get currentVideo =>
      currentIndex >= 0 && currentIndex < videos.length
      ? videos[currentIndex]
      : null;

  /// Whether we have videos to display.
  bool get hasVideos => videos.isNotEmpty;

  /// Metadata-sensitive signature for detecting updates to videos that keep
  /// the same IDs and order but change user-visible fields like loop counts.
  ///
  /// This is initialized lazily because computing it requires runtime video
  /// data. Consequently, this state cannot have a const constructor.
  late final List<String> videoUpdateSignature = List.unmodifiable(
    videos.map(
      (video) => [
        video.id,
        video.stableId,
        video.videoUrl ?? '',
        video.thumbnailUrl ?? '',
        '${video.originalLoops ?? ''}',
        video.rawTags['views'] ?? '',
      ].join('|'),
    ),
  );

  /// Create a copy with updated values. [pendingSkipTarget] accepts
  /// `null` explicitly via [clearPendingSkipTarget] — the default
  /// copy-on-null-preserves behavior would otherwise prevent clearing it.
  FullscreenFeedState copyWith({
    FullscreenFeedStatus? status,
    List<VideoEvent>? videos,
    int? currentIndex,
    bool? isLoadingMore,
    bool? canLoadMore,
    Set<String>? removedVideoIds,
    int? pendingSkipTarget,
    bool? initialTargetResolved,
    bool? userChangedIndex,
    FullscreenFeedTuningAction? lastTuningAction,
    bool clearPendingSkipTarget = false,
  }) {
    return FullscreenFeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      removedVideoIds: removedVideoIds ?? this.removedVideoIds,
      pendingSkipTarget: clearPendingSkipTarget
          ? null
          : (pendingSkipTarget ?? this.pendingSkipTarget),
      initialTargetResolved:
          initialTargetResolved ?? this.initialTargetResolved,
      userChangedIndex: userChangedIndex ?? this.userChangedIndex,
      lastTuningAction: lastTuningAction ?? this.lastTuningAction,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    videoUpdateSignature,
    currentIndex,
    isLoadingMore,
    canLoadMore,
    removedVideoIds,
    pendingSkipTarget,
    initialTargetResolved,
    userChangedIndex,
    lastTuningAction,
  ];
}
