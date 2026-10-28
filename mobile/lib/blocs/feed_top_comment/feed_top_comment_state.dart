part of 'feed_top_comment_cubit.dart';

/// Loading phase of [FeedTopCommentCubit].
enum FeedTopCommentStatus { initial, loading, ready, empty, failure }

/// The top comment of one video and whether its overlay is up.
class FeedTopCommentState extends Equatable {
  const FeedTopCommentState({
    this.status = FeedTopCommentStatus.initial,
    this.topComment,
    this.repliedToPubkey,
    this.repliedToContent,
    this.hasCompletedLoop = false,
    this.isDismissed = false,
  });

  final FeedTopCommentStatus status;

  /// The comment shown, set once [status] is [FeedTopCommentStatus.ready].
  final Comment? topComment;

  /// Who [topComment] answered: the video's creator for a top-level comment,
  /// the parent comment's author for a reply.
  final String? repliedToPubkey;

  /// What [topComment] answered: the video's description, or the parent
  /// comment's text. `null` when the parent is not among the loaded comments.
  final String? repliedToContent;

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
    String? repliedToPubkey,
    String? repliedToContent,
    bool? hasCompletedLoop,
    bool? isDismissed,
  }) {
    return FeedTopCommentState(
      status: status ?? this.status,
      topComment: topComment ?? this.topComment,
      repliedToPubkey: repliedToPubkey ?? this.repliedToPubkey,
      repliedToContent: repliedToContent ?? this.repliedToContent,
      hasCompletedLoop: hasCompletedLoop ?? this.hasCompletedLoop,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    topComment,
    repliedToPubkey,
    repliedToContent,
    hasCompletedLoop,
    isDismissed,
  ];
}
