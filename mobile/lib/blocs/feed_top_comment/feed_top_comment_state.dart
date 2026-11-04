part of 'feed_top_comment_cubit.dart';

/// Loading phase of [FeedTopCommentCubit].
enum FeedTopCommentStatus { initial, loading, ready, empty, failure }

/// The top comment of one video and whether its overlay is up.
class FeedTopCommentState extends Equatable {
  const FeedTopCommentState({
    this.status = FeedTopCommentStatus.initial,
    this.topComment,
    this.hasCompletedLoop = false,
    this.isDismissed = false,
  });

  final FeedTopCommentStatus status;

  /// The comment shown, set once [status] is [FeedTopCommentStatus.ready].
  final Comment? topComment;

  /// Whether the video has finished playing through once.
  final bool hasCompletedLoop;

  /// Whether the viewer dismissed the overlay.
  final bool isDismissed;

  /// Whether the reaction overlay should be on screen.
  bool get isOverlayVisible =>
      status == FeedTopCommentStatus.ready &&
      topComment != null &&
      hasCompletedLoop &&
      !isDismissed;

  FeedTopCommentState copyWith({
    FeedTopCommentStatus? status,
    Comment? topComment,
    bool? hasCompletedLoop,
    bool? isDismissed,
  }) {
    return FeedTopCommentState(
      status: status ?? this.status,
      topComment: topComment ?? this.topComment,
      hasCompletedLoop: hasCompletedLoop ?? this.hasCompletedLoop,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    topComment,
    hasCompletedLoop,
    isDismissed,
  ];
}
