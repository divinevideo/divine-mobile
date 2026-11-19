// ABOUTME: State class for the VideoSearchBloc
// ABOUTME: Represents search state with status, query, results, and pagination

part of 'video_search_bloc.dart';

/// Enum representing the status of the video search
enum VideoSearchStatus {
  /// Initial state, no search performed yet
  initial,

  /// Currently searching for videos
  searching,

  /// Search completed successfully
  success,

  /// An error occurred while searching
  failure,
}

/// State class for the VideoSearchBloc
final class VideoSearchState extends Equatable {
  const VideoSearchState({
    this.status = VideoSearchStatus.initial,
    this.query = '',
    this.videos = const [],
    this.resultCount,
    this.apiOffset = 0,
    this.totalApiCount,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.sort = VideoSearchSort.trending,
  });

  /// The current status of the search
  final VideoSearchStatus status;

  /// The current search query
  final String query;

  /// The list of videos matching the search
  final List<VideoEvent> videos;

  /// Lightweight count for tab badges when full results were not fetched.
  final int? resultCount;

  /// Tracks how many results have been fetched from the API for pagination.
  final int apiOffset;

  /// Total API result count from `X-Total-Count` header (null until known).
  final int? totalApiCount;

  /// Whether more API pages are available.
  final bool hasMore;

  /// Whether a load-more request is currently in flight.
  final bool isLoadingMore;

  /// Server-backed sort order for video search results.
  final VideoSearchSort sort;

  /// Create a copy with updated values
  VideoSearchState copyWith({
    VideoSearchStatus? status,
    String? query,
    List<VideoEvent>? videos,
    Object? resultCount = _unset,
    int? apiOffset,
    Object? totalApiCount = _unset,
    bool? hasMore,
    bool? isLoadingMore,
    VideoSearchSort? sort,
  }) {
    return VideoSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      videos: videos ?? this.videos,
      resultCount: identical(resultCount, _unset)
          ? this.resultCount
          : resultCount as int?,
      apiOffset: apiOffset ?? this.apiOffset,
      totalApiCount: identical(totalApiCount, _unset)
          ? this.totalApiCount
          : totalApiCount as int?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      sort: sort ?? this.sort,
    );
  }

  @override
  List<Object> get props => [
    status,
    query,
    videos,
    // VideoEvent == compares event ids only. Progressive API results can
    // update archive verdicts for IDs already emitted from cache or relays.
    [
      for (final video in videos)
        (
          video.isVerifiedArchive,
          video.isArchiveVerificationUnknown,
          video.archiveAudioReuseEnabled,
        ),
    ],
    resultCount ?? -1,
    apiOffset,
    totalApiCount ?? -1,
    hasMore,
    isLoadingMore,
    sort,
  ];

  static const Object _unset = Object();
}
