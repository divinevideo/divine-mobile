part of 'comments_list_bloc.dart';

/// A node in the comment tree, used for threaded display.
///
/// Not part of bloc state — produced by
/// [CommentsListState.threadedCommentsWith] on demand.
@immutable
final class CommentNode {
  const CommentNode({
    required this.comment,
    this.replies = const [],
    this.depth = 0,
  });

  /// The comment this node represents.
  final Comment comment;

  /// Child replies to this comment.
  final List<CommentNode> replies;

  /// Nesting depth (0 = root, 1 = reply, etc.).
  final int depth;
}

/// Status of the list-loading lifecycle.
enum CommentsStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Currently loading comments.
  loading,

  /// Comments loaded successfully.
  success,

  /// An error occurred while loading comments.
  failure,
}

/// l10n-friendly list-side errors.
///
/// The UI layer maps these to localized strings via [BlocListener].
enum CommentsListError {
  /// Failed to load comments from relays.
  loadFailed,

  /// The video owner's hide or restore of a comment could not be saved.
  moderationFailed,
}

/// Sort mode for the comments list.
enum CommentsSortMode {
  /// Newest comments first (default).
  newest,

  /// Oldest comments first.
  oldest,

  /// Top engagement: scored by likes + replies with time decay.
  topEngagement,
}

/// State for the [CommentsListBloc].
///
/// Holds the canonical [commentsById] store including any optimistic
/// placeholders inserted by [CommentComposerBloc] via the outbox bridge.
final class CommentsListState extends Equatable {
  const CommentsListState({
    this.status = CommentsStatus.initial,
    this.rootEventId = '',
    this.rootEventKind = 0,
    this.rootAuthorPubkey = '',
    this.rootAddressableId,
    this.commentsById = const {},
    this.error,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.nextOffset,
    this.sortMode = CommentsSortMode.newest,
    this.replyCountsByCommentId = const {},
    this.newCommentIds = const {},
    this.isBackfillComplete = false,
    this.scrollToCommentId,
    this.pendingFocusCommentId,
    this.viewerPubkey,
    this.viewerBlockedAuthors = const {},
    this.moderation = CommentModeration.empty,
    this.showHiddenComments = false,
  });

  /// The current status of the list.
  final CommentsStatus status;

  /// The root event ID (video) for these comments.
  final String rootEventId;

  /// The kind of the root event (e.g., 34236 for videos).
  final int rootEventKind;

  /// The author pubkey of the root event (video).
  final String rootAuthorPubkey;

  /// Optional addressable identifier for the root event (`kind:pubkey:d-tag`).
  ///
  /// Used for Kind 34236 addressable events so comments can be found/created
  /// using both `E` and `A` tags — see #4478 for the cache-key fix this
  /// preserves.
  final String? rootAddressableId;

  /// Comments indexed by ID for O(1) deduplication.
  /// Uses [Comment] from the repository layer.
  final Map<String, Comment> commentsById;

  /// Pre-computed reply counts per comment ID.
  /// Updated whenever [commentsById] changes to avoid O(n^2) in getters.
  final Map<String, int> replyCountsByCommentId;

  /// Current sort mode for the comments list.
  final CommentsSortMode sortMode;

  /// Comments received from the real-time subscription that the user has not
  /// yet acknowledged (scrolled to top / tapped the pill).
  final Set<String> newCommentIds;

  /// How many new comments the pill shows; see [newCommentIds].
  int get newCommentCount => newCommentIds.length;

  /// `true` once the initial relay backfill has reached EOSE; subsequent
  /// stream events represent live (post-backfill) comments and bump the
  /// [newCommentCount] pill. Lifted into state (instead of a mutable bloc
  /// instance field) per rules/state_management.md so it is observable in
  /// `blocTest` and survives state restoration. Default `false` to prevent
  /// pre-load `NewCommentsBatchReceived` events from being mis-classified as live.
  final bool isBackfillComplete;

  /// l10n-friendly error code; null when no error is pending.
  final CommentsListError? error;

  /// Whether more comments are being loaded (pagination).
  final bool isLoadingMore;

  /// Where the next REST page of comments starts, or `null` until REST has
  /// served a page.
  ///
  /// Paging by this position, rather than by the oldest loaded comment,
  /// keeps later pages on REST, which also lists comments scoped to an
  /// earlier revision of an edited video.
  final int? nextOffset;

  /// Whether there are more comments to load.
  final bool hasMoreContent;

  /// Transient one-shot signal: the id of a comment the UI should scroll into
  /// view (e.g. the local user's just-inserted reply, which nests under an
  /// older parent and would otherwise render off-screen — #5854). Set by the
  /// optimistic-insert handler, and by the load once [pendingFocusCommentId]
  /// is in the list; cleared by [CommentsScrollHandled] after the UI performs
  /// the scroll.
  final String? scrollToCommentId;

