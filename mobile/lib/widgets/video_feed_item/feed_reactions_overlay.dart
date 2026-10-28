// ABOUTME: "Show reactions" overlay for the playing feed video: after its first
// ABOUTME: loop, dims the video and shows its top comment over it.

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:openvine/blocs/feed_top_comment/feed_top_comment_cubit.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/utils/detached_future.dart';

/// Reactions-mode layer of one feed item.
///
/// Mount it only for the video that is playing: it loads that video's top
/// comment as soon as it builds, and unmounting it — scrolling to another
/// video — drops the overlay with it.
class FeedReactionsLayer extends ConsumerWidget {
  const FeedReactionsLayer({
    required this.video,
    required this.loopCompletions,
    super.key,
  });

  final VideoEvent video;

  /// Fires each time [video] finishes a loop.
  final Stream<void> loopCompletions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    return BlocProvider<FeedTopCommentCubit>(
      key: ValueKey((video.id, commentsRepository, likesRepository)),
      create: (_) {
        final cubit = FeedTopCommentCubit(
          commentsRepository: commentsRepository,
          likesRepository: likesRepository,
          rootEventId: video.id,
          rootEventKind: NIP71VideoKinds.addressableShortVideo,
          rootAuthorPubkey: video.pubkey,
          rootAddressableId: video.addressableId,
          rootContent: _videoDescription(video),
          loopCompletions: loopCompletions,
        );
        runDetached(
          cubit.load(),
          'load feed top comment',
          logName: 'FeedReactionsLayer',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: FeedReactionsOverlay(video: video),
    );
  }

  static String _videoDescription(VideoEvent video) {
    final content = video.content.trim();
    if (content.isNotEmpty) return content;
    return video.title?.trim() ?? '';
  }
}

/// Dims the playing video and shows its top comment, once
/// [FeedTopCommentState.isOverlayVisible].
///
/// Tapping the dimmed area dismisses it; tapping the comment opens the
/// comments sheet at that comment.
class FeedReactionsOverlay extends StatelessWidget {
  const FeedReactionsOverlay({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final isVisible = context.select(
      (FeedTopCommentCubit cubit) => cubit.state.isOverlayVisible,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: reduceMotion
            ? Duration.zero
            : FeedReactionsOverlayLayout.fadeDuration,
        child: isVisible
            ? _ReactionContent(video: video)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ReactionContent extends StatelessWidget {
  const _ReactionContent({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final top =
        MediaQuery.viewPaddingOf(context).top +
        FeedReactionsOverlayLayout.topBarHeight +
        FeedReactionsOverlayLayout.gapBelowTopBar;
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: context.l10n.feedReactionDismiss,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.read<FeedTopCommentCubit>().dismiss(),
              child: ColoredBox(color: FeedReactionsOverlayLayout.dim),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: FeedReactionsOverlayLayout.sidePadding,
          right: FeedReactionsOverlayLayout.sidePadding,
          child: _TopCommentContent(video: video),
        ),
      ],
    );
  }
}

class _TopCommentContent extends StatelessWidget {
  const _TopCommentContent({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FeedTopCommentCubit>().state;
    final comment = state.topComment;
    if (comment == null) return const SizedBox.shrink();
    final repliedToPubkey = state.repliedToPubkey;
    final repliedToContent = state.repliedToContent?.trim() ?? '';

    return Semantics(
      button: true,
      hint: context.l10n.feedReactionOpenComment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openComment(context, comment),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (repliedToPubkey != null)
              CommentReplyIndicator(
                parentAuthorPubkey: repliedToPubkey,
                chipColor: VineTheme.containerLow,
              ),
            if (repliedToContent.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                repliedToContent,
                style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
                maxLines: FeedReactionsOverlayLayout.repliedToMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 18),
            const _TopCommentAuthorSlot(),
            Text(
              comment.content.trim(),
              style: VineTheme.headlineLargeFont(color: VineTheme.whiteText),
              maxLines: FeedReactionsOverlayLayout.commentMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openComment(BuildContext context, Comment comment) {
    context.read<FeedTopCommentCubit>().dismiss();
    final interactionsBloc = context.read<VideoInteractionsBloc?>();
    runDetached(
      CommentsScreen.show(
        context,
        video,
        initialCommentCount: interactionsBloc?.state.commentCount,
        focusCommentId: comment.id,
        onCommentCountChanged: interactionsBloc == null
            ? null
            : (count) {
                if (!interactionsBloc.isClosed) {
                  interactionsBloc.add(
                    VideoInteractionsCommentCountUpdated(count),
                  );
                }
              },
      ),
      'present comments screen from reaction',
      logName: 'FeedReactionsOverlay',
      category: LogCategory.ui,
    );
  }
}

/// Where the top comment's author (avatar and name) goes.
///
/// Intentionally empty: how the author is shown is still being designed.
class _TopCommentAuthorSlot extends StatelessWidget {
  const _TopCommentAuthorSlot();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Layout constants of [FeedReactionsOverlay], from the reactions design.
abstract final class FeedReactionsOverlayLayout {
  /// Height of the home feed's top bar below the status bar: its 48 px row
  /// plus 16 px padding above and below.
  static const double topBarHeight = 80;

  /// Space between the top bar and the "Re:" line.
  static const double gapBelowTopBar = 13;

  static const double sidePadding = 16;

  /// The video keeps playing underneath at 25% opacity.
  static final Color dim = VineTheme.backgroundColor.withValues(alpha: 0.75);

  static const fadeDuration = Duration(milliseconds: 250);

  static const repliedToMaxLines = 2;

  static const commentMaxLines = 6;
}
