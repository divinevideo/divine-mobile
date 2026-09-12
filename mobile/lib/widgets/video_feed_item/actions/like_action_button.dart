// ABOUTME: Like action button for video feed overlay.
// ABOUTME: Displays heart icon with like count. On other-people's videos
// ABOUTME: tapping toggles the like; on the owner's own video it opens the
// ABOUTME: list of users who liked the video instead.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Like action button with count display for video overlay.
///
/// Shows a heart icon that toggles between filled (liked) and outline (not
/// liked). Displays the like count from the [VideoInteractionsBloc] once
/// loaded.
///
/// On the current user's own video [isOwnVideo] is `true`, and tapping the
/// button navigates to the likers list instead of toggling — you can't like
/// your own video.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class LikeActionButton extends StatelessWidget {
  const LikeActionButton({
    required this.video,
    super.key,
    this.isPreviewMode = false,
    this.isOwnVideo = false,
    this.onInteracted,
  });

  const LikeActionButton.preview({
    super.key,
    this.onInteracted,
  }) : video = null,
       isPreviewMode = true,
       isOwnVideo = false;

  final VideoEvent? video;
  final bool isPreviewMode;
  final bool isOwnVideo;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    if (isPreviewMode) return const _ActionButton();

    return BlocSelector<
      VideoInteractionsBloc,
      VideoInteractionsState,
      ({bool isLiked, int count})
    >(
      selector: (state) => (
        isLiked: state.isLiked,
        count: state.likeCount ?? 0,
      ),
      builder: (context, data) {
        return _ActionButton(
          isLiked: data.isLiked,
          totalLikes: data.count,
          isOwnVideo: isOwnVideo,
          video: video,
          onInteracted: onInteracted,
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.isLiked = false,
    this.totalLikes = 0,
    this.isOwnVideo = false,
    this.video,
    this.onInteracted,
  });

  final bool isLiked;
  final int totalLikes;
  final bool isOwnVideo;
  final VideoEvent? video;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .heartDuo,
      semanticIdentifier: 'like_button',
      semanticLabel: isLiked
          ? context.l10n.videoActionUnlike
          : context.l10n.videoActionLike,
      iconColor: isLiked ? VineTheme.likeRed : VineTheme.whiteText,
      count: totalLikes,
      labelWhenZero: context.l10n.videoActionLikeLabel,
      onPressed: () {
        onInteracted?.call();
        final video = this.video;
        if (isOwnVideo && video != null) {
          _openLikersList(context, video);
          return;
        }
        if (video == null) return;
        context.read<VideoInteractionsBloc>().add(
          const VideoInteractionsLikeToggled(),
        );
      },
      onLongPress: video == null
          ? null
          : () {
              onInteracted?.call();
              _openLikersList(context, video!);
            },
    );
  }

  static void _openLikersList(BuildContext context, VideoEvent video) {
    final addressableId = video.addressableId;
    context.pushNamed(
      VideoEngagementListScreen.likersRouteName,
      pathParameters: {'eventId': video.id},
      queryParameters: addressableId == null ? const {} : {'a': addressableId},
    );
  }
}
