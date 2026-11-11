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
import 'package:openvine/blocs/sequential_by_key.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/auth_service.dart';
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
    required ContentBlocklistRepository contentBlocklistRepository,
    required String rootEventId,
    String? rootAddressableId,
  }) : _authService = authService,
       _likesRepository = likesRepository,
       _commentsRepository = commentsRepository,
       _contentBlocklistRepository = contentBlocklistRepository,
       _rootEventId = rootEventId,
       _rootAddressableId = rootAddressableId,
       super(const CommentReactionsState()) {
    // Per comment: votes on different comments publish side by side, and
    // taps on one comment run in order, so an up and a down never interleave
    // their kind 7 and kind 5 publishes (#8168).
    on<CommentVoteToggled>(
      _onVoteToggled,
      transformer: sequentialByKey((event) => event.commentId),
    );
    // Disjoint batches load concurrently. The handler deduplicates pending ids.
    on<CommentVoteCountsFetchRequested>(_onVoteCountsFetchRequested);
    // sequential(): every block republishes the whole kind 10000 mute list,
    // so two at once would race to replace it; each block still runs (#8168).
    on<CommentBlockUserRequested>(
      _onBlockUserRequested,
      transformer: sequential(),
    );
    // Per comment: deleting one comment never waits on another's relay OK,
    // and a repeat for the same comment queues behind the first (#8168).
    on<CommentDeleteRequested>(
      _onDeleteRequested,
      transformer: sequentialByKey((event) => event.commentId),
    );
    on<CommentReactionsErrorCleared>(_onErrorCleared);
    on<ReactionsOutboxConsumed>(_onOutboxConsumed);
  }

  final AuthService _authService;
  final LikesRepository _likesRepository;
  final CommentsRepository _commentsRepository;
  final ContentBlocklistRepository _contentBlocklistRepository;
  final String _rootEventId;
  final String? _rootAddressableId;

  // A pending read may finish after the viewer changes their vote. Keep the
  // read in flight for deduplication, while ignoring its stale result.
  final _voteReads = <String, bool>{};
  final _publishingVotes = <String>{};
  final _confirmedLocalVotes = <String>{};
  final _voteRefreshAfterPublish = <String, CommentVoteCountsFetchRequested>{};

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
    final commentIds = <String>[];
    for (final id in event.commentIds) {
      if (_voteReads.containsKey(id)) continue;
      _voteReads[id] = !_publishingVotes.contains(id);
      commentIds.add(id);
    }
    if (commentIds.isEmpty) return;

    bool canApply(String id) => _voteReads[id] == true;

    Future<void> loadCounts() async {
      final counts = await _likesRepository.getVoteCounts(
        commentIds,
        addressableIds: event.addressableIdsByCommentId,
      );
      if (emit.isDone) return;

      emit(
        state.copyWith(
          commentUpvoteCounts: {
            ...state.commentUpvoteCounts,
            for (final entry in counts.upvotes.entries)
              if (canApply(entry.key)) entry.key: entry.value,
          },
          commentDownvoteCounts: {
            ...state.commentDownvoteCounts,
            for (final entry in counts.downvotes.entries)
              if (canApply(entry.key)) entry.key: entry.value,
          },
        ),
      );
    }

    Future<void> loadViewerVotes() async {
      // A confirmed local action is newer than the viewer's relay snapshot.
      final viewerIds = commentIds
          .where((id) => !_confirmedLocalVotes.contains(id))
          .toList();
      if (viewerIds.isEmpty) return;

      final votes = await _likesRepository.getUserVoteStatuses(
        viewerIds,
        addressableIds: event.addressableIdsByCommentId,
      );
      if (emit.isDone) return;

      final refreshed = viewerIds.where(canApply).toSet();
      emit(
        state.copyWith(
          upvotedCommentIds: {
            ...state.upvotedCommentIds.difference(refreshed),
            ...votes.upvotedIds.where(refreshed.contains),
          },
          downvotedCommentIds: {
            ...state.downvotedCommentIds.difference(refreshed),
            ...votes.downvotedIds.where(refreshed.contains),
          },
        ),
      );
    }

    try {
      await Future.wait([loadCounts(), loadViewerVotes()]);
    } catch (e, stackTrace) {
      _logFailure(
        e,
        stackTrace,
        CommentReactionsBlocReportableSites.onVoteCountsFetchRequested,
        'Error fetching comment votes',
      );
    } finally {
      for (final id in commentIds) {
        final invalidated = _voteReads.remove(id) == false;
        if (invalidated && !isClosed) {
          final refresh = CommentVoteCountsFetchRequested(
            [id],
            addressableIdsByCommentId: {
              id: ?event.addressableIdsByCommentId[id],
            },
          );
          if (_publishingVotes.contains(id)) {
            _voteRefreshAfterPublish[id] = refresh;
          } else {
            add(refresh);
          }
        }
      }
    }
  }

  /// [counts] with [id] set back to [count], or without [id] when it was
  /// never loaded.
  static Map<String, int> _restoreCount(
    Map<String, int> counts,
    String id,
    int? count,
  ) => count == null ? ({...counts}..remove(id)) : {...counts, id: count};

  Future<void> _onVoteToggled(
    CommentVoteToggled event,
    Emitter<CommentReactionsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: ReactionsError.notAuthenticated));
      return;
    }

    final commentId = event.commentId;
    _publishingVotes.add(commentId);
    if (_voteReads.containsKey(commentId)) _voteReads[commentId] = false;
    final isUpvote = event.vote == Vote.up;

    final wasUpvoted = state.upvotedCommentIds.contains(commentId);
    final wasDownvoted = state.downvotedCommentIds.contains(commentId);
    final hadSameVote = isUpvote ? wasUpvoted : wasDownvoted;
    final hadOppositeVote = isUpvote ? wasDownvoted : wasUpvoted;
    // Null means the total never loaded. Adjusting it would show a guess as
    // a real count, so leave it unknown and read both once the vote settles.
    final prevUpCount = state.commentUpvoteCounts[commentId];
    final prevDownCount = state.commentDownvoteCounts[commentId];
    if (prevUpCount == null || prevDownCount == null) {
      _voteRefreshAfterPublish[commentId] ??= CommentVoteCountsFetchRequested(
        [commentId],
        addressableIdsByCommentId: {commentId: ?event.addressableId},
      );
    }

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

    void adjust(Map<String, int> counts, int? previous, int delta) {
      if (previous != null) counts[commentId] = max(0, previous + delta);
    }

    if (hadSameVote) {
      sameIds.remove(commentId);
      adjust(sameCounts, prevSameCount, -1);
    } else {
      sameIds.add(commentId);
      adjust(sameCounts, prevSameCount, 1);
      if (hadOppositeVote) {
        oppositeIds.remove(commentId);
        adjust(oppositeCounts, prevOppositeCount, -1);
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
      _confirmedLocalVotes.add(commentId);
    } on AlreadyLikedException {
      _confirmedLocalVotes.add(commentId);
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
      _confirmedLocalVotes.add(commentId);
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
          commentUpvoteCounts: _restoreCount(
            state.commentUpvoteCounts,
            commentId,
            prevUpCount,
          ),
          commentDownvoteCounts: _restoreCount(
            state.commentDownvoteCounts,
            commentId,
            prevDownCount,
          ),
          error: ReactionsError.voteFailed,
        ),
      );
    } finally {
      _publishingVotes.remove(commentId);
      final refresh = _voteRefreshAfterPublish.remove(commentId);
      if (refresh != null && !isClosed) add(refresh);
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
