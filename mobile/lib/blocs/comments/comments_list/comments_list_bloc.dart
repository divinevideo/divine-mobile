import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/blocs/comments/comments_list/reportable_sites.dart';
import 'package:openvine/blocs/comments/comments_list/throttled_subscription.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:unified_logger/unified_logger.dart';

part 'comments_list_event.dart';
part 'comments_list_state.dart';

/// BLoC owning the canonical store of [Comment]s for one video.
///
/// Loads, paginates, sorts, and watches the live stream of comments for one
/// video. Mutations from [CommentComposerBloc] and [CommentReactionsBloc]
/// flow in through UI [BlocListener]s as Optimistic*/CommentReplacedInStore /
/// CommentRemovedFromStore / CommentsRemovedByAuthorFromStore events.
/// Engagement sort needs upvote counts from [CommentReactionsBloc] — see
/// [CommentsListState.threadedCommentsWith].
class CommentsListBloc extends Bloc<CommentsListEvent, CommentsListState> {
  CommentsListBloc({
    required CommentsRepository commentsRepository,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
    String? rootAddressableId,
    int? initialTotalCount,
    bool includeVideoReplies = false,
  }) : _commentsRepository = commentsRepository,
       _initialTotalCount = initialTotalCount,
       _includeVideoReplies = includeVideoReplies,
       super(
         CommentsListState(
           rootEventId: rootEventId,
           rootEventKind: rootEventKind,
           rootAuthorPubkey: rootAuthorPubkey,
           rootAddressableId: rootAddressableId,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentsLoadMoreRequested>(_onLoadMoreRequested);
    on<CommentsSortModeChanged>(_onSortModeChanged);
    on<NewCommentReceived>(_onNewCommentReceived);
    on<CommentsInitialBackfillCompleted>(_onInitialBackfillCompleted);
    on<NewCommentsAcknowledged>(_onNewCommentsAcknowledged);
    on<CommentsListErrorCleared>(_onErrorCleared);
    on<CommentsScrollHandled>(_onScrollHandled);
    on<OptimisticCommentInserted>(_onOptimisticCommentInserted);
    on<OptimisticCommentConfirmed>(_onOptimisticCommentConfirmed);
    on<OptimisticCommentRolledBack>(_onOptimisticCommentRolledBack);
    on<CommentReplacedInStore>(_onCommentReplacedInStore);
    on<CommentRemovedFromStore>(_onCommentRemovedFromStore);
    on<CommentsRemovedByAuthorFromStore>(_onCommentsRemovedByAuthorFromStore);
  }

  /// Page size for comment loading.
  static const _pageSize = 50;

  /// Maximum number of real-time comments to accept per second.
  /// Beyond this rate the stream is paused briefly to avoid UI thrashing
  /// on viral videos.
  static const _maxCommentsPerSecond = 10;

  /// Optional initial total count from video metadata or interactions state.
  /// Used to accurately determine hasMoreContent instead of page size heuristic.
  final int? _initialTotalCount;

  final CommentsRepository _commentsRepository;
  final bool _includeVideoReplies;
  StreamSubscription<Comment>? _commentStreamSubscription;

  /// Records a [CommentsRepositoryException] in the unified log (matrix-NO,
  /// stays out of Crashlytics — see `rules/error_handling.md`).
  void _logRepoFailure(Object error, StackTrace stackTrace, String operation) {
    addError(error, stackTrace);
    Log.error(
      '$operation: $error',
      name: 'CommentsListBloc',
      category: LogCategory.ui,
    );
  }

  /// Records an unexpected throw via [Reportable] (matrix-YES → Crashlytics)
  /// and logs to the unified log.
  void _logUnexpectedFailure(
    Object error,
    StackTrace stackTrace,
    String site,
    String operation,
  ) {
    addError(Reportable(error, context: site), stackTrace);
    Log.error(
      '$operation: $error',
      name: 'CommentsListBloc',
      category: LogCategory.ui,
    );
  }

  Future<void> _onLoadRequested(
    CommentsLoadRequested event,
    Emitter<CommentsListState> emit,
  ) async {
    if (state.status == CommentsStatus.loading) return;

    emit(
      state.copyWith(
        status: CommentsStatus.loading,
        newCommentCount: 0,
        isBackfillComplete: false,
      ),
    );

    try {
      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        limit: _pageSize,
        includeVideoReplies: _includeVideoReplies,
      );

      final commentsById = {
        ...state.commentsById,
        for (final comment in thread.comments) comment.id: comment,
      };
      final hasMore = _hasMoreContent(
        loadedCount: commentsById.length,
        lastBatchCount: thread.comments.length,
        threadTotalCount: thread.totalCount,
        threadHasMore: thread.hasMore,
      );

      emit(
        state.copyWith(
          status: CommentsStatus.success,
          commentsById: commentsById,
          hasMoreContent: hasMore,
          replyCountsByCommentId: computeReplyCounts(commentsById),
        ),
      );
      await _startWatchingComments();
    } on CommentsRepositoryException catch (e, stackTrace) {
      // *FailedException + relay timeouts are matrix-NO (API/domain +
      // Network/IO). addError logs without flagging Reportable so they stay
      // out of Crashlytics — see rules/error_handling.md.
      _logRepoFailure(e, stackTrace, 'Error loading comments');
      _emitLoadFailureOrRecover(emit);
    } catch (e, stackTrace) {
      _logUnexpectedFailure(
        e,
        stackTrace,
        CommentsListBlocReportableSites.onLoadRequested,
        'Error loading comments',
      );
      _emitLoadFailureOrRecover(emit);
    }
  }

