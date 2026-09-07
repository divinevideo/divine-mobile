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
    FullscreenFeedStatus status = FullscreenFeedStatus.initial,
    List<VideoEvent> videos = const [],
    int currentIndex = 0,
    bool isLoadingMore = false,
    bool canLoadMore = false,
    Set<String> removedVideoIds = const <String>{},
    int? pendingSkipTarget,
    bool initialTargetResolved = false,
    bool userChangedIndex = false,
    FullscreenFeedTuningAction? lastTuningAction,
  }) : this._(
         status: status,
         videos: videos,
         currentIndex: currentIndex,
         isLoadingMore: isLoadingMore,
         canLoadMore: canLoadMore,
         removedVideoIds: removedVideoIds,
         pendingSkipTarget: pendingSkipTarget,
         initialTargetResolved: initialTargetResolved,
         userChangedIndex: userChangedIndex,
         lastTuningAction: lastTuningAction,
       );

  /// Carries an already-materialized [videoUpdateSignature] into a copy whose
  /// [videos] is the identical list instance, so the signature is built once
  /// per list rather than once per state. See [copyWith].
  FullscreenFeedState._({
    required this.status,
    required this.videos,
    required this.currentIndex,
    required this.isLoadingMore,
    required this.canLoadMore,
    required this.removedVideoIds,
    required this.pendingSkipTarget,
    required this.initialTargetResolved,
    required this.userChangedIndex,
    required this.lastTuningAction,
    List<String>? signature,
  }) : _inheritedSignature = signature;

  /// Non-null only when [copyWith] proved [videos] unchanged by identity.
  final List<String>? _inheritedSignature;

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
  /// A per-instance snapshot rather than a live view: it materializes once
  /// from whatever [videos] holds at first access, so a later in-place
  /// mutation of that same list is reported as a change instead of being
  /// silently absorbed. The bloc's filter helpers do return the source list
  /// by reference when no filter applies, so that case is reachable.
  ///
  /// The trade is memory for CPU — each live state retains one
  /// `List<String>` (~130 KiB at 200 videos). Being `late` is also why this
  /// class has no `const` constructor.
  late final List<String> videoUpdateSignature =
      _inheritedSignature ??
      List.unmodifiable(
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
    final nextVideos = videos ?? this.videos;
    return FullscreenFeedState._(
      status: status ?? this.status,
      videos: nextVideos,
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
      signature: identical(nextVideos, this.videos)
          ? videoUpdateSignature
          : null,
    );
  }

  /// [videos] is deliberately absent: every [videoUpdateSignature] entry
  /// starts with `video.id` and `VideoEvent ==` is id-only, so equal
  /// signatures already imply equal length, ids and order. Listing both made
  /// every `==` and `hashCode` walk the videos twice to answer one question.
  @override
  List<Object?> get props => [
    status,
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
