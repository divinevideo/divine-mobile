import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';

/// Shows the search-filter selection bottom sheet.
///
/// Uses [VineBottomSheetSelectionMenu] to present filter options and updates
/// the [SearchResultsFilterCubit] when the user picks one.
class SearchFilterSheet {
  static Future<void> show(BuildContext context) async {
    final cubit = context.read<SearchResultsFilterCubit>();

    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: cubit.state.name,
      options: [
        for (final filter in SearchResultsFilter.values)
          VineBottomSheetSelectionOptionData(
            label: filter.label,
            value: filter.name,
          ),
      ],
    );

    if (selected == null) return;

    final filter = SearchResultsFilter.values.byName(selected);
    cubit.filterChanged(filter);
  }
}
