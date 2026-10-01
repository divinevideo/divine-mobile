// ABOUTME: Own-profile list management with independent people and video sections.
// ABOUTME: Retains bookmarks and explicit creation choices during loading and failures.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/curated_list_initialization_failure.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';

/// Independently loaded people and video lists owned by the profile viewer.
class ProfileListsGrid extends ConsumerWidget {
  const ProfileListsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              const Expanded(child: _VideoListsSection()),
              if (peopleEnabled) const Expanded(child: _PeopleListsSection()),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeopleListsSection extends StatelessWidget {
  const _PeopleListsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PeopleListsBloc, PeopleListsState>(
      builder: (context, state) {
        if (!state.enabled || state.activeOwnerPubkey == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeading(title: context.l10n.explorePeopleLists),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DivineButton(
                label: context.l10n.listNewPeopleList,
                leadingIcon: DivineIconName.plus,
                expanded: true,
                onPressed: () => context.push(CreatePeopleListPage.path),
              ),
            ),
            for (final list in state.lists)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: DivineListThumbnail.people(
                  key: ValueKey(list.id),
                  userList: list,
                  onTap: () => runDetached(
                    context.push<void>(RoutePaths.peopleListForId(list.id)),
                    'open owned people list',
                    logName: 'ProfileListsGrid',
                    category: LogCategory.ui,
                  ),
                ),
              ),
            if (state.ownerReadStatus == PeopleListsOwnerReadStatus.failed)
              _ListReadFailure(
                onRetry: () => context.read<PeopleListsBloc>().add(
                  const PeopleListsOwnerSyncRequested(),
                ),
              )
            else if (!state.listsKnown)
              const _ListLoading()
            else if (state.lists.isEmpty)
              _ListMessage(text: context.l10n.peopleListsEmptySubtitle),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _VideoListsSection extends ConsumerWidget {
  const _VideoListsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(curatedListsStateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(title: context.l10n.exploreVideoLists),
        DivineButton(
          label: context.l10n.listNewVideoList,
          leadingIcon: DivineIconName.plus,
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: () => runDetached(
            showListInfoSheet(context),
            'open list creation sheet',
            logName: 'ProfileListsGrid',
            category: LogCategory.ui,
          ),
        ),
        const _BookmarksEntry(),
        listsAsync.when(
          data: (_) {
            final ownLists =
                ref.read(curatedListsStateProvider.notifier).service?.myLists ??
                const <CuratedList>[];
            if (ownLists.isEmpty) {
              return _ListMessage(text: context.l10n.profileListsEmpty);
            }
            // Retained previews belong to a prior account/policy until the
            // current hydration has completed successfully.
            final hydration = ref.watch(myListsWithThumbnailsProvider);
            final hydrated = switch (hydration) {
              AsyncData(isLoading: false, :final value) => value,
              _ => null,
            };
            return _VideoListsColumn(
              lists: _withResolvedThumbnails(ownLists, hydrated),
              thumbnailsPending: hydration.isLoading,
            );
          },
          loading: () => const _ListLoading(),
          error: (_, _) => CuratedListInitializationFailure(
            onRetry: () => ref.invalidate(curatedListsStateProvider),
          ),
        ),
      ],
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
  final thumbnailsById = <String, List<String>>{
    for (final list in hydrated ?? const <CuratedList>[])
      if (list.thumbnailUrls.isNotEmpty)
        list.authorScopedId: list.thumbnailUrls,
  };
  return [
    for (final list in ownLists)
      // Stored thumbnails have not passed the current policy/owner hydration.
      list.copyWith(
        thumbnailUrls: thumbnailsById[list.authorScopedId] ?? const [],
      ),
  ];
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
            onTap: () => runDetached(
              context.push<void>(
                CuratedListFeedScreen.pathForId(list.id),
                extra: CuratedListRouteExtra(listName: list.name),
              ),
              'open owned list',
              logName: 'ProfileListsGrid',
              category: LogCategory.ui,
            ),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Text(
      title,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
  );
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: BrandedLoadingIndicator(size: 40)),
  );
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: VineTheme.bodyMediumFont(color: context.vineColors.secondaryText),
    ),
  );
}

class _ListReadFailure extends StatelessWidget {
  const _ListReadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ListMessage(text: context.l10n.listErrorLoading),
      DivineButton(
        label: context.l10n.peopleListsAddPeopleRetry,
        onPressed: onRetry,
      ),
    ],
  );
}

/// Entry point to the viewer's bookmarks.
///
/// Bookmarks are a NIP-51 kind 10003 list rather than a kind 30005 one, so
/// they can't come through a curated-list thumbnail — but they are still one of the
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
