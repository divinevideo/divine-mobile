// ABOUTME: Feed empty-state widgets — mode-aware empty messaging for the home
// ABOUTME: video feed, including the Following test-pattern empty state.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/explore_screen.dart';

/// Empty state for the home video feed.
///
/// Picks copy based on the current [VideoFeedBlocState.mode] and surfaces an
/// "explore videos" call to action when the For You feed is empty because the
/// viewer follows no one.
class FeedEmptyWidget extends StatelessWidget {
  const FeedEmptyWidget({required this.state, super.key});

  final VideoFeedBlocState state;

  @override
  Widget build(BuildContext context) {
    final isNoFollowedUsers =
        state.mode == FeedMode.forYou &&
        state.error == VideoFeedError.noFollowedUsers;

    if (state.mode == FeedMode.following) {
      return const _FollowingFeedEmptyState();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.filmSlate,
            color: context.vineColors.mutedText,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(context, state),
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          if (isNoFollowedUsers) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(ExploreScreen.path),
              icon: DivineIcon(
                icon: DivineIconName.compass,
                color: context.vineColors.background,
              ),
              label: Text(context.l10n.feedExploreVideos),
              style: FilledButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: context.vineColors.background,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmptyMessage(BuildContext context, VideoFeedBlocState state) {
    if ((state.mode == FeedMode.following || state.mode == FeedMode.forYou) &&
        state.error == VideoFeedError.noFollowedUsers) {
      return context.l10n.feedNoFollowedUsers;
    }

    return switch (state.mode) {
      FeedMode.forYou => context.l10n.feedForYouEmpty,
      FeedMode.following => context.l10n.feedFollowingEmpty,
      FeedMode.latest => context.l10n.feedLatestEmpty,
      FeedMode.classic => context.l10n.feedClassicEmpty,
    };
  }
}

class _FollowingFeedEmptyState extends StatelessWidget {
  const _FollowingFeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FeedEmptyTestPatternMark(),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                context.l10n.feedFollowingEmpty,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            DivineButton(
              label: context.l10n.feedExploreVideos,
              trailingIcon: DivineIconName.arrowRight,
              onPressed: () => context.go(ExploreScreen.pathForTab('popular')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedEmptyTestPatternMark extends StatelessWidget {
  const _FeedEmptyTestPatternMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 88,
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ColoredBox(color: VineTheme.primary)),
                Expanded(child: ColoredBox(color: VineTheme.warning)),
                Expanded(child: ColoredBox(color: VineTheme.error)),
                // Fourth bar of a fixed test-pattern illustration; the other
                // three are brand constants, so this one stays white too.
                Expanded(child: ColoredBox(color: VineTheme.whiteText)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: ColoredBox(color: context.vineColors.onSurface),
                ),
                Expanded(
                  child: ColoredBox(color: context.vineColors.outlineMuted),
                ),
                const Expanded(
                  flex: 2,
                  child: ColoredBox(color: VineTheme.scrim65),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
