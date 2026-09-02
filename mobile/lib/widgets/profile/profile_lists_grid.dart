// ABOUTME: The own profile's My Lists tab: create button, bookmarks entry,
// ABOUTME: and the two-column gallery of the user's video and people lists.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';

/// My Lists surface for the current user's profile: the same two-column
/// card gallery as the Explore discovery tab, scoped to lists the viewer
/// owns, with the create entry point on top.
class ProfileListsGrid extends ConsumerWidget {
  const ProfileListsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(curatedListsStateProvider);
    // Reading the global PeopleListsBloc wakes it, so every entry point
    // checks the flag first (see curated_lists_gate.dart).
    final peopleEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );

    return listsAsync.when(
      data: (_) {
        final ownLists =
            ref.read(curatedListsStateProvider.notifier).service?.myLists ??
            const <CuratedList>[];
        // Instant render from the service's lists (placeholder fans); the
        // enriched copies swap in once the thumbnail resolver returns.
        final hydrated = ref.watch(myListsWithThumbnailsProvider).value;
        return _ProfileListsContent(
          videoLists: hydrated ?? ownLists,
          peopleEnabled: peopleEnabled,
        );
      },
      loading: () => const Center(child: BrandedLoadingIndicator(size: 60)),
      error: (_, _) => Center(
        child: Text(
          context.l10n.listErrorLoading,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ProfileListsContent extends StatelessWidget {
  const _ProfileListsContent({
    required this.videoLists,
    required this.peopleEnabled,
  });

  final List<CuratedList> videoLists;
  final bool peopleEnabled;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DivineButton(
            label: context.l10n.listCreateNewList,
            leadingIcon: DivineIconName.plus,
            // The design's outline look: surface container with a muted
            // border and primary ink.
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: () => context.showVideoPausingDialog<void>(
              builder: (_) => const CreateListDialog(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _BookmarksEntry(),
        const SizedBox(height: 8),
        if (peopleEnabled)
          _OwnListsGallery(videoLists: videoLists)
        else if (videoLists.isEmpty)
          const _EmptyListsMessage()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VideoListsColumn(lists: videoLists),
          ),
      ],
    );
  }
}

/// The two-column gallery: own video lists left, own people lists right.
///
/// Columns are independent, like the Explore discovery gallery: when one
/// kind runs out its side stays empty while the other keeps going.
class _OwnListsGallery extends StatelessWidget {
  const _OwnListsGallery({required this.videoLists});

  final List<CuratedList> videoLists;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PeopleListsBloc, PeopleListsState, List<UserList>>(
      selector: (state) => state.lists,
      builder: (context, peopleLists) {
        if (videoLists.isEmpty && peopleLists.isEmpty) {
          return const _EmptyListsMessage();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Expanded(child: _VideoListsColumn(lists: videoLists)),
              Expanded(child: _PeopleListsColumn(lists: peopleLists)),
            ],
          ),
        );
      },
    );
  }
}

class _VideoListsColumn extends StatelessWidget {
  const _VideoListsColumn({required this.lists});

  final List<CuratedList> lists;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: [
        for (final list in lists)
          DivineListThumbnail.videos(
            curatedList: list,
            onTap: () => context.push(
              CuratedListFeedScreen.pathForId(list.id),
              extra: CuratedListRouteExtra(listName: list.name),
            ),
          ),
      ],
    );
  }
}

class _PeopleListsColumn extends StatelessWidget {
  const _PeopleListsColumn({required this.lists});

  final List<UserList> lists;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: [
        for (final list in lists)
          DivineListThumbnail.people(
            userList: list,
            onTap: () => context.push(RoutePaths.peopleListForId(list.id)),
          ),
      ],
    );
  }
}

class _EmptyListsMessage extends StatelessWidget {
  const _EmptyListsMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        context.l10n.profileListsEmpty,
        textAlign: TextAlign.center,
        style: VineTheme.bodyLargeFont(color: context.vineColors.secondaryText),
      ),
    );
  }
}

/// Entry point to the viewer's bookmarks.
///
/// Bookmarks are a NIP-51 kind 10003 list rather than a kind 30005 one, so
/// they can't render as a gallery card — but they are still one of the
/// viewer's lists, which is why they sit here rather than in a tab of their
/// own. Without this the share sheet's Save action would be write-only.
class _BookmarksEntry extends StatelessWidget {
  const _BookmarksEntry();

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
      label: context.l10n.shareMenuBookmarks,
      child: InkWell(
        onTap: () => context.push(SavedVideosScreen.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            spacing: 12,
            children: [
              // Coloured for the same reason the label is: the asset is a
              // hardcoded white fill, and DivineIcon applies no filter when
              // color is null, so it disappears on the light palette.
              DivineIcon(icon: .bookmarkSimple, color: colors.primaryText),
              Expanded(
                child: Text(
                  context.l10n.shareMenuBookmarks,
                  style: VineTheme.titleSmallFont(color: colors.primaryText),
                ),
              ),
              DivineIcon(icon: .caretRight, color: colors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
