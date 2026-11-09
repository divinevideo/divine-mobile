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
    this.appliedModeration = CommentModeration.empty,
    this.moderationRevision = 0,
  });

  final FeedTopCommentStatus status;

  /// The comment shown, set once [status] is [FeedTopCommentStatus.ready].
  final Comment? topComment;

  /// Whether the video has looped since this cubit was created.
  final bool hasCompletedLoop;

  /// Whether the viewer dismissed the overlay.
  final bool isDismissed;

  /// Published policy used for this selection, separate from local owner blocks.
  final CommentModeration appliedModeration;

  /// Scoped cache version used for this selection, not an app-wide counter.
  final int moderationRevision;

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
    CommentModeration? appliedModeration,
    int? moderationRevision,
  }) {
    return FeedTopCommentState(
      status: status ?? this.status,
      topComment: topComment ?? this.topComment,
      hasCompletedLoop: hasCompletedLoop ?? this.hasCompletedLoop,
      isDismissed: isDismissed ?? this.isDismissed,
      appliedModeration: appliedModeration ?? this.appliedModeration,
      moderationRevision: moderationRevision ?? this.moderationRevision,
    );
  }

  @override
  List<Object?> get props => [
    status,
    topComment,
    hasCompletedLoop,
    isDismissed,
    appliedModeration,
    moderationRevision,
  ];
}
