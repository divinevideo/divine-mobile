// ABOUTME: The own profile's My Lists tab: the create button and the
// ABOUTME: two-column gallery of the user's video and people lists.

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
        // Membership comes from the service, so a list created or deleted
        // just now is on screen immediately. The resolver only supplies
        // thumbnails, and it lags: riverpod carries the previous value
        // through a dependency-driven recompute, so a list the user just
        // made is missing from `hydrated` for as long as every other list
        // takes to resolve.
        final hydrated = ref.watch(myListsWithThumbnailsProvider).value;
        return _ProfileListsContent(
          videoLists: _withResolvedThumbnails(ownLists, hydrated),
          // Until the resolver's first pass lands, every fan slot a video
          // could fill shimmers rather than sitting flat.
          thumbnailsPending: hydrated == null,
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

/// [ownLists] with thumbnails filled in from [hydrated] where the resolver
/// has caught up.
///
/// Lists it has not reached yet keep their placeholder fan rather than
/// dropping out of the gallery.
List<CuratedList> _withResolvedThumbnails(
  List<CuratedList> ownLists,
  List<CuratedList>? hydrated,
) {
  if (hydrated == null) return ownLists;
  final thumbnailsById = <String, List<String>>{
    for (final list in hydrated)
      if (list.thumbnailUrls.isNotEmpty) list.id: list.thumbnailUrls,
  };
  if (thumbnailsById.isEmpty) return ownLists;
  return [
    for (final list in ownLists)
      if (thumbnailsById[list.id] case final urls?)
        list.copyWith(thumbnailUrls: urls)
      else
        list,
  ];
}

class _ProfileListsContent extends StatelessWidget {
  const _ProfileListsContent({
    required this.videoLists,
    required this.thumbnailsPending,
    required this.peopleEnabled,
  });

  final List<CuratedList> videoLists;
  final bool thumbnailsPending;
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
        if (peopleEnabled)
          _OwnListsGallery(
            videoLists: videoLists,
            thumbnailsPending: thumbnailsPending,
          )
        else if (videoLists.isEmpty)
          const _EmptyListsMessage()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VideoListsColumn(
              lists: videoLists,
              thumbnailsPending: thumbnailsPending,
            ),
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
  const _OwnListsGallery({
    required this.videoLists,
    required this.thumbnailsPending,
  });

  final List<CuratedList> videoLists;
  final bool thumbnailsPending;

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
              Expanded(
                child: _VideoListsColumn(
                  lists: videoLists,
                  thumbnailsPending: thumbnailsPending,
                ),
              ),
              Expanded(child: _PeopleListsColumn(lists: peopleLists)),
            ],
          ),
        );
      },
    );
  }
}

class _VideoListsColumn extends StatelessWidget {
  const _VideoListsColumn({
    required this.lists,
    required this.thumbnailsPending,
  });

  final List<CuratedList> lists;
  final bool thumbnailsPending;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: [
        for (final list in lists)
          DivineListThumbnail.videos(
            // Lists are created, deleted and re-hydrated in place, so cards
            // shift slots; the key keeps each card's image state with its list.
            key: ValueKey(list.authorScopedId),
            curatedList: list,
            thumbnailsPending: thumbnailsPending,
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
            key: ValueKey(list.id),
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
