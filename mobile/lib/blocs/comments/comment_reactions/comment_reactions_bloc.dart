import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/blocs/comments/comment_reactions/reportable_sites.dart';
import 'package:openvine/models/content_moderation.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'comment_reactions_event.dart';
part 'comment_reactions_state.dart';

/// BLoC owning vote state + moderation actions for one video's comments.
///
/// Responsibilities:
/// - Voting: optimistic update + relay publish via [LikesRepository], with
///   the four state-sync sentinels ([AlreadyLikedException], etc.) handled
///   silently to reconcile pre-tap state without surfacing as failures.
/// - Vote count batch fetch on demand (UI bridges from [CommentsListBloc]).
/// - Reporting (Kind 1984) via [ContentReportingService].
/// - Blocking (Kind 10000 mute) via [ContentBlocklistRepository]; emits
///   [ReactionsOutboxRemoveByAuthor] for list cleanup.
/// - Deleting via [CommentsRepository.deleteComment]; emits
///   [ReactionsOutboxRemoveComment] for list cleanup.
class CommentReactionsBloc
    extends Bloc<CommentReactionsEvent, CommentReactionsState> {
  CommentReactionsBloc({
    required AuthService authService,
    required LikesRepository likesRepository,
    required CommentsRepository commentsRepository,
    required Future<ContentReportingService> contentReportingServiceFuture,
    required ContentBlocklistRepository contentBlocklistRepository,
    required String rootEventId,
    String? rootAddressableId,
  }) : _authService = authService,
       _likesRepository = likesRepository,
       _commentsRepository = commentsRepository,
       _contentReportingServiceFuture = contentReportingServiceFuture,
       _contentBlocklistRepository = contentBlocklistRepository,
       _rootEventId = rootEventId,
       _rootAddressableId = rootAddressableId,
       super(const CommentReactionsState()) {
    on<CommentVoteToggled>(_onVoteToggled, transformer: droppable());
    // restartable(): on a fast comment stream the UI bridge dispatches a
    // fetch for each new id batch. Without this, a slow earlier fetch
    // returning after a newer one could clobber the fresher counts.
    on<CommentVoteCountsFetchRequested>(
      _onVoteCountsFetchRequested,
      transformer: restartable(),
    );
    on<CommentReportRequested>(_onReportRequested, transformer: droppable());
    on<CommentBlockUserRequested>(
      _onBlockUserRequested,
      transformer: droppable(),
    );
    on<CommentDeleteRequested>(_onDeleteRequested, transformer: droppable());
    on<CommentReactionsErrorCleared>(_onErrorCleared);
    on<ReactionsOutboxConsumed>(_onOutboxConsumed);
  }

  final AuthService _authService;
  final LikesRepository _likesRepository;
  final CommentsRepository _commentsRepository;
  final Future<ContentReportingService> _contentReportingServiceFuture;
  final ContentBlocklistRepository _contentBlocklistRepository;
  final String _rootEventId;
  final String? _rootAddressableId;

  /// Logs [error] to the unified log and forwards through [addError]. Wraps
  /// with [Reportable] (matrix-YES → Crashlytics) when [error] is not one of
  /// the named domain-exception types this bloc is expected to throw.
  ///
  /// The named [LikesRepositoryException] / [CommentsRepositoryException]
  /// types are matrix-NO per rules/error_handling.md (network/IO + API
  /// domain). Anything else — `StateError`, `TypeError`, project-owned
  /// `*InvariantException`s, etc. — must reach Crashlytics.
  ///
  /// [treatExceptionAsDomain] is for call sites whose underlying dependency
  /// throws untyped [Exception] subtypes (e.g.
  /// [ContentBlocklistRepository.blockUser] doesn't ship a typed exception
  /// hierarchy yet). Set to true ONLY where the original code used
  /// `on Exception catch` to keep relay/network failures out of Crashlytics.
  void _logFailure(
    Object error,
    StackTrace stackTrace,
    String site,
    String operation, {
    bool treatExceptionAsDomain = false,
  }) {
    final isMatrixNo =
        error is LikesRepositoryException ||
        error is CommentsRepositoryException ||
        (treatExceptionAsDomain && error is Exception);
    if (isMatrixNo) {
      addError(error, stackTrace);
    } else {
      addError(Reportable(error, context: site), stackTrace);
    }
    Log.error(
      '$operation: $error',
      name: 'CommentReactionsBloc',
      category: LogCategory.ui,
    );
  }

  void _onErrorCleared(
    CommentReactionsErrorCleared event,
    Emitter<CommentReactionsState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onOutboxConsumed(
    ReactionsOutboxConsumed event,
    Emitter<CommentReactionsState> emit,
  ) {
    // The UI may dispatch a duplicate ack during rebuild/listener churn; once
    // outbox is null, extra acks are harmless no-ops.
    if (state.outbox == null) return;
    emit(state.copyWith(clearOutbox: true));
  }

  Future<void> _onVoteCountsFetchRequested(
    CommentVoteCountsFetchRequested event,
    Emitter<CommentReactionsState> emit,
  ) async {
    if (event.commentIds.isEmpty) return;

    try {
      final results = await Future.wait([
        _likesRepository.getVoteCounts(
          event.commentIds,
          addressableIds: event.addressableIdsByCommentId,
        ),
        _likesRepository.getUserVoteStatuses(
          event.commentIds,
          addressableIds: event.addressableIdsByCommentId,
        ),
      ]);

      final voteCounts =
          results[0]
              as ({Map<String, int> upvotes, Map<String, int> downvotes});
      final voteStatuses =
          results[1] as ({Set<String> upvotedIds, Set<String> downvotedIds});

      // Merge into existing maps/sets rather than replacing — keep
      // previously-fetched counts for ids not in this batch so an
      // incremental fetch (only newly-loaded comments) doesn't lose
      // already-known counts.
      emit(
        state.copyWith(
          commentUpvoteCounts: {
            ...state.commentUpvoteCounts,
            ...voteCounts.upvotes,
          },
          commentDownvoteCounts: {
            ...state.commentDownvoteCounts,
            ...voteCounts.downvotes,
          },
          upvotedCommentIds: {
            ...state.upvotedCommentIds,
            ...voteStatuses.upvotedIds,
          },
          downvotedCommentIds: {
            ...state.downvotedCommentIds,
            ...voteStatuses.downvotedIds,
          },
        ),
      );
    } catch (e, stackTrace) {
      // LikesRepository fetch IO — matrix-NO (Network/IO). UI silently
      // misses vote counts but the rest of the screen is unaffected.
      _logFailure(
        e,
        stackTrace,
        CommentReactionsBlocReportableSites.onVoteCountsFetchRequested,
        'Error fetching comment vote counts',
      );
    }
  }

  Future<void> _onVoteToggled(
    CommentVoteToggled event,
    Emitter<CommentReactionsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: ReactionsError.notAuthenticated));
      return;
    }

    final commentId = event.commentId;
    final isUpvote = event.vote == Vote.up;

    final wasUpvoted = state.upvotedCommentIds.contains(commentId);
    final wasDownvoted = state.downvotedCommentIds.contains(commentId);
    final hadSameVote = isUpvote ? wasUpvoted : wasDownvoted;
    final hadOppositeVote = isUpvote ? wasDownvoted : wasUpvoted;
    final prevUpCount = state.commentUpvoteCounts[commentId] ?? 0;
    final prevDownCount = state.commentDownvoteCounts[commentId] ?? 0;

    // Optimistic update.
    final upIds = Set<String>.from(state.upvotedCommentIds);
    final downIds = Set<String>.from(state.downvotedCommentIds);
    final upCounts = Map<String, int>.from(state.commentUpvoteCounts);
    final downCounts = Map<String, int>.from(state.commentDownvoteCounts);

    final sameIds = isUpvote ? upIds : downIds;
    final sameCounts = isUpvote ? upCounts : downCounts;
    final prevSameCount = isUpvote ? prevUpCount : prevDownCount;
    final oppositeIds = isUpvote ? downIds : upIds;
    final oppositeCounts = isUpvote ? downCounts : upCounts;
    final prevOppositeCount = isUpvote ? prevDownCount : prevUpCount;

    if (hadSameVote) {
      sameIds.remove(commentId);
      sameCounts[commentId] = max(0, prevSameCount - 1);
    } else {
      sameIds.add(commentId);
      sameCounts[commentId] = prevSameCount + 1;
      if (hadOppositeVote) {
        oppositeIds.remove(commentId);
        oppositeCounts[commentId] = max(0, prevOppositeCount - 1);
      }
    }

    emit(
      state.copyWith(
        upvotedCommentIds: upIds,
        downvotedCommentIds: downIds,
        commentUpvoteCounts: upCounts,
        commentDownvoteCounts: downCounts,
      ),
    );

    try {
      // Remove the existing vote (same or opposite) first. The repo tracks
      // upvotes in _likeRecords and downvotes in _downvoteRecords; pick the
      // right teardown call based on which side actually had it.
      if (hadSameVote || hadOppositeVote) {
        // A teardown miss must not abort the placement below. The repo's
        // downvote cache is in-memory only, so after a cold start removing a
        // pre-restart vote reports "not voted" even though the new vote still
        // needs publishing — previously that threw past the placement and the
        // UI showed a vote that was never sent (#6124).
        try {
          if (wasUpvoted) {
            await _likesRepository.unlikeEvent(
              commentId,
              addressableId: event.addressableId,
            );
          } else {
            await _likesRepository.removeDownvote(
              commentId,
              addressableId: event.addressableId,
            );
          }
        } on NotLikedException {
          // Nothing to remove; the optimistic update already reflects that.
        } on NotDownvotedException {
          // Nothing to remove; the optimistic update already reflects that.
        }
      }

      // Place the new vote (only when this tap isn't a same-side removal).
      if (!hadSameVote) {
        // NIP-25: `a` and `k` describe the event being reacted to, so both
        // come from the target itself. A Kind 34236 video reply is
        // addressable and carries a coordinate; a Kind 1111 comment does not
        // and passes null (#6124).
        final targetKind = event.targetKind ?? EventKind.comment;
        if (isUpvote) {
          await _likesRepository.likeEvent(
            eventId: commentId,
            authorPubkey: event.authorPubkey,
            targetKind: targetKind,
            addressableId: event.addressableId,
          );
        } else {
          await _likesRepository.downvoteEvent(
            eventId: commentId,
            authorPubkey: event.authorPubkey,
            targetKind: targetKind,
            addressableId: event.addressableId,
          );
        }
      }
    } on AlreadyLikedException {
      // State-sync sentinel (silent): repo already had the upvote, the
      // pre-tap baseline was wrong. Reconcile and continue.
      emit(
        state.copyWith(
          upvotedCommentIds: Set<String>.from(state.upvotedCommentIds)
            ..add(commentId),
          downvotedCommentIds: Set<String>.from(state.downvotedCommentIds)
            ..remove(commentId),
        ),
      );
    } on AlreadyDownvotedException {
      // State-sync sentinel (silent): repo already had the downvote.
      emit(
        state.copyWith(
          downvotedCommentIds: Set<String>.from(state.downvotedCommentIds)
            ..add(commentId),
          upvotedCommentIds: Set<String>.from(state.upvotedCommentIds)
            ..remove(commentId),
        ),
      );
    } catch (e, stackTrace) {
      // LikesRepository publish IO is matrix-NO; anything else is wrapped
      // with Reportable inside _logFailure. Revert the optimistic update.
      _logFailure(
        e,
        stackTrace,
        CommentReactionsBlocReportableSites.onVoteToggled,
        'Error toggling comment ${isUpvote ? 'upvote' : 'downvote'}',
      );
      emit(
        state.copyWith(
          upvotedCommentIds: Set<String>.from(state.upvotedCommentIds)
            ..addAll(wasUpvoted ? {commentId} : {})
            ..removeAll(wasUpvoted ? {} : {commentId}),
          downvotedCommentIds: Set<String>.from(state.downvotedCommentIds)
            ..addAll(wasDownvoted ? {commentId} : {})
            ..removeAll(wasDownvoted ? {} : {commentId}),
          commentUpvoteCounts: Map<String, int>.from(state.commentUpvoteCounts)
            ..[commentId] = prevUpCount,
          commentDownvoteCounts: Map<String, int>.from(
            state.commentDownvoteCounts,
          )..[commentId] = prevDownCount,
          error: ReactionsError.voteFailed,
        ),
      );
    }
  }

  Future<void> _onReportRequested(
    CommentReportRequested event,
    Emitter<CommentReactionsState> emit,
  ) async {
    try {
      final reportingService = await _contentReportingServiceFuture;
      final result = await reportingService.reportContent(
        eventId: event.commentId,
        authorPubkey: event.authorPubkey,
        reason: event.reason,
        details: event.details,
      );
      // The result carries two separate claims and the UI needs both:
      // `success` is false for an uninitialized service, a missing signer,
      // or an unbuildable event, and a `success` report can still have
      // reached no channel off this device (#6387). Neither throws, so
      // discarding the result showed the user a silent success (#6595).
      // A deliberately refused report (a self-report, #8352) is a silent
      // success like `reached` — it must not surface as a failure the user
      // could "retry", since it will always refuse identically.
      if (!result.isSilentSuccess) {
        Log.warning(
          'Comment report not delivered '
          '(success=${result.success}, delivery=${result.delivery}): '
          '${result.error ?? 'reached no channel'}',
          name: 'CommentReactionsBloc',
          category: LogCategory.ui,
        );
        emit(state.copyWith(error: ReactionsError.reportFailed));
      }
    } catch (e, stackTrace) {
      // ContentReportingService returns a typed failure result for normal
      // domain issues; a throw escaping here is unexpected.
      _logFailure(
        e,
        stackTrace,
        CommentReactionsBlocReportableSites.onReportRequested,
        'Error reporting comment',
      );
      emit(state.copyWith(error: ReactionsError.reportFailed));
    }
  }

  Future<void> _onBlockUserRequested(
    CommentBlockUserRequested event,
    Emitter<CommentReactionsState> emit,
  ) async {
    try {
      await _contentBlocklistRepository.blockUser(event.authorPubkey);
    } catch (e, stackTrace) {
      // ContentBlocklistRepository persist + kind-30000 broadcast IO failures
      // are expected-domain/IO here, so treatExceptionAsDomain matches the
      // original `on Exception catch` to keep them out of Crashlytics.
      _logFailure(
        e,
        stackTrace,
        CommentReactionsBlocReportableSites.onBlockUserRequested,
        'Error blocking user',
        treatExceptionAsDomain: true,
      );
      emit(state.copyWith(error: ReactionsError.blockFailed));
      return;
    }

    // Block is durable at this point; drop the author's comments from the
    // list so the user sees it confirmed.
    //
    // Severing the follow is not this bloc's job: FollowRepository drops
    // blocked accounts from the kind 3 it publishes, and the app-level
    // reconciler triggers that republish (#6903).
    emit(
      state.copyWith(outbox: ReactionsOutboxRemoveByAuthor(event.authorPubkey)),
    );
  }

  Future<void> _onDeleteRequested(
    CommentDeleteRequested event,
    Emitter<CommentReactionsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: ReactionsError.notAuthenticated));
      return;
    }

    try {
      await _commentsRepository.deleteComment(
        commentId: event.commentId,
        rootEventId: _rootEventId,
        rootAddressableId: _rootAddressableId,
      );
      emit(
        state.copyWith(outbox: ReactionsOutboxRemoveComment(event.commentId)),
      );
    } catch (e, stackTrace) {
      // DeleteCommentFailedException + relay broadcast IO — matrix-NO.
      _logFailure(
        e,
        stackTrace,
        CommentReactionsBlocReportableSites.onDeleteRequested,
        'Error deleting comment',
      );
      emit(state.copyWith(error: ReactionsError.deleteCommentFailed));
    }
  }
}
