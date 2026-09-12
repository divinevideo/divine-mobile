import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Maximum number of user profiles shown in the People preview.
const _maxPeoplePreview = 3;

/// Always-visible People section with a "People" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class PeopleSection extends StatelessWidget {
  const PeopleSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results instead of a limited preview.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select((UserSearchBloc bloc) => bloc.state.status);
    final results = context.select((UserSearchBloc bloc) => bloc.state.results);
    final isDegradedEmpty = context.select(
      (UserSearchBloc bloc) => bloc.state.isDegradedEmpty,
    );

    // In the All tab, hide entire section when truly empty. A degraded
    // empty (some source failed) still shows so the user gets a retry
    // affordance instead of an invisible section that looks like the
    // friend they searched for "doesn't exist". See #3791.
    if (!showAll && status == .success && results.isEmpty && !isDegradedEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(
              title: context.l10n.searchPeopleSectionHeader,
              onTap: onSeeAll,
              semanticIdentifier: SemanticIds.searchSectionHeader('people'),
            ),
          ),
        _PeopleContent(showAll: showAll),
        if (showAll) const _PeoplePaginationTrigger(),
      ],
    );
  }
}

class _PeoplePaginationTrigger extends StatelessWidget {
  const _PeoplePaginationTrigger();

  @override
  Widget build(BuildContext context) {
    final hasMore = context.select((UserSearchBloc b) => b.state.hasMore);
    final isLoadingMore = context.select(
      (UserSearchBloc b) => b.state.isLoadingMore,
    );
    return SliverPaginationTrigger(
      onLoadMore: () =>
          context.read<UserSearchBloc>().add(const UserSearchLoadMore()),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }
}

class _PeopleContent extends StatelessWidget {
  const _PeopleContent({this.showAll = false});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select((UserSearchBloc bloc) => bloc.state.status);
    final results = context.select((UserSearchBloc bloc) => bloc.state.results);
    final query = context.select((UserSearchBloc bloc) => bloc.state.query);
    final isDegradedEmpty = context.select(
      (UserSearchBloc bloc) => bloc.state.isDegradedEmpty,
    );

    if ((status == .initial || status == .loading) && results.isEmpty) {
      return const _PeopleSkeletonLoader();
    }

    // Degraded-empty: every source we consulted reported failure (or
    // outer-timeout promoted them all to failure) AND we have nothing
    // to show. Surface the retry affordance instead of a misleading
    // "No results found for X" — this is the #3791 fix.
    if (status == .failure || isDegradedEmpty) {
      return SearchSectionErrorState(
        onRetry: () =>
            context.read<UserSearchBloc>().add(UserSearchQueryChanged(query)),
      );
    }

    if (results.isEmpty) {
      if (showAll) return SearchSectionEmptyState(query: query);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final profiles = showAll
        ? results
        : results.take(_maxPeoplePreview).toList();

    // No outer horizontal padding — each [SearchUserTile] already
    // applies its own EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    // matching the Figma list-item spec (node 11177:208718). Wrapping
    // in another Padding here would double the side inset to 32 px.
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The tile's own identifier is keyed by pubkey, which a UI test
          // cannot know ahead of time; the ordinal wrapper gives flows a
          // "tap the first result" handle without matching display names.
          for (final (index, profile) in profiles.indexed)
            Semantics(
              identifier: SemanticIds.searchUserTileAt(index),
              container: true,
              child: SearchUserTile(
                profile: profile,
                onTap: () => _navigateToProfile(context, profile),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context, UserProfile profile) {
    final npub = normalizeToNpub(profile.pubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}

class _PeopleSkeletonLoader extends StatelessWidget {
  const _PeopleSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    // No outer horizontal padding — each [_UserTileSkeletonItem]
    // applies its own 16 px inset to match the loaded-state tile
    // geometry. See `_PeopleContent.build` for the same rationale.
    return SliverToBoxAdapter(
      child: Semantics(
        identifier: 'people_loading_indicator',
        label: context.l10n.searchPeopleLoadingLabel,
        child: Skeletonizer(
          effect: vineSkeletonEffectOf(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              _maxPeoplePreview,
              (_) => const _UserTileSkeletonItem(),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTileSkeletonItem extends StatelessWidget {
  const _UserTileSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        spacing: 16,
        children: [
          Skeleton.leaf(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.vineColors.skeleton,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Skeleton.leaf(
                  child: Container(
                    width: 140,
                    height: 18,
                    decoration: BoxDecoration(
                      color: context.vineColors.skeleton,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Skeleton.leaf(
                  child: Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: context.vineColors.skeleton,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
