// ABOUTME: Comments list widget with loading, error, and empty states
// ABOUTME: Renders comments in a flat list using CommentItem widget

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/blocs/comments/comments_list/comments_list_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';

class CommentsList extends StatefulWidget {
  const CommentsList({
    required this.showClassicVineNotice,
    required this.scrollController,
    this.showVideoReplies = true,
    super.key,
  });

  final bool showClassicVineNotice;
  final ScrollController scrollController;
  final bool showVideoReplies;

  @override
  State<CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends State<CommentsList> {
  /// Attached to the single comment the list should scroll into view
  /// ([CommentsListState.scrollToCommentId]); lets us resolve its render
  /// object for `ensureVisible` even though the list is index-built (#5854).
  final GlobalKey _scrollTargetKey = GlobalKey();

  /// The ids of the comments the list shows, in order, as last built; the
  /// scroll target's place among them tells where to jump while it is not
  /// built yet.
  List<String> _shownIds = const [];

  /// How often the list jumps towards a scroll target it has not built yet.
  /// Each jump lays out more of the list, which sharpens the estimate of
  /// where the target lies.
  static const _maxJumpsTowardsTarget = 5;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Scrolling to the top of Recent reveals the latest comments.
    if (!widget.scrollController.hasClients) return;
    final bloc = context.read<CommentsListBloc>();
    if (widget.scrollController.offset <= 0 &&
        bloc.state.sortMode == CommentsSortMode.newest &&
        bloc.state.newCommentCount > 0) {
      bloc.add(const NewCommentsAcknowledged());
    }
  }

  /// Scrolls the flagged comment into view after the next frame (so the target
  /// item is laid out), then acks the one-shot signal. A target the list has
  /// not built yet, such as a comment far down that the list was opened on,
  /// is jumped towards first, [_maxJumpsTowardsTarget] times at most.
  void _scrollToTarget(String commentId, [int jumps = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<CommentsListBloc>();
      if (bloc.state.scrollToCommentId != commentId) return;
      final targetContext = _scrollTargetKey.currentContext;
      if (targetContext == null &&
          jumps < _maxJumpsTowardsTarget &&
          _jumpTowardsTarget(commentId)) {
        _scrollToTarget(commentId, jumps + 1);
        return;
      }
      if (targetContext != null) {
        final reduceMotion = MediaQuery.of(context).disableAnimations;
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.3,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      bloc.add(CommentsScrollHandled(commentId));
    });
  }

  /// Jumps to where the scroll target should lie, estimated from its place
  /// among [_shownIds]; `false` when the list does not show it.
  bool _jumpTowardsTarget(String commentId) {
    final index = _shownIds.indexOf(commentId);
    if (index < 0 || !widget.scrollController.hasClients) return false;
    final position = widget.scrollController.position;
    final share = _shownIds.length < 2 ? 0.0 : index / (_shownIds.length - 1);
    position.jumpTo(
      (position.maxScrollExtent * share).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Match TikTok / Instagram Reels: any interaction with the comments
    // area (tap on a comment, drag to scroll) dismisses the keyboard so
    // the user can read other comments unobstructed. Draft text in the
    // input is retained — re-tapping the input restores focus.
    //
    // The Listener catches taps anywhere in the list (including dead
    // space and on comment items themselves) without competing in the
    // gesture arena, so existing tap handlers (reply, vote, navigate to
    // profile) still run normally afterwards. The ListView's
    // [ScrollViewKeyboardDismissBehavior.onDrag] covers the scroll case
    // idiomatically.
    return BlocListener<CommentsListBloc, CommentsListState>(
      listenWhen: (prev, next) =>
          prev.scrollToCommentId != next.scrollToCommentId &&
          next.scrollToCommentId != null,
      listener: (_, state) => _scrollToTarget(state.scrollToCommentId!),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: BlocBuilder<CommentsListBloc, CommentsListState>(
          builder: (context, state) {
            if (state.status == CommentsStatus.loading) {
              return const _LoadingState();
            }

            if (state.status == CommentsStatus.failure) {
              return const _ErrorState();
            }

            return BlocSelector<
              CommentReactionsBloc,
              CommentReactionsState,
              ({Map<String, int> upvotes, Map<String, int> downvotes})
            >(
              selector: (s) => (
                upvotes: s.commentUpvoteCounts,
                downvotes: s.commentDownvoteCounts,
              ),
              builder: (context, votes) {
                final all = state.displayCommentsWith(
                  upvoteCounts: votes.upvotes,
                  downvoteCounts: votes.downvotes,
                );
                final displayed = widget.showVideoReplies
                    ? all
                    : all.where((node) => !node.comment.hasVideo).toList();

                _shownIds = [for (final node in displayed) node.comment.id];
                if (displayed.isEmpty) {
                  return CommentsEmptyState(
                    isClassicVine: widget.showClassicVineNotice,
                  );
                }

                // While the viewer chose to see what the owner hid, say so
                // once above the list.
                final showNotice =
                    state.showHiddenComments && state.hiddenCommentCount > 0;
                final offset = showNotice ? 1 : 0;
                return ListView.builder(
                  controller: widget.scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: displayed.length + offset,
                  itemBuilder: (context, index) {
                    if (index < offset) {
                      return HiddenCommentsNotice(
                        viewerOwnsVideo: state.isViewerRootAuthor,
                      );
                    }
                    final node = displayed[index - offset];
                    final isScrollTarget =
                        node.comment.id == state.scrollToCommentId;
                    return CommentItem(
                      key: isScrollTarget
                          ? _scrollTargetKey
                          : ValueKey('comment_${node.comment.id}'),
                      comment: node.comment,
                      depth: node.depth,
                      isHiddenByOwner: state.isHiddenByOwner(node.comment),
                      viewerOwnsVideo: state.isViewerRootAuthor,
                      supportsModeration: state.supportsModeration,
                      repliesToHiddenComment: state.repliesToHiddenComment(
                        node.comment,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Tells the viewer that the comments the owner hid are shown because they
/// chose to see them: "You hid these comments…" to the owner, "The creator
/// hid these comments on purpose." to everyone else.
@visibleForTesting
class HiddenCommentsNotice extends StatelessWidget {
  const HiddenCommentsNotice({required this.viewerOwnsVideo, super.key});

  final bool viewerOwnsVideo;

  @override
  Widget build(BuildContext context) {
    final color = context.vineColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        spacing: 8,
        children: [
          DivineIcon(icon: DivineIconName.info, size: 16, color: color),
          Expanded(
            child: Text(
              viewerOwnsVideo
                  ? context.l10n.commentsHiddenNoticeOwner
                  : context.l10n.commentsHiddenNotice,
              style: VineTheme.bodySmallFont(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const CommentsSkeletonLoader();
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      context.l10n.commentsErrorLoadFailed,
      style: VineTheme.bodyMediumFont(color: VineTheme.error),
    ),
  );
}
