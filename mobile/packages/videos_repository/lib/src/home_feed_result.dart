// ABOUTME: Result model for home feed fetches with list attribution.
// ABOUTME: Contains merged videos (following + list) plus metadata
// ABOUTME: mapping videos to their source curated lists.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// {@template home_feed_result}
/// Result of a home feed fetch, including list attribution metadata.
///
/// When the home feed includes videos from subscribed curated lists,
/// [videoListSources] maps each video to the lists that reference it,
/// and [listOnlyVideoIds] identifies videos present only because of
/// list subscriptions (not from followed authors).
///
/// When no list video refs are provided, [videoListSources] and
/// [listOnlyVideoIds] are empty — the result contains only following
/// videos with no attribution data.
/// {@endtemplate}
class HomeFeedResult extends Equatable {
  /// {@macro home_feed_result}
  const HomeFeedResult({
    required this.videos,
    this.videoListSources = const {},
    this.listOnlyVideoIds = const {},
    this.consumedItemCount,
    this.nextCursor,
    this.paginationCursor,
    this.hasMore,
    this.recommendationPageCount = 0,
    this.followingPageCount = 0,
  });

  /// All videos (following + list), sorted by createdAt descending.
  final List<VideoEvent> videos;

  /// Maps videoId to the set of list IDs that reference it.
  ///
  /// Empty for videos that aren't in any subscribed list.
  /// A video from a followed author can still appear here if it's also
  /// in a subscribed list.
  final Map<String, Set<String>> videoListSources;

  /// Video IDs present ONLY because of list subscriptions
  /// (not from followed authors).
  ///
  /// Used by the UI to show list attribution — these videos need
  /// visual attribution since the user didn't follow the author.
  final Set<String> listOnlyVideoIds;

  /// Number of raw upstream items consumed to produce [videos], when the
  /// caller needs pagination metadata that differs from `videos.length`.
  final int? consumedItemCount;

  /// Cursor for the next page request when the feed is cursor-backed.
  final int? nextCursor;

  /// Opaque cursor for feeds backed by string cursor APIs.
  final String? paginationCursor;

  /// Whether the upstream feed has more data to fetch.
  final bool? hasMore;

  /// Recommendation pages fetched to produce this result.
  final int recommendationPageCount;

  /// Following-feed pages fetched across REST or relay fallback.
  final int followingPageCount;

  @override
  List<Object?> get props => [
    videos,
    videoListSources,
    listOnlyVideoIds,
    consumedItemCount,
    nextCursor,
    paginationCursor,
    hasMore,
    recommendationPageCount,
    followingPageCount,
  ];
}
