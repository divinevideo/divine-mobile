import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';

class SearchResultsView extends StatelessWidget {
  /// Use [SearchResultsPage] to ensure BLoC providers are wired.
  const SearchResultsView({required this.controller, super.key});

  /// Shared search field controller, owned by the parent page so this view
  /// can read the same live text the user is typing into the app bar.
  ///
  /// Driving the idle-placeholder gate from the live controller value
  /// (rather than the route arg) is what lets the view return to the
  /// empty-query placeholder when the user clears or shortens a prefilled
  /// query after landing on /search-results/:query — without this, the
  /// BLoCs reset to `initial` but the immutable route arg leaves the gate
  /// stuck open, re-introducing the #3023 "infinite skeleton" symptom.
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.surface,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => _Body(text: value.text),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.text});

  /// Current text in the search field.
  final String text;

  @override
  Widget build(BuildContext context) {
    // All search BLoCs are driven from the same [SearchResultsAppBar] query
    // dispatcher, so any one of them reflects whether the user has entered a
    // searchable query yet. Reading [VideoSearchBloc] is enough to short
    // circuit every filter into the shared idle placeholder.
    final isInitialStatus = context.select(
      (VideoSearchBloc bloc) => bloc.state.status == VideoSearchStatus.initial,
    );

    // Mirror the BLoC handlers' own `length < minSearchQueryLength` guard:
    // queries that would never reach the network (empty, whitespace-only,
    // sub-min-length) render the idle placeholder; anything searchable
    // falls through to the section skeletons. The gate combines (a) the
    // BLoC being in `initial` — load-bearing for the #3023 / PR #3199 empty
    // mount — with (b) the live field text being below the searchable
    // threshold, so post-mount edits that drop the user back below the
    // threshold also return to the placeholder.
    final isIdle = isInitialStatus && text.trim().length < minSearchQueryLength;

    if (isIdle) {
      return CustomScrollView(
        slivers: [
          SearchSectionInitialState(
            title: context.l10n.searchEnterQuery,
            subtitle: context.l10n.searchDiscoverSomethingInteresting,
          ),
          const SliverBottomSafeArea(),
        ],
      );
    }

    final filter = context.select(
      (SearchResultsFilterCubit cubit) => cubit.state,
    );

    return switch (filter) {
      SearchResultsFilter.all => CustomScrollView(
        // Reset scroll position when filter changes.
        key: ValueKey(filter),
        slivers: [
          PeopleSection(
            onSeeAll: () =>
                context.read<SearchResultsFilterCubit>().filterChanged(.people),
          ),
          ListsSection(
            onSeeAll: () =>
                context.read<SearchResultsFilterCubit>().filterChanged(.lists),
          ),
          TagsSection(
            onSeeAll: () =>
                context.read<SearchResultsFilterCubit>().filterChanged(.tags),
          ),
          VideosSection(
            onSeeAll: () =>
                context.read<SearchResultsFilterCubit>().filterChanged(.videos),
          ),
          const SliverBottomSafeArea(),
        ],
      ),
      SearchResultsFilter.people => const CustomScrollView(
        slivers: [PeopleSection(showAll: true), SliverBottomSafeArea()],
      ),
      SearchResultsFilter.tags => const CustomScrollView(
        slivers: [TagsSection(showAll: true), SliverBottomSafeArea()],
      ),
      SearchResultsFilter.lists => const CustomScrollView(
        slivers: [ListsSection(showAll: true), SliverBottomSafeArea()],
      ),
      SearchResultsFilter.videos => const CustomScrollView(
        slivers: [VideosSection(showAll: true), SliverBottomSafeArea()],
      ),
    };
  }
}