  void _emitLoadFailureOrRecover(Emitter<CommentsListState> emit) {
    final hasLoadedRealComments = state.commentsById.keys.any(
      (id) => !id.startsWith(commentPlaceholderIdPrefix),
    );
    if (hasLoadedRealComments) {
      emit(state.copyWith(status: CommentsStatus.success));
      return;
    }
    emit(
      state.copyWith(
        status: CommentsStatus.failure,
        error: CommentsListError.loadFailed,
      ),
    );
  }

  Future<void> _onLoadMoreRequested(
    CommentsLoadMoreRequested event,
    Emitter<CommentsListState> emit,
  ) async {
    if (state.status != CommentsStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent ||
        state.commentsById.isEmpty) {
      return;
    }

    // Cursor = min createdAt across non-placeholder comments. Sort-mode
    // agnostic so `oldest` / `topEngagement` don't fold to the wrong cursor.
    // Returns early if every comment is an optimistic placeholder.
    final realCreatedAts = state.commentsById.values
        .where((c) => !c.id.startsWith(commentPlaceholderIdPrefix))
        .map((c) => c.createdAt);
    if (realCreatedAts.isEmpty) return;
    final cursor = realCreatedAts.reduce((a, b) => a.isBefore(b) ? a : b);

    emit(state.copyWith(isLoadingMore: true));

    try {
      Log.info(
        'Loading more comments before $cursor',
        name: 'CommentsListBloc',
        category: LogCategory.ui,
      );

      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        limit: _pageSize,
        before: cursor,
        includeVideoReplies: _includeVideoReplies,
      );

      final allCommentsById = {
        ...state.commentsById,
        for (final c in thread.comments) c.id: c,
      };

      emit(
        state.copyWith(
          commentsById: allCommentsById,
          isLoadingMore: false,
          hasMoreContent: _hasMoreContent(
            loadedCount: allCommentsById.length,
            lastBatchCount: thread.comments.length,
            threadTotalCount: thread.totalCount,
            threadHasMore: thread.hasMore,
          ),
          replyCountsByCommentId: computeReplyCounts(allCommentsById),
        ),
      );
    } on CommentsRepositoryException catch (e, stackTrace) {
      _logRepoFailure(e, stackTrace, 'Error loading more comments');
      emit(
        state.copyWith(
          isLoadingMore: false,
          error: CommentsListError.loadFailed,
        ),
      );
    } catch (e, stackTrace) {
      _logUnexpectedFailure(
        e,
        stackTrace,
        CommentsListBlocReportableSites.onLoadMoreRequested,
        'Error loading more comments',
      );
      emit(
        state.copyWith(
          isLoadingMore: false,
          error: CommentsListError.loadFailed,
        ),
      );
    }
  }

  void _onSortModeChanged(
    CommentsSortModeChanged event,
    Emitter<CommentsListState> emit,
  ) {
    emit(state.copyWith(sortMode: event.sortMode));
  }

  void _onErrorCleared(
    CommentsListErrorCleared event,
    Emitter<CommentsListState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onScrollHandled(
    CommentsScrollHandled event,
    Emitter<CommentsListState> emit,
  ) {
    if (state.scrollToCommentId == null) return;
    emit(state.copyWith(clearScrollTo: true));
  }

  void _onNewCommentReceived(
    NewCommentReceived event,
    Emitter<CommentsListState> emit,
  ) {
    final comment = event.comment;

    // Skip if already in the map by id (relay echo of a confirmed comment),
    // unless the echo carries video metadata missing from the REST bootstrap
    // copy. In that case, upgrade in place so a REST-loaded video reply can
    // render as soon as the relay echo arrives.
    // Blocked/muted authors are already filtered by the repository's
    // watchComments stream, so no additional check is needed here.
    final existingComment = state.commentsById[comment.id];
    if (existingComment != null) {
      if (!existingComment.hasVideo && comment.hasVideo) {
        _emitStore(
          emit,
          Map<String, Comment>.from(state.commentsById)
            ..[comment.id] = existingComment.copyWith(
              videoUrl: comment.videoUrl,
              thumbnailUrl: comment.thumbnailUrl,
              videoDimensions: comment.videoDimensions,
              videoDuration: comment.videoDuration,
              videoBlurhash: comment.videoBlurhash,
            ),
        );
      }
      return;
    }

    // Optimistic-post reconciliation: if a pending placeholder matches this
    // relay echo by author + content, swap it for the canonical comment so
    // the user sees their own post settle into its real id without a
    // duplicate row. Counter does not bump because the placeholder was
    // already on screen.
    String? placeholderToReplace;
    for (final entry in state.commentsById.entries) {
      final existing = entry.value;
      if (existing.id.startsWith(commentPlaceholderIdPrefix) &&
          existing.authorPubkey == comment.authorPubkey &&
          existing.content == comment.content) {
        placeholderToReplace = entry.key;
        break;
      }
    }

    final updated = Map<String, Comment>.from(state.commentsById);
    if (placeholderToReplace != null) updated.remove(placeholderToReplace);
    updated[comment.id] = comment;
    final isReplacingPlaceholder = placeholderToReplace != null;

    emit(
      state.copyWith(
        status: CommentsStatus.success,
        commentsById: updated,
        replyCountsByCommentId: computeReplyCounts(updated),
        newCommentCount: state.isBackfillComplete && !isReplacingPlaceholder
            ? state.newCommentCount + 1
            : state.newCommentCount,
      ),
    );
  }

  void _onInitialBackfillCompleted(
    CommentsInitialBackfillCompleted event,
    Emitter<CommentsListState> emit,
  ) {
    emit(state.copyWith(isBackfillComplete: true));
  }

  void _onNewCommentsAcknowledged(
    NewCommentsAcknowledged event,
    Emitter<CommentsListState> emit,
  ) {
    emit(state.copyWith(newCommentCount: 0));
  }

  void _emitStore(
    Emitter<CommentsListState> emit,
    Map<String, Comment> updated,
  ) {
    emit(
      state.copyWith(
        commentsById: updated,
        replyCountsByCommentId: computeReplyCounts(updated),
      ),
    );
  }

  void _onOptimisticCommentInserted(
    OptimisticCommentInserted event,
    Emitter<CommentsListState> emit,
  ) {
    // Flag the just-inserted comment for scroll-into-view only when it is a
    // reply: a reply nests under an (often older) parent and would otherwise
    // render off-screen, so the poster thinks the post failed and retries
    // (#5854). A new top-level comment already lands at the visible top, so it
    // needs no scroll. The UI scrolls to the flagged id then acks via
    // [CommentsScrollHandled].
    final updated = {
      ...state.commentsById,
      event.placeholder.id: event.placeholder,
    };
    final isReply = event.placeholder.replyToEventId != null;
    emit(
      state.copyWith(
        commentsById: updated,
        replyCountsByCommentId: computeReplyCounts(updated),
        scrollToCommentId: isReply ? event.placeholder.id : null,
      ),
    );
  }

  void _onOptimisticCommentConfirmed(
    OptimisticCommentConfirmed event,
    Emitter<CommentsListState> emit,
  ) {
    // Race-safe: if the relay echo arrived first via NewCommentReceived, the
    // confirmed id is already present in the store and the placeholder has
    // been swapped out. Just clean up any leftover placeholder.
    if (state.commentsById.containsKey(event.confirmed.id)) {
      if (!state.commentsById.containsKey(event.placeholderId)) return;
      _emitStore(
        emit,
        Map<String, Comment>.from(state.commentsById)
          ..remove(event.placeholderId),
      );
      return;
    }

    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)
        ..remove(event.placeholderId)
        ..[event.confirmed.id] = event.confirmed,
    );
  }

  void _onOptimisticCommentRolledBack(
    OptimisticCommentRolledBack event,
    Emitter<CommentsListState> emit,
  ) {
    if (!state.commentsById.containsKey(event.placeholderId)) return;
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)
        ..remove(event.placeholderId),
    );
  }

  void _onCommentReplacedInStore(
    CommentReplacedInStore event,
    Emitter<CommentsListState> emit,
  ) {
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)
        ..remove(event.oldId)
        ..[event.newComment.id] = event.newComment,
    );
  }

  void _onCommentRemovedFromStore(
    CommentRemovedFromStore event,
    Emitter<CommentsListState> emit,
  ) {
    if (!state.commentsById.containsKey(event.commentId)) return;
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)..remove(event.commentId),
    );
  }

  void _onCommentsRemovedByAuthorFromStore(
    CommentsRemovedByAuthorFromStore event,
    Emitter<CommentsListState> emit,
  ) {
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)
        ..removeWhere((_, c) => c.authorPubkey == event.authorPubkey),
    );
  }

  /// Starts the real-time comment subscription.
  ///
  /// Called from [_onLoadRequested] after the initial load so the REST-backed
  /// first paint is not blocked by relay backfill. Routes incoming comments
  /// through [NewCommentReceived].
  Future<void> _startWatchingComments() async {
    // Detached on purpose: the replacement subscription does not depend on the
    // old one finishing teardown, and awaiting here suspends between reading
    // _commentStreamSubscription and assigning it. _onLoadRequested emits
    // success before calling this, so its `status == loading` guard is open
    // during that window and a second load can enter, leaving the first
    // subscription assigned over and never cancelled. Pinned by
    // comments_list_reload_race_test.dart.
    unawaited(_commentStreamSubscription?.cancel());

    try {
      final stream = _commentsRepository.watchComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        includeVideoReplies: _includeVideoReplies,
        onEose: () {
          if (!isClosed) add(const CommentsInitialBackfillCompleted());
        },
      );

      _commentStreamSubscription = throttledListen(
        stream,
        maxPerSecond: _maxCommentsPerSecond,
        onData: (comment) {
          if (!isClosed) add(NewCommentReceived(comment));
        },
        onError: (Object e) {
          Log.warning(
            'Comment watch stream error: $e',
            name: 'CommentsListBloc',
            category: LogCategory.ui,
          );
        },
      );
    } on CommentsRepositoryException catch (e, stackTrace) {
      _logRepoFailure(e, stackTrace, 'Failed to start watching comments');
    } catch (e, stackTrace) {
      _logUnexpectedFailure(
        e,
        stackTrace,
        CommentsListBlocReportableSites.startWatchingComments,
        'Failed to start watching comments',
      );
    }
  }

  @override
  Future<void> close() async {
    await _commentStreamSubscription?.cancel();
    await _commentsRepository.stopWatchingComments();
    return super.close();
  }

  bool _hasMoreContent({
    required int loadedCount,
    required int lastBatchCount,
    required int threadTotalCount,
    bool? threadHasMore,
  }) {
    if (threadHasMore != null) return threadHasMore;

    final effectiveTotalCount =
        _initialTotalCount ??
        (threadTotalCount > lastBatchCount
            ? threadTotalCount
            : lastBatchCount < _pageSize
            ? loadedCount
            : null);

    if (effectiveTotalCount != null) return loadedCount < effectiveTotalCount;

    return lastBatchCount >= _pageSize;
  }
}
