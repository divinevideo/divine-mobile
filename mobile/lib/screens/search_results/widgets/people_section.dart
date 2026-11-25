import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/profile_routes.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Maximum number of user profiles shown in the People preview.
const _maxPeoplePreview = 3;

/// How long the skeleton and the loaded rows cross-fade.
const _skeletonSwitchDuration = Duration(milliseconds: 90);

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
    final rankingSignals = context.select(
      (UserSearchBloc bloc) => bloc.state.rankingSignals,
    );
    final query = context.select((UserSearchBloc bloc) => bloc.state.query);
    final isDegradedEmpty = context.select(
      (UserSearchBloc bloc) => bloc.state.isDegradedEmpty,
    );

    final isLoading =
        (status == .initial || status == .loading) && results.isEmpty;

    if (!isLoading) {
      // Degraded-empty: every source we consulted reported failure (or
      // outer-timeout promoted them all to failure) AND we have nothing
      // to show. Surface the retry affordance instead of a misleading
      // "No results found for X" — this is the #3791 fix.
      if (status == .failure || isDegradedEmpty) {
        return SearchSectionErrorState(
          onRetry: () => context.read<UserSearchBloc>().add(
            UserSearchQueryChanged(query),
          ),
        );
      }

      if (results.isEmpty) {
        if (showAll) return SearchSectionEmptyState(query: query);
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
    }

    final profiles = showAll
        ? results
        : results.take(_maxPeoplePreview).toList();

    // No outer horizontal padding — each [SearchUserTile] already
    // applies its own EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    // matching the Figma list-item spec (node 11177:208718). Wrapping
    // in another Padding here would double the side inset to 32 px.
    return SliverToBoxAdapter(
      child: _PeopleSkeletonizer(
        isLoading: isLoading,
        child: isLoading
            ? const _PeopleSkeletonRows()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The tile's own identifier is keyed by pubkey, which a UI
                  // test cannot know ahead of time; the ordinal wrapper gives
                  // flows a "tap the first result" handle without matching
                  // display names.
                  for (final (index, profile) in profiles.indexed)
                    Semantics(
                      identifier: SemanticIds.searchUserTileAt(index),
                      container: true,
                      child: SearchUserTile(
                        profile: profile,
                        videoCount: rankingSignals[profile.pubkey]?.videoCount,
                        lastPostedAt:
                            rankingSignals[profile.pubkey]?.lastPostedAt,
                        onTap: () => _navigateToProfile(context, profile),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, UserProfile profile) {
    final npub = normalizeToNpub(profile.pubkey);
    if (npub != null) {
      runDetached(
        OtherProfileRouteData(npub: npub).push<void>(context),
        'open profile search result',
        logName: 'PeopleSection',
        category: LogCategory.ui,
      );
    }
  }
}

/// Cross-fades between the skeleton and the loaded rows.
///
/// One [Skeletonizer] spans both states, because its switch animation runs
/// only when the same instance turns `enabled` on or off.
class _PeopleSkeletonizer extends StatelessWidget {
  const _PeopleSkeletonizer({required this.isLoading, required this.child});

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: isLoading,
      enableSwitchAnimation: true,
      switchAnimationConfig: SwitchAnimationConfig(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _skeletonSwitchDuration,
        layoutBuilder: _topAlignedSwitcherLayout,
      ),
      effect: vineSkeletonEffectOf(context),
      child: child,
    );
  }
}

/// Stacks the cross-fade from the top (a [Stack]'s default alignment).
/// `AnimatedSwitcher`'s own layout centres the shorter state inside the
/// taller one, so the rows would jump during the fade.
Widget _topAlignedSwitcherLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  return Stack(children: [...previousChildren, ?currentChild]);
}

class _PeopleSkeletonRows extends StatelessWidget {
  const _PeopleSkeletonRows();

  /// Fills the real [SearchUserTile] so the skeleton follows its layout.
  ///
  /// No NIP-05 claim, so the tile starts no verification lookup; a video
  /// count lets the info line show the handle. No bio: many accounts have
  /// none, so the skeleton shows the name and info lines only.
  static final _demoProfile = UserProfile(
    pubkey: '0' * 64,
    name: 'demo.name',
    displayName: 'Demo Display Name',
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'people-search-skeleton',
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'people_loading_indicator',
      label: context.l10n.searchPeopleLoadingLabel,
      // The demo rows are not results: screen readers hear only the
      // loading label. Skeletonizer blocks touch, not semantics.
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _maxPeoplePreview; i++)
              SearchUserTile(profile: _demoProfile, videoCount: 12),
          ],
        ),
      ),
    );
  }
}
