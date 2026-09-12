// ABOUTME: Comment action button for video feed overlay.
// ABOUTME: Displays comment icon with count, navigates to comments screen.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';
import 'package:unified_logger/unified_logger.dart';

/// Comment action button with count display for video overlay.
///
/// Shows a comment icon that navigates to the comments screen.
/// Uses [VideoInteractionsBloc] for live comment count.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class CommentActionButton extends StatelessWidget {
  const CommentActionButton({
    required this.video,
    this.isPreviewMode = false,
    this.onInteracted,
    super.key,
  });

  const CommentActionButton.preview({this.onInteracted, super.key})
    : video = null,
      isPreviewMode = true;

  final VideoEvent? video;
  final bool isPreviewMode;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    if (isPreviewMode) return const _ActionButton();
    final video = this.video;
    if (video == null) return const SizedBox.shrink();

    return BlocSelector<
      VideoInteractionsBloc,
      VideoInteractionsState,
      ({bool isInProgress, int count})
    >(
      selector: (state) => (
        isInProgress: state.isCommentsInProgress,
        count: state.commentCount ?? liveCommentCountSeed(video) ?? 0,
      ),
      builder: (context, data) {
        return _ActionButton(
          isCommentsInProgress: data.isInProgress,
          totalComments: data.count,
          onPressed: () {
            onInteracted?.call();
            Log.info(
              '💬 Comment button tapped for ${video.id}',
              name: 'VideoFeedItem',
              category: LogCategory.ui,
            );
            final interactionsBloc = context.read<VideoInteractionsBloc?>();
            CommentsScreen.show(
              context,
              video,
              initialCommentCount: data.count,
              onCommentCountChanged: interactionsBloc == null
                  ? null
                  : (count) {
                      if (!interactionsBloc.isClosed) {
                        interactionsBloc.add(
                          VideoInteractionsCommentCountUpdated(count),
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.onPressed,
    this.isCommentsInProgress = false,
    this.totalComments = 0,
  });

  final Function()? onPressed;
  final bool isCommentsInProgress;
  final int totalComments;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .chatDuo,
      semanticIdentifier: 'comments_button',
      semanticLabel: context.l10n.videoActionViewComments,
      isLoading: isCommentsInProgress,
      count: totalComments,
      labelWhenZero: context.l10n.videoActionReplyLabel,
      onPressed: onPressed,
    );
  }
}
