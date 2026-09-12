// ABOUTME: Shared sort sheet for the followers and following lists
// ABOUTME: Returns the picked FollowSortOrder, or null when dismissed

import 'package:divine_ui/divine_ui.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Opens the follow-list sort sheet with [current] preselected.
///
/// Returns the order the user picked, or `null` when they dismissed the sheet
/// without choosing — callers should leave the list alone in that case.
///
/// Shared by the followers and following screens so both offer the same two
/// options in the same wording.
Future<FollowSortOrder?> showFollowSortMenu({
  required BuildContext context,
  required FollowSortOrder current,
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
        label: context.l10n.followSortNewest,
        value: FollowSortOrder.newestFirst.name,
        leadingIcon: .arrowFatLineDown,
      ),
      VineBottomSheetSelectionOptionData(
        label: context.l10n.followSortOldest,
        value: FollowSortOrder.oldestFirst.name,
        leadingIcon: .arrowFatLineUp,
      ),
    ],
  );

  if (selected == null) return null;
  return FollowSortOrder.values.byName(selected);
}
