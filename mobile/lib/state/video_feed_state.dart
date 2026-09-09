// ABOUTME: Simple state model for video lists without global feed modes
// ABOUTME: Represents the current state of a video list with basic metadata

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/state/copy_with_sentinel.dart';
import 'package:openvine/state/equal_unmodifiable_collections.dart';

/// State model for video lists
class VideoFeedState extends Equatable {
  const VideoFeedState({
    required List<VideoEvent> videos,
    required this.hasMoreContent,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isInitialLoad = false,
    this.error,
    this.lastUpdated,
    Map<String, Set<String>> videoListSources = const {},
    Set<String> listOnlyVideoIds = const {},
    this.totalVideoCount,
    this.isFetchingTotalCount = false,
  }) : _videos = videos,
       _videoListSources = videoListSources,
       _listOnlyVideoIds = listOnlyVideoIds;

  /// List of videos in the feed
  final List<VideoEvent> _videos;
  List<VideoEvent> get videos {
    if (_videos is EqualUnmodifiableListView) return _videos;
    return EqualUnmodifiableListView(_videos);
  }

  /// Whether more content can be loaded
  final bool hasMoreContent;

  /// Loading state for pagination
  final bool isLoadingMore;

  /// Refreshing state for pull-to-refresh
  final bool isRefreshing;

  /// Whether this is the initial load (videos may still be arriving)
  /// When true and videos is empty, show loading indicator instead of empty
  /// state
  final bool isInitialLoad;

  /// Error message if any
  final String? error;

  /// Timestamp of last update
  final DateTime? lastUpdated;

  /// Maps video IDs to the set of curated list IDs they appear in
  /// Used to show "From list: X" attribution chip on videos
  final Map<String, Set<String>> _videoListSources;
  Map<String, Set<String>> get videoListSources {
    if (_videoListSources is EqualUnmodifiableMapView) {
      return _videoListSources;
    }
    return EqualUnmodifiableMapView(_videoListSources);
  }

  /// Set of video IDs that appear ONLY from subscribed lists (not from follows)
  /// These videos should show the list attribution chip in the UI
  final Set<String> _listOnlyVideoIds;
  Set<String> get listOnlyVideoIds {
    if (_listOnlyVideoIds is EqualUnmodifiableSetView) {
      return _listOnlyVideoIds;
    }
    return EqualUnmodifiableSetView(_listOnlyVideoIds);
  }

  /// Total video count from the server's X-Total-Count header.
  /// When available, this is more accurate than `videos.length` which
  /// only reflects the number of loaded videos.
  final int? totalVideoCount;

  /// Whether a REST call that will resolve [totalVideoCount] is currently
  /// in flight. Stays `true` from the moment the fetch starts until it
  /// settles (success, empty, or failure). UI uses this to distinguish
  /// "still loading, authoritative count may still arrive" from
  /// "settled, no authoritative count available — fall back to
  /// videos.length".
  final bool isFetchingTotalCount;

  VideoFeedState copyWith({
    List<VideoEvent>? videos,
    bool? hasMoreContent,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isInitialLoad,
    Object? error = unsetCopyWithArgument,
    Object? lastUpdated = unsetCopyWithArgument,
    Map<String, Set<String>>? videoListSources,
    Set<String>? listOnlyVideoIds,
    Object? totalVideoCount = unsetCopyWithArgument,
    bool? isFetchingTotalCount,
  }) {
    return VideoFeedState(
      videos: videos ?? _videos,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialLoad: isInitialLoad ?? this.isInitialLoad,
      error: identical(error, unsetCopyWithArgument)
          ? this.error
          : error as String?,
      lastUpdated: identical(lastUpdated, unsetCopyWithArgument)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
      videoListSources: videoListSources ?? _videoListSources,
      listOnlyVideoIds: listOnlyVideoIds ?? _listOnlyVideoIds,
      totalVideoCount: identical(totalVideoCount, unsetCopyWithArgument)
          ? this.totalVideoCount
          : totalVideoCount as int?,
      isFetchingTotalCount: isFetchingTotalCount ?? this.isFetchingTotalCount,
    );
  }

  @override
  List<Object?> get props => [
    _videos,
    hasMoreContent,
    isLoadingMore,
    isRefreshing,
    isInitialLoad,
    error,
    lastUpdated,
    _videoListSources,
    _listOnlyVideoIds,
    totalVideoCount,
    isFetchingTotalCount,
  ];
}
