// ABOUTME: Shared sort sheet for the followers and following lists
// ABOUTME: Returns the picked FollowListSort, or null when dismissed

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/l10n/l10n.dart';

/// Opens the follow-list sort sheet with [current] preselected.
///
/// Returns the order the user picked, or `null` when they dismissed the sheet
/// without choosing — callers should leave the list alone in that case.
///
/// Shared by the followers and following screens so both offer the same three
/// options in the same wording.
Future<FollowListSort?> showFollowSortMenu({
  required BuildContext context,
  required FollowListSort current,
}) async {
  final selected = await VineBottomSheetSelectionMenu.show(
    context: context,
    title: Text(
      context.l10n.followSortTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
    ),
    selectedValue: current.name,
    options: [
      VineBottomSheetSelectionOptionData(
        label: context.l10n.followSortSmart,
        value: FollowListSort.smart.name,
        leadingIcon: .sparkle,
      ),
      VineBottomSheetSelectionOptionData(
        label: context.l10n.followSortNewest,
        value: FollowListSort.newestFirst.name,
        leadingIcon: .arrowFatLineDown,
      ),
      VineBottomSheetSelectionOptionData(
        label: context.l10n.followSortOldest,
        value: FollowListSort.oldestFirst.name,
        leadingIcon: .arrowFatLineUp,
      ),
    ],
  );

  if (selected == null) return null;
  return FollowListSort.values.byName(selected);
}
