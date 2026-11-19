part of 'post_analytics_detail_cubit.dart';

/// What the post stats screen can honestly say about the post.
enum PostAnalyticsDetailStatus {
  /// The first load has not answered yet.
  loading,

  /// The post was found and at least one count is worth showing.
  ready,

  /// Funnelcake has not caught up yet, before the settle point.
  onTheirWay,

  /// Past the settle point and inside the first hour, views, likes and
  /// comments are confirmed zero.
  nothingYet,

  /// Past the settle point, Funnelcake still has no record of the post.
  cantFind,

  /// The request failed: an error, not an answer.
  couldNotLoad,
}

/// One post's counts, each null while it is not known.
///
/// Unlike [VideoPerformance], an unknown count stays unknown here instead of
/// reading as zero, and a zero before the settle point counts as unknown.
class PostCounts extends Equatable {
  /// Creates the counts.
  const PostCounts({
    this.views,
    this.likes,
    this.comments,
    this.reposts,
    this.uniqueViewers,
  });

  final int? views;
  final int? likes;
  final int? comments;
  final int? reposts;
  final int? uniqueViewers;

  /// Whether any known count is above zero.
  bool get anyAboveZero => [
    views,
    likes,
    comments,
    reposts,
    uniqueViewers,
  ].any((count) => count != null && count > 0);

  /// Whether views, likes and comments are all known and zero.
  bool get confirmedEmpty => views == 0 && likes == 0 && comments == 0;

  /// Likes, comments and reposts together, or null while any is unknown.
  int? get interactions {
    final (likes, comments, reposts) = (
      this.likes,
      this.comments,
      this.reposts,
    );
    if (likes == null || comments == null || reposts == null) return null;
    return likes + comments + reposts;
  }

  /// [interactions] per view, or null while either side is unknown or there
  /// are no views.
  double? get engagementRate {
    final (interactions, views) = (this.interactions, this.views);
    if (interactions == null || views == null || views == 0) return null;
    return interactions / views;
  }

  @override
  List<Object?> get props => [views, likes, comments, reposts, uniqueViewers];
}

/// State of the post stats screen.
class PostAnalyticsDetailState extends Equatable {
  /// Creates the state.
  const PostAnalyticsDetailState({
    this.status = PostAnalyticsDetailStatus.loading,
    this.performance,
    this.counts = const PostCounts(),
    this.postedAt,
    this.liveMinutes = 0,
    this.coordinate,
    this.liveActivityRunning = false,
  });

  final PostAnalyticsDetailStatus status;

  /// The post as Funnelcake returned it; null while it is not found.
  final VideoPerformance? performance;

  /// The post's counts as this screen may show them.
  final PostCounts counts;

  /// When the post was published: the Live Activity's time, else the
  /// video's `created_at`. Null when neither is known.
  final DateTime? postedAt;

  /// Whole minutes the post had been live when the state was built.
  final int liveMinutes;

  /// The post's `kind:pubkey:d-tag` address, when known.
  final String? coordinate;

  /// Whether a Lock Screen Live Activity is running for the post.
  final bool liveActivityRunning;

  PostAnalyticsDetailState copyWith({
    PostAnalyticsDetailStatus? status,
    bool? liveActivityRunning,
  }) => PostAnalyticsDetailState(
    status: status ?? this.status,
    performance: performance,
    counts: counts,
    postedAt: postedAt,
    liveMinutes: liveMinutes,
    coordinate: coordinate,
    liveActivityRunning: liveActivityRunning ?? this.liveActivityRunning,
  );

  @override
  List<Object?> get props => [
    status,
    performance,
    counts,
    postedAt,
    liveMinutes,
    coordinate,
    liveActivityRunning,
  ];
}
