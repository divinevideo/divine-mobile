// ABOUTME: Feed mode picker overlay widget for video feed
// ABOUTME: Shows current source (For You/Following/lists) with bottom sheet selection

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

/// Feed mode picker overlay that displays the current feed mode
/// and allows users to switch between modes via a bottom sheet.
///
/// This widget is designed to be used in a [Stack] as an overlay
/// on top of video content. It includes a gradient background
/// that fades from semi-transparent black to transparent.
class FeedModeSwitch extends StatelessWidget {
  const FeedModeSwitch({this.isPreviewMode = false, super.key});

  /// When true, displays a static "For You" label without requiring
  /// [VideoFeedBloc] or feature-flag providers in the widget tree.
  final bool isPreviewMode;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FeedImmersiveChrome(
        child: Container(
          decoration: isPreviewMode
              ? null
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VineTheme.innerShadowPressed,
                      VineTheme.transparent,
                    ],
                  ),
                ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              // Left padding (16) matches the video metadata container's
              // `start: 16` on the overlay below, so the feed-mode label
              // lines up with the avatar.
              // Right padding (12) gives the trailing More popover a hair
              // more breathing room from the screen edge — matches the
              // fullscreen app bar and the profile screen's nav-button row.
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 16),
              child: isPreviewMode
                  ? _FeedModeContent(
                      label: _labelForMode(FeedMode.forYou, context.l10n),
                    )
                  : BlocBuilder<VideoFeedBloc, VideoFeedBlocState>(
                      buildWhen: (prev, curr) =>
                          prev.source != curr.source ||
                          prev.subscribedLists != curr.subscribedLists ||
                          prev.followedPeopleLists !=
                              curr.followedPeopleLists ||
                          prev.currentIndex != curr.currentIndex ||
                          prev.videos != curr.videos,
                      builder: (context, state) {
                        final activeVideo =
                            state.currentIndex >= 0 &&
                                state.currentIndex < state.videos.length
                            ? state.videos[state.currentIndex]
                            : null;
                        return _FeedModeContent(
                          onTap: () => _showFeedModeBottomSheet(context, state),
                          label: _labelForSource(state, context.l10n),
                          trailing: FeedSettingsMenu(videoId: activeVideo?.id),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFeedModeBottomSheet(
    BuildContext context,
    VideoFeedBlocState state,
  ) async {
    final l10n = context.l10n;
    final selected = await context.showVideoPausingSelectionMenu(
      selectedValue: state.source.persistenceValue,
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeForYou,
          value: 'forYou',
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeFollowing,
          value: 'following',
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeNew,
          value: 'latest',
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeClassics,
          value: 'classic',
        ),
        ...state.subscribedLists.map(
          (list) => VineBottomSheetSelectionOptionData(
            label: list.name,
            value: 'list:${list.id}',
          ),
        ),
        ...state.followedPeopleLists.map(
          (followed) => VineBottomSheetSelectionOptionData(
            label: followed.list.name,
            value: _sourceForPeopleList(followed).persistenceValue,
          ),
        ),
      ],
    );

    if (selected != null && context.mounted) {
      context.read<VideoFeedBloc>().add(
        VideoFeedSourceChanged(_sourceForSelection(selected, state)),
      );
    }
  }
}

VideoFeedSource _sourceForSelection(String selected, VideoFeedBlocState state) {
  if (selected == 'forYou') {
    return const VideoFeedSource.forYou();
  }
  if (selected == 'following') {
    return const VideoFeedSource.following();
  }
  if (selected == 'latest') {
    return const VideoFeedSource.newVideos();
  }
  if (selected == 'classic') {
    return const VideoFeedSource.classic();
  }
  if (selected.startsWith('list:')) {
    final listId = selected.substring('list:'.length);
    final list = state.subscribedLists.firstWhere((list) => list.id == listId);
    return VideoFeedSource.subscribedList(listId: list.id, listName: list.name);
  }
  for (final followed in state.followedPeopleLists) {
    final source = _sourceForPeopleList(followed);
    if (source.persistenceValue == selected) return source;
  }

  return const VideoFeedSource.forYou();
}

VideoFeedSource _sourceForPeopleList(PeopleListSearchResult followed) =>
    VideoFeedSource.peopleList(
      listId: followed.list.id,
      listName: followed.list.name,
      listOwnerPubkey: followed.ownerPubkey,
    );

String _labelForSource(VideoFeedBlocState state, AppLocalizations l10n) {
  final source = state.source;
  return switch (source.type) {
    VideoFeedSourceType.forYou => l10n.feedModeForYou,
    VideoFeedSourceType.following => l10n.feedModeFollowing,
    VideoFeedSourceType.newVideos => l10n.feedModeNew,
    VideoFeedSourceType.classic => l10n.feedModeClassics,
    VideoFeedSourceType.subscribedList =>
      _listNameForSource(state) ?? source.listName ?? source.labelFallback,
    // The followed copy first: it follows a rename, the source does not.
    VideoFeedSourceType.peopleList =>
      state.selectedPeopleList?.list.name ?? source.labelFallback,
  };
}

String? _listNameForSource(VideoFeedBlocState state) {
  for (final list in state.subscribedLists) {
    if (list.id == state.source.listId) {
      return list.name;
    }
  }
  return null;
}

String _labelForMode(FeedMode mode, AppLocalizations l10n) => switch (mode) {
  FeedMode.forYou => l10n.feedModeForYou,
  FeedMode.latest => l10n.feedModeNew,
  FeedMode.following => l10n.feedModeFollowing,
  FeedMode.classic => l10n.feedModeClassics,
};

/// Shared row rendering — label + caret + optional trailing widget — used
/// for both the live [BlocBuilder]-driven label and the static preview-mode
/// label.
///
/// [trailing], when provided, is rendered as the right-aligned sibling of
/// the label, sharing the same vertical center via the parent [Row].
class _FeedModeContent extends StatelessWidget {
  const _FeedModeContent({required this.label, this.onTap, this.trailing});

  final VoidCallback? onTap;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              label: context.l10n.feedModeSemanticLabel(label),
              button: true,
              child: GestureDetector(
                behavior: .opaque,
                onTap: onTap,
                // Interactive instances need a 48dp target. Preview instances
                // have no onTap and retain their intrinsic height.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: onTap == null ? 0 : kMinInteractiveDimension,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VineTheme.headlineSmallFont(
                            color: VineTheme.whiteText,
                          ).copyWith(shadows: VineTheme.buttonShadows),
                        ),
                      ),
                      const _FeedModeCaret(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Caret icon with the same two drop shadows applied to the feed-mode label
/// text, so the icon matches the label's legibility over video content.
///
/// [ShadowedDivineIcon] bakes glyph and shadows into one bitmap; drawn as
/// live blur layers, the pair cost two gaussian passes on every video frame.
class _FeedModeCaret extends StatelessWidget {
  const _FeedModeCaret();

  @override
  Widget build(BuildContext context) {
    return const ShadowedDivineIcon(
      icon: DivineIconName.caretDown,
      color: VineTheme.whiteText,
    );
  }
}
