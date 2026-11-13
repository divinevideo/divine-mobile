import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/comments/comments_list/batched_subscription.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_helpers.dart';
import 'package:openvine/blocs/comments/comments_list/reportable_sites.dart';
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
/// Top sort needs vote counts from [CommentReactionsBloc]; see
/// [CommentsListState.displayCommentsWith].
///
/// With a [CommentModerationRepository] it also loads what the video owner
/// hid from the thread (#5044), and lets the owner hide and restore comments.
/// [viewerBlockedAuthors] are the accounts the viewer blocked; on the
/// viewer's own video their comments count as hidden by the owner.
class CommentsListBloc extends Bloc<CommentsListEvent, CommentsListState> {
  CommentsListBloc({
    required CommentsRepository commentsRepository,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
    String? rootAddressableId,
    int? initialTotalCount,
    bool includeVideoReplies = false,
    String? focusCommentId,
    CommentModerationRepository? commentModerationRepository,
    String? viewerPubkey,
    Set<String> viewerBlockedAuthors = const {},
    Stream<Set<String>>? viewerBlockedAuthorsChanges,
  }) : _commentsRepository = commentsRepository,
       _commentModerationRepository = commentModerationRepository,
       _initialTotalCount = initialTotalCount,
       _includeVideoReplies = includeVideoReplies,
       super(
         CommentsListState(
           rootEventId: rootEventId,
           rootEventKind: rootEventKind,
           rootAuthorPubkey: rootAuthorPubkey,
           rootAddressableId: rootAddressableId,
           pendingFocusCommentId: focusCommentId,
           viewerPubkey: viewerPubkey,
           viewerBlockedAuthors: viewerBlockedAuthors,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentsLoadMoreRequested>(_onLoadMoreRequested);
    on<CommentsSortModeChanged>(_onSortModeChanged);
    on<CommentsTopOrderFrozen>(_onTopOrderFrozen);
    on<NewCommentsBatchReceived>(_onNewCommentsBatchReceived);
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
    on<CommentDeletionReceived>(_onCommentDeletionReceived);
    on<HiddenCommentsVisibilityToggled>(_onHiddenCommentsVisibilityToggled);
    on<_ViewerBlockedAuthorsChanged>((event, emit) {
      if (!state.isViewerRootAuthor) return;
      final removed = state.viewerBlockedAuthors.difference(event.authors);
      final next = state.copyWith(
        viewerBlockedAuthors: event.authors,
        moderation: _withoutAutoHiddenAuthors(state.moderation, removed),
      );
      emit(
        next.hiddenCommentCount == 0
            ? next.copyWith(showHiddenComments: false)
            : next,
      );
    });
    on<CommentModerationRequested>(
      _onCommentModerationRequested,
      transformer: sequential(),
    );
    _viewerBlocksSubscription = viewerBlockedAuthorsChanges?.listen(
      (authors) => addIfOpen(_ViewerBlockedAuthorsChanged(Set.of(authors))),
    );
  }

  /// Page size for comment loading.
  static const _pageSize = 50;

  /// Below this many loaded comments, the search for the comment the list was
  /// opened on asks for another page; at or above it, the list is shown from
  /// the top without that comment.
  static const _maxCommentsLoadedForFocus = 500;

  /// How long real-time comments are gathered before they reach the state.
  /// A burst becomes one update, so the UI changes at most ten times a second
  /// on a viral video and no comment is dropped.
  static const _commentBatchWindow = Duration(milliseconds: 100);

  /// Optional initial total count from video metadata or interactions state.
  /// Used to accurately determine hasMoreContent instead of page size heuristic.
  final int? _initialTotalCount;

  final CommentsRepository _commentsRepository;
  final CommentModerationRepository? _commentModerationRepository;
  StreamSubscription<Set<String>>? _viewerBlocksSubscription;
  final bool _includeVideoReplies;
  BatchedSubscription<Comment>? _commentStreamSubscription;
  StreamSubscription<CommentDeletion>? _commentDeletionSubscription;

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
        newCommentIds: const {},
        isBackfillComplete: false,
      ),
    );

    // Read alongside the first page, so a hidden comment is never painted
    // before the owner's moderation arrives. Never throws.
    final moderation = _loadModeration();

    try {
      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        limit: _pageSize,
        includeVideoReplies: _includeVideoReplies,
      );
      final loadedModeration = await moderation;

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
          nextOffset: thread.nextOffset,
          moderation: loadedModeration,
        ),
      );
      _focusWhenLoaded(emit, pageAddedComments: thread.comments.isNotEmpty);
      await _startWatchingComments();
      await _removeAuthorDeletedComments(thread.comments, emit);
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

    // Cursor = min createdAt across non-placeholder comments, whatever the
    // sort mode, so Top's vote ranking never moves the paging cursor.
    // Returns early if every comment is an optimistic placeholder.
    final realCreatedAts = state.commentsById.values
        .where((c) => !c.id.startsWith(commentPlaceholderIdPrefix))
        .map((c) => c.createdAt);
    if (realCreatedAts.isEmpty) return;
    final cursor = realCreatedAts.reduce((a, b) => a.isBefore(b) ? a : b);

    emit(state.copyWith(isLoadingMore: true, loadMoreFailed: false));

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
        offset: state.nextOffset ?? 0,
        includeVideoReplies: _includeVideoReplies,
      );

      final loadedBefore = state.commentsById.length;
      final allCommentsById = {
        ...state.commentsById,
        for (final c in thread.comments) c.id: c,
      };
      // A page that adds nothing and moves no REST position would be asked
      // for again, unchanged, each time the viewer nears the end.
      final advanced =
          allCommentsById.length > loadedBefore ||
          (thread.nextOffset != null && thread.nextOffset != state.nextOffset);

      emit(
        state.copyWith(
          commentsById: allCommentsById,
          isLoadingMore: false,
          nextOffset: thread.nextOffset,
          hasMoreContent:
              advanced &&
              _hasMoreContent(
                loadedCount: allCommentsById.length,
                lastBatchCount: thread.comments.length,
                threadTotalCount: thread.totalCount,
                threadHasMore: thread.hasMore,
              ),
        ),
      );
      _focusWhenLoaded(
        emit,
        pageAddedComments: allCommentsById.length > loadedBefore,
      );
      await _removeAuthorDeletedComments(thread.comments, emit);
    } on CommentsRepositoryException catch (e, stackTrace) {
      _logRepoFailure(e, stackTrace, 'Error loading more comments');
      emit(
        state.copyWith(
          isLoadingMore: false,
          loadMoreFailed: true,
          error: CommentsListError.loadFailed,
          clearPendingFocus: true,
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
          loadMoreFailed: true,
          error: CommentsListError.loadFailed,
          clearPendingFocus: true,
        ),
      );
    }
  }

  /// Scrolls to the comment the list was opened on once it is loaded, and
  /// asks for another page of older comments while it is not and fewer than
  /// [_maxCommentsLoadedForFocus] are loaded, so the list can end a page past
  /// it. The search also ends on the last page and on a failed load. A comment
  /// it does not find, such as a deleted one, leaves the list where it starts.
  ///
  /// A page that added no comment ends the search, and the paging with it:
  /// the count `hasMoreContent` is measured against includes comments the
  /// list never gets.
  void _focusWhenLoaded(
    Emitter<CommentsListState> emit, {
    required bool pageAddedComments,
  }) {
    final focus = state.pendingFocusCommentId;
    if (focus == null) return;
    if (state.commentsById.containsKey(focus)) {
      emit(
        state.copyWith(scrollToCommentId: focus, clearPendingFocus: true),
      );
    } else if (pageAddedComments &&
        state.hasMoreContent &&
        state.commentsById.length < _maxCommentsLoadedForFocus) {
      // Reached after the page load awaited; the sheet may have closed.
      addIfOpen(const CommentsLoadMoreRequested());
    } else {
      emit(state.copyWith(clearPendingFocus: true));
    }
  }

  void _onSortModeChanged(
    CommentsSortModeChanged event,
    Emitter<CommentsListState> emit,
  ) {
    if (event.sortMode == state.sortMode) return;
    // Top ranks again by the current votes until the next freeze.
    emit(state.copyWith(sortMode: event.sortMode, clearTopOrder: true));
  }

  /// Appends the comments Top has not placed yet to the Top order, ranked by
  /// the event's votes. The first freeze places every comment.
  void _onTopOrderFrozen(
    CommentsTopOrderFrozen event,
    Emitter<CommentsListState> emit,
  ) {
    if (state.sortMode != CommentsSortMode.topEngagement) return;
    final placed = state.topOrder ?? const <String>[];
    final placedIds = placed.toSet();
    final unplaced = [
      for (final comment in state.commentsById.values)
        if (!placedIds.contains(comment.id)) comment,
    ];
    if (state.topOrder != null && unplaced.isEmpty) return;
    unplaced.sort(
      commentVoteComparator(
        upvoteCounts: event.upvoteCounts,
        downvoteCounts: event.downvoteCounts,
      ),
    );
    emit(
      state.copyWith(
        topOrder: [...placed, for (final comment in unplaced) comment.id],
      ),
    );
  }

  /// [CommentsListState.topOrder] kept to the comments in [store], with
  /// [prepended] on top and each id in [renamed] taking the place of the
  /// comment it replaces; `null` while Top is not frozen.
  List<String>? _topOrderFor(
    Map<String, Comment> store, {
    Iterable<String> prepended = const [],
    Map<String, String> renamed = const {},
  }) {
    final order = state.topOrder;
    if (order == null) return null;
    final seen = <String>{};
    return [
      for (final id in [
        ...prepended,
        for (final id in order) renamed[id] ?? id,
      ])
        if (store.containsKey(id) && seen.add(id)) id,
    ];
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
    if (state.scrollToCommentId != event.commentId) return;
    emit(state.copyWith(clearScrollTo: true));
  }

  void _onNewCommentsBatchReceived(
    NewCommentsBatchReceived event,
    Emitter<CommentsListState> emit,
  ) => _takeInComments(event.comments, emit);

  /// Takes real-time [incoming] comments into the store with one state update.
  void _takeInComments(
    List<Comment> incoming,
    Emitter<CommentsListState> emit,
  ) {
    final store = Map<String, Comment>.from(state.commentsById);
    // Pending placeholders are few; a batch looks through them, not the store.
    final placeholders = [
      for (final entry in store.entries)
        if (entry.key.startsWith(commentPlaceholderIdPrefix)) entry.value,
    ];
    final newIds = <String>{};
    final live = <Comment>[];
    final renamed = <String, String>{};
    var scrollToCommentId = state.scrollToCommentId;
    var changed = false;
    var added = false;

    for (final comment in incoming) {
      // Skip if already in the map by id (relay echo of a confirmed comment),
      // unless the echo carries video metadata missing from the REST bootstrap
      // copy. In that case, upgrade in place so a REST-loaded video reply can
      // render as soon as the relay echo arrives.
      // The repository's watchComments stream already drops blocked and
      // muted authors, except the owner's own blocks on their video, which
      // stay as comments the owner hid.
      final existingComment = store[comment.id];
      if (existingComment != null) {
        if (!existingComment.hasVideo && comment.hasVideo) {
          store[comment.id] = existingComment.copyWith(
            videoUrl: comment.videoUrl,
            thumbnailUrl: comment.thumbnailUrl,
            videoDimensions: comment.videoDimensions,
            videoDuration: comment.videoDuration,
            videoBlurhash: comment.videoBlurhash,
            stickerTags: comment.stickerTags,
          );
          changed = true;
        }
        continue;
      }

      // Optimistic-post reconciliation: if a pending placeholder matches this
      // relay echo by author + content, swap it for the canonical comment so
      // the user sees their own post settle into its real id without a
      // duplicate row. Counter does not bump because the placeholder was
      // already on screen.
      final placeholder = placeholders
          .where(
            (existing) =>
                existing.authorPubkey == comment.authorPubkey &&
                existing.content == comment.content,
          )
          .firstOrNull;

      if (placeholder != null) {
        store.remove(placeholder.id);
        placeholders.remove(placeholder);
        renamed[placeholder.id] = comment.id;
        if (scrollToCommentId == placeholder.id) scrollToCommentId = comment.id;
      } else if (state.isBackfillComplete) {
        live.add(comment);
      }
      store[comment.id] = comment;
      // A comment the owner hid does not announce itself in the pill.
      if (state.isBackfillComplete &&
          placeholder == null &&
          (state.showHiddenComments || !state.isHiddenByOwner(comment))) {
        newIds.add(comment.id);
      }
      changed = true;
      added = true;
    }

    if (!changed) return;
    // Live comments go on top, newest first. Comments from the backfill wait
    // below the placed rows until the next freeze.
    live.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(
      state.copyWith(
        status: added ? CommentsStatus.success : state.status,
        commentsById: store,
        topOrder: _topOrderFor(
          store,
          prepended: [for (final comment in live) comment.id],
          renamed: renamed,
        ),
        scrollToCommentId: scrollToCommentId,
        // The pill counts only new comments that are still listed.
        newCommentIds: {
          ...state.newCommentIds,
          ...newIds,
        }.where(store.containsKey).toSet(),
      ),
    );
  }

  /// Marks the backfill complete, then checks every listed comment for its
  /// author's deletion request.
  ///
  /// The backfill can bring comments the first page lacked, such as a race-lost
  /// deletion's comment a CDN-cached REST page has not caught up with (#7048).
  /// A replay after a reconnect completes the backfill again, which also
  /// catches a request the relay was slow to serve.
  Future<void> _onInitialBackfillCompleted(
    CommentsInitialBackfillCompleted event,
    Emitter<CommentsListState> emit,
  ) async {
    emit(state.copyWith(isBackfillComplete: true));
    await _removeAuthorDeletedComments([
      for (final comment in state.commentsById.values)
        if (!comment.id.startsWith(commentPlaceholderIdPrefix)) comment,
    ], emit);
  }

  void _onNewCommentsAcknowledged(
    NewCommentsAcknowledged event,
    Emitter<CommentsListState> emit,
  ) {
    emit(state.copyWith(newCommentIds: const {}));
  }

  void _emitStore(
    Emitter<CommentsListState> emit,
    Map<String, Comment> updated, {
    String? scrollToCommentId,
    Map<String, String> renamed = const {},
  }) {
    final next = state.copyWith(
      commentsById: updated,
      topOrder: _topOrderFor(updated, renamed: renamed),
      scrollToCommentId: scrollToCommentId,
      // The pill counts only new comments that are still listed.
      newCommentIds: state.newCommentIds.where(updated.containsKey).toSet(),
    );
    // The last hidden comment left the store, say its author was blocked or
    // deleted it: a later hidden one must not arrive already revealed.
    emit(
      next.showHiddenComments && next.hiddenCommentCount == 0
          ? next.copyWith(showHiddenComments: false)
          : next,
    );
  }

  void _onOptimisticCommentInserted(
    OptimisticCommentInserted event,
    Emitter<CommentsListState> emit,
  ) {
    // A post can rank below other comments in Top until the order is
    // frozen, and goes on top after. In Recent a new top-level post lands at
    // the top, while replies can nest off-screen under an older parent
    // (#5854).
    final updated = {
      ...state.commentsById,
      event.placeholder.id: event.placeholder,
    };
    final shouldReveal =
        event.placeholder.replyToEventId != null ||
        state.sortMode != CommentsSortMode.newest;
    emit(
      state.copyWith(
        commentsById: updated,
        topOrder: _topOrderFor(updated, prepended: [event.placeholder.id]),
        scrollToCommentId: shouldReveal ? event.placeholder.id : null,
      ),
    );
  }

  void _onOptimisticCommentConfirmed(
    OptimisticCommentConfirmed event,
    Emitter<CommentsListState> emit,
  ) {
    // A relay echo can arrive first. Keep its canonical comment, and transfer
    // any outstanding reveal request when replacing the placeholder.
    final updated = Map<String, Comment>.from(state.commentsById);
    final placeholder = updated.remove(event.placeholderId);
    if (placeholder == null && updated.containsKey(event.confirmed.id)) return;
    updated.putIfAbsent(event.confirmed.id, () => event.confirmed);
    _emitStore(
      emit,
      updated,
      scrollToCommentId: state.scrollToCommentId == event.placeholderId
          ? event.confirmed.id
          : null,
      renamed: {event.placeholderId: event.confirmed.id},
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
      renamed: {event.oldId: event.newComment.id},
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
    if (state.isViewerRootAuthor) {
      emit(
        state.copyWith(
          viewerBlockedAuthors: {
            ...state.viewerBlockedAuthors,
            event.authorPubkey,
          },
          showHiddenComments: false,
        ),
      );
      return;
    }
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)
        ..removeWhere((_, c) => c.authorPubkey == event.authorPubkey),
    );
  }

  void _onCommentDeletionReceived(
    CommentDeletionReceived event,
    Emitter<CommentsListState> emit,
  ) {
    final comment = state.commentsById[event.deletion.commentId];
    if (comment == null || !event.deletion.appliesTo(comment)) return;
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)..remove(comment.id),
    );
  }

  /// The video owner's published moderation. Local owner block snapshots
  /// remain separate so they cannot be lost behind this asynchronous read.
  Future<CommentModeration> _loadModeration() async {
    final repository = _commentModerationRepository;
    final coordinate = state.rootAddressableId;
    if (repository == null || coordinate == null || coordinate.isEmpty) {
      return CommentModeration.empty;
    }
    return repository.loadModeration(
      rootAddressableId: coordinate,
    );
  }

  /// [state] with [moderation] applied.
  ///
  /// [closeHidden] — the owner just hid something — puts the hidden comments
  /// away, so the thread is clean at once. With nothing hidden any more the
  /// toggle resets too, so a later hide does not show up already revealed.
  CommentsListState _withModeration(
    CommentModeration moderation, {
    bool closeHidden = false,
  }) {
    final next = state.copyWith(moderation: moderation);
    if (!next.showHiddenComments) return next;
    if (closeHidden || next.hiddenCommentCount == 0) {
      return next.copyWith(showHiddenComments: false);
    }
    return next;
  }

  void _onHiddenCommentsVisibilityToggled(
    HiddenCommentsVisibilityToggled event,
    Emitter<CommentsListState> emit,
  ) {
    emit(state.copyWith(showHiddenComments: !state.showHiddenComments));
  }

  /// Applies the owner's hide or restore at once and publishes it; a failed
  /// publish takes the change back and reports
  /// [CommentsListError.moderationFailed].
  Future<void> _onCommentModerationRequested(
    CommentModerationRequested event,
    Emitter<CommentsListState> emit,
  ) async {
    final repository = _commentModerationRepository;
    final coordinate = state.rootAddressableId;
    final comment = event.comment;
    if (repository == null ||
        coordinate == null ||
        coordinate.isEmpty ||
        !state.isViewerRootAuthor ||
        comment.authorPubkey == state.viewerPubkey) {
      return;
    }

    final previous = state.moderation;
    final ownBlocksBefore = state.viewerBlockedAuthors;
    final effectivePrevious = state.effectiveModeration;
    final edited = event.hide
        ? effectivePrevious.hide(comment)
        : effectivePrevious.restore(comment);
    emit(
      _withModeration(
        CommentModeration(
          hiddenCommentIds: edited.hiddenCommentIds,
          restoredCommentIds: edited.restoredCommentIds,
          autoHiddenAuthors: previous.autoHiddenAuthors,
        ),
        closeHidden: event.hide,
      ),
    );
    try {
      if (event.hide) {
        await repository.hideComment(
          rootAddressableId: coordinate,
          comment: comment,
        );
      } else {
        await repository.restoreComment(
          rootAddressableId: coordinate,
          comment: comment,
          authorAutoHidden: effectivePrevious.autoHiddenAuthors.contains(
            comment.authorPubkey,
          ),
        );
      }
    } on CommentsRepositoryException catch (e, stackTrace) {
      _logRepoFailure(e, stackTrace, 'Error saving comment moderation');
      emit(_moderationReverted(previous, ownBlocksBefore));
    } catch (e, stackTrace) {
      // A defect, such as a signer error the repository does not wrap; the
      // unsaved change still has to go back.
      _logUnexpectedFailure(
        e,
        stackTrace,
        CommentsListBlocReportableSites.onCommentModerationRequested,
        'Error saving comment moderation',
      );
      emit(_moderationReverted(previous, ownBlocksBefore));
    }
  }

  /// [state] with the moderation back at [previous] and the failure
  /// reported.
  CommentsListState _moderationReverted(
    CommentModeration previous,
    Set<String> ownBlocksBefore,
  ) => _withModeration(
    _withoutAutoHiddenAuthors(
      previous.withAutoHiddenAuthors(state.moderation.autoHiddenAuthors),
      ownBlocksBefore.difference(state.viewerBlockedAuthors),
    ),
  ).copyWith(error: CommentsListError.moderationFailed);

  static CommentModeration _withoutAutoHiddenAuthors(
    CommentModeration moderation,
    Set<String> removed,
  ) => CommentModeration(
    hiddenCommentIds: moderation.hiddenCommentIds,
    restoredCommentIds: moderation.restoredCommentIds,
    autoHiddenAuthors: moderation.autoHiddenAuthors.difference(removed),
  );

  /// Removes the [comments] whose author asked for their deletion.
  ///
  /// Runs after the page is on screen: a relay can still serve a comment its
  /// author deleted (#7048), and the lookup that finds it waits on a relay.
  Future<void> _removeAuthorDeletedComments(
    List<Comment> comments,
    Emitter<CommentsListState> emit,
  ) async {
    if (comments.isEmpty) return;
    final Set<String> deleted;
    try {
      deleted = await _commentsRepository.findAuthorDeletedComments(comments);
    } catch (e, stackTrace) {
      // The repository already absorbs lookup failures, so this is a defect;
      // report it without changing what the load itself reported.
      _logUnexpectedFailure(
        e,
        stackTrace,
        CommentsListBlocReportableSites.removeAuthorDeletedComments,
        'Comment deletion check failed',
      );
      return;
    }
    if (deleted.isEmpty) return;
    _emitStore(
      emit,
      Map<String, Comment>.from(state.commentsById)
        ..removeWhere((id, _) => deleted.contains(id)),
    );
  }

  /// Starts the real-time comment subscription.
  ///
  /// Called from [_onLoadRequested] after the initial load so the REST-backed
  /// first paint is not blocked by relay backfill. Routes incoming comments
  /// through [NewCommentsBatchReceived].
  Future<void> _startWatchingComments() async {
    // Detached on purpose: the replacement subscription does not depend on the
    // old one finishing teardown, and awaiting here suspends between reading
    // _commentStreamSubscription and assigning it. _onLoadRequested emits
    // success before calling this, so its `status == loading` guard is open
    // during that window and a second load can enter, leaving the first
    // subscription assigned over and never cancelled. Pinned by
    // comments_list_reload_race_test.dart.
    unawaited(_commentStreamSubscription?.cancel());
    unawaited(_commentDeletionSubscription?.cancel());

    try {
      final stream = _commentsRepository.watchComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        includeVideoReplies: _includeVideoReplies,
        onEose: () {
          // The stored comments are still in the open window; take them in
          // first, or the backfill would be called complete before they
          // arrive and they would read as new.
          _commentStreamSubscription?.flush();
          addIfOpen(const CommentsInitialBackfillCompleted());
        },
      );

      _commentStreamSubscription = batchedListen(
        stream,
        window: _commentBatchWindow,
        onBatch: (comments) => addIfOpen(NewCommentsBatchReceived(comments)),
        onError: (Object e) {
          Log.warning(
            'Comment watch stream error: $e',
            name: 'CommentsListBloc',
            category: LogCategory.ui,
          );
        },
      );

      _commentDeletionSubscription = _commentsRepository
          .watchCommentDeletions(
            rootEventId: state.rootEventId,
            includeVideoReplies: _includeVideoReplies,
          )
          .listen(
            (deletion) {
              // Preserve arrival order across the batched comment stream and
              // the unbatched deletion stream. Otherwise a held comment can
              // arrive after its deletion was ignored for not being listed.
              _commentStreamSubscription?.flush();
              addIfOpen(CommentDeletionReceived(deletion));
            },
            onError: (Object e) {
              Log.warning(
                'Comment deletion watch error: $e',
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
    await _commentDeletionSubscription?.cancel();
    await _viewerBlocksSubscription?.cancel();
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
