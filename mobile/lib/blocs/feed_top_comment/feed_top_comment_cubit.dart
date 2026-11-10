// ABOUTME: Picks a video's top comment for the feed's "Show reactions" mode and
// ABOUTME: decides when it shows: after the first loop, until dismissed.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:unified_logger/unified_logger.dart';

part 'feed_top_comment_state.dart';

/// Loads one video's comments and their vote counts, and selects the one with
/// the highest net vote score, using the comments sheet's Top comparator.
/// Ties go to the newer comment. Text replies are also candidates for the
/// overlay. The creator's own comments, video replies, blank comments, pending
/// placeholders and comments dated more than [maxFutureSkew] ahead are excluded.
/// Creator-hidden comments are excluded using the same author-view
/// exception as the comments sheet.
///
/// The overlay shows once the video has finished its first loop and the top
/// comment is known, whichever happens last, and stays hidden after the
/// viewer dismisses it.
class FeedTopCommentCubit extends Cubit<FeedTopCommentState>
    with CloseGuardedEmit<FeedTopCommentState> {
  FeedTopCommentCubit({
    required CommentsRepository commentsRepository,
    required LikesRepository likesRepository,
    required CommentModerationRepository commentModerationRepository,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
    required Stream<void> loopCompletions,
    String? rootAddressableId,
    String? viewerPubkey,
    Set<String> viewerBlockedAuthors = const {},
    bool initialHasCompletedLoop = false,
    bool initiallyDismissed = false,
    DateTime Function()? now,
  }) : _commentsRepository = commentsRepository,
       _likesRepository = likesRepository,
       _commentModerationRepository = commentModerationRepository,
       _rootEventId = rootEventId,
       _rootEventKind = rootEventKind,
       _rootAuthorPubkey = rootAuthorPubkey,
       _rootAddressableId = rootAddressableId,
       _viewerPubkey = viewerPubkey,
       _viewerBlockedAuthors = Set.unmodifiable(viewerBlockedAuthors),
       _now = now ?? DateTime.now,
       super(
         FeedTopCommentState(
           hasCompletedLoop: initialHasCompletedLoop,
           isDismissed: initiallyDismissed,
         ),
       ) {
    _loopSubscription = loopCompletions.listen((_) => _onLoopCompleted());
  }

  /// How many comments are ranked — the first page the comments sheet loads.
  static const commentPageSize = 50;

  /// Tolerated author clock skew. `created_at` is author-signed, so a comment
  /// dated further ahead could win a tie until its timestamp catches up.
  static const maxFutureSkew = Duration(minutes: 5);

  final CommentsRepository _commentsRepository;
  final LikesRepository _likesRepository;
  final CommentModerationRepository _commentModerationRepository;
  final String? _viewerPubkey;
  final Set<String> _viewerBlockedAuthors;
  final String _rootEventId;
  final int _rootEventKind;

  /// The video's creator. Their own comments are never the reaction.
  final String _rootAuthorPubkey;
  final String? _rootAddressableId;
  final DateTime Function() _now;
  late final StreamSubscription<void> _loopSubscription;

  /// Fetches the comments and their vote counts and selects the top comment.
  ///
  /// Runs once per cubit; later calls do nothing, so a finished state never
  /// carries an earlier load's comment.
  Future<void> load() async {
    if (state.status != FeedTopCommentStatus.initial) return;
    emit(state.copyWith(status: FeedTopCommentStatus.loading));

    final List<Comment> comments;
    try {
      final results = await Future.wait<Object>([
        _commentsRepository.loadComments(
          rootEventId: _rootEventId,
          rootEventKind: _rootEventKind,
          rootAddressableId: _rootAddressableId,
          limit: commentPageSize,
        ),
        _loadModeration(),
      ]);
      if (isClosed) return;
      final thread = results[0] as CommentThread;
      // Read sources can still serve author-deleted comments. The repository
      // validates NIP-09 requests and fails open when the relay cannot answer.
      final deleted = await _commentsRepository.findAuthorDeletedComments(
        thread.comments,
      );
      if (isClosed) return;
      comments = thread.comments
          .where((comment) => !deleted.contains(comment.id))
          .toList();
    } on CommentsRepositoryException catch (error, stackTrace) {
      _fail(error, stackTrace, isExpected: true);
      return;
    } catch (error, stackTrace) {
      _fail(error, stackTrace, isExpected: false);
      return;
    }

    final latestPlausible = _now().add(maxFutureSkew);
    final candidates = comments
        .where(
          (comment) =>
              comment.authorPubkey != _rootAuthorPubkey &&
              !comment.hasVideo &&
              comment.content.trim().isNotEmpty &&
              !comment.id.startsWith(commentPlaceholderIdPrefix) &&
              !comment.createdAt.isAfter(latestPlausible),
        )
        .toList();
    final beforeCounts = _knownModeration();
    final effectiveBeforeCounts = _effectiveModeration(beforeCounts.moderation);
    if (candidates.every(
      (comment) => !_isVisible(comment, effectiveBeforeCounts),
    )) {
      emitIfOpen(
        state.copyWith(
          status: FeedTopCommentStatus.empty,
          appliedModeration: beforeCounts.moderation,
          moderationRevision: beforeCounts.revision,
        ),
      );
      return;
    }

    final votes = await _voteCounts(candidates);
    if (isClosed) return;

    // A relevant cache change while the network reads were in flight is
    // already applied here; it must not cause the host to load the page again.
    final current = _knownModeration();
    final moderation = _effectiveModeration(current.moderation);
    final visibleCandidates = candidates
        .where((comment) => _isVisible(comment, moderation))
        .toList();
    if (visibleCandidates.isEmpty) {
      emitIfOpen(
        state.copyWith(
          status: FeedTopCommentStatus.empty,
          appliedModeration: current.moderation,
          moderationRevision: current.revision,
        ),
      );
      return;
    }
    final compare = commentVoteComparator(
      upvoteCounts: votes.upvotes,
      downvoteCounts: votes.downvotes,
    );
    final top = visibleCandidates.reduce(
      (best, comment) => compare(comment, best) < 0 ? comment : best,
    );
    emitIfOpen(
      state.copyWith(
        status: FeedTopCommentStatus.ready,
        topComment: top,
        appliedModeration: current.moderation,
        moderationRevision: current.revision,
      ),
    );
  }

  /// Populates the authenticated cache alongside the page read. Selection uses
  /// its newest snapshot after vote counts settle, plus local owner blocks.
  Future<CommentModeration> _loadModeration() async {
    final coordinate = _rootAddressableId;
    return coordinate == null || coordinate.isEmpty
        ? CommentModeration.empty
        : await _commentModerationRepository.loadModeration(
            rootAddressableId: coordinate,
          );
  }

  ({CommentModeration moderation, int revision}) _knownModeration() {
    final coordinate = _rootAddressableId;
    return coordinate == null || coordinate.isEmpty
        ? const (moderation: CommentModeration.empty, revision: 0)
        : _commentModerationRepository.knownModeration(
            rootAddressableId: coordinate,
          );
  }

  CommentModeration _effectiveModeration(CommentModeration moderation) =>
      moderation.withAutoHiddenAuthors(
        _viewerPubkey == _rootAuthorPubkey ? _viewerBlockedAuthors : const {},
      );

  bool _isVisible(Comment comment, CommentModeration moderation) =>
      comment.authorPubkey == _viewerPubkey || !moderation.hides(comment);

  /// Hides the overlay for the rest of this video's time on screen.
  void dismiss() {
    if (state.isDismissed) return;
    emit(state.copyWith(isDismissed: true));
  }

  void _onLoopCompleted() {
    if (state.hasCompletedLoop) return;
    emitIfOpen(state.copyWith(hasCompletedLoop: true));
  }

  /// A failed fetch gives every comment zero votes so ties fall back to recency.
  Future<({Map<String, int> upvotes, Map<String, int> downvotes})> _voteCounts(
    List<Comment> comments,
  ) async {
    try {
      return await _likesRepository.getVoteCounts(
        [for (final comment in comments) comment.id],
        addressableIds: {
          for (final comment in comments) comment.id: ?comment.addressableId,
        },
      );
    } on LikesRepositoryException catch (error, stackTrace) {
      addError(error, stackTrace);
      Log.warning(
        'Ranking the top comment of video $_rootEventId without vote counts',
        name: 'FeedTopCommentCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      return const (upvotes: <String, int>{}, downvotes: <String, int>{});
    } catch (error, stackTrace) {
      addError(
        Reportable(error, context: 'FeedTopCommentCubit._voteCounts'),
        stackTrace,
      );
      return const (upvotes: <String, int>{}, downvotes: <String, int>{});
    }
  }

  void _fail(Object error, StackTrace stackTrace, {required bool isExpected}) {
    addError(
      isExpected
          ? error
          : Reportable(error, context: 'FeedTopCommentCubit.load'),
      stackTrace,
    );
    final message = 'Failed to load the top comment of video $_rootEventId';
    if (isExpected) {
      Log.warning(
        message,
        name: 'FeedTopCommentCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      Log.error(
        message,
        name: 'FeedTopCommentCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
    }
    emitIfOpen(state.copyWith(status: FeedTopCommentStatus.failure));
  }

  @override
  Future<void> close() async {
    await _loopSubscription.cancel();
    return super.close();
  }
}
