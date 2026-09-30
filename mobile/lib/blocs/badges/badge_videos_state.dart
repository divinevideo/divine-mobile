part of 'badge_videos_cubit.dart';

/// Loading status of a badge's holder videos.
enum BadgeVideosStatus {
  /// Nothing has been requested yet.
  initial,

  /// The holders and first page are loading.
  loading,

  /// At least the first page loaded.
  loaded,

  /// The holders or first page could not be loaded.
  failure,
}

/// State for the [BadgeVideosCubit].
class BadgeVideosState extends Equatable {
  /// Creates badge video state.
  const BadgeVideosState({
    this.status = BadgeVideosStatus.initial,
    this.videos = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailures = 0,
  });

  /// Loading status of the first page.
  final BadgeVideosStatus status;

  /// Videos loaded so far, newest first.
  final List<VideoEvent> videos;

  /// Whether another page may exist.
  final bool hasMore;

  /// Whether a further page is loading.
  final bool isLoadingMore;

  /// Increments each time a further page fails to load.
  final int loadMoreFailures;

  /// Returns a copy with the given fields replaced.
  BadgeVideosState copyWith({
    BadgeVideosStatus? status,
    List<VideoEvent>? videos,
    bool? hasMore,
    bool? isLoadingMore,
    int? loadMoreFailures,
  }) {
    return BadgeVideosState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailures: loadMoreFailures ?? this.loadMoreFailures,
    );
  }

  @override
  List<Object?> get props => [
    status,
    videos,
    hasMore,
    isLoadingMore,
    loadMoreFailures,
  ];
}