  /// The comment the list was opened on, such as the one a tapped reply
  /// sticker replies to, until it is loaded and handed to
  /// [scrollToCommentId].
  ///
  /// The search for it ends when it is found or gives up: no more pages, the
  /// comment cap, a page that adds nothing, or a failed load.
  final String? pendingFocusCommentId;

  /// The signed-in viewer, or `null` while signed out.
  final String? viewerPubkey;

  /// The viewer's current account-scoped blocks, including late hydration.
  final Set<String> viewerBlockedAuthors;

  /// The creator's decisions plus the owner's local blocks while syncing.
  CommentModeration get effectiveModeration => isViewerRootAuthor
      ? moderation.withAutoHiddenAuthors(viewerBlockedAuthors)
      : moderation;

  /// What the video owner hid from the thread's default view (#5044).
  ///
  /// For the owner it also covers everyone they blocked, so their comments
  /// stay reviewable here instead of being dropped.
  final CommentModeration moderation;

  /// Whether the viewer chose to see the comments the owner hid.
  final bool showHiddenComments;

  /// Whether this root has the coordinate required to persist moderation.
  bool get supportsModeration => rootAddressableId?.isNotEmpty ?? false;

  /// Whether the viewer owns the video, and so moderates its comments.
  bool get isViewerRootAuthor {
    final viewer = viewerPubkey;
    return viewer != null && viewer.isNotEmpty && viewer == rootAuthorPubkey;
  }

  /// Whether the video owner hid [comment] from the default view.
  ///
  /// Never true for the viewer's own comments: their authors keep seeing
  /// them as they posted them.
  bool isHiddenByOwner(Comment comment) =>
      comment.authorPubkey != viewerPubkey &&
      effectiveModeration.hides(comment);

  /// Whether [comment] answers a comment the list leaves out because the
  /// video owner hid it, so its reply line must not name that comment's
  /// author.
  bool repliesToHiddenComment(Comment comment) {
    if (showHiddenComments) return false;
    final parentId = comment.replyToEventId;
    final parent = parentId == null ? null : commentsById[parentId];
    if (parent != null) return isHiddenByOwner(parent);
    // Not loaded: its author tells whether the owner hides it.
    final author = comment.replyToAuthorPubkey;
    return author != null &&
        author != viewerPubkey &&
        effectiveModeration.autoHiddenAuthors.contains(author);
  }

  /// The authors of the comments the list shows, for mention suggestions:
  /// the authors of comments the owner hid stay out.
  Iterable<String> get shownAuthorPubkeys =>
      shownCommentsById.values.map((comment) => comment.authorPubkey);

  /// How many loaded comments the video owner hid.
  int get hiddenCommentCount =>
      commentsById.values.where(isHiddenByOwner).length;

  /// The comments the list shows: all of them while [showHiddenComments],
  /// otherwise those the video owner did not hide.
  Map<String, Comment> get shownCommentsById {
    if (showHiddenComments || hiddenCommentCount == 0) return commentsById;
    return {
      for (final entry in commentsById.entries)
        if (!isHiddenByOwner(entry.value)) entry.key: entry.value,
    };
  }

  /// Returns a comparator for sorting comments based on [sortMode].
  ///
  /// For [CommentsSortMode.topEngagement] the caller must provide
  /// [upvoteCounts] from [CommentReactionsBloc] — engagement sort spans two
  /// blocs and is reconciled in the UI builder rather than via cross-bloc
  /// dependency.
  Comparator<Comment> _commentComparator({
    Map<String, int> upvoteCounts = const {},
  }) {
    switch (sortMode) {
      case CommentsSortMode.newest:
        return (a, b) => b.createdAt.compareTo(a.createdAt);
      case CommentsSortMode.oldest:
        return (a, b) => a.createdAt.compareTo(b.createdAt);
      case CommentsSortMode.topEngagement:
        final now = DateTime.now();
        return (a, b) {
          final scoreA = commentEngagementScore(
            comment: a,
            now: now,
            likeCounts: upvoteCounts,
            replyCounts: replyCountsByCommentId,
          );
          final scoreB = commentEngagementScore(
            comment: b,
            now: now,
            likeCounts: upvoteCounts,
            replyCounts: replyCountsByCommentId,
          );
          return scoreB.compareTo(scoreA);
        };
    }
  }

