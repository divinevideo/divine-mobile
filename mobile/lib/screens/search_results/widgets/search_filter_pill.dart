import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_sheet.dart';
import 'package:videos_repository/videos_repository.dart';

/// Green pill button that shows the active search filter label.
///
/// Tapping it opens [SearchFilterSheet] so the user can pick a different
/// category.
class SearchFilterPill extends StatelessWidget {
  const SearchFilterPill({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.select(
      (SearchResultsFilterCubit cubit) => cubit.state,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          _SearchFilterButton(filter: filter),
          if (filter == SearchResultsFilter.videos)
            const _VideoSearchSortButton(),
        ],
      ),
    );
  }
}

class _SearchFilterButton extends StatelessWidget {
  const _SearchFilterButton({required this.filter});

  final SearchResultsFilter filter;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.searchFilterPill,
      label: context.l10n.searchFilterPillSemanticLabel(filter.label),
      button: true,
      child: GestureDetector(
        onTap: () => SearchFilterSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            filter.label,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoSearchSortButton extends StatelessWidget {
  const _VideoSearchSortButton();

  @override
  Widget build(BuildContext context) {
    final sort = context.select((VideoSearchBloc bloc) => bloc.state.sort);
    final label = _videoSearchSortLabel(context, sort);

    return Semantics(
      label: context.l10n.searchVideosSortOptionsLabel,
      button: true,
      child: Material(
        color: VineTheme.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final selected = await VineBottomSheetSelectionMenu.show(
              context: context,
              selectedValue: sort.apiValue,
              options: _videoSearchSortOptions(context),
            );
            if (!context.mounted ||
                selected == null ||
                selected == sort.apiValue) {
              return;
            }

            final selectedSort = _videoSearchSortFromApiValue(selected);
            if (selectedSort == null) return;

            context.read<VideoSearchBloc>().add(
              VideoSearchSortChanged(selectedSort),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(
                  label,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.accentPositive,
                  ),
                ),
                DivineIcon(
                  icon: DivineIconName.caretDown,
                  color: context.vineColors.accentPositive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<VineBottomSheetSelectionOptionData> _videoSearchSortOptions(
  BuildContext context,
) => [
  for (final sort in VideoSearchSort.values)
    VineBottomSheetSelectionOptionData(
      label: _videoSearchSortLabel(context, sort),
      value: sort.apiValue,
    ),
];

String _videoSearchSortLabel(BuildContext context, VideoSearchSort sort) {
  final l10n = context.l10n;

  return switch (sort) {
    VideoSearchSort.trending => l10n.searchVideosSortTrending,
    VideoSearchSort.loops => l10n.searchVideosSortLoops,
    VideoSearchSort.engagement => l10n.searchVideosSortEngagement,
    VideoSearchSort.recent => l10n.searchVideosSortRecent,
  };
}

VideoSearchSort? _videoSearchSortFromApiValue(String value) {
  for (final sort in VideoSearchSort.values) {
    if (sort.apiValue == value) return sort;
  }
  return null;
}
