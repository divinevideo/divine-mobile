// ABOUTME: Lists section for search results, used in both "All" preview
// ABOUTME: and the dedicated "Lists" tab (showAll: true).
// ABOUTME: Shows curated video lists (kind 30005) and, when the
// ABOUTME: peopleListSearch feature flag is enabled (injected via BLoC),
// ABOUTME: people lists (kind 30000).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Always-visible Lists section with a "Lists" header.
///
/// When [showAll] is true, displays all results in a grid and hides the
/// section header — matching the pattern used by [VideosSection],
/// [PeopleSection], and [TagsSection].
class ListsSection extends StatelessWidget {
  const ListsSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results and hides the section header.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select((ListSearchBloc bloc) => bloc.state.status);
    final videoResults = context.select(
      (ListSearchBloc bloc) => bloc.state.videoResults,
    );
    final peopleResults = context.select(
      (ListSearchBloc bloc) => bloc.state.peopleResults,
    );

    final hasAnyResults = videoResults.isNotEmpty || peopleResults.isNotEmpty;

    // In the All tab, hide entire section when results are empty and loaded.
    if (!showAll && status == .success && !hasAnyResults) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(
              title: context.l10n.searchListsSectionHeader,
              onTap: onSeeAll,
              semanticIdentifier: SemanticIds.searchSectionHeader('lists'),
            ),
          ),
        _ListsContent(showAll: showAll),
      ],
    );
  }
}

class _ListsContent extends StatelessWidget {
  const _ListsContent({required this.showAll});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select((ListSearchBloc bloc) => bloc.state.status);
    final videoResults = context.select(
      (ListSearchBloc bloc) => bloc.state.videoResults,
    );
    final peopleResults = context.select(
      (ListSearchBloc bloc) => bloc.state.peopleResults,
    );
    final query = context.select((ListSearchBloc bloc) => bloc.state.query);

    if (status == .initial && showAll) {
      return const _InitialState();
    }

    if ((status == .initial || status == .loading) &&
        videoResults.isEmpty &&
        peopleResults.isEmpty) {
      return const _LoadingState();
    }

    if (status == .failure) {
      return SearchSectionErrorState(
        onRetry: () =>
            context.read<ListSearchBloc>().add(ListSearchQueryChanged(query)),
      );
    }

    final hasAnyResults = videoResults.isNotEmpty || peopleResults.isNotEmpty;

    if (!hasAnyResults) {
      if (showAll && status == .success) {
        return SearchSectionEmptyState(query: query);
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return _ResultsGrid(
      videoResults: videoResults,
      peopleResults: peopleResults,
      showAll: showAll,
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({
    required this.videoResults,
    required this.peopleResults,
    required this.showAll,
  });

  final List<CuratedList> videoResults;
  final List<PeopleListSearchResult> peopleResults;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    if (showAll) {
      // In the full grid, show all video results followed by all people results.
      final totalCount = videoResults.length + peopleResults.length;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index < videoResults.length) {
              final list = videoResults[index];
              return _ListCard(
                curatedList: list,
                onTap: () => _navigateToCuratedList(context, list),
              );
            }
            final peopleResult = peopleResults[index - videoResults.length];
            return _PeopleListCard(
              result: peopleResult,
              onTap: () => _navigateToPeopleList(context, peopleResult),
            );
          }, childCount: totalCount),
        ),
      );
    }
    // In the preview (All tab), show at most 1 video card + 1 people card.
    final previewVideo = videoResults.isNotEmpty ? videoResults.first : null;
    final previewPeople = peopleResults.isNotEmpty ? peopleResults.first : null;
    final previewCount =
        (previewVideo != null ? 1 : 0) + (previewPeople != null ? 1 : 0);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previewVideo != null)
              Expanded(
                child: _ListCard(
                  curatedList: previewVideo,
                  onTap: () => _navigateToCuratedList(context, previewVideo),
                ),
              ),
            if (previewPeople != null)
              Expanded(
                child: _PeopleListCard(
                  result: previewPeople,
                  onTap: () => _navigateToPeopleList(context, previewPeople),
                ),
              ),
            // If only one item, fill the second slot with empty space.
            if (previewCount == 1) const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

/// Card widget for a curated video list result.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.curatedList, required this.onTap});

  final CuratedList curatedList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DivineListThumbnail.videos(curatedList: curatedList, onTap: onTap);
  }
}

/// Card widget for a people list result.
class _PeopleListCard extends StatelessWidget {
  const _PeopleListCard({required this.result, required this.onTap});

  final PeopleListSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DivineListThumbnail.people(userList: result.list, onTap: onTap);
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DivineIcon(
              icon: DivineIconName.search,
              color: context.vineColors.secondaryText,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.searchForLists,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              context.l10n.searchFindCuratedVideoLists,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: _ListsSkeletonLoader());
  }
}

class _ListsSkeletonLoader extends StatelessWidget {
  const _ListsSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'lists_loading_indicator',
      label: context.l10n.searchListsLoadingLabel,
      child: Skeletonizer(
        effect: vineSkeletonEffectOf(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ListCardSkeletonItem()),
              Expanded(child: _ListCardSkeletonItem()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListCardSkeletonItem extends StatelessWidget {
  const _ListCardSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Skeleton.leaf(
          child: AspectRatio(
            aspectRatio: 0.85,
            child: Container(
              decoration: BoxDecoration(
                color: context.vineColors.skeleton,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Skeleton.leaf(
          child: Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: context.vineColors.skeleton,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Skeleton.leaf(
          child: Container(
            width: 140,
            height: 12,
            decoration: BoxDecoration(
              color: context.vineColors.skeleton,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

void _navigateToPeopleList(
  BuildContext context,
  PeopleListSearchResult result,
) {
  context.push(
    RoutePaths.peopleListForId(result.list.id, ownerPubkey: result.ownerPubkey),
  );
}

void _navigateToCuratedList(BuildContext context, CuratedList list) {
  context.push(
    CuratedListFeedScreen.pathForId(list.id),
    extra: CuratedListRouteExtra(
      listName: list.name,
      videoIds: list.videoEventIds,
      authorPubkey: list.pubkey,
    ),
  );
}
