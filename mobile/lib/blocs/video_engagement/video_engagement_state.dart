// ABOUTME: State and supporting enums for VideoEngagementBloc.

part of 'video_engagement_bloc.dart';

/// Which engagement list a [VideoEngagementBloc] is fetching.
enum VideoEngagementType {
  /// Users who reacted with a `+` (like) to the target event.
  likers,

  /// Users who reposted (NIP-18, kind 6/16) the target event.
  reposters,
}

/// Loading status for the engagement list.
enum VideoEngagementStatus {
  /// Initial state before any load has been requested.
  initial,

  /// A relay query is in flight.
  loading,

  /// The list has been loaded successfully.
  success,

  /// The relay query failed.
  failure,
}

/// Status of the follow-on page request, separate from the first load.
///
/// A failed page must be distinguishable from an idle one: the view triggers
/// the next page from its item builder, so retrying automatically on
/// [failure] would re-fire on every rebuild the failure itself causes.
enum VideoEngagementLoadMoreStatus {
  /// No page request in flight; another may be triggered.
  idle,

  /// A page request is in flight.
  inProgress,

  /// The last page request failed. Only an explicit retry starts another.
  failure,
}

/// Marks "leave this field alone" so [VideoEngagementState.copyWith] can set
/// a nullable field back to null.
const Object _unchanged = Object();

/// State emitted by [VideoEngagementBloc].
final class VideoEngagementState extends Equatable {
  const VideoEngagementState({
    required this.type,
    this.status = VideoEngagementStatus.initial,
    this.pubkeys = const [],
    this.loadMoreStatus = VideoEngagementLoadMoreStatus.idle,
    this.nextCursor,
  });

  /// Whether this state is for the likers list or the reposters list.
  final VideoEngagementType type;

  /// Current load status.
  final VideoEngagementStatus status;

  /// Pubkeys of users who liked or reposted the target event, ordered by
  /// reaction recency (most recent first), accumulated across loaded pages
  /// and deduplicated.
  final List<String> pubkeys;

  /// Status of the follow-on page request.
  final VideoEngagementLoadMoreStatus loadMoreStatus;

  /// Opaque cursor for the next page, or `null` when the list is complete.
  ///
  /// Always `null` for reposters, which are served from relays in one page.
  final String? nextCursor;

  /// Whether a further page can be requested.
  bool get hasMore => nextCursor != null;

  /// Returns a copy of this state with the supplied fields overridden.
  ///
  /// [nextCursor] is a sentinel parameter: omit it to keep the current value,
  /// pass `null` explicitly to clear it.
  VideoEngagementState copyWith({
    VideoEngagementStatus? status,
    List<String>? pubkeys,
    VideoEngagementLoadMoreStatus? loadMoreStatus,
    Object? nextCursor = _unchanged,
  }) {
    return VideoEngagementState(
      type: type,
      status: status ?? this.status,
      pubkeys: pubkeys ?? this.pubkeys,
      loadMoreStatus: loadMoreStatus ?? this.loadMoreStatus,
      nextCursor: identical(nextCursor, _unchanged)
          ? this.nextCursor
          : nextCursor as String?,
    );
  }

  @override
  List<Object?> get props => [
    type,
    status,
    pubkeys,
    loadMoreStatus,
    nextCursor,
  ];
}