  /// All comments sorted according to [sortMode].
  ///
  /// For [CommentsSortMode.topEngagement] pass [upvoteCounts] from
  /// [CommentReactionsBloc].
  List<Comment> commentsSortedWith({Map<String, int> upvoteCounts = const {}}) {
    return commentsById.values.toList()
      ..sort(_commentComparator(upvoteCounts: upvoteCounts));
  }

  /// The comments the list shows ([shownCommentsById]), threaded as a flat
  /// display list with depth info.
  ///
  /// Root comments and orphaned replies appear at depth 0; a reply to a
  /// comment the owner hid is such an orphan. For
  /// [CommentsSortMode.topEngagement] pass [upvoteCounts] from
  /// [CommentReactionsBloc] so the engagement scoring can complete.
  List<CommentNode> threadedCommentsWith({
    Map<String, int> upvoteCounts = const {},
  }) {
    // Build children map: parentId -> list of child comments.
    final childrenMap = <String, List<Comment>>{};
    final rootComments = <Comment>[];
    final shown = shownCommentsById;

    for (final comment in shown.values) {
      final parentId = comment.replyToEventId;
      if (parentId == null ||
          parentId.isEmpty ||
          !shown.containsKey(parentId)) {
        rootComments.add(comment);
      } else {
        childrenMap.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    final sorter = _commentComparator(upvoteCounts: upvoteCounts);

    // Build tree recursively.
    List<CommentNode> buildNodes(List<Comment> comments, int depth) {
      final sorted = List<Comment>.from(comments)..sort(sorter);
      return sorted.map((comment) {
        final children = childrenMap[comment.id] ?? [];
        return CommentNode(
          comment: comment,
          depth: depth,
          replies: buildNodes(children, depth + 1),
        );
      }).toList();
    }

    final roots = buildNodes(rootComments, 0);

    // Flatten tree using DFS.
    final result = <CommentNode>[];
    void flatten(List<CommentNode> nodes) {
      for (final node in nodes) {
        result.add(node);
        flatten(node.replies);
      }
    }

    flatten(roots);
    return result;
  }

  CommentsListState copyWith({
    CommentsStatus? status,
    String? rootEventId,
    int? rootEventKind,
    String? rootAuthorPubkey,
    String? rootAddressableId,
    Map<String, Comment>? commentsById,
    CommentsListError? error,
    bool? isLoadingMore,
    bool? hasMoreContent,
    int? nextOffset,
    CommentsSortMode? sortMode,
    Map<String, int>? replyCountsByCommentId,
    Set<String>? newCommentIds,
    bool? isBackfillComplete,
    String? scrollToCommentId,
    CommentModeration? moderation,
    Set<String>? viewerBlockedAuthors,
    bool? showHiddenComments,
    bool clearError = false,
    bool clearScrollTo = false,
    bool clearPendingFocus = false,
  }) {
    return CommentsListState(
      status: status ?? this.status,
      rootEventId: rootEventId ?? this.rootEventId,
      rootEventKind: rootEventKind ?? this.rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
      rootAddressableId: rootAddressableId ?? this.rootAddressableId,
      commentsById: commentsById ?? this.commentsById,
      // Aligns with CommentComposerState / CommentReactionsState: `error` is
      // sticky until either replaced or explicitly cleared, so unrelated
      // emits (sort change, store mutation, stream tick) don't silently null
      // a pending failure before the snackbar listener can read it.
      error: clearError ? null : (error ?? this.error),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      nextOffset: nextOffset ?? this.nextOffset,
      sortMode: sortMode ?? this.sortMode,
      replyCountsByCommentId:
          replyCountsByCommentId ?? this.replyCountsByCommentId,
      newCommentIds: newCommentIds ?? this.newCommentIds,
      isBackfillComplete: isBackfillComplete ?? this.isBackfillComplete,
      scrollToCommentId: clearScrollTo
          ? null
          : (scrollToCommentId ?? this.scrollToCommentId),
      // Only the constructor sets it; copyWith can only clear it.
      pendingFocusCommentId: clearPendingFocus ? null : pendingFocusCommentId,
      viewerPubkey: viewerPubkey,
      viewerBlockedAuthors: viewerBlockedAuthors ?? this.viewerBlockedAuthors,
      moderation: moderation ?? this.moderation,
      showHiddenComments: showHiddenComments ?? this.showHiddenComments,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rootEventId,
    rootEventKind,
    rootAuthorPubkey,
    rootAddressableId,
    commentsById,
    error,
    isLoadingMore,
    hasMoreContent,
    nextOffset,
    sortMode,
    replyCountsByCommentId,
    newCommentIds,
    isBackfillComplete,
    scrollToCommentId,
    pendingFocusCommentId,
    viewerPubkey,
    viewerBlockedAuthors,
    moderation,
    showHiddenComments,
  ];
}
