// ABOUTME: Repost action button for video feed overlay.
// ABOUTME: Displays repost icon with count. On other-people's videos tapping
// ABOUTME: toggles the repost; on the owner's own video it opens the list of
// ABOUTME: users who reposted the video instead.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Repost action button with count display for video overlay.
///
/// Shows a repost icon that toggles the repost state.
/// Uses [VideoInteractionsBloc] for state management.
///
/// On the current user's own video [isOwnVideo] is `true`, and tapping the
/// button navigates to the reposters list instead of toggling — you can't
/// repost your own video.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class RepostActionButton extends StatelessWidget {
  const RepostActionButton({
    required this.video,
    super.key,
    this.isPreviewMode = false,
    this.isOwnVideo = false,
    this.onInteracted,
  });

  const RepostActionButton.preview({super.key, this.onInteracted})
    : video = null,
      isPreviewMode = true,
      isOwnVideo = false;

  final VideoEvent? video;
  final bool isPreviewMode;
  final bool isOwnVideo;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    if (isPreviewMode) return const _ActionButton();
    final video = this.video;
    if (video == null) return const SizedBox.shrink();

    // Bloc state is seeded from the feed payload, preserving any archived
    // baseline and adding live Divine reposts when the server provides them.
    return BlocSelector<
      VideoInteractionsBloc,
      VideoInteractionsState,
      ({bool isReposted, int count})
    >(
      selector: (state) => (
        isReposted: state.isReposted,
        count: state.repostCount ?? liveRepostCountSeed(video) ?? 0,
      ),
      builder: (context, data) {
        return _ActionButton(
          isReposted: data.isReposted,
          totalReposts: data.count,
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
    this.isReposted = false,
    this.totalReposts = 0,
    this.isOwnVideo = false,
    this.video,
    this.onInteracted,
  });

  final bool isReposted;
  final int totalReposts;
  final bool isOwnVideo;
  final VideoEvent? video;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .repeatDuo,
      semanticIdentifier: 'repost_button',
      semanticLabel: isReposted
          ? context.l10n.videoActionRemoveRepost
          : context.l10n.videoActionRepost,
      iconColor: isReposted ? VineTheme.vineGreen : VineTheme.whiteText,
      count: totalReposts,
      labelWhenZero: context.l10n.videoActionRepostLabel,
      onPressed: () {
        onInteracted?.call();
        final video = this.video;
        if (isOwnVideo && video != null) {
          _openRepostersList(context, video);
          return;
        }
        if (video == null) return;
        context.read<VideoInteractionsBloc>().add(
          const VideoInteractionsRepostToggled(),
        );
      },
      onLongPress: video == null
          ? null
          : () {
              onInteracted?.call();
              _openRepostersList(context, video!);
            },
    );
  }

  static void _openRepostersList(BuildContext context, VideoEvent video) {
    final addressableId = video.addressableId;
    context.pushNamed(
      VideoEngagementListScreen.repostersRouteName,
      pathParameters: {'eventId': video.id},
      queryParameters: addressableId == null ? const {} : {'a': addressableId},
    );
  }
}
